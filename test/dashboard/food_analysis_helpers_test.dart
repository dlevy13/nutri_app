import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_app/dashboard/food_analysis_helpers.dart';
import 'package:nutri_app/models/meal.dart';

Meal meal({
  required String name,
  required String date,
  required String timestamp,
  required double quantity,
  double calories = 0,
  double protein = 0,
  double carbs = 0,
  double fat = 0,
  double fiber = 0,
  double sugars = 0,
  double sat = 0,
  double mono = 0,
  double poly = 0,
}) {
  return Meal(
    name: name,
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
    quantity: quantity,
    type: 'Déjeuner',
    date: date,
    fiber: fiber,
    sucres: sugars,
    fatSaturated: sat,
    fatMonounsaturated: mono,
    fatPolyunsaturated: poly,
    timestamp: timestamp,
  );
}

void main() {
  group('mealsForSelectedDay', () {
    test('keeps only the selected day and removes exact duplicates', () {
      final selectedDay = DateTime(2026, 7, 15);
      final meals = [
        meal(
          name: 'Banane',
          date: '2026-07-15',
          timestamp: '2026-07-15T08:00:00',
          quantity: 120,
        ),
        meal(
          name: 'Banane',
          date: '2026-07-15',
          timestamp: '2026-07-15T08:00:00',
          quantity: 120,
        ),
        meal(
          name: 'Banane',
          date: '2026-07-14',
          timestamp: '2026-07-14T08:00:00',
          quantity: 90,
        ),
      ];

      final result = mealsForSelectedDay(selectedDay, {
        '2026-07-15': meals,
      });

      expect(result, hasLength(1));
      expect(result.first.date, '2026-07-15');
      expect(result.first.name, 'Banane');
    });
  });

  group('aggregateMealsByName', () {
    test('aggregates quantities and macros for repeated foods', () {
      final result = aggregateMealsByName([
        meal(
          name: 'Banane',
          date: '2026-07-15',
          timestamp: '2026-07-15T08:00:00',
          quantity: 120,
          calories: 110,
          protein: 1.0,
          carbs: 25,
          fat: 0.5,
          fiber: 2.0,
          sugars: 15,
          sat: 0.1,
          mono: 0.2,
          poly: 0.1,
        ),
        meal(
          name: 'banane',
          date: '2026-07-15',
          timestamp: '2026-07-15T16:00:00',
          quantity: 80,
          calories: 70,
          protein: 0.7,
          carbs: 18,
          fat: 0.3,
          fiber: 1.4,
          sugars: 10,
          sat: 0.05,
          mono: 0.1,
          poly: 0.05,
        ),
      ]);

      expect(result, hasLength(1));
      expect(result.first.name, 'Banane');
      expect(result.first.quantity, 200);
      expect(result.first.calories, 180);
      expect(result.first.protein, 1.7);
      expect(result.first.carbs, 43);
      expect(result.first.fat, 0.8);
      expect(result.first.fiber, 3.4);
      expect(result.first.sucres, 25);
      expect(result.first.fatSaturated, closeTo(0.15, 0.000001));
      expect(result.first.fatMonounsaturated, closeTo(0.3, 0.000001));
      expect(result.first.fatPolyunsaturated, closeTo(0.15, 0.000001));
    });
  });
}
