import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/strava_service.dart';

class StravaRepository {
  final StravaService _stravaService;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  StravaRepository(this._stravaService, this._firestore, this._auth);

  User? get _currentUser => _auth.currentUser;
  StravaService getStravaService() => _stravaService;

  Future<({List<dynamic> activities, double totalCalories})> getActivitiesAndCaloriesForDate(DateTime date) async {
  final uid = _currentUser?.uid;
  if (uid == null) return (activities: [], totalCalories: 0.0);

  if (!await _stravaService.isConnected()) {
    return (activities: [], totalCalories: 0.0);
  }

  // ⚠️ Aligne bien la date sur la "local time" Strava
  final dateKey = DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];
  final docRef = _firestore.collection('users').doc(uid).collection('daily_calories').doc(dateKey);

  try {
    final allActivities = await _stravaService.getActivities();

    // Filtrer sur la journée (Strava fournit start_date_local)
    final List<Map<String, dynamic>> activitiesForDay = [];
    for (final a in allActivities) {
      final localDay = DateTime.parse(a["start_date_local"]).toIso8601String().split("T")[0];
      if (localDay == dateKey) activitiesForDay.add(Map<String, dynamic>.from(a));
    }

    // 👉 Charger les détails pour avoir 'calories'
    final details = await Future.wait(
      activitiesForDay.map((a) => _stravaService.getActivityDetails(a['id'] as int)),
      eagerError: false,
    );

    double totalCalories = 0.0;

    for (var i = 0; i < activitiesForDay.length; i++) {
      final d = details[i];
      double cals = 0.0;

      if (d != null) {
        // 1) calories directes si dispo
        cals = _parseDouble(d['calories']);

        // 2) fallback vélo : 'kilojoules' ≈ kcal (1 kJ ≈ 0,239 kcal)
        if (cals == 0.0) {
          final kj = _parseDouble(d['kilojoules']);
          if (kj > 0) cals = kj * 0.239006;
        }

        // (optionnel) Autres fallbacks : estimation course/marche
        // ex: running ~ 1 kcal / kg / km si tu as le poids → à éviter sans poids fiable
      }

      // Mémoriser la calorie sur l'item pour ton UI
      activitiesForDay[i]['calories'] = cals;
      totalCalories += cals;
    }

    await docRef.set({
      'strava_totalCalories': totalCalories,
      'strava_lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print("✅ [StravaRepository] ${activitiesForDay.length} activités, ${totalCalories.toStringAsFixed(0)} kcal");
    return (activities: activitiesForDay, totalCalories: totalCalories);
  } catch (e) {
    print("❌ Erreur dans StravaRepository: $e");
    return (activities: [], totalCalories: 0.0);
  }
}

}

// ✅ ON AJOUTE LA FONCTION D'ASSISTANCE ICI, EN DEHORS DE LA CLASSE
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) {
    // On nettoie la chaîne pour ne garder que les chiffres et le point
    final cleanedString = value.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleanedString) ?? 0.0;
  }
  return 0.0;
}


// --- Providers Riverpod ---
final stravaServiceProvider = Provider((ref) => StravaService());

final stravaRepositoryProvider = Provider((ref) {
  return StravaRepository(
    ref.watch(stravaServiceProvider),
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );
});