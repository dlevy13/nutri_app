import 'package:hive/hive.dart';
import '../models/meal.dart';
import '../log.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



class MealDatabaseService {
  final Box<Meal> _mealBox;

  MealDatabaseService(this._mealBox); // ✅ Constructeur propre

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

    await _mealBox.add(meal);
    logger.d("📦 Repas ajouté localement dans Hive : ${meal.name}");

    await _uploadToFirestore(meal);
  }

  Future<void> addCustomFood(Meal meal) async {
    logger.d("📥 Fonction addCustomFood appelée pour : ${meal.name}");
    await _mealBox.add(meal);
    logger.d("📦 Repas ajouté localement : ${meal.name}");

    await _uploadToFirestore(meal);
  }

  Future<void> _uploadToFirestore(Meal meal) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      logger.e("❌ Aucun utilisateur connecté → Firestore annulé");
      return;
    }

    final mealRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meals');

    try {
      final doc = await mealRef.add(meal.toMap());
      logger.d("✅ Repas envoyé sur Firestore (ID : ${doc.id})");
    } catch (e) {
      logger.e("❌ Erreur Firestore : $e");
    }
  }

  Future<void> deleteMeal(String key) async {
    await _mealBox.delete(key);
  }

  Future<void> resetMeals() async {
    await _mealBox.clear();
  }

  Future<List<Meal>> getMeals({required String mealType, required String date}) async {
    return _mealBox.values
        .where((meal) => meal.type == mealType && meal.date == date)
        .toList();
  }

  Future<List<String>> getCustomFoods() async {
    final allFoods = _mealBox.values.map((meal) => meal.name.trim()).toSet();
    return allFoods.toList();
  }

  Future<List<Meal>> searchFoods(String query) async {
    return _mealBox.values
        .where((meal) => meal.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Future<List<Meal>> getMealsByDateAndType(String date, String type) async {
    return _mealBox.values
        .where((meal) => meal.date == date && meal.type == type)
        .toList();
  }

  Future<Map<String, List<Map<String, dynamic>>>> getMealsForTheWeek() async {
    final Map<String, List<Map<String, dynamic>>> data = {};
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));

    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final meals = _mealBox.values
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
    await _mealBox.put(key, updatedMeal);
  }

  Future<void> deleteDatabaseFile() async {
    await _mealBox.deleteFromDisk();
  }

  Future<List<Meal>> getMostFrequentMealsByType(String mealType, {int limit = 10}) async {
    final meals = _mealBox.values.where((m) => m.type == mealType);

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
