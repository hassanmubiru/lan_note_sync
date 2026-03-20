// lib/services/storage/hive_service.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/note.dart';
import '../../core/constants.dart';

class HiveService {
  static Box<Note>? _notesBox;
  static Box<dynamic>? _settingsBox;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    await Hive.initFlutter();
    Hive.registerAdapter(NoteAdapter());

    // Generate or retrieve encryption key
    final encryptionKey = await _getOrCreateEncryptionKey();

    // Open encrypted boxes
    _notesBox = await Hive.openBox<Note>(
      AppConstants.notesBox,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );

    _settingsBox = await Hive.openBox<dynamic>(
      AppConstants.settingsBox,
    );

    _initialized = true;
    debugPrint('[HiveService] Initialized. Notes: ${_notesBox!.length}');
  }

  static Future<Uint8List> _getOrCreateEncryptionKey() async {
    // Use a separate non-encrypted box to store the key
    final keyBox = await Hive.openBox('_keystore');
    final existingKey = keyBox.get(AppConstants.encryptionKeyPref);

    if (existingKey != null) {
      return Uint8List.fromList(List<int>.from(existingKey as List));
    }

    // Generate new 32-byte key
    final key = Uint8List(AppConstants.keyLength);
    final rand = Random.secure();
    for (var i = 0; i < key.length; i++) {
      key[i] = rand.nextInt(256);
    }

    await keyBox.put(AppConstants.encryptionKeyPref, key.toList());
    return key;
  }

  // ─── Notes CRUD ───────────────────────────────────────────────────────────

  static Box<Note> get notesBox {
    assert(_initialized, 'HiveService not initialized');
    return _notesBox!;
  }

  static List<Note> getAllNotes() {
    return notesBox.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static List<Note> getNotesByFolder(String? folder) {
    return notesBox.values
        .where((n) => n.folder == folder)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static List<Note> searchNotes(String query) {
    final q = query.toLowerCase();
    return notesBox.values
        .where((n) =>
            n.title.toLowerCase().contains(q) ||
            n.content.toLowerCase().contains(q) ||
            n.tags.any((t) => t.toLowerCase().contains(q)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static Note? getNoteById(String id) {
    try {
      return notesBox.values.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveNote(Note note) async {
    await notesBox.put(note.id, note);
  }

  static Future<void> saveNotes(List<Note> notes) async {
    final map = {for (final n in notes) n.id: n};
    await notesBox.putAll(map);
  }

  static Future<void> deleteNote(String id) async {
    await notesBox.delete(id);
  }

  static Future<void> deleteAllNotes() async {
    await notesBox.clear();
  }

  /// Merge incoming notes from a peer with conflict detection
  static Future<List<Note>> mergeNotes(
    List<Note> incoming, {
    required String sourceDeviceId,
  }) async {
    final conflicts = <Note>[];

    for (final incomingNote in incoming) {
      final existing = getNoteById(incomingNote.id);

      if (existing == null) {
        // New note - just save it
        final saved = incomingNote.copyWith(sourceDeviceId: sourceDeviceId);
        await saveNote(saved);
      } else if (existing.conflictsWith(incomingNote)) {
        conflicts.add(incomingNote);
      } else {
        // Same version or no conflict - use last-write-wins
        final resolved = existing.resolveConflict(incomingNote);
        await saveNote(resolved);
      }
    }

    return conflicts;
  }

  // ─── Settings ─────────────────────────────────────────────────────────────

  static Box<dynamic> get settingsBox {
    assert(_initialized, 'HiveService not initialized');
    return _settingsBox!;
  }

  static T? getSetting<T>(String key, {T? defaultValue}) {
    return settingsBox.get(key, defaultValue: defaultValue) as T?;
  }

  static Future<void> setSetting<T>(String key, T value) async {
    await settingsBox.put(key, value);
  }

  // ─── Import/Export ────────────────────────────────────────────────────────

  static String exportNotesToJson(List<Note> notes) {
    final list = notes.map((n) => n.toJson()).toList();
    return jsonEncode({'version': 1, 'notes': list, 'exportedAt': DateTime.now().toIso8601String()});
  }

  static List<Note> importNotesFromJson(String jsonStr) {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final notesList = data['notes'] as List;
    return notesList.map((n) => Note.fromJson(n as Map<String, dynamic>)).toList();
  }

  // ─── Stats ────────────────────────────────────────────────────────────────

  static Map<String, int> getFolderStats() {
    final stats = <String, int>{};
    for (final note in notesBox.values) {
      final folder = note.folder ?? 'Uncategorized';
      stats[folder] = (stats[folder] ?? 0) + 1;
    }
    return stats;
  }

  static Future<void> dispose() async {
    await Hive.close();
  }
}
