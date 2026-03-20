// lib/services/network/http_server_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants.dart';
import '../../models/note.dart';
import '../../services/storage/hive_service.dart';
import '../../services/device_service.dart';

class HttpServerService {
  HttpServer? _server;
  final List<WebSocketChannel> _wsClients = [];
  final Function(List<Note> notes, String sourceId)? onNotesReceived;
  final Function(String peerId)? onPeerConnected;

  bool get isRunning => _server != null;

  HttpServerService({this.onNotesReceived, this.onPeerConnected});

  Future<void> start({int port = AppConstants.servicePort}) async {
    if (kIsWeb) return; // HTTP server only on native

    try {
      final router = Router();

      // GET /info - device info
      router.get(AppConstants.endpointInfo, _handleInfo);

      // GET /ping - health check
      router.get(AppConstants.endpointPing, _handlePing);

      // GET /notes - list notes (metadata only)
      router.get(AppConstants.endpointNotes, _handleGetNotes);

      // POST /share - receive notes from peer
      router.post(AppConstants.endpointShare, _handleShare);

      // WebSocket /sync - real-time bidirectional sync
      router.get(AppConstants.wsPath, webSocketHandler(_handleWebSocket));

      // CORS + logging pipeline
      final handler = Pipeline()
          .addMiddleware(_corsMiddleware())
          .addMiddleware(logRequests())
          .addHandler(router.call);

      _server = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        port,
      );

      debugPrint('[HttpServer] Running on ${_server!.address.address}:${_server!.port}');
    } catch (e) {
      debugPrint('[HttpServer] Failed to start: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    for (final client in _wsClients) {
      await client.sink.close();
    }
    _wsClients.clear();
    await _server?.close(force: true);
    _server = null;
    debugPrint('[HttpServer] Stopped');
  }

  // ─── Route Handlers ────────────────────────────────────────────────────────

  Response _handleInfo(Request request) {
    final info = {
      'deviceId': DeviceService.deviceId,
      'deviceName': DeviceService.deviceName,
      'platform': DeviceService.platform,
      'noteCount': HiveService.notesBox.length,
      'version': '1.0.0',
    };
    return Response.ok(
      jsonEncode(info),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Response _handlePing(Request request) {
    return Response.ok('{"status":"ok","time":"${DateTime.now().toIso8601String()}"}',
        headers: {'Content-Type': 'application/json'});
  }

  Response _handleGetNotes(Request request) {
    final notes = HiveService.getAllNotes();
    // Return only metadata (not full content) for the list view
    final meta = notes.map((n) => {
          'id': n.id,
          'title': n.title,
          'updatedAt': n.updatedAt.toIso8601String(),
          'version': n.version,
          'tags': n.tags,
          'folder': n.folder,
        }).toList();
    return Response.ok(
      jsonEncode({'notes': meta, 'total': meta.length}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _handleShare(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final sourceId = data['sourceDeviceId'] as String? ?? 'unknown';
      final notesList = data['notes'] as List;
      final notes = notesList
          .map((n) => Note.fromJson(n as Map<String, dynamic>))
          .toList();

      onNotesReceived?.call(notes, sourceId);

      return Response.ok(
        jsonEncode({'status': 'ok', 'received': notes.length}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  void _handleWebSocket(WebSocketChannel channel) {
    _wsClients.add(channel);
    debugPrint('[HttpServer] WebSocket client connected. Total: ${_wsClients.length}');

    // Send initial hello
    channel.sink.add(jsonEncode({
      'type': 'hello',
      'payload': {
        'deviceId': DeviceService.deviceId,
        'deviceName': DeviceService.deviceName,
        'noteCount': HiveService.notesBox.length,
      },
      'timestamp': DateTime.now().toIso8601String(),
    }));

    channel.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message.toString()) as Map<String, dynamic>;
          _handleWsMessage(data, channel);
        } catch (e) {
          debugPrint('[HttpServer] WS parse error: $e');
        }
      },
      onDone: () {
        _wsClients.remove(channel);
        debugPrint('[HttpServer] WS client disconnected');
      },
      onError: (error) {
        _wsClients.remove(channel);
        debugPrint('[HttpServer] WS error: $error');
      },
    );
  }

  void _handleWsMessage(Map<String, dynamic> data, WebSocketChannel channel) {
    final type = data['type'] as String?;
    switch (type) {
      case 'requestNotes':
        _handleWsRequestNotes(data, channel);
        break;
      case 'sendNotes':
        _handleWsSendNotes(data);
        break;
      case 'ping':
        channel.sink.add(jsonEncode({'type': 'pong', 'timestamp': DateTime.now().toIso8601String()}));
        break;
    }
  }

  void _handleWsRequestNotes(Map<String, dynamic> data, WebSocketChannel channel) {
    final payload = data['payload'] as Map<String, dynamic>? ?? {};
    final requestedIds = List<String>.from(payload['ids'] as List? ?? []);

    List<Note> notes;
    if (requestedIds.isEmpty) {
      notes = HiveService.getAllNotes();
    } else {
      notes = requestedIds
          .map((id) => HiveService.getNoteById(id))
          .whereType<Note>()
          .toList();
    }

    channel.sink.add(jsonEncode({
      'type': 'sendNotes',
      'payload': {'notes': notes.map((n) => n.toJson()).toList()},
      'timestamp': DateTime.now().toIso8601String(),
    }));
  }

  void _handleWsSendNotes(Map<String, dynamic> data) {
    final payload = data['payload'] as Map<String, dynamic>? ?? {};
    final notesList = payload['notes'] as List? ?? [];
    final sourceId = payload['sourceDeviceId'] as String? ?? 'unknown';

    final notes = notesList
        .map((n) => Note.fromJson(n as Map<String, dynamic>))
        .toList();

    onNotesReceived?.call(notes, sourceId);
  }

  /// Broadcast to all WebSocket clients
  void broadcast(String message) {
    for (final client in List.from(_wsClients)) {
      try {
        client.sink.add(message);
      } catch (_) {
        _wsClients.remove(client);
      }
    }
  }

  // ─── CORS Middleware ───────────────────────────────────────────────────────

  Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final response = await handler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  static const Map<String, String> _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };
}
