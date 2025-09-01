import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../meal_input/meal_input_state.dart';
import '../models/meal.dart';
import '../repositories/meal_repository.dart'; 
import '../services/date_service.dart';
import '../services/fonctions.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../repositories/food_api_repository.dart';
import '../repositories/user_repository.dart';


// ✅ CORRECTION : Le cache interne doit gérer TOUS les nutriments
class _Per100 {
  final double kcal, prot, carbs, fat, fiber, satFat, polyFat, monoFat;
  const _Per100(this.kcal, this.prot, this.carbs, this.fat, this.fiber, this.satFat, this.polyFat, this.monoFat);
}

class MealInputNotifier extends StateNotifier<MealInputState> {
  final Ref _ref;
  late final MealRepository _mealRepository = _ref.read(mealRepositoryProvider);
  Timer? _debounce;
  late final FoodAPIRepository _foodApiRepository = _ref.read(foodApiRepositoryProvider);
  final Map<String, _Per100> _per100Cache = {};

  String _mealKey(Meal m) =>
    (m.firestoreId != null && m.firestoreId!.isNotEmpty)
      ? m.firestoreId!
      : '${m.name}|${m.date}|${m.type}';
      
  MealInputNotifier(this._ref, String mealType, String selectedDateStr)
      : super(MealInputState(
          selectedMealType: mealType,
          selectedDate: DateTime.parse(selectedDateStr),
        )) {
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    // On lance les chargements en parallèle pour plus d'efficacité
    await Future.wait([
      _loadAddedFoods(),
      _loadRecentSuggestions(),
      _loadYesterdayMeal(), // L'appel pour le bouton "copier"
    ]);
  }

  void _warmPer100Cache(List<Meal> meals) {
    for (final m in meals) {
      final k = _mealKey(m);
      if (_per100Cache.containsKey(k)) continue;
      final per = _derivePer100FromMeal(m);
      if (per != null) _per100Cache[k] = per;
    }
  }

  Future<void> _loadAddedFoods() async {
    final dateKey = DateService.formatStandard(state.selectedDate);
    final meals = await _mealRepository.getMealsForTypeAndDate(state.selectedMealType, dateKey);
    _warmPer100Cache(meals);
    state = state.copyWith(addedFoodsForDay: meals);
  }

  Future<void> _loadRecentSuggestions() async {
    final suggestions = await _mealRepository.getLastMealsByType(state.selectedMealType);
    state = state.copyWith(recentSuggestions: suggestions);
  }
Future<void> _loadYesterdayMeal() async {
    final yesterday = state.selectedDate.subtract(const Duration(days: 1));
    final dateKey = DateService.formatStandard(yesterday);
    final meals = await _mealRepository.getMealsForTypeAndDate(state.selectedMealType, dateKey);
    if (mounted) {
      state = state.copyWith(yesterdayMealSuggestions: meals);
    }
  }


  void changeMealType(String newType) {
    state = state.copyWith(selectedMealType: newType, searchSuggestions: [], yesterdayMealSuggestions: []);
    loadInitialData();
  }
  
  // ✅ CORRECTION : La mise à jour de quantité gère maintenant TOUS les nutriments
  Future<void> updateFoodQuantity(Meal meal, double newQty) async {
    final key = _mealKey(meal);
    _per100Cache.putIfAbsent(key, () => _derivePer100FromMeal(meal) ?? const _Per100(0,0,0,0,0,0,0,0));

    final per = _per100Cache[key]!;
    final q = (newQty.isNaN || newQty.isInfinite || newQty < 0) ? 0.0 : newQty;
    
    // On met à jour les champs totaux en utilisant les noms de champs de votre modèle
    meal
      ..quantity = q
      ..calories = per.kcal * q / 100.0
      ..protein = per.prot * q / 100.0
      ..carbs = per.carbs * q / 100.0
      ..fat = per.fat * q / 100.0
      ..fiber = per.fiber * q / 100.0
      ..fatSaturated = per.satFat * q / 100.0
      ..fatPolyunsaturated = per.polyFat * q / 100.0
      ..fatMonounsaturated = per.monoFat * q / 100.0;

    await _mealRepository.updateMeal(meal);
    
    final list = [...state.addedFoodsForDay];
    final idx = list.indexWhere((m) => _mealKey(m) == key);
    if (idx != -1) {
      list[idx] = meal;
      state = state.copyWith(addedFoodsForDay: list);
    }
  }
  
  Future<void> createAndAddFood({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double fibers,
    required double saturatedFat,
    required double polyunsaturatedFat,
    required double monounsaturatedFat,
    required double quantity,
  }) async {
    final newMeal = await addFromPer100(
      name: name,
      kcalPer100: calories,
      proteinPer100: protein,
      carbsPer100: carbs,
      fatPer100: fat,
      fibersPer100: fibers,
      saturatedFatPer100: saturatedFat,
      polyunsaturatedFatPer100: polyunsaturatedFat,
      monounsaturatedFatPer100: monounsaturatedFat,
      qty: quantity,
    );

    if (newMeal != null) {
      await _ref.read(userRepositoryProvider).saveCustomFood(newMeal);
    }
  }

