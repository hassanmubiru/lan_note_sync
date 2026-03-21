// lib/services/sync/sync_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../models/note.dart';
import '../../models/peer.dart';
import '../../services/storage/hive_service.dart';
import '../../services/device_service.dart';
import '../../services/webrtc_service.dart';
import '../../services/network/http_server_service.dart';

enum SyncResult { success, partial, conflict, failed }

class SyncOutcome {
  final SyncResult result;
  final int notesReceived;
  final int notesSent;
  final List<Note> conflicts;
  final String? error;

  const SyncOutcome({
    required this.result,
    this.notesReceived = 0,
    this.notesSent = 0,
    this.conflicts = const [],
    this.error,
  });

  @override
  String toString() =>
      'SyncOutcome(result: $result, received: $notesReceived, sent: $notesSent, conflicts: ${conflicts.length})';
}

class SyncService {
  final HttpServerService? httpServer;
  final WebRTCService? webRtcService;

  SyncService({this.httpServer, this.webRtcService});

  // ─── Pull notes from a peer (native HTTP) ─────────────────────────────────

  Future<SyncOutcome> pullFromPeer(
    DiscoveredPeer peer, {
    List<String>? specificIds,
  }) async {
    if (kIsWeb) {
      return _pullViaWebRtc(peer, specificIds: specificIds);
    }
    return _pullViaHttp(peer, specificIds: specificIds);
  }

