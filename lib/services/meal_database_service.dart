import 'package:hive/hive.dart';
import '../models/meal.dart';
import '../log.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



class MealDatabaseService {
  final Box<Meal> _mealBox;

  MealDatabaseService(this._mealBox);
/// 🔥 Convertit toute date vers ISO `yyyy-MM-dd`
  String _normalizeToISO(String dateStr) {
    // Si déjà ISO
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) return dateStr;

    // Si format français dd/MM/yyyy
    final parts = dateStr.split('/');
    if (parts.length == 3) {
      final day = parts[0].padLeft(2, '0');
      final month = parts[1].padLeft(2, '0');
      final year = parts[2];
      return "$year-$month-$day";
    }

    // Fallback : on renvoie tel quel
    return dateStr;
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
    final isoDate = _normalizeToISO(date);
    final meal = Meal(
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      quantity: quantity,
      type: mealType,
      date: isoDate,
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

    final mealData = meal.toMap();
    mealData['userId'] = uid;

    try {
      final doc = await mealRef.add(meal.toMap());
      meal.firestoreId = doc.id; // ✅ on sauvegarde l'id Firestore
      await meal.save(); // ✅ on met à jour l'objet Hive
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
  final lowerQuery = query.toLowerCase();

  /// 1️⃣ Recherche locale (Hive)
  final localResults = _mealBox.values.where((meal) {
    return meal.name.toLowerCase().contains(lowerQuery);
  }).toList();

  logger.d("🔍 Hive → ${localResults.length} résultats trouvés");

  /// 2️⃣ Recherche Firestore (toujours, pour synchro)
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    logger.w("⚠️ Pas d’utilisateur connecté, Firestore ignoré");
    return localResults;
  }

  List<Meal> firestoreResults = [];
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meals')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThan: query + '\uf8ff')
        .get();

    firestoreResults = snapshot.docs.map((doc) {
      final data = doc.data();
      final meal = Meal.fromMap(data); // ⚠️ Assure-toi que Meal.fromMap existe
      return meal;
    }).toList();

    logger.d("🔥 Firestore → ${firestoreResults.length} résultats trouvés");

    /// 3️⃣ Mettre en cache dans Hive les résultats Firestore s’ils n’existent pas déjà
    for (final meal in firestoreResults) {
      final exists = _mealBox.values.any((m) => m.name == meal.name);
      if (!exists) {
        await _mealBox.add(meal);
        logger.d("💾 Aliment Firestore ajouté au cache Hive : ${meal.name}");
      }
    }

  } catch (e) {
    logger.e("❌ Erreur recherche Firestore : $e");
  }

    /// 4️⃣ Fusionner Hive + Firestore et supprimer les doublons par nom
    final Map<String, Meal> uniqueMeals = {};

    for (final meal in [...localResults, ...firestoreResults]) {
      uniqueMeals[meal.name.toLowerCase()] = meal; // clé = nom en minuscule
    }

    /// ✅ Retourne uniquement les valeurs uniques
    return uniqueMeals.values.toList();
}


  Future<List<Meal>> getMealsForDate(String date) async {
  final isoDate = _normalizeToISO(date);
  return _mealBox.values.where((meal) => meal.date == isoDate).toList();
}


  Future<List<Meal>> getMealsByDateAndType(String date, String type) async {
    final isoDate = _normalizeToISO(date);
    return _mealBox.values.where((meal) => meal.date == isoDate).toList();
  }

  Future<Map<String, List<Map<String, dynamic>>>> getMealsForTheWeek() async {
  // ✅ 1. Synchroniser avec Firestore avant lecture Hive
  await fetchMealsFromFirestore();

  final Map<String, List<Map<String, dynamic>>> data = {};
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));

  // ✅ 2. Lire les repas depuis Hive (après synchro)
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

  Future<List<Meal>> getMostFrequentMealsByType(String mealType, {int limit = 15}) async {
  // 1) filtre local par type
  final items = _mealBox.values.where((m) => m.type == mealType).toList();

  // 2) tri récent uniquement via 'date' (yyyy-MM-dd)
  items.sort((a, b) {
    final ad = (a.date ?? '').toString();
    final bd = (b.date ?? '').toString();
    return bd.compareTo(ad); // lexicographique OK pour yyyy-MM-dd
  });

  // 3) dédoublonnage par nom normalisé
  final seen = <String>{};
  final out = <Meal>[];
  for (final m in items) {
    final name = (m.name).trim();
    if (name.isEmpty) continue;
    final key = _normalizeName(name);
    if (seen.add(key)) {
      out.add(m);
      if (out.length >= limit) break;
    }
  }
  return out;
}

String _normalizeName(String s) {
  var t = s.trim().toLowerCase();
  const withAccents = 'àâäáãåçéèêëíìîïñóòôöõúùûüŷýÿœæ';
  const noAccents   = 'aaaaaaceeeeiiiinooooouuuuyyyoeae';
  for (var i = 0; i < withAccents.length; i++) {
    t = t.replaceAll(withAccents[i], noAccents[i]);
  }
  t = t.replaceAll(RegExp(r'[^\w\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ');
  return t;
}


  Future<List<Meal>> fetchMealsFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      logger.w("⚠️ Pas d’utilisateur connecté, Firestore ignoré");
      return [];
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('meals')
          .get();

      final meals = snapshot.docs.map((doc) => Meal.fromMap(doc.data())).toList();
      logger.d("🔥 Firestore → ${meals.length} repas récupérés");

      // ✅ Cache Hive
      for (final meal in meals) {
        final exists = _mealBox.values.any((m) =>
            m.name == meal.name && m.date == meal.date && m.type == meal.type);
        if (!exists) {
          await _mealBox.add(meal);
          logger.d("💾 Repas Firestore ajouté dans Hive : ${meal.name}");
        }
      }
      return meals;
    } catch (e) {
      logger.e("❌ Erreur récupération Firestore : $e");
      return [];
    }
}

}
