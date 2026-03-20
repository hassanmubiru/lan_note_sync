// lib/services/webrtc_service.dart
//
// WebRTC P2P Service — LAN + WAN + TURN relay, Web + Mobile.
//
// ICE strategy:
//   • LAN: host candidates → STUN fallback (sub-50ms)
//   • WAN: STUN hole-punch → TURN relay (works across NATs)
//   • Corporate: relay-only mode via TURN/TLS on port 443
//
// Two data channels per peer:
//   'notes-sync'  — reliable, ordered (note payloads)
//   'cursor-sync' — unreliable, unordered (live cursor, <16ms)

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/peer.dart';
import '../models/encrypted_note.dart';
import '../services/device_service.dart';
import '../services/network/connectivity_service.dart';

// ─── Message types ────────────────────────────────────────────────────────────

enum WebRTCMsgType { noteSync, cursorUpdate, hello, ack, bye }

class WebRTCMessage {
  final WebRTCMsgType type;
  final Map<String, dynamic> payload;
  final String fromDeviceId;
  final int timestamp;

  const WebRTCMessage({
    required this.type,
    required this.payload,
    required this.fromDeviceId,
    required this.timestamp,
  });

  factory WebRTCMessage.fromJson(Map<String, dynamic> j) => WebRTCMessage(
        type: WebRTCMsgType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => WebRTCMsgType.hello,
        ),
        payload:      Map<String, dynamic>.from(j['payload'] as Map? ?? {}),
        fromDeviceId: j['fromDeviceId'] as String? ?? '',
        timestamp:    j['ts'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'type':         type.name,
        'payload':      payload,
        'fromDeviceId': fromDeviceId,
        'ts':           timestamp,
      };
}

// ─── Per-peer connection ──────────────────────────────────────────────────────

class _PeerConn {
  RTCPeerConnection pc;
  RTCDataChannel? notesDc;
  RTCDataChannel? cursorDc;
  bool isReady = false;
  ConnectivityTier tier = ConnectivityTier.stun;

  _PeerConn(this.pc);

  Future<void> close() async {
    await notesDc?.close();
    await cursorDc?.close();
    await pc.close();
  }
}

// ─── WebRTCService ────────────────────────────────────────────────────────────

class WebRTCService {
  final ConnectivityService _connectivity;

  final void Function(EncryptedNote note, String fromPeerId)? onNoteReceived;
  final void Function(String peerId, String noteId, int offset)? onCursorUpdate;
  final void Function(DiscoveredPeer peer)? onPeerJoined;
  final void Function(String peerId)? onPeerLeft;
  final void Function(String peerId, ConnectivityTier tier)? onTierChanged;

  io.Socket? _socket;
  final Map<String, _PeerConn>    _peers    = {};
  final Map<String, DiscoveredPeer> _peerMeta = {};

  bool    _connected = false;
  String? _roomId;

  WebRTCService({
    required ConnectivityService connectivity,
    this.onNoteReceived,
    this.onCursorUpdate,
    this.onPeerJoined,
    this.onPeerLeft,
    this.onTierChanged,
  }) : _connectivity = connectivity;

  bool get isConnected => _connected;
  List<DiscoveredPeer> get connectedPeers =>
      _peerMeta.values.where((p) => _peers.containsKey(p.id)).toList();

  // ─── Connect to signaling server ──────────────────────────────────────────

  Future<void> connect(String signalingUrl, {required String roomId}) async {
    _roomId = roomId;
    debugPrint('[WebRTC] Connecting to $signalingUrl, room=$roomId');

    _socket = io.io(
      signalingUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/socket.io')
          .enableAutoConnect()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(10)
          .build(),
    );

    _socket!.onConnect((_) {
      _connected = true;
      debugPrint('[WebRTC] Signaling connected');
      _socket!.emit('join-room', {
        'room':       roomId,
        'deviceId':   DeviceService.deviceId,
        'deviceName': DeviceService.deviceName,
      });
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      debugPrint('[WebRTC] Signaling disconnected — will reconnect automatically');
    });

    _socket!.on('peers-in-room', _onPeersInRoom);
    _socket!.on('peer-joined',   _onRemotePeerJoined);
    _socket!.on('peer-left',     _onRemotePeerLeft);
    _socket!.on('offer',         _onOffer);
    _socket!.on('answer',        _onAnswer);
    _socket!.on('ice-candidate', _onIceCandidate);
    _socket!.on('relay',         _onRelay);

    _socket!.connect();
  }

  // ─── Peer presence ─────────────────────────────────────────────────────────

  void _onPeersInRoom(dynamic data) {
    for (final p in List<Map<String, dynamic>>.from(data as List? ?? [])) {
      final id = p['deviceId'] as String? ?? '';
      if (id.isEmpty || id == DeviceService.deviceId) continue;
      _registerPeer(p);
      connectToPeer(id);
    }
  }

  void _onRemotePeerJoined(dynamic data) {
    final p  = data as Map<String, dynamic>;
    final id = p['deviceId'] as String? ?? '';
    if (id.isEmpty || id == DeviceService.deviceId) return;
    onPeerJoined?.call(_registerPeer(p));
  }

