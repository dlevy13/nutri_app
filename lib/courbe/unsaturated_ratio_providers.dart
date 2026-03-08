import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/date_service.dart';
import '../providers/common_providers.dart';
import '../../models/meal.dart';

//refonte

// Portée : Dashboard / Graph lipides
// Hypothèses :
// - Champs Firestore (en g / jour) :
//   consumedFat_g, consumedSatFat_g, consumedMono_g, consumedPoly_g, consumedTrans_g
// - Fonction utilitaire existante : DateService.formatStandard / parseStandard
// - Fonction sma(series, window) déjà disponible (sinon voir commentaire en bas)

final bejRangeDaysProvider = StateProvider<int>((_) => 60);

// ----------------------------------------------------------------------------
// 1) Modèle des lipides journaliers
// ----------------------------------------------------------------------------

double _safeD(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;

class DailyLipids {
  final DateTime day;
  final double total;
  final double sat;
  final double mono;
  final double poly;
  final double trans;
  final int mealsCount;

  DailyLipids({
    required this.day,
    required this.total,
    required this.sat,
    required this.mono,
    required this.poly,
    required this.trans,
    required this.mealsCount,
  });

  double? get unsatRatio {
    if (sat <= 0) return null;

    final sum = mono + poly;
    if (sum > 0) return sum / sat;

    final est = total - sat - trans;
    if (est.isFinite && est > 0) return est / sat;

    return null;
  }

  bool get isCoherent => total > 0 && sat > 0 && sat <= total;
}

// ----------------------------------------------------------------------------
// 2) dailyLipidsProvider → 🌟 Version 100% Hive, mêmes variables, même logique.
// ----------------------------------------------------------------------------

final dailyLipidsProvider = FutureProvider<List<DailyLipids>>((ref) async {
  final repo = ref.watch(mealRepositoryProvider);

  final days = ref.watch(bejRangeDaysProvider);
  final now = DateTime.now();

  final start = DateService.startOfLocalDay(now.subtract(Duration(days: days - 1)));
  final end = DateService.startOfLocalDay(now);

  final meals = await repo.getMealsInRange(start, end);
  if (meals.isEmpty) return [];

  // regrouper par date (yyyy-MM-dd)
  final Map<String, List<Meal>> byDay = {};
  for (final m in meals) {
    byDay.putIfAbsent(m.date, () => []).add(m);
  }

  final today = DateService.startOfLocalDay(now);
  final list = <DailyLipids>[];

  for (final entry in byDay.entries) {
    final dateStr = entry.key;
    final mealsOfDay = entry.value;
    final day = DateService.parseStandard(dateStr);
    final isToday = DateService.startOfLocalDay(day) == today;

    final mealsCount = mealsOfDay.length;

    // 🔥 règle J-1 identique à Firestore
    if (isToday && mealsCount < 3) continue;

    double fat = 0, sat = 0, mono = 0, poly = 0;

    for (final m in mealsOfDay) {
      fat  += _safeD(m.fat);
      sat  += _safeD(m.fatSaturated);
      mono += _safeD(m.fatMonounsaturated);
      poly += _safeD(m.fatPolyunsaturated);
    }

    list.add(DailyLipids(
      day: day,
      total: fat,
      sat: sat,
      mono: mono,
      poly: poly,
      trans: 0.0,
      mealsCount: mealsCount,
    ));
  }

  list.sort((a, b) => a.day.compareTo(b.day));
  return list;
});

// ----------------------------------------------------------------------------
// 3) Série brute unsaturated ratio
// ----------------------------------------------------------------------------

final unsatRatioSeriesProvider =
    Provider<AsyncValue<List<MapEntry<DateTime, double>>>>((ref) {
  final daily = ref.watch(dailyLipidsProvider);

  return daily.whenData((list) {
    final sorted = [...list]..sort((a, b) => a.day.compareTo(b.day));

    return sorted
        .where((d) => d.isCoherent && d.unsatRatio != null)
        .map((d) => MapEntry(d.day, d.unsatRatio!))
        .toList();
  });
});

// ----------------------------------------------------------------------------
// 4) Lissage SMA5 (réutilise ta fonction sma exacte)
// ----------------------------------------------------------------------------

List<MapEntry<DateTime,double>> sma(List<MapEntry<DateTime,double>> s, int w) {
  if (s.isEmpty || w <= 1) return const [];
  final out = <MapEntry<DateTime,double>>[];
  double sum = 0;

  for (int i = 0; i < s.length; i++) {
    sum += s[i].value;
    if (i >= w) sum -= s[i - w].value;
    if (i >= w - 1) {
      out.add(MapEntry(s[i].key, sum / w));
    }
  }
  return out;
}

final unsatRatioSma5Provider =
    Provider<AsyncValue<List<MapEntry<DateTime, double>>>>((ref) {
  final series = ref.watch(unsatRatioSeriesProvider);
  return series.whenData((s) => sma(s, 5));
});