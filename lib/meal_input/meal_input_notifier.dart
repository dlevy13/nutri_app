import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../meal_input/meal_input_state.dart';
import '../models/meal.dart';
import '../repositories/meal_repository.dart'; 
import '../services/date_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../meal_input/meal_input_state.dart';
import '../repositories/food_api_repository.dart';
import '../repositories/user_repository.dart';

class MealInputNotifier extends StateNotifier<MealInputState> {
  final Ref _ref;
  late final MealRepository _mealRepository = _ref.read(mealRepositoryProvider);
  Timer? _debounce;
  late final FoodAPIRepository _foodApiRepository = _ref.read(foodApiRepositoryProvider);

  MealInputNotifier(this._ref, String mealType, String selectedDateStr)
      : super(MealInputState(
          selectedMealType: mealType,
          selectedDate: DateTime.parse(selectedDateStr), 
        )) {
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    await _loadAddedFoods();
    await _loadFrequentSuggestions();
  }

  Future<void> _loadAddedFoods() async {
    final dateKey = DateService.formatStandard(state.selectedDate);
    final meals = await _mealRepository.getMealsForTypeAndDate(
        state.selectedMealType, dateKey);
    state = state.copyWith(addedFoodsForDay: meals);
  }

  Future<void> _loadFrequentSuggestions() async {
    final suggestions =
        await _mealRepository.getMostFrequentMealsByType(state.selectedMealType);
    state = state.copyWith(frequentSuggestions: suggestions);
  }

  void changeMealType(String newType) {
    state = state.copyWith(selectedMealType: newType, searchSuggestions: []);
    loadInitialData();
  }
Future<void> updateFoodQuantity(Meal meal, double newQty) async {
  // 1) Recalcule les macros par règle de 3 (ou utilise tes champs *_per100g si tu les as)
  final baseQty = (meal.quantity ?? 100).toDouble();
  final safeBase = baseQty <= 0 ? 100.0 : baseQty;

  final c100 = (meal.calories ?? 0).toDouble() * 100 / safeBase;
  final p100 = (meal.protein  ?? 0).toDouble() * 100 / safeBase;
  final g100 = (meal.carbs    ?? 0).toDouble() * 100 / safeBase;
  final f100 = (meal.fat      ?? 0).toDouble() * 100 / safeBase;

  final newMeal = Meal(
  name: meal.name,
  calories: c100 * newQty / 100,
  protein:  p100 * newQty / 100,
  carbs:    g100 * newQty / 100,
  fat:      f100 * newQty / 100,
  quantity: newQty,
  type: meal.type,
  date: meal.date,
  firestoreId: meal.firestoreId, // 👈 garde l’id si présent
      // etc. copie tes autres champs si tu en as
);

  // 2) Persistance : update si on a l'id Firestore, sinon fallback delete+add
  try {
    if (newMeal.firestoreId != null && newMeal.firestoreId!.isNotEmpty) {
      await _mealRepository.updateMeal(newMeal);
    } else {
      await _mealRepository.deleteMeal(meal);
      await _mealRepository.addMeal(newMeal);
    }
  } catch (e) {
    // Option: notifier l'UI d'une erreur
    // state = state.copyWith(errorMessage: "MAJ quantité impossible: $e");
  }

  // 3) Recharge (ou mets à jour localement la liste si tu préfères)
  await _loadAddedFoods();
}

  Future<void> addFood(dynamic foodData, double quantity) async {
    final dateKey = DateService.formatStandard(state.selectedDate);
    
    final Meal meal;
    if (foodData is Meal) {
        meal = foodData;
    } else if (foodData is Map<String, dynamic>) {
        meal = Meal.fromMap(foodData);
    } else {
        return; // Type non supporté
    }

    final newMeal = Meal(
      name: meal.name,
      calories: (meal.calories * quantity / 100),
      protein: (meal.protein * quantity / 100),
      carbs: (meal.carbs * quantity / 100),
      fat: (meal.fat * quantity / 100),
      quantity: quantity,
      type: state.selectedMealType,
      date: dateKey,
    );

    await _mealRepository.addMeal(newMeal);
    await _loadAddedFoods();
    state = state.copyWith(searchSuggestions: []);
  }
  
  Future<void> createAndAddFood({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double quantity,
  }) async {
      final dateKey = DateService.formatStandard(state.selectedDate);
      final newMeal = Meal(
          name: name,
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          quantity: quantity,
          type: state.selectedMealType,
          date: dateKey
      );
      // On l'ajoute comme un repas consommé
      await addFood(newMeal, quantity);
      // ✅ Étape 1 : Sauvegarder comme un aliment personnalisé réutilisable
      await _ref.read(userRepositoryProvider).saveCustomFood(newMeal);
  }

  Future<void> removeFood(Meal meal) async {
    await _mealRepository.deleteMeal(meal);
    await _loadAddedFoods();
  }

// dans la classe MealInputNotifier

void searchFood(String query) {
  if (_debounce?.isActive ?? false) _debounce!.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () async {
    if (query.length < 3) {
      if (mounted) state = state.copyWith(searchSuggestions: [], status: SearchStatus.initial);
      return;
    }
    if (mounted) state = state.copyWith(status: SearchStatus.loading);
    
    try {
      // On récupère les aliments personnalisés en parallèle de la recherche locale
      final results = await Future.wait([
        rootBundle.loadString('assets/food_data.json'),
        _ref.read(userRepositoryProvider).getCustomFoods(),
      ]);

      // ✅ CORRECTION N°1 : On convertit l'Object en String
      final List<dynamic> localJsonList = jsonDecode(results[0] as String);
      // ✅ CORRECTION N°2 : On convertit l'Object en List<Meal>
      final List<Meal> customFoods = results[1] as List<Meal>;

      // Le reste de la méthode ne change pas...
      final localResults = localJsonList
          .where((food) => (food['name'] as String).toLowerCase().contains(query.toLowerCase()))
          .toList();
          
      final customResults = customFoods
          .where((food) => food.name.toLowerCase().contains(query.toLowerCase()))
          .map((meal) => meal.toMap())
          .toList();
      
      final combinedResults = [...customResults, ...localResults];

      if (mounted) {
          state = state.copyWith(
            searchSuggestions: _mapToApiFormat(combinedResults),
            status: SearchStatus.success
          );
        }
    } catch (e) {
      if (mounted) state = state.copyWith(status: SearchStatus.failure);
    }
  });
}
List<dynamic> _mapToApiFormat(List<dynamic> results) {
  return results.map((food) {
    return {
      'product_name': food['name'] as String? ?? 'Nom inconnu',
      'nutriments': {
        'energy-kcal_100g': food['calories'],
        'proteins_100g': food['protein'],
        'carbohydrates_100g': food['carbs'],
        'fat_100g': food['fat'],
      }
    };
  }).toList();
}
  
  void clearSearch() {
      state = state.copyWith(searchSuggestions: [], status: SearchStatus.initial);
  }
  /// Lance une recherche sur l'API externe.
  Future<void> searchFoodFromAPI(String query) async {
    state = state.copyWith(status: SearchStatus.loading); 
    try {
      final results = await _foodApiRepository.search(query);
      state = state.copyWith(searchSuggestions: results, status: SearchStatus.success);
    } catch (e) {
      state = state.copyWith(status: SearchStatus.failure);
    }
  }

}

// Le provider.family reste le même
final mealInputProvider = StateNotifierProvider.autoDispose.family<MealInputNotifier, MealInputState, (String, String)>(
  (ref, params) => MealInputNotifier(ref, params.$1, params.$2),
);