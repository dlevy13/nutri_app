import 'package:equatable/equatable.dart';
import '../models/meal.dart';
import '../models/daily_calories.dart';

//refonte
enum ViewStatus { initial, loading, success, failure }

class DashboardState extends Equatable {
  // --- ÉTAT GÉNÉRAL ---
  final ViewStatus status;
  final String? errorMessage;

  // --- DONNÉES UTILISATEUR ---
  final String prenom;
  final double tdee;
  final Map<String, double> macroNeeds;

  // --- DATE & SEMAINE ---
  final DateTime selectedDate;
  final DateTime currentWeekStart;
  final Map<String, List<Meal>> weeklyMeals;

  // --- CONSOMMATION & MACROS ---
  final Map<String, double> consumedMacros;
  final Map<String, double> caloriesPerMeal;

  final Map<String, Map<String, double>> macrosPerMealType;

  final Map<String, double> theoreticalCalorieSplit;
  final DailyCalories? dailyCaloriesForDay;

  // --- STRAVA ---
  final double stravaCaloriesForDay;
  final List<dynamic> stravaActivitiesForDay;
  final bool isStravaConnected;

  // --- ANALYSE IA ---
  final ViewStatus analysisStatus;
  final String aiAnalysis;
  final bool isWeeklyAnalysis;
  final String weeklyAiAnalysis;
  final bool hasWeeklyAnalysis;
  final bool hasDailyAnalysis;

  final bool isDailyExpanded;
  final bool isWeeklyExpanded;

  // --- EAU ---
  final double waterGoalMl;
  final double waterConsumedMl;

  const DashboardState({
    this.status = ViewStatus.initial,
    this.errorMessage,
    this.prenom = '',
    this.tdee = 0.0,
    this.macroNeeds = const {},

    required this.selectedDate,
    required this.currentWeekStart,

    this.weeklyMeals = const {},

    this.consumedMacros = const {"Calories": 0, "Protéines": 0, "Glucides": 0, "Lipides": 0},
    this.caloriesPerMeal = const {},
    this.dailyCaloriesForDay,
    this.macrosPerMealType = const {
      "Protéines": {},
      "Glucides": {},
      "Lipides": {},
      "Fibres": {},
      "Saturés": {},
      "Polyinsaturés": {},
      "Monoinsaturés": {},
      "Sucres": {},
    },

    this.theoreticalCalorieSplit = const {},

    this.stravaCaloriesForDay = 0.0,
    this.stravaActivitiesForDay = const [],
    this.isStravaConnected = false,

    this.analysisStatus = ViewStatus.initial,
    this.aiAnalysis = '',
    this.isWeeklyAnalysis = false,
    this.weeklyAiAnalysis = '',
    this.hasWeeklyAnalysis = false,
    this.hasDailyAnalysis = false,

    this.isDailyExpanded = false,
    this.isWeeklyExpanded = false,

    this.waterGoalMl = 2500.0,
    this.waterConsumedMl = 0.0,
  });

  DashboardState copyWith({
    ViewStatus? status,
    String? errorMessage,
    String? prenom,
    double? tdee,
    Map<String, double>? macroNeeds,
    DateTime? selectedDate,
    DateTime? currentWeekStart,
    Map<String, List<Meal>>? weeklyMeals,
    Map<String, double>? consumedMacros,
    Map<String, double>? caloriesPerMeal,
    Map<String, Map<String, double>>? macrosPerMealType,
    Map<String, double>? theoreticalCalorieSplit,
    double? stravaCaloriesForDay,
    List<dynamic>? stravaActivitiesForDay,
    bool? isStravaConnected,
    DailyCalories? dailyCaloriesForDay,
    ViewStatus? analysisStatus,
    String? aiAnalysis,
    bool? isWeeklyAnalysis,
    String? weeklyAiAnalysis,
    bool? hasWeeklyAnalysis,
    bool? hasDailyAnalysis,
    bool? isDailyExpanded,
    bool? isWeeklyExpanded,
    double? waterGoalMl,
    double? waterConsumedMl,
  }) {
    return DashboardState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      prenom: prenom ?? this.prenom,
      tdee: tdee ?? this.tdee,
      macroNeeds: macroNeeds ?? this.macroNeeds,

      selectedDate: selectedDate ?? this.selectedDate,
      currentWeekStart: currentWeekStart ?? this.currentWeekStart,

      weeklyMeals: weeklyMeals ?? this.weeklyMeals,

      consumedMacros: consumedMacros ?? this.consumedMacros,
      caloriesPerMeal: caloriesPerMeal ?? this.caloriesPerMeal,
      macrosPerMealType: macrosPerMealType ?? this.macrosPerMealType,
      theoreticalCalorieSplit: theoreticalCalorieSplit ?? this.theoreticalCalorieSplit,

      stravaCaloriesForDay: stravaCaloriesForDay ?? this.stravaCaloriesForDay,
      stravaActivitiesForDay: stravaActivitiesForDay ?? this.stravaActivitiesForDay,
      isStravaConnected: isStravaConnected ?? this.isStravaConnected,

      analysisStatus: analysisStatus ?? this.analysisStatus,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      isWeeklyAnalysis: isWeeklyAnalysis ?? this.isWeeklyAnalysis,
      weeklyAiAnalysis: weeklyAiAnalysis ?? this.weeklyAiAnalysis,
      hasWeeklyAnalysis: hasWeeklyAnalysis ?? this.hasWeeklyAnalysis,
      hasDailyAnalysis: hasDailyAnalysis ?? this.hasDailyAnalysis,

      isDailyExpanded: isDailyExpanded ?? this.isDailyExpanded,
      isWeeklyExpanded: isWeeklyExpanded ?? this.isWeeklyExpanded,

      waterGoalMl: waterGoalMl ?? this.waterGoalMl,
      waterConsumedMl: waterConsumedMl ?? this.waterConsumedMl,
      dailyCaloriesForDay:dailyCaloriesForDay ?? this.dailyCaloriesForDay,
    );
  }

  @override
  List<Object?> get props => [
        status,
        errorMessage,
        prenom,
        tdee,
        macroNeeds,
        selectedDate,
        currentWeekStart,
        weeklyMeals,
        consumedMacros,
        caloriesPerMeal,
        macrosPerMealType,
        theoreticalCalorieSplit,
        stravaCaloriesForDay,
        stravaActivitiesForDay,
        isStravaConnected,
        analysisStatus,
        aiAnalysis,
        isWeeklyAnalysis,
        weeklyAiAnalysis,
        hasWeeklyAnalysis,
        hasDailyAnalysis,
        isDailyExpanded,
        isWeeklyExpanded,
        waterGoalMl,
        waterConsumedMl,
        dailyCaloriesForDay,
      ];
}
