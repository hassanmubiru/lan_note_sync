// lib/services/network/connectivity_service.dart
//
// Cross-network connectivity layer.
//
// Modes (auto-detected, priority order):
//   1. LAN Direct   — same subnet, mDNS discovery + direct HTTP/TCP
//   2. LAN WebRTC   — same LAN via WebRTC DataChannels (no relay needed)
//   3. WAN WebRTC   — different networks, WebRTC with STUN hole-punch
//   4. TURN Relay   — symmetric NAT / corporate firewall, relayed via TURN
//   5. Signal Relay — no WebRTC, messages relayed through signaling server
//
// Configuration:
//   - Public STUN:  stun.l.google.com, stun.cloudflare.com (free)
//   - Public TURN:  open-relay.metered.ca (free tier) or self-hosted
//   - Signaling:    configurable URL (default: wss://lannote-signal.fly.dev)

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';

// ─── ICE configuration ────────────────────────────────────────────────────────

/// ICE server configuration supporting LAN, WAN, and TURN relay.
class IceConfig {
  /// LAN-optimised: prefer host candidates, STUN as fallback
  static Map<String, dynamic> get lan => {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun.cloudflare.com:3478'},
    ],
    'iceTransportPolicy': 'all',
    'iceCandidatePoolSize': 10,
  };

  /// WAN: STUN for hole-punch + TURN for symmetric NAT fallback.
  /// Replace TURN credentials with your own for production.
  static Map<String, dynamic> get wan => {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun.cloudflare.com:3478'},
      {'urls': 'stun:global.stun.twilio.com:3478'},
      // Free TURN from open-relay.metered.ca
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turns:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
    'iceTransportPolicy': 'all',
    'iceCandidatePoolSize': 10,
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
  };

  /// Force relay only (TURN) — for environments that block UDP entirely
  static Map<String, dynamic> get relayOnly => {
    'iceServers': [
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turns:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
    'iceTransportPolicy': 'relay',
    'iceCandidatePoolSize': 5,
  };
}

// ─── Network mode ─────────────────────────────────────────────────────────────

enum NetworkMode { unknown, lan, wan, offline }
enum ConnectivityTier { direct, stun, turn, signalRelay }

class NetworkStatus {
  final NetworkMode mode;
  final ConnectivityTier tier;
  final String? localIp;
  final String? publicIp;
  final String? ssid;
  final bool isOnline;

  const NetworkStatus({
    required this.mode,
    required this.tier,
    this.localIp,
    this.publicIp,
    this.ssid,
    required this.isOnline,
  });

  static const offline = NetworkStatus(
    mode: NetworkMode.offline,
    tier: ConnectivityTier.signalRelay,
    isOnline: false,
  );

  String get displayMode {
    switch (mode) {
      case NetworkMode.lan:     return 'Local Network';
      case NetworkMode.wan:     return 'Internet';
      case NetworkMode.offline: return 'Offline';
      default:                  return 'Unknown';
    }
  }

  String get tierLabel {
    switch (tier) {
      case ConnectivityTier.direct:      return 'Direct P2P';
      case ConnectivityTier.stun:        return 'STUN (NAT traversal)';
      case ConnectivityTier.turn:        return 'TURN (relayed)';
      case ConnectivityTier.signalRelay: return 'Signal relay';
    }
  }

  @override
  String toString() => 'NetworkStatus($displayMode, $tierLabel, ip=$localIp)';
}

// ─── ConnectivityService ──────────────────────────────────────────────────────

class ConnectivityService {
  static const _publicIpUrl = 'https://api.ipify.org?format=json';
  static const _checkTimeout = Duration(seconds: 4);

  final _networkInfo = NetworkInfo();
  final _connectivity = Connectivity();

  NetworkStatus _status = NetworkStatus.offline;
  StreamSubscription? _connectivitySub;
  final _statusController = StreamController<NetworkStatus>.broadcast();

