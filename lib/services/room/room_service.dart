// lib/services/room/room_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../../models/room.dart';

class RoomService {
  final _networkInfo = NetworkInfo();

  String? _currentSsid;
  Timer? _pollTimer;

  final _roomController = StreamController<String?>.broadcast();
  Stream<String?> get ssidStream => _roomController.stream;

  String? get currentSsid => _currentSsid;
  String? get currentRoomId => _currentSsid != null ? _ssidToRoomId(_currentSsid!) : null;

  Future<void> start() async {
    await _refreshSsid();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshSsid());
  }

  Future<void> _refreshSsid() async {
    try {
      if (kIsWeb) return;
      final ssid = await _networkInfo.getWifiName();
      final cleaned = ssid?.replaceAll('"', '');
      if (cleaned != _currentSsid) {
        _currentSsid = cleaned;
        _roomController.add(_currentSsid);
        debugPrint('[Room] SSID changed → ${_currentSsid ?? "none"}');
      }
    } catch (e) {
      debugPrint('[Room] SSID fetch failed: $e');
    }
  }

  /// Convert WiFi SSID to a deterministic room ID
  String _ssidToRoomId(String ssid) {
    return ssid
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();
  }

  Future<String?> getCurrentIp() async {
    try { return await _networkInfo.getWifiIP(); } catch (_) { return null; }
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> dispose() async {
    stop();
    await _roomController.close();
  }
}
