// lib/providers/notes_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../services/storage/hive_service.dart';

// ─── Notes List ───────────────────────────────────────────────────────────────

class NotesNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() async {
    return HiveService.getAllNotes();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => HiveService.getAllNotes());
  }

  Future<void> addNote(Note note) async {
    await HiveService.saveNote(note);
    await refresh();
  }

  Future<void> updateNote(Note note) async {
    final updated = note.copyWith(
      updatedAt: DateTime.now(),
      version: note.version + 1,
    );
    await HiveService.saveNote(updated);
    await refresh();
  }

  Future<void> deleteNote(String id) async {
    await HiveService.deleteNote(id);
    await refresh();
  }

  Future<void> togglePin(String id) async {
    final note = HiveService.getNoteById(id);
    if (note != null) {
      await updateNote(note.copyWith(isPinned: !note.isPinned));
    }
  }

  Future<void> mergeIncoming(List<Note> incoming, String sourceId) async {
    final conflicts = await HiveService.mergeNotes(incoming, sourceDeviceId: sourceId);
    await refresh();
    if (conflicts.isNotEmpty) {
      state = AsyncError('Conflicts: ${conflicts.length}', StackTrace.current);
    }
  }
}

final notesProvider = AsyncNotifierProvider<NotesNotifier, List<Note>>(
  NotesNotifier.new,
);

// ─── Search ───────────────────────────────────────────────────────────────────

final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  final query = ref.watch(searchQueryProvider);
  final notesAsync = ref.watch(notesProvider);

  return notesAsync.when(
    data: (notes) {
      if (query.isEmpty) return AsyncData(notes);
      final filtered = HiveService.searchNotes(query);
      return AsyncData(filtered);
    },
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
  );
});

// ─── Folders ─────────────────────────────────────────────────────────────────

final foldersProvider = Provider<AsyncValue<Map<String, int>>>((ref) {
  final notesAsync = ref.watch(notesProvider);
  return notesAsync.when(
    data: (_) => AsyncData(HiveService.getFolderStats()),
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
  );
});

final selectedFolderProvider = StateProvider<String?>((ref) => null);

final notesByFolderProvider = Provider<AsyncValue<List<Note>>>((ref) {
  final folder = ref.watch(selectedFolderProvider);
  final notesAsync = ref.watch(notesProvider);
  return notesAsync.when(
    data: (_) => AsyncData(HiveService.getNotesByFolder(folder)),
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
  );
});

// ─── Single Note ──────────────────────────────────────────────────────────────

final noteByIdProvider = Provider.family<Note?, String>((ref, id) {
  ref.watch(notesProvider); // Re-evaluate when notes change
  return HiveService.getNoteById(id);
});

// ─── Selected Notes (for batch share) ────────────────────────────────────────

class SelectedNotesNotifier extends StateNotifier<Set<String>> {
  SelectedNotesNotifier() : super({});

  void toggle(String id) {
    if (state.contains(id)) {
      state = {...state}..remove(id);
    } else {
      state = {...state, id};
    }
  }

  void selectAll(List<Note> notes) {
    state = notes.map((n) => n.id).toSet();
  }

  void clearAll() {
    state = {};
  }

  bool isSelected(String id) => state.contains(id);
}

final selectedNotesProvider = StateNotifierProvider<SelectedNotesNotifier, Set<String>>(
  (ref) => SelectedNotesNotifier(),
);

// ─── Tags ─────────────────────────────────────────────────────────────────────

final allTagsProvider = Provider<List<String>>((ref) {
  final notesAsync = ref.watch(notesProvider);
  return notesAsync.maybeWhen(
    data: (notes) {
      final tags = <String>{};
      for (final note in notes) {
        tags.addAll(note.tags);
      }
      return tags.toList()..sort();
    },
    orElse: () => <Note>[],
  );
});

// ─── Sort ─────────────────────────────────────────────────────────────────────

enum NoteSort { updatedDesc, updatedAsc, titleAsc, titleDesc, createdDesc }

final noteSortProvider = StateProvider<NoteSort>((ref) => NoteSort.updatedDesc);

final sortedNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  final sort = ref.watch(noteSortProvider);
  final notesAsync = ref.watch(filteredNotesProvider);

  return notesAsync.whenData((notes) {
    final sorted = List<Note>.from(notes);
    switch (sort) {
      case NoteSort.updatedDesc:
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case NoteSort.updatedAsc:
        sorted.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case NoteSort.titleAsc:
        sorted.sort((a, b) => a.title.compareTo(b.title));
        break;
      case NoteSort.titleDesc:
        sorted.sort((a, b) => b.title.compareTo(a.title));
        break;
      case NoteSort.createdDesc:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    // Pinned notes always first
    final pinned = sorted.where((n) => n.isPinned).toList();
    final unpinned = sorted.where((n) => !n.isPinned).toList();
    return [...pinned, ...unpinned];
  });
});
