import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../meal_input/meal_input_page.dart';
import '../models/meal.dart';
import '../pages/profile_form_page.dart';
import '../pages/training_planner_page.dart';
import '../services/date_service.dart';
import '../repositories/strava_repository.dart';
import '../dashboard/dashboard_notifier.dart';
import '../dashboard/dashboard_state.dart';
import '../widget/ai_analysis_card.dart';
import '../dashboard/widgets/food_analysis_section.dart';
import '../courbe/bej_trends_page.dart';
import '../ui/strings.dart';
import 'package:firebase_auth/firebase_auth.dart';

//refonte
class OldDashboardPage extends ConsumerWidget {
  final DateTime selectedDate;

  const OldDashboardPage({
    super.key,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifier.selectDate(selectedDate);
    });


    if (state.status == ViewStatus.loading && state.prenom.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.status == ViewStatus.failure) {
      return Scaffold(
        body: Center(child: Text('Erreur: ${state.errorMessage}')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false, // 👈 IMPORTANT pour l’alignement iOS
        titleSpacing: 0,    // 👈 colle le titre à gauche
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Rapport du ${DateService.formatFrenchShort(state.selectedDate)}",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(width: 8),

                // 🏷️ Badge "Aujourd’hui"
                if (DateUtils.isSameDay(state.selectedDate, DateTime.now()))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FF), // bleu très clair
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "Aujourd’hui",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B49D1), // bleu NutriWatt
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
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
              tooltip: 'Profil',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileFormPage()),
                ).then((_) => notifier.loadLocalData());
              },
            ),

          const SizedBox(width: 8),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: () => notifier.loadLocalData(),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [

            // === HERO CALORIES (nouveau) ===
            const _HeroCaloriesCard(),
            const SizedBox(height: 16),

           // === NUTRITION DU JOUR (Dépliable) ===
            const _ExpandableNutritionSection(),
            const SizedBox(height: 16),
            
            // +++ NOTRE NOUVELLE SECTION +++
            const FoodAnalysisSection(), // <-- On appelle le widget public
            const SizedBox(height: 16),

            // === ACTIVITÉ & ENTRAÎNEMENT (Dépliable) ===
            const _ExpandableActivitySection(),
            const SizedBox(height: 16),

            // === RÉPARTITION DES REPAS (Dépliable) ===
            const _ExpandableMealSection(), // <-- Le NOUVEAU widget
            const SizedBox(height: 24),

            // === TES SECTIONS / GRAPHIQUES EXISTANTS (inchangés) ===
           
            //const SizedBox(height: 16),
            //const _CalorieSummaryDetailed(),
            //const SizedBox(height: 32),
            
            _AiAnalysisCard(),
           
           
          ],
                  ),
      ),
      bottomNavigationBar: _BottomNavBar(
    currentIndex: 0, // 0 = Dashboard
    onTap: (i) {
      switch (i) {
        case 0:
          // déjà sur Dashboard
          break;
        case 1:
          // TODO: ouvrir ta page "Graphiques"
          // Navigator.push(context, MaterialPageRoute(builder: (_) => const BejTrendsPage()));
          break;
        case 2:
          // TODO: ouvrir ta page "Repas" (si tu en as une)
          // Navigator.push(context, MaterialPageRoute(builder: (_) => const MealsPage()));
          break;
        case 3:
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileFormPage()));
          break;
      }
    },
  ),

);
    
  }
}

// ===========================================================================
// == WIDGETS D'UI SPÉCIALISÉS (RESTANTS)
// ===========================================================================

