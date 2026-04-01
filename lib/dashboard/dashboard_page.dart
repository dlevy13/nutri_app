import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_notifier.dart';
import 'dashboard_state.dart';
import '../pages/profile_form_page.dart';
import '../pages/training_planner_page.dart';
import '../meal_input/meal_input_page.dart';
import '../services/date_service.dart';
import '../services/feedback_utils.dart';
import '../courbe/bej_trends_page.dart';
import 'old_dashboard_page.dart';
import 'widgets/dashboard_content.dart';
import '../widget/app_navigation_bar.dart';
import 'widgets/chrono_logger_card.dart';
import 'widgets/macro_quality_radar.dart';
import 'widgets/hydration_card.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_initDashboard);
  }

  Future<void> _initDashboard() async {
    ref.invalidate(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);
    await notifier.loadLocalData();
    if (!mounted) return;
    await notifier.hydrateLocalFromSupabase();
    if (!mounted) return;
    await notifier.loadLocalData();
  }

  Future<void> _openMeal(DateTime date) async {
    // Le choix du repas précède la saisie : la date consultée est conservée.
    final mealType = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Quel repas ajouter ?',
                style: Theme.of(context).textTheme.titleLarge)),
        for (final entry in const {
          'Petit-déjeuner': Icons.wb_sunny_outlined,
          'Déjeuner': Icons.lunch_dining_outlined,
          'Dîner': Icons.nights_stay_outlined,
          'Collation': Icons.apple_outlined,
        }.entries)
          ListTile(
              leading: Icon(entry.value),
              title: Text(entry.key),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pop(context, entry.key)),
      ])),
    );
    if (!mounted || mealType == null) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => MealInputPage(
                selectedDate: DateService.formatStandard(date),
                mealType: mealType)));
    if (mounted) await ref.read(dashboardProvider.notifier).loadLocalData();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);
    if (state.status == ViewStatus.loading && state.prenom.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.status == ViewStatus.failure) {
      return Scaffold(
          body: SafeArea(
              child: Center(
                  child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 16),
          const Text('Le tableau de bord est indisponible pour le moment.',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: () => notifier.loadLocalData(),
              child: const Text('Réessayer')),
        ]),
      ))));
    }
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset('assets/icons/nutriwatt_brand.png',
                  width: 40, height: 40, excludeFromSemantics: true)),
          const SizedBox(width: 10),
          const Text('NutriWatt',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          IconButton(
              tooltip: 'Envoyer un avis',
              onPressed: sendFeedbackEmail,
              icon: const Icon(Icons.chat_bubble_outline_rounded)),
          IconButton(
              tooltip: 'Mon profil',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfileFormPage()));
                if (mounted) await notifier.loadLocalData();
              }),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
          top: false,
          bottom: false,
          child: RefreshIndicator(
            onRefresh: notifier.loadLocalData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: DashboardContent(
                state: state,
                journal: const ChronoLoggerCard(),
                hydration: const HydrationCard(),
                quality: const MacroQualityRadar(embedded: true),
                onAddMeal: () => _openMeal(state.selectedDate),
                onTraining: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TrainingPlannerPage()));
                  if (mounted) await notifier.loadLocalData();
                },
                onToday: notifier.resetToToday,
                onChangeWeek: notifier.changeWeek,
                onSelectDate: notifier.selectDate,
                onSync: notifier.forceStravaSync,
              ),
            ),
          )),
      bottomNavigationBar:
          _BottomNavBar(currentIndex: 0, selectedDate: state.selectedDate),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final DateTime selectedDate;

  const _BottomNavBar({
    required this.currentIndex,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    return AppNavigationBar(
      currentIndex: currentIndex,
      onDestinationSelected: (i) {
        switch (i) {
          case 0:
            Navigator.popUntil(context, (route) => route.isFirst);
            break;

          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BejTrendsPage()),
            );
            break;

          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OldDashboardPage(
                  selectedDate: selectedDate, // Date déjà choisie
                ),
              ),
            );

            break;

          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileFormPage()),
            );
            break;
        }
      },
    );
  }
}
