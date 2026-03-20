// lib/providers/voice_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/voice/voice_service.dart';

class VoiceState {
  final VoiceStatus status;
  final String currentTranscript;
  final double confidence;

  const VoiceState({
    this.status = VoiceStatus.idle,
    this.currentTranscript = '',
    this.confidence = 0.0,
  });

  VoiceState copyWith({VoiceStatus? status, String? currentTranscript, double? confidence}) =>
      VoiceState(
        status: status ?? this.status,
        currentTranscript: currentTranscript ?? this.currentTranscript,
        confidence: confidence ?? this.confidence,
      );
}

class VoiceNotifier extends StateNotifier<VoiceState> {
  final VoiceService _service;
  StreamSubscription? _statusSub;
  StreamSubscription? _transcriptSub;

  VoiceNotifier(this._service) : super(const VoiceState()) {
    _statusSub = _service.statusStream.listen((s) {
      state = state.copyWith(status: s);
    });
    _transcriptSub = _service.transcriptStream.listen((t) {
      state = state.copyWith(currentTranscript: t);
    });
  }

  Future<void> startListening({String locale = 'en-US'}) async {
    state = state.copyWith(currentTranscript: '');
    await _service.startListening(locale: locale);
  }

  Future<VoiceResult?> stopListening() async {
    final result = await _service.stopListening();
    if (result != null) {
      state = state.copyWith(
        currentTranscript: result.text,
        confidence: result.confidence,
      );
    }
    return result;
  }

  Future<void> cancel() async {
    await _service.cancelListening();
    state = const VoiceState();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _transcriptSub?.cancel();
    _service.dispose();
    super.dispose();
  }
}

final voiceServiceProvider = Provider<VoiceService>((ref) {
  final s = VoiceService();
  ref.onDispose(() => s.dispose());
  return s;
});

final voiceProvider = StateNotifierProvider<VoiceNotifier, VoiceState>((ref) {
  return VoiceNotifier(ref.watch(voiceServiceProvider));
});
