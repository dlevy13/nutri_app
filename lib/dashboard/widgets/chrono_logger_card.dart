/// Ce widget lit les entraînements pour afficher les bons boutons de saisie
/// ET affiche également les blocs d'entraînement.
// 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../services/date_service.dart';
import '../../widget/card_shell.dart';
import '../../widget/section_title.dart';
import '../../meal_input/meal_input_page.dart'; 
import '../dashboard_notifier.dart';
import '../../../models/meal.dart';

class ChronoLoggerCard extends ConsumerWidget {
  const ChronoLoggerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);

    final selectedDate = state.selectedDate;
    final y = selectedDate.year, m = selectedDate.month, d = selectedDate.day;
    final selectedDateStr = DateService.formatStandard(selectedDate);

    // 1) Repas déjà saisis
    final List<Meal> loggedMeals = state.weeklyMeals[selectedDateStr] ?? [];

    // 2) Activités Strava filtrées
    final allActivities = state.stravaActivitiesForDay;
    final activities = allActivities.where((act) {
      final calories = (act['calories'] as num?)?.toDouble() ?? 0.0;
      return calories > 200;
    }).toList();

    // 3) Slots de base — on sépare "label" d'affichage et "mealType" logique
    final baseSlots = <Map<String, dynamic>>[
      {
        'type': 'log_slot',
        'time': DateTime(y, m, d, 8, 0),
        'label': 'Petit-déjeuner',
        'mealType': 'Petit-déjeuner',
        'icon': Icons.wb_sunny_rounded,
      },
      {
        'type': 'log_slot',
        'time': DateTime(y, m, d, 12, 0),
        'label': 'Déjeuner',
        'mealType': 'Déjeuner',
        'icon': Icons.lunch_dining_rounded,
      },
      {
        'type': 'log_slot',
        'time': DateTime(y, m, d, 19, 0),
        'label': 'Dîner',
        'mealType': 'Dîner',
        'icon': Icons.nightlight_round,
      },
      {
        'type': 'log_slot',
        'time': DateTime(y, m, d, 21, 0),
        'label': 'Collation',
        'mealType': 'Collation',
        'icon': Icons.apple_rounded,
      },
    ];

    // 4) Ajout des slots "Récupération (Post-effort)" -> type de repas "Activité"
    final activityBlockItems = <Map<String, dynamic>>[];
{
  // On trie les activités par heure de début pour donner un groupId stable
  final actsSorted = [...activities]..sort((a, b) {
    final sa = DateTime.parse((a['start_date_local'] as String? ?? '').replaceAll('Z', ''));
    final sb = DateTime.parse((b['start_date_local'] as String? ?? '').replaceAll('Z', ''));
    return sa.compareTo(sb);
  });

  for (var i = 0; i < actsSorted.length; i++) {
    final act = actsSorted[i];
    final startIso = (act['start_date_local'] as String? ?? '').replaceAll('Z', '');
    final start = DateTime.parse(startIso);
    final durationSec = (act['elapsed_time'] as num?)?.toDouble() ?? 0.0;
    final end = start.add(Duration(seconds: durationSec.toInt()));
    final postRecovery = end.add(const Duration(minutes: 30));

    // Item "activité" (affiché avec l’heure)
    activityBlockItems.add({
      'type': 'activity_display',
      'time': start,                  // heure réelle de l’activité (affichage)
      'blockTime': start,             // clé de tri du bloc
      'groupId': i,                   // identifiant du bloc
      'groupOrder': 0,                // activité avant récupération
      'data': act,
    });

    // Item "récupération" (slot de saisie)
    activityBlockItems.add({
      'type': 'log_slot',
      'time': postRecovery,           // timestamp réel pour la saisie
      'blockTime': start,             // **clé de tri du bloc = début activité**
      'groupId': i,                   // même bloc
      'groupOrder': 1,                // après l’activité
      'label': 'Récupération (Post-effort)',
      'mealType': 'Activité',
      'icon': Icons.healing_rounded,
    });
  }
  }


    // 5) Fusion & tri (Petit-déj toujours avant toute activité du matin)
    final timeline = <Map<String, dynamic>>[
  ...baseSlots.map((m) => {
        ...m,
        'blockTime': m['time'],       // les slots "simples" se trient sur leur propre heure
        'groupId': null,
        'groupOrder': 0,
      }),
  ...activityBlockItems,              // déjà "groupés"
]..sort((a, b) {
    final taBlock = a['blockTime'] as DateTime;
    final tbBlock = b['blockTime'] as DateTime;

    // Règle spéciale : Petit-déj avant toute activité < 12:00
    final aIsBreakfast = a['type'] == 'log_slot' && (a['mealType'] == 'Petit-déjeuner');
    final bIsBreakfast = b['type'] == 'log_slot' && (b['mealType'] == 'Petit-déjeuner');
    final bIsMorningActBlock = b['groupId'] != null && tbBlock.hour < 12;
    final aIsMorningActBlock = a['groupId'] != null && taBlock.hour < 12;

    if (aIsBreakfast && bIsMorningActBlock) return -1;
    if (bIsBreakfast && aIsMorningActBlock) return 1;

    // 1) Trier par "blockTime" (début d’activité pour les blocs, heure du slot sinon)
    final cmpBlock = taBlock.compareTo(tbBlock);
    if (cmpBlock != 0) return cmpBlock;

    // 2) Si on est dans le même bloc activité → imposer activité (0) avant récup (1)
    final ga = a['groupId'];
    final gb = b['groupId'];
    if (ga != null && gb != null && ga == gb) {
      final oa = a['groupOrder'] as int;
      final ob = b['groupOrder'] as int;
      return oa.compareTo(ob);
    }

    // 3) Sinon : log_slot avant activity_display si heure bloc identique (cohérence UI)
    final ra = a['type'] == 'log_slot' ? 0 : 1;
    final rb = b['type'] == 'log_slot' ? 0 : 1;
    return ra.compareTo(rb);
});

    // 6) Vue (anti-overflow)
    return CardShell(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('📅 Saisie Chrono-Nutrition'),
          const SizedBox(height: 16),
          ...timeline.map((item) {
            if (item['type'] == 'log_slot') {
              final slotTime = item['time'] as DateTime;
              final label = item['label'] as String;       // affichage
              final mealType = item['mealType'] as String; // logique
              final mealsForThisSlot = loggedMeals.where((m) => m.type == mealType).toList();

              return _buildLogSlot(
                context: context,
                notifier: notifier,
                label: label,
                icon: item['icon'] as IconData,
                timestampToLog: slotTime,
                mealType: mealType,              // <- "Activité" pour post-effort
                mealsInSlot: mealsForThisSlot,
              );
            }

            if (item['type'] == 'activity_display') {
              return _buildActivityDisplay(
                context: context,
                activityTime: item['time'] as DateTime,
                activityData: item['data'] as Map<String, dynamic>,
              );
            }

            return const SizedBox.shrink();
          }).expand((w) => [w, const SizedBox(height: 12)]),
        ],
      ),
    );
  }

  // ————————————————————————————————————————————————————————————————
  // ACTIVITÉ (on garde l'heure visible pour les activités)
  Widget _buildActivityDisplay({
    required BuildContext context,
    required DateTime activityTime,
    required Map<String, dynamic> activityData,
  }) {
    final theme = Theme.of(context);
    final durationSec = (activityData['elapsed_time'] as num?)?.toDouble() ?? 0.0;
    final durationMin = durationSec / 60;
    final calories = (activityData['calories'] as num?)?.toDouble() ?? 0.0;
    final name = activityData['name'] as String? ?? 'Entraînement';
    final timeStr = DateFormat('HH:mm').format(activityTime);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.fitness_center_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$timeStr - $name',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${durationMin.toStringAsFixed(0)} min / ${calories.toStringAsFixed(0)} kcal',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.orange.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ————————————————————————————————————————————————————————————————
  // SLOT DE SAISIE (REPAS) — sans afficher l'heure
  Widget _buildLogSlot({
    required BuildContext context,
    required DashboardNotifier notifier,
    required String label,            // affichage
    required IconData icon,
    required DateTime timestampToLog, // on garde l'horodatage pour la saisie
    required String mealType,         // logique (ex. "Activité" pour post-effort)
    required List<Meal> mealsInSlot,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MealInputPage(
              selectedDate: DateService.formatStandard(timestampToLog),
              mealType: mealType,            // <- important : type logique
              fullTimestamp: timestampToLog,
            ),
          ),
        ).then((_) => notifier.refreshDataAfterMealUpdate());
      },
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1.0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne titre (sans heure)
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Colors.blueGrey),
              ],
            ),

            if (mealsInSlot.isNotEmpty) _buildMealSummary(mealsInSlot),
          ],
        ),
      ),
    );
  }

  // ————————————————————————————————————————————————————————————————
  // Résumé des repas d'un slot
  Widget _buildMealSummary(List<Meal> meals) {
    double totalKcal = 0, totalProt = 0, totalCarb = 0, totalFat = 0;
    for (final meal in meals) {
      totalKcal += meal.calories;
      totalProt += meal.protein;
      totalCarb += meal.carbs;
      totalFat += meal.fat;
    }
    return Padding(
      padding: const EdgeInsets.only(left: 28.0, top: 8, right: 8.0),
      child: Text(
        "${totalKcal.toStringAsFixed(0)} kcal (P: ${totalProt.toStringAsFixed(0)}g  G: ${totalCarb.toStringAsFixed(0)}g  L: ${totalFat.toStringAsFixed(0)}g)",
        style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
