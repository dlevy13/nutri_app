import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal.dart';
import '../repositories/meal_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/training_repository.dart';
import '../services/date_service.dart';
import '../repositories/strava_repository.dart';
import '../services/ai_providers.dart';
import '../services/ai_manager.dart';
import 'dashboard_state.dart';
import 'package:intl/intl.dart';
import 'dart:async';


class DashboardNotifier extends StateNotifier<DashboardState> {
  final Ref _ref;
  late final UserRepository _userRepository = _ref.read(userRepositoryProvider);
  late final MealRepository _mealRepository = _ref.read(mealRepositoryProvider);
  late final StravaRepository _stravaRepository = _ref.read(stravaRepositoryProvider);
  late final AIManager _aiManager = _ref.read(aiManagerProvider);
  late final TrainingRepository _trainingRepository = _ref.read(trainingRepositoryProvider);



  DashboardNotifier(this._ref)
      : super(DashboardState(
          selectedDate: DateTime.now(),
          currentWeekStart: DateService.startOfWeek(DateTime.now()),
        )) {
    loadInitialData();
   
  }

  
  // ===========================================================================
  // == GESTION DES DONNÉES
  // ===========================================================================

  /// Méthode principale pour charger ou recharger toutes les données de la page.

// dans la classe DashboardNotifier

Future<void> loadInitialData({DateTime? newSelectedDate}) async {
  state = state.copyWith(status: ViewStatus.loading);
  try {
    final dateForLoading = newSelectedDate ?? state.selectedDate;
    final currentWeekStart = newSelectedDate != null 
        ? DateService.startOfWeek(newSelectedDate) 
        : state.currentWeekStart;

    if (newSelectedDate != null) {
      state = state.copyWith(
        selectedDate: newSelectedDate,
        currentWeekStart: currentWeekStart,
      );
    }

    // ✅ On crée la clé pour l'analyse de la semaine
    final weekKey = "week_${DateService.formatStandard(currentWeekStart)}";

    final results = await Future.wait([
      _userRepository.getProfile(),
      _mealRepository.getMealsForWeek(currentWeekStart),
      _getTheoreticalCaloriesSplit(),
      _stravaRepository.getActivitiesAndCaloriesForDate(dateForLoading),
      _stravaRepository.getStravaService().isConnected(),
      _trainingRepository.getTrainingTypeForDate(dateForLoading),
      _trainingRepository.getTrainingTypeForDate(dateForLoading.add(const Duration(days: 1))),
      // ✅ On va chercher l'analyse en cache en parallèle
      _aiManager.cacheService.getCachedAnalysis(weekKey),
    ]);

    // On extrait tous les résultats
    final userProfile = results[0] as UserProfile;
    final weeklyMeals = results[1] as Map<String, List<Meal>>;
    final calorieSplit = results[2] as Map<String, double>;
    final stravaData = results[3] as ({List<dynamic> activities, double totalCalories});
    final isStravaConnected = results[4] as bool;
    final typeToday = results[5] as String;
    final typeTomorrow = results[6] as String;
    final cachedWeeklyAnalysis = results[7] as String?; // ✅ On récupère l'analyse

    // On fait les calculs
    final dateKey = DateService.formatStandard(dateForLoading);
    final mealsForDay = weeklyMeals[dateKey] ?? [];
    final consumedData = _calculateConsumedMacros(mealsForDay);
    final neededMacros = _calculateMacroNeeds(userProfile, stravaData.totalCalories, typeToday, typeTomorrow);

    // On met à jour l'état final UNE SEULE FOIS avec TOUTES les données
    state = state.copyWith(
      status: ViewStatus.success,
      prenom: userProfile.firstName,
      tdee: userProfile.tdee,
      weeklyMeals: weeklyMeals,
      theoreticalCalorieSplit: calorieSplit,
      consumedMacros: consumedData['consumedMacros'],
      caloriesPerMeal: consumedData['caloriesPerMeal'],
      macrosPerMealType: consumedData['macrosPerMealType'],
      macroNeeds: neededMacros,
      stravaCaloriesForDay: stravaData.totalCalories,
      stravaActivitiesForDay: stravaData.activities,
      isStravaConnected: isStravaConnected,
      // ✅ On met à jour l'état de l'analyse hebdomadaire
      weeklyAiAnalysis: cachedWeeklyAnalysis ?? '',
      hasWeeklyAnalysis: cachedWeeklyAnalysis != null,
    );

  } catch (e, st) {
    print("💥 ERREUR DANS loadInitialData: $e");
    print("STACK TRACE : $st");
    state = state.copyWith(status: ViewStatus.failure, errorMessage: e.toString());
  }
}
Future<Map<String, double>> _getTheoreticalCaloriesSplit() async {
    // Note: Idéalement, la logique pour déterminer le type d'entraînement
    // devrait aussi être dans un repository. Pour l'instant, on garde simple.
    // final typeToday = await _ref.read(trainingRepoProvider).getTypeFor(state.selectedDate);
    final typeToday = "Endurance"; // Placeholder

    if (typeToday == "Endurance") {
      return {'Petit-déjeuner': 0.33, 'Déjeuner': 0.33, 'Dîner': 0.27, 'Collation': 0.07};
    } else {
      return {'Petit-déjeuner': 0.23, 'Déjeuner': 0.37, 'Dîner': 0.33, 'Collation': 0.07};
    }
  }
  // ===========================================================================
  // == ACTIONS DE L'UTILISATEUR (deviennent très simples)
  // ===========================================================================

