
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/date_service.dart';
import '../providers/common_providers.dart';

//refonte
class MacroPctPoint {
  final DateTime day;
  final double protPct;
  final double carbPct;
  final double fatPct;

  const MacroPctPoint(this.day, this.protPct, this.carbPct, this.fatPct);
}

final macroPctRangeDaysProvider = StateProvider<int>((_) => 60);

/// ⚠️ Nouvelle version : on récupère les macros en RAM depuis Hive
final macroPctSma5Provider = FutureProvider<List<MacroPctPoint>>((ref) async {
  final repo = ref.watch(mealRepositoryProvider);     // <-- plus Firestore
  final days = ref.watch(macroPctRangeDaysProvider);

  final now = DateTime.now();
  final start = DateService.startOfLocalDay(
    now.subtract(Duration(days: days - 1)),
  );
  final end = DateService.startOfLocalDay(now);

  // 🔥 On récupère TOUS les repas dans la période (tous types)
  final allMeals = await repo.getMealsInRange(start, end);

  if (allMeals.isEmpty) return [];

  // --- Regrouper par jour ---
  final Map<String, (double p, double c, double f)> dayMap = {};

  for (final m in allMeals) {
    final d = m.date; // 'yyyy-MM-dd'
    final prev = dayMap[d] ?? (0, 0, 0);

    dayMap[d] = (
      prev.$1 + (m.protein),
      prev.$2 + (m.carbs),
      prev.$3 + (m.fat),
    );
  }

  // On convertit en série chronologique
  final series = dayMap.entries.map((e) {
    final day = DateService.parseStandard(e.key);
    return MapEntry(day, e.value);
  }).toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  if (series.length < 5) return [];

  // --- SMA5 ---
  const w = 5;
  double sp = 0, sc = 0, sf = 0;
  final out = <MacroPctPoint>[];

  for (int i = 0; i < series.length; i++) {
    final cur = series[i].value;
    sp += cur.$1; sc += cur.$2; sf += cur.$3;

    if (i >= w) {
      final prev = series[i - w].value;
      sp -= prev.$1; sc -= prev.$2; sf -= prev.$3;
    }

    if (i >= w - 1) {
      final pAvg = sp / w, cAvg = sc / w, fAvg = sf / w;
      final tot = pAvg + cAvg + fAvg;

      final protPct = (tot > 0) ? (pAvg / tot) * 100 : 0;
      final carbPct = (tot > 0) ? (cAvg / tot) * 100 : 0;
      final fatPct = (tot > 0) ? (fAvg / tot) * 100 : 0;

      out.add(
        MacroPctPoint(
          series[i].key,
          protPct.toDouble(),
          carbPct.toDouble(),
          fatPct.toDouble(),
        ),
  );

    }
  }

  return out;
});
