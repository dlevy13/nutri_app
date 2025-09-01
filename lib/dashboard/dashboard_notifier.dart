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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
// 🔒 Écrit/merge un document par jour : users/{uid}/daily_calories/{YYYY-MM-DD}
    Future<void> _upsertDailyCalories({
      required DateTime day,
      required double neededKcal,    // = state.macroNeeds['Calories']
      required double consumedKcal,  // = state.consumedMacros['Calories']
      required double activityKcal,  // = state.stravaCaloriesForDay
      int? mealsCount,
      double? consumedProt_g,       
      double? consumedCarb_g,      
      double? consumedFat_g, 
      double? consumedFibres_g,
      double? consumedSatFat_g,
      double? consumedPolyFat_g,
      double? consumedMonoFat_g,
    }) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final docId = DateService.formatStandard(day); // "yyyy-MM-dd"
      final ref = FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('daily_calories')
          .doc(docId);

      await ref.set({
        'date': docId,
        'neededKcal': neededKcal,
        'consumedKcal': consumedKcal,
        'activityKcal': activityKcal,
        if (mealsCount != null) 'mealsCount': mealsCount,
        if (consumedProt_g != null) 'consumedProt_g': consumedProt_g, 
        if (consumedCarb_g != null) 'consumedCarb_g': consumedCarb_g, 
        if (consumedFat_g  != null) 'consumedFat_g' : consumedFat_g,
        if (consumedFibres_g != null) 'consumedFibres_g': consumedFibres_g,
        if (consumedSatFat_g != null) 'consumedSatFat_g': consumedSatFat_g,
        if (consumedPolyFat_g != null) 'consumedPolyFat_g': consumedPolyFat_g,
        if (consumedMonoFat_g != null) 'consumedMonoFat_g': consumedMonoFat_g,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

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

   
      final mealsCount = _countDistinctMealsByType(
        mealsForDay,
        includeSnack: false,   // passe à false si tu veux exiger B/D/D uniquement
        minKcalPerType: 50.0, // ajuste le seuil si besoin
      );

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
      final consumedMap = Map<String, double>.from(
        (state.consumedMacros) // {"Calories": double, ...}
      );
      final double consumedTodayKcal = (consumedMap['Calories'] ?? 0).toDouble();
      final double neededWithStrava  = (state.macroNeeds['Calories'] ?? 0).toDouble();
      final double stravaCals        = (state.stravaCaloriesForDay).toDouble();
      final double protG = (consumedMap['Protéines'] ?? 0).toDouble();
      final double carbG = (consumedMap['Glucides']  ?? 0).toDouble();
      final double fatG  = (consumedMap['Lipides']   ?? 0).toDouble();
      final double fibresG = consumedMap['Fibres'] ?? 0;
      final double satFatG = consumedMap['Saturés'] ?? 0;
      final double polyFatG = consumedMap['Polyinsaturés'] ?? 0;
      final double monoFatG = consumedMap['Monoinsaturés'] ?? 0;

      // --- Upsert Firestore pour le jour affiché ---
      await _upsertDailyCalories(
        day: dateForLoading,
        neededKcal: neededWithStrava,
        consumedKcal: consumedTodayKcal,
        activityKcal: stravaCals,
        mealsCount: mealsCount,
        consumedProt_g: protG,   
        consumedCarb_g: carbG,   
        consumedFat_g:  fatG,
        consumedFibres_g: fibresG,
        consumedSatFat_g: satFatG,
        consumedPolyFat_g: polyFatG,
        consumedMonoFat_g: monoFatG,    
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
  int _countDistinctMealsByType(
    List<Meal> meals, {
    bool includeSnack = true,          // inclure "Collation" dans le comptage
    double minKcalPerType = 50.0,      // seuil pour considérer un type "présent"
  }) {
    final allowed = <String>{
      'Petit-déjeuner', 'Déjeuner', 'Dîner', if (includeSnack) 'Collation',
    };

    // Somme des kcal par type (plus robuste que “au moins un item”)
    final Map<String, double> kcalPerType = { for (final t in allowed) t: 0.0 };

    for (final m in meals) {
      if (allowed.contains(m.type)) {
        kcalPerType[m.type] = (kcalPerType[m.type]! + (m.calories));
      }
    }

    // Un type compte comme "1 repas" si la somme dépasse le seuil
    final presentTypes = kcalPerType.entries
        .where((e) => e.value >= minKcalPerType)
        .map((e) => e.key)
        .toSet();

    return presentTypes.length;
  }

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
  final Map<String, double> consumedMacros = {
    "Calories": 0.0, "Protéines": 0.0, "Glucides": 0.0, "Lipides": 0.0,
    "Fibres": 0.0, "Saturés": 0.0, "Polyinsaturés": 0.0, "Monoinsaturés": 0.0,
  };
  final Map<String, double> caloriesParRepas = {
    'Petit-déjeuner': 0.0, 'Déjeuner': 0.0, 'Dîner': 0.0, 'Collation': 0.0, 'Activité': 0.0,
  };
  final Map<String, Map<String, double>> repartition = {
    "Protéines": {}, "Glucides": {}, "Lipides": {}, "Fibres": {},
    "Saturés": {}, "Polyinsaturés": {}, "Monoinsaturés": {},
  };
  double d(num? v) => (v ?? 0).toDouble();
  void inc(Map<String, double> b, String k, double add) => b[k] = (b[k] ?? 0) + add;

  for (final m in meals) {
    consumedMacros['Calories']       = consumedMacros['Calories']!      + d(m.calories);
    consumedMacros['Protéines']      = consumedMacros['Protéines']!     + d(m.protein);
    consumedMacros['Glucides']       = consumedMacros['Glucides']!      + d(m.carbs);
    consumedMacros['Lipides']        = consumedMacros['Lipides']!       + d(m.fat);
    consumedMacros['Fibres']         = consumedMacros['Fibres']!        + d(m.fiber);
    consumedMacros['Saturés']        = consumedMacros['Saturés']!       + d(m.fatSaturated);
    consumedMacros['Polyinsaturés']  = consumedMacros['Polyinsaturés']! + d(m.fatPolyunsaturated);
    consumedMacros['Monoinsaturés']  = consumedMacros['Monoinsaturés']! + d(m.fatMonounsaturated);

    if (m.type.isNotEmpty && caloriesParRepas.containsKey(m.type)) {
      caloriesParRepas[m.type] = caloriesParRepas[m.type]! + d(m.calories);
    }
    if (m.type.isNotEmpty) {
      inc(repartition['Protéines']!,      m.type, d(m.protein));
      inc(repartition['Glucides']!,       m.type, d(m.carbs));
      inc(repartition['Lipides']!,        m.type, d(m.fat));
      inc(repartition['Fibres']!,         m.type, d(m.fiber));
      inc(repartition['Saturés']!,        m.type, d(m.fatSaturated));
      inc(repartition['Polyinsaturés']!,  m.type, d(m.fatPolyunsaturated));
      inc(repartition['Monoinsaturés']!,  m.type, d(m.fatMonounsaturated));
    }
  }

  return {
    'consumedMacros': consumedMacros,
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


//**** POUR DEBUG */
//void d(String msg) => debugPrint('[WEEK] $msg');

Future<Map<String, dynamic>> _collectDailyMealsData() async {
 

  // 1) Date clé unifiée
  final dateKey = DateService.formatStandard(state.selectedDate);
  // d('dateKey = $dateKey');

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
 

  // 7) Debug
  final counts = <String,int>{};
  for (final m in deduped) {
    counts[m.type] = (counts[m.type] ?? 0) + 1;
  }

  // 8) ✅ Totaux FIABLES (cast double + somme simple)
  int sumRound(Iterable<Meal> it, num? Function(Meal m) pick) {
  return it.fold<double>(0.0, (a, m) => a + ((pick(m) ?? 0).toDouble())).round();
}
  final totalsPerType = <String, Map<String,int>>{
    for (final type in allowed)
      type: {
        "kcal":    sumRound(deduped.where((m) => m.type == type), (m) => m.calories),
        "protein": sumRound(deduped.where((m) => m.type == type), (m) => m.protein),
        "carbs":   sumRound(deduped.where((m) => m.type == type), (m) => m.carbs),
        "fat":     sumRound(deduped.where((m) => m.type == type), (m) => m.fat),
        "fibres":  sumRound(deduped.where((m) => m.type == type), (m) => m.fiber),         
        "saturés": sumRound(deduped.where((m) => m.type == type), (m) => m.fatSaturated),  
      }
  };


  final dayTotals = {
    "kcal":    sumRound(deduped, (m) => m.calories),
    "protein": sumRound(deduped, (m) => m.protein),
    "carbs":   sumRound(deduped, (m) => m.carbs),
    "fat":     sumRound(deduped, (m) => m.fat),
    "fibres":  sumRound(deduped, (m) => m.fiber),
    "saturés": sumRound(deduped, (m) => m.fatSaturated),
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
  final intFibres = dayTotals["fibres"] as int;
  final intSat = dayTotals["saturés"] as int;

  final line1 = "Total $intKcal kcal — Prot $intProt g • Gluc $intCarbs g • Lip $intFat g • Fib $intFibres g (dont sat. $intSat g)";
  String _fmtTop(Meal m) => "${_cap(m.name)} (${m.calories.round()} kcal)";
  final line2 = (top.isEmpty) ? "Top cal. : —" : "Top cal. : ${top.map(_fmtTop).join(" ** ")}";
  final shortText = "$line1\n$line2";
  
  // 10) Payload complet
  final repasList = deduped.map((m) => m.toMap()).toList();
 
  return {
    "jour": {
      "date": dateKey,
      "text": shortText, // summary possible si besoin
      "sessions": sessions,
      "itemsParType": counts,
      "totaux": dayTotals,                 // total global (ints)
      "totauxParType": totalsPerType,      // totaux par type (ints)
      "repas": repasList,
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
  final weekDatesStr = weekDates
      .map((dt) => '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}')
      .join(', ');
 

  final dateKeys = weekDates.map(DateService.formatStandard).toList();
  

  // Récup par date
  final Map<String, List<Meal>> byDate = {
    for (final k in dateKeys) k: (state.weeklyMeals[k] ?? const <Meal>[])
  };
  final byDateCounts = byDate.entries.map((e) => '${e.key}: ${e.value.length}').join(', ');
  

  // Types autorisés
  const allowed = {'Petit-déjeuner', 'Déjeuner', 'Dîner', 'Collation','Activité'};

  // Dédup helper
  String norm(num x) => x.toStringAsFixed(2);
  String keyOf(Meal m) =>
      '${m.date}|${m.type}|${m.name}|${norm(m.calories)}|${norm(m.protein)}|${norm(m.carbs)}|${norm(m.fat)}|${norm(m.quantity)}';

  // Agrégats
  int breakfastDays = 0, lunchDays = 0, dinnerDays = 0, snackDays = 0, actDays = 0;
  double wkKcal = 0, wkPro = 0, wkCarb = 0, wkFat = 0,wkFibres = 0, wkSat = 0;

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

    sessionsPerDay[dateKey] = {
      "Petit-déjeuner": hasB ? 1 : 0,
      "Déjeuner":       hasL ? 1 : 0,
      "Dîner":          hasD ? 1 : 0,
      "Collation":      hasS ? 1 : 0,
      "Activité":       hasA ? 1 : 0,
    };


    // ★ Incréments oubliés
    breakfastDays += hasB ? 1 : 0;  // ★
    lunchDays     += hasL ? 1 : 0;  // ★
    dinnerDays    += hasD ? 1 : 0;  // ★
    snackDays     += hasS ? 1 : 0;  // ★
    actDays       += hasA ? 1 : 0;  // ★

    // totaux jour (casts robustes)
    double d(num? v) => (v ?? 0).toDouble();
    double kcal = 0, pro = 0, carb = 0, fat = 0, fibres = 0 ,sat = 0;
    for (final m in deduped) {
      kcal   += d(m.calories);
      pro    += d(m.protein);
      carb   += d(m.carbs);
      fat    += d(m.fat);
      fibres += (m.fiber ?? 0);   
      sat    += (m.fatSaturated ?? 0);  
    }
    double round1(double x) => (x * 10).round() / 10.0; 
    final dayTotals = {
      "kcal":    round1(kcal),
      "protein": round1(pro),
      "carbs":   round1(carb),
      "fat":     round1(fat),
      "fibres":  round1(fibres),
      "saturés": round1(sat),
      
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
    wkFibres += dayTotals["fibres"]!;
    wkSat += dayTotals["saturés"]!;
  }

  
  final summary =
      "Résumé de la semaine : $breakfastDays petits-déjeuners, "
      "$lunchDays déjeuners, $dinnerDays dîners, $snackDays collations, $actDays activité.";


  final weekTotals = {
    "kcal": double.parse(wkKcal.toStringAsFixed(1)),
    "protein": double.parse(wkPro.toStringAsFixed(1)),
    "carbs": double.parse(wkCarb.toStringAsFixed(1)),
    "fat": double.parse(wkFat.toStringAsFixed(1)),
    "fibres": double.parse(wkFibres.toStringAsFixed(1)),
    "saturés": double.parse(wkSat.toStringAsFixed(1)),
  };
 
  final payload = {
    "type": "week",
    "text": summary,
    "totaux": weekTotals,
    "sessionsParJour": sessionsPerDay,
    "jours": days,         // liste [{date, totaux, repas}]
  };


 
  return payload;
}




}

final dashboardProvider =
    StateNotifierProvider.autoDispose<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref);
});
