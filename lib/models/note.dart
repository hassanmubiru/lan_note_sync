// lib/models/note.dart
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'note.g.dart';

@HiveType(typeId: 0)
class Note extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String content;

  @HiveField(3)
  List<String> tags;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  @HiveField(6)
  String? folder;

  @HiveField(7)
  List<String> imageBase64; // Base64 encoded images

  @HiveField(8)
  bool isPinned;

  @HiveField(9)
  bool isMarkdown;

  @HiveField(10)
  String? sourceDeviceId; // Which device this came from

  @HiveField(11)
  int version; // For conflict resolution

  @HiveField(12)
  String? color; // Optional note color (hex)

  Note({
    String? id,
    required this.title,
    this.content = '',
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.folder,
    List<String>? imageBase64,
    this.isPinned = false,
    this.isMarkdown = true,
    this.sourceDeviceId,
    this.version = 1,
    this.color,
  })  : id = id ?? const Uuid().v4(),
        tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        imageBase64 = imageBase64 ?? [];

  Note copyWith({
    String? id,
    String? title,
    String? content,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? folder,
    List<String>? imageBase64,
    bool? isPinned,
    bool? isMarkdown,
    String? sourceDeviceId,
    int? version,
    String? color,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? List.from(this.tags),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      folder: folder ?? this.folder,
      imageBase64: imageBase64 ?? List.from(this.imageBase64),
      isPinned: isPinned ?? this.isPinned,
      isMarkdown: isMarkdown ?? this.isMarkdown,
      sourceDeviceId: sourceDeviceId ?? this.sourceDeviceId,
      version: version ?? this.version,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'folder': folder,
      'imageBase64': imageBase64,
      'isPinned': isPinned,
      'isMarkdown': isMarkdown,
      'sourceDeviceId': sourceDeviceId,
      'version': version,
      'color': color,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String? ?? '',
      tags: List<String>.from(json['tags'] as List? ?? []),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      folder: json['folder'] as String?,
      imageBase64: List<String>.from(json['imageBase64'] as List? ?? []),
      isPinned: json['isPinned'] as bool? ?? false,
      isMarkdown: json['isMarkdown'] as bool? ?? true,
      sourceDeviceId: json['sourceDeviceId'] as String?,
      version: json['version'] as int? ?? 1,
      color: json['color'] as String?,
    );
  }

  /// Resolve conflict: last-write-wins strategy
  Note resolveConflict(Note other) {
    return updatedAt.isAfter(other.updatedAt) ? this : other;
  }

  /// Check if this note conflicts with another
  bool conflictsWith(Note other) {
    return id == other.id &&
        version != other.version &&
        (title != other.title || content != other.content);
  }

  String get preview {
    final stripped = content
        .replaceAll(RegExp(r'#{1,6}\s'), '')
        .replaceAll(RegExp(r'\*+'), '')
        .replaceAll(RegExp(r'`+'), '')
        .replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1')
        .trim();
    return stripped.length > 150 ? '${stripped.substring(0, 150)}...' : stripped;
  }

  @override
  String toString() => 'Note(id: $id, title: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Note && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
