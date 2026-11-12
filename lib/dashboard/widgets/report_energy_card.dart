import 'package:flutter/material.dart';
import '../../ui/theme/app_theme.dart';

class ReportEnergyCard extends StatelessWidget {
  final double consumed, needed;
  const ReportEnergyCard(
      {super.key, required this.consumed, required this.needed});

  @override
  Widget build(BuildContext context) {
    final progress = needed > 0 ? (consumed / needed).clamp(0.0, 1.0) : 0.0;
    final text = Theme.of(context).textTheme;
    return Material(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(AppLayout.radius),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Row(children: [
              Icon(Icons.bolt_rounded, color: AppColors.lime),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Énergie du jour',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)))
            ]),
            const SizedBox(height: 16),
            Text('${consumed.toStringAsFixed(0)} kcal',
                style: text.headlineLarge?.copyWith(color: Colors.white)),
            Text(
                needed > 0
                    ? 'consommées · objectif ${needed.toStringAsFixed(0)} kcal'
                    : 'consommées · objectif à définir',
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 20),
            LinearProgressIndicator(
                value: progress,
                color: AppColors.lime,
                backgroundColor: Colors.white24,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                semanticsLabel: 'Progression vers l’objectif énergétique'),
          ]),
        ));
  }
}
