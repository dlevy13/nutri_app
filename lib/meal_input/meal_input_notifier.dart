import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../meal_input/meal_input_state.dart';
import '../models/meal.dart';
import '../repositories/meal_repository.dart'; 
import '../services/date_service.dart';
import '../services/fonctions.dart';
import '../services/search_api_service.dart';
import '../services/nutrition_snapshot_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../repositories/food_api_repository.dart';
import '../repositories/user_repository.dart';
import '../providers/common_providers.dart';


// ------------------------------
// Cache nutriments /100g
// ------------------------------
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
  late final NutritionSnapshotService _nutritionSnapshotService =
      _ref.read(nutritionSnapshotServiceProvider);

  String _mealKey(Meal m) => '${m.name}|${m.date}|${m.type}';


  MealInputNotifier(this._ref, String mealType, String selectedDateStr, DateTime? fullTimestamp)
      : super(MealInputState(
          selectedMealType: mealType,
          selectedDate: DateTime.parse(selectedDateStr),
          fullTimestamp: fullTimestamp,
        )) {
    loadLocalData();
    _loadAllRecentMeals();
  }

  // ------------------------------------------------
  // Chargements initiaux
  // ------------------------------------------------
  Future<void> loadLocalData() async {
    await Future.wait([
      _loadAddedFoods(),
      _loadRecentSuggestions(),
      _loadYesterdayMeal(),
    ]);
  }
Future<void> _loadAllRecentMeals() async {
    // ⬇️ À CRÉER DANS VOTRE MEALREPOSITORY ⬇️
    // Par exemple : .orderBy('timestamp', descending: true).limit(200).get()
    final allMeals = await _mealRepository.getAllRecentMeals(); 
    if (mounted) {
      state = state.copyWith(allRecentMeals: allMeals);
    }
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
    state = state.copyWith(
      selectedMealType: newType, 
      searchSuggestions: [], 
      historySearchSuggestions: [], // <-- AJOUTÉ
      yesterdayMealSuggestions: [],
    );
    loadLocalData();
  }

  // ------------------------------------------------
  // Mise à jour quantité (tous nutriments)
  // ------------------------------------------------
  Future<void> updateFoodQuantity(Meal meal, double newQty) async {
    final key = _mealKey(meal);
    _per100Cache.putIfAbsent(key, () => _derivePer100FromMeal(meal) ?? const _Per100(0, 0, 0, 0, 0, 0, 0, 0));

    final per = _per100Cache[key]!;
    final q = (newQty.isNaN || newQty.isInfinite || newQty < 0) ? 0.0 : newQty;

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
    await _nutritionSnapshotService.recomputeAndSyncForDate(meal.date);

    final list = [...state.addedFoodsForDay];
    final idx = list.indexWhere((m) => _mealKey(m) == key);
    if (idx != -1) {
      list[idx] = meal;
      state = state.copyWith(addedFoodsForDay: list);
    }
  }

  // ------------------------------------------------
  // Recherche : priorisation nom → groupe → reste
  // + filtre requête-groupe (ex: "fromage")
  // ------------------------------------------------096,/,