  void _onRemotePeerLeft(dynamic data) {
    final id = (data as Map<String, dynamic>)['deviceId'] as String? ?? '';
    _peers[id]?.close();
    _peers.remove(id);
    _peerMeta.remove(id);
    onPeerLeft?.call(id);
  }

  DiscoveredPeer _registerPeer(Map<String, dynamic> data) {
    final peer = DiscoveredPeer(
      id:        data['deviceId']   as String,
      name:      data['deviceName'] as String? ?? 'Unknown',
      host:      data['host']       as String? ?? '',
      lastSeen:  DateTime.now(),
      isWebPeer: true,
    );
    _peerMeta[peer.id] = peer;
    return peer;
  }

  // ─── Initiate WebRTC connection ────────────────────────────────────────────

  Future<void> connectToPeer(String peerId) async {
    if (_peers.containsKey(peerId)) return;

    // Adaptive ICE: use richer config for WAN
    final iceConfig = _connectivity.iceConfig;
    debugPrint('[WebRTC] Connecting to $peerId with tier=${_connectivity.status.tier}');

    final conn = _PeerConn(await createPeerConnection(iceConfig));
    _peers[peerId] = conn;

    conn.notesDc = await conn.pc.createDataChannel(
      'notes-sync',
      RTCDataChannelInit()..ordered = true..maxRetransmits = 5,
    );
    conn.cursorDc = await conn.pc.createDataChannel(
      'cursor-sync',
      RTCDataChannelInit()..ordered = false..maxRetransmits = 0,
    );

    _hookDataChannel(conn.notesDc!, peerId, reliable: true);
    _hookDataChannel(conn.cursorDc!, peerId, reliable: false);
    _hookPeerConnection(conn.pc, peerId);

    final offer = await conn.pc.createOffer();
    await conn.pc.setLocalDescription(offer);

    _socket?.emit('offer', {
      'target': peerId,
      'from':   DeviceService.deviceId,
      'sdp':    offer.sdp,
      'type':   offer.type,
    });
  }

  // ─── ICE & connection hooks ────────────────────────────────────────────────

