// lib/services/device_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'storage/hive_service.dart';

class DeviceService {
  static String? _deviceId;
  static String? _deviceName;

  static Future<void> initialize() async {
    _deviceId = await _getOrCreateDeviceId();
    _deviceName = await _getDeviceName();
  }

  static String get deviceId => _deviceId ?? 'unknown-${DateTime.now().millisecondsSinceEpoch}';
  static String get deviceName => _deviceName ?? 'Unknown Device';

  static Future<String> _getOrCreateDeviceId() async {
    const key = 'device_id';
    final existing = HiveService.getSetting<String>(key);
    if (existing != null) return existing;

    final id = const Uuid().v4();
    await HiveService.setSetting(key, id);
    return id;
  }

  static Future<String> _getDeviceName() async {
    // Check for user-set custom name
    final customName = HiveService.getSetting<String>('device_name');
    if (customName != null && customName.isNotEmpty) return customName;

    try {
      final info = DeviceInfoPlugin();

      if (kIsWeb) {
        final webInfo = await info.webBrowserInfo;
        return 'Web - ${webInfo.browserName.name}';
      }

      if (Platform.isAndroid) {
        final androidInfo = await info.androidInfo;
        return androidInfo.model;
      }

      if (Platform.isIOS) {
        final iosInfo = await info.iosInfo;
        return iosInfo.name;
      }

      if (Platform.isMacOS) {
        final macInfo = await info.macOsInfo;
        return macInfo.computerName;
      }

      if (Platform.isWindows) {
        final winInfo = await info.windowsInfo;
        return winInfo.computerName;
      }

      if (Platform.isLinux) {
        final linuxInfo = await info.linuxInfo;
        return linuxInfo.prettyName ?? linuxInfo.name ?? 'Linux Device';
      }
    } catch (e) {
      debugPrint('[DeviceService] Error getting device name: $e');
    }

    return 'LanNote Device';
  }

  static Future<void> setCustomName(String name) async {
    _deviceName = name;
    await HiveService.setSetting('device_name', name);
  }

  static String get platform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  static bool get isNative => !kIsWeb;
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  static bool get isDesktop => !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
}