  Future<void> removeFood(Meal meal) async {
    _per100Cache.remove(_mealKey(meal));
    await _mealRepository.deleteMeal(meal);
    await _loadAddedFoods();
  }
  
  // ✅ CORRECTION : La recherche est SIMPLIFIÉE et utilise le Repository
  void searchFood(String query, {bool forceOnline = false}) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final q = query.trim();
      if (q.length < 3) {
        if (mounted) state = state.copyWith(searchSuggestions: [], status: SearchStatus.initial);
        return;
      }
      if (mounted) state = state.copyWith(status: SearchStatus.loading);

      try {
        final localResults = await _searchLocal(q);
        final bool needApi = forceOnline || localResults.length < 5;

        List<Map<String, dynamic>> apiResults = [];
        if (needApi) {
          // Utilise le repository qui fait déjà le parsing !
          apiResults = await _foodApiRepository.search(q);
        }

        final combined = [...localResults, ...apiResults];
        final dedup = _dedupApiLike(combined);

        if (mounted) {
          state = state.copyWith(searchSuggestions: dedup, status: SearchStatus.success);
        }
      } catch (e) {
        if (mounted) state = state.copyWith(status: SearchStatus.failure);
      }
    });
  }

  Future<List<Map<String, dynamic>>> _searchLocal(String q) async {
    final results = await Future.wait([
      rootBundle.loadString('assets/food_data.json'),
      _ref.read(userRepositoryProvider).getCustomFoods(),
    ]);

    final List localJson = jsonDecode(results[0] as String);
    final List<Meal> customFoods = results[1] as List<Meal>;
    
    // Transforme les aliments locaux (assets)
    final localResults = localJson
        .where((f) => normalize(f['name'] ?? '').contains(normalize(q)))
        .map<Map<String, dynamic>>((f) => {
              'product_name': f['name'], 'source': 'local',
              'nutriments': {
                'energy-kcal_100g': f['calories'], 'proteins_100g': f['protein'],
                'carbohydrates_100g': f['carbs'], 'fat_100g': f['fat'],
                'fiber_100g': f['fibres'], 
                'saturated-fat_100g': f['fat_sa'], // Assurez-vous que ces clés correspondent à votre JSON
                'monounsaturated-fat_100g': f['fat_mi'],
                'polyunsaturated-fat_100g': f['fat_pi'],
              }
            }).toList();

    // Transforme les aliments personnalisés
    final customResults = customFoods
        .where((m) => normalize(m.name).contains(normalize(q)))
        .map<Map<String, dynamic>>((m) => {
              'product_name': m.name, 'source': 'custom',
              'nutriments': {
                'energy-kcal_100g': m.kcalPer100X, 'proteins_100g': m.proteinPer100X,
                'carbohydrates_100g': m.carbsPer100X, 'fat_100g': m.fatPer100X,
                'fiber_100g': m.fiberPer100X, 'saturated-fat_100g': m.fatSaturatedPer100X,
                'monounsaturated-fat_100g': m.fatMonounsaturatedPer100X,
                'polyunsaturated-fat_100g': m.fatPolyunsaturatedPer100X,
              }
            }).toList();
            
    return [...customResults, ...localResults];
  }

  List<Map<String, dynamic>> _dedupApiLike(List<Map<String, dynamic>> items, {int limit = 50}) {
    final seenNames = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final m in items) {
      final name = (m['product_name'] as String?) ?? '';
      if (seenNames.add(normalize(name))) {
        out.add(m);
      }
      if (out.length >= limit) break;
    }
    return out;
  }
  
  void clearSearch() {
    state = state.copyWith(searchSuggestions: [], status: SearchStatus.initial);
  }

  Future<void> addFood(dynamic foodData, double quantity) async {
    if (foodData is Map<String, dynamic> && foodData.containsKey('nutriments')) {
      await _addFromApiLike(foodData, quantity);
    }
  }

  /// NOUVELLE MÉTHODE pour ajouter une liste d'aliments
Future<void> addMultipleFoods(List<({Meal meal, double quantity})> items) async {
    for (final item in items) {
      final meal = item.meal;
      final qty = item.quantity;

      // On réutilise la logique existante pour ajouter un aliment
      await addFromPer100(
        name: meal.name,
        kcalPer100: meal.kcalPer100X,
        proteinPer100: meal.proteinPer100X,
        carbsPer100: meal.carbsPer100X,
        fatPer100: meal.fatPer100X,
        fibersPer100: meal.fibersPer100X,
        saturatedFatPer100: meal.saturatedFatPer100X,
        polyunsaturatedFatPer100: meal.polyunsaturatedFatPer100X,
        monounsaturatedFatPer100: meal.monounsaturatedFatPer100X,
        qty: qty,
      );
    }
    // Les rechargements sont déjà gérés par addFromPer100
  }
  // ✅ L'ajout depuis la recherche est simplifié et gère TOUS les nutriments
  // dans la classe MealInputNotifier de meal_input_notifier.dart

