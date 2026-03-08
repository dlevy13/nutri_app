// fonctions.dart
import 'package:characters/characters.dart';
import '../models/meal.dart';

/// Normalise une chaîne (pour recherches, comparaisons, etc.)
String normalize(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r"œ"), "oe")
      .replaceAll(RegExp(r"[àáâãäå]"), "a")
      .replaceAll(RegExp(r"[èéêë]"), "e")
      .replaceAll(RegExp(r"[ìíîï]"), "i")
      .replaceAll(RegExp(r"[òóôõö]"), "o")
      .replaceAll(RegExp(r"[ùúûü]"), "u")
      .replaceAll(RegExp(r"[ç]"), "c")
      .replaceAll(RegExp(r"[ñ]"), "n")
      .replaceAll(RegExp(r"[^a-z0-9\s]"), "") // supprime caractères spéciaux
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// Raccourcit un nom à N mots (utile pour l’affichage).
String getShortenedName(String name, {int wordCount = 5}) {
  return name.split(' ').take(wordCount).join(' ');
}

// ============================================================================
//  ANALYSE LOCALE DES REPAS (fallback utilisé par AIManager)
// ============================================================================

/// 🔹 Fallback local : analyse avancée sans IA
String _fallbackLocalAnalysis(Map<String, dynamic> data) {
  double totalCal = 0, totalProt = 0, totalCarb = 0, totalFat = 0;

  // 🔸 Extraction des données selon format
  if (data.containsKey("jour")) {
    final jour = data["jour"];
    if (jour is Map && jour["repas"] is List) {
      for (var meal in (jour["repas"] as List)) {
        if (meal is Map) {
          totalCal += (meal["calories"] ?? 0) * 1.0;
          totalProt += (meal["protein"] ?? 0) * 1.0;
          totalCarb += (meal["carbs"] ?? 0) * 1.0;
          totalFat += (meal["fat"] ?? 0) * 1.0;
        }
      }
    }
  } else if (data.containsKey("semaine")) {
    final semaine = data["semaine"];
    if (semaine is List) {
      for (var day in semaine) {
        if (day is Map && day["totaux"] is Map) {
          final totaux = day["totaux"] as Map;
          totalCal += (totaux["calories"] ?? 0) * 1.0;
          totalProt += (totaux["proteins"] ?? 0) * 1.0;
          totalCarb += (totaux["carbs"] ?? 0) * 1.0;
          totalFat += (totaux["fats"] ?? 0) * 1.0;
        }
      }
    }
  }

  if (totalCal == 0) return "⚠️ Aucun repas enregistré, analyse impossible.";

  // 🔸 Calcul des ratios (% des calories totales)
  final protPct = ((totalProt * 4) / totalCal) * 100;
  final carbPct = ((totalCarb * 4) / totalCal) * 100;
  final fatPct  = ((totalFat  * 9) / totalCal) * 100;

  String interpretation = "📊 **Analyse locale des repas :**\n";
  interpretation +=
      "- Calories : ${totalCal.toStringAsFixed(0)} kcal\n"
      "- Répartition : Prot. ${protPct.toStringAsFixed(1)}% | "
      "Gluc. ${carbPct.toStringAsFixed(1)}% | "
      "Lip. ${fatPct.toStringAsFixed(1)}%\n\n";

  // 🔸 Observations simples
  final List<String> observations = [];

  if (protPct < 15) {
    observations.add("🔹 Apport en protéines trop faible pour soutenir la masse musculaire.");
  } else if (protPct > 30) {
    observations.add("🔹 Protéines très élevées, attention à l’excès.");
  }

  if (carbPct > 60) {
    observations.add("🔹 Glucides élevés, privilégie des sources complexes.");
  } else if (carbPct < 40) {
    observations.add("🔹 Glucides bas, risque de manque d’énergie.");
  }

  if (fatPct > 35) {
    observations.add("🔹 Lipides élevés, surveille les graisses saturées.");
  } else if (fatPct < 20) {
    observations.add("🔹 Lipides un peu bas, veille à consommer de bonnes graisses.");
  }

  if (observations.isEmpty) {
    observations.add("✅ Ton profil nutritionnel est globalement bien équilibré.");
  }

  // 🔸 Conseils pratiques
  const List<String> conseils = [
    "🥗 Varie tes sources de protéines (viande maigre, poisson, œufs, légumineuses).",
    "🥑 Favorise les bonnes graisses (huile d’olive, noix, graines, avocat).",
    "🍞 Choisis des glucides complexes (riz complet, patate douce, flocons d’avoine).",
  ];

  interpretation += "**Observations :**\n";
  for (final o in observations) {
    interpretation += "- $o\n";
  }

  interpretation += "\n**Conseils pratiques :**\n";
  for (final c in conseils) {
    interpretation += "- $c\n";
  }

  return interpretation;
}

