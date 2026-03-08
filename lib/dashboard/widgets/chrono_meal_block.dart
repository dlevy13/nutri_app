// Ce widget affiche une simple ligne pour un repas. ///
// 

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChronoMealBlock extends StatelessWidget {
  final Map<String, dynamic> mealData;
  const ChronoMealBlock({required this.mealData, super.key});

  IconData _getIconForMealType(String mealType) {
    switch (mealType) {
      case 'Petit-déjeuner': return Icons.wb_sunny_rounded;
      case 'Déjeuner': return Icons.lunch_dining_rounded;
      case 'Dîner': return Icons.nightlight_round;
      case 'Collation': return Icons.apple_rounded;
      default: return Icons.restaurant_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = DateTime.tryParse(mealData['timestamp'] as String? ?? '');
    final name = mealData['mealType'] as String? ?? 'Repas';
    final calories = (mealData['calories'] as num?)?.toDouble() ?? 0.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            time != null ? DateFormat('HH:mm').format(time) : '--:--',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          Icon(_getIconForMealType(name), size: 20, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text(name, style: theme.textTheme.bodyLarge),
          const Spacer(),
          Text(
            '${calories.toStringAsFixed(0)} kcal',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}