// lib/features/metrics/bej_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bej_providers.dart';
import '../ui/strings.dart';

class BejChart extends ConsumerWidget {
  const BejChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bej = ref.watch(bejSeriesProvider);
    final sma = ref.watch(bejSma5Provider);
    final days = ref.watch(bejRangeDaysProvider);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.show_chart, size: 18),
            const SizedBox(width: 6),
            Text(
              L10n.calometreWithTrend, 
              style: Theme.of(context).textTheme.titleSmall
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.info_outline, size: 18),
              tooltip: 'À propos du CaloMètre',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => _showCalometreInfo(context),
            ),
            const Spacer(),
            DropdownButton<int>(
              value: days,
              items: const [30,60,90].map((d)=>DropdownMenuItem(value:d,child: Text("$d j"))).toList(),
              onChanged: (v) => ref.read(bejRangeDaysProvider.notifier).state = v ?? 60,
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: bej.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Erreur: $e")),
              data: (raw) {
                    if (raw.isEmpty) return const Center(child: Text("Aucune donnée - il faut au moins 1 semaine de repas pour avoir l'anayse graphique"));

                    // 1) base (premier jour) et utilitaire spots
                    final DateTime base = raw.first.key;
                    List<FlSpot> toSpots(List<MapEntry<DateTime,double>> s) => s.map((e) {
                      final dx = e.key.difference(base).inDays.toDouble();
                      return FlSpot(dx, e.value);
                    }).toList();

                    // 2) séries prêtes (INIT IMMÉDIAT)
                    final List<FlSpot> sBrut = toSpots(raw);
                    final List<MapEntry<DateTime,double>> smaSeries =
                        sma.asData?.value ?? const <MapEntry<DateTime,double>>[];
                    final List<FlSpot> sSmaSpots = toSpots(smaSeries);
                    final scheme = Theme.of(context).colorScheme;
                    final colorRaw = scheme.outline.withValues(alpha:0.65);     // courbe brute, discrète
                    final colorSma = scheme.primary;                       // MM5
                    final colorGlow = scheme.primary.withValues(alpha:0.14);    // halo
                    final fillTop   = scheme.primary.withValues(alpha:0.22);    // zone sous MM5
                    final fillBot   = Colors.transparent;
                   

                    // 4) y-min / y-max robustes
                    final allY = <double>[
                      ...sBrut.map((e) => e.y),
                      ...sSmaSpots.map((e) => e.y),
                      0.0
                    ];
                    final double minY = (allY.reduce((a,b)=>a<b?a:b) - 150).clamp(-4000.0, 4000.0);
                    final double maxY = (allY.reduce((a,b)=>a>b?a:b) + 150).clamp(-4000.0, 4000.0);

                    final rangeY = (maxY - minY).abs();
                    final double stepY = rangeY <= 800 ? 200 : rangeY <= 2000 ? 500 : 1000;
                    // 2) Bornes "propres" alignées sur le pas
                    double niceMinY = (minY / stepY).floor() * stepY;
                    double niceMaxY = (maxY / stepY).ceil()  * stepY;
                    // 5) courbes (références gardées pour le tooltip)
                    final barRaw = LineChartBarData(
                      spots: sBrut,
                      isCurved: false,
                      barWidth: 2,
                      dashArray: const [6, 4],
                      dotData: const FlDotData(show: false),
                      color: colorRaw,
                    );

                    // Halo derrière la MM5 (même spots, plus épais & transparent)
                    final barSmaGlow = LineChartBarData(
                      spots: sSmaSpots,
                      isCurved: true,
                      barWidth: 8,
                      dotData: const FlDotData(show: false),
                      color: colorGlow,
                    );

                    final barSma = LineChartBarData(
                      spots: sSmaSpots,
                      isCurved: true,
                      barWidth: 3.5,
                      dotData: const FlDotData(show: false),
                      color: colorSma,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [fillTop, fillBot],
                        ),
                      ),
                    );
                    String formatK(double v) {
                      final n = v.round();
                      if (n.abs() >= 1000) return "${(n/1000).toStringAsFixed(0)}k";
                      return n.toString();
                    }
                    String xLabel(double v) {
                      final d = base.add(Duration(days: v.toInt()));
                      return "${d.day}/${d.month}";
                    }

                    return LineChart(
                      LineChartData(
                        minY: niceMinY,
                        maxY: niceMaxY,

                        // Grille plus fun (pointillés, sans verticales)
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: stepY,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: Theme.of(context).dividerColor.withValues(alpha:0.25),
                            strokeWidth: 1,
                            dashArray: const [4, 6],
                          ),
                        ),

                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 44,
                              interval: stepY,
                              getTitlesWidget: (v, _) {
                                const tol = 1e-6;
                                final isMin  = (v - niceMinY).abs() < tol;
                                final isMax  = (v - niceMaxY).abs() < tol;
                                final hasZeroInRange = niceMinY <= 0 && niceMaxY >= 0;
                                final isZero = hasZeroInRange && v.abs() < tol;

                                if (isMin || isMax || isZero) {
                                  // éviter doublon si min==0 ou max==0
                                  if ((isMin && isZero) || (isMax && isZero)) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(formatK(v));
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: (raw.length / 6).clamp(1, 14).toDouble(),
                              getTitlesWidget: (v, _) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(xLabel(v), style: const TextStyle(fontSize: 11)),
                              ),
                            ),
                          ),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),

                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),

                        extraLinesData: ExtraLinesData(
                          horizontalLines: (niceMinY <= 0 && niceMaxY >= 0)
                              ? [HorizontalLine(y: 0, strokeWidth: 1,
                                  color: Theme.of(context).colorScheme.outline)]
                              : const [],
                        ),

                        // Ordre important pour l'effet glow : halo (derrière) -> brut -> MM5
                        lineBarsData: [barSmaGlow, barRaw, barSma],

                        // Zéro interaction / tooltips (propre)
                        lineTouchData: const LineTouchData(enabled: false),

                        // Petite anim d’entrée
                        // (si ta version fl_chart supporte ces props; sinon enlève-les)
                        // swapAnimationDuration: const Duration(milliseconds: 600),
                        // swapAnimationCurve: Curves.easeOutCubic,
                      ),
                    );
                  }

            ),
          ),
        ]),
      ),
    );
  }
  void _showCalometreInfo(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      final t = Theme.of(context).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 8),
                Text('À propos du CaloMètre', style: t.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Définition\n'
              'CaloMètre = calories consommées − calories nécessaires totales.\n'
              'Nécessaires totales = Besoins caloriques ajustés (profil + entraînement) + activité Strava.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Interprétation\n'
              '• > 0 : surplus (apport supérieur aux besoins)\n'
              '• < 0 : déficit (apport inférieur aux besoins)',
            ),
            const SizedBox(height: 8),
            const Text(
              'Courbe\n'
              'En pointillé les données brutes\n'
              'Le trait plein représente la moyenne mobile 5 jours (MM5) des valeurs quotidiennes pour lisser les variations.\n'
              'La ligne horizontale à 0 indique l’équilibre.',
            ),
            const SizedBox(height: 8),
            
          ],
        ),
      );
    },
  );
}

}
