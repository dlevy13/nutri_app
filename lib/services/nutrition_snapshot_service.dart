import 'package:flutter/foundation.dart';

import '../repositories/meal_repository.dart';
import '../repositories/daily_calories_repository.dart';
import '../repositories/daily_snapshot_remote_repository.dart';
import '../models/day_snapshot.dart';
import '../models/meal.dart';

/// Orchestration métier :
/// - Hive (Meal) = source de vérité
/// - Recalcule les totaux pour une date
/// - Met à jour le cache local (DailyCalories)
/// - Push le snapshot vers Supabase (DaySnapshot)
class NutritionSnapshotService {
  final MealRepository _mealRepo;
  final DailyCaloriesRepository _dailyCaloriesRepo;
  final DailySnapshotRemoteRepository _remoteRepo;

  NutritionSnapshotService(
    this._mealRepo,
    this._dailyCaloriesRepo,
    this._remoteRepo,
  );

  /// Point d’entrée UNIQUE à appeler après add / update / delete d’un Meal
  Future<void> recomputeAndSyncForDate(String dateKey) async {
    try {
      // ------------------------------------------------------------------
      // 1) Récupérer tous les meals du jour depuis Hive
      // ------------------------------------------------------------------
      final meals = await _mealsForDate(dateKey);

      // ------------------------------------------------------------------
      // 2) Recalculer les totaux alimentaires
      // ------------------------------------------------------------------
      double calories = 0;
      double protein = 0;
      double carbs = 0;
      double fat = 0;
      double fiber = 0;
      double sugars = 0;
      double fatSat = 0;
      double fatMono = 0;
      double fatPoly = 0;

      for (final m in meals) {
        calories += m.calories;
        protein += m.protein;
        carbs += m.carbs;
        fat += m.fat;

        fiber += (m.fiber ?? 0);
        sugars += (m.sucres ?? 0);

        fatSat += (m.fatSaturated ?? 0);
        fatMono += (m.fatMonounsaturated ?? 0);
        fatPoly += (m.fatPolyunsaturated ?? 0);
      }

      // ------------------------------------------------------------------
      // 3) Mettre à jour le cache local DailyCalories (sans écraser Strava/Objectif)
      // ------------------------------------------------------------------
      final existingDC = _dailyCaloriesRepo.getForDate(dateKey);

      final objectif = existingDC?.objectif ?? 0.0;
      final strava = existingDC?.strava ?? 0.0;

      await _dailyCaloriesRepo.upsert(
        date: dateKey,
        objectif: objectif,
        strava: strava,
        total: calories,
        // ⚠️ ne PAS toucher à stravaFetchedAt ici
      );

      // ------------------------------------------------------------------
      // 4) Construire le DaySnapshot (projection cloud)
      // ------------------------------------------------------------------
      final snapshot = DaySnapshot(
        date: DateTime.parse(dateKey),
        objectiveKcal: objectif,
        activityKcal: strava,
        consumedKcal: calories,

        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
        fiberG: fiber,
        sugarsG: sugars,

        fatSaturatedG: fatSat,
        fatMonounsaturatedG: fatMono,
        fatPolyunsaturatedG: fatPoly,

        updatedAt: DateTime.now(),
      );

      // ------------------------------------------------------------------
      // 5) Push Supabase (silencieux, offline-friendly)
      // ------------------------------------------------------------------
      await _remoteRepo.upsertDaySnapshot(snapshot);
    } catch (e, st) {
      // ⚠️ Volontairement silencieux pour ne jamais casser l’UI
      // Tu peux logger si besoin
      debugPrint('NutritionSnapshotService error: $e\n$st');
    }
  }

  // ----------------------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------------------

  Future<List<Meal>> _mealsForDate(String dateKey) async {
    // Utilise le repo Hive comme source de vérité
    return _mealRepo
        .getMealsForTypeAndDate('', dateKey)
        .then((_) async {
      // getMealsForTypeAndDate filtre par type, ici on veut TOUS les types.
      // Donc on récupère directement depuis Hive via getMealsInRange sur 1 jour.
      final d = DateTime.parse(dateKey);
      return _mealRepo.getMealsInRange(d, d);
    });
  }
}
