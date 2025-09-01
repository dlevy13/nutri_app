import 'package:hive/hive.dart';

part 'meal.g.dart';

/// Parse sûr → double (gère num, string "12,3", null)
double _parseDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
}

/// Parse optionnel → double? (retourne null si non convertible)
double? _parseDoubleOpt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.'));
}

@HiveType(typeId: 0)
class Meal extends HiveObject {
  // ⚠️ Conserve EXACTEMENT ces indices si tu as déjà des données Hive
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

  @HiveField(8)
  String? firestoreId;

  // --- Nouveaux champs /100 g (indices ajoutés) ---
  @HiveField(50)
  double? kcalPer100;

  @HiveField(51)
  double? proteinPer100;

  @HiveField(52)
  double? carbsPer100;

  @HiveField(53)
  double? fatPer100;

  // --- Lipides détaillés & fibres (/100 g) ---
  @HiveField(20)
  double? fiberPer100;
  @HiveField(21)
  double? fatSaturatedPer100;
  @HiveField(22)
  double? fatMonounsaturatedPer100;
  @HiveField(23)
  double? fatPolyunsaturatedPer100;

  // --- Valeurs par portion (totaux, selon quantity) ---
  @HiveField(24)
  double? fiber;
  @HiveField(25)
  double? fatSaturated;
  @HiveField(26)
  double? fatMonounsaturated;
  @HiveField(27)
  double? fatPolyunsaturated;

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
    this.kcalPer100,
    this.proteinPer100,
    this.carbsPer100,
    this.fatPer100,
    this.fiberPer100,
    this.fatSaturatedPer100,
    this.fatMonounsaturatedPer100,
    this.fatPolyunsaturatedPer100,
    this.fiber,
    this.fatSaturated,
    this.fatMonounsaturated,
    this.fatPolyunsaturated,
  });

  /// fromMap robuste (Firestore / API normalisée type OFF)
  factory Meal.fromMap(Map<String, dynamic> map, {String? id}) {
    final nutr = map['nutriments'] as Map<String, dynamic>? ?? const {};

    // Nom : product_name > name > défaut
    String name = ((map['product_name'] ?? map['name']) as String?)?.trim() ?? '';
    if (name.isEmpty) name = 'Aliment sans nom';

    // kcal: plusieurs clés possibles ; fallback kJ → kcal
    double kcal = _parseDouble(nutr['energy-kcal_100g'] ?? map['calories']);
    if (kcal == 0.0) {
      final kj = _parseDouble(nutr['energy-kj_100g'] ?? map['energy-kj_100g'] ?? nutr['energy_100g'] ?? map['energy_100g']);
      if (kj > 0) kcal = kj / 4.184;
    }

    return Meal(
      name: name,
      calories: kcal,
      protein:  _parseDouble(nutr['proteins_100g'] ?? map['protein']),
      carbs:    _parseDouble(nutr['carbohydrates_100g'] ?? map['carbs']),
      fat:      _parseDouble(nutr['fat_100g'] ?? map['fat']),

      // ✅ totaux "par portion" (si fournis côté Firestore/JSON)
      fiber:               _parseDouble(nutr['fiber_100g'] ?? map['fiber'] ?? map['fibres'] ?? map['dietary_fiber']),
      fatSaturated:        _parseDouble(nutr['saturated-fat_100g'] ?? map['fatSaturated'] ?? map['saturated_fat'] ?? map['saturated']),
      fatMonounsaturated:  _parseDouble(nutr['monounsaturated-fat_100g'] ?? map['fatMonounsaturated'] ?? map['monounsaturated'] ?? map['mono_fat']),
      fatPolyunsaturated:  _parseDouble(nutr['polyunsaturated-fat_100g'] ?? map['fatPolyunsaturated'] ?? map['polyunsaturated'] ?? map['poly_fat']),

      quantity: _parseDouble(map['quantity']),

      // ✅ champs /100 g : Firestore si présent, sinon fallback nutriments
      kcalPer100:               _parseDoubleOpt(map['kcalPer100']        ?? nutr['energy-kcal_100g']),
      proteinPer100:            _parseDoubleOpt(map['proteinPer100']     ?? nutr['proteins_100g']),
      carbsPer100:              _parseDoubleOpt(map['carbsPer100']       ?? nutr['carbohydrates_100g']),
      fatPer100:                _parseDoubleOpt(map['fatPer100']         ?? nutr['fat_100g']),
      fiberPer100:              _parseDoubleOpt(map['fiberPer100']       ?? map['fibresPer100'] ?? map['dietary_fiber_per_100'] ?? nutr['fiber_100g']),
      fatSaturatedPer100:       _parseDoubleOpt(map['fatSaturatedPer100']?? map['saturated_fat_per_100'] ?? map['saturated-fat_per_100'] ?? nutr['saturated-fat_100g']),
      fatMonounsaturatedPer100: _parseDoubleOpt(map['fatMonounsaturatedPer100'] ?? map['monounsaturated_per_100'] ?? map['fat_monounsaturated_per_100'] ?? nutr['monounsaturated-fat_100g']),
      fatPolyunsaturatedPer100: _parseDoubleOpt(map['fatPolyunsaturatedPer100'] ?? map['polyunsaturated_per_100'] ?? map['fat_polyunsaturated_per_100'] ?? nutr['polyunsaturated-fat_100g']),

      // strings
      type: (map['type'] as String?) ?? '',
      date: (map['date'] as String?) ?? '',
      firestoreId: id ?? map['firestoreId'] as String?,
    );
  }

  /// toMap → sérialisation Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'calories': calories,     // totaux pour la qty
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'quantity': quantity,     // en grammes
      'type': type,
      'date': date,
      if (firestoreId != null) 'firestoreId': firestoreId,

      // totaux "par portion"
      'fiber': fiber,
      'fatSaturated': fatSaturated,
      'fatMonounsaturated': fatMonounsaturated,
      'fatPolyunsaturated': fatPolyunsaturated,
      // pratique: lipides insaturés total (portion)
      'fatUnsaturated': (_parseDouble(fatMonounsaturated) + _parseDouble(fatPolyunsaturated)),

      // champs /100 g
      'kcalPer100': kcalPer100,
      'proteinPer100': proteinPer100,
      'carbsPer100': carbsPer100,
      'fatPer100': fatPer100,
      'fiberPer100': fiberPer100,
      'fatSaturatedPer100': fatSaturatedPer100,
      'fatMonounsaturatedPer100': fatMonounsaturatedPer100,
      'fatPolyunsaturatedPer100': fatPolyunsaturatedPer100,
    };
  }
}

