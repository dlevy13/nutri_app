
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/date_service.dart';

class DailyEnergy {
  final DateTime day;
  final double needed;     // neededKcal (incluant Strava)
  final double consumed;   // consumedKcal
  final double activity;   // activityKcal (info)
  DailyEnergy({required this.day, required this.needed, required this.consumed, required this.activity});
  double get bej => consumed - needed; // BEJ = consommées − nécessaires
}

final bejRangeDaysProvider = StateProvider<int>((_) => 60);


final dailyEnergyProvider = FutureProvider<List<DailyEnergy>>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const [];

  final days = ref.watch(bejRangeDaysProvider);
  final to   = DateService.formatStandard(DateTime.now());
  final from = DateService.formatStandard(DateTime.now().subtract(Duration(days: days - 1)));

  final qs = await FirebaseFirestore.instance
      .collection('users').doc(uid)
      .collection('daily_calories')
      .where('date', isGreaterThanOrEqualTo: from)
      .where('date', isLessThanOrEqualTo: to)
      .orderBy('date')
      .get();

  final today = DateService.startOfLocalDay(DateTime.now());

  final docs = qs.docs.where((d) {
    final m = d.data();
    final dateStr = (m['date'] as String?) ?? d.id;
    final day = DateService.parseStandard(dateStr);
    final isToday = DateService.startOfLocalDay(day) == today;

    final meals = (m['mealsCount'] as num?)?.toInt();
    // ⚠️ On exclut seulement si on SAIT qu’il y a <3 repas.
    if (isToday && meals != null && meals < 3) return false;

    return true;
  });

  double _toD(v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;

  return docs.map((d) {
    final m = d.data();
    final dateStr = (m['date'] as String?) ?? d.id;
    final day = DateService.parseStandard(dateStr);
    return DailyEnergy(
      day: day,
      needed:   _toD(m['neededKcal']),
      consumed: _toD(m['consumedKcal']),
      activity: _toD(m['activityKcal']),
    );
  }).toList();
});


List<MapEntry<DateTime,double>> _sma(List<MapEntry<DateTime,double>> series, int w) {
  if (series.isEmpty || w <= 1) return const [];
  final out = <MapEntry<DateTime,double>>[];
  double sum = 0;
  for (int i=0;i<series.length;i++) {
    sum += series[i].value;
    if (i >= w) sum -= series[i - w].value;
    if (i >= w - 1) {
      out.add(MapEntry(series[i].key, sum / w));
    }
  }
  return out;
}

final bejSeriesProvider = Provider<AsyncValue<List<MapEntry<DateTime,double>>>>((ref) {
  final daily = ref.watch(dailyEnergyProvider);
  return daily.whenData((list) {
    final sorted = [...list]..sort((a,b)=>a.day.compareTo(b.day));
    return sorted.map((d) => MapEntry(d.day, d.bej)).toList();
  });
});

final bejSma5Provider = Provider<AsyncValue<List<MapEntry<DateTime,double>>>>((ref) {
  final series = ref.watch(bejSeriesProvider);
  return series.whenData((s) => _sma(s, 5));
});
