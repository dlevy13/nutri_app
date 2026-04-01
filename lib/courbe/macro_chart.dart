import '../widget/chart_section_header.dart';
import '../ui/theme/app_theme.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'macro_providers.dart';
//refonte

class MacroPctSmaChart extends ConsumerWidget {
  const MacroPctSmaChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(macroPctSma5Provider);
    final days = ref.watch(macroPctRangeDaysProvider);

    // Couleurs lisibles

    final colorProt = AppColors.green; // Prot
    final colorCarb = AppColors.orange; // Gluc
    final colorFat = AppColors.blue; // Lip

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ChartSectionHeader(
              title: "Part des macros (%)",
              icon: Icons.multiline_chart_rounded,
              days: days,
              onInfo: () => _showMacroPctInfo(context),
              onRangeChanged: (v) =>
                  ref.read(macroPctRangeDaysProvider.notifier).state = v),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: dataAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(
                  child: Text("Le graphique est indisponible pour le moment.")),
              data: (points) {
                final pts = (points.length > 4)
                    ? points.sublist(4)
                    : const <MacroPctPoint>[];
                if (pts.isEmpty) {
                  return const Center(
                      child: Text(
                          "Encore un peu de patience : la tendance nécessite au moins 5 jours de données."));
                }

                // Base X = premier point
                final base = pts.first.day;

                List<FlSpot> toSpots(double Function(MacroPctPoint p) pick) =>
                    pts.map((p) {
                      final dx = p.day.difference(base).inDays.toDouble();
                      return FlSpot(dx, pick(p));
                    }).toList();

                final sProt = toSpots((p) => p.protPct);
                final sCarb = toSpots((p) => p.carbPct);
                final sFat = toSpots((p) => p.fatPct);

                String xLabel(double v) {
                  final d = base.add(Duration(days: v.toInt()));
                  return "${d.day}/${d.month}";
                }

                // Lignes MM5 uniquement (pas de brute)

                final barProt = LineChartBarData(
                  spots: sProt,
                  isCurved: true,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  color: colorProt,
                );
                final barCarb = LineChartBarData(
                  spots: sCarb,
                  isCurved: true,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  color: colorCarb,
                );
                final barFat = LineChartBarData(
                  spots: sFat,
                  isCurved: true,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  color: colorFat,
                );

                return LineChart(
                  LineChartData(
                    minY: 0, maxY: 100,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 25,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.25),
                        strokeWidth: 1,
                        dashArray: const [4, 6],
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 38,
                          interval: 25,
                          getTitlesWidget: (v, _) {
                            final n = v.toInt();
                            if (n == 0 || n == 50 || n == 100) {
                              return Text("$n%");
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: (points.length / 6).clamp(1, 14).toDouble(),
                          getTitlesWidget: (v, _) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(xLabel(v),
                                style: const TextStyle(fontSize: 11)),
                          ),
                        ),
                      ),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    lineBarsData: [barProt, barCarb, barFat],
                    // Aucune interaction / tooltip
                    lineTouchData: const LineTouchData(enabled: false),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Légende
          Wrap(spacing: 16, runSpacing: 8, children: [
            _legendSwatch(colorCarb, "Glucides"),
            _legendSwatch(colorProt, "Protéines"),
            _legendSwatch(colorFat, "Lipides"),
          ]),
        ]),
      ),
    );
  }

  Widget _legendSwatch(Color c, String t) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 14, height: 3, color: c),
          const SizedBox(width: 6),
          Text(t, style: const TextStyle(fontSize: 12)),
        ],
      );
  void _showMacroPctInfo(BuildContext context) {
    showChartInfo(context, title: 'À propos de la part des macros', children: [
      const Text(
        "Définition\n"
        "Ce graphique montre la part (%) de chaque macro dans le total des macros, "
        "après lissage en moyenne mobile 5 jours (MM5).",
      ),
      const SizedBox(height: 8),
    ]);
  }
}
