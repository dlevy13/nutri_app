import '../models/meal.dart';
import '../services/date_service.dart';

List<Meal> mealsForSelectedDay(
  DateTime selectedDate,
  Map<String, List<Meal>> weeklyMeals,
) {
  final dateStr = DateService.formatStandard(selectedDate);
  final dailyMeals = weeklyMeals[dateStr] ?? const <Meal>[];
  final seen = <String>{};
  final unique = <Meal>[];

  String keyOf(Meal meal) {
    final timestamp = meal.timestamp ?? '';
    if (timestamp.isNotEmpty) {
      return '${meal.date}|${meal.type}|${meal.name}|$timestamp';
    }
    return '${meal.date}|${meal.type}|${meal.name}|'
        '${meal.quantity.toStringAsFixed(2)}|'
        '${meal.calories.toStringAsFixed(2)}|'
        '${meal.protein.toStringAsFixed(2)}|'
        '${meal.carbs.toStringAsFixed(2)}|'
        '${meal.fat.toStringAsFixed(2)}';
  }

  for (final meal in dailyMeals) {
    if (meal.date != dateStr) continue;
    final key = keyOf(meal);
    if (seen.add(key)) unique.add(meal);
  }

  return unique;
}

List<Meal> aggregateMealsByName(List<Meal> meals) {
  final aggregated = <String, Meal>{};

  for (final meal in meals) {
    final key = meal.name.trim().toLowerCase();
    final existing = aggregated[key];

    if (existing == null) {
      aggregated[key] = Meal(
        name: meal.name,
        calories: meal.calories,
        protein: meal.protein,
        carbs: meal.carbs,
        fat: meal.fat,
        quantity: meal.quantity,
        type: meal.type,
        date: meal.date,
        fiber: meal.fiber,
        sucres: meal.sucres,
        fatSaturated: meal.fatSaturated,
        fatMonounsaturated: meal.fatMonounsaturated,
        fatPolyunsaturated: meal.fatPolyunsaturated,
        group: meal.group,
        kcalPer100: meal.kcalPer100,
        proteinPer100: meal.proteinPer100,
        carbsPer100: meal.carbsPer100,
        fatPer100: meal.fatPer100,
        fiberPer100: meal.fiberPer100,
        sucresPer100: meal.sucresPer100,
        fatSaturatedPer100: meal.fatSaturatedPer100,
        fatMonounsaturatedPer100: meal.fatMonounsaturatedPer100,
        fatPolyunsaturatedPer100: meal.fatPolyunsaturatedPer100,
        timestamp: meal.timestamp,
      );
      continue;
    }

    existing
      ..quantity += meal.quantity
      ..calories += meal.calories
      ..protein += meal.protein
      ..carbs += meal.carbs
      ..fat += meal.fat
      ..fiber = (existing.fiber ?? 0) + (meal.fiber ?? 0)
      ..sucres = (existing.sucres ?? 0) + (meal.sucres ?? 0)
      ..fatSaturated = (existing.fatSaturated ?? 0) + (meal.fatSaturated ?? 0)
      ..fatMonounsaturated =
          (existing.fatMonounsaturated ?? 0) + (meal.fatMonounsaturated ?? 0)
      ..fatPolyunsaturated =
          (existing.fatPolyunsaturated ?? 0) + (meal.fatPolyunsaturated ?? 0);
  }

  return aggregated.values.toList();
}
