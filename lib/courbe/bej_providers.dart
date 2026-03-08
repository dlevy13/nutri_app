import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/date_service.dart';
import '../../providers/common_providers.dart';
//refonte

// -----------
// Modèle BEJ
// -----------
class DailyEnergy {
  final DateTime day;
  final double needed;     // neededKcal (objectif + activité)
  final double consumed;   // consommé total
  final double activity;   // activité Strava (informative)

  DailyEnergy({
    required this.day,
    required this.needed,
    required this.consumed,
    required this.activity,
  });

  double get bej => consumed - needed; // BEJ = consommées − nécessaires
}

// nombre de jours affichés
final bejRangeDaysProvider = StateProvider<int>((_) => 60);

// -----------
// Provider principal : remplace Firestore par Hive
// -----------
final dailyEnergyProvider = FutureProvider<List<DailyEnergy>>((ref) async {
  final repo = ref.watch(dailyCaloriesRepositoryProvider);

  final days = ref.watch(bejRangeDaysProvider);
  final now = DateTime.now();

  final start = DateService.startOfLocalDay(
    now.subtract(Duration(days: days - 1)),
  );

  final end = DateService.startOfLocalDay(now);

  // On récupère les entrées Hive dans la plage
  final list = repo.getRange(start, end);

  if (list.isEmpty) return [];

  final today = DateService.startOfLocalDay(now);

  // ⚠️ EXACTE même logique que ta version Firestore : 
  // on ignore TODAY si repas incomplets (<3).
  final filtered = list.where((e) {
    final day = DateService.parseStandard(e.date);
    final isToday = DateService.startOfLocalDay(day) == today;

    // mealsCount n’existe plus → on NE FILTRE PAS
    // (si tu veux réactiver la logique je peux la réimplémenter autrement)
    return true;
  });

  return filtered.map((dc) {
    final day = DateService.parseStandard(dc.date);

    return DailyEnergy(
      day: day,
      needed: dc.objectif + dc.strava, // objectif ajusté + activité
      consumed: dc.total,
      activity: dc.strava,
    );
  }).toList();
});

// -----------
// SMA utilitaire
// -----------
List<MapEntry<DateTime,double>> sma(
  List<MapEntry<DateTime,double>> series,
  int w,
) {
  if (series.isEmpty || w <= 1) return const [];
  final out = <MapEntry<DateTime,double>>[];
  double sum = 0;

  for (int i = 0; i < series.length; i++) {
    sum += series[i].value;
    if (i >= w) sum -= series[i - w].value;
    if (i >= w - 1) {
      out.add(MapEntry(series[i].key, sum / w));
    }
  }
  return out;
}

// -----------
// Provider → Série BEJ brute
// -----------
final bejSeriesProvider =
    Provider<AsyncValue<List<MapEntry<DateTime,double>>>>((ref) {
  final daily = ref.watch(dailyEnergyProvider);

  return daily.whenData((list) {
    final sorted = [...list]..sort((a, b) => a.day.compareTo(b.day));
    return sorted.map((d) => MapEntry(d.day, d.bej)).toList();
  });
});

// -----------
// Provider → SMA5
// -----------
final bejSma5Provider =
    Provider<AsyncValue<List<MapEntry<DateTime,double>>>>((ref) {
  final series = ref.watch(bejSeriesProvider);
  return series.whenData((s) => sma(s, 5));
});