class _WeekSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dashboardProvider.notifier);
    final currentWeekStart =
        ref.watch(dashboardProvider.select((s) => s.currentWeekStart));
    final selectedDate =
        ref.watch(dashboardProvider.select((s) => s.selectedDate));
    final weeklyMeals =
        ref.watch(dashboardProvider.select((s) => s.weeklyMeals));

    final weekDates =
        List.generate(7, (i) => currentWeekStart.add(Duration(days: i)));

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => notifier.changeWeek(-1)),
            Text(
              "${DateService.formatStandard(weekDates.first)} → ${DateService.formatStandard(weekDates.last)}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => notifier.changeWeek(1)),
            IconButton(
                icon: const Icon(Icons.home),
                onPressed: () => notifier.resetToToday(),
                tooltip: "Aujourd'hui"),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDates.map((date) {
            final dateStr = DateService.formatStandard(date);
            final isSelected = dateStr == DateService.formatStandard(selectedDate);
            final hasMeals = (weeklyMeals[dateStr] ?? []).isNotEmpty;
            return GestureDetector(
              onTap: () => notifier.selectDate(date),
              child: Column(
                children: [
                  Text(DateFormat('E', 'fr_FR').format(date).substring(0, 3)),
                  const SizedBox(height: 4),
                  CircleAvatar(
                    radius: isSelected ? 14 : 12,
                    backgroundColor: isSelected
                        ? Theme.of(context).primaryColor
                        : (hasMeals
                            ? Colors.green.shade200
                            : Colors.grey.shade300),
                    child: Text(
                      date.day.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}




class _CalorieSummaryDetailed extends ConsumerWidget {
  const _CalorieSummaryDetailed({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consumed =
        ref.watch(dashboardProvider.select((s) => s.consumedMacros['Calories'] ?? 0));
    final neededWithStrava =
        ref.watch(dashboardProvider.select((s) => s.macroNeeds['Calories'] ?? 0));
    final neededWithoutStrava =
        ref.watch(dashboardProvider.select((s) => s.tdee));
    final stravaCals =
        ref.watch(dashboardProvider.select((s) => s.stravaCaloriesForDay));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Résumé textuel
        Text(
          stravaCals > 0
              ? "Nécessaires : ${neededWithStrava.toStringAsFixed(0)} Kcal\n"
                "🔥 ${stravaCals.toStringAsFixed(0)} Kcal d'activité"
              : "Nécessaires : ${neededWithStrava.toStringAsFixed(0)} Kcal",
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 24),

        LayoutBuilder(
          builder: (context, constraints) {
            final double consomme = consumed;
            final double totalNecessaire = neededWithStrava;
            final double objectifSansStrava = neededWithoutStrava;
            final bool afficherOrange = stravaCals > 0;

            final double largeurTotale = constraints.maxWidth;
            const double targetPositionRatio = 0.75;
            final double traitRougePos = largeurTotale * targetPositionRatio;
            final double traitOrangePos = (afficherOrange && totalNecessaire > 0)
                ? (objectifSansStrava / totalNecessaire) * traitRougePos
                : 0;
            final double widthVert = (totalNecessaire > 0)
                ? (consomme / totalNecessaire) * traitRougePos
                : 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 50,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Fond gris
                      Container(
                        height: 24,
                        width: largeurTotale,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      // Barre verte (consommation)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        height: 24,
                        width: widthVert.clamp(0, largeurTotale),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 133, 194, 234),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      // Texte sur la barre
                      if (widthVert > 40)
                        Positioned(
                          left: (widthVert / 2 - 25).clamp(0, largeurTotale - 50),
                          top: 3,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: 1.0,
                            child: Text(
                              "${consomme.toStringAsFixed(0)} kcal",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // Trait orange (TDEE sans Strava)
                      if (afficherOrange)
                        Positioned(
                          left: traitOrangePos - 1,
                          top: 0,
                          height: 24,
                          child: Container(width: 2, color: Colors.orange),
                        ),
                      // Trait rouge (objectif total)
                      Positioned(
                        left: traitRougePos - 1,
                        top: 0,
                        height: 24,
                        child: Container(width: 2, color: Colors.red),
                      ),
                      // Labels
                      if (afficherOrange)
                        Positioned(
                          left: traitOrangePos - 30,
                          top: 30,
                          child: Text(
                            "${objectifSansStrava.toStringAsFixed(0)} kcal",
                            style: const TextStyle(
                              color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      Positioned(
                        left: traitRougePos - 30,
                        top: -18,
                        child: Text(
                          "${totalNecessaire.toStringAsFixed(0)} kcal",
                          style: const TextStyle(
                            color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // ↓↓↓ Bouton pour la page courbe BEJ ↓↓↓
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.speed, size: 18), // icône "compteur"
                    label: const Text(L10n.seeCalometre, style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BejTrendsPage()));
                    },
                  ),
                )

              ],
            );
          },
        ),
      ],
    );
  }
}






class _MacroDetailsDetailed extends ConsumerWidget {
  const _MacroDetailsDetailed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consumed =
        ref.watch(dashboardProvider.select((s) => s.consumedMacros));
    final needed = ref.watch(dashboardProvider.select((s) => s.macroNeeds));

    final repas = ["Petit-déjeuner", "Déjeuner", "Dîner", "Collation"];
    final colorsRepas = [
      Colors.orange,
      Colors.green,
      Colors.blue,
      Colors.purple
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Détail des apports par repas",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        for (final macro in ["Protéines", "Glucides", "Lipides"])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    // ✅ La logique est maintenant dans un switch pour plus de clarté
                    switch (macro) {
                      case "Lipides":
                        final totalFat = consumed['Lipides'] ?? 0.0;
                        final saturatedFat = consumed['Saturés'] ?? 0.0;
                        final percentage = totalFat > 0 ? (saturatedFat / totalFat) * 100 : 0.0;
                        return Text(
                          "Lipides : ${totalFat.toStringAsFixed(0)} g (${percentage.toStringAsFixed(0)}% sat.) / ${(needed['Lipides'] ?? 0).toStringAsFixed(0)} g",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        );

                      case "Glucides":
                        final totalCarbs = consumed['Glucides'] ?? 0.0;
                        final totalSugars = consumed['Sucres'] ?? 0.0; // Assurez-vous que la clé "Sucres" existe
                        final percentage = totalCarbs > 0 ? (totalSugars / totalCarbs) * 100 : 0.0;
                        return Text(
                          "Glucides : ${totalCarbs.toStringAsFixed(0)} g (${percentage.toStringAsFixed(0)}% sucres) / ${(needed['Glucides'] ?? 0).toStringAsFixed(0)} g",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        );

                      default: // Cas pour "Protéines"
                        return Text(
                          "$macro : ${(consumed[macro] ?? 0).toStringAsFixed(0)} g / ${(needed[macro] ?? 0).toStringAsFixed(0)} g",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                    }
                  },
                ),
                const SizedBox(height: 8),
                _MacroBreakdownBar(macro: macro),
              ],
            ),
          ),

        // La légende des couleurs (inchangée)
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (int i = 0; i < repas.length; i++)
              Row(
                children: [
                  Container(width: 12, height: 12, color: colorsRepas[i]),
                  const SizedBox(width: 4),
                  Text(repas[i], style: const TextStyle(fontSize: 12)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
// ===========================================================================
// == WIDGET POUR LA SECTION NUTRITION DÉPLIABLE
// ===========================================================================

class _ExpandableNutritionSection extends ConsumerStatefulWidget {
  const _ExpandableNutritionSection({super.key});

  @override
  ConsumerState<_ExpandableNutritionSection> createState() =>
      _ExpandableNutritionSectionState();
}

class _ExpandableNutritionSectionState
    extends ConsumerState<_ExpandableNutritionSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- 1. Le Titre (extérieur) ---
        // On utilise le widget public `SectionTitle`
        const SectionTitle('Nutrition du jour'),
        const SizedBox(height: 10),

        // --- 2. Le CONTENEUR (fond blanc) ---
        // On utilise le widget public `CardShell`
        CardShell(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // --- Le résumé des macros (maintenant sans fond propre) ---
              const _NutritionSummaryCard(),

              // --- 3. La flèche "Déplier" (si c'est replié) ---
              if (!_isExpanded)
                Align(
                  alignment: Alignment.center,
                  child: IconButton(
                    icon: const Icon(Icons.expand_more, color: Colors.blueGrey, size: 28),
                    tooltip: "Afficher le détail des calories",
                    onPressed: () {
                      setState(() {
                        _isExpanded = true;
                      });
                    },
                  ),
                ),

              // --- 4. Le contenu dépliable (Graphique calories) ---
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Container(
                  child: _isExpanded
                      ? _buildExpandedContent()
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Construit le graphique Calories + la flèche "Replier"
  Widget _buildExpandedContent() {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),

        // --- Le graphique détaillé des macros ---
        const _MacroDetailsDetailed(),
        
        // --- Les listes d'aliments ont été retirées d'ici ---
        
        // --- Flèche "Replier" ---
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.center,
          child: IconButton(
            icon: const Icon(Icons.expand_less, color: Colors.blueGrey, size: 28),
            tooltip: "Replier",
            onPressed: () {
              setState(() {
                _isExpanded = false;
              });
            },
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// == LES WIDGETS D'ANALYSE D'ALIMENTS ONT ÉTÉ DÉPLACÉS
// == VERS `food_analysis_section.dart`
// ===========================================================================


class _MacroBreakdownBar extends ConsumerWidget {
  final String macro;
  const _MacroBreakdownBar({required this.macro});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On récupère les données
    final macrosPerMealType =
        ref.watch(dashboardProvider.select((s) => s.macrosPerMealType));
    
    final macroMap = macrosPerMealType[macro] ?? {};
    final totalMacro = macroMap.values.fold(0.0, (a, b) => a + b);
    // Si le total est à zéro, on affiche une simple barre grise
    if (totalMacro == 0) {
      return Container(
        height: 12,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }
    
    final repas = ["Petit-déjeuner", "Déjeuner", "Dîner", "Collation"];
    final colorsRepas = [
      Colors.orange,
      Colors.green,
      Colors.blue,
      Colors.purple
    ];

    // ✅ ON UTILISE UN ROW AVEC DES EXPANDED
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 12,
        child: Row(
          children: List.generate(repas.length, (i) {
            final repasName = repas[i];
            final value = macroMap[repasName] ?? 0;
            
            // Le `flex` détermine la proportion de chaque segment.
            // On utilise la valeur du macro directement.
            return Expanded(
              flex: (value * 100).toInt(), // flex a besoin d'un int
              child: Container(
                color: colorsRepas[i],
              ),
            );
          }),
        ),
      ),
    );
  }
}



class _AiAnalysisCard extends ConsumerWidget {
  const _AiAnalysisCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(dashboardProvider.select((s) => s.analysisStatus));
    final isWeekly = ref.watch(dashboardProvider.select((s) => s.isWeeklyAnalysis));

    // ✅ Présence d’analyses (jour/semaine)
    final hasDaily = ref.watch(dashboardProvider.select(
      (s) => s.aiAnalysis.trim().isNotEmpty,
    ));
    final hasWeekly = ref.watch(dashboardProvider.select(
      (s) => s.weeklyAiAnalysis.trim().isNotEmpty,
    ));

    final analysisText = ref.watch(dashboardProvider.select(
      (s) => s.isWeeklyAnalysis ? s.weeklyAiAnalysis : s.aiAnalysis,
    ));

    final expanded = ref.watch(dashboardProvider.select(
      (s) => s.isWeeklyAnalysis ? s.isWeeklyExpanded : s.isDailyExpanded,
    ));

    final notifier = ref.read(dashboardProvider.notifier);

    // ───────────────── Header (contrôles) ─────────────────
    final controls = Card(
  elevation: 2,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        // 🧠 Titre (flexible → évite overflow)
        Expanded(
          child: Text(
            "🤖 Analyse IA",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(width: 12),

        // ===== MODE JOUR =====
        const Text("Jour"),
        AnimatedOpacity(
          opacity: hasDaily ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 18,
            ),
          ),
        ),

        /*
        // ===== SWITCH + MODE SEMAINE (désactivé pour l’instant) =====

        const SizedBox(width: 8),

        Switch(
          value: isWeekly,
          onChanged: (v) => notifier.setAnalysisType(v),
        ),

        const Text("Semaine"),
        AnimatedOpacity(
          opacity: hasWeekly ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 18,
            ),
          ),
        ),
        */
      ],
    ),
  ),
);


    // ───────────────── Corps (carte + bouton) ─────────────────
    final noAnalysisYet = analysisText.trim().isEmpty;
    final showLaunchButton = (noAnalysisYet || status == ViewStatus.failure) && status != ViewStatus.loading;

    Widget body;

    if (showLaunchButton) {
      // 🔹 Pas encore d’analyse → bouton centré
      body = Center(
        child: ElevatedButton.icon(
          onPressed: () => notifier.runMealAnalysis(force: true),
          icon: const Icon(Icons.play_arrow),
          label: const Text("Lancer l’analyse"),
        ),
      );
    } else {
      // 🔹 Analyse disponible → carte + bouton “Relancer” en bas à droite du cadre
      final card = AiAnalysisCard(
        title: "🤖 Analyse IA — ${isWeekly ? 'Semaine' : 'Jour'}",
        content: analysisText,
        expanded: expanded,
        onToggle: () => isWeekly
            ? notifier.toggleWeeklyExpanded()
            : notifier.toggleDailyExpanded(),
        isLoading: status == ViewStatus.loading,
        error: status == ViewStatus.failure
            ? (ref.read(dashboardProvider).errorMessage?.isNotEmpty == true
                ? ref.read(dashboardProvider).errorMessage
                : "Erreur lors de l’analyse")
            : null,
        collapsedLines: 4,
      );

      body = Stack(
        children: [
          // La carte d’analyse
          card,

          // Bouton en bas à droite du cadre (caché si en cours de chargement)
          if (status != ViewStatus.loading)
            Positioned(
              right: 16,
              bottom: 16,
              child: ElevatedButton.icon(
                onPressed: () => notifier.runMealAnalysis(force: true),
                icon: const Icon(Icons.refresh),
                label: const Text("Relancer l’analyse"),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        controls,
        const SizedBox(height: 8),
        body,
      ],
    );
  }
}



class _StravaActivitiesList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(
      dashboardProvider.select((s) => s.stravaActivitiesForDay),
    );

    final isConnected = ref.watch(
      dashboardProvider.select((s) => s.isStravaConnected),
    );

    final stravaService = ref.read(stravaServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CAS 1 : Non connecté → bouton Strava
        if (!isConnected)
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text("Se connecter à Strava"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFC4C02),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final uid = FirebaseAuth.instance.currentUser?.uid;

                if (uid == null) {
                  // Optionnel mais propre : éviter un crash si non connecté Firebase
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Veuillez vous connecter d'abord.")),
                  );
                  return;
                }

                await stravaService.launchAuthUrl(uid);
              },
            ),
          )

        // CAS 2 : Connecté mais pas d'activité
        else if (activities.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Aucune activité Strava pour ce jour."),
          )

        // CAS 3 : Activités trouvées
        else
          Column(
            children: activities.map((act) {
              final distanceInKm =
                  ((act["distance"] as num?)?.toDouble() ?? 0.0) / 1000;
              final calories = (act["calories"] as num?)?.toDouble() ?? 0.0;
              final date = DateTime.parse(act["start_date_local"]);

              return ListTile(
                leading: const Icon(Icons.directions_run, color: Colors.orange),
                title: Text(act["name"] ?? "Activité"),
                subtitle: Text(
                  "${DateService.formatFrenchShort(date)} • "
                  "${distanceInKm.toStringAsFixed(2)} km • "
                  "${calories.toStringAsFixed(0)} kcal",
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}


// ===========================================================================
// == LES WIDGETS SECTIONTITLE ET CARDSHELL ONT ÉTÉ DÉPLACÉS
// == VERS `food_analysis_section.dart`
// ===========================================================================


class _HeroCaloriesCard extends ConsumerWidget {
  const _HeroCaloriesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consumed = ref.watch(dashboardProvider.select((s) => (s.consumedMacros['Calories'] ?? 0).toDouble()));
    final needed   = ref.watch(dashboardProvider.select((s) => (s.macroNeeds['Calories'] ?? 0).toDouble()));
    final progress = (needed > 0) ? (consumed / needed).clamp(0.0, 1.0) : 0.0;

    // On utilise le widget public `CardShell`
    return CardShell(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4B49D1), Color(0xFF26256B)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${consumed.toStringAsFixed(0)} kcal',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                  const SizedBox(height: 4),
                  Text('consommées · Objectif : ${needed.toStringAsFixed(0)} kcal',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9))),
                ],
              ),
            ),
            SizedBox(
              height: 60, width: 60,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress, strokeWidth: 8,
                    backgroundColor: Colors.white.withOpacity(0.18),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF00C896)),
                  ),
                  Center(
                    child: Text('${(progress*100).round()}%',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _NutritionSummaryCard extends ConsumerWidget {
  const _NutritionSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consumed = ref.watch(dashboardProvider.select((s) => s.consumedMacros));
    final needs    = ref.watch(dashboardProvider.select((s) => s.macroNeeds));

    Widget row(String label, IconData icon, Color color) {
      final val = (consumed[label] ?? 0).toDouble();
      final goal = (needs[label] ?? 0).toDouble();
      final ratio = goal > 0 ? (val / goal).clamp(0.0, 1.0) : 0.0;
      final unit = 'g';

      return Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
                  Text('${val.toStringAsFixed(0)}$unit / ${goal.toStringAsFixed(0)}$unit',
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: ratio, minHeight: 10, color: color, backgroundColor: const Color(0xFFEAECEF),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // === MODIFICATION ===
    // Le _CardShell a été retiré. On retourne le Column directement.
    return Column(
      children: [
        row('Protéines', Icons.eco_rounded, const Color(0xFF00C896)),
        const SizedBox(height: 12),
        row('Glucides', Icons.bolt_rounded, const Color(0xFF2F80ED)),
        const SizedBox(height: 12),
        row('Lipides', Icons.water_drop_rounded, const Color(0xFFFF9F43)),
        const SizedBox(height: 12),
        row('Fibres', Icons.grass_rounded, const Color(0xFF7D5FFF)),
      ],
    );
  }
}
class _ActivityCompactCard extends ConsumerWidget {
  const _ActivityCompactCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stravaCals = ref.watch(dashboardProvider.select((s) => (s.stravaCaloriesForDay).toDouble()));

    // === MODIFICATION ===
    // On retourne la Row directement. Le _CardShell a été retiré
    // car il est maintenant géré par _ExpandableActivitySection.
    return Row(
      children: [
        const Icon(Icons.fitness_center_rounded),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Entraînement du jour',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                stravaCals > 0
                    ? 'Activité détectée : ${stravaCals.toStringAsFixed(0)} kcal'
                    : 'Aucune activité détectée',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const TrainingPlannerPage())),
          icon: const Icon(Icons.calendar_today, size: 18),
          label: const Text('Planifier'),
        )
      ],
    );
  }
}
// ===========================================================================
// == WIDGET POUR LA SECTION REPAS DÉPLIABLE
// ===========================================================================

class _ExpandableMealSection extends ConsumerStatefulWidget {
  const _ExpandableMealSection({super.key});

  @override
  ConsumerState<_ExpandableMealSection> createState() =>
      _ExpandableMealSectionState();
}
// ===========================================================================
// == WIDGET POUR LA SECTION ACTIVITÉ DÉPLIABLE
// ===========================================================================

class _ExpandableActivitySection extends ConsumerStatefulWidget {
  const _ExpandableActivitySection({super.key});

  @override
  ConsumerState<_ExpandableActivitySection> createState() =>
      _ExpandableActivitySectionState();
}

class _ExpandableActivitySectionState
    extends ConsumerState<_ExpandableActivitySection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- 1. Le Titre (extérieur) ---
        // On utilise le widget public `SectionTitle`
        const SectionTitle('Activité & Entraînement'),
        const SizedBox(height: 10),

        // --- 2. Le CONTENEUR (fond blanc) ---
        // On utilise le widget public `CardShell`
        CardShell(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // --- La carte compacte (maintenant sans fond propre) ---
              const _ActivityCompactCard(),

              // --- 3. La flèche "Déplier" (si c'est replié) ---
              if (!_isExpanded)
                Align(
                  alignment: Alignment.center,
                  child: IconButton(
                    icon: const Icon(Icons.expand_more, color: Colors.blueGrey, size: 28),
                    tooltip: "Afficher les activités Strava",
                    onPressed: () {
                      setState(() {
                        _isExpanded = true;
                      });
                    },
                  ),
                ),

              // --- 4. Le contenu dépliable (Liste Strava) ---
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Container(
                  child: _isExpanded
                      ? _buildExpandedContent()
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Construit le contenu de la liste Strava + la flèche "Replier"
  Widget _buildExpandedContent() {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),

        // --- La liste Strava (maintenant sans son titre) ---
        _StravaActivitiesList(),
        
        // --- Flèche "Replier" ---
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.center,
          child: IconButton(
            icon: const Icon(Icons.expand_less, color: Colors.blueGrey, size: 28),
            tooltip: "Replier",
            onPressed: () {
              setState(() {
                _isExpanded = false;
              });
            },
          ),
        ),
      ],
    );
  }
}