void searchFood(String query, {bool forceOnline = false}) {
  if (_debounce?.isActive ?? false) _debounce!.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () async {
    final qTrim = query.trim();

    // ✅ CORRECTION : On ne crée plus une seule racine (qRoot)
    // On crée une LISTE de racines à partir de la requête.
    final qRoots = qTrim.split(' ').map(_root).where((t) => t.isNotEmpty).toList();

    if (qTrim.length < 3) { // On garde la garde sur la longueur brute
      if (mounted) {
        state = state.copyWith(
          searchSuggestions: [],
          historySearchSuggestions: [], 
          status: SearchStatus.initial,
        );
      }
      return;
    }
    
    if (mounted) state = state.copyWith(status: SearchStatus.loading);

    try {
      // --- 1. Recherche dans l'historique (Firestore) ---
      List<Meal> uniqueHistoryResults = [];
      if (qRoots.isNotEmpty) {
        final historyMatches = state.allRecentMeals.where((meal) {
          // ✅ CORRECTION : On applique la logique multi-mots
          final mealTokens = meal.name.split(' ').map(_root).where((t) => t.isNotEmpty).toList();
          if (mealTokens.isEmpty) return false;
          
          // Pour CHAQUE mot de la requête (qToken)...
          return qRoots.every((qToken) => 
              // ...il faut qu'AU MOINS UN mot de l'aliment (mToken) commence par celui-ci.
              mealTokens.any((mToken) => mToken.startsWith(qToken))
          );
        }).toList();

        // Dédoublonnage (inchangé)
        final seenNames = <String>{};
        for (final meal in historyMatches) {
          final key = normalize(meal.name); 
          if (seenNames.add(key)) {
            uniqueHistoryResults.add(meal);
          }
        }
      }

      // --- 2. Recherche Locale (OFF) + API (FatSecret, etc.) ---
      // On passe qTrim, _searchLocal a aussi été corrigée
      final localResults = await _searchLocal(qTrim); 
      final bool needApi = forceOnline || localResults.length < 5;

      List<Map<String, dynamic>> apiResults = [];
      if (needApi) {
        apiResults = await _foodApiRepository.search(qTrim);
      }

      final combinedLocalApi = [...localResults, ...apiResults];
      final dedupLocalApi = _dedupApiLike(combinedLocalApi);

      // Filtre et tri (inchangé)
      final isGroupQuery = _isGroupQueryForData(qTrim, dedupLocalApi);
      final afterFilter = isGroupQuery
          ? dedupLocalApi.where((it) => _matchGroupStrict(it, qTrim) || _nameStartsWith(it, qTrim)).toList()
          : dedupLocalApi;

      afterFilter.sort((a, b) => _scoreEntry(b, qTrim).compareTo(_scoreEntry(a, qTrim)));
      
      // --- 3. Mise à jour de l'état avec les DEUX listes ---
      if (mounted) {
        state = state.copyWith(
          historySearchSuggestions: uniqueHistoryResults, 
          searchSuggestions: afterFilter,
          status: SearchStatus.success,
        );
      }

    } catch (e) {
      if (mounted) state = state.copyWith(status: SearchStatus.failure);
    }
  });
}

  // Scoring : début du nom > groupe exact/prefix > autres mots > contient nom > contient groupe
  int _scoreEntry(Map<String, dynamic> item, String qRaw) {
  final q = normalize(qRaw);
  if (q.isEmpty) return 0;

  final name = normalize((item['product_name'] as String?) ?? '');
  final grp  = (item['group'] as String?) ?? '';

  final tokens = name.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList(); // ◄── LIGNE CORRIGÉE
  final firstName = tokens.isNotEmpty ? tokens.first : '';

  // nom qui commence par la requête
  if (firstName.startsWith(q)) return 100;

  // groupe : 1er mot très prioritaire (avec racine)
  final qr = _root(qRaw);
  final firstGrp = _root(_groupFirstToken(grp));
  if (firstGrp == qr) return 95;
  if (firstGrp.startsWith(qr)) return 90;

  // autres mots du nom
  if (tokens.skip(1).any((t) => t == q || t.startsWith(q))) return 60;

  // autres mots du groupe (poids moyen)
  final grpToks = _groupTokens(grp).map(_root).toList();
  if (grpToks.skip(1).any((t) => t == qr || t.startsWith(qr))) return 55;

  // contient dans le nom (faible)
  if (name.contains(q)) return 20;

  // contient dans le groupe (faible)
  if (normalize(grp).contains(q)) return 15;

  return 0;
}



  bool _matchGroupStrict(Map<String, dynamic> item, String qRaw) {
  final qr = _root(qRaw);
  final grp = (item['group'] as String?) ?? '';
  if (grp.isEmpty) return false;

  final first = _root(_groupFirstToken(grp));
  if (first.isEmpty) return false;

  if (first == qr || first.startsWith(qr)) return true;

  // fallback : n'importe quel mot du groupe après le 1er
  final toks = _groupTokens(grp).map(_root);
  return toks.any((t) => t == qr || t.startsWith(qr));
}


  bool _nameStartsWith(Map<String, dynamic> item, String qRaw) {
    final q = normalize(qRaw);
    final name = normalize((item['product_name'] as String?) ?? '');
    final parts = name.split(' ');
    final first = parts.isNotEmpty ? parts.first : '';
    return first.startsWith(q);
  }

  Future<List<Map<String, dynamic>>> _searchLocal(String q) async {
  final results = await Future.wait([
    rootBundle.loadString('assets/food_data.json'),
    _ref.read(userRepositoryProvider).getCustomFoods(),
  ]);

  final List localJson = jsonDecode(results[0] as String);
  final List<Meal> customFoods = results[1] as List<Meal>;

  // final nq = normalize(q); // <-- Plus nécessaire pour la recherche de nom
  final qr = _root(q); // <-- On utilise la racine pour TOUTES les recherches (nom + groupe)
  // On crée la LISTE de racines pour la RECHERCHE DE NOM (ex: "salade fruits")
  final qRoots = q.split(' ').map(_root).where((t) => t.isNotEmpty).toList();
  // On crée la LISTE de racines pour la RECHERCHE DE GRPE (ex: "fruits")
  bool _groupMatches(dynamic g) {
    final grpRaw = (g as String?) ?? '';
    final firstRoot = _root(_groupFirstToken(grpRaw));
    if (firstRoot.isEmpty) return false;
    if (firstRoot == qr || firstRoot.startsWith(qr)) return true;
    final toks = _groupTokens(grpRaw).map(_root);
    return toks.any((t) => t == qr || t.startsWith(qr));
  }

  final localResults = localJson
      .where((f) {
        final name = (f['name'] as String?) ?? '';
        final tokens = name.split(' ').map(_root).where((t) => t.isNotEmpty).toList();
        final nameOk = qRoots.every((qt) => tokens.any((mt) => mt.startsWith(qt)));

        final grpVal = f['group'] ?? f['groupe'];
        final grpOk  = _groupMatches(grpVal);
        return nameOk || grpOk;
      })
      .map<Map<String, dynamic>>((f) => {
            'product_name': f['name'],
            'source': 'local',
            'group': (f['group'] ?? f['groupe'] ?? ''),
            'nutriments': {
              'energy-kcal_100g': f['calories'],
              'proteins_100g': f['protein'],
              'carbohydrates_100g': f['carbs'],
              'fat_100g': f['fat'],
              'fiber_100g': f['fibres'],
              'saturated-fat_100g': f['fat_sa'],
              'monounsaturated-fat_100g': f['fat_mi'],
              'polyunsaturated-fat_100g': f['fat_pi'],
              'sugars_100g': f['sucres'],
            }
          })
      .toList();

  final customResults = customFoods
      .where((m) {
        final name = m.name;
        final tokens = name.split(' ').map(_root).where((t) => t.isNotEmpty).toList();
        final nameOk = qRoots.every((qt) => tokens.any((mt) => mt.startsWith(qt)));
        
        final grpOk  = _groupMatches(m.group);
        return nameOk || grpOk;
      })
      .map<Map<String, dynamic>>((m) => {
            'product_name': m.name,
            'source': 'custom',
            'group': m.group ?? '',
            'nutriments': {
              'energy-kcal_100g': m.kcalPer100X,
              'proteins_100g': m.proteinPer100X,
              'carbohydrates_100g': m.carbsPer100X,
              'fat_100g': m.fatPer100X,
              'fiber_100g': m.fiberPer100X,
              'saturated-fat_100g': m.fatSaturatedPer100X,
              'monounsaturated-fat_100g': m.fatMonounsaturatedPer100X,
              'polyunsaturated-fat_100g': m.fatPolyunsaturatedPer100X,
            }
          })
      .toList();

  return [...customResults, ...localResults];
}


  String _norm(String s) => normalize(s); // réutilise ta normalisation (accents + œ→oe)

String _stableKey(Map<String, dynamic> m) {
  for (final k in ['id','ciqual_id','ciqual_code','fdcId','code','gtin','source_id']) {
    final v = m[k];
    if (v != null && v.toString().isNotEmpty) return 'id:$v';
  }
  final name = _norm(((m['product_name'] ?? m['name'] ?? m['libelle']) ?? '').toString());
  final brand = _norm(((m['brand'] ?? m['marque']) ?? '').toString());
  return 'name:$name|brand:$brand';
}

List<Map<String, dynamic>> _dedupApiLike(List<Map<String, dynamic>> items) {
  final seen = <String>{};
  final out = <Map<String, dynamic>>[];
  for (final m in items) {
    final key = _stableKey(m);
    if (key == 'name:|brand:') continue; // skip entrées vides
    if (seen.add(key)) out.add(m);
  }
  return out;
}


  void clearSearch() {
    state = state.copyWith(
      searchSuggestions: [], 
      historySearchSuggestions: [], // <-- AJOUTÉ
      status: SearchStatus.initial,
    );
  }
// --- Helpers groupe -------------------------------------------------

String _root(String s) {
  // normalise + racine très simple FR (pluriels courants)
  final n = normalize(s);
  if (n.endsWith('aux')) return n.substring(0, n.length - 3) + 'al'; // chevaux -> cheval
  if (n.endsWith('eux')) return n.substring(0, n.length - 3) + 'eu'; // feux -> feu
  if (n.endsWith('x'))   return n.substring(0, n.length - 1);       // gâteaux -> gâteau (approx)
  if (n.endsWith('s'))   return n.substring(0, n.length - 1);       // fromages -> fromage
  return n;
}

List<String> _groupTokens(String? g) => normalize(g ?? '').split(' ').where((t) => t.isNotEmpty).toList();

String _groupFirstToken(String? g) {
  final toks = _groupTokens(g);
  return toks.isNotEmpty ? toks.first : '';
}

bool _isGroupQueryForData(String qRaw, List<Map<String, dynamic>> items) {
  final qr = _root(qRaw);                           // "fromage"
  if (qr.length < 3 || qr.contains(' ')) return false;

  for (final it in items) {
    final grp = (it['group'] as String?) ?? '';
    final first = _root(_groupFirstToken(grp));     // "fromage" pour "fromages et assimilés"
    if (first == qr || first.startsWith(qr)) return true;
  }
  return false;
}



  Future<void> addFood(dynamic foodData, double quantity) async {
    if (foodData is Map<String, dynamic> && foodData.containsKey('nutriments')) {
      await _addFromApiLike(foodData, quantity);
    }
  }

  Future<void> addMultipleFoods(List<({Meal meal, double quantity})> items) async {
    for (final item in items) {
      final meal = item.meal;
      final qty = item.quantity;

      await addFromPer100(
        name: meal.name,
        kcalPer100: meal.kcalPer100X,
        proteinPer100: meal.proteinPer100X,
        carbsPer100: meal.carbsPer100X,
        fatPer100: meal.fatPer100X,
        fibersPer100: meal.fiberPer100X,
        sucresPer100: meal.sucresPer100X,
        saturatedFatPer100: meal.fatSaturatedPer100X,
        polyunsaturatedFatPer100: meal.fatPolyunsaturatedPer100X,
        monounsaturatedFatPer100: meal.fatMonounsaturatedPer100X,
        qty: qty,
        group: meal.group,
      );
    }
  }
