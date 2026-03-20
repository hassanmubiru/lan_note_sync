// lib/models/room.dart

class Room {
  final String id;         // Derived from SSID
  final String ssid;       // Raw WiFi SSID
  final String displayName;
  final int peerCount;
  final int noteCount;
  final DateTime joinedAt;
  final List<String> pinnedNoteIds;

  const Room({
    required this.id,
    required this.ssid,
    required this.displayName,
    this.peerCount = 0,
    this.noteCount = 0,
    required this.joinedAt,
    this.pinnedNoteIds = const [],
  });

  Room copyWith({
    int? peerCount,
    int? noteCount,
    List<String>? pinnedNoteIds,
  }) =>
      Room(
        id: id,
        ssid: ssid,
        displayName: displayName,
        peerCount: peerCount ?? this.peerCount,
        noteCount: noteCount ?? this.noteCount,
        joinedAt: joinedAt,
        pinnedNoteIds: pinnedNoteIds ?? this.pinnedNoteIds,
      );

  String get emoji {
    // Give each room a fun emoji based on its name
    const emojis = ['🏢', '🎯', '🚀', '💡', '🔥', '⚡', '🌟', '🎪', '🏆', '🧠'];
    final idx = ssid.codeUnits.fold(0, (s, c) => s + c) % emojis.length;
    return emojis[idx];
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'ssid': ssid, 'displayName': displayName,
        'joinedAt': joinedAt.toIso8601String(),
        'pinnedNoteIds': pinnedNoteIds,
      };

  factory Room.fromSsid(String ssid) {
    final id = ssid.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
    return Room(
      id: id,
      ssid: ssid,
      displayName: ssid,
      joinedAt: DateTime.now(),
    );
  }
}