class _ExpandableMealSectionState extends ConsumerState<_ExpandableMealSection> {
  bool _isExpanded = false;

  // --- Helpers copiés depuis _MealCalorieBreakdown ---

  // Fonction utilitaire pour les couleurs
  Color _getColorForRepas(String repas) {
    switch (repas) {
      case 'Petit-déjeuner':
        return const Color.fromARGB(255, 184, 167, 141);
      case 'Déjeuner':
        return Colors.green;
      case 'Dîner':
        return Colors.blue;
      case 'Collation':
        return Colors.purple;
      case 'Activité':
        return const Color.fromARGB(255, 233, 115, 107);
      default:
        return Colors.grey;
    }
  }

  void _openMealInput(String repas, DashboardState state, DashboardNotifier notifier) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MealInputPage(
          selectedDate: DateService.formatStandard(state.selectedDate),
          mealType: repas,
        ),
      ),
    ).then((_) => notifier.refreshDataAfterMealUpdate());
  }

  // --- Fin des helpers ---

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- 1. Le Titre avec l'icône pour déplier ---
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // On utilise le widget public `SectionTitle`
            SectionTitle('Répartition des repas'),
            // Le IconButton a été retiré d'ici
          ],
        ),
        const SizedBox(height: 10),

        // --- 2. Le NOUVEAU CONTENEUR (fond blanc) ---
        // On utilise le widget public `CardShell`
        CardShell(
          padding: const EdgeInsets.all(16.0), // On met le padding ici
          child: Column(
            children: [
              // --- La grille (qui n'a plus son propre fond) ---
              const _MealsSplitCard(),
              if (!_isExpanded)
                Align(
                  alignment: Alignment.center,
                  child: IconButton(
                    icon: const Icon(Icons.expand_more, color: Colors.blueGrey, size: 28),
                    tooltip: "Afficher la répartition détaillée",
                    onPressed: () {
                      setState(() {
                        _isExpanded = true;
                      });
                    },
                  ),
                ),
              // --- Le contenu dépliable (Réel vs Théorique) ---
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Container(
                  // Le 'if' contrôle si le contenu est construit ou non
                  child:
                      _isExpanded ? _buildExpandedContent() : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // C'est le contenu de votre ancien widget _MealCalorieBreakdown
  Widget _buildExpandedContent() {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);

    // On récupère toutes les données nécessaires depuis l'état
    final totalNeededKcal = state.macroNeeds['Calories'] ?? 0;
    final totalConsumedKcal = state.consumedMacros['Calories'] ?? 0;
    final ratios = state.theoreticalCalorieSplit;
    final consumedPerMeal = state.caloriesPerMeal;
    final stravaCals = state.stravaCaloriesForDay;

    final maxWidth = MediaQuery.of(context).size.width * 0.9;
    final repasKeys = [
      'Petit-déjeuner',
      'Déjeuner',
      'Dîner',
      'Collation',
      'Activité'
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Répartition : Réel vs Théorique",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...repasKeys.map((repas) {
            // CAS SPÉCIAL : ACTIVITÉ
            if (repas == "Activité") {
              if (stravaCals <= 0) return const SizedBox.shrink();

              final consommeKcal = (consumedPerMeal[repas] ?? 0).toDouble();
              final widthConsomme = totalConsumedKcal > 0
                  ? (maxWidth * (consommeKcal / totalConsumedKcal))
                  : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: GestureDetector(
                  onTap: () => _openMealInput(repas, state, notifier),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Activité (${consommeKcal.toStringAsFixed(0)} kcal)",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.add_circle_outline,
                              size: 18, color: Colors.blueGrey),
                        ],
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        height: 20,
                        width: widthConsomme.clamp(0.0, maxWidth),
                        decoration: BoxDecoration(
                          color: _getColorForRepas(repas),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // AUTRES REPAS
            final ratio = (ratios[repas] ?? 0).toDouble();
            final theoriqueKcal = totalNeededKcal * ratio;
            final theoriqueWidth = maxWidth * ratio;
            final consommeKcal = (consumedPerMeal[repas] ?? 0).toDouble();
            final ratioConsomme =
                totalConsumedKcal > 0 ? consommeKcal / totalConsumedKcal : 0.0;
            final widthConsomme = (maxWidth * ratioConsomme).clamp(0.0, maxWidth);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: GestureDetector(
                onTap: () => _openMealInput(repas, state, notifier),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "$repas (${consommeKcal.toStringAsFixed(0)} / ${theoriqueKcal.toStringAsFixed(0)} kcal)",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.add_circle_outline,
                            size: 18, color: Colors.blueGrey),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Barre théorique (fond clair)
                    Container(
                      height: 24,
                      width: theoriqueWidth,
                      decoration: BoxDecoration(
                        color: _getColorForRepas(repas).withOpacity(0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "${(ratio * 100).toStringAsFixed(0)}%",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Barre de consommation (couleur vive)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: 20,
                      width: widthConsomme,
                      decoration: BoxDecoration(
                        color: _getColorForRepas(repas),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          // La légende
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 14, height: 14, color: Colors.black.withOpacity(0.8)),
              const SizedBox(width: 5),
              const Text("Consommé"),
              const SizedBox(width: 15),
              Container(width: 14, height: 14, color: Colors.black.withOpacity(0.3)),
              const SizedBox(width: 5),
              const Text("Théorique"),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.center,
            child: IconButton(
              icon: const Icon(Icons.expand_less, color: Colors.blueGrey, size: 28),
              tooltip: "Replier",
              onPressed: () {
                // On met à jour l'état (qui est géré par _ExpandableMealSectionState)
                setState(() {
                  _isExpanded = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MealsSplitCard extends ConsumerWidget {
  const _MealsSplitCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);
    final kpm = state.caloriesPerMeal;
    final selectedDate = DateService.formatStandard(state.selectedDate);

    Future<void> _open(String mealType) async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MealInputPage(
            selectedDate: selectedDate,
            mealType: mealType,
          ),
        ),
      );
      if (context.mounted) notifier.refreshDataAfterMealUpdate();
    }

    Widget tile({
      required IconData icon,
      required String label,
      required int kcal,
      required double height,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(label),
        child: Container(
          height: height,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Stack(
            children: [
              // Contenu centré
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 22),
                    const SizedBox(height: 8),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      '${kcal.toStringAsFixed(0)} kcal',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              // + intégré dans le carré
              Positioned(
                top: 0,
                right: 0,
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _open(label),
                      child: const Icon(Icons.add_rounded, size: 16, color: Colors.blueGrey),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Le LayoutBuilder est toujours là
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = (w >= 720) ? 4 : 2;
        const hSpacing = 12.0;
        const vSpacing = 12.0;
        final cardWidth = (w - hSpacing * (cols - 1)) / cols;
        final cardHeight = 120.0; // hauteur stable et compacte

        // === MODIFICATION ===
        // On retourne la GridView directement.
        // Le 'Container' avec le fond blanc a été retiré.
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: hSpacing,
            mainAxisSpacing: vSpacing,
            childAspectRatio: cardWidth / cardHeight,
          ),
          children: [
            tile(
              icon: Icons.wb_sunny_rounded,
              label: 'Petit-déjeuner',
              kcal: (kpm['Petit-déjeuner'] ?? 0).toInt(),
              height: cardHeight,
            ),
            tile(
              icon: Icons.lunch_dining_rounded,
              label: 'Déjeuner',
              kcal: (kpm['Déjeuner'] ?? 0).toInt(),
              height: cardHeight,
            ),
            tile(
              icon: Icons.nightlight_round,
              label: 'Dîner',
              kcal: (kpm['Dîner'] ?? 0).toInt(),
              height: cardHeight,
            ),
            tile(
              icon: Icons.apple_rounded,
              label: 'Collation',
              kcal: (kpm['Collation'] ?? 0).toInt(),
              height: cardHeight,
            ),
          ],
        );
      },
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNavBar({required this.currentIndex, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, -6))],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        child: NavigationBar(
          height: 64,
          selectedIndex: currentIndex,
          onDestinationSelected: (i) {
            switch (i) {
              case 0: // Accueil
                Navigator.popUntil(context, (route) => route.isFirst);
                break;
              case 1: // Profil (Index 1 maintenant)
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileFormPage()));
                break;
            }
          },
          backgroundColor: Colors.white,
          indicatorColor: const Color(0x114B49D1),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Accueil'),
            NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}


class _AddMealPill extends ConsumerWidget {
  const _AddMealPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);

    void openQuickAdd() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: false,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _QuickAddSheet(selectedDate: DateService.formatStandard(state.selectedDate)),
      );
    }

    // La "pill" (bouton large et arrondi)
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.68,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: openQuickAdd,
        icon: const Icon(Icons.add, size: 20),
        label: const Text("Saisir un repas"),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4B49D1),
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: const Color(0x29000000),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

class _QuickAddSheet extends ConsumerWidget {
  final String selectedDate;
  const _QuickAddSheet({required this.selectedDate, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dashboardProvider.notifier);

    Future<void> _open(String mealType) async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MealInputPage(
            selectedDate: selectedDate,
            mealType: mealType,
          ),
        ),
      );
      if (context.mounted) {
        Navigator.pop(context); // ferme le sheet
        notifier.refreshDataAfterMealUpdate();
      }
    }

    Widget chip(IconData icon, String label) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(
            color: Colors.black12, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text("Ajouter un repas", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),

          Row(children: [
            chip(Icons.wb_sunny_rounded, 'Petit-déjeuner'),
            const SizedBox(width: 10),
            chip(Icons.lunch_dining_rounded, 'Déjeuner'),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            chip(Icons.nightlight_round, 'Dîner'),
            const SizedBox(width: 10),
            chip(Icons.apple_rounded, 'Collation'),
          ]),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _open(''),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text("Scanner un produit / code-barres"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(height: MediaQuery.of(context).padding.bottom), // Safe area
        ],
      ),
    );
  }
}

class AiAnalysisPage extends ConsumerWidget {
  const AiAnalysisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rapport IA')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          // On réutilise EXACTEMENT ta carte existante
          _AiAnalysisCard(),
        ],
      ),
    );
  }
}

// dans lib/features/dashboard/dashboard_page.dart

// Ce provider vérifie de manière asynchrone si un token Strava est stocké.
final isStravaConnectedProvider = FutureProvider<bool>((ref) {
  // Il dépend du stravaServiceProvider que nous avons défini dans le repository
  return ref.watch(stravaServiceProvider).isConnected();
});