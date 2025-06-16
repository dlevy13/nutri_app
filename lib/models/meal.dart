//Utilitaires pour traitement de texte (normalisation, raccourcissement, etc.)

import 'package:hive/hive.dart';

part 'meal.g.dart';

@HiveType(typeId: 0)
class Meal extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  double calories;

  @HiveField(2)
  double protein;

  @HiveField(3)
  double carbs;

  @HiveField(4)
  double fat;

  @HiveField(5)
  double quantity;

  @HiveField(6)
  String type;

  @HiveField(7)
  String date;

  Meal({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.quantity,
    required this.type,
    required this.date,
  });

  factory Meal.fromMap(Map<String, dynamic> map) {
    return Meal(
      name: map['name'] ?? '',
      calories: (map['calories'] ?? 0).toDouble(),
      protein: (map['protein'] ?? 0).toDouble(),
      carbs: (map['carbs'] ?? 0).toDouble(),
      fat: (map['fat'] ?? 0).toDouble(),
      quantity: (map['quantity'] ?? 1).toDouble(),
      type: map['type'] ?? '',
      date: map['date'] ?? '',
    );
  }
  Map<String, dynamic> toMap() {
  return {
    'name': name,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'quantity': quantity,
    'type': type,
    'date': date,
  };
}

}