  Future<void> selectDate(DateTime newDate) async {
    if (DateService.formatStandard(newDate) == DateService.formatStandard(state.selectedDate)) return;
    // On appelle simplement la méthode principale avec la nouvelle date.
    await loadInitialData(newSelectedDate: newDate);
  }

  Future<void> changeWeek(int offset) async {
    // ✅ ÉTAPE 1 : On met l'état en chargement et on vide les repas existants.
    state = state.copyWith(status: ViewStatus.loading, weeklyMeals: {});
    
    // ✅ ÉTAPE 2 : On calcule la nouvelle date de début de semaine.
    final newWeekStart = state.currentWeekStart.add(Duration(days: 7 * offset));
    
    // ✅ ÉTAPE 3 : On met à jour l'état avec la nouvelle date ET on lance le rechargement.
    // `loadInitialData` s'occupera de remettre le statut à `success` à la fin.
    state = state.copyWith(currentWeekStart: newWeekStart);
    await loadInitialData(newSelectedDate: newWeekStart);
  }

  Future<void> resetToToday() async {
    final now = DateTime.now();
    state = state.copyWith(currentWeekStart: DateService.startOfWeek(now));
    await loadInitialData(newSelectedDate: now);
  }

  // ===========================================================================
  // == LOGIQUE DE CALCUL (ces méthodes retournent maintenant des valeurs)
  // ===========================================================================

  // dans la classe DashboardNotifier

Map<String, dynamic> _calculateConsumedMacros(List<Meal> meals) {
  double calories = 0, prot = 0, gluc = 0, lip = 0;
  Map<String, double> caloriesParRepas = {'Petit-déjeuner': 0, 'Déjeuner': 0, 'Dîner': 0, 'Collation': 0, 'Activité': 0};
  
  Map<String, Map<String, double>> repartition = {
    "Protéines": {}, "Glucides": {}, "Lipides": {},
  };

  for (final meal in meals) {
    calories += meal.calories;
    prot += meal.protein;
    gluc += meal.carbs;
    lip += meal.fat;
    
    // ✅ ON VÉRIFIE QUE LE TYPE DE REPAS EXISTE AVANT DE FAIRE LA RÉPARTITION
    if (meal.type.isNotEmpty && caloriesParRepas.containsKey(meal.type)) {
      caloriesParRepas[meal.type] = (caloriesParRepas[meal.type]! + meal.calories);
      
      // On initialise les compteurs si ce n'est pas déjà fait
      repartition['Protéines']![meal.type] ??= 0;
      repartition['Glucides']![meal.type] ??= 0;
      repartition['Lipides']![meal.type] ??= 0;

      // On ajoute les valeurs
      repartition['Protéines']![meal.type] = repartition['Protéines']![meal.type]! + meal.protein;
      repartition['Glucides']![meal.type] = repartition['Glucides']![meal.type]! + meal.carbs;
      repartition['Lipides']![meal.type] = repartition['Lipides']![meal.type]! + meal.fat;
    }
  }
  return {
    'consumedMacros': {"Calories": calories, "Protéines": prot, "Glucides": gluc, "Lipides": lip},
    'caloriesPerMeal': caloriesParRepas,
    'macrosPerMealType': repartition,
  };
}
  
