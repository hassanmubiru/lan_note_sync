// lib/services/ssid_room_manager.dart
//
// WiFi SSID → Auto-Room Sync
//
// How it works:
//   1. Poll current SSID every 8 seconds via network_info_plus
//   2. When SSID changes → emit [RoomChangeEvent]
//   3. Callers subscribe via [roomStream] to react (join/leave rooms)
//   4. Each unique SSID becomes a deterministic room ID
//
// Test case: Connect to "Cafe123" → auto room join in <3s

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/room.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

enum RoomEventType { joined, left, unchanged }

class RoomChangeEvent {
  final RoomEventType type;
  final Room? room;       // null when 'left'
  final String? prevSsid;
  final String? newSsid;

  const RoomChangeEvent({
    required this.type,
    this.room,
    this.prevSsid,
    this.newSsid,
  });

  bool get isJoin  => type == RoomEventType.joined;
  bool get isLeave => type == RoomEventType.left;

  @override
  String toString() => 'RoomChangeEvent($type, $newSsid)';
}

// ─── SsidRoomManager ─────────────────────────────────────────────────────────

class SsidRoomManager {
  static const _pollInterval = Duration(seconds: 8);

  final _networkInfo = NetworkInfo();

  String? _currentSsid;
  Room?   _currentRoom;
  Timer?  _timer;
  bool    _started = false;

  final _eventController = StreamController<RoomChangeEvent>.broadcast();
  Stream<RoomChangeEvent> get roomStream => _eventController.stream;

  String? get currentSsid => _currentSsid;
  Room?   get currentRoom => _currentRoom;
  bool    get hasRoom     => _currentRoom != null;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_started || kIsWeb) return;
    _started = true;

    await _requestPermission();
    await _refresh();
    _timer = Timer.periodic(_pollInterval, (_) => _refresh());
    debugPrint('[SSID] Room manager started. Poll every ${_pollInterval.inSeconds}s');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  Future<void> dispose() async {
    stop();
    await _eventController.close();
  }

  // ─── Permission ────────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    if (kIsWeb) return;
    try {
      // Android 8+: SSID requires location permission
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) {
        debugPrint('[SSID] Location permission denied — SSID unavailable on Android 8+');
      }
    } catch (_) {}
  }

  // ─── Core polling ──────────────────────────────────────────────────────────

  Future<void> _refresh() async {
    try {
      final rawSsid = await _networkInfo.getWifiName();
      final ssid    = _clean(rawSsid);

      if (ssid == _currentSsid) return; // no change

      final prev = _currentSsid;
      _currentSsid = ssid;

      if (ssid == null || ssid.isEmpty) {
        // Left WiFi
        final leftRoom = _currentRoom;
        _currentRoom = null;
        _emit(RoomChangeEvent(type: RoomEventType.left, prevSsid: prev));
        debugPrint('[SSID] Left WiFi — room closed (was: $prev)');
      } else {
        // New SSID → create room
        _currentRoom = Room.fromSsid(ssid);
        _emit(RoomChangeEvent(
          type: RoomEventType.joined,
          room: _currentRoom,
          prevSsid: prev,
          newSsid: ssid,
        ));
        debugPrint('[SSID] Joined room for SSID: "$ssid" → id=${_currentRoom!.id}');
      }
    } catch (e) {
      debugPrint('[SSID] Poll error: $e');
    }
  }

  // ─── Manual force-refresh ──────────────────────────────────────────────────

  Future<Room?> forceRefresh() async {
    // Temporarily clear current to force event even if SSID unchanged
    final saved = _currentSsid;
    _currentSsid = null;
    await _refresh();
    return _currentRoom;
  }

  // ─── Network info helpers ──────────────────────────────────────────────────

  Future<String?> getCurrentIp() async {
    try { return await _networkInfo.getWifiIP(); } catch (_) { return null; }
  }

  Future<String?> getGatewayIp() async {
    try { return await _networkInfo.getWifiGatewayIP(); } catch (_) { return null; }
  }

  Future<String?> getSubnet() async {
    try { return await _networkInfo.getWifiSubmask(); } catch (_) { return null; }
  }

  /// Human-readable network summary for the settings screen
  Future<Map<String, String?>> getNetworkInfo() async => {
    'ssid':    currentSsid,
    'ip':      await getCurrentIp(),
    'gateway': await getGatewayIp(),
    'subnet':  await getSubnet(),
    'roomId':  currentRoom?.id,
  };

  // ─── Helpers ───────────────────────────────────────────────────────────────

  /// Android wraps SSIDs in double quotes — strip them.
  String? _clean(String? raw) {
    if (raw == null) return null;
    final s = raw.replaceAll('"', '').trim();
    return s.isEmpty ? null : s;
  }

  void _emit(RoomChangeEvent event) {
    if (!_eventController.isClosed) _eventController.add(event);
  }
}
