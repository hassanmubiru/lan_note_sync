// lib/models/peer.dart
import 'package:flutter/material.dart';
import '../core/constants.dart';

// ─── Peer status ──────────────────────────────────────────────────────────────

enum PeerStatus { discovered, connecting, connected, syncing, error, disconnected }

// ─── DiscoveredPeer ───────────────────────────────────────────────────────────

class DiscoveredPeer {
  final String id;
  final String name;
  final String host;
  final int port;
  final int noteCount;
  final DateTime lastSeen;
  final PeerStatus status;
  final String? publicKey;
  final bool isWebPeer;
  final Map<String, dynamic> metadata;

  const DiscoveredPeer({
    required this.id,
    required this.name,
    required this.host,
    this.port = AppConstants.servicePort,
    this.noteCount = 0,
    required this.lastSeen,
    this.status = PeerStatus.discovered,
    this.publicKey,
    this.isWebPeer = false,
    this.metadata = const {},
  });

  DiscoveredPeer copyWith({
    String?  id,
    String?  name,
    String?  host,
    int?     port,
    int?     noteCount,
    DateTime? lastSeen,
    PeerStatus? status,
    String?  publicKey,
    bool?    isWebPeer,
    Map<String, dynamic>? metadata,
  }) =>
      DiscoveredPeer(
        id:         id         ?? this.id,
        name:       name       ?? this.name,
        host:       host       ?? this.host,
        port:       port       ?? this.port,
        noteCount:  noteCount  ?? this.noteCount,
        lastSeen:   lastSeen   ?? this.lastSeen,
        status:     status     ?? this.status,
        publicKey:  publicKey  ?? this.publicKey,
        isWebPeer:  isWebPeer  ?? this.isWebPeer,
        metadata:   metadata   ?? this.metadata,
      );

  // ─── Status helpers ─────────────────────────────────────────────────────────

  Color get statusColor {
    switch (status) {
      case PeerStatus.connected:    return AppColors.success;
      case PeerStatus.syncing:      return AppColors.warning;
      case PeerStatus.connecting:   return AppColors.tertiary;
      case PeerStatus.error:        return AppColors.error;
      default:                      return Colors.grey;
    }
  }

  String get statusText {
    switch (status) {
      case PeerStatus.discovered:   return 'Tap to connect';
      case PeerStatus.connecting:   return 'Connecting…';
      case PeerStatus.connected:    return 'Connected';
      case PeerStatus.syncing:      return 'Syncing…';
      case PeerStatus.error:        return 'Connection failed';
      case PeerStatus.disconnected: return 'Disconnected';
    }
  }

  // ─── Avatar helpers ─────────────────────────────────────────────────────────

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty
        ? name.substring(0, name.length.clamp(1, 2)).toUpperCase()
        : '?';
  }

  Color get avatarColor {
    const colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.tertiary,
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
    ];
    final idx = name.codeUnits.fold(0, (s, c) => s + c) % colors.length;
    return colors[idx];
  }

  // ─── Network helpers ────────────────────────────────────────────────────────

  String get baseUrl => 'http://$host:$port';
  bool   get isStale => DateTime.now().difference(lastSeen).inSeconds > 30;

  // ─── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id':         id,
        'name':       name,
        'host':       host,
        'port':       port,
        'noteCount':  noteCount,
        'lastSeen':   lastSeen.toIso8601String(),
        'publicKey':  publicKey,
        'isWebPeer':  isWebPeer,
      };

  factory DiscoveredPeer.fromJson(Map<String, dynamic> j) => DiscoveredPeer(
        id:        j['id']        as String,
        name:      j['name']      as String,
        host:      j['host']      as String,
        port:      j['port']      as int?    ?? AppConstants.servicePort,
        noteCount: j['noteCount'] as int?    ?? 0,
        lastSeen:  j['lastSeen'] != null
            ? DateTime.parse(j['lastSeen'] as String)
            : DateTime.now(),
        publicKey: j['publicKey'] as String?,
        isWebPeer: j['isWebPeer'] as bool?   ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DiscoveredPeer && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DiscoveredPeer(id: $id, name: $name, host: $host:$port)';
}

// ─── SyncMessage ──────────────────────────────────────────────────────────────

class SyncMessage {
  final SyncMessageType type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  SyncMessage({
    required this.type,
    required this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SyncMessage.fromJson(Map<String, dynamic> j) => SyncMessage(
        type: SyncMessageType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => SyncMessageType.unknown,
        ),
        payload:   Map<String, dynamic>.from(j['payload'] as Map? ?? {}),
        timestamp: DateTime.parse(
            j['timestamp'] as String? ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toJson() => {
        'type':      type.name,
        'payload':   payload,
        'timestamp': timestamp.toIso8601String(),
      };
}

enum SyncMessageType {
  hello,
  notesList,
  requestNotes,
  sendNotes,
  conflict,
  ack,
  bye,
  error,
  unknown,
}