  Map<String, double> _calculateMacroNeeds(UserProfile profile, double stravaCals,String typeToday,
  String typeTomorrow) {
    final poids = profile.weight;
    double adjustedTDEE = profile.tdee;
    
  if (typeToday == "Intensité") {
      adjustedTDEE *= 1.10;
    } else if (typeToday == "Endurance") {
      adjustedTDEE *= 1.30;
    } else if (typeToday == "Affûtage") {
      adjustedTDEE *= 0.90;
    }

  if (typeTomorrow == "Endurance" && typeToday != "Endurance") {
      adjustedTDEE *= 1.10;
  }
    double tdeeFinal = adjustedTDEE + stravaCals;
    final proteines = poids * 2;
    final caloriesProteines = proteines * 4;
    final remainingCalories = tdeeFinal - caloriesProteines > 0 ? tdeeFinal - caloriesProteines : 0;
    
    final glucides = (remainingCalories * 0.6) / 4;
    final lipides = (remainingCalories * 0.4) / 9;
    return {
      "Calories": tdeeFinal,
      "Protéines": proteines,
      "Glucides": glucides,
      "Lipides": lipides,
    };
  }
  Future<void> refreshDataAfterMealUpdate() async {
    // Cette méthode fait simplement appel à la logique de chargement principale.
    // C'est propre, car l'UI demande une action précise et le notifier l'exécute.
    await loadInitialData();
  }

/// Change le type d'analyse (jour ou semaine)
void setAnalysisType(bool isWeekly) {
  state = state.copyWith(isWeeklyAnalysis: isWeekly);
  // Idéalement, on pourrait aussi charger l'analyse en cache pour ce nouveau type ici
}

// ===========================================================================
  // == ANALYSE IA
  // ===========================================================================
/// Lance l'analyse IA
Future<void> runMealAnalysis({bool force = false}) async {
    state = state.copyWith(analysisStatus: ViewStatus.loading);
    try {
      final String key;
      final Map<String, dynamic> data;

      // On choisit les bonnes données et la bonne clé en fonction du switch
      if (state.isWeeklyAnalysis) {
        key = "week_${DateService.formatStandard(state.currentWeekStart)}";
        data = await _collectWeeklyMealsData();
      } else {
        key = DateService.formatStandard(state.selectedDate);
        data = await _collectDailyMealsData();
      }

      if (data.isEmpty || (data['jour'] != null && (data['jour']['repas'] as List).isEmpty)) {
        state = state.copyWith(
            analysisStatus: ViewStatus.success,
            aiAnalysis: "🤷‍♂️ Aucun repas trouvé. Ajoutez-en un !");
        return;
      }
      
      final analysisResult = await _aiManager.getOrGenerateAnalysis(
        key, data, preferApi: true, force: force, provider: "mistral");

      // On met à jour le bon champ dans l'état
      if (state.isWeeklyAnalysis) {
        state = state.copyWith(
          analysisStatus: ViewStatus.success,
          weeklyAiAnalysis: analysisResult,
          hasWeeklyAnalysis: true,
        );
      } else {
        state = state.copyWith(
          analysisStatus: ViewStatus.success,
          aiAnalysis: analysisResult,
        );
      }
    } catch (e) {
      state = state.copyWith(status: ViewStatus.failure, errorMessage: "Erreur analyse IA: $e");
    }
  }
Future<Map<String, dynamic>> _collectDailyMealsData() async {
    final dateKey = DateFormat('yyyy-MM-dd').format(state.selectedDate);
    final meals = state.weeklyMeals[dateKey]?.map((m) => m.toMap()).toList() ?? [];
    return { "jour": {"date": dateKey, "repas": meals} };
  }

  // dans la classe DashboardNotifier

  /// Prépare les données pour l'analyse de la semaine en regroupant les aliments par repas.
  Future<Map<String, dynamic>> _collectWeeklyMealsData() async {
    // 1. On récupère tous les aliments de la semaine depuis l'état
    final allMealsForWeek = state.weeklyMeals.values
        .expand((dayMeals) => dayMeals)
        .toList();

    if (allMealsForWeek.isEmpty) {
      return {};
    }

    // 2. On regroupe les aliments par date, puis par type de repas
    final Map<String, Map<String, List<Meal>>> groupedMeals = {};
    for (var meal in allMealsForWeek) {
      groupedMeals.putIfAbsent(meal.date, () => {});
      groupedMeals[meal.date]!.putIfAbsent(meal.type, () => []);
      groupedMeals[meal.date]![meal.type]!.add(meal);
    }

    // 3. On compte le nombre de repas uniques (un petit-déjeuner par jour, etc.)
    int breakfastCount = 0;
    int lunchCount = 0;
    int dinnerCount = 0;
    int snackCount = 0;

    groupedMeals.forEach((date, dayMeals) {
      if (dayMeals.containsKey('Petit-déjeuner') && dayMeals['Petit-déjeuner']!.isNotEmpty) {
        breakfastCount++;
      }
      if (dayMeals.containsKey('Déjeuner') && dayMeals['Déjeuner']!.isNotEmpty) {
        lunchCount++;
      }
      if (dayMeals.containsKey('Dîner') && dayMeals['Dîner']!.isNotEmpty) {
        dinnerCount++;
      }
      if (dayMeals.containsKey('Collation') && dayMeals['Collation']!.isNotEmpty) {
        snackCount++;
      }
    });
    
    // On crée un résumé textuel clair pour l'IA
    final summary = "Résumé de la semaine : $breakfastCount petits-déjeuners, $lunchCount déjeuners, $dinnerCount dîners, $snackCount collations.";
    
    print("DEBUG ANALYSE SEMAINE: $summary");

    // 4. On envoie ce résumé et la liste brute à l'IA
    return {
      "type": "week",
      "text": summary, // On envoie le compte correct
      "meals": allMealsForWeek.map((e) => e.toMap()).toList(), // On envoie toujours la liste complète pour le détail
    };
  }


}
final dashboardProvider = StateNotifierProvider.autoDispose<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref);
});