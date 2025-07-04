import 'package:hive/hive.dart';
import '../models/meal.dart';
import 'package:intl/intl.dart';

class MealDatabaseService {
  static const String _mealBoxName = 'mealsBox';

  Future<void> init() async {
    await Hive.openBox<Meal>(_mealBoxName);
  }

 Future<void> addMeal({
  required String name,
  required double calories,
  required double protein,
  required double carbs,
  required double fat,
  required double quantity,
  required String mealType,
  required String date,
}) async {
  final meal = Meal(
    name: name,
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
    quantity: quantity,
    type: mealType,
    date: date,
  );

  final box = await Hive.openBox<Meal>('meals');
  await box.add(meal);
}



  Future<void> deleteMeal(String key) async {
    final box = Hive.box<Meal>(_mealBoxName);
    await box.delete(key);
  }

  Future<void> resetMeals() async {
    final box = Hive.box<Meal>(_mealBoxName);
    await box.clear();
  }

  Future<List<Meal>> getMeals({required String mealType, required String date}) async {
  final box = await Hive.openBox<Meal>('meals');
  return box.values.where((meal) => meal.type == mealType && meal.date == date).toList();
}

Future<List<String>> getCustomFoods() async {
  final box = await Hive.openBox<Meal>('meals');
  final allFoods = box.values.map((meal) => meal.name.trim()).toSet();
  return allFoods.toList();
}

Future<void> addCustomFood(Meal meal) async {
  final box = await Hive.openBox<Meal>('meals');
  await box.add(meal);
}
Future<List<Meal>> searchFoods(String query) async {
  final box = await Hive.openBox<Meal>('meals');
  return box.values
      .where((meal) => meal.name.toLowerCase().contains(query.toLowerCase()))
      .toList();
}

  Future<List<Meal>> getMealsByDateAndType(String date, String type) async {
    final box = Hive.box<Meal>(_mealBoxName);
    return box.values.where((meal) =>
      meal.date == date && meal.type == type
    ).toList();
  }
Future<Map<String, List<Map<String, dynamic>>>> getMealsForTheWeek(Box<Meal> box) async {
  final Map<String, List<Map<String, dynamic>>> data = {};
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));

  for (int i = 0; i < 7; i++) {
    final date = monday.add(Duration(days: i));
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final meals = box.values
        .where((meal) => meal.date == dateStr)
        .map((meal) => {
              "name": meal.name,
              "calories": meal.calories,
              "protein": meal.protein,
              "carbs": meal.carbs,
              "fat": meal.fat,
              "quantity": meal.quantity,
              "type": meal.type,
              "date": meal.date,
            })
        .toList();

    data[dateStr] = meals;
  }

  return data;
}



  Future<void> updateMeal(String key, Meal updatedMeal) async {
    final box = Hive.box<Meal>(_mealBoxName);
    await box.put(key, updatedMeal);
  }

  Future<void> deleteDatabaseFile() async {
    await Hive.deleteBoxFromDisk(_mealBoxName);
  }
  // pour avoir les 10 aliments saisis précédemment par type de repas
  Future<List<Meal>> getMostFrequentMealsByType(String mealType, {int limit = 10}) async {
  final box = await Hive.openBox<Meal>('meals');
  final meals = box.values.where((m) => m.type == mealType);

  final countMap = <String, int>{};
  final mealMap = <String, Meal>{};

  for (final meal in meals) {
    countMap[meal.name] = (countMap[meal.name] ?? 0) + 1;
    mealMap[meal.name] = meal;
  }

  final sortedNames = countMap.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sortedNames
      .take(limit)
      .map((entry) => mealMap[entry.key]!)
      .toList();
}

}
