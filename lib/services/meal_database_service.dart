import 'package:hive/hive.dart';
import '../models/meal.dart';
import '../log.dart';
import 'package:intl/intl.dart';
//refonte
class MealDatabaseService {
  final Box<Meal> _mealBox;

  MealDatabaseService(this._mealBox);

  /// Convertit une date vers format ISO `yyyy-MM-dd`
  String _normalizeToISO(String dateStr) {
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) return dateStr;

    final parts = dateStr.split('/');
    if (parts.length == 3) {
      final day = parts[0].padLeft(2, '0');
      final month = parts[1].padLeft(2, '0');
      final year = parts[2];
      return "$year-$month-$day";
    }

    return dateStr;
  }

  // --------------------------------------------------------------------
  // 🔵 AJOUTER UN REPAS (version locale uniquement)
  // --------------------------------------------------------------------

  Future<void> addMeal({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double quantity,
    required String mealType,
    required String date,

    double? fiber,
    double? sugars,
    double? fatSaturated,
    double? fatMonounsaturated,
    double? fatPolyunsaturated,

    double? kcalPer100,
    double? proteinPer100,
    double? carbsPer100,
    double? fatPer100,
    double? fiberPer100,
    double? sugarsPer100,
    double? fatSaturatedPer100,
    double? fatMonounsaturatedPer100,
    double? fatPolyunsaturatedPer100,

    String? group,
  }) async {
    final isoDate = _normalizeToISO(date);

    final meal = Meal(
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      quantity: quantity,
      type: mealType,
      date: isoDate,

      // totaux
      fiber: fiber,
      sucres: sugars,
      fatSaturated: fatSaturated,
      fatMonounsaturated: fatMonounsaturated,
      fatPolyunsaturated: fatPolyunsaturated,

      // per 100 g
      kcalPer100: kcalPer100,
      proteinPer100: proteinPer100,
      carbsPer100: carbsPer100,
      fatPer100: fatPer100,
      fiberPer100: fiberPer100,
      sucresPer100: sugarsPer100,
      fatSaturatedPer100: fatSaturatedPer100,
      fatMonounsaturatedPer100: fatMonounsaturatedPer100,
      fatPolyunsaturatedPer100: fatPolyunsaturatedPer100,

      group: group,
    );

    await _mealBox.add(meal);
    logger.d("📦 Repas ajouté LOCAL : ${meal.name}");
  }

  Future<void> addCustomFood(Meal meal) async {
    await _mealBox.add(meal);
    logger.d("📦 Aliment custom ajouté LOCAL : ${meal.name}");
  }

  // --------------------------------------------------------------------
  // 🔴 SUPPRESSION & RESET
  // --------------------------------------------------------------------

  Future<void> deleteMealAt(int index) async {
    await _mealBox.deleteAt(index);
  }

  Future<void> resetMeals() async {
    await _mealBox.clear();
  }

  Future<void> deleteDatabaseFile() async {
    await _mealBox.deleteFromDisk();
  }

  // --------------------------------------------------------------------
  // 🔍 LECTURE
  // --------------------------------------------------------------------

  Future<List<Meal>> getMeals({
    required String mealType,
    required String date,
  }) async {
    final iso = _normalizeToISO(date);
    return _mealBox.values
        .where((m) => m.type == mealType && m.date == iso)
        .toList();
  }

  Future<List<Meal>> getMealsForDate(String date) async {
    final iso = _normalizeToISO(date);
    return _mealBox.values.where((m) => m.date == iso).toList();
  }

  Future<List<Meal>> getMealsByDateAndType(String date, String type) async {
    final iso = _normalizeToISO(date);
    return _mealBox.values
        .where((m) => m.date == iso && m.type == type)
        .toList();
  }

  Future<List<String>> getCustomFoods() async {
    return _mealBox.values.map((m) => m.name.trim()).toSet().toList();
  }

  Future<List<Meal>> searchFoods(String query) async {
    final q = query.toLowerCase();
    return _mealBox.values
        .where((m) => m.name.toLowerCase().contains(q))
        .toList();
  }

  // --------------------------------------------------------------------
  // 🔥 Derniers repas utilisés (type pour suggestions)
  // --------------------------------------------------------------------

  Future<List<Meal>> getMostFrequentMealsByType(
    String mealType, {
    int limit = 15,
  }) async {
    final items = _mealBox.values.where((m) => m.type == mealType).toList();

    items.sort((a, b) => b.date.compareTo(a.date));

    final seen = <String>{};
    final result = <Meal>[];

    for (final m in items) {
      final key = _normalizeName(m.name);
      if (seen.add(key)) {
        result.add(m);
        if (result.length >= limit) break;
      }
    }

    return result;
  }

  String _normalizeName(String s) {
    var t = s.trim().toLowerCase();
    const withAccents = 'àâäáãåçéèêëíìîïñóòôöõúùûüŷýÿœæ';
    const noAccents = 'aaaaaaceeeeiiiinooooouuuuyyyoeae';

    for (var i = 0; i < withAccents.length; i++) {
      t = t.replaceAll(withAccents[i], noAccents[i]);
    }

    t = t.replaceAll(RegExp(r'[^\w\s]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ');

    return t;
  }

  // --------------------------------------------------------------------
  // 🔵 Repas de la semaine
  // --------------------------------------------------------------------

  Future<Map<String, List<Meal>>> getMealsForTheWeek() async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));

    final Map<String, List<Meal>> out = {};

    for (int i = 0; i < 7; i++) {
      final d = monday.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(d);

      out[dateStr] =
          _mealBox.values.where((m) => m.date == dateStr).toList();
    }

    return out;
  }
}
