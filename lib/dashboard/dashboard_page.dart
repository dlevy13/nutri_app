import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../dashboard/dashboard_notifier.dart';
import '../dashboard/dashboard_state.dart';
import '../pages/profile_form_page.dart';
import '../pages/training_planner_page.dart';
import '../services/date_service.dart';
import '../services/feedback_utils.dart';
import '../courbe/bej_trends_page.dart';
import 'old_dashboard_page.dart';
import '../widget/section_title.dart';

// CARTES DU DASHBOARD
import 'widgets/energy_gauge_card.dart';
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

    // 1️⃣ Local immédiat
    await notifier.loadLocalData();

    // 2️⃣ Remote → local (Supabase → Hive)
    await notifier.hydrateLocalFromSupabase();

    // 3️⃣ Rebuild avec données complètes
    await notifier.loadLocalData();
  }
  

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);
    final cs = Theme.of(context).colorScheme;

      

    // État loading
    if (state.status == ViewStatus.loading && state.prenom.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // État erreur
    if (state.status == ViewStatus.failure) {
      return Scaffold(
        body: Center(child: Text('Erreur: ${state.errorMessage}')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          // Affichage prénom / accès profil
          if (state.prenom.isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileFormPage()),
                ).then((_) => notifier.loadLocalData());
              },
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    state.prenom,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileFormPage()),
                ).then((_) => notifier.loadLocalData());
              },
            ),
            IconButton(
              icon: const Icon(Icons.feedback_outlined),
              tooltip: 'Envoyer un feedback',
              onPressed: sendFeedbackEmail,
            ),


          const SizedBox(width: 8),
        ],
      ),

      floatingActionButton: SizedBox(
        height: 36,
        child: FloatingActionButton.extended(
          heroTag: 'fab-planning',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TrainingPlannerPage()),
            );
          },
          label: const Text(
            "Entraînement",
            style: TextStyle(fontSize: 11),
          ),
          icon: const Icon(Icons.calendar_today, size: 16),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          extendedPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: () => notifier.loadLocalData(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyWeekHeader(),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 12),

                  // ======= ÉNERGIE =======
                  ThemedSectionCard(
                    title: "Énergie & charge",
                    accent: cs.primary,
                    child: const EnergyGaugeCard(),
                  ),
                  const SizedBox(height: 20),

                  // ======= JOURNAL =======
                  ThemedSectionCard(
                    title: "Journal Nutrition",
                    accent: cs.primary.withValues(alpha: 0.35),
                    trailing: IconButton(
                      icon: const Icon(Icons.sync, size: 20),
                      tooltip: "Actualiser le journal",
                      onPressed: () {
                        ref.read(dashboardProvider.notifier).forceStravaSync();
                      },
                    ),
                    child: const ChronoLoggerCard(),
                  ),

                  const SizedBox(height: 20),

                  // ======= HYDRATATION =======
                  ThemedSectionCard(
                    title: "Hydratation",
                    accent: Colors.blue,
                    child: const HydrationCard(),
                  ),
                  const SizedBox(height: 20),

                  // ======= MACROS =======
                  ThemedSectionCard(
                    title: "Qualité nutritionnelle",
                    accent: Colors.green,
                    child: const MacroQualityRadar(),
                  ),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: _BottomNavBar(
        currentIndex: 0,
        selectedDate: state.selectedDate,
      ),

    );
  }
}

//
// ============================================================================
// SELECTEUR DE SEMAINE
// ============================================================================
class _WeekSelectorCompact extends ConsumerWidget {
  const _WeekSelectorCompact({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dashboardProvider.notifier);
    final state = ref.watch(dashboardProvider);
    final cs = Theme.of(context).colorScheme;

    final start = state.currentWeekStart;
    final weekDates = List.generate(7, (i) => start.add(Duration(days: i)));
    final selectedStr = DateService.formatStandard(state.selectedDate);

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Column(
          children: [
            // ---- Navigation semaine précédente / suivante ----
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => notifier.changeWeek(-1),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      "${DateService.formatStandard(weekDates.first)} → ${DateService.formatStandard(weekDates.last)}",
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => notifier.changeWeek(1),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: notifier.resetToToday,
                  icon: const Icon(Icons.home, size: 18),
                  label: const Text("Aujourd'hui"),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // ---- Sélection des jours ----
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: weekDates.map((d) {
                final key = DateService.formatStandard(d);
                final isSelected = key == selectedStr;
                final hasMeals = (state.weeklyMeals[key] ?? []).isNotEmpty;

                return GestureDetector(
                  onTap: () => notifier.selectDate(d),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('E', 'fr_FR').format(d).substring(0, 3),
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? cs.primary : null,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: isSelected ? 30 : 26,
                        height: isSelected ? 30 : 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? cs.primary
                              : (hasMeals
                                  ? cs.primaryContainer.withOpacity(.45)
                                  : cs.surfaceVariant),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "${d.day}",
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? cs.onPrimary : null,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class ThemedSectionCard extends StatelessWidget {
  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final String? title;
  final Widget? trailing;

  const ThemedSectionCard({
    super.key,
    required this.child,
    required this.accent,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bandeau coloré
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),

          if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}

// Sticky Header du haut
class _StickyWeekHeader extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 200;

  @override
  double get maxExtent => 220;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Material(
      color: bg,
      elevation: overlapsContent ? 1.5 : 0,
      shadowColor: Colors.black12,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SectionTitle("Semaine"),
            SizedBox(height: 8),
            _WeekSelectorCompact(),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyWeekHeader oldDelegate) => false;
}

//
// ============================================================================
// BOTTOM NAVIGATION
// ============================================================================
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final DateTime selectedDate;

  const _BottomNavBar({
    required this.currentIndex,
    required this.selectedDate,
  });


  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: NavigationBar(
        height: 64,
        selectedIndex: currentIndex,
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
        backgroundColor: Colors.white,
        indicatorColor: const Color(0x114B49D1),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.insights_rounded), label: 'Tendances'),
          NavigationDestination(icon: Icon(Icons.donut_small_rounded), label: 'Rapport'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}