// Création rapide d’un aliment "custom" à partir de valeurs /100g,
// puis ajout direct au repas en cours.
Future<void> createAndAddFood({
  required String name,
  required double calories,              // kcal /100g
  required double protein,               // g /100g
  required double carbs,                 // g /100g
  required double fat,                   // g /100g
  required double fibers,                // g /100g
  required double sucres,                // g /100g
  required double saturatedFat,          // g /100g
  required double polyunsaturatedFat,    // g /100g
  required double monounsaturatedFat,    // g /100g
  required double quantity,              // g à ajouter au repas
  String? group,                         // optionnel
}) async {
  // 1) Ajoute dans le repas du jour (et rafraîchit la liste)
  final newMeal = await addFromPer100(
    name: name,
    group: group,
    kcalPer100: calories,
    proteinPer100: protein,
    carbsPer100: carbs,
    fatPer100: fat,
    fibersPer100: fibers,
    sucresPer100: sucres,
    saturatedFatPer100: saturatedFat,
    polyunsaturatedFatPer100: polyunsaturatedFat,
    monounsaturatedFatPer100: monounsaturatedFat,
    qty: quantity,
  );

  // 2) Optionnel : persiste cet aliment dans les "custom foods" de l’utilisateur
  if (newMeal != null) {
      await _ref.read(userRepositoryProvider).saveCustomFood(
        _cloneMealForCustom(newMeal),
      );
  }
}
  Meal _cloneMealForCustom(Meal m) {
    return Meal(
      name: m.name,
      calories: m.calories,
      protein: m.protein,
      carbs: m.carbs,
      fat: m.fat,
      quantity: m.quantity,
      type: m.type,
      date: m.date,
      fiber: m.fiber,
      sucres: m.sucres,
      fatSaturated: m.fatSaturated,
      fatMonounsaturated: m.fatMonounsaturated,
      fatPolyunsaturated: m.fatPolyunsaturated,
      group: m.group,
      kcalPer100: m.kcalPer100,
      proteinPer100: m.proteinPer100,
      carbsPer100: m.carbsPer100,
      fatPer100: m.fatPer100,
      fiberPer100: m.fiberPer100,
      sucresPer100: m.sucresPer100,
      fatSaturatedPer100: m.fatSaturatedPer100,
      fatMonounsaturatedPer100: m.fatMonounsaturatedPer100,
      fatPolyunsaturatedPer100: m.fatPolyunsaturatedPer100,
      timestamp: m.timestamp,
    );
  }

  Future<void> _addFromApiLike(Map<String, dynamic> item, double qty) async {
    final name = (item['product_name'] as String?)?.trim() ?? 'Aliment';
    final nutr = (item['nutriments'] as Map<String, dynamic>?) ?? {};
    final group = (item['group'] as String?)?.trim() ?? '';
    final source = (item['source'] as String?) ?? 'api';

    double toD(dynamic v) => (v is num) ? v.toDouble() : (double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0);

    final kcal100 = toD(nutr['energy-kcal_100g']);
    final p100 = toD(nutr['proteins_100g']);
    final c100 = toD(nutr['carbohydrates_100g']);
    final f100 = toD(nutr['fat_100g']);
    final fbr100 = toD(nutr['fiber_100g']);
    final sat100 = toD(nutr['saturated-fat_100g']);
    double mono100 = toD(nutr['monounsaturated-fat_100g']);
    double poly100 = toD(nutr['polyunsaturated-fat_100g']); 
    final sucres100 = toD(nutr['sugars_100g']);

    // --- Inférence insaturés si absents mais fat & sat présents ---
    if ((mono100 <= 0 && poly100 <= 0) && (f100 > 0 && sat100 > 0)) {
      final unsat = (f100 - sat100 );
      final fixed = unsat.isFinite && unsat > 0 ? unsat : 0.0;
      mono100 = fixed;   // choix simple : tout en mono (peut être 60/40 si tu veux)
      poly100 = 0.0;
      // Debug :
      // print('🛠️ Notifier infer: fat=$f100 sat=$sat100 trans=$trans100 → mono=$mono100 poly=$poly100');
    }
    // Optionnel : persister dans "custom foods" si ça vient de l'API
    if (source == 'api' && (kcal100 > 0 || p100 > 0 || c100 > 0 || f100 > 0)) {
      await _mealRepository.upsertCustomFoodFromApi(
        name: name,
        kcalPer100: kcal100,
        proteinPer100: p100,
        carbsPer100: c100,
        fatPer100: f100,
        fibersPer100: fbr100,
        sucresPer100: sucres100,
        saturatedFatPer100: sat100,
        polyunsaturatedFatPer100: poly100,
        monounsaturatedFatPer100: mono100,
        externalId: (item['id'] ?? item['code'])?.toString(),
        imageUrl: (item['image_url'] as String?),
        source: 'api',
        // 👉 si ton repo accepte group, passe-le :
        // group: group,
      );
    }

    await addFromPer100(
      name: name,
      group: group,
      kcalPer100: kcal100,
      proteinPer100: p100,
      carbsPer100: c100,
      fatPer100: f100,
      fibersPer100: fbr100,
      saturatedFatPer100: sat100,
      polyunsaturatedFatPer100: poly100,
      monounsaturatedFatPer100: mono100,
      sucresPer100: sucres100,
      
      qty: qty,
    );
  }

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
  required double sucresPer100,
  required double qty,
  String? group,
}) async {
  final q = (qty <= 0) ? 100.0 : qty;
  final dateKey = DateService.formatStandard(state.selectedDate);
  double pp(double v) => (v * q / 100.0);

  // copies mutables
  double monoP = monounsaturatedFatPer100;
  double polyP = polyunsaturatedFatPer100;

  // horodatage
  final DateTime timestampToSave;
  if (state.fullTimestamp != null) {
    timestampToSave = state.fullTimestamp!;
  } else {
    final DateTime datePart = DateService.parseStandard(dateKey);
    final now = DateTime.now();
    timestampToSave = datePart.copyWith(hour: now.hour, minute: now.minute);
  }

  // 🔧 inférence : si mono/poly absents mais fat & sat présents
  if ((monoP <= 0 && polyP <= 0) && (fatPer100 > 0 && saturatedFatPer100 > 0)) {
    final unsat = fatPer100 - saturatedFatPer100; // (tu peux retrancher trans si tu le passes en param)
    final fixed = (unsat.isFinite && unsat > 0) ? unsat : 0.0;
    monoP = fixed;   // choix simple : tout en mono (ou 60/40 si tu préfères)
    polyP = 0.0;
    // print('🛠️ addFromPer100 infer: fat=$fatPer100 sat=$saturatedFatPer100 → mono=$monoP poly=$polyP');
  }

  final newMeal = Meal(
    name: name,
    group: group,
    type: state.selectedMealType,
    date: dateKey,
    timestamp: timestampToSave.toIso8601String(),
    quantity: q,

    // totaux
    calories: pp(kcalPer100),
    protein:  pp(proteinPer100),
    carbs:    pp(carbsPer100),
    fat:      pp(fatPer100),
    fiber:    pp(fibersPer100),
    sucres:   pp(sucresPer100),

    // graisses totales détaillées (⚠️ utilisent monoP/polyP)
    fatSaturated:       pp(saturatedFatPer100),
    fatMonounsaturated: pp(monoP),
    fatPolyunsaturated: pp(polyP),

    // valeurs /100 (⚠️ utilisent monoP/polyP)
    kcalPer100:               kcalPer100,
    proteinPer100:            proteinPer100,
    carbsPer100:              carbsPer100,
    fatPer100:                fatPer100,
    fiberPer100:              fibersPer100,
    sucresPer100:             sucresPer100,
    fatSaturatedPer100:       saturatedFatPer100,
    fatMonounsaturatedPer100: monoP,
    fatPolyunsaturatedPer100: polyP,
  );

  await _mealRepository.addMeal(newMeal);
  await _nutritionSnapshotService.recomputeAndSyncForDate(newMeal.date);
  await _loadAddedFoods();
  await _loadRecentSuggestions();
  state = state.copyWith(searchSuggestions: []);
  return newMeal;
}


  Future<void> removeFood(Meal meal) async {
    _per100Cache.remove(_mealKey(meal));
    await _mealRepository.deleteMeal(meal);
    await _nutritionSnapshotService.recomputeAndSyncForDate(meal.date);
    await _loadAddedFoods();
  }
