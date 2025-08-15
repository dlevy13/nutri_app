//Utilitaires pour traitement de texte (normalisation, raccourcissement, etc.)
import 'package:hive/hive.dart';

part 'meal.g.dart'; 

// Fonction "assistante" privée pour convertir les nombres de manière sûre
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) {
    final cleanedString = value.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleanedString) ?? 0.0;
  }
  return 0.0;
}

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
  String type;

  @HiveField(6)
  String date;

  @HiveField(7)
  double quantity;

  @HiveField(8)
  String? firestoreId;

  Meal({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.type,
    required this.date,
    this.quantity = 100.0,
    this.firestoreId,
  });

  // ✅ CONSTRUCTEUR fromMap FINAL ET ROBUSTE
  factory Meal.fromMap(Map<String, dynamic> map, {String? id}) {
    final nutriments = map['nutriments'] as Map<String, dynamic>? ?? {};
    // ✅ On lit le nom et on vérifie s'il est vide
      String name = map['product_name'] as String? ?? map['name'] as String? ?? '';
      if (name.trim().isEmpty) {
        name = 'Aliment sans nom'; // Valeur par défaut si le nom est vide
      }
    return Meal(
      // Gère plusieurs noms de champs possibles
      name: name,
      // Utilise notre parseur sécurisé pour tous les champs numériques
      calories: _parseDouble(nutriments['energy-kcal_100g'] ?? map['calories']),
      protein: _parseDouble(nutriments['proteins_100g'] ?? map['protein']),
      carbs: _parseDouble(nutriments['carbohydrates_100g'] ?? map['carbs']),
      fat: _parseDouble(nutriments['fat_100g'] ?? map['fat']),
      quantity: _parseDouble(map['quantity']),
      
      // Gère les champs String avec des valeurs par défaut
      type: map['type'] as String? ?? '',
      date: map['date'] as String? ?? '',
      firestoreId: id ?? map['firestoreId'] as String?, 
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'type': type,
      'date': date,
      'quantity': quantity,
    };
  }
}