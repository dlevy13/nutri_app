import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutri_app/dashboard/food_analysis_helpers.dart';
import 'package:nutri_app/models/daily_calories.dart';
import 'package:nutri_app/models/day_snapshot.dart';
import 'package:nutri_app/models/meal.dart';
import 'package:nutri_app/repositories/daily_calories_repository.dart';
import 'package:nutri_app/repositories/daily_snapshot_remote_repository.dart';
import 'package:nutri_app/repositories/meal_repository.dart';
import 'package:nutri_app/services/date_service.dart';
import 'package:nutri_app/services/nutrition_snapshot_service.dart';

class RecordingSnapshotRepository extends DailySnapshotRemoteRepository {
  RecordingSnapshotRepository()
      : super(SupabaseClient('http://localhost', 'test-key'));

  final snapshots = <DaySnapshot>[];

  @override
  Future<void> upsertDaySnapshot(DaySnapshot snapshot) async {
    snapshots.add(snapshot);
  }
}

void main() {
  late Directory tempDir;
  late Box<Meal> mealBox;
  late Box<DailyCalories> caloriesBox;
  late MealRepository meals;
  late DailyCaloriesRepository calories;
  late RecordingSnapshotRepository remote;
  late NutritionSnapshotService service;

  setUpAll(() {
    Hive.registerAdapter(MealAdapter());
    Hive.registerAdapter(DailyCaloriesAdapter());
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nutrition_dates_test_');
    Hive.init(tempDir.path);
    mealBox = await Hive.openBox<Meal>('meals');
    caloriesBox = await Hive.openBox<DailyCalories>('calories');
    meals = MealRepository(mealBox);
    calories = DailyCaloriesRepository(caloriesBox);
    remote = RecordingSnapshotRepository();
    service = NutritionSnapshotService(meals, calories, remote);
  });

  tearDown(() async {
    await mealBox.close();
    await caloriesBox.close();
    await tempDir.delete(recursive: true);
  });

  test('backdated dinner and cached food are assigned consistently', () async {
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final todayKey = DateService.formatStandard(today);
    final dinnerKey = DateService.formatStandard(yesterday);

    // La recherche met une fiche /100 g en cache à la date de saisie.
    await meals.upsertCustomFoodFromApi(
      name: 'Dessert',
      kcalPer100: 300,
      proteinPer100: 6,
      carbsPer100: 40,
      fatPer100: 14,
      fibersPer100: 2,
      sucresPer100: 30,
      saturatedFatPer100: 10,
      polyunsaturatedFatPer100: 1,
      monounsaturatedFatPer100: 3,
    );
    final dinner = Meal(
      name: 'Dessert',
      date: dinnerKey,
      type: 'Dîner',
      group: 'custom',
      timestamp: today.toIso8601String(),
      quantity: 50,
      calories: 150,
      protein: 3,
      carbs: 20,
      fat: 7,
      fiber: 1,
      sucres: 15,
      fatSaturated: 5,
      fatMonounsaturated: 1.5,
      fatPolyunsaturated: 0.5,
    );
    await meals.addMeal(dinner);

    // Même un ancien horodatage de saisie ne déplace pas la consommation.
    expect(await meals.getMealsInRange(today, today), isEmpty);
    expect(await meals.getMealsInRange(yesterday, yesterday), [dinner]);
    final todayWeek =
        await meals.getMealsForWeek(DateService.startOfWeek(today));
    final dinnerWeek =
        await meals.getMealsForWeek(DateService.startOfWeek(yesterday));
    expect(mealsForSelectedDay(today, todayWeek), isEmpty);
    expect(mealsForSelectedDay(yesterday, dinnerWeek), [dinner]);
    // Défense de l'analyse face à une liste ancienne contenant le catalogue.
    expect(mealsForSelectedDay(today, {todayKey: mealBox.values.toList()}),
        isEmpty);

    await service.recomputeAndSyncForDate(dinnerKey);
    await service.recomputeAndSyncForDate(todayKey);
    expect(calories.getForDate(dinnerKey)!.total, 150);
    expect(calories.getForDate(todayKey)!.total, 0);
    final past = remote.snapshots.first;
    expect(DateService.formatStandard(past.date), dinnerKey);
    expect(past.consumedKcal, 150);
    expect(past.proteinG, 3);
    expect(past.carbsG, 20);
    expect(past.fatG, 7);
    expect(past.fiberG, 1);
    expect(past.sugarsG, 15);
    expect(past.fatSaturatedG, 5);
    expect(past.fatMonounsaturatedG, 1.5);
    expect(past.fatPolyunsaturatedG, 0.5);
    final current = remote.snapshots.last;
    expect(DateService.formatStandard(current.date), todayKey);
    expect([
      current.consumedKcal,
      current.proteinG,
      current.carbsG,
      current.fatG,
      current.fiberG,
      current.sugarsG,
      current.fatSaturatedG,
      current.fatMonounsaturatedG,
      current.fatPolyunsaturatedG,
    ], everyElement(0));
  });
}
