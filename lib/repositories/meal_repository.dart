import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/meal.dart';
import '../services/date_service.dart';
import '../services/nutrition_snapshot_service.dart';
import 'package:collection/collection.dart';
import '../providers/common_providers.dart';


/// Repository 100% Hive
class MealRepository {
  final Box<Meal> _mealBox;
  MealRepository(
    this._mealBox);
  
  // ----------------------------------------------------------
  // 📅 Récupère les repas d'une semaine complète
  // ----------------------------------------------------------
  Future<Map<String, List<Meal>>> getMealsForWeek(DateTime weekStartDate) async {
    final Map<String, List<Meal>> weeklyMeals = {};

    // Prépare les 7 jours de la semaine
    for (int i = 0; i < 7; i++) {
      final date = weekStartDate.add(Duration(days: i));
      final key = DateService.formatStandard(date);
      weeklyMeals[key] = [];
    }

    for (final meal in _mealBox.values) {
      if (weeklyMeals.containsKey(meal.date)) {
        weeklyMeals[meal.date]!.add(meal);
      }
    }

    return weeklyMeals;
  }

  // ----------------------------------------------------------
  // 📌 Récupère les 300 repas les plus récents (tri par date + key)
  // ----------------------------------------------------------
  Future<List<Meal>> getAllRecentMeals() async {
    final list = _mealBox.values.toList();

    list.sort((a, b) {
      final cmp = b.date.compareTo(a.date);
      if (cmp != 0) return cmp;
      // fallback pour garantir un ordre stable
      return (b.key ?? 0).compareTo(a.key ?? 0);
    });

    return list.take(300).toList();
  }

  // ----------------------------------------------------------
  // 🍽️ Récupère tous les repas d'un type donné un jour donné
  // ----------------------------------------------------------
  Future<List<Meal>> getMealsForTypeAndDate(
      String mealType, String dateKey) async {
    return _mealBox.values
        .where((m) => m.date == dateKey && m.type == mealType)
        .toList();
  }

  // ----------------------------------------------------------
  // ⭐ Trouve les 15 derniers repas uniques d’un type (tri récence)
  // ----------------------------------------------------------
  Future<List<Meal>> getLastMealsByType(String mealType) async {
    final list = _mealBox.values
        .where((m) => m.type == mealType)
        .toList();

    list.sort((a, b) => b.date.compareTo(a.date));

    final seen = <String>{};
    final result = <Meal>[];

    for (final m in list) {
      final key = m.name.trim().toLowerCase();
      if (key.isEmpty) continue;
      if (seen.add(key)) {
        result.add(m);
        if (result.length >= 15) break;
      }
    }

    return result;
  }

  // ----------------------------------------------------------
  // ➕ Ajoute un repas
  // ----------------------------------------------------------
  Future<void> addMeal(Meal meal) async {
    await _mealBox.add(meal); 
  }

  // ----------------------------------------------------------
  // ✏️ Met à jour un repas existant (car Meal extends HiveObject)
  // ----------------------------------------------------------
  Future<void> updateMeal(Meal meal) async {
    await meal.save();
  }

  // ----------------------------------------------------------
  // ❌ Supprime un repas
  // ----------------------------------------------------------
  Future<void> deleteMeal(Meal meal) async {
    await meal.delete();
  }

  // ----------------------------------------------------------
  // 🔥 Custom food API → converti en Meal stocké en local
  // ----------------------------------------------------------
  Future<Meal> upsertCustomFoodFromApi({
    required String name,
    required double kcalPer100,
    required double proteinPer100,
    required double carbsPer100,
    required double fatPer100,

    required double fibersPer100,
    required double sucresPer100,
    required double saturatedFatPer100,
    required double polyunsaturatedFatPer100,
    required double monounsaturatedFatPer100,

    String? externalId,
    String? imageUrl,
    String source = 'api',
  }) async {
    final normalized = name.trim().toLowerCase();

    final existing = _mealBox.values
        .where((m) => m.name.trim().toLowerCase() == normalized && m.group == "custom")
        .cast<Meal?>()
        .firstOrNull;

    if (existing != null) {
      existing.kcalPer100 = kcalPer100;
      existing.proteinPer100 = proteinPer100;
      existing.carbsPer100 = carbsPer100;
      existing.fatPer100 = fatPer100;

      existing.fiberPer100 = fibersPer100;
      existing.sucresPer100 = sucresPer100;
      existing.fatSaturatedPer100 = saturatedFatPer100;
      existing.fatPolyunsaturatedPer100 = polyunsaturatedFatPer100;
      existing.fatMonounsaturatedPer100 = monounsaturatedFatPer100;

      await existing.save();
      return existing;
    }

    final today = DateService.formatStandard(DateTime.now());

    final meal = Meal(
      name: name,
      calories: kcalPer100, // base 100g
      protein: proteinPer100,
      carbs: carbsPer100,
      fat: fatPer100,
      quantity: 100,
      type: "Custom",
      date: today,

      fiber: fibersPer100,
      sucres: sucresPer100,
      fatSaturated: saturatedFatPer100,
      fatMonounsaturated: monounsaturatedFatPer100,
      fatPolyunsaturated: polyunsaturatedFatPer100,

      group: "custom",

      kcalPer100: kcalPer100,
      proteinPer100: proteinPer100,
      carbsPer100: carbsPer100,
      fatPer100: fatPer100,
      fiberPer100: fibersPer100,
      sucresPer100: sucresPer100,
      fatSaturatedPer100: saturatedFatPer100,
      fatMonounsaturatedPer100: monounsaturatedFatPer100,
      fatPolyunsaturatedPer100: polyunsaturatedFatPer100,
    );

    await _mealBox.add(meal);
    return meal;
  }

// Retourne tous les repas entre deux dates incluses
Future<List<Meal>> getMealsInRange(DateTime start, DateTime end) async {
    final s = DateService.formatStandard(start);
    final e = DateService.formatStandard(end);

    final meals = _mealBox.values.where((m) {
      final d = m.date; // déjà "yyyy-MM-dd"
      return d.compareTo(s) >= 0 && d.compareTo(e) <= 0;
    }).toList();

    meals.sort((a, b) {
      final da = DateService.parseStandard(a.date);
      final db = DateService.parseStandard(b.date);
      return da.compareTo(db);
    });

    return meals;
  }


  // ----------------------------------------------------------
  // 🔄 "Touch" = mise à jour de dernier usage (ici, on remet la date du jour)
  // ----------------------------------------------------------
  Future<void> touchCustomFood(Meal meal) async {
    meal.date = DateService.formatStandard(DateTime.now());
    await meal.save();
  }
}

// ----------------------------------------------------------
// 🔌 Providers Riverpod
// ----------------------------------------------------------


