// lib/providers/shake_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/shake/shake_service.dart';
import '../models/peer.dart';

class ShakeState {
  final bool isShaking;
  final DiscoveredPeer? justFoundPeer;
  final DateTime? lastShakeAt;

  const ShakeState({
    this.isShaking = false,
    this.justFoundPeer,
    this.lastShakeAt,
  });

  ShakeState copyWith({bool? isShaking, DiscoveredPeer? justFoundPeer, DateTime? lastShakeAt}) =>
      ShakeState(
        isShaking: isShaking ?? this.isShaking,
        justFoundPeer: justFoundPeer,
        lastShakeAt: lastShakeAt ?? this.lastShakeAt,
      );
}

class ShakeNotifier extends StateNotifier<ShakeState> {
  ShakeService? _service;

  ShakeNotifier() : super(const ShakeState());

  void start() {
    if (_service != null || kIsWeb) return;
    _service = ShakeService(onShake: _onShake);
    _service!.start();
  }

  void _onShake() {
    state = state.copyWith(
      isShaking: true,
      lastShakeAt: DateTime.now(),
    );
    // Auto-reset "isShaking" after animation completes
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) state = state.copyWith(isShaking: false);
    });
  }

  void notifyPeerFound(DiscoveredPeer peer) {
    state = state.copyWith(justFoundPeer: peer);
  }

  void clearFoundPeer() {
    state = ShakeState(
      isShaking: state.isShaking,
      lastShakeAt: state.lastShakeAt,
    );
  }

  @override
  void dispose() {
    _service?.dispose();
    super.dispose();
  }
}

final shakeProvider = StateNotifierProvider<ShakeNotifier, ShakeState>(
  (ref) {
    final notifier = ShakeNotifier();
    notifier.start();
    return notifier;
  },
);
