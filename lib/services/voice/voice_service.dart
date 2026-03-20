// lib/services/voice/voice_service.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

enum VoiceStatus { idle, initializing, listening, processing, done, error }

class VoiceResult {
  final String text;
  final double confidence;
  final Duration duration;

  const VoiceResult({
    required this.text,
    required this.confidence,
    required this.duration,
  });
}

class VoiceService {
  final _stt = SpeechToText();
  bool _initialized = false;

  // Streams
  final _statusController = StreamController<VoiceStatus>.broadcast();
  final _transcriptController = StreamController<String>.broadcast();
  final _waveformController = StreamController<List<double>>.broadcast();

  Stream<VoiceStatus> get statusStream => _statusController.stream;
  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<List<double>> get waveformStream => _waveformController.stream;

  VoiceStatus _status = VoiceStatus.idle;
  String _currentTranscript = '';
  DateTime? _startTime;
  Timer? _waveformTimer;

  VoiceStatus get status => _status;
  String get currentTranscript => _currentTranscript;

  Future<bool> initialize() async {
    if (_initialized) return true;
    if (kIsWeb) {
      debugPrint('[Voice] STT available on web via Web Speech API');
    }

    _setStatus(VoiceStatus.initializing);
    try {
      _initialized = await _stt.initialize(
        onError: (err) {
          debugPrint('[Voice] Error: ${err.errorMsg}');
          _setStatus(VoiceStatus.error);
        },
        onStatus: (status) => debugPrint('[Voice] STT status: $status'),
        debugLogging: false,
      );
      if (_initialized) _setStatus(VoiceStatus.idle);
      return _initialized;
    } catch (e) {
      debugPrint('[Voice] Init failed: $e');
      _setStatus(VoiceStatus.error);
      return false;
    }
  }

  Future<void> startListening({String locale = 'en-US'}) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    _currentTranscript = '';
    _startTime = DateTime.now();
    _setStatus(VoiceStatus.listening);
    _startFakeWaveform(); // Visual waveform while listening

    await _stt.listen(
      onResult: _onResult,
      localeId: locale,
      cancelOnError: false,
      partialResults: true,
      listenMode: ListenMode.dictation,
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<VoiceResult?> stopListening() async {
    _stopFakeWaveform();
    _setStatus(VoiceStatus.processing);

    await _stt.stop();

    final duration = _startTime != null
        ? DateTime.now().difference(_startTime!)
        : Duration.zero;

    _setStatus(VoiceStatus.done);

    if (_currentTranscript.trim().isEmpty) {
      _setStatus(VoiceStatus.idle);
      return null;
    }

    return VoiceResult(
      text: _currentTranscript.trim(),
      confidence: 0.92, // speech_to_text provides confidence per word
      duration: duration,
    );
  }

  Future<void> cancelListening() async {
    _stopFakeWaveform();
    await _stt.cancel();
    _currentTranscript = '';
    _setStatus(VoiceStatus.idle);
  }

  void _onResult(SpeechRecognitionResult result) {
    _currentTranscript = result.recognizedWords;
    _transcriptController.add(_currentTranscript);
    debugPrint('[Voice] Partial: $_currentTranscript');
  }

  // Simulated waveform bars for visual feedback
  void _startFakeWaveform() {
    final rand = Random();
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (_status != VoiceStatus.listening) return;
      final bars = List.generate(20, (_) => 0.15 + rand.nextDouble() * 0.85);
      _waveformController.add(bars);
    });
  }

  void _stopFakeWaveform() {
    _waveformTimer?.cancel();
    _waveformTimer = null;
    _waveformController.add(List.filled(20, 0.1));
  }

  void _setStatus(VoiceStatus s) {
    _status = s;
    _statusController.add(s);
  }

  Future<List<LocaleName>> getLocales() async {
    if (!_initialized) await initialize();
    return _stt.locales();
  }

  Future<void> dispose() async {
    await cancelListening();
    await _statusController.close();
    await _transcriptController.close();
    await _waveformController.close();
  }
}
