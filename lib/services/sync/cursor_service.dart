// lib/services/sync/cursor_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../services/device_service.dart';

class PeerCursor {
  final String deviceId;
  final String deviceName;
  final Color color;
  final int offset;     // text cursor offset
  final DateTime lastSeen;

  const PeerCursor({
    required this.deviceId,
    required this.deviceName,
    required this.color,
    required this.offset,
    required this.lastSeen,
  });

  PeerCursor copyWith({int? offset, DateTime? lastSeen}) => PeerCursor(
        deviceId: deviceId,
        deviceName: deviceName,
        color: color,
        offset: offset ?? this.offset,
        lastSeen: lastSeen ?? this.lastSeen,
      );
}

class CursorService {
  static const _cursorColors = [
    Color(0xFF6366F1), Color(0xFF10B981), Color(0xFFF59E0B),
    Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF06B6D4),
  ];

  final Map<String, PeerCursor> _cursors = {};
  final _cursorController = StreamController<Map<String, PeerCursor>>.broadcast();
  Stream<Map<String, PeerCursor>> get cursorsStream => _cursorController.stream;

  WebSocketChannel? _channel;
  String? _currentNoteId;
  Timer? _cleanupTimer;

  Map<String, PeerCursor> get cursors => Map.unmodifiable(_cursors);

  Future<void> joinNote(String noteId, String peerHost, int port) async {
    await leaveNote();
    _currentNoteId = noteId;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://$peerHost:$port/cursor?noteId=$noteId'),
      );

      _channel!.stream.listen(
        _onMessage,
        onError: (_) => _channel = null,
        onDone: () => _channel = null,
      );

      // Send hello
      _sendCursor(0);

      // Clean up stale cursors every 5s
      _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        final stale = _cursors.keys
            .where((k) => DateTime.now()
                .difference(_cursors[k]!.lastSeen)
                .inSeconds > 10)
            .toList();
        for (final k in stale) _cursors.remove(k);
        if (stale.isNotEmpty) _emit();
      });
    } catch (e) {
      debugPrint('[Cursor] WebSocket connect failed: $e');
    }
  }

  Future<void> leaveNote() async {
    _cleanupTimer?.cancel();
    _cursors.clear();
    await _channel?.sink.close();
    _channel = null;
    _currentNoteId = null;
  }

  void updatePosition(int offset) {
    if (_channel == null) return;
    _sendCursor(offset);
  }

  void _sendCursor(int offset) {
    try {
      _channel?.sink.add(jsonEncode({
        'type': 'cursor',
        'deviceId': DeviceService.deviceId,
        'deviceName': DeviceService.deviceName,
        'noteId': _currentNoteId,
        'offset': offset,
        'ts': DateTime.now().millisecondsSinceEpoch,
      }));
    } catch (_) {}
  }

  void _onMessage(dynamic msg) {
    try {
      final data = jsonDecode(msg.toString()) as Map<String, dynamic>;
      final type = data['type'] as String?;
      if (type != 'cursor') return;

      final deviceId = data['deviceId'] as String? ?? '';
      if (deviceId == DeviceService.deviceId) return;

      final colorIdx = _cursors.length % _cursorColors.length;
      final existing = _cursors[deviceId];

      _cursors[deviceId] = PeerCursor(
        deviceId: deviceId,
        deviceName: data['deviceName'] as String? ?? '?',
        color: existing?.color ?? _cursorColors[colorIdx],
        offset: data['offset'] as int? ?? 0,
        lastSeen: DateTime.now(),
      );
      _emit();
    } catch (_) {}
  }

  void _emit() {
    if (!_cursorController.isClosed) {
      _cursorController.add(Map.from(_cursors));
    }
  }

  Future<void> dispose() async {
    await leaveNote();
    await _cursorController.close();
  }
}
