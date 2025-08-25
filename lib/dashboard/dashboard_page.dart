import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../meal_input/meal_input_page.dart';
import '../pages/profile_form_page.dart';
import '../pages/training_planner_page.dart';
import '../services/date_service.dart';
import '../repositories/strava_repository.dart';
import '../dashboard/dashboard_notifier.dart';
import '../dashboard/dashboard_state.dart';
import '../widget/ai_analysis_card.dart';



class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);

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
        title: const Text('Tableau de bord'),
        actions: [
          // Condition pour afficher le nom ou un bouton de connexion
          if (state.prenom.isNotEmpty)
            // Si le prénom existe, on l'affiche et on le rend cliquable
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileFormPage()),
                ).then((_) => notifier.loadInitialData()); // On recharge les données au retour
              },
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    state.prenom,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            )
          else
            // Si le prénom est vide, on affiche une icône pour se connecter/voir le profil
            IconButton(
              icon: const Icon(Icons.person),
              tooltip: 'Profil / Connexion',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileFormPage()),
                ).then((_) => notifier.loadInitialData());
              },
            ),

          // Le bouton de déconnexion est toujours présent
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // L'AuthWrapper dans main.dart s'occupera de la redirection automatique
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Vous avez été déconnecté.")),
                );
              }
            },
          ),
          const SizedBox(width: 8), // Un peu d'espace à droite
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.loadInitialData(),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _WeekSelector(),
            const SizedBox(height: 24),
            Text(
              "Macros du ${DateFormat.yMMMMEEEEd('fr_FR').format(state.selectedDate)}",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _CalorieSummaryDetailed(),
            const SizedBox(height: 24),
            _MacroDetailsDetailed(),
            const SizedBox(height: 32),
            _MealCalorieBreakdown(),
            const SizedBox(height: 32),
            _StravaActivitiesList(),
            const SizedBox(height: 32),
            _AiAnalysisCard(),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.restaurant_menu),
              label: const Text("Saisir un repas"),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MealInputPage(
                          selectedDate:
                              DateService.formatStandard(state.selectedDate)))).then(
                  (_) => notifier.refreshDataAfterMealUpdate()),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: const Text("Planning d'entraînement"),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TrainingPlannerPage())),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// == WIDGETS D'UI SPÉCIALISÉS
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
    // On récupère les données depuis le state de Riverpod
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
        // Le résumé textuel
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
            // --- Mapping des variables du state vers votre logique ---
            final double consomme = consumed;
            final double totalNecessaire = neededWithStrava;
            final double objectifSansStrava = neededWithoutStrava;
            final bool afficherOrange = stravaCals > 0;

            // --- NOUVELLE STRATÉGIE DE CALCUL ---
            final double largeurTotale = constraints.maxWidth;
            const double targetPositionRatio = 0.75; // ✅ La cible est à 75%

            // ✅ 1. La limite rouge (objectif total) est maintenant positionnée à 75%
            final double traitRougePos = largeurTotale * targetPositionRatio;

            // ✅ 2. La limite orange est calculée proportionnellement à la position de la rouge
            final double traitOrangePos = (afficherOrange && totalNecessaire > 0)
                ? (objectifSansStrava / totalNecessaire) * traitRougePos
                : 0;

            // ✅ 3. La barre de progression est aussi calculée par rapport à la limite rouge
            // Quand consomme == totalNecessaire, la barre atteindra exactement le trait rouge.
            final double widthVert = (totalNecessaire > 0)
                ? (consomme / totalNecessaire) * traitRougePos
                : 0;
            // --- Fin de votre logique ---

            return SizedBox(
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
                    // On s'assure que la barre ne dépasse pas la largeur totale
                    width: widthVert.clamp(0, largeurTotale), 
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 133, 194, 234),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  // Texte des calories sur la barre verte
                  if (widthVert > 40)
                    Positioned(
                      left: widthVert / 2 - 25,
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
                  // Trait orange (objectif de base)
                  if (afficherOrange)
                    Positioned(
                      left: traitOrangePos - 1,
                      top: 0,
                      height: 24,
                      child: Container(width: 2, color: Colors.orange),
                    ),
                  // Trait rouge (objectif total, au milieu)
                  Positioned(
                    left: traitRougePos - 1,
                    top: 0,
                    height: 24,
                    child: Container(width: 2, color: Colors.red),
                  ),
                  // Texte sous le trait orange
                  if (afficherOrange)
                    Positioned(
                      left: traitOrangePos - 30,
                      top: 30,
                      child: Text(
                        "${objectifSansStrava.toStringAsFixed(0)} kcal",
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  // Texte au-dessus du trait rouge
                  Positioned(
                    left: traitRougePos - 30,
                    top: -18,
                    child: Text(
                      "${totalNecessaire.toStringAsFixed(0)} kcal",
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}



// dans lib/features/dashboard/dashboard_page.dart

class _MacroDetailsDetailed extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consumed =
        ref.watch(dashboardProvider.select((s) => s.consumedMacros));
    final needed = ref.watch(dashboardProvider.select((s) => s.macroNeeds));

    // Vos couleurs pour la légende
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
          "Consommation / Besoins",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        for (final macro in ["Protéines", "Glucides", "Lipides"])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Texte "Consommé / Objectif"
                Text(
                  "$macro : ${(consumed[macro] ?? 0).toStringAsFixed(0)} g / ${(needed[macro] ?? 0).toStringAsFixed(0)} g",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8), // Un peu d'espace
                
                // ✅ ON A SUPPRIMÉ LE LINEARPROGRESSINDICATOR. IL NE RESTE QUE LA BARRE DE RÉPARTITION.
                _MacroBreakdownBar(macro: macro),
              ],
            ),
          ),

        // La légende des couleurs
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
      child: Container(
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
            Text(
              "🤖 Analyse IA",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),

            // Jour + coche si analyse jour dispo
            const Text("Jour"),
            AnimatedOpacity(
              opacity: hasDaily ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.check_circle, color: Colors.green, size: 18),
              ),
            ),

            // Switch
            Switch(
              value: isWeekly,
              onChanged: (v) => notifier.setAnalysisType(v),
            ),

            // Semaine + coche si analyse semaine dispo
            const Text("Semaine"),
            AnimatedOpacity(
              opacity: hasWeekly ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.check_circle, color: Colors.green, size: 18),
              ),
            ),

            const Spacer(),

            // ❌ on supprime le refresh ici (le bouton sera en bas de la carte)
            // IconButton(
            //   icon: const Icon(Icons.refresh),
            //   tooltip: "Recalculer l’analyse",
            //   onPressed: () => notifier.runMealAnalysis(force: true),
            // ),
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