Future<void> _addFromApiLike(Map<String, dynamic> item, double qty) async {
  final name = (item['product_name'] as String?)?.trim() ?? 'Aliment';
  final nutr = (item['nutriments'] as Map<String, dynamic>?) ?? {};

  double toD(dynamic v) => (v is num) ? v.toDouble() : (double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0);
  
  final kcal100 = toD(nutr['energy-kcal_100g']);
  final p100 = toD(nutr['proteins_100g']);
  final c100 = toD(nutr['carbohydrates_100g']);
  final f100 = toD(nutr['fat_100g']);
  final fbr100 = toD(nutr['fiber_100g']);
  final sat100 = toD(nutr['saturated-fat_100g']);
  final poly100 = toD(nutr['polyunsaturated-fat_100g']);
  final mono100 = toD(nutr['monounsaturated-fat_100g']);
  
  // On ne sauvegarde que si les données nutritionnelles de base sont valides
  if (kcal100 > 0 || p100 > 0 || c100 > 0 || f100 > 0) {
    // ✅ CORRECTION : On réintègre l'appel pour sauvegarder l'aliment
    await _mealRepository.upsertCustomFoodFromApi(
      name: name,
      kcalPer100: kcal100,
      proteinPer100: p100,
      carbsPer100: c100,
      fatPer100: f100,
      fibersPer100: fbr100,
      saturatedFatPer100: sat100,
      polyunsaturatedFatPer100: poly100,
      monounsaturatedFatPer100: mono100,
      externalId: (item['id'] ?? item['code'])?.toString(),
      imageUrl: (item['image_url'] as String?),
      source: 'api',
    );
  }
  
  // On continue ensuite pour ajouter l'aliment au repas du jour
  await addFromPer100(
    name: name,
    kcalPer100: kcal100,
    proteinPer100: p100,
    carbsPer100: c100,
    fatPer100: f100,
    fibersPer100: fbr100,
    saturatedFatPer100: sat100,
    polyunsaturatedFatPer100: poly100,
    monounsaturatedFatPer100: mono100,
    qty: qty,
  );
}

  // ✅ Cette fonction devient la méthode centrale pour créer un Meal et retourne le Meal créé
  Future<Meal?> addFromPer100({
    required String name,
    required double kcalPer100,
    required double proteinPer100,
    required double carbsPer100,
    required double fatPer100,
    required double fibersPer100,
    required double saturatedFatPer100,
    required double polyunsaturatedFatPer100,
    required double monounsaturatedFatPer100,
    required double qty,
  }) async {
    final q = (qty <= 0) ? 100.0 : qty;
    final dateKey = DateService.formatStandard(state.selectedDate);
    double pp(double v) => (v * q / 100.0);

    final newMeal = Meal(
      name: name,
      type: state.selectedMealType,
      date: dateKey,
      quantity: q,
      calories: pp(kcalPer100),
      protein:  pp(proteinPer100),
      carbs:    pp(carbsPer100),
      fat:      pp(fatPer100),
      fiber:    pp(fibersPer100),
      fatSaturated: pp(saturatedFatPer100),
      fatPolyunsaturated: pp(polyunsaturatedFatPer100),
      fatMonounsaturated: pp(monounsaturatedFatPer100),
      kcalPer100: kcalPer100,
      proteinPer100: proteinPer100,
      carbsPer100: carbsPer100,
      fatPer100: fatPer100,
      fiberPer100: fibersPer100,
      fatSaturatedPer100: saturatedFatPer100,
      fatPolyunsaturatedPer100: polyunsaturatedFatPer100,
      fatMonounsaturatedPer100: monounsaturatedFatPer100,
    );

    await _mealRepository.addMeal(newMeal);
    await _loadAddedFoods();
    await _loadRecentSuggestions();
    state = state.copyWith(searchSuggestions: []);
    return newMeal;
  }
}

// ✅ Le cache et sa déduction sont mis à jour pour tous les champs
_Per100? _derivePer100FromMeal(Meal m) {
  // Priorité aux valeurs /100g explicites
  if ((m.kcalPer100 ?? 0) > 0) {
    return _Per100(
      m.kcalPer100!, m.proteinPer100!, m.carbsPer100!, m.fatPer100!,
      m.fiberPer100 ?? 0, m.fatSaturatedPer100 ?? 0, 
      m.fatPolyunsaturatedPer100 ?? 0, m.fatMonounsaturatedPer100 ?? 0
    );
  }
  // Sinon, calcul à partir des totaux si la quantité est valide
  if (m.quantity > 0) {
    double calc(double? total) => ((total ?? 0) * 100.0) / m.quantity;
    return _Per100(
      calc(m.calories), calc(m.protein), calc(m.carbs), calc(m.fat),
      calc(m.fiber), calc(m.fatSaturated),
      calc(m.fatPolyunsaturated), calc(m.fatMonounsaturated)
    );
  }
  return null;
}

final mealInputProvider = StateNotifierProvider.autoDispose.family<MealInputNotifier, MealInputState, (String, String)>(
  (ref, params) => MealInputNotifier(ref, params.$1, params.$2),
);