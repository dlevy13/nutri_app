import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal.dart';
import '../services/date_service.dart';
import '../services/fonctions.dart';

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

    return querySnapshot.docs.map((doc) => Meal.fromMap(doc.data(), id: doc.id)).toList();
    
  }

  /// Trouve les repas les plus fréquents pour un type donné depuis Firestore.
  Future<List<Meal>> getLastMealsByType(String mealType) async {
    final uid = _currentUser?.uid;
    if (uid == null) return [];

    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('meals')
        .where('type', isEqualTo: mealType)
        .orderBy('date', descending: true)
        .limit(50) // On limite pour la performance
        .get();
        
    if (snap.docs.isEmpty) return [];
    final seen = <String>{};
    final result = <Meal>[];

    for (final doc in snap.docs) {
      final meal = Meal.fromMap(doc.data());
      final key = meal.name.trim().toLowerCase();
       if (key.isEmpty) continue;
        if (seen.add(key)) {
          result.add(meal);
          if (result.length >= 15) break;
        }
      }
      return result;
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

// enregistré repas API dans custom_foods

// dans la classe MealRepository de meal_repository.dart

Future<String> upsertCustomFoodFromApi({
  required String name,
  required double kcalPer100,
  required double proteinPer100,
  required double carbsPer100,
  required double fatPer100,
  // ✅ AJOUT : Nouveaux paramètres pour les nutriments détaillés
  required double fibersPer100,
  required double saturatedFatPer100,
  required double polyunsaturatedFatPer100,
  required double monounsaturatedFatPer100,
  String? externalId,
  String? imageUrl,
  String source = 'api',
}) async {
  final uid = _currentUser?.uid;
  if (uid == null) return '';

  final col = _firestore.collection('users').doc(uid).collection('custom_foods');
  final norm = normalize(name);
  String rawId = (externalId != null && externalId.trim().isNotEmpty)
      ? 'api:${externalId.trim()}'
      : 'name:$norm';
  final docId = rawId.replaceAll(RegExp(r'[\/?#\[\]]'), '_');
  final docRef = col.doc(docId);
  final snap = await docRef.get();

  final payload = <String, dynamic>{
    'name': name.trim(),
    'normalizedName': norm,
    // Macros de base
    'calories': kcalPer100,
    'protein': proteinPer100,
    'carbs': carbsPer100,
    'fat': fatPer100,
    // ✅ AJOUT : Sauvegarde des nouveaux champs
    'fibres': fibersPer100,                 // ou 'fiber' selon votre convention
    'fat_s': saturatedFatPer100,          // ou 'saturated_fat'
    'fat_m': monounsaturatedFatPer100,    // ou 'monounsaturated_fat'
    'fat_p': polyunsaturatedFatPer100,    // ou 'polyunsaturated_fat'
    
    'per': 100,
    'imageUrl': imageUrl,
    'source': source,
    'externalId': externalId,
    'lastUsedAt': FieldValue.serverTimestamp(),
    'usesCount': FieldValue.increment(1),
    if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),

    // Rétrocompatibilité (si nécessaire)
    'kcalPer100': kcalPer100,
    'proteinPer100': proteinPer100,
    'carbsPer100': carbsPer100,
    'fatPer100': fatPer100,
    'fiberPer100': fibersPer100,
    'fatSaturatedPer100': saturatedFatPer100,
    'fatMonounsaturatedPer100': monounsaturatedFatPer100,
    'fatPolyunsaturatedPer100': polyunsaturatedFatPer100,
  };

  await docRef.set(payload, SetOptions(merge: true));
  return docId;
}



// Appelé quand tu utilises un custom food déjà présent
Future<void> touchCustomFood(String docId) async {
  final uid = _currentUser?.uid;
  if (uid == null) return;
  await _firestore
      .collection('users').doc(uid).collection('custom_foods')
      .doc(docId)
      .set({'lastUsedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
}

}

// Le provider ne dépend plus de Hive
final mealRepositoryProvider = Provider<MealRepository>((ref) {
  return MealRepository(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );
});