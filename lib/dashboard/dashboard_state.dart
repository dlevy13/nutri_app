import 'package:equatable/equatable.dart';
import '../models/meal.dart';

// Enum pour gérer les états de chargement de manière plus propre
enum ViewStatus { initial, loading, success, failure }

class DashboardState extends Equatable {
  // --- ÉTAT GÉNÉRAL ---
  final ViewStatus status;
  final String? errorMessage;

  // --- DONNÉES UTILISATEUR & PROFIL ---
  final String prenom;
  final double tdee; // TDEE de base sans ajustements
  final Map<String, double> macroNeeds; // Besoins calculés pour le jour J

  // --- GESTION DE LA DATE & SEMAINE ---
  final DateTime selectedDate;
  final DateTime currentWeekStart;
  final Map<String, List<Meal>> weeklyMeals;

  // --- MACROS & CALORIES CONSOMMÉES ---
  final Map<String, double> consumedMacros;
  final Map<String, double> caloriesPerMeal;
  final Map<String, Map<String, double>> macrosPerMealType;
  final Map<String, double> theoreticalCalorieSplit;

  // --- DONNÉES STRAVA ---
  final double stravaCaloriesForDay;
  final List<dynamic> stravaActivitiesForDay;
  final bool isStravaConnected;

  // --- ANALYSE IA ---
  final ViewStatus analysisStatus;
  final String aiAnalysis;
  final bool isWeeklyAnalysis;
  final String weeklyAiAnalysis;      // Pour stocker le texte de l'analyse de la semaine
  final bool hasWeeklyAnalysis;
  final bool hasDailyAnalysis;
  final bool isDailyExpanded;
  final bool isWeeklyExpanded;

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
    this.macrosPerMealType = const {},
    this.stravaCaloriesForDay = 0.0,
    this.isStravaConnected = false,
    this.stravaActivitiesForDay = const [],
    this.analysisStatus = ViewStatus.initial,
    this.aiAnalysis = '',
    this.isWeeklyAnalysis = false,
    this.theoreticalCalorieSplit = const {},
    this.weeklyAiAnalysis = '',
    this.hasWeeklyAnalysis = false,
    this.hasDailyAnalysis = false,
    this.isDailyExpanded = false,
    this.isWeeklyExpanded = false,
  });

  // La méthode copyWith est essentielle pour mettre à jour l'état de manière immuable.
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
    double? stravaCaloriesForDay,
    List<dynamic>? stravaActivitiesForDay,
    ViewStatus? analysisStatus,
    String? aiAnalysis,
    bool? isWeeklyAnalysis,
    bool? isStravaConnected,
     Map<String, double>? theoreticalCalorieSplit,
      String? weeklyAiAnalysis,
    bool? hasWeeklyAnalysis,
    bool? hasDailyAnalysis,
    bool? isDailyExpanded,
    bool? isWeeklyExpanded,
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
      stravaCaloriesForDay: stravaCaloriesForDay ?? this.stravaCaloriesForDay,
      stravaActivitiesForDay: stravaActivitiesForDay ?? this.stravaActivitiesForDay,
      analysisStatus: analysisStatus ?? this.analysisStatus,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      isWeeklyAnalysis: isWeeklyAnalysis ?? this.isWeeklyAnalysis,
      isStravaConnected: isStravaConnected ?? this.isStravaConnected,
      weeklyAiAnalysis: weeklyAiAnalysis ?? this.weeklyAiAnalysis,
      hasWeeklyAnalysis: hasWeeklyAnalysis ?? this.hasWeeklyAnalysis,
      hasDailyAnalysis: hasDailyAnalysis ?? this.hasDailyAnalysis,
      theoreticalCalorieSplit: theoreticalCalorieSplit ?? this.theoreticalCalorieSplit,
      isDailyExpanded: isDailyExpanded ?? this.isDailyExpanded,
      isWeeklyExpanded: isWeeklyExpanded ?? this.isWeeklyExpanded,
    );
  }

  // `Equatable` permet de comparer les objets DashboardState et d'éviter
  // les reconstructions inutiles du widget si l'état n'a pas réellement changé.
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
        stravaCaloriesForDay,
        isStravaConnected,
        stravaActivitiesForDay,
        analysisStatus,
        aiAnalysis,
        isWeeklyAnalysis,
        theoreticalCalorieSplit,
        weeklyAiAnalysis,
        hasWeeklyAnalysis,
        hasDailyAnalysis,
      ];
}