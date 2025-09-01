import 'package:equatable/equatable.dart';
import '../models/meal.dart';

enum SearchStatus { initial, loading, success, failure }

class MealInputState extends Equatable {
  final SearchStatus status;
  final String selectedMealType;
  final DateTime selectedDate;
  
  final List<Meal> addedFoodsForDay; // Aliments déjà ajoutés
  final List<Meal> recentSuggestions; // Suggestions fréquentes
  final List<dynamic> searchSuggestions; // Suggestions de la recherche
  final List<Meal> yesterdayMealSuggestions; 

  const MealInputState({
    this.status = SearchStatus.initial,
    required this.selectedMealType,
    required this.selectedDate,
    this.addedFoodsForDay = const [],
    this.recentSuggestions = const [],
    this.searchSuggestions = const [],
    this.yesterdayMealSuggestions = const [],
  });
  
  MealInputState copyWith({
    SearchStatus? status,
    String? selectedMealType,
    List<Meal>? addedFoodsForDay,
    List<Meal>? recentSuggestions,
    List<dynamic>? searchSuggestions,
    List<Meal>? yesterdayMealSuggestions,
  }) {
    return MealInputState(
      status: status ?? this.status,
      selectedMealType: selectedMealType ?? this.selectedMealType,
      selectedDate: selectedDate, // Ne change pas
      addedFoodsForDay: addedFoodsForDay ?? this.addedFoodsForDay,
      recentSuggestions: recentSuggestions ?? this.recentSuggestions,
      searchSuggestions: searchSuggestions ?? this.searchSuggestions,
      yesterdayMealSuggestions: yesterdayMealSuggestions ?? this.yesterdayMealSuggestions,
    );
  }
  
  @override
  List<Object?> get props => [
        status,
        selectedMealType,
        addedFoodsForDay,
        recentSuggestions,
        searchSuggestions,
        yesterdayMealSuggestions 
      ];
}