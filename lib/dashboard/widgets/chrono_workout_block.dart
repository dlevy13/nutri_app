// Ce widget affiche l'entraînement et ses fenêtres ///
// 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ChronoWorkoutBlock extends ConsumerWidget {
  final Map<String, dynamic> activityData;
  final List<Map<String, dynamic>> allDayMeals;

  const ChronoWorkoutBlock({
    required this.activityData,
    required this.allDayMeals,
    super.key,
  });

  // Fonction helper pour calculer les macros dans une fenêtre
  Map<String, double> _getMacrosInWindow(DateTime start, DateTime end) {
    double protein = 0;
    double carbs = 0;
    
    for (final meal in allDayMeals) {
      final mealTime = DateTime.tryParse(meal['timestamp'] as String? ?? '');
      if (mealTime != null && 
          mealTime.isAfter(start) && 
          mealTime.isBefore(end)) {
        
        final macros = meal['macros'] as Map<String, dynamic>? ?? {};
        protein += (macros['Protéines'] as num?)?.toDouble() ?? 0.0;
        carbs += (macros['Glucides'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return {'protein': protein, 'carbs': carbs};
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activityTime = DateTime.parse(activityData['start_date_local'] as String? ?? '');
    final durationSec = (activityData['elapsed_time'] as num?)?.toDouble() ?? 0.0;
    final durationMin = durationSec / 60;
    final activityEndTime = activityTime.add(Duration(seconds: durationSec.toInt()));
    final calories = (activityData['calories'] as num?)?.toDouble() ?? 0.0;
    final name = activityData['name'] as String? ?? 'Entraînement';
    final timeStr = DateFormat('HH:mm').format(activityTime);

    // 1. Définir les fenêtres
    final preFuelStart = activityTime.subtract(const Duration(hours: 2));
    final preFuelEnd = activityTime;
    final postRecoveryStart = activityEndTime;
    final postRecoveryEnd = activityEndTime.add(const Duration(minutes: 90));

    // 2. Calculer les macros
    final preFuelMacros = _getMacrosInWindow(preFuelStart, preFuelEnd);
    final double preCarbs = preFuelMacros['carbs'] ?? 0;
    
    final postRecoveryMacros = _getMacrosInWindow(postRecoveryStart, postRecoveryEnd);
    final double postProtein = postRecoveryMacros['protein'] ?? 0;
    final double postCarbs = postRecoveryMacros['carbs'] ?? 0;

    // 3. Définir le feedback
    final String preFuelFeedback = preCarbs < 30 ? '⚠️ Faible (Objectif: >30g)' : '✅ Ok';
    
    final String postFuelFeedback;
    if (postProtein < 20) {
      postFuelFeedback = '⚠️ Protéines faibles (<20g)';
    } else if (postCarbs < 20) {
      postFuelFeedback = '⚠️ Glucides faibles (<20g)';
    } else {
      final ratio = postCarbs / postProtein;
      postFuelFeedback = '✅ Ratio 1:${ratio.toStringAsFixed(1)}';
    }

    // 4. Construire le widget
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne d'en-tête de l'activité
          Row(
            children: [
              Text(
                timeStr,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.fitness_center_rounded, size: 20, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 60.0, top: 4),
            child: Text(
              '${durationMin.toStringAsFixed(0)} min / ${calories.toStringAsFixed(0)} kcal',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Fenêtre de Fuel (Pré-effort)
          _buildWindowRow(
            context,
            title: 'Fenêtre de Fuel',
            time: '${DateFormat('HH:mm').format(preFuelStart)} - ${DateFormat('HH:mm').format(preFuelEnd)}',
            data: '💡 Glucides: ${preCarbs.toStringAsFixed(0)}g',
            feedback: preFuelFeedback,
          ),
          
          const SizedBox(height: 16),

          // Fenêtre de Récupération (Post-effort)
          _buildWindowRow(
            context,
            title: 'Fenêtre de Récup.',
            time: '${DateFormat('HH:mm').format(postRecoveryStart)} - ${DateFormat('HH:mm').format(postRecoveryEnd)}',
            data: '⚡ Prot: ${postProtein.toStringAsFixed(0)}g / Gluc: ${postCarbs.toStringAsFixed(0)}g',
            feedback: postFuelFeedback,
          ),
        ],
      ),
    );
  }

  // Helper pour construire les lignes de fenêtre
  Widget _buildWindowRow(BuildContext context, {
    required String title,
    required String time,
    required String data,
    required String feedback,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 8), // Petit décalage
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(time, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                feedback,
                style: TextStyle(
                  fontSize: 12,
                  color: feedback.startsWith('✅') ? Colors.green.shade700 : Colors.orange.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}