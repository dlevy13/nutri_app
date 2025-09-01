
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard/dashboard_notifier.dart'; // Import pour le provider

class FatBreakdownCard extends ConsumerWidget {
  const FatBreakdownCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consumedMacros = ref.watch(dashboardProvider.select((s) => s.consumedMacros));
    final saturated = consumedMacros['Saturés'] ?? 0.0;
    final monounsaturated = consumedMacros['Monoinsaturés'] ?? 0.0;
    final polyunsaturated = consumedMacros['Polyinsaturés'] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Qualité des lipides",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // Barre de répartition
        FatBreakdownBar(
          saturated: saturated,
          monounsaturated: monounsaturated,
          polyunsaturated: polyunsaturated,
        ),
        const SizedBox(height: 12),
        // Légende
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildLegendItem(Colors.red.shade400, "Saturés", saturated),
            _buildLegendItem(Colors.green.shade400, "Monoinsaturés", monounsaturated),
            _buildLegendItem(Colors.blue.shade400, "Polyinsaturés", polyunsaturated),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, double value) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 6),
        Text(
          "$label (${value.toStringAsFixed(1)}g)",
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class FatBreakdownBar extends StatelessWidget {
  final double saturated;
  final double monounsaturated;
  final double polyunsaturated;

  const FatBreakdownBar({
    super.key,
    required this.saturated,
    required this.monounsaturated,
    required this.polyunsaturated,
  });

  @override
  Widget build(BuildContext context) {
    final totalFat = saturated + monounsaturated + polyunsaturated;

    if (totalFat == 0) {
      return Container(
        height: 16,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 16,
        child: Row(
          children: [
            if (saturated > 0)
              Expanded(
                flex: (saturated * 100).toInt(),
                child: Container(color: Colors.red.shade400),
              ),
            if (monounsaturated > 0)
              Expanded(
                flex: (monounsaturated * 100).toInt(),
                child: Container(color: Colors.green.shade400),
              ),
            if (polyunsaturated > 0)
              Expanded(
                flex: (polyunsaturated * 100).toInt(),
                child: Container(color: Colors.blue.shade400),
              ),
          ],
        ),
      ),
    );
  }
}