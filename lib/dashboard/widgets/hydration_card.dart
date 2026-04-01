import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard_notifier.dart';
import 'hydration_summary.dart';

class HydrationCard extends ConsumerWidget {
  const HydrationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dashboardProvider.notifier);
    final state = ref.watch(dashboardProvider);
    return HydrationSummary(
      goalMl: state.waterGoalMl,
      consumedMl: state.waterConsumedMl,
      onAdd: notifier.addWater,
      onRemove: notifier.removeWater,
    );
  }
}
