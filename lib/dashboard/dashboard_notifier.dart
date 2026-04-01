import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal.dart';
import '../models/day_snapshot.dart';
import '../repositories/meal_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/training_repository.dart';
import '../repositories/strava_repository.dart';
import '../repositories/daily_calories_repository.dart';
import '../services/date_service.dart';
import '../services/ai_providers.dart';
import '../services/ai_manager.dart';
import '../providers/common_providers.dart';
import 'dashboard_state.dart';
import '../repositories/daily_snapshot_remote_repository.dart';




class DashboardNotifier extends StateNotifier<DashboardState> {
  final Ref _ref;
  final DailySnapshotRemoteRepository _remoteRepo;
  final DailyCaloriesRepository _localRepo;
  late final UserRepository _userRepository =
      _ref.read(userRepositoryProvider);
  late final MealRepository _mealRepository =
      _ref.read(mealRepositoryProvider);
  late final StravaRepository _stravaRepository =
      _ref.read(stravaRepositoryProvider);
  late final AIManager _aiManager = _ref.read(aiManagerProvider);
  late final TrainingRepository _trainingRepository =
      _ref.read(trainingRepositoryProvider);
  bool _alive = true;
  bool _localHydrated = false;

    @override
    void dispose() {
      _alive = false;
      super.dispose();
    }

  bool _loadingLocal = false;
  bool _syncing = false;

  DashboardNotifier(this._ref,this._localRepo,
  this._remoteRepo,)
      : super(
          DashboardState(
            selectedDate: DateTime.now(),
            currentWeekStart: DateService.startOfWeek(DateTime.now()),
          ),
        );

  // ===========================================================================
  // == GESTION DES DONNÉES
  // ===========================================================================

  /// Sauvegarde locale (Hive) des infos journalières de calories.
  Future<void> _saveDailyCaloriesLocal({
    required DateTime day,
    required double neededKcal,
    required double consumedKcal,
    required double activityKcal,
  }) async {
    final dateStr = DateService.formatStandard(day);

    await _localRepo.upsert(
      date: dateStr,
      objectif: neededKcal,
      strava: activityKcal,
      total: consumedKcal,
    );
  }
  Future<void> hydrateLocalFromSupabase() async {
    try {
      final remoteDays = await _remoteRepo.fetchLastDays(limit: 90);
      if (remoteDays.isEmpty) return;

      for (final s in remoteDays) {
        await _localRepo.upsert(
          date: DateService.formatStandard(s.date),
          objectif: s.objectiveKcal,
          strava: s.activityKcal,
          total: s.consumedKcal,
        );
      }
    } catch (_) {
      // silent
    }
  }
Future<void> pushSelectedDayToSupabase() async {
  try {
    final date = DateTime(
      state.selectedDate.year,
      state.selectedDate.month,
      state.selectedDate.day,
    );

    final dateKey = DateService.formatStandard(date);

    // Source de vérité locale (Hive)
    final daily = _localRepo.getForDate(dateKey);
    if (daily == null) return;
    if ((daily.total == 0 || daily.total.isNaN) &&
            (daily.objectif == 0 || daily.objectif.isNaN)) {
          return;
        }
    final consumed = state.consumedMacros;

    final snapshot = DaySnapshot(
      date: date,

      // Énergie
      objectiveKcal: daily.objectif,
      activityKcal: daily.strava,
      consumedKcal: daily.total,

      // Macros
      proteinG: (consumed['Protéines'] ?? 0).toDouble(),
      carbsG: (consumed['Glucides'] ?? 0).toDouble(),
      fatG: (consumed['Lipides'] ?? 0).toDouble(),
      fiberG: (consumed['Fibres'] ?? 0).toDouble(),
      sugarsG: (consumed['Sucres'] ?? 0).toDouble(),

      // Qualité lipides
      fatSaturatedG: (consumed['Saturés'] ?? 0).toDouble(),
      fatMonounsaturatedG:
          (consumed['Monoinsaturés'] ?? 0).toDouble(),
      fatPolyunsaturatedG:
          (consumed['Polyinsaturés'] ?? 0).toDouble(),
    );

    await _remoteRepo.upsertDaySnapshot(snapshot);
  } catch (_) {
    // ⚠️ volontairement silencieux
  }
}