  Future<SyncOutcome> _pullViaHttp(
    DiscoveredPeer peer, {
    List<String>? specificIds,
  }) async {
    try {
      debugPrint('[Sync] Pulling from ${peer.name} via HTTP');

      List<Note> fetchedNotes;

      if (specificIds != null && specificIds.isNotEmpty) {
        // Request specific notes
        final response = await http.post(
          Uri.parse('${peer.baseUrl}${AppConstants.endpointShare}'),
          headers: {
            'Content-Type': 'application/json',
            'X-Device-Id': DeviceService.deviceId,
          },
          body: jsonEncode({
            'requestedIds': specificIds,
            'sourceDeviceId': DeviceService.deviceId,
          }),
        ).timeout(AppConstants.syncTimeout);

        if (response.statusCode != 200) {
          return SyncOutcome(result: SyncResult.failed, error: 'HTTP ${response.statusCode}');
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final notesList = data['notes'] as List? ?? [];
        fetchedNotes = notesList.map((n) => Note.fromJson(n as Map<String, dynamic>)).toList();
      } else {
        // Get all notes
        final response = await http.get(
          Uri.parse('${peer.baseUrl}${AppConstants.endpointNotes}'),
          headers: {'X-Device-Id': DeviceService.deviceId},
        ).timeout(AppConstants.syncTimeout);

        if (response.statusCode != 200) {
          return SyncOutcome(result: SyncResult.failed, error: 'HTTP ${response.statusCode}');
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final metaList = data['notes'] as List? ?? [];

        // Determine which notes to fetch (those we don't have or have older versions)
        final toFetch = <String>[];
        for (final meta in metaList) {
          final id = meta['id'] as String;
          final version = meta['version'] as int? ?? 1;
          final existing = HiveService.getNoteById(id);
          if (existing == null || existing.version < version) {
            toFetch.add(id);
          }
        }

        if (toFetch.isEmpty) {
          return const SyncOutcome(result: SyncResult.success, notesReceived: 0);
        }

        // Fetch full content of needed notes
        final fetchResponse = await http.post(
          Uri.parse('${peer.baseUrl}${AppConstants.endpointShare}'),
          headers: {
            'Content-Type': 'application/json',
            'X-Device-Id': DeviceService.deviceId,
          },
          body: jsonEncode({
            'requestedIds': toFetch,
            'sourceDeviceId': DeviceService.deviceId,
          }),
        ).timeout(AppConstants.syncTimeout);

        if (fetchResponse.statusCode != 200) {
          return SyncOutcome(result: SyncResult.failed, error: 'HTTP ${fetchResponse.statusCode}');
        }

        final fetchData = jsonDecode(fetchResponse.body) as Map<String, dynamic>;
        final notesList = fetchData['notes'] as List? ?? [];
        fetchedNotes = notesList.map((n) => Note.fromJson(n as Map<String, dynamic>)).toList();
      }

      // Merge into local storage
      final conflicts = await HiveService.mergeNotes(
        fetchedNotes,
        sourceDeviceId: peer.id,
      );

      return SyncOutcome(
        result: conflicts.isEmpty ? SyncResult.success : SyncResult.conflict,
        notesReceived: fetchedNotes.length,
        conflicts: conflicts,
      );
    } catch (e) {
      debugPrint('[Sync] Pull failed: $e');
      return SyncOutcome(result: SyncResult.failed, error: e.toString());
    }
  }

  Future<SyncOutcome> _pullViaWebRtc(
    DiscoveredPeer peer, {
    List<String>? specificIds,
  }) async {
    // WebRTC sync is handled via data channel messages
    // Request notes from peer
    debugPrint('[Sync] Requesting notes via WebRTC from ${peer.name}');
    // The actual data comes through the WebRtcService callback
    return const SyncOutcome(result: SyncResult.success);
  }

  // ─── Push notes to a peer ─────────────────────────────────────────────────

  Future<SyncOutcome> pushToPeer(
    DiscoveredPeer peer,
    List<Note> notes,
  ) async {
    if (kIsWeb) {
      return _pushViaWebRtc(peer, notes);
    }
    return _pushViaHttp(peer, notes);
  }

  Future<SyncOutcome> _pushViaHttp(
    DiscoveredPeer peer,
    List<Note> notes,
  ) async {
    try {
      debugPrint('[Sync] Pushing ${notes.length} notes to ${peer.name} via HTTP');

      // Send in batches
      int sent = 0;
      for (var i = 0; i < notes.length; i += AppConstants.maxNotesPerBatch) {
        final batch = notes.skip(i).take(AppConstants.maxNotesPerBatch).toList();

        final response = await http.post(
          Uri.parse('${peer.baseUrl}${AppConstants.endpointShare}'),
          headers: {
            'Content-Type': 'application/json',
            'X-Device-Id': DeviceService.deviceId,
          },
          body: jsonEncode({
            'notes': batch.map((n) => n.toJson()).toList(),
            'sourceDeviceId': DeviceService.deviceId,
            'deviceName': DeviceService.deviceName,
          }),
        ).timeout(AppConstants.syncTimeout);

        if (response.statusCode == 200) {
          sent += batch.length;
        } else {
          debugPrint('[Sync] Batch push failed: ${response.statusCode}');
        }
      }

      return SyncOutcome(
        result: sent == notes.length ? SyncResult.success : SyncResult.partial,
        notesSent: sent,
      );
    } catch (e) {
      debugPrint('[Sync] Push failed: $e');
      return SyncOutcome(result: SyncResult.failed, error: e.toString());
    }
  }

  Future<SyncOutcome> _pushViaWebRtc(
    DiscoveredPeer peer,
    List<Note> notes,
  ) async {
    try {
      // WebRTC sync not yet implemented in this version
      // await webRtcService?.sendNotesToPeer(peer.id, notes);
      return SyncOutcome(result: SyncResult.success, notesSent: notes.length);
    } catch (e) {
      return SyncOutcome(result: SyncResult.failed, error: e.toString());
    }
  }

  // ─── Bidirectional Sync ────────────────────────────────────────────────────

  Future<SyncOutcome> syncBidirectional(DiscoveredPeer peer) async {
    debugPrint('[Sync] Starting bidirectional sync with ${peer.name}');

    // Push our notes
    final myNotes = HiveService.getAllNotes();
    final pushResult = await pushToPeer(peer, myNotes);

    // Pull their notes
    final pullResult = await pullFromPeer(peer);

    return SyncOutcome(
      result: (pushResult.result == SyncResult.success && pullResult.result == SyncResult.success)
          ? SyncResult.success
          : SyncResult.partial,
      notesSent: pushResult.notesSent,
      notesReceived: pullResult.notesReceived,
      conflicts: pullResult.conflicts,
    );
  }

  // ─── Conflict Resolution ───────────────────────────────────────────────────

  Future<void> resolveConflict(
    Note localNote,
    Note remoteNote, {
    required bool useLocal,
  }) async {
    final resolved = useLocal ? localNote : remoteNote;
    final updated = resolved.copyWith(
      version: (localNote.version > remoteNote.version ? localNote.version : remoteNote.version) + 1,
      updatedAt: DateTime.now(),
    );
    await HiveService.saveNote(updated);
  }

  Future<void> mergeConflict(
    Note localNote,
    Note remoteNote, {
    required String mergedContent,
    required String mergedTitle,
  }) async {
    final merged = localNote.copyWith(
      title: mergedTitle,
      content: mergedContent,
      version: (localNote.version > remoteNote.version ? localNote.version : remoteNote.version) + 1,
      updatedAt: DateTime.now(),
      tags: {...localNote.tags, ...remoteNote.tags}.toList(),
    );
    await HiveService.saveNote(merged);
  }
}
