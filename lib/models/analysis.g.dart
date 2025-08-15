// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analysis.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AnalysisAdapter extends TypeAdapter<Analysis> {
  @override
  final int typeId = 2;

  @override
  Analysis read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Analysis(
      date: fields[0] as String,
      result: fields[1] as String,
      createdAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Analysis obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.result)
      ..writeByte(2)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