  void _hookPeerConnection(RTCPeerConnection pc, String peerId) {
    pc.onIceCandidate = (c) {
      if (c.candidate == null) return;
      _socket?.emit('ice-candidate', {
        'target':        peerId,
        'from':          DeviceService.deviceId,
        'candidate':     c.candidate,
        'sdpMid':        c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };

    pc.onIceConnectionState = (state) {
      debugPrint('[WebRTC] $peerId ICE → $state');
      // Detect TURN relay usage
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        _detectActualTier(pc, peerId);
      }
    };

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _peers[peerId]?.isReady = true;
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        debugPrint('[WebRTC] $peerId FAILED — attempting relay-only reconnect');
        _reconnectViaRelay(peerId);
      }
    };
  }

  /// Inspect selected candidate pair to detect if we're actually using TURN.
  Future<void> _detectActualTier(RTCPeerConnection pc, String peerId) async {
    try {
      final stats = await pc.getStats();
      ConnectivityTier tier = ConnectivityTier.direct;
      stats.forEach((report) {
        if (report.type == 'candidate-pair' && report.values['state'] == 'succeeded') {
          final remoteType = report.values['remoteCandidateType'] as String? ?? '';
          if (remoteType == 'relay') tier = ConnectivityTier.turn;
          else if (remoteType == 'srflx') tier = ConnectivityTier.stun;
          else tier = ConnectivityTier.direct;
        }
      });
      _peers[peerId]?.tier = tier;
      onTierChanged?.call(peerId, tier);
      debugPrint('[WebRTC] $peerId actual tier: $tier');
    } catch (_) {}
  }

  /// When connection fails, reconnect using relay-only ICE.
  Future<void> _reconnectViaRelay(String peerId) async {
    await _peers[peerId]?.close();
    _peers.remove(peerId);

    final conn = _PeerConn(await createPeerConnection(IceConfig.relayOnly));
    _peers[peerId] = conn;
    conn.pc.onDataChannel = (ch) => _hookDataChannel(ch, peerId, reliable: ch.label == 'notes-sync');
    _hookPeerConnection(conn.pc, peerId);

    conn.notesDc = await conn.pc.createDataChannel(
      'notes-sync',
      RTCDataChannelInit()..ordered = true..maxRetransmits = 10,
    );
    _hookDataChannel(conn.notesDc!, peerId, reliable: true);

    final offer = await conn.pc.createOffer();
    await conn.pc.setLocalDescription(offer);
    _socket?.emit('offer', {
      'target': peerId, 'from': DeviceService.deviceId,
      'sdp': offer.sdp, 'type': offer.type,
    });
    debugPrint('[WebRTC] $peerId relay-only reconnect initiated');
  }

  void _hookDataChannel(RTCDataChannel dc, String peerId, {required bool reliable}) {
    dc.onDataChannelState = (s) {
      if (s == RTCDataChannelState.RTCDataChannelOpen) {
        _peers[peerId]?.isReady = true;
      }
    };
    dc.onMessage = (msg) {
      try {
        _handleMessage(
          WebRTCMessage.fromJson(jsonDecode(msg.text) as Map<String, dynamic>),
          peerId,
          reliable: reliable,
        );
      } catch (e) {
        debugPrint('[WebRTC] Parse error: $e');
      }
    };
  }

  // ─── Signaling: receive ────────────────────────────────────────────────────

  Future<void> _onOffer(dynamic data) async {
    final from = (data as Map<String, dynamic>)['from'] as String;
    final sdp  = data['sdp']  as String;
    final type = data['type'] as String;

    final conn = _PeerConn(await createPeerConnection(_connectivity.iceConfig));
    _peers[from] = conn;
    _hookPeerConnection(conn.pc, from);
    conn.pc.onDataChannel = (ch) {
      if (ch.label == 'notes-sync')  { conn.notesDc  = ch; _hookDataChannel(ch, from, reliable: true);  }
      if (ch.label == 'cursor-sync') { conn.cursorDc = ch; _hookDataChannel(ch, from, reliable: false); }
    };

    await conn.pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    final answer = await conn.pc.createAnswer();
    await conn.pc.setLocalDescription(answer);

    _socket?.emit('answer', {
      'target': from, 'from': DeviceService.deviceId,
      'sdp': answer.sdp, 'type': answer.type,
    });
  }

  Future<void> _onAnswer(dynamic data) async {
    final from = (data as Map<String, dynamic>)['from'] as String;
    await _peers[from]?.pc.setRemoteDescription(
      RTCSessionDescription(data['sdp'] as String, data['type'] as String),
    );
  }

  Future<void> _onIceCandidate(dynamic data) async {
    final from  = (data as Map<String, dynamic>)['from'] as String;
    final cand  = data['candidate'] as String?;
    final mid   = data['sdpMid'] as String?;
    final index = data['sdpMLineIndex'] as int? ?? 0;
    if (cand != null) {
      await _peers[from]?.pc.addCandidate(RTCIceCandidate(cand, mid, index));
    }
  }

  void _onRelay(dynamic data) {
    try {
      final from    = (data as Map<String, dynamic>)['from'] as String;
      final payload = jsonDecode(data['payload'] as String) as Map<String, dynamic>;
      _handleMessage(WebRTCMessage.fromJson(payload), from, reliable: true);
    } catch (e) {
      debugPrint('[WebRTC] Relay error: $e');
    }
  }

  // ─── Message handling ──────────────────────────────────────────────────────

  void _handleMessage(WebRTCMessage msg, String peerId, {required bool reliable}) {
    switch (msg.type) {
      case WebRTCMsgType.noteSync:
        final note = EncryptedNote.fromJson(msg.payload);
        onNoteReceived?.call(note, peerId);
        _sendAck(peerId, note.transferId);
        break;
      case WebRTCMsgType.cursorUpdate:
        onCursorUpdate?.call(
          peerId,
          msg.payload['noteId'] as String? ?? '',
          msg.payload['offset'] as int? ?? 0,
        );
        break;
      default: break;
    }
  }

  // ─── Send helpers ──────────────────────────────────────────────────────────

  void sendNote(EncryptedNote note, {required String toPeer}) {
    _sendOnChannel(toPeer, reliable: true, message: WebRTCMessage(
      type: WebRTCMsgType.noteSync,
      payload: note.toJson(),
      fromDeviceId: DeviceService.deviceId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void broadcastNote(EncryptedNote note) {
    for (final id in _peers.keys) sendNote(note, toPeer: id);
  }

  void sendCursorUpdate(String peerId, String noteId, int offset) {
    _sendOnChannel(peerId, reliable: false, message: WebRTCMessage(
      type: WebRTCMsgType.cursorUpdate,
      payload: {'noteId': noteId, 'offset': offset},
      fromDeviceId: DeviceService.deviceId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void _sendAck(String peerId, String transferId) {
    _sendOnChannel(peerId, reliable: true, message: WebRTCMessage(
      type: WebRTCMsgType.ack,
      payload: {'transferId': transferId},
      fromDeviceId: DeviceService.deviceId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void _sendOnChannel(String peerId, {required bool reliable, required WebRTCMessage message}) {
    final conn = _peers[peerId];
    final dc   = reliable ? conn?.notesDc : conn?.cursorDc;

    if (dc?.state == RTCDataChannelState.RTCDataChannelOpen) {
      try {
        dc!.send(RTCDataChannelMessage(jsonEncode(message.toJson())));
      } catch (e) {
        debugPrint('[WebRTC] Send error: $e — falling back to relay');
        _relayViaSignaling(peerId, message);
      }
    } else {
      _relayViaSignaling(peerId, message);
    }
  }

  void _relayViaSignaling(String peerId, WebRTCMessage message) {
    _socket?.emit('relay', {
      'target':  peerId,
      'from':    DeviceService.deviceId,
      'payload': jsonEncode(message.toJson()),
    });
  }

  // ─── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    for (final c in _peers.values) await c.close();
    _peers.clear();
    _peerMeta.clear();
    _socket?.disconnect();
    _socket = null;
    _connected = false;
  }
}
