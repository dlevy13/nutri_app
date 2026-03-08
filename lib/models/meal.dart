import 'package:hive/hive.dart';

part 'meal.g.dart';
//refonte
/// Parse sûr → double (gère num, string "12,3", null)
double _parseDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
}

@HiveType(typeId: 0)
class Meal extends HiveObject {
  // -----------------------------------------------------
  // 🟢 Champs de base (portion)
  // -----------------------------------------------------

  @HiveField(0)
  String name;

  @HiveField(1)
  double calories; // total pour la portion

  @HiveField(2)
  double protein;

  @HiveField(3)
  double carbs;

  @HiveField(4)
  double fat;

  /// Quantité de la portion en grammes (ex: 100, 45, etc.)
  @HiveField(5)
  double quantity;

  /// Type / catégorie (ex: petit-déjeuner, collation...)
  @HiveField(6)
  String type;

  /// Date au format "YYYY-MM-DD"
  @HiveField(7)
  String date;

  // -----------------------------------------------------
  // 🟣 Totaux par portion (champ "brut")
  // -----------------------------------------------------

  /// Fibres totales pour la portion
  @HiveField(8)
  double? fiber;

  /// Sucres totaux pour la portion
  @HiveField(9)
  double? sucres;

  /// Lipides saturés (portion)
  @HiveField(10)
  double? fatSaturated;

  /// Lipides mono-insaturés (portion)
  @HiveField(11)
  double? fatMonounsaturated;

  /// Lipides poly-insaturés (portion)
  @HiveField(12)
  double? fatPolyunsaturated;

  /// Optionnel : pour grouper visuellement ou logiquement
  @HiveField(13)
  String? group;

  // -----------------------------------------------------
  // 🔵 Valeurs par 100 g (si connues)
  // -----------------------------------------------------

  @HiveField(14)
  double? kcalPer100;

  @HiveField(15)
  double? proteinPer100;

  @HiveField(16)
  double? carbsPer100;

  @HiveField(17)
  double? fatPer100;

  @HiveField(18)
  double? fiberPer100;

  @HiveField(19)
  double? sucresPer100;

  @HiveField(20)
  double? fatSaturatedPer100;

  @HiveField(21)
  double? fatMonounsaturatedPer100;

  @HiveField(22)
  double? fatPolyunsaturatedPer100;

  @HiveField(23)
  String? timestamp; 
  // Format ISO "2025-02-03T12:45:00"
  // Laisse null pour compat anciens repas

  Meal({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.quantity,
    required this.type,
    required this.date,
    this.fiber,
    this.sucres,
    this.fatSaturated,
    this.fatMonounsaturated,
    this.fatPolyunsaturated,
    this.group,
    this.kcalPer100,
    this.proteinPer100,
    this.carbsPer100,
    this.fatPer100,
    this.fiberPer100,
    this.sucresPer100,
    this.fatSaturatedPer100,
    this.fatMonounsaturatedPer100,
    this.fatPolyunsaturatedPer100,
    this.timestamp,
  });
}

// -----------------------------------------------------
// 🔥 Calculs automatiques /100 g
// -----------------------------------------------------

extension MealPer100X on Meal {
  double _valOrAuto(double? explicit, double total) {
    if (explicit != null && explicit > 0) return explicit;
    if (quantity > 0) return (total * 100.0) / quantity;
    return 0.0;
  }

  double get kcalPer100X => _valOrAuto(kcalPer100, calories);
  double get proteinPer100X => _valOrAuto(proteinPer100, protein);
  double get carbsPer100X => _valOrAuto(carbsPer100, carbs);
  double get fatPer100X => _valOrAuto(fatPer100, fat);
  double get fiberPer100X => _valOrAuto(fiberPer100, _parseDouble(fiber));
  double get sucresPer100X => _valOrAuto(sucresPer100, _parseDouble(sucres));
  double get fatSaturatedPer100X =>
      _valOrAuto(fatSaturatedPer100, _parseDouble(fatSaturated));
  double get fatMonounsaturatedPer100X =>
      _valOrAuto(fatMonounsaturatedPer100, _parseDouble(fatMonounsaturated));
  double get fatPolyunsaturatedPer100X =>
      _valOrAuto(fatPolyunsaturatedPer100, _parseDouble(fatPolyunsaturated));

  /// Total insaturés (portion)
  double get fatUnsaturated =>
      _parseDouble(fatMonounsaturated) + _parseDouble(fatPolyunsaturated);

  /// Total insaturés /100 g
  double get fatUnsaturatedPer100X {
    final mono = fatMonounsaturatedPer100;
    final poly = fatPolyunsaturatedPer100;
    if ((mono ?? 0) > 0 || (poly ?? 0) > 0) {
      return (mono ?? 0) + (poly ?? 0);
    }
    // fallback: lipides totaux - saturés
    final v = fatPer100X - fatSaturatedPer100X;
    return v > 0 ? v : 0.0;
  }
}

// -----------------------------------------------------
// 🧩 Aliases de compat (pour ne rien casser ailleurs)
// -----------------------------------------------------

extension MealCompatAliases on Meal {
  // portion
  double? get fibres => fiber;
  set fibres(double? v) => fiber = v;

  double? get fibers => fiber;
  set fibers(double? v) => fiber = v;

  double? get sugars => sucres;
  set sugars(double? v) => sucres = v;

  // /100g
  double? get fibersPer100 => fiberPer100;
  set fibersPer100(double? v) => fiberPer100 = v;

  double? get sugarsPer100 => sucresPer100;
  set sugarsPer100(double? v) => sucresPer100 = v;

  double get fibersPer100X => fiberPer100X;
  double get sugarsPer100X => sucresPer100X;
  double get saturatedFatPer100X => fatSaturatedPer100X;
  double get polyunsaturatedFatPer100X => fatPolyunsaturatedPer100X;
  double get monounsaturatedFatPer100X => fatMonounsaturatedPer100X;
}
