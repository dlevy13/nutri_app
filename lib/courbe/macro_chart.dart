
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'macro_providers.dart';


class MacroPctSmaChart extends ConsumerWidget {
  const MacroPctSmaChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(macroPctSma5Provider);
    final days = ref.watch(macroPctRangeDaysProvider);

    // Couleurs lisibles
    
    final colorProt = Color(0xFF0072B2);                        // Prot
    final colorCarb = Color(0xFFE69F00);                       // Gluc
    final colorFat  = Color(0xFFCC79A7);  // Lip

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.multiline_chart, size: 18),
            const SizedBox(width: 6),
            Text("Part des macros (%)",
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.info_outline, size: 18),
              tooltip: "À propos de la part des macros",
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => _showMacroPctInfo(context),
            ),
            const Spacer(),
            DropdownButton<int>(
              value: days,
              items: const [30, 60, 90]
                  .map((d) => DropdownMenuItem(value: d, child: Text("$d j")))
                  .toList(),
              onChanged: (v) => ref.read(macroPctRangeDaysProvider.notifier).state = v ?? 60,
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: dataAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Erreur: $e")),
              data: (points) {
                final pts = (points.length > 4) ? points.sublist(4) : const <MacroPctPoint>[];
                if (pts.isEmpty) {
                  return const Center(child: Text("Pas assez de données pour une MM5"));
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
                final sFat  = toSpots((p) => p.fatPct);

                String xLabel(double v) {
                  final d = base.add(Duration(days: v.toInt()));
                  return "${d.day}/${d.month}";
                }

                // Lignes MM5 uniquement (pas de brute)
                
                final barProt = LineChartBarData(
                  spots: sProt, isCurved: true, barWidth: 3,
                  dotData: const FlDotData(show: false), color: colorProt,
                );
                final barCarb = LineChartBarData(
                  spots: sCarb, isCurved: true, barWidth: 3,
                  dotData: const FlDotData(show: false), color: colorCarb,
                );
                final barFat = LineChartBarData(
                  spots: sFat, isCurved: true, barWidth: 3,
                  dotData: const FlDotData(show: false), color: colorFat,
                );

                return LineChart(
                  LineChartData(
                    minY: 0, maxY: 100,
                    gridData: FlGridData(
                      show: true, drawVerticalLine: false, horizontalInterval: 25,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
                        strokeWidth: 1, dashArray: const [4, 6],
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true, reservedSize: 38, interval: 25,
                          getTitlesWidget: (v, _) {
                            final n = v.toInt();
                            if (n == 0 || n == 50 || n == 100) return Text("$n%");
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
                            child: Text(xLabel(v), style: const TextStyle(fontSize: 11)),
                          ),
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true, border: Border.all(color: Theme.of(context).dividerColor),
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
          Wrap(spacing: 16, children: [
             _legendSwatch(colorCarb, "Gluc"),
             _legendSwatch(colorProt, "Prot"),
            _legendSwatch(colorFat,  "Lip"),
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
                Text("À propos de la part des macros", style: t.titleMedium),
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
              "Ce graphique montre la part (%) de chaque macro dans le total des macros, "
              "après lissage en moyenne mobile 5 jours (MM5).",
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

}