  /// Charge l'eau consommée depuis SharedPreferences (clé: water_yyyy-MM-dd).
  Future<double> _loadWaterLocal(DateTime day) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final key = 'water_${DateService.formatStandard(day)}';
    return prefs.getDouble(key) ?? 0.0;
  }

  /// Sauvegarde l'eau consommée en local.
  Future<void> _saveWaterLocal(DateTime day, double value) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final key = 'water_${DateService.formatStandard(day)}';
    await prefs.setDouble(key, value);
  }

  /// Charge ou recharge toutes les données de la page.
  
  
  Future<void> loadLocalData({DateTime? newSelectedDate}) async {
  if (_loadingLocal) return;
  _loadingLocal = true;

  state = state.copyWith(status: ViewStatus.loading);

  try {
// ✅ HYDRATATION INITIALE (UNE SEULE FOIS)
    if (!_localHydrated) {
      await hydrateLocalFromSupabase();
      _localHydrated = true;
    }

    state = state.copyWith(status: ViewStatus.loading);
    final dateForLoading = newSelectedDate ?? state.selectedDate;
    final currentWeekStart = DateService.startOfWeek(dateForLoading);

    if (newSelectedDate != null) {
      state = state.copyWith(
        selectedDate: dateForLoading,
        currentWeekStart: currentWeekStart,
      );
    }

    final dayKey = DateService.formatStandard(dateForLoading);
    final weekKey = "week_${DateService.formatStandard(currentWeekStart)}";

    // ✅ ICI : UNIQUEMENT LOCAL
    final results = await Future.wait([
      _userRepository.getProfile(),                                 // 0
      _mealRepository.getMealsForWeek(currentWeekStart),            // 1
      _getTheoreticalCaloriesSplit(),                               // 2
      _trainingRepository.getTrainingTypeForDate(dateForLoading),   // 3
      _trainingRepository.getTrainingTypeForDate(
        dateForLoading.add(const Duration(days: 1)),
      ),                                                            // 4
      _aiManager.cacheService.getCachedAnalysis(weekKey),           // 5
      _aiManager.cacheService.getCachedAnalysis(dayKey),            // 6
    ]);

  Future<bool> _getIsStravaConnected() async {
    return await _ref.read(isStravaConnectedProvider.future);
  }


    final userProfile = results[0] as UserProfile;
    if (!_alive) return;
    final weeklyMeals = results[1] as Map<String, List<Meal>>;
    final calorieSplit = results[2] as Map<String, double>;
    final typeToday = results[3] as String;
    final typeTomorrow = results[4] as String;
    final cachedWeeklyAnalysis = results[5] as String?;
    final cachedDailyAnalysis = results[6] as String?;

    // ✅ Strava = 0 en local (sera rempli après syncRemoteData)
    final dateKey = DateService.formatStandard(dateForLoading);

    // 🔥 SOURCE DE VÉRITÉ = Hive (DailyCalories)
    final daily = _localRepo.getForDate(dateKey);

    double stravaCalories = daily?.strava ?? 0.0;
    // 🔥 Source de vérité pour la liste d'activités = Hive (StravaDayActivities)
    // Sinon, un simple rebuild / navigation peut "vider" l'affichage jusqu'à resync.
    final activitiesRepo = _ref.read(stravaActivitiesRepositoryProvider);
    final cachedActivities = activitiesRepo.getForDate(dateKey);
    final List<dynamic> stravaActivities =
        cachedActivities?.activities ?? const [];

    // Si les activités sont bien en cache mais que DailyCalories.strava vaut 0,
    // on recalcule les kcal depuis les activités et on les persiste.
    if (stravaCalories <= 0 && stravaActivities.isNotEmpty) {
      double parsed = 0.0;
      for (final a in stravaActivities) {
        if (a is Map) {
          final raw = a['calories'];
          if (raw is num) {
            parsed += raw.toDouble();
          } else if (raw is String) {
            parsed += double.tryParse(raw.replaceAll(',', '.')) ?? 0.0;
          }
        }
      }
      stravaCalories = parsed;
      if (stravaCalories > 0) {
        await _localRepo.upsert(
          date: dateKey,
          objectif: daily?.objectif ?? 0.0,
          strava: stravaCalories,
          total: daily?.total ?? 0.0,
          stravaFetchedAt: DateTime.now(),
        );
      }
    }
    final bool isStravaConnected = await _getIsStravaConnected();


    final mealsForDay = weeklyMeals[dateKey] ?? [];
    final consumedData = _calculateConsumedMacros(mealsForDay);

    final neededMacros = _calculateMacroNeeds(
      userProfile,
      stravaCalories,
      typeToday,
      typeTomorrow,
    );

    const double baseWaterMl = 2500.0;
    final double waterGoalMl = baseWaterMl + stravaCalories;
    final double waterConsumedMl = await _loadWaterLocal(dateForLoading);
final prefs = _ref.read(sharedPreferencesProvider);
final localPrenom = prefs.getString('prenom') ?? '';

if (!_alive) return;

    state = state.copyWith(
      status: ViewStatus.success,
      prenom: localPrenom.isNotEmpty
        ? localPrenom
        : userProfile.firstName, 
      tdee: userProfile.tdee,
      weeklyMeals: weeklyMeals,
      theoreticalCalorieSplit: calorieSplit,
      consumedMacros: consumedData['consumedMacros'],
      caloriesPerMeal: consumedData['caloriesPerMeal'],
      macrosPerMealType: consumedData['macrosPerMealType'],
      macroNeeds: neededMacros,
      stravaCaloriesForDay: stravaCalories,
      stravaActivitiesForDay: stravaActivities,
      isStravaConnected: isStravaConnected,
      weeklyAiAnalysis: cachedWeeklyAnalysis ?? '',
      hasWeeklyAnalysis: (cachedWeeklyAnalysis ?? '').isNotEmpty,
      hasDailyAnalysis: (cachedDailyAnalysis ?? '').isNotEmpty,
      aiAnalysis: cachedDailyAnalysis ?? '',
      waterGoalMl: waterGoalMl,
      waterConsumedMl: waterConsumedMl,
      dailyCaloriesForDay: daily,

    );
   
    // Sauvegarde locale des calories journalières (ok)
    final consumedMap = Map<String, double>.from(state.consumedMacros);
    await _saveDailyCaloriesLocal(
      day: dateForLoading,
      neededKcal: (state.macroNeeds['Calories'] ?? 0).toDouble(),
      consumedKcal: (consumedMap['Calories'] ?? 0).toDouble(),
      activityKcal: stravaCalories,
    );
  } catch (e) {
    state = state.copyWith(status: ViewStatus.failure, errorMessage: e.toString());
  } finally {
    _loadingLocal = false;
  }
}

