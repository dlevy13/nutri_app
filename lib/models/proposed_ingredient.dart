// lib/models/proposed_ingredient.dart
class ProposedIngredient {
  final String name;

  /// Valeurs de référence pour 100 g
  final double kcalPer100;
  final double proteinPer100;
  final double carbsPer100;
  final double fatPer100;
  // ✅ AJOUT : Nouveaux champs de nutriments /100g
  final double fibersPer100;
  final double saturatedFatPer100;
  final double polyunsaturatedFatPer100;
  final double monounsaturatedFatPer100;

  /// Quantité courante (en g) ajustable par l’utilisateur
  double quantity;

  /// Confiance et unité d’origine
  final double confidence;
  final String unit;

  /// Sélection dans l’UI
  bool selected;

  ProposedIngredient({
    required this.name,
    required this.kcalPer100,
    required this.proteinPer100,
    required this.carbsPer100,
    required this.fatPer100,
    // ✅ AJOUT : Nouveaux paramètres au constructeur
    required this.fibersPer100,
    required this.saturatedFatPer100,
    required this.polyunsaturatedFatPer100,
    required this.monounsaturatedFatPer100,
    required this.quantity,
    required this.confidence,
    this.unit = "g",
    this.selected = true,
  });

  /// Getters calculés selon la quantité
  double get kcal   => (kcalPer100   / 100.0) * quantity;
  double get protein=> (proteinPer100/ 100.0) * quantity;
  double get carbs  => (carbsPer100  / 100.0) * quantity;
  double get fat    => (fatPer100    / 100.0) * quantity;
  // ✅ AJOUT : Getters pour les nouveaux champs
  double get fibers   => (fibersPer100    / 100.0) * quantity;
  double get saturatedFat => (saturatedFatPer100 / 100.0) * quantity;
  double get polyunsaturatedFat => (polyunsaturatedFatPer100 / 100.0) * quantity;
  double get monounsaturatedFat => (monounsaturatedFatPer100 / 100.0) * quantity;

  /// Le backend renvoie des totaux pour la quantité proposée.
  /// On convertit en valeurs /100g au parsing.
  factory ProposedIngredient.fromJson(Map<String, dynamic> j) {
    final q = ((j["quantity"] ?? 0) as num).toDouble().clamp(0.0, 1e9);
    final kcalTot = ((j["kcal"] ?? 0) as num).toDouble();
    final pTot    = ((j["protein"] ?? 0) as num).toDouble();
    final cTot    = ((j["carbs"] ?? 0) as num).toDouble();
    final fTot    = ((j["fat"] ?? 0) as num).toDouble();
    // ✅ AJOUT : Lecture des totaux pour les nouveaux champs
    final fbrTot  = ((j["fibers"] ?? 0) as num).toDouble();
    final satTot  = ((j["saturated_fat"] ?? 0) as num).toDouble();
    final polyTot = ((j["polyunsaturated_fat"] ?? 0) as num).toDouble();
    final monoTot = ((j["monounsaturated_fat"] ?? 0) as num).toDouble();

    // évite division par zéro : si q==0, on met /100g à 0
    final safe = q > 0 ? q : 100.0;

    return ProposedIngredient(
      name: (j["name"] ?? "") as String,
      kcalPer100:   q > 0 ? (kcalTot / safe) * 100.0 : 0.0,
      proteinPer100:q > 0 ? (pTot    / safe) * 100.0 : 0.0,
      carbsPer100:  q > 0 ? (cTot    / safe) * 100.0 : 0.0,
      fatPer100:    q > 0 ? (fTot    / safe) * 100.0 : 0.0,
      // ✅ AJOUT : Calcul des valeurs /100g pour les nouveaux champs
      fibersPer100: q > 0 ? (fbrTot  / safe) * 100.0 : 0.0,
      saturatedFatPer100: q > 0 ? (satTot  / safe) * 100.0 : 0.0,
      polyunsaturatedFatPer100: q > 0 ? (polyTot / safe) * 100.0 : 0.0,
      monounsaturatedFatPer100: q > 0 ? (monoTot / safe) * 100.0 : 0.0,
      quantity: q,
      confidence: ((j["confidence"] ?? 0.7) as num).toDouble(),
      unit: (j["unit"] ?? "g") as String,
      selected: true,
    );
  }
}
