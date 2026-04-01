import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../training_planner/training_planner_notifier.dart';
import 'widgets/training_planner_content.dart';

class TrainingPlannerPage extends ConsumerWidget {
  const TrainingPlannerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trainingPlannerProvider);
    final notifier = ref.read(trainingPlannerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Entraînements')),
      body: TrainingPlannerContent(
        state: state,
        today: DateTime.now(),
        onChangeWeek: notifier.changeWeek,
        onToday: notifier.resetToToday,
        onSync: notifier.reloadGarminEvents,
        onRetry: notifier.loadData,
        onSelectActivity: notifier.selectActivity,
      ),
    );
  }
}
