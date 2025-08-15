import 'package:equatable/equatable.dart';
import '../models/meal.dart';

enum SearchStatus { initial, loading, success, failure }

class MealInputState extends Equatable {
  final SearchStatus status;
  final String selectedMealType;
  final DateTime selectedDate;
  
  final List<Meal> addedFoodsForDay; // Aliments déjà ajoutés
  final List<Meal> frequentSuggestions; // Suggestions fréquentes
  final List<dynamic> searchSuggestions; // Suggestions de la recherche
  
  const MealInputState({
    this.status = SearchStatus.initial,
    required this.selectedMealType,
    required this.selectedDate,
    this.addedFoodsForDay = const [],
    this.frequentSuggestions = const [],
    this.searchSuggestions = const [],
  });
  
  MealInputState copyWith({
    SearchStatus? status,
    String? selectedMealType,
    List<Meal>? addedFoodsForDay,
    List<Meal>? frequentSuggestions,
    List<dynamic>? searchSuggestions,
  }) {
    return MealInputState(
      status: status ?? this.status,
      selectedMealType: selectedMealType ?? this.selectedMealType,
      selectedDate: selectedDate, // Ne change pas
      addedFoodsForDay: addedFoodsForDay ?? this.addedFoodsForDay,
      frequentSuggestions: frequentSuggestions ?? this.frequentSuggestions,
      searchSuggestions: searchSuggestions ?? this.searchSuggestions,
    );
  }
  
  @override
  List<Object?> get props => [status, selectedMealType, addedFoodsForDay, frequentSuggestions, searchSuggestions];
}