import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widget/card_shell.dart';
import '../dashboard_notifier.dart';

class EnergyGaugeCard extends ConsumerWidget {
  const EnergyGaugeCard({super.key});

  final double gaugeHeight = 150.0;
  final double gaugeWidth = 40.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final theme = Theme.of(context);

    // --- 1. RÉCUPÉRATION DES DONNÉES ---
    final double consumed = state.dailyCaloriesForDay?.total ?? 0.0;
    final double baseTdee = state.tdee;

    // 🔥 ACTIVITÉ UNIQUEMENT VIA HIVE → Strava
    final double activityKcalFinal = state.stravaCaloriesForDay;

    // Objectif total = Base + Activité
    final double totalGoal = baseTdee + activityKcalFinal;

    // --- 2. CALCUL DES PROPORTIONS ---
    final double baseRatio =
        totalGoal > 0 ? (baseTdee / totalGoal) : 1.0;

    final double bonusRatio =
        totalGoal > 0 ? (activityKcalFinal / totalGoal) : 0.0;

    // Hauteur du remplissage
    final double consumedHeight = (totalGoal > 0)
        ? (consumed / totalGoal * gaugeHeight).clamp(0.0, gaugeHeight)
        : 0.0;

    // Position de la ligne Base TDEE
    final double tdeeLineOffset = gaugeHeight * baseRatio;

    // --- 3. TEXTES ---
    final remaining = totalGoal - consumed;

    final String remainingText = remaining > 0
        ? "${remaining.toStringAsFixed(0)} kcal restantes"
        : "${(remaining.abs()).toStringAsFixed(0)} kcal en surplus";

    final Color remainingColor =
        remaining > 0 ? Colors.black54 : Colors.green.shade700;

    return CardShell(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // 🌡️ JAUGE GRAPHIQUE
          SizedBox(
            height: gaugeHeight,
            width: gaugeWidth,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // 1. FOND DE JAUGE (base + activité)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      // Activité (top)
                      Expanded(
                        flex: (bonusRatio * 100).toInt(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              topRight: Radius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      // Base TDEE (bottom)
                      Expanded(
                        flex: (baseRatio * 100).toInt(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. REMPLISSAGE consommation
                Container(
                  height: consumedHeight,
                  width: gaugeWidth,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C896),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                // 3. Ligne « Base TDEE »
                Positioned(
                  bottom: tdeeLineOffset - 1,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    color: Colors.orange,
                    child: Center(
                      child: Text(
                        '100%',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          // 🔤 TEXTE
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "JAUGE D'ÉNERGIE",
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.black54,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  consumed.toStringAsFixed(0),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF00C896),
                  ),
                ),
                Text(
                  "/ ${totalGoal.toStringAsFixed(0)} kcal",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                Text(
                  remainingText,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: remainingColor,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  "Base: ${baseTdee.toStringAsFixed(0)} kcal",
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                Text(
                  "Activité: ${activityKcalFinal.toStringAsFixed(0)} kcal",
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
