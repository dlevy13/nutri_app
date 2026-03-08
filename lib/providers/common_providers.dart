// dans lib/providers/common_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal.dart'; // Adaptez le chemin
import '../models/analysis.dart'; 
import '../models/daily_calories.dart';
import '../repositories/daily_calories_repository.dart';
import '../repositories/daily_snapshot_remote_repository.dart';
import '../repositories/meal_repository.dart';
import '../services/nutrition_snapshot_service.dart';

// ✅ On définit le provider pour SharedPreferences ICI et nulle part ailleurs.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

// ✅ On peut aussi centraliser les providers pour Hive ici.
final mealBoxProvider = Provider<Box<Meal>>((ref) {
  throw UnimplementedError();
});

final analysisBoxProvider = Provider<Box<Analysis>>((ref) {
  throw UnimplementedError();
});

final dailyCaloriesBoxProvider =
    Provider<Box<DailyCalories>>((ref) => throw UnimplementedError());

final dailyCaloriesRepositoryProvider = Provider<DailyCaloriesRepository>((ref) {
  final box = ref.watch(dailyCaloriesBoxProvider);
  return DailyCaloriesRepository(box);
});
final customFoodsBoxProvider = Provider<Box<Meal>>((ref) {
  throw UnimplementedError("customFoodsBox must be overridden in main.dart");
});
final dailySnapshotRemoteRepositoryProvider =
    Provider<DailySnapshotRemoteRepository>((ref) {
  return DailySnapshotRemoteRepository(
    Supabase.instance.client,
  );
});
final mealRepositoryProvider = Provider<MealRepository>((ref) {
  final box = ref.watch(mealBoxProvider);
  return MealRepository(box);
});
final nutritionSnapshotServiceProvider =
    Provider<NutritionSnapshotService>((ref) {
  return NutritionSnapshotService(
    ref.read(mealRepositoryProvider),
    ref.read(dailyCaloriesRepositoryProvider),
    ref.read(dailySnapshotRemoteRepositoryProvider),
  );
});
