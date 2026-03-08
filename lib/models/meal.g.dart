// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MealAdapter extends TypeAdapter<Meal> {
  @override
  final int typeId = 0;

  @override
  Meal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Meal(
      name: fields[0] as String,
      calories: fields[1] as double,
      protein: fields[2] as double,
      carbs: fields[3] as double,
      fat: fields[4] as double,
      quantity: fields[5] as double,
      type: fields[6] as String,
      date: fields[7] as String,
      fiber: fields[8] as double?,
      sucres: fields[9] as double?,
      fatSaturated: fields[10] as double?,
      fatMonounsaturated: fields[11] as double?,
      fatPolyunsaturated: fields[12] as double?,
      group: fields[13] as String?,
      kcalPer100: fields[14] as double?,
      proteinPer100: fields[15] as double?,
      carbsPer100: fields[16] as double?,
      fatPer100: fields[17] as double?,
      fiberPer100: fields[18] as double?,
      sucresPer100: fields[19] as double?,
      fatSaturatedPer100: fields[20] as double?,
      fatMonounsaturatedPer100: fields[21] as double?,
      fatPolyunsaturatedPer100: fields[22] as double?,
      timestamp: fields[23] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Meal obj) {
    writer
      ..writeByte(24)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.calories)
      ..writeByte(2)
      ..write(obj.protein)
      ..writeByte(3)
      ..write(obj.carbs)
      ..writeByte(4)
      ..write(obj.fat)
      ..writeByte(5)
      ..write(obj.quantity)
      ..writeByte(6)
      ..write(obj.type)
      ..writeByte(7)
      ..write(obj.date)
      ..writeByte(8)
      ..write(obj.fiber)
      ..writeByte(9)
      ..write(obj.sucres)
      ..writeByte(10)
      ..write(obj.fatSaturated)
      ..writeByte(11)
      ..write(obj.fatMonounsaturated)
      ..writeByte(12)
      ..write(obj.fatPolyunsaturated)
      ..writeByte(13)
      ..write(obj.group)
      ..writeByte(14)
      ..write(obj.kcalPer100)
      ..writeByte(15)
      ..write(obj.proteinPer100)
      ..writeByte(16)
      ..write(obj.carbsPer100)
      ..writeByte(17)
      ..write(obj.fatPer100)
      ..writeByte(18)
      ..write(obj.fiberPer100)
      ..writeByte(19)
      ..write(obj.sucresPer100)
      ..writeByte(20)
      ..write(obj.fatSaturatedPer100)
      ..writeByte(21)
      ..write(obj.fatMonounsaturatedPer100)
      ..writeByte(22)
      ..write(obj.fatPolyunsaturatedPer100)
      ..writeByte(23)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