class _MealCalorieBreakdown extends ConsumerWidget {
  
  // Fonction utilitaire pour les couleurs
  Color _getColorForRepas(String repas) {
    switch (repas) {
      case 'Petit-déjeuner': return const Color.fromARGB(255, 184, 167, 141);
      case 'Déjeuner': return Colors.green;
      case 'Dîner': return Colors.blue;
      case 'Collation': return Colors.purple;
      case 'Activité': return const Color.fromARGB(255, 233, 115, 107);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);
    /// utilitaire locaale
    /// 

    // On récupère toutes les données nécessaires depuis l'état
    final totalNeededKcal = state.macroNeeds['Calories'] ?? 0;
    final totalConsumedKcal = state.consumedMacros['Calories'] ?? 0;
    final ratios = state.theoreticalCalorieSplit;
    final consumedPerMeal = state.caloriesPerMeal;
    final stravaCals = state.stravaCaloriesForDay;
    
    final maxWidth = MediaQuery.of(context).size.width * 0.9;
    final repasKeys = ['Petit-déjeuner', 'Déjeuner', 'Dîner', 'Collation', 'Activité'];
    void _openMealInput(String repas) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const Text(
          "Répartition des calories : Réel vs Théorique",
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
                onTap: () => _openMealInput(repas),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Activité (${consommeKcal.toStringAsFixed(0)} kcal)",
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
              onTap: () => _openMealInput(repas),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$repas (${consommeKcal.toStringAsFixed(0)} / ${theoriqueKcal.toStringAsFixed(0)} kcal)",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  // Barre théorique (fond clair)
                  Container(
                    height: 24,
                    width: theoriqueWidth,
                    decoration: BoxDecoration(
                      // Si ton SDK ne supporte pas .withValues, remplace par .withOpacity(0.2)
                      color: _getColorForRepas(repas).withValues(alpha: 150),
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
            Container(width: 14, height: 14, color: Colors.black.withValues(alpha:204)),
            const SizedBox(width: 5),
            const Text("Consommé"),
            const SizedBox(width: 15),
            Container(width: 14, height: 14, color: Colors.black.withValues(alpha:75)),
            const SizedBox(width: 5),
            const Text("Théorique"),
          ],
        ),
      ],
    );
  }
}


class _StravaActivitiesList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On lit toutes les données directement depuis l'état principal
    final activities = ref.watch(dashboardProvider.select((s) => s.stravaActivitiesForDay));
    final isConnected = ref.watch(dashboardProvider.select((s) => s.isStravaConnected));
    final stravaService = ref.read(stravaServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("🏃 Activités Strava du jour",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        // ✅ La logique est maintenant un simple "if/else" basé sur le booléen 'isConnected'
    
        if (!isConnected)
          // CAS 1 : Non connecté -> Affiche le bouton
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text("Se connecter à Strava"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFC4C02),
                  foregroundColor: Colors.white),
              onPressed: () async {
                await stravaService.launchAuthUrl();
              },
            ),
          )
        else if (activities.isEmpty)
          // CAS 2 : Connecté mais pas d'activité
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Aucune activité Strava pour ce jour."),
          )
        else
          // CAS 3 : Connecté avec des activités
          Column(
            children: activities.map((act) {
              final distanceInKm = ((act["distance"] as num?)?.toDouble() ?? 0.0) / 1000;
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
// dans lib/features/dashboard/dashboard_page.dart

// Ce provider vérifie de manière asynchrone si un token Strava est stocké.
final isStravaConnectedProvider = FutureProvider<bool>((ref) {
  // Il dépend du stravaServiceProvider que nous avons défini dans le repository
  return ref.watch(stravaServiceProvider).isConnected();
});
