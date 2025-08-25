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

  /// Charge ou recharge toutes les données de la page.
  Future<void> loadInitialData({DateTime? newSelectedDate}) async {
    state = state.copyWith(status: ViewStatus.loading);

    try {
      final dateForLoading = newSelectedDate ?? state.selectedDate;
      final currentWeekStart = newSelectedDate != null
          ? DateService.startOfWeek(newSelectedDate)
          : state.currentWeekStart;

      if (newSelectedDate != null) {
        state = state.copyWith(
          selectedDate: dateForLoading,
          currentWeekStart: currentWeekStart,
        );
      }

      // ✅ Clés cache jour / semaine
      final dayKey = DateService.formatStandard(dateForLoading);
      final weekKey = "week_${DateService.formatStandard(currentWeekStart)}";

      final results = await Future.wait([
        _userRepository.getProfile(),                                     // [0]
        _mealRepository.getMealsForWeek(currentWeekStart),                // [1]
        _getTheoreticalCaloriesSplit(),                                   // [2]
        _stravaRepository.getActivitiesAndCaloriesForDate(dateForLoading),// [3]
        _stravaRepository.getStravaService().isConnected(),               // [4]
        _trainingRepository.getTrainingTypeForDate(dateForLoading),       // [5]
        _trainingRepository.getTrainingTypeForDate(
          dateForLoading.add(const Duration(days: 1))),                   // [6]
        _aiManager.cacheService.getCachedAnalysis(weekKey),               // [7]
        _aiManager.cacheService.getCachedAnalysis(dayKey),                // [8] ✅ daily cache
      ]);

      final userProfile          = results[0] as UserProfile;
      final weeklyMeals          = results[1] as Map<String, List<Meal>>;
      final calorieSplit         = results[2] as Map<String, double>;
      final stravaData           = results[3] as ({List<dynamic> activities, double totalCalories});
      final isStravaConnected    = results[4] as bool;
      final typeToday            = results[5] as String;
      final typeTomorrow         = results[6] as String;
      final cachedWeeklyAnalysis = results[7] as String?;
      final cachedDailyAnalysis  = results[8] as String?;

      final dateKey = DateService.formatStandard(dateForLoading);
      final mealsForDay = weeklyMeals[dateKey] ?? [];
      final consumedData = _calculateConsumedMacros(mealsForDay);
      final neededMacros = _calculateMacroNeeds(
        userProfile, stravaData.totalCalories, typeToday, typeTomorrow);

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
        weeklyAiAnalysis: cachedWeeklyAnalysis ?? '',
        hasWeeklyAnalysis: (cachedWeeklyAnalysis ?? '').isNotEmpty,
        aiAnalysis: cachedDailyAnalysis ?? '',
      );

    } catch (e) {
      //print("💥 ERREUR DANS loadInitialData: $e");
      //print("STACK TRACE : $st");
      state = state.copyWith(status: ViewStatus.failure, errorMessage: e.toString());
    }
  }

  Future<Map<String, double>> _getTheoreticalCaloriesSplit() async {
    // Placeholder simple (tu peux brancher ton vrai repo si besoin)
    const typeToday = "Endurance";
    if (typeToday == "Endurance") {
      return {'Petit-déjeuner': 0.33, 'Déjeuner': 0.33, 'Dîner': 0.27, 'Collation': 0.07};
    } else {
      return {'Petit-déjeuner': 0.23, 'Déjeuner': 0.37, 'Dîner': 0.33, 'Collation': 0.07};
    }
  }

  // ===========================================================================
  // == ACTIONS UTILISATEUR
  // ===========================================================================

  Future<void> selectDate(DateTime newDate) async {
    if (DateService.formatStandard(newDate) ==
        DateService.formatStandard(state.selectedDate)) {
      return;
    }
    await loadInitialData(newSelectedDate: newDate);
  }

  /// Conserve le même **jour de semaine** lorsqu’on change de semaine.
  Future<void> changeWeek(int offset) async {
    state = state.copyWith(status: ViewStatus.loading, weeklyMeals: {});
    final newWeekStart = state.currentWeekStart.add(Duration(days: 7 * offset));
    final weekdayDelta = state.selectedDate.difference(state.currentWeekStart).inDays;
    final newSelectedDate = newWeekStart.add(Duration(days: weekdayDelta.clamp(0, 6)));

    state = state.copyWith(currentWeekStart: newWeekStart);
    await loadInitialData(newSelectedDate: newSelectedDate);
  }

  Future<void> resetToToday() async {
    final now = DateTime.now();
    state = state.copyWith(currentWeekStart: DateService.startOfWeek(now));
    await loadInitialData(newSelectedDate: now);
  }

  // ===========================================================================
  // == LOGIQUE DE CALCUL
  // ===========================================================================

  Map<String, dynamic> _calculateConsumedMacros(List<Meal> meals) {
    double calories = 0, prot = 0, gluc = 0, lip = 0;
    Map<String, double> caloriesParRepas = {
      'Petit-déjeuner': 0, 'Déjeuner': 0, 'Dîner': 0, 'Collation': 0, 'Activité': 0
    };

    Map<String, Map<String, double>> repartition = {
      "Protéines": {}, "Glucides": {}, "Lipides": {},
    };

    for (final meal in meals) {
      calories += meal.calories;
      prot += meal.protein;
      gluc += meal.carbs;
      lip += meal.fat;

      if (meal.type.isNotEmpty && caloriesParRepas.containsKey(meal.type)) {
        caloriesParRepas[meal.type] = (caloriesParRepas[meal.type]! + meal.calories);

        repartition['Protéines']![meal.type] ??= 0;
        repartition['Glucides']![meal.type] ??= 0;
        repartition['Lipides']![meal.type] ??= 0;

        repartition['Protéines']![meal.type] =
            repartition['Protéines']![meal.type]! + meal.protein;
        repartition['Glucides']![meal.type] =
            repartition['Glucides']![meal.type]! + meal.carbs;
        repartition['Lipides']![meal.type] =
            repartition['Lipides']![meal.type]! + meal.fat;
      }
    }

    return {
      'consumedMacros': {
        "Calories": calories, "Protéines": prot, "Glucides": gluc, "Lipides": lip
      },
      'caloriesPerMeal': caloriesParRepas,
      'macrosPerMealType': repartition,
    };
  }

  Map<String, double> _calculateMacroNeeds(
    UserProfile profile,
    double stravaCals,
    String typeToday,
    String typeTomorrow,
  ) {
    final poids = profile.weight;
    double adjustedTDEE = profile.tdee;

    // Ajustements
    if (typeToday == "Affûtage") {
      adjustedTDEE *= 0.90; // -10%
    }
    if (typeTomorrow == "Endurance") {
      adjustedTDEE *= 1.10; // +10%
    }

    double tdeeFinal = adjustedTDEE + stravaCals;

    final proteines = poids * 2;
    final remainingCalories = tdeeFinal - (proteines * 4);
    final glucides = (remainingCalories > 0 ? remainingCalories * 0.6 : 0) / 4;
    final lipides = (remainingCalories > 0 ? remainingCalories * 0.4 : 0) / 9;

    return {
      "Calories": tdeeFinal,
      "Protéines": proteines,
      "Glucides": glucides,
      "Lipides": lipides,
    };
  }

  Future<void> refreshDataAfterMealUpdate() async {
    await loadInitialData();
  }

  // ===========================================================================
  // == ANALYSE IA
  // ===========================================================================

  /// Change le type d’analyse (jour/semaine) et précharge le cache correspondant.
  void setAnalysisType(bool isWeekly) async {
    state = state.copyWith(isWeeklyAnalysis: isWeekly);

    final key = isWeekly
        ? "week_${DateService.formatStandard(state.currentWeekStart)}"
        : DateService.formatStandard(state.selectedDate);

    final cached = await _aiManager.cacheService.getCachedAnalysis(key);
    if (isWeekly) {
      state = state.copyWith(
        weeklyAiAnalysis: cached ?? state.weeklyAiAnalysis,
        hasWeeklyAnalysis: (cached ?? '').isNotEmpty,
      );
    } else {
      state = state.copyWith(aiAnalysis: cached ?? state.aiAnalysis);
    }
  }

  /// Lance l’analyse IA (jour ou semaine selon l’état).
  Future<void> runMealAnalysis({bool force = false}) async {
  state = state.copyWith(analysisStatus: ViewStatus.loading);

  try {
    final String key;
    final Map<String, dynamic> data;

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

    var analysisResult = await _aiManager.getOrGenerateAnalysis(
      key, data, preferApi: true, force: force, provider: "mistral");

    if (state.isWeeklyAnalysis) {
      state = state.copyWith(
        analysisStatus: ViewStatus.success,
        weeklyAiAnalysis: analysisResult,
        hasWeeklyAnalysis: true,
      );
    } else {
     
  // 👉 JOUR : on affiche le résumé court + le texte IA (sans toucher au weekly)
  final jour  = data['jour'] as Map<String, dynamic>?;
  final short = (jour?['text'] as String?)?.trim() ?? '';
  if (short.isNotEmpty) {
    analysisResult = '$short\n\n$analysisResult';
  }// fallback si jamais pas de short

  // (si tu as une sauvegarde ici, utilise ta méthode habituelle avec 'combined')
  // await _aiManager.cacheService.taMethodeDeSauvegarde(key, combined);

  state = state.copyWith(
    analysisStatus: ViewStatus.success,
    aiAnalysis: analysisResult,
  );


    }
  } catch (e) {
    state = state.copyWith(
      analysisStatus: ViewStatus.failure,
      errorMessage: "Erreur analyse IA: $e",
    );
  }
}



  Future<Map<String, dynamic>> _collectDailyMealsData() async {
  // 1) Date clé unifiée
  final dateKey = DateService.formatStandard(state.selectedDate);

  // 2) Source unique (pas de doublon)
  final baseList = state.weeklyMeals[dateKey] ?? const <Meal>[];
  if (baseList.isEmpty) {
    return {
      "jour": {
        "date": dateKey,
        "repas": <Map<String, dynamic>>[],
        "text": "Résumé du jour : aucun repas.",
        "totaux": {"kcal": 0.0, "protein": 0.0, "carbs": 0.0, "fat": 0.0},
      }
    };
  }

  // 3) Types autorisés
  const allowed = {'Petit-déjeuner', 'Déjeuner', 'Dîner', 'Collation','Activité'};
  final filtered = baseList.where((m) => allowed.contains(m.type)).toList();
  if (filtered.isEmpty) {
    return {
      "jour": {
        "date": dateKey,
        "repas": <Map<String, dynamic>>[],
        "text": "Résumé du jour : aucun repas.",
        "totaux": {"kcal": 0.0, "protein": 0.0, "carbs": 0.0, "fat": 0.0},
      }
    };
  }

  // 4) Dédup robuste (⚠️ peut fusionner 2 occurrences identiques le même jour)
  String norm(num x) => x.toStringAsFixed(2);
  String keyOf(Meal m) =>
      '${m.date}|${m.type}|${m.name}|${norm(m.calories)}|${norm(m.protein)}|${norm(m.carbs)}|${norm(m.fat)}|${norm(m.quantity)}';

  final seen = <String>{};
  final deduped = <Meal>[];
  for (final m in filtered) {
    if (seen.add(keyOf(m))) deduped.add(m);
  }

  // 5) Sessions (0/1 par type)
  final hasType = {
    'Petit-déjeuner': deduped.any((m) => m.type == 'Petit-déjeuner'),
    'Déjeuner':       deduped.any((m) => m.type == 'Déjeuner'),
    'Dîner':          deduped.any((m) => m.type == 'Dîner'),
    'Collation':      deduped.any((m) => m.type == 'Collation'),
    'Activité':       deduped.any((m) => m.type == 'Activité'),
  };
  final sessions = {
    'Petit-déjeuner': hasType['Petit-déjeuner']! ? 1 : 0,
    'Déjeuner':       hasType['Déjeuner']! ? 1 : 0,
    'Dîner':          hasType['Dîner']! ? 1 : 0,
    'Collation':      hasType['Collation']! ? 1 : 0,
    'Activité':       hasType['Activité']! ? 1 : 0,
  };

  // 6) Résumé IA
  final summary =
      "Résumé du jour : ${sessions['Petit-déjeuner']} petit-déjeuner, "
      "${sessions['Déjeuner']} déjeuner, ${sessions['Dîner']} dîner, "
      "${sessions['Collation']} collation, ${sessions['Activité']} activité.";

  // 7) Debug
  final counts = <String,int>{};
  for (final m in deduped) {
    counts[m.type] = (counts[m.type] ?? 0) + 1;
  }

  // 8) ✅ Totaux FIABLES (cast double + somme simple)

  int sumRound(Iterable<Meal> it, double Function(Meal m) pick) =>
    it.fold<double>(0, (a, m) => a + pick(m)).round();


  final totalsPerType = <String, Map<String,int>>{
    for (final type in allowed)
      type: {
        "kcal":    sumRound(deduped.where((m) => m.type == type), (m) => m.calories),
        "protein": sumRound(deduped.where((m) => m.type == type), (m) => m.protein),
        "carbs":   sumRound(deduped.where((m) => m.type == type), (m) => m.carbs),
        "fat":     sumRound(deduped.where((m) => m.type == type), (m) => m.fat),
      }
  };

  final dayTotals = {
    "kcal":    sumRound(deduped, (m) => m.calories),
    "protein": sumRound(deduped, (m) => m.protein),
    "carbs":   sumRound(deduped, (m) => m.carbs),
    "fat":     sumRound(deduped, (m) => m.fat),
  };


  // 9-bis) Top 3 aliments par calories + résumé compact sur 2 lignes
  final sortedByKcal = [...deduped]..sort((a, b) => b.calories.compareTo(a.calories));
  final top = sortedByKcal.take(3).toList();

  String _cap(String s, {int max = 22}) =>
      (s.length <= max) ? s : (s.substring(0, max - 1) + '…');

  final intKcal   = dayTotals["kcal"] as int;
  final intProt   = dayTotals["protein"] as int;
  final intCarbs  = dayTotals["carbs"] as int;
  final intFat    = dayTotals["fat"] as int;

  final line1 = "Total $intKcal kcal — Prot $intProt g • Gluc $intCarbs g • Lip $intFat g";

  String _fmtTop(Meal m) => "${_cap(m.name)} (${m.calories.round()} kcal)";
final line2 = (top.isEmpty)
    ? "Top cal. : —"
    : "Top cal. : ${top.map(_fmtTop).join(" ** ")}";
  final shortText = "$line1\n$line2";

  // 10) Payload complet
  return {
    "jour": {
      "date": dateKey,
      "text": shortText, //summary, -> summary = résumé plus complet du jour
      "sessions": sessions,
      "itemsParType": counts,
      "totaux": dayTotals,                 // total global (ints)
      "totauxParType": totalsPerType,      // totaux par type (ints)
      "repas": deduped.map((m) => m.toMap()).toList(),
      "top2": top.map((m) => m.toMap()).toList(),
    }
  };

}


