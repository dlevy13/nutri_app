import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../training_planner/training_planner_notifier.dart';
import '../training_planner/training_planner_state.dart';

class TrainingPlannerPage extends ConsumerWidget {
  const TrainingPlannerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trainingPlannerProvider);
    final notifier = ref.read(trainingPlannerProvider.notifier);
    
    final List<String> activities = const ['Repos', 'Endurance', 'Intensité', 'Affûtage'];
    
    final now = DateTime.now();
    final mondayOfThisWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = mondayOfThisWeek.add(Duration(days: state.weekOffset * 7));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning d\'entraînement'),
        actions: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => notifier.changeWeek(-1)),
          IconButton(icon: const Icon(Icons.home), onPressed: () => notifier.resetToToday()),
          IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => notifier.changeWeek(1)),
          IconButton(icon: const Icon(Icons.sync), onPressed: () => notifier.reloadGarminEvents()),
        ],
      ),
      body: state.status == PlannerStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : state.status == PlannerStatus.failure
              ? const Center(child: Text("Erreur de chargement des données."))
              : ListView.builder(
                  itemCount: 7,
                  itemBuilder: (context, index) {
                    final date = startOfWeek.add(Duration(days: index));
                    final dayLabel = DateFormat.EEEE('fr_FR').format(date);
                    final formattedDate = DateFormat.MMMd('fr_FR').format(date);
                    final dayDisplay = "$dayLabel $formattedDate";
                    final dayKey = "${date.year}-${date.month}-${date.day}";

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(dayDisplay, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                                DropdownButton<String>(
                                  value: state.planning[dayKey] ?? 'Repos',
                                  items: activities.map((act) => DropdownMenuItem(value: act, child: Text(act))).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      notifier.selectActivity(dayKey, value);
                                    }
                                  },
                                ),
                              ],
                            ),
                            // ✅ ON APPELLE LE WIDGET D'AFFICHAGE DES ÉVÉNEMENTS ICI
                            _GarminEventsForDay(date: date),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

/// ✅ WIDGET DÉDIÉ À L'AFFICHAGE DES ÉVÉNEMENTS GARMIN POUR UN JOUR DONNÉ
class _GarminEventsForDay extends ConsumerWidget {
  final DateTime date;
  const _GarminEventsForDay({required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On écoute la liste complète des événements
    final allGarminEvents = ref.watch(trainingPlannerProvider.select((s) => s.garminEvents));

    // On filtre pour ne garder que les événements du jour concerné
    final eventsForDay = allGarminEvents.where((event) {
      final startDate = event['start'];
      return startDate != null &&
          startDate is DateTime &&
          startDate.year == date.year &&
          startDate.month == date.month &&
          startDate.day == date.day;
    }).toList();

    // Si pas d'événement, on n'affiche rien
    if (eventsForDay.isEmpty) {
      return const SizedBox.shrink();
    }

    // On construit la liste des événements à afficher
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: eventsForDay.map((event) {
          final summary = event['summary'] ?? 'Événement';
          final startTime = event['start'] as DateTime?;
          final timeStr = startTime != null ? DateFormat.Hm('fr_FR').format(startTime) : '';
          
          return Text("📅 $summary à $timeStr", style: const TextStyle(color: Colors.black54));
        }).toList(),
      ),
    );
  }
}