
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/date_service.dart';

class MacroPctPoint {
  final DateTime day;
  final double protPct; // 0..100
  final double carbPct; // 0..100
  final double fatPct;  // 0..100
  const MacroPctPoint(this.day, this.protPct, this.carbPct, this.fatPct);
}

final macroPctRangeDaysProvider = StateProvider<int>((_) => 60);

final macroPctSma5Provider = FutureProvider<List<MacroPctPoint>>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const [];

  final days = ref.watch(macroPctRangeDaysProvider);
  final to   = DateService.formatStandard(DateTime.now());
  final from = DateService.formatStandard(
      DateTime.now().subtract(Duration(days: days - 1)));

  final qs = await FirebaseFirestore.instance
      .collection('users').doc(uid)
      .collection('daily_calories')
      .where('date', isGreaterThanOrEqualTo: from)
      .where('date', isLessThanOrEqualTo: to)
      .orderBy('date')
      .get();

  final today = DateService.startOfLocalDay(DateTime.now());

  // Série chronologique des grammes (P, C, F), avec filtre "aujourd’hui < 3 repas" si connu
  final rows = <MapEntry<DateTime, (double p, double c, double f)>>[];
  double _toD(v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;

  for (final d in qs.docs) {
    final m = d.data();
    final dateStr = (m['date'] as String?) ?? d.id;
    final day = DateService.parseStandard(dateStr);

    final isToday = DateService.startOfLocalDay(day) == today;
    final meals = (m['mealsCount'] as num?)?.toInt();
    if (isToday && meals != null && meals < 3) continue; // exclure aujourd'hui si <3 repas

    rows.add(MapEntry(
      day,
      (_toD(m['consumedProt_g']), _toD(m['consumedCarb_g']), _toD(m['consumedFat_g'])),
    ));
  }

  rows.sort((a, b) => a.key.compareTo(b.key));
  if (rows.length < 5) return const []; // pas assez de points pour une MM5

  // MM5 sur les grammes
  const w = 5;
  final out = <MacroPctPoint>[];
  double sp = 0, sc = 0, sf = 0;

  for (int i = 0; i < rows.length; i++) {
    final cur = rows[i].value;
    sp += cur.$1; sc += cur.$2; sf += cur.$3;

    if (i >= w) {
      final prev = rows[i - w].value;
      sp -= prev.$1; sc -= prev.$2; sf -= prev.$3;
    }

    if (i >= w - 1) {
      final pAvg = sp / w, cAvg = sc / w, fAvg = sf / w;
      final tot  = pAvg + cAvg + fAvg;
      final pp   = (tot > 0) ? (pAvg / tot) * 100.0 : 0.0;
      final pc   = (tot > 0) ? (cAvg / tot) * 100.0 : 0.0;
      final pf   = (tot > 0) ? (fAvg / tot) * 100.0 : 0.0;
      out.add(MacroPctPoint(rows[i].key, pp, pc, pf));
    }
  }

  return out;
});