/// Getters affichage : garantissent des valeurs **/100 g**
extension MealPer100X on Meal {
  double get kcalPer100X =>
      (kcalPer100 != null && kcalPer100! > 0)
          ? kcalPer100!
          : (quantity > 0 ? (calories * 100.0) / quantity : 0.0);

  double get proteinPer100X =>
      (proteinPer100 != null && proteinPer100! > 0)
          ? proteinPer100!
          : (quantity > 0 ? (protein * 100.0) / quantity : 0.0);

  double get carbsPer100X =>
      (carbsPer100 != null && carbsPer100! > 0)
          ? carbsPer100!
          : (quantity > 0 ? (carbs * 100.0) / quantity : 0.0);

  double get fatPer100X =>
      (fatPer100 != null && fatPer100! > 0)
          ? fatPer100!
          : (quantity > 0 ? (fat * 100.0) / quantity : 0.0);

  double get fiberPer100X =>
      (fiberPer100 != null && fiberPer100! > 0)
          ? fiberPer100!
          : (quantity > 0 ? (_parseDouble(fiber) * 100.0) / quantity : 0.0);

  double get fatSaturatedPer100X =>
      (fatSaturatedPer100 != null && fatSaturatedPer100! > 0)
          ? fatSaturatedPer100!
          : (quantity > 0 ? (_parseDouble(fatSaturated) * 100.0) / quantity : 0.0);

  double get fatMonounsaturatedPer100X =>
      (fatMonounsaturatedPer100 != null && fatMonounsaturatedPer100! > 0)
          ? fatMonounsaturatedPer100!
          : (quantity > 0 ? (_parseDouble(fatMonounsaturated) * 100.0) / quantity : 0.0);

  double get fatPolyunsaturatedPer100X =>
      (fatPolyunsaturatedPer100 != null && fatPolyunsaturatedPer100! > 0)
          ? fatPolyunsaturatedPer100!
          : (quantity > 0 ? (_parseDouble(fatPolyunsaturated) * 100.0) / quantity : 0.0);

  /// Total insaturés (portion)
  double get fatUnsaturated =>
      _parseDouble(fatMonounsaturated) + _parseDouble(fatPolyunsaturated);

  /// Total insaturés /100 g (fallback si mono/poly absents)
  double get fatUnsaturatedPer100X {
    final mono = fatMonounsaturatedPer100;
    final poly = fatPolyunsaturatedPer100;
    if ((mono ?? 0) > 0 || (poly ?? 0) > 0) {
      return (mono ?? 0) + (poly ?? 0);
    }
    final v = fatPer100X - fatSaturatedPer100X;
    return v > 0 ? v : 0.0;
  }
}

/// Alias de compat pour l'ancien code (lecture/écriture)
extension MealCompatAliases on Meal {
  // portion
  double? get fibres => fiber;
  set fibres(double? v) => fiber = v;

  double? get fibers => fiber;
  set fibers(double? v) => fiber = v;

  double? get saturatedFat => fatSaturated;
  set saturatedFat(double? v) => fatSaturated = v;

  double? get polyunsaturatedFat => fatPolyunsaturated;
  set polyunsaturatedFat(double? v) => fatPolyunsaturated = v;

  double? get monounsaturatedFat => fatMonounsaturated;
  set monounsaturatedFat(double? v) => fatMonounsaturated = v;

  // /100 g alias & raccourcis UI
  double? get fibersPer100 => fiberPer100;
  set fibersPer100(double? v) => fiberPer100 = v;

  double get fibersPer100X => fiberPer100X;
  double get saturatedFatPer100X => fatSaturatedPer100X;
  double get polyunsaturatedFatPer100X => fatPolyunsaturatedPer100X;
  double get monounsaturatedFatPer100X => fatMonounsaturatedPer100X;
}
