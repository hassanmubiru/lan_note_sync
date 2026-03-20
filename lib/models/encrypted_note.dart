// lib/models/encrypted_note.dart
//
// Wire format for a note that has been E2EE-encrypted before transmission.
// All P2P note transfers use this envelope.

import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../services/e2ee_service.dart';
import 'note.dart';

class EncryptedNote {
  /// Unique transfer ID (not the note ID — used for dedup/ack)
  final String transferId;

  /// The E2EE payload
  final EncryptedPayload payload;

  /// Note ID (unencrypted for routing/conflict detection)
  final String noteId;

  /// Note version (unencrypted for conflict resolution)
  final int version;

  /// Sender's device ID
  final String senderDeviceId;

  /// Timestamp of this transfer
  final DateTime sentAt;

  EncryptedNote({
    String? transferId,
    required this.payload,
    required this.noteId,
    required this.version,
    required this.senderDeviceId,
    DateTime? sentAt,
  })  : transferId = transferId ?? const Uuid().v4(),
        sentAt = sentAt ?? DateTime.now();

  // ─── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'transferId': transferId,
        'noteId': noteId,
        'version': version,
        'senderDeviceId': senderDeviceId,
        'sentAt': sentAt.toIso8601String(),
        'payload': payload.toJson(),
      };

  factory EncryptedNote.fromJson(Map<String, dynamic> j) => EncryptedNote(
        transferId: j['transferId'] as String,
        noteId: j['noteId'] as String,
        version: j['version'] as int,
        senderDeviceId: j['senderDeviceId'] as String,
        sentAt: DateTime.parse(j['sentAt'] as String),
        payload: EncryptedPayload.fromJson(j['payload'] as Map<String, dynamic>),
      );

  String toJsonString() => jsonEncode(toJson());

  factory EncryptedNote.fromJsonString(String s) =>
      EncryptedNote.fromJson(jsonDecode(s) as Map<String, dynamic>);

  // ─── Factory: encrypt a Note ───────────────────────────────────────────────

  /// Encrypt a [Note] for transmission to a specific peer.
  static Future<EncryptedNote> fromNote({
    required Note note,
    required dynamic sharedKey, // SecretKey from E2EEService
    required String senderDeviceId,
    required String senderPublicKey,
  }) async {
    final payload = await E2EEService.encryptNote(
      note.toJson(),
      sharedKey,
      senderPublicKey: senderPublicKey,
    );

    return EncryptedNote(
      payload: payload,
      noteId: note.id,
      version: note.version,
      senderDeviceId: senderDeviceId,
    );
  }

  /// Decrypt this envelope back to a [Note].
  Future<Note?> toNote(dynamic sharedKey) async {
    final json = await E2EEService.decryptNote(payload, sharedKey);
    if (json == null) return null;
    return Note.fromJson(json);
  }

  @override
  String toString() =>
      'EncryptedNote(transferId: $transferId, noteId: $noteId, v$version)';
}

// ─── Transfer batch ───────────────────────────────────────────────────────────

class EncryptedNoteBatch {
  final String batchId;
  final String senderDeviceId;
  final String senderPublicKey;
  final List<EncryptedNote> notes;
  final DateTime createdAt;

  EncryptedNoteBatch({
    String? batchId,
    required this.senderDeviceId,
    required this.senderPublicKey,
    required this.notes,
    DateTime? createdAt,
  })  : batchId = batchId ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'batchId': batchId,
        'senderDeviceId': senderDeviceId,
        'senderPublicKey': senderPublicKey,
        'noteCount': notes.length,
        'createdAt': createdAt.toIso8601String(),
        'notes': notes.map((n) => n.toJson()).toList(),
      };

  factory EncryptedNoteBatch.fromJson(Map<String, dynamic> j) =>
      EncryptedNoteBatch(
        batchId: j['batchId'] as String,
        senderDeviceId: j['senderDeviceId'] as String,
        senderPublicKey: j['senderPublicKey'] as String,
        notes: (j['notes'] as List)
            .map((n) => EncryptedNote.fromJson(n as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
