// lib/models/note.g.dart
// GENERATED CODE - manually written for completeness
// Run `flutter pub run build_runner build` to regenerate

part of 'note.dart';

class NoteAdapter extends TypeAdapter<Note> {
  @override
  final int typeId = 0;

  @override
  Note read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Note(
      id: fields[0] as String,
      title: fields[1] as String,
      content: fields[2] as String,
      tags: (fields[3] as List).cast<String>(),
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime,
      folder: fields[6] as String?,
      imageBase64: (fields[7] as List).cast<String>(),
      isPinned: fields[8] as bool,
      isMarkdown: fields[9] as bool,
      sourceDeviceId: fields[10] as String?,
      version: fields[11] as int,
      color: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.tags)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.folder)
      ..writeByte(7)
      ..write(obj.imageBase64)
      ..writeByte(8)
      ..write(obj.isPinned)
      ..writeByte(9)
      ..write(obj.isMarkdown)
      ..writeByte(10)
      ..write(obj.sourceDeviceId)
      ..writeByte(11)
      ..write(obj.version)
      ..writeByte(12)
      ..write(obj.color);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
