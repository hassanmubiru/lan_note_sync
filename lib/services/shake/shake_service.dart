// lib/services/shake/shake_service.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';
import '../../core/constants.dart';

/// Detects device shake via accelerometer.
/// Fires [onShake] callback (max once per [shakeMinInterval] ms).
class ShakeService {
  StreamSubscription<AccelerometerEvent>? _sub;
  DateTime _lastShake = DateTime(2000);
  final VoidCallback onShake;

  // Gesture smoothing
  double _prevX = 0, _prevY = 0, _prevZ = 0;
  bool _listening = false;

  ShakeService({required this.onShake});

  bool get isListening => _listening;

  Future<void> start() async {
    if (_listening || kIsWeb) return;

    _sub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen(_onAccelerometer);

    _listening = true;
    debugPrint('[Shake] Listening for shake gestures');
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _listening = false;
  }

  void _onAccelerometer(AccelerometerEvent e) {
    final dx = e.x - _prevX;
    final dy = e.y - _prevY;
    final dz = e.z - _prevZ;

    _prevX = e.x;
    _prevY = e.y;
    _prevZ = e.z;

    final magnitude = sqrt(dx * dx + dy * dy + dz * dz);

    if (magnitude > AppConstants.shakeThreshold) {
      final now = DateTime.now();
      final msSinceLast = now.difference(_lastShake).inMilliseconds;

      if (msSinceLast > AppConstants.shakeMinInterval) {
        _lastShake = now;
        _triggerShake();
      }
    }
  }

  void _triggerShake() {
    debugPrint('[Shake] Shake detected!');
    _hapticFeedback();
    onShake();
  }

  Future<void> _hapticFeedback() async {
    try {
      final canVibrate = await Vibration.hasVibrator() ?? false;
      if (canVibrate) {
        await Vibration.vibrate(pattern: [0, 80, 50, 80], intensities: [0, 200, 0, 200]);
      }
    } catch (_) {}
  }

  void dispose() => stop();
}