/// ✅ Fonction utilisée par AIManager comme fallback local
Future<String> analyzeMealsLocal(Map<String, dynamic> mealsData) async {
  return _fallbackLocalAnalysis(mealsData);
}

// ============================================================================
//  EXTENSIONS / OUTILS TEXTE
// ============================================================================

extension StringCap on String {
  /// Coupe une string à [max] caractères, avec "…" si trop long.
  String cap({int max = 30}) {
    final t = trim();
    final chars = t.characters;
    return (chars.length <= max) ? t : chars.take(max).toString() + '…';
  }
}

// ============================================================================
//  NORMALISATION DES MACROS (/100 g + portion)
// ============================================================================

/// Structure pour représenter les macros normalisées /100 g
class Macros100 {
  final double kcal;
  final double pro;
  final double carb;
  final double fat;

  const Macros100(this.kcal, this.pro, this.carb, this.fat);
}

double _d(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return 0.0;
}

/// Remonte toujours à des macros /100 g depuis :— un `Meal`
/// — ou une `Map` compatible (par ex. venant d’un JSON local)
Macros100 per100From(dynamic foodData) {
  // Cas A : c’est un Meal (Hive)
  if (foodData is Meal) {
    final qty  = foodData.quantity;
    final kcal = _d(foodData.calories);
    final pro  = _d(foodData.protein);
    final carb = _d(foodData.carbs);
    final fat  = _d(foodData.fat);

    if (qty > 0 && qty != 100) {
      final f = 100.0 / qty;
      return Macros100(kcal * f, pro * f, carb * f, fat * f);
    }
    return Macros100(kcal, pro, carb, fat); // déjà en /100 g
  }

  // Cas B : c’est une Map (JSON local, etc.)
  final m = foodData as Map<String, dynamic>;

  // Si déjà normalisé /100 g
  final bool hasPerFlag100 = (m['per'] == 100);
  final bool hasPer100Keys = m.containsKey('kcalPer100') ||
      m.containsKey('proteinPer100') ||
      m.containsKey('carbsPer100') ||
      m.containsKey('fatPer100');

  if (hasPerFlag100 || hasPer100Keys) {
    final kcal = hasPer100Keys ? _d(m['kcalPer100']) : _d(m['calories']);
    final pro  = hasPer100Keys ? _d(m['proteinPer100']) : _d(m['protein']);
    final carb = hasPer100Keys ? _d(m['carbsPer100'])   : _d(m['carbs']);
    final fat  = hasPer100Keys ? _d(m['fatPer100'])     : _d(m['fat']);
    return Macros100(kcal, pro, carb, fat);
  }

  // Sinon : valeurs pour une portion → remonter en /100 g
  final qty  = _d(m['quantity']);
  final kcal = _d(m['calories']);
  final pro  = _d(m['protein']);
  final carb = _d(m['carbs']);
  final fat  = _d(m['fat']);

  if (qty > 0 && qty != 100) {
    final f = 100.0 / qty;
    return Macros100(kcal * f, pro * f, carb * f, fat * f);
  }
  return Macros100(kcal, pro, carb, fat);
}

/// Calcule les macros pour une portion choisie à partir du /100 g
Macros100 portionFromPer100(Macros100 p100, double grams) {
  final f = grams / 100.0;
  return Macros100(
    p100.kcal * f,
    p100.pro  * f,
    p100.carb * f,
    p100.fat  * f,
  );
}
