import 'package:equatable/equatable.dart';
import '../models/meal.dart';

//refonte
enum SearchStatus { initial, loading, success, failure }

const _unsetSportGroup = Object();
const _unsetSportBrand = Object();

class MealInputState extends Equatable {
  final SearchStatus status;
  final String selectedMealType;
  final DateTime selectedDate;
  final DateTime? fullTimestamp; // <-- 1. AJOUTÉ
  final List<String> sportProductGroups;
  final List<String> sportProductBrands;
  final String? selectedSportProductGroup;
  final String? selectedSportProductBrand;
  final String? sportProductError;

  final List<Meal> addedFoodsForDay;
  final List<Meal> recentSuggestions;
  final List<dynamic> searchSuggestions;
  final List<dynamic> sportProductSuggestions;
  final List<Meal> yesterdayMealSuggestions;
  final List<Meal> historySearchSuggestions;
  final List<Meal> allRecentMeals;

  const MealInputState({
    this.status = SearchStatus.initial,
    required this.selectedMealType,
    required this.selectedDate,
    this.fullTimestamp, // <-- 2. AJOUTÉ
    this.sportProductGroups = const [],
    this.sportProductBrands = const [],
    this.selectedSportProductGroup,
    this.selectedSportProductBrand,
    this.sportProductError,
    this.addedFoodsForDay = const [],
    this.recentSuggestions = const [],
    this.searchSuggestions = const [],
    this.sportProductSuggestions = const [],
    this.yesterdayMealSuggestions = const [],
    this.historySearchSuggestions = const [],
    this.allRecentMeals = const [],
  });

  MealInputState copyWith({
    SearchStatus? status,
    String? selectedMealType,
    DateTime? selectedDate,
    DateTime? fullTimestamp, // <-- 3. AJOUTÉ
    List<String>? sportProductGroups,
    List<String>? sportProductBrands,
    Object? selectedSportProductGroup = _unsetSportGroup,
    Object? selectedSportProductBrand = _unsetSportBrand,
    String? sportProductError,
    List<Meal>? addedFoodsForDay,
    List<Meal>? recentSuggestions,
    List<dynamic>? searchSuggestions,
    List<dynamic>? sportProductSuggestions,
    List<Meal>? yesterdayMealSuggestions,
    List<Meal>? historySearchSuggestions,
    List<Meal>? allRecentMeals,
  }) {
    return MealInputState(
      status: status ?? this.status,
      selectedMealType: selectedMealType ?? this.selectedMealType,
      selectedDate: selectedDate ?? this.selectedDate,
      fullTimestamp: fullTimestamp ?? this.fullTimestamp, // <-- 4. AJOUTÉ
      sportProductGroups: sportProductGroups ?? this.sportProductGroups,
      sportProductBrands: sportProductBrands ?? this.sportProductBrands,
      selectedSportProductGroup:
          identical(selectedSportProductGroup, _unsetSportGroup)
              ? this.selectedSportProductGroup
              : selectedSportProductGroup as String?,
      selectedSportProductBrand:
          identical(selectedSportProductBrand, _unsetSportBrand)
              ? this.selectedSportProductBrand
              : selectedSportProductBrand as String?,
      sportProductError: sportProductError ?? this.sportProductError,
      addedFoodsForDay: addedFoodsForDay ?? this.addedFoodsForDay,
      recentSuggestions: recentSuggestions ?? this.recentSuggestions,
      searchSuggestions: searchSuggestions ?? this.searchSuggestions,
      sportProductSuggestions:
          sportProductSuggestions ?? this.sportProductSuggestions,
      yesterdayMealSuggestions:
          yesterdayMealSuggestions ?? this.yesterdayMealSuggestions,
      historySearchSuggestions:
          historySearchSuggestions ?? this.historySearchSuggestions,
      allRecentMeals: allRecentMeals ?? this.allRecentMeals,
    );
  }

  @override
  List<Object?> get props => [
        status,
        selectedMealType,
        selectedDate, // <-- 5. AJOUTÉ (pour être propre)
        fullTimestamp, // <-- 6. AJOUTÉ
        sportProductGroups,
        sportProductBrands,
        selectedSportProductGroup,
        selectedSportProductBrand,
        sportProductError,
        addedFoodsForDay,
        recentSuggestions,
        searchSuggestions,
        sportProductSuggestions,
        yesterdayMealSuggestions,
        historySearchSuggestions,
        allRecentMeals,
      ];
}
