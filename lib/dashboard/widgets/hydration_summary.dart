import 'package:flutter/material.dart';
import '../../ui/theme/app_theme.dart';
import '../../widget/card_shell.dart';

class HydrationSummary extends StatelessWidget {
  final double goalMl;
  final double consumedMl;
  final ValueChanged<double> onAdd;
  final ValueChanged<double> onRemove;
  const HydrationSummary(
      {super.key,
      required this.goalMl,
      required this.consumedMl,
      required this.onAdd,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final progress = goalMl > 0 ? (consumedMl / goalMl).clamp(0.0, 1.0) : 0.0;
    final text = Theme.of(context).textTheme;
    return CardShell(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.water_drop_outlined, color: AppColors.blue),
        const SizedBox(width: 8),
        Expanded(child: Text('Mon hydratation', style: text.titleLarge)),
      ]),
      const SizedBox(height: 20),
      Text('${(consumedMl / 1000).toStringAsFixed(2)} L',
          style: text.headlineLarge?.copyWith(color: AppColors.blue)),
      Text(
          goalMl > 0
              ? 'sur ${(goalMl / 1000).toStringAsFixed(2)} L · ${(progress * 100).round()} % de l’objectif'
              : 'Objectif à définir',
          style: text.bodyMedium),
      const SizedBox(height: 16),
      LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          color: AppColors.blue,
          backgroundColor: const Color(0xFFE4F1F8),
          semanticsLabel: 'Hydratation : $consumedMl millilitres sur $goalMl'),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final amount in [250.0, 500.0])
          FilledButton.tonal(
              onPressed: () => onAdd(amount),
              style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: const Color(0xFFE4F1F8),
                  foregroundColor: AppColors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: Text('+ ${amount.toInt()} ml')),
        IconButton.outlined(
            tooltip: 'Retirer 250 ml',
            onPressed: consumedMl > 0 ? () => onRemove(250) : null,
            icon: const Icon(Icons.remove_rounded),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48)),
      ]),
    ]));
  }
}