void toggleDailyExpanded() {
  state = state.copyWith(isDailyExpanded: !state.isDailyExpanded);
}

void toggleWeeklyExpanded() {
  state = state.copyWith(isWeeklyExpanded: !state.isWeeklyExpanded);
}

  /// Prépare les données pour l’analyse de la semaine (groupées par jour/type).
List<DateTime> _getWeekDates(DateTime startOfWeek) {
  return List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
}

 Future<Map<String, dynamic>> _collectWeeklyMealsData() async {
  // ⚠️ On ne prend QUE la semaine courante (pas toutes les semaines en mémoire)
  final weekStart = state.currentWeekStart;
  
  final weekDates = _getWeekDates(weekStart);
  final dateKeys = weekDates.map(DateService.formatStandard).toList();
  // Récup par date (évite values.expand(...) qui peut englober d'autres semaines)
  final Map<String, List<Meal>> byDate = {
    for (final k in dateKeys) k: (state.weeklyMeals[k] ?? const <Meal>[])
  };

  // Types autorisés
  const allowed = {'Petit-déjeuner', 'Déjeuner', 'Dîner', 'Collation','Activité'};

  // Dédup helper
  String norm(num x) => x.toStringAsFixed(2);
  String keyOf(Meal m) =>
      '${m.date}|${m.type}|${m.name}|${norm(m.calories)}|${norm(m.protein)}|${norm(m.carbs)}|${norm(m.fat)}|${norm(m.quantity)}';

  // Agrégats
  int breakfastDays = 0, lunchDays = 0, dinnerDays = 0, snackDays = 0, actDays = 0;
  double wkKcal = 0, wkPro = 0, wkCarb = 0, wkFat = 0;

  final sessionsPerDay = <String, Map<String,int>>{};
  final days = <Map<String, dynamic>>[];

  for (final dateKey in dateKeys) {
    final baseList = byDate[dateKey] ?? const <Meal>[];
    if (baseList.isEmpty) {
      days.add({"date": dateKey, "repas": <Map<String, dynamic>>[], "totaux": {"kcal":0.0,"protein":0.0,"carbs":0.0,"fat":0.0}});
      sessionsPerDay[dateKey] = {"Petit-déjeuner":0,"Déjeuner":0,"Dîner":0,"Collation":0,"Activité":0};
      continue;
    }

    // filtre + dédup
    final filtered = baseList.where((m) => allowed.contains(m.type)).toList();
    final seen = <String>{};
    final deduped = <Meal>[];
    for (final m in filtered) {
      if (seen.add(keyOf(m))) deduped.add(m);
    }

    // sessions jour (0/1)
    final hasB = deduped.any((m) => m.type == 'Petit-déjeuner');
    final hasL = deduped.any((m) => m.type == 'Déjeuner');
    final hasD = deduped.any((m) => m.type == 'Dîner');
    final hasS = deduped.any((m) => m.type == 'Collation');
    final hasA = deduped.any((m) => m.type == 'Activité');

    breakfastDays += hasB ? 1 : 0;
    lunchDays     += hasL ? 1 : 0;
    dinnerDays    += hasD ? 1 : 0;
    snackDays     += hasS ? 1 : 0;
    actDays       += hasA ? 1 : 0;

    sessionsPerDay[dateKey] = {
      "Petit-déjeuner": hasB ? 1 : 0,
      "Déjeuner":       hasL ? 1 : 0,
      "Dîner":          hasD ? 1 : 0,
      "Collation":      hasS ? 1 : 0,
      "Activité":       hasA ? 1 : 0,
    };

    // totaux jour (casts robustes)
    double kcal = 0, pro = 0, carb = 0, fat = 0;
    for (final m in deduped) {
      kcal += m.calories;
      pro  += m.protein;
      carb += m.carbs;
      fat  += m.fat;
    }
    // helper d’arrondi à 1 décimale
    double round1(double x) => (x * 10).round() / 10.0; 
   final dayTotals = {
      "kcal":    round1(kcal),
      "protein": round1(pro),
      "carbs":   round1(carb),
      "fat":     round1(fat),
    };

    // push jour
    days.add({
      "date": dateKey,
      "totaux": dayTotals,
      "repas": deduped.map((e) => e.toMap()).toList(),
    });

    // cumule semaine
    wkKcal += dayTotals["kcal"]!;
    wkPro  += dayTotals["protein"]!;
    wkCarb += dayTotals["carbs"]!;
    wkFat  += dayTotals["fat"]!;
  }

  final summary =
      "Résumé de la semaine : $breakfastDays petits-déjeuners, "
      "$lunchDays déjeuners, $dinnerDays dîners, $snackDays collations, $actDays activité.";

  final weekTotals = {
    "kcal": double.parse(wkKcal.toStringAsFixed(1)),
    "protein": double.parse(wkPro.toStringAsFixed(1)),
    "carbs": double.parse(wkCarb.toStringAsFixed(1)),
    "fat": double.parse(wkFat.toStringAsFixed(1)),
  };


  return {
    "type": "week",
    "text": summary,
    "totaux": weekTotals,
    "sessionsParJour": sessionsPerDay,
    "jours": days,         // liste [{date, totaux, repas}]
  };
}

}

final dashboardProvider =
    StateNotifierProvider.autoDispose<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref);
});
