import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal.dart';
import '../services/date_service.dart';

class MealRepository {
  // Le repository n'a plus besoin de Hive, seulement de Firestore et Auth
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  MealRepository(this._firestore, this._auth);
  
  User? get _currentUser => _auth.currentUser;

  /// Récupère les repas pour une semaine donnée depuis Firestore.
  Future<Map<String, List<Meal>>> getMealsForWeek(DateTime weekStartDate) async {
    final uid = _currentUser?.uid;
    if (uid == null) return {};

    final Map<String, List<Meal>> weeklyMeals = {};
    
    // On prépare les 7 jours de la semaine
    for (int i = 0; i < 7; i++) {
      final date = weekStartDate.add(Duration(days: i));
      weeklyMeals[DateService.formatStandard(date)] = [];
    }
    
    // On crée les dates de début et de fin pour la requête Firestore
    final endDate = weekStartDate.add(const Duration(days: 7));
    
    // On fait une seule requête à Firestore pour toute la semaine
    final querySnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('meals')
        .where('date', isGreaterThanOrEqualTo: DateService.formatStandard(weekStartDate))
        .where('date', isLessThan: DateService.formatStandard(endDate))
        .get();

    // On distribue les repas trouvés dans les bons jours
    for (var doc in querySnapshot.docs) {
      final meal = Meal.fromMap(doc.data(), id: doc.id);
      if (weeklyMeals.containsKey(meal.date)) {
        weeklyMeals[meal.date]!.add(meal);
      }
    }
    
    return weeklyMeals;
  }
Future<void> updateMeal(Meal meal) async {
  final uid = _currentUser?.uid;
  if (uid == null) return;

  // Besoin d'un id Firestore pour cibler le doc
  if (meal.firestoreId == null || meal.firestoreId!.isEmpty) {
    // En dernier recours on pourrait faire delete + add, mais autant refuser proprement
    throw Exception("updateMeal: firestoreId manquant pour ${meal.name}");
  }

  await _firestore
      .collection('users')
      .doc(uid)
      .collection('meals')
      .doc(meal.firestoreId)
      .update(meal.toMap());
}

  /// Récupère les repas pour un type et une date spécifiques depuis Firestore.
  Future<List<Meal>> getMealsForTypeAndDate(String mealType, String dateKey) async {
    final uid = _currentUser?.uid;
    if (uid == null) return [];
  
    final querySnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('meals')
        .where('date', isEqualTo: dateKey)
        .where('type', isEqualTo: mealType)
        .get();

  // --- FIN DU BLOC DE DÉBOGAGE ---
    return querySnapshot.docs.map((doc) => Meal.fromMap(doc.data(), id: doc.id)).toList();
    
  }

  /// Trouve les repas les plus fréquents pour un type donné depuis Firestore.
  Future<List<Meal>> getMostFrequentMealsByType(String mealType) async {
    final uid = _currentUser?.uid;
    if (uid == null) return [];

    final querySnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('meals')
        .where('type', isEqualTo: mealType)
        .limit(50) // On limite pour la performance
        .get();
        
    if (querySnapshot.docs.isEmpty) return [];

    final meals = querySnapshot.docs.map((doc) => Meal.fromMap(doc.data())).toList();
    
    final Map<String, int> frequencyMap = {};
    final Map<String, Meal> mealMap = {};

    for (var meal in meals) {
      frequencyMap[meal.name] = (frequencyMap[meal.name] ?? 0) + 1;
      mealMap.putIfAbsent(meal.name, () => meal);
    }

    final sortedMeals = frequencyMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedMeals.take(5).map((entry) => mealMap[entry.key]!).toList();
  }

  /// Ajoute un nouveau repas dans Firestore.
  Future<void> addMeal(Meal meal) async {
    final uid = _currentUser?.uid;
    if (uid == null) throw Exception("Utilisateur non connecté.");

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('meals')
        .add(meal.toMap());
  }
  
  /// Supprime un repas de Firestore.
  Future<void> deleteMeal(Meal meal) async {
    final uid = _currentUser?.uid;
    if (uid == null || meal.firestoreId == null || meal.firestoreId!.isEmpty) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('meals')
        .doc(meal.firestoreId)
        .delete();
  }
}

// Le provider ne dépend plus de Hive
final mealRepositoryProvider = Provider<MealRepository>((ref) {
  return MealRepository(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );
});