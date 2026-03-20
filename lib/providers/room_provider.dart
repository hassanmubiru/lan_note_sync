// lib/providers/room_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room.dart';
import '../models/note.dart';
import '../services/room/room_service.dart';
import '../services/storage/hive_service.dart';

class RoomState {
  final Room? currentRoom;
  final bool isAutoJoined;

  const RoomState({this.currentRoom, this.isAutoJoined = false});

  RoomState copyWith({Room? currentRoom, bool? isAutoJoined}) => RoomState(
        currentRoom: currentRoom ?? this.currentRoom,
        isAutoJoined: isAutoJoined ?? this.isAutoJoined,
      );

  List<Note> pinnedNotes(List<Note> allNotes) {
    if (currentRoom == null) return [];
    return allNotes
        .where((n) => currentRoom!.pinnedNoteIds.contains(n.id))
        .toList();
  }
}

class RoomNotifier extends StateNotifier<RoomState> {
  final RoomService _roomService;
  StreamSubscription<String?>? _ssidSub;

  RoomNotifier(this._roomService) : super(const RoomState()) {
    _init();
  }

  Future<void> _init() async {
    await _roomService.start();
    _ssidSub = _roomService.ssidStream.listen(_onSsidChange);

    // Check current SSID immediately
    final ssid = _roomService.currentSsid;
    if (ssid != null && ssid.isNotEmpty) {
      _onSsidChange(ssid);
    }
  }

  void _onSsidChange(String? ssid) {
    if (ssid == null || ssid.isEmpty) {
      state = const RoomState();
      return;
    }

    final room = Room.fromSsid(ssid);

    // Restore pinned notes from storage
    final pinnedKey = 'room_pins_${room.id}';
    final savedPins = HiveService.getSetting<List>('room_pins_${room.id}');
    final pinIds = savedPins != null ? List<String>.from(savedPins) : <String>[];

    state = RoomState(
      currentRoom: room.copyWith(pinnedNoteIds: pinIds),
      isAutoJoined: true,
    );
  }

  Future<void> pinNote(String noteId) async {
    if (state.currentRoom == null) return;
    final updated = List<String>.from(state.currentRoom!.pinnedNoteIds);
    if (!updated.contains(noteId)) updated.add(noteId);
    await _savePins(updated);
    state = state.copyWith(currentRoom: state.currentRoom!.copyWith(pinnedNoteIds: updated));
  }

  Future<void> unpinNote(String noteId) async {
    if (state.currentRoom == null) return;
    final updated = List<String>.from(state.currentRoom!.pinnedNoteIds)
      ..remove(noteId);
    await _savePins(updated);
    state = state.copyWith(currentRoom: state.currentRoom!.copyWith(pinnedNoteIds: updated));
  }

  Future<void> _savePins(List<String> pins) async {
    if (state.currentRoom == null) return;
    await HiveService.setSetting('room_pins_${state.currentRoom!.id}', pins);
  }

  @override
  void dispose() {
    _ssidSub?.cancel();
    _roomService.dispose();
    super.dispose();
  }
}

final roomServiceProvider = Provider<RoomService>((ref) {
  final s = RoomService();
  ref.onDispose(() => s.dispose());
  return s;
});

final roomProvider = StateNotifierProvider<RoomNotifier, RoomState>((ref) {
  return RoomNotifier(ref.watch(roomServiceProvider));
});