// API FATSECRET //
  Future<void> searchFoodFatSecret(String query) async {
  final q = query.trim();
  if (q.length < 3) return;

  try {
    state = state.copyWith(status: SearchStatus.loading);

    // Appel FatSecret → retourne la MÊME forme OFF que ton UI consomme
    final fsItems = await searchFoodOnFatSecret_OFFCompatible(q);

    // Mets simplement le résultat FS dans tes suggestions
    state = state.copyWith(
      searchSuggestions: fsItems,
      status: SearchStatus.success,
    );
  } catch (e) {
    state = state.copyWith(
      status: SearchStatus.success,
    );
  }
}

}

// ------------------------------------------------
// Dérive /100g à partir d'un Meal (totaux ou champs /100g)
// ------------------------------------------------
_Per100? _derivePer100FromMeal(Meal m) {
  if ((m.kcalPer100 ?? 0) > 0) {
    return _Per100(
      m.kcalPer100!, m.proteinPer100!, m.carbsPer100!, m.fatPer100!,
      m.fiberPer100 ?? 0, m.fatSaturatedPer100 ?? 0,
      m.fatPolyunsaturatedPer100 ?? 0, m.fatMonounsaturatedPer100 ?? 0,
    );
  }
  if (m.quantity > 0) {
    double calc(double? total) => ((total ?? 0) * 100.0) / m.quantity;
    return _Per100(
      calc(m.calories), calc(m.protein), calc(m.carbs), calc(m.fat),
      calc(m.fiber), calc(m.fatSaturated),
      calc(m.fatPolyunsaturated), calc(m.fatMonounsaturated),
    );
    }
  return null;
}

// Provider
typedef MealInputParams = ({String mealType, String selectedDate, DateTime? fullTimestamp});

final mealInputProvider = StateNotifierProvider.autoDispose
    .family<MealInputNotifier, MealInputState, MealInputParams>(
  (ref, params) => MealInputNotifier(
    ref,
    params.mealType,
    params.selectedDate,
    params.fullTimestamp, // On passe le 3ème paramètre
  ),
);

