
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard/dashboard_notifier.dart'; // Import pour le provider

//// WIDGET plus utilisé car on n'a pas toujours l'info sur les mono et poly insaturés
class FatBreakdownCard extends ConsumerWidget {
  const FatBreakdownCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consumedMacros = ref.watch(dashboardProvider.select((s) => s.consumedMacros));
    // ✅ On récupère le total "officiel" des lipides
    final totalFat = consumedMacros['Lipides'] ?? 0.0;
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
          // ✅ On passe le total officiel à la barre
          totalFat: totalFat,
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
  // ✅ On ajoute `totalFat` aux paramètres
  final double totalFat;
  final double saturated;
  final double monounsaturated;
  final double polyunsaturated;

  const FatBreakdownBar({
    super.key,
    required this.totalFat,
    required this.saturated,
    required this.monounsaturated,
    required this.polyunsaturated,
  });

  @override
  Widget build(BuildContext context) {
    // On n'a plus besoin de recalculer le total ici
    if (totalFat == 0) {
      return Container(
        height: 16,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    // On calcule la part "autre" (lipides non classifiés)
    final other = totalFat - saturated - monounsaturated - polyunsaturated;

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
            // ✅ On ajoute un segment gris pour les lipides non classifiés
            if (other > 0.1) // Seuil pour éviter les micro-barres dues aux arrondis
              Expanded(
                flex: (other * 100).toInt(),
                child: Container(color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }
}