// unsaturated_ratio_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../courbe/unsaturated_ratio_providers.dart'; // On importe les nouveaux providers
//refonte

class UnsaturatedRatioChart extends ConsumerWidget {
  const UnsaturatedRatioChart({super.key});

  // VALEUR DE SEUIL POUR LE RATIO
  // Un ratio de 2.0 (2g d'insaturés pour 1g de saturés) est souvent recommandé.
  static const double thresholdRatio = 2.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sma = ref.watch(unsatRatioSma5Provider);
    final days = ref.watch(bejRangeDaysProvider); // On réutilise le sélecteur de jours

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.waves, size: 18), // Icône différente
            const SizedBox(width: 6),
            Text(
              "Ratio Insaturés / Saturés",
              style: Theme.of(context).textTheme.titleSmall
            ),
             const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.info_outline, size: 18),
              tooltip: "À propos du ratio Insaturés / Saturés",
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => _showRatioInfo(context),
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
            child: sma.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Erreur: $e")),
              data: (smaSeries) {
                    if (smaSeries.isEmpty) {
                      return const Center(child: Text("Données insuffisantes pour le calcul du ratio (au moins 5 jours nécessaires)."));
                    }

                    final DateTime base = smaSeries.first.key;
                    List<FlSpot> toSpots(List<MapEntry<DateTime,double>> s) => s.map((e) {
                      final dx = e.key.difference(base).inDays.toDouble();
                      return FlSpot(dx, e.value);
                    }).toList();

                    final List<FlSpot> sSmaSpots = toSpots(smaSeries);
                    //final scheme = Theme.of(context).colorScheme;
                    final colorSma = Colors.teal; // Couleur spécifique pour ce chart
                    final colorGlow = colorSma.withValues(alpha:0.2);
                    final colorThreshold = Colors.redAccent.withValues(alpha:0.8);

                    final allY = <double>[
                      ...sSmaSpots.map((e) => e.y),
                      0.0,
                      thresholdRatio, // Inclure le seuil dans le calcul des bornes
                    ];
                    final double minY = 0.0; // Le ratio ne peut pas être négatif
                    final double maxY = (allY.reduce((a, b) => a > b ? a : b) + 0.5);

                    final barSma = LineChartBarData(
                      spots: sSmaSpots,
                      isCurved: true,
                      barWidth: 3.5,
                      dotData: const FlDotData(show: false),
                      color: colorSma,
                    );
                     final barSmaGlow = LineChartBarData(
                      spots: sSmaSpots,
                      isCurved: true,
                      barWidth: 8,
                      dotData: const FlDotData(show: false),
                      color: colorGlow,
                    );

                    String xLabel(double v) {
                      final d = base.add(Duration(days: v.toInt()));
                      return "${d.day}/${d.month}";
                    }

                    return LineChart(
                      LineChartData(
                        minY: minY,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 1,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                            strokeWidth: 1,
                            dashArray: const [4, 6],
                          ),
                        ),
                        titlesData: FlTitlesData(
                           leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              interval: 1,
                               getTitlesWidget: (v, meta) {
                                // Affiche seulement les entiers
                                if (v == v.floorToDouble()) {
                                   return Padding(
                                     padding: const EdgeInsets.only(right: 6.0),
                                     child: Text(v.toStringAsFixed(0), textAlign: TextAlign.right),
                                   );
                                }
                                return const SizedBox.shrink();
                              }
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: (smaSeries.length / 6).clamp(5, 14).toDouble(),
                              getTitlesWidget: (v, _) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(xLabel(v), style: const TextStyle(fontSize: 11)),
                              ),
                            ),
                          ),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        extraLinesData: ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: thresholdRatio,
                              strokeWidth: 2,
                              dashArray: const [8, 4],
                              color: colorThreshold,
                              label: HorizontalLineLabel(
                                show: true,
                                alignment: Alignment.topRight,
                                padding: const EdgeInsets.only(right: 5, bottom: 2),
                                style: TextStyle(color: colorThreshold, fontSize: 12, fontWeight: FontWeight.bold),
                                labelResolver: (_) => "Seuil (${thresholdRatio.toStringAsFixed(1)})"
                              )
                            )
                          ],
                        ),
                        lineBarsData: [barSmaGlow, barSma],
                        lineTouchData: const LineTouchData(enabled: false),
                      ),
                    );
                  }
            ),
          ),
        ]),
      ),
    );
  }
  void _showRatioInfo(BuildContext context) {
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
                Text("Ratio Insaturés / Saturés", style: t.titleMedium),
                const SizedBox(width: 6),
            
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: "Fermer",
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Définition\n"
              "Le ratio compare la quantité de 'bonnes' graisses (insaturées) à celle des 'mauvaises' graisses (saturées). "
              ),
            const SizedBox(height: 8),
            const Text(
              'Interprétation\n'
              '• > 2 Indique une bonne qualité de lipides, favorable à la santé.\n'
              '• < 1 : Suggère une alimentation trop riche en graisses saturées, présentant un risque potentiel pour la santé cardiovasculaire.',
               ),
            const SizedBox(height: 8),
            const Text(
              'Courbe\n'
              'Lissage en moyenne mobile 5 jours (MM5).',
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
}