// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_calories.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyCaloriesAdapter extends TypeAdapter<DailyCalories> {
  @override
  final int typeId = 2;

  @override
  DailyCalories read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyCalories(
      date: fields[0] as String,
      objectif: fields[1] as double,
      strava: fields[2] as double,
      total: fields[3] as double,
      stravaFetchedAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyCalories obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.objectif)
      ..writeByte(2)
      ..write(obj.strava)
      ..writeByte(3)
      ..write(obj.total)
      ..writeByte(4)
      ..write(obj.stravaFetchedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyCaloriesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
