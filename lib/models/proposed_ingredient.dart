// lib/models/proposed_ingredient.dart
class ProposedIngredient {
  final String name;

  /// Valeurs de référence pour 100 g
  final double kcalPer100;
  final double proteinPer100;
  final double carbsPer100;
  final double fatPer100;

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

  /// Le backend renvoie des totaux pour la quantité proposée.
  /// On convertit en valeurs /100g au parsing.
  factory ProposedIngredient.fromJson(Map<String, dynamic> j) {
    final q = ((j["quantity"] ?? 0) as num).toDouble().clamp(0.0, 1e9);
    final kcalTot = ((j["kcal"] ?? 0) as num).toDouble();
    final pTot    = ((j["protein"] ?? 0) as num).toDouble();
    final cTot    = ((j["carbs"] ?? 0) as num).toDouble();
    final fTot    = ((j["fat"] ?? 0) as num).toDouble();

    // évite division par zéro : si q==0, on met /100g à 0
    final safe = q > 0 ? q : 100.0;

    return ProposedIngredient(
      name: (j["name"] ?? "") as String,
      kcalPer100:   q > 0 ? (kcalTot / safe) * 100.0 : 0.0,
      proteinPer100:q > 0 ? (pTot    / safe) * 100.0 : 0.0,
      carbsPer100:  q > 0 ? (cTot    / safe) * 100.0 : 0.0,
      fatPer100:    q > 0 ? (fTot    / safe) * 100.0 : 0.0,
      quantity: q,
      confidence: ((j["confidence"] ?? 0.7) as num).toDouble(),
      unit: (j["unit"] ?? "g") as String,
      selected: true,
    );
  }
}
