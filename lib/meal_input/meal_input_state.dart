import 'package:equatable/equatable.dart';
import '../models/meal.dart';

//refonte
enum SearchStatus { initial, loading, success, failure }

class MealInputState extends Equatable {
  final SearchStatus status;
  final String selectedMealType;
  final DateTime selectedDate;
  final DateTime? fullTimestamp; // <-- 1. AJOUTÉ
  
  final List<Meal> addedFoodsForDay; 
  final List<Meal> recentSuggestions; 
  final List<dynamic> searchSuggestions; 
  final List<Meal> yesterdayMealSuggestions; 
  final List<Meal> historySearchSuggestions;
  final List<Meal> allRecentMeals;
 


  const MealInputState({
    this.status = SearchStatus.initial,
    required this.selectedMealType,
    required this.selectedDate,
    this.fullTimestamp, // <-- 2. AJOUTÉ
    this.addedFoodsForDay = const [],
    this.recentSuggestions = const [],
    this.searchSuggestions = const [],
    this.yesterdayMealSuggestions = const [],
    this.historySearchSuggestions = const [],
     this.allRecentMeals = const [],
  });
  
  MealInputState copyWith({
    SearchStatus? status,
    String? selectedMealType,
    DateTime? fullTimestamp, // <-- 3. AJOUTÉ
    List<Meal>? addedFoodsForDay,
    List<Meal>? recentSuggestions,
    List<dynamic>? searchSuggestions,
    List<Meal>? yesterdayMealSuggestions,
    List<Meal>? historySearchSuggestions,
    List<Meal>? allRecentMeals, 
  }) {
    return MealInputState(
      status: status ?? this.status,
      selectedMealType: selectedMealType ?? this.selectedMealType,
      selectedDate: selectedDate, 
      fullTimestamp: fullTimestamp ?? this.fullTimestamp, // <-- 4. AJOUTÉ
      addedFoodsForDay: addedFoodsForDay ?? this.addedFoodsForDay,
      recentSuggestions: recentSuggestions ?? this.recentSuggestions,
      searchSuggestions: searchSuggestions ?? this.searchSuggestions,
      yesterdayMealSuggestions: yesterdayMealSuggestions ?? this.yesterdayMealSuggestions,
      historySearchSuggestions: historySearchSuggestions ?? this.historySearchSuggestions,
      allRecentMeals: allRecentMeals ?? this.allRecentMeals,
    );
  }
  
  @override
  List<Object?> get props => [
        status,
        selectedMealType,
        selectedDate, // <-- 5. AJOUTÉ (pour être propre)
        fullTimestamp, // <-- 6. AJOUTÉ
        addedFoodsForDay,
        recentSuggestions,
        searchSuggestions,
        yesterdayMealSuggestions,
        historySearchSuggestions,
        allRecentMeals, 
      ];
}