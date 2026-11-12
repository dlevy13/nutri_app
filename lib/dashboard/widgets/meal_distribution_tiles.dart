import 'package:flutter/material.dart';
import '../../ui/theme/app_theme.dart';

class MealDistributionTiles extends StatelessWidget {
  final Map<String, double> caloriesPerMeal;
  final ValueChanged<String> onOpenMeal;
  const MealDistributionTiles(
      {super.key, required this.caloriesPerMeal, required this.onOpenMeal});

  @override
  Widget build(BuildContext context) {
    const meals = {
      'Petit-déjeuner': Icons.wb_sunny_outlined,
      'Déjeuner': Icons.lunch_dining_outlined,
      'Dîner': Icons.nights_stay_outlined,
      'Collation': Icons.apple_outlined
    };
    return LayoutBuilder(builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final columns =
          (constraints.maxWidth / (190 * scale)).floor().clamp(1, 4);
      final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: meals.entries
              .map((entry) => SizedBox(
                    width: width,
                    child: Material(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => onOpenMeal(entry.key),
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Icon(entry.value, color: AppColors.green),
                                      const Spacer(),
                                      const Icon(
                                          Icons.add_circle_outline_rounded,
                                          color: AppColors.green)
                                    ]),
                                    const SizedBox(height: 12),
                                    Text(entry.key,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: 4),
                                    Text(
                                        '${(caloriesPerMeal[entry.key] ?? 0).toStringAsFixed(0)} kcal',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium),
                                  ])),
                        )),
                  ))
              .toList());
    });
  }
}
