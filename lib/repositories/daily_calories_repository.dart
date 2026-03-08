import 'package:hive/hive.dart';
import '../models/daily_calories.dart';

class DailyCaloriesRepository {
  final Box<DailyCalories> _box;

  DailyCaloriesRepository(this._box);

  /// Retourne l'objet DailyCalories pour une date ("yyyy-MM-dd")
  DailyCalories? getForDate(String date) {
        try {
      return _box.values.firstWhere((e) => e.date == date);
    } catch (_) {
      return null;
    }

  }


  bool isStravaFresh(DailyCalories dc) {
  if (dc.stravaFetchedAt == null) return false;

  final age = DateTime.now().difference(dc.stravaFetchedAt!);
  return age.inHours < 24;
}


/// 🧹 Nettoyage automatique (7 jours)
  Future<void> cleanupOldEntries({int keepDays = 7}) async {
    final cutoff = DateTime.now().subtract(Duration(days: keepDays));

    final keysToDelete = <dynamic>[];

    for (final dc in _box.values) {
      final d = DateTime.tryParse(dc.date);
      if (d != null && d.isBefore(cutoff)) {
        keysToDelete.add(dc.key);
      }
    }

    if (keysToDelete.isNotEmpty) {
      await _box.deleteAll(keysToDelete);
    }
  }

  /// Ajoute ou met à jour une entrée DailyCalories
  Future<void> upsert({
  required String date,
  required double objectif,
  required double strava,
  required double total,
  DateTime? stravaFetchedAt,
}) async {
  final existing = getForDate(date);

  if (existing != null) {
    existing.objectif = objectif;
    existing.strava = strava;
    existing.total = total;

    // ⚠️ Important : ne pas écraser si null
    if (stravaFetchedAt != null) {
      existing.stravaFetchedAt = stravaFetchedAt;
    }

    await existing.save();
    return;
  }

  final dc = DailyCalories(
    date: date,
    objectif: objectif,
    strava: strava,
    total: total,
    stravaFetchedAt: stravaFetchedAt,
  );

  await _box.add(dc);
}


  /// Récupère un historique sur un intervalle
  List<DailyCalories> getRange(DateTime start, DateTime end) {
    final s = start.toIso8601String().substring(0, 10);
    final e = end.toIso8601String().substring(0, 10);

    return _box.values
        .where((dc) => dc.date.compareTo(s) >= 0 && dc.date.compareTo(e) <= 0)
        .toList();
  }

  ///
  Future<double> getStravaCaloriesForDate({
  required String dateKey,
  required Future<double> Function() fetchRemote,
}) async {
  final existing = getForDate(dateKey);

  // ✅ Cache HIT
  if (existing != null && isStravaFresh(existing)) {
    return existing.strava;
  }

  // 🌐 Cache MISS → appel réseau
  final calories = await fetchRemote();

  await upsert(
    date: dateKey,
    objectif: existing?.objectif ?? 0,
    total: existing?.total ?? 0,
    strava: calories,
    stravaFetchedAt: DateTime.now(),
  );

 await cleanupOldEntries();


  return calories;
}


}
