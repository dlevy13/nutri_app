// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'strava_day_activities.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StravaDayActivitiesAdapter extends TypeAdapter<StravaDayActivities> {
  @override
  final int typeId = 3;

  @override
  StravaDayActivities read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StravaDayActivities(
      date: fields[0] as String,
      activities: (fields[1] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      fetchedAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, StravaDayActivities obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.activities)
      ..writeByte(2)
      ..write(obj.fetchedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StravaDayActivitiesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