Future<void> syncRemoteData() async {
  if (_syncing) return;
  _syncing = true;

  try {
    final date = DateTime(
      state.selectedDate.year,
      state.selectedDate.month,
      state.selectedDate.day,
    );

    final strava = await _stravaRepository.getActivitiesAndCaloriesForDate(date);

    // ✅ mise à jour strava
    state = state.copyWith(
      isStravaConnected: true,
      stravaCaloriesForDay: strava.totalCalories,
      stravaActivitiesForDay: strava.activities,
      
    );

    // ✅ IMPORTANT : persister en local (Hive DailyCalories)
    final dateKey = DateService.formatStandard(date);
    await _localRepo.upsert(
      date: dateKey,
      objectif: (state.macroNeeds['Calories'] ?? 0).toDouble(),
      strava: strava.totalCalories,
      total: (state.consumedMacros['Calories'] ?? 0).toDouble(),
    );
    await pushSelectedDayToSupabase();
  } catch (_) {
    // ⚠️ si erreur, ne touche pas au prénom, ni aux autres champs
    state = state.copyWith(isStravaConnected: false);
  } finally {
    _syncing = false;
  }
}


/// pour bouton synchro strava
Future<void> forceStravaSync() async {
  if (_syncing) return;
  _syncing = true;

  try {
    final date = DateTime(
      state.selectedDate.year,
      state.selectedDate.month,
      state.selectedDate.day,
    );

    final strava = await _stravaRepository
        .getActivitiesAndCaloriesForDate(
          date,
          forceRefresh: true,
        );

    state = state.copyWith(
      isStravaConnected: true,
      stravaCaloriesForDay: strava.totalCalories,
      stravaActivitiesForDay: strava.activities,
    );

    // Persister la partie "kcal" en local, pour que loadLocalData puisse
    // réafficher Strava sans forcer un resync.
    final dateKey = DateService.formatStandard(date);
    await _localRepo.upsert(
      date: dateKey,
      objectif: (state.macroNeeds['Calories'] ?? 0).toDouble(),
      strava: strava.totalCalories,
      total: (state.consumedMacros['Calories'] ?? 0).toDouble(),
    );
    await pushSelectedDayToSupabase();
  } finally {
    _syncing = false;
  }
}


  Future<Map<String, double>> _getTheoreticalCaloriesSplit() async {
    // Placeholder simple (tu peux brancher ton vrai repo si besoin)
    const typeToday = "Endurance";
    if (typeToday == "Endurance") {
      return {
        'Petit-déjeuner': 0.33,
        'Déjeuner': 0.33,
        'Dîner': 0.27,
        'Collation': 0.07,
      };
    } else {
      return {
        'Petit-déjeuner': 0.23,
        'Déjeuner': 0.37,
        'Dîner': 0.33,
        'Collation': 0.07,
      };
    }
  }

  // ===========================================================================
  // == ACTIONS UTILISATEUR
  // ===========================================================================

  Future<void> selectDate(DateTime newDate) async {
    final normalized = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
    );

    if (DateService.formatStandard(normalized) ==
        DateService.formatStandard(state.selectedDate)) {
      return;
    }

    // 🔥 reset Strava pour éviter le recyclage
    state = state.copyWith(
      selectedDate: normalized,
      status: ViewStatus.loading,
    );

    await loadLocalData(newSelectedDate: normalized);
    await syncRemoteData(); // ✅ MANQUAIT ICI
  }


  /// Conserve le même **jour de semaine** lorsqu’on change de semaine.
  Future<void> changeWeek(int offset) async {
    state = state.copyWith(
      status: ViewStatus.loading,
      weeklyMeals: {},
    );
    final newWeekStart =
        state.currentWeekStart.add(Duration(days: 7 * offset));
    final weekdayDelta = state.selectedDate
        .difference(state.currentWeekStart)
        .inDays;
    final newSelectedDate =
        newWeekStart.add(Duration(days: weekdayDelta.clamp(0, 6)));

    state = state.copyWith(currentWeekStart: newWeekStart);
    await loadLocalData(newSelectedDate: newSelectedDate);
  }

  Future<void> resetToToday() async {
    final now = DateTime.now();
    state = state.copyWith(
      currentWeekStart: DateService.startOfWeek(now),
    );
    await loadLocalData(newSelectedDate: now);
  }

  // ===========================================================================
  // == LOGIQUE DE CALCUL
  // ===========================================================================

  Map<String, dynamic> _calculateConsumedMacros(
    List<Meal> meals,
  ) {
    final Map<String, double> consumedMacros = {
      "Calories": 0.0,
      "Protéines": 0.0,
      "Glucides": 0.0,
      "Lipides": 0.0,
      "Fibres": 0.0,
      "Saturés": 0.0,
      "Polyinsaturés": 0.0,
      "Monoinsaturés": 0.0,
      "Sucres": 0.0,
    };

    final Map<String, double> caloriesParRepas = {
      'Petit-déjeuner': 0.0,
      'Déjeuner': 0.0,
      'Dîner': 0.0,
      'Collation': 0.0,
      'Activité': 0.0,
    };

    final Map<String, Map<String, double>> repartition = {
      "Protéines": {},
      "Glucides": {},
      "Lipides": {},
      "Fibres": {},
      "Saturés": {},
      "Polyinsaturés": {},
      "Monoinsaturés": {},
      "Sucres": {},
    };

    double d(num? v) => (v ?? 0).toDouble();
    void inc(Map<String, double> b, String k, double add) =>
        b[k] = (b[k] ?? 0) + add;

    for (final m in meals) {
      consumedMacros['Calories'] =
          consumedMacros['Calories']! + d(m.calories);
      consumedMacros['Protéines'] =
          consumedMacros['Protéines']! + d(m.protein);
      consumedMacros['Glucides'] =
          consumedMacros['Glucides']! + d(m.carbs);
      consumedMacros['Lipides'] =
          consumedMacros['Lipides']! + d(m.fat);
      consumedMacros['Fibres'] =
          consumedMacros['Fibres']! + d(m.fiber);
      consumedMacros['Sucres'] =
          consumedMacros['Sucres']! + d(m.sucres);
      consumedMacros['Saturés'] =
          consumedMacros['Saturés']! + d(m.fatSaturated);
      consumedMacros['Polyinsaturés'] =
          consumedMacros['Polyinsaturés']! +
              d(m.fatPolyunsaturated);
      consumedMacros['Monoinsaturés'] =
          consumedMacros['Monoinsaturés']! +
              d(m.fatMonounsaturated);

      if (m.type.isNotEmpty &&
          caloriesParRepas.containsKey(m.type)) {
        caloriesParRepas[m.type] =
            caloriesParRepas[m.type]! + d(m.calories);
      }

      if (m.type.isNotEmpty) {
        inc(repartition['Protéines']!, m.type, d(m.protein));
        inc(repartition['Glucides']!, m.type, d(m.carbs));
        inc(repartition['Lipides']!, m.type, d(m.fat));
        inc(repartition['Fibres']!, m.type, d(m.fiber));
        inc(repartition['Sucres']!, m.type, d(m.sucres));
        inc(repartition['Saturés']!, m.type, d(m.fatSaturated));
        inc(
          repartition['Polyinsaturés']!,
          m.type,
          d(m.fatPolyunsaturated),
        );
        inc(
          repartition['Monoinsaturés']!,
          m.type,
          d(m.fatMonounsaturated),
        );
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

    if (typeToday == "Affûtage") {
      adjustedTDEE *= 0.90;
    }
    if (typeTomorrow == "Endurance") {
      adjustedTDEE *= 1.10;
    }

    double tdeeFinal = adjustedTDEE + stravaCals;

    final proteines = poids * 2;
    final remainingCalories = tdeeFinal - (proteines * 4);
    final glucides =
        (remainingCalories > 0 ? remainingCalories * 0.6 : 0) / 4;
    final lipides =
        (remainingCalories > 0 ? remainingCalories * 0.4 : 0) / 9;

    double baseFibres = 30.0;
    if (glucides > 300) {
      baseFibres = 35.0;
    } else if (glucides < 150) {
      baseFibres = 25.0;
    }

    return {
      "Calories": tdeeFinal,
      "Protéines": proteines,
      "Glucides": glucides,
      "Lipides": lipides,
      "Fibres": baseFibres,
    };
  }

  Future<void> refreshDataAfterMealUpdate() async {
    await loadLocalData();
    await pushSelectedDayToSupabase();
  }


  // ===========================================================================
  // == ANALYSE IA
  // ===========================================================================

  void setAnalysisType(bool isWeekly) async {
    state = state.copyWith(isWeeklyAnalysis: isWeekly);

    final key = isWeekly
        ? "week_${DateService.formatStandard(state.currentWeekStart)}"
        : DateService.formatStandard(state.selectedDate);

    final cached =
        await _aiManager.cacheService.getCachedAnalysis(key);
    if (isWeekly) {
      state = state.copyWith(
        weeklyAiAnalysis: cached ?? state.weeklyAiAnalysis,
        hasWeeklyAnalysis: (cached ?? '').isNotEmpty,
      );
    } else {
      state =
          state.copyWith(aiAnalysis: cached ?? state.aiAnalysis);
    }
  }

  Future<void> runMealAnalysis({bool force = false}) async {
    state = state.copyWith(analysisStatus: ViewStatus.loading);

    try {
      final String key;
      final Map<String, dynamic> data;

      if (state.isWeeklyAnalysis) {
        key =
            "week_${DateService.formatStandard(state.currentWeekStart)}";
        data = await _collectWeeklyMealsData();
      } else {
        key = DateService.formatStandard(state.selectedDate);
        data = await _collectDailyMealsData();
      }

      if (data.isEmpty ||
          (data['jour'] != null &&
              (data['jour']['repas'] as List).isEmpty)) {
        state = state.copyWith(
          analysisStatus: ViewStatus.success,
          aiAnalysis:
              "🤷‍♂️ Aucun repas trouvé. Ajoutez-en un !",
        );
        return;
      }

      var analysisResult =
          await _aiManager.getOrGenerateAnalysis(
        key,
        data,
        preferApi: true,
        force: force,
        provider: "mistral",
      );

      if (state.isWeeklyAnalysis) {
        state = state.copyWith(
          analysisStatus: ViewStatus.success,
          weeklyAiAnalysis: analysisResult,
          hasWeeklyAnalysis: true,
        );
      } else {
        final jour =
            data['jour'] as Map<String, dynamic>?;
        final short =
            (jour?['text'] as String?)?.trim() ?? '';
        if (short.isNotEmpty) {
          analysisResult = '$short\n\n$analysisResult';
        }

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
    final dateKey =
        DateService.formatStandard(state.selectedDate);

    final baseList =
        state.weeklyMeals[dateKey] ?? const <Meal>[];

    if (baseList.isEmpty) {
      return {
        "jour": {
          "date": dateKey,
          "repas": <Map<String, dynamic>>[],
          "text": "Résumé du jour : aucun repas.",
          "totaux": {
            "kcal": 0.0,
            "protein": 0.0,
            "carbs": 0.0,
            "fat": 0.0,
          },
        }
      };
    }

    const allowed = {
      'Petit-déjeuner',
      'Déjeuner',
      'Dîner',
      'Collation',
      'Activité',
    };
    final filtered = baseList
        .where((m) => allowed.contains(m.type))
        .toList();
    if (filtered.isEmpty) {
      return {
        "jour": {
          "date": dateKey,
          "repas": <Map<String, dynamic>>[],
          "text": "Résumé du jour : aucun repas.",
          "totaux": {
            "kcal": 0.0,
            "protein": 0.0,
            "carbs": 0.0,
            "fat": 0.0,
          },
        }
      };
    }

    String norm(num x) => x.toStringAsFixed(2);
    String keyOf(Meal m) =>
        '${m.date}|${m.type}|${m.name}|${norm(m.calories)}|${norm(m.protein)}|${norm(m.carbs)}|${norm(m.fat)}|${norm(m.quantity)}';

    final seen = <String>{};
    final deduped = <Meal>[];
    for (final m in filtered) {
      if (seen.add(keyOf(m))) deduped.add(m);
    }

    final hasType = {
      'Petit-déjeuner':
          deduped.any((m) => m.type == 'Petit-déjeuner'),
      'Déjeuner': deduped.any((m) => m.type == 'Déjeuner'),
      'Dîner': deduped.any((m) => m.type == 'Dîner'),
      'Collation':
          deduped.any((m) => m.type == 'Collation'),
      'Activité':
          deduped.any((m) => m.type == 'Activité'),
    };
    final sessions = {
      'Petit-déjeuner': hasType['Petit-déjeuner']! ? 1 : 0,
      'Déjeuner': hasType['Déjeuner']! ? 1 : 0,
      'Dîner': hasType['Dîner']! ? 1 : 0,
      'Collation': hasType['Collation']! ? 1 : 0,
      'Activité': hasType['Activité']! ? 1 : 0,
    };

    final counts = <String, int>{};
    for (final m in deduped) {
      counts[m.type] = (counts[m.type] ?? 0) + 1;
    }

    int sumRound(Iterable<Meal> it, num? Function(Meal m) pick) {
      return it.fold<double>(
        0.0,
        (a, m) => a + ((pick(m) ?? 0).toDouble()),
      ).round();
    }

    final allowedTypes = allowed;
    final totalsPerType =
        <String, Map<String, int>>{
      for (final type in allowedTypes)
        type: {
          "kcal": sumRound(
              deduped.where((m) => m.type == type),
              (m) => m.calories),
          "protein": sumRound(
              deduped.where((m) => m.type == type),
              (m) => m.protein),
          "carbs": sumRound(
              deduped.where((m) => m.type == type),
              (m) => m.carbs),
          "fat": sumRound(
              deduped.where((m) => m.type == type),
              (m) => m.fat),
          "fibres": sumRound(
              deduped.where((m) => m.type == type),
              (m) => m.fiber),
          "saturés": sumRound(
              deduped.where((m) => m.type == type),
              (m) => m.fatSaturated),
        }
    };

    final dayTotals = {
      "kcal": sumRound(deduped, (m) => m.calories),
      "protein": sumRound(deduped, (m) => m.protein),
      "carbs": sumRound(deduped, (m) => m.carbs),
      "fat": sumRound(deduped, (m) => m.fat),
      "fibres": sumRound(deduped, (m) => m.fiber),
      "saturés": sumRound(deduped, (m) => m.fatSaturated),
    };

    final sortedByKcal = [...deduped]
      ..sort(
        (a, b) => b.calories.compareTo(a.calories),
      );
    final top = sortedByKcal.take(3).toList();

    String _cap(String s, {int max = 22}) =>
        (s.length <= max)
            ? s
            : (s.substring(0, max - 1) + '…');

    final intKcal = dayTotals["kcal"] as int;
    final intProt = dayTotals["protein"] as int;
    final intCarbs = dayTotals["carbs"] as int;
    final intFat = dayTotals["fat"] as int;
    final intFibres = dayTotals["fibres"] as int;
    final intSat = dayTotals["saturés"] as int;

    final line1 =
        "Total $intKcal kcal — Prot $intProt g • Gluc $intCarbs g • Lip $intFat g • Fib $intFibres g (dont sat. $intSat g)";
    String _fmtTop(Meal m) =>
        "${_cap(m.name)} (${m.calories.round()} kcal)";
    final line2 = (top.isEmpty)
        ? "Top cal. : —"
        : "Top cal. : ${top.map(_fmtTop).join(" ** ")}";
    final shortText = "$line1\n$line2";

    final repasList =
        deduped.map((m) => m.toAIMap()).toList();

    return {
      "jour": {
        "date": dateKey,
        "text": shortText,
        "sessions": sessions,
        "itemsParType": counts,
        "totaux": dayTotals,
        "totauxParType": totalsPerType,
        "repas": repasList,
        "top2": top.map((m) => m.toAIMap()).toList(),
      }
    };
  }

  void toggleDailyExpanded() {
    state = state.copyWith(
      isDailyExpanded: !state.isDailyExpanded,
    );
  }

  void toggleWeeklyExpanded() {
    state = state.copyWith(
      isWeeklyExpanded: !state.isWeeklyExpanded,
    );
  }

  List<DateTime> _getWeekDates(DateTime startOfWeek) {
    return List.generate(
      7,
      (i) => startOfWeek.add(Duration(days: i)),
    );
  }

  Future<Map<String, dynamic>> _collectWeeklyMealsData() async {
    final weekStart = state.currentWeekStart;
    final weekDates = _getWeekDates(weekStart);
    final dateKeys =
        weekDates.map(DateService.formatStandard).toList();

    final Map<String, List<Meal>> byDate = {
      for (final k in dateKeys)
        k: (state.weeklyMeals[k] ?? const <Meal>[])
    };

    const allowed = {
      'Petit-déjeuner',
      'Déjeuner',
      'Dîner',
      'Collation',
      'Activité',
    };

    String norm(num x) => x.toStringAsFixed(2);
    String keyOf(Meal m) =>
        '${m.date}|${m.type}|${m.name}|${norm(m.calories)}|${norm(m.protein)}|${norm(m.carbs)}|${norm(m.fat)}|${norm(m.quantity)}';

    int breakfastDays = 0,
        lunchDays = 0,
        dinnerDays = 0,
        snackDays = 0,
        actDays = 0;
    double wkKcal = 0,
        wkPro = 0,
        wkCarb = 0,
        wkFat = 0,
        wkFibres = 0,
        wkSat = 0;

    final sessionsPerDay =
        <String, Map<String, int>>{};
    final days = <Map<String, dynamic>>[];

    for (final dateKey in dateKeys) {
      final baseList = byDate[dateKey] ?? const <Meal>[];

      if (baseList.isEmpty) {
        days.add({
          "date": dateKey,
          "repas": <Map<String, dynamic>>[],
          "totaux": {
            "kcal": 0.0,
            "protein": 0.0,
            "carbs": 0.0,
            "fat": 0.0,
          },
        });
        sessionsPerDay[dateKey] = {
          "Petit-déjeuner": 0,
          "Déjeuner": 0,
          "Dîner": 0,
          "Collation": 0,
          "Activité": 0,
        };
        continue;
      }

      final filtered = baseList
          .where((m) => allowed.contains(m.type))
          .toList();
      final seen = <String>{};
      final deduped = <Meal>[];
      for (final m in filtered) {
        if (seen.add(keyOf(m))) deduped.add(m);
      }

      final hasB =
          deduped.any((m) => m.type == 'Petit-déjeuner');
      final hasL =
          deduped.any((m) => m.type == 'Déjeuner');
      final hasD =
          deduped.any((m) => m.type == 'Dîner');
      final hasS =
          deduped.any((m) => m.type == 'Collation');
      final hasA =
          deduped.any((m) => m.type == 'Activité');

      sessionsPerDay[dateKey] = {
        "Petit-déjeuner": hasB ? 1 : 0,
        "Déjeuner": hasL ? 1 : 0,
        "Dîner": hasD ? 1 : 0,
        "Collation": hasS ? 1 : 0,
        "Activité": hasA ? 1 : 0,
      };

      breakfastDays += hasB ? 1 : 0;
      lunchDays += hasL ? 1 : 0;
      dinnerDays += hasD ? 1 : 0;
      snackDays += hasS ? 1 : 0;
      actDays += hasA ? 1 : 0;

      double d(num? v) => (v ?? 0).toDouble();
      double kcal = 0,
          pro = 0,
          carb = 0,
          fat = 0,
          fibres = 0,
          sat = 0;
      for (final m in deduped) {
        kcal += d(m.calories);
        pro += d(m.protein);
        carb += d(m.carbs);
        fat += d(m.fat);
        fibres += (m.fiber ?? 0);
        sat += (m.fatSaturated ?? 0);
      }
      double round1(double x) =>
          (x * 10).round() / 10.0;
      final dayTotals = {
        "kcal": round1(kcal),
        "protein": round1(pro),
        "carbs": round1(carb),
        "fat": round1(fat),
        "fibres": round1(fibres),
        "saturés": round1(sat),
      };

      days.add({
        "date": dateKey,
        "totaux": dayTotals,
        "repas": deduped.map((e) => e.toAIMap()).toList(),
      });

      wkKcal += dayTotals["kcal"]!;
      wkPro += dayTotals["protein"]!;
      wkCarb += dayTotals["carbs"]!;
      wkFat += dayTotals["fat"]!;
      wkFibres += dayTotals["fibres"]!;
      wkSat += dayTotals["saturés"]!;
    }

    final summary =
        "Résumé de la semaine : $breakfastDays petits-déjeuners, "
        "$lunchDays déjeuners, $dinnerDays dîners, "
        "$snackDays collations, $actDays activité.";

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
      "jours": days,
    };

    return payload;
  }

  Future<void> addWater(double amountMl) async {
    final newTotal =
        state.waterConsumedMl + amountMl;
    state =
        state.copyWith(waterConsumedMl: newTotal);

    await _saveWaterLocal(state.selectedDate, newTotal);

    await _saveDailyCaloriesLocal(
      day: state.selectedDate,
      neededKcal:
          state.macroNeeds['Calories'] ?? 0.0,
      consumedKcal:
          state.consumedMacros['Calories'] ?? 0.0,
      activityKcal: state.stravaCaloriesForDay,
    );
  }

  Future<void> removeWater(double amountMl) async {
    final newTotal = (state.waterConsumedMl - amountMl)
        .clamp(0.0, double.infinity);
    state =
        state.copyWith(waterConsumedMl: newTotal);

    await _saveWaterLocal(state.selectedDate, newTotal);

    await _saveDailyCaloriesLocal(
      day: state.selectedDate,
      neededKcal:
          state.macroNeeds['Calories'] ?? 0.0,
      consumedKcal:
          state.consumedMacros['Calories'] ?? 0.0,
      activityKcal: state.stravaCaloriesForDay,
    );
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(
    ref,
    ref.watch(dailyCaloriesRepositoryProvider),
    ref.watch(dailySnapshotRemoteRepositoryProvider),
  );
});


/// Petit helper pour sérialiser un Meal vers un Map utilisable par l'IA.
extension MealAIMap on Meal {
  Map<String, dynamic> toAIMap() => {
        "name": name,
        "calories": calories,
        "protein": protein,
        "carbs": carbs,
        "fat": fat,
        "quantity": quantity,
        "type": type,
        "date": date,
        "fiber": fiber,
        "sucres": sucres,
        "fatSaturated": fatSaturated,
        "fatMonounsaturated": fatMonounsaturated,
        "fatPolyunsaturated": fatPolyunsaturated,

        // 🔥 Infos /100 g dérivées → beaucoup plus utiles pour l'IA
        "kcalPer100": kcalPer100X,
        "proteinPer100": proteinPer100X,
        "carbsPer100": carbsPer100X,
        "fatPer100": fatPer100X,
        "fibersPer100": fibersPer100X,
        "sugarsPer100": sugarsPer100X,
        "saturatedFatPer100": fatSaturatedPer100X,
        "polyunsaturatedFatPer100": fatPolyunsaturatedPer100X,
        "monounsaturatedFatPer100": fatMonounsaturatedPer100X,
        "unsaturatedFatPer100": fatUnsaturatedPer100X,
      };
}