  Stream<NetworkStatus> get statusStream => _statusController.stream;
  NetworkStatus get status => _status;
  bool get isOnline => _status.isOnline;
  bool get isLan => _status.mode == NetworkMode.lan;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> start() async {
    await _refresh();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((_) => _refresh());
  }

  void stop() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  Future<void> dispose() async {
    stop();
    await _statusController.close();
  }

  // ─── Detection ──────────────────────────────────────────────────────────────

  Future<NetworkStatus> _refresh() async {
    final result = await _connectivity.checkConnectivity();
    final isConnected = result != ConnectivityResult.none;

    if (!isConnected) {
      _update(NetworkStatus.offline);
      return _status;
    }

    final localIp = await _getLocalIp();
    final ssid    = await _getSsid();
    final pubIp   = await _getPublicIp();

    final mode = localIp != null ? NetworkMode.lan : NetworkMode.wan;

    // Determine if LAN peers are likely reachable
    final tier = pubIp != null
        ? (localIp != null ? ConnectivityTier.direct : ConnectivityTier.stun)
        : ConnectivityTier.signalRelay;

    final status = NetworkStatus(
      mode: mode,
      tier: tier,
      localIp: localIp,
      publicIp: pubIp,
      ssid: ssid,
      isOnline: true,
    );

    _update(status);
    debugPrint('[Connectivity] $status');
    return status;
  }

  void _update(NetworkStatus s) {
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }

  Future<String?> _getLocalIp() async {
    try { return await _networkInfo.getWifiIP(); } catch (_) { return null; }
  }

  Future<String?> _getSsid() async {
    try {
      final raw = await _networkInfo.getWifiName();
      return raw?.replaceAll('"', '').trim();
    } catch (_) { return null; }
  }

  Future<String?> _getPublicIp() async {
    try {
      final res = await http.get(Uri.parse(_publicIpUrl)).timeout(_checkTimeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['ip'] as String?;
      }
    } catch (_) {}
    return null;
  }

  // ─── ICE config selection ───────────────────────────────────────────────────

  /// Returns the appropriate WebRTC ICE config based on current network status.
  Map<String, dynamic> get iceConfig {
    switch (_status.mode) {
      case NetworkMode.lan:
        // LAN: try host candidates first, fall back to STUN
        return IceConfig.lan;
      case NetworkMode.wan:
        // WAN: full STUN + TURN for NAT traversal
        return IceConfig.wan;
      default:
        return IceConfig.wan; // safe default
    }
  }

  // ─── Manual peer URL ────────────────────────────────────────────────────────

  /// Parse a manual peer address entered by the user.
  /// Accepts: IP, IP:port, hostname, hostname:port, lannote://... URLs
  static ManualPeerAddress? parseManualAddress(String input) {
    input = input.trim();
    if (input.isEmpty) return null;

    // lannote://ar?... QR format
    if (input.startsWith('lannote://')) {
      try {
        final uri = Uri.parse(input);
        final host = uri.queryParameters['h'] ?? '';
        final port = int.tryParse(uri.queryParameters['p'] ?? '') ?? AppConstants.servicePort;
        final name = uri.queryParameters['n'] ?? host;
        return ManualPeerAddress(host: host, port: port, displayName: name);
      } catch (_) {}
    }

    // Standard host:port
    if (input.contains(':')) {
      final parts = input.split(':');
      final host  = parts[0].trim();
      final port  = int.tryParse(parts[1].trim()) ?? AppConstants.servicePort;
      return ManualPeerAddress(host: host, port: port);
    }

    return ManualPeerAddress(host: input, port: AppConstants.servicePort);
  }

  Future<bool> canReachHost(String host, int port) async {
    try {
      final res = await http.get(
        Uri.parse('http://$host:$port${AppConstants.endpointPing}'),
      ).timeout(_checkTimeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class ManualPeerAddress {
  final String host;
  final int port;
  final String? displayName;
  const ManualPeerAddress({required this.host, required this.port, this.displayName});
  String get baseUrl => 'http://$host:$port';
}
