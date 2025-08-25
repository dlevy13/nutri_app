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
    await _loadRecentSuggestions();
  }

  Future<void> _loadAddedFoods() async {
    final dateKey = DateService.formatStandard(state.selectedDate);
    final meals = await _mealRepository.getMealsForTypeAndDate(
        state.selectedMealType, dateKey);
    state = state.copyWith(addedFoodsForDay: meals);
  }

  Future<void> _loadRecentSuggestions() async {
    
    final suggestions = await _mealRepository.getLastMealsByType(state.selectedMealType);
    state = state.copyWith(recentSuggestions: suggestions);
  }
// amélioration de la recherche
// Stopwords FR minimaux (tu peux en ajouter)
  static const Set<String> _frStop = {
    'a','à','au','aux','de','des','du','d','la','le','les','l',
    'un','une','et','en','sur','pour','par','avec','sans','ou','dans','chez'
  };
// Score source: plus petit = mieux
int _srcScore(String? s) {
  switch (s) {
    case 'custom': return 0;
    case 'api':    return 1;
    case 'local':  return 2;
    default:       return 3;
  }
}

List<String> _tokens(String s) => normalize(s)
    .split(' ')
    .where((t) => t.isNotEmpty && !_frStop.contains(t) && t.length >= 2)
    .toList();

List<int> _scoreFor(Map<String, dynamic> item, String query) {
  final name = (item['product_name'] as String?) ?? '';
  final src  = (item['source'] as String?) ?? 'api';

  final n  = normalize(name);
  final nq = normalize(query);

  // 1) Exact match
  final exact = (n == nq) ? 0 : 1;

  // 2) StartsWith
  final starts = n.startsWith(nq) ? 0 : 1;

  // 3) Couverture de tokens (moins manquants = mieux)
  final nt = _tokens(n);
  final qt = _tokens(nq);
  int missing = 0;
  for (final qtok in qt) {
    final ok = nt.any((w) => w == qtok || w.startsWith(qtok) || qtok.startsWith(w) || w.contains(qtok));
    if (!ok) missing++;
  }

  // 4) Position du 1er match (plus tôt = mieux)
  final idx = n.indexOf(nq);
  final pos = idx >= 0 ? idx : 1 << 20;

  // 5) Priorité de la source
  final srcSc = _srcScore(src);

  // 6) Légère préférence aux noms plus courts
  final len = n.length;

  // Ordre: exact → starts → missing → pos → src → len
  return [exact, starts, missing, pos, srcSc, len];
}

int _cmpList(List<int> a, List<int> b) {
  for (var i = 0; i < a.length; i++) {
    final d = a[i] - b[i];
    if (d != 0) return d;
  }
  return 0;
}

void _rerank(List<Map<String, dynamic>> items, String query) {
  items.sort((a, b) => _cmpList(_scoreFor(a, query), _scoreFor(b, query)));
}

  bool matchesQuery(String name, String query) {
    final nn = normalize(name);
    final nq = normalize(query);

    if (nq.isEmpty) return true;
    if (nn.contains(nq)) return true; // match direct simple

    // Tokenise + retire stopwords et tokens trop courts
    List<String> toks(String s) =>
        s.split(' ').where((t) => t.isNotEmpty && !_frStop.contains(t) && t.length >= 2).toList();

    final nameT = toks(nn);
    final queryT = toks(nq);

    if (queryT.isEmpty) return nn.contains(nq);

    // Every query token must appear in any order in name tokens (exact, prefix, or contained)
    for (final qt in queryT) {
      final ok = nameT.any((nt) => nt == qt || nt.startsWith(qt) || qt.startsWith(nt) || nt.contains(qt));
      if (!ok) return false;
    }
    return true;
  }
List<String> _qtokens(String s) => normalize(s)
    .split(RegExp(r'\s+'))
    .where((t) => t.isNotEmpty && !_frStop.contains(t) && t.length >= 2)
    .toList();

/// Tous les tokens de `query` sont-ils présents (exact/prefix/contains) dans `name` ?
bool _allTokensCovered(String name, String query) {
  final n = normalize(name);
  final nt = _tokens(n);      // tu as déjà _tokens()
  final qt = _qtokens(query); // tokens de la requête (stopwords retirés)
  if (qt.isEmpty) return n.contains(normalize(query));
  for (final qtkn in qt) {
    final ok = nt.any((w) =>
        w == qtkn || w.startsWith(qtkn) || qtkn.startsWith(w) || w.contains(qtkn));
    if (!ok) return false;
  }
  return true;
}

/// Score bonus pour la couverture de tokens (0 = aucun, plus petit = mieux dans ton tri)
int _tokenMissCount(String name, String query) {
  final n = normalize(name);
  final nt = _tokens(n);
  final qt = _qtokens(query);
  if (qt.isEmpty) return 0;
  int missing = 0;
  for (final qtkn in qt) {
    final ok = nt.any((w) =>
        w == qtkn || w.startsWith(qtkn) || qtkn.startsWith(w) || w.contains(qtkn));
    if (!ok) missing++;
  }
  return missing; // 0 = parfait, 1 = il manque 1 token, etc.
}

  void changeMealType(String newType) {
    state = state.copyWith(selectedMealType: newType, searchSuggestions: []);
    loadInitialData();
  }
Future<void> updateFoodQuantity(Meal meal, double newQty) async {
  // 1) Recalcule les macros par règle de 3 (ou utilise tes champs *_per100g si tu les as)
  final baseQty = (meal.quantity).toDouble();
  final safeBase = baseQty <= 0 ? 100.0 : baseQty;

  final c100 = meal.calories * 100 / safeBase;
  final p100 = meal.protein * 100 / safeBase;
  final g100 = meal.carbs * 100 / safeBase;
  final f100 = meal.fat * 100 / safeBase;

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
  // Si la sélection vient de la recherche (Map "API-like"), on passe par _addFromApiLike.
  if (foodData is Map<String, dynamic> && foodData.containsKey('nutriments')) {
    final src = (foodData['source'] as String?) ?? 'api';
    await _addFromApiLike(foodData, quantity, source: src);
    return;
  }

  // Legacy: Meal (absolu) ou Map sans 'nutriments' -> on garde ton comportement existant
  final dateKey = DateService.formatStandard(state.selectedDate);

  final Meal? meal = switch (foodData) {
    Meal m => m,
    Map<String, dynamic> m => Meal.fromMap(m),
    _ => null,
    };
  if (meal == null) return;

  final newMeal = Meal(
    name: meal.name,
    calories: (meal.calories * quantity / 100),
    protein:  (meal.protein  * quantity / 100),
    carbs:    (meal.carbs    * quantity / 100),
    fat:      (meal.fat      * quantity / 100),
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
      // 1) LOCAL : assets + custom (en parallèle)
      final results = await Future.wait([
        rootBundle.loadString('assets/food_data.json'),
        _ref.read(userRepositoryProvider).getCustomFoods(),
      ]);

      final List<dynamic> localJson = jsonDecode(results[0] as String) as List<dynamic>;
      final List<Meal> customFoods = results[1] as List<Meal>;
      final qLower = q.toLowerCase();

      // Local (assets) → API-like
      final localResults = localJson
          .where((f) => matchesQuery((f['name'] as String?) ?? '', q))
          .map<Map<String, dynamic>>((f) => {
                'product_name': f['name'] ?? 'Nom inconnu',
                'nutriments': {
                  'energy-kcal_100g': f['calories'],
                  'proteins_100g': f['protein'],
                  'carbohydrates_100g': f['carbs'],
                  'fat_100g': f['fat'],
                },
                'source': 'local',
              })
          .toList();

      // Custom (Firestore) → API-like
      final customResults = customFoods
          .where((m) => matchesQuery(m.name, q))
          .map<Map<String, dynamic>>((m) => {
                'product_name': m.name,
                'nutriments': {
                  'energy-kcal_100g': m.calories,
                  'proteins_100g': m.protein,
                  'carbohydrates_100g': m.carbs,
                  'fat_100g': m.fat,
                },
                'source': 'custom',
                'docId': m.firestoreId,
              })
          .toList();

      // Fusion locale (priorité custom > local) + dédoublonnage
      final combinedLocal = <Map<String, dynamic>>[
        ...customResults,
        ...localResults,
      ];
      final localDedup = _dedupApiLike(combinedLocal, limit: 50);

      // --- Évaluer la "force" du local ---
      bool hasExact = false, hasPrefix = false;
      int topLocalScore = 0;

      String _norm(String s) => normalize(s);
      int _scoreOf(String name, String nq) {
        final n = _norm(name);
        final qn = _norm(nq);
        if (n == qn) return 100;     // exact
        if (n.startsWith(qn)) return 95; // préfixe fort
        if (n.contains(qn)) return 80;   // contient
        return 50;
      }

      for (final m in localDedup) {
        final name = (m['product_name'] as String?) ?? '';
        final s = _scoreOf(name, q);
        if (s > topLocalScore) topLocalScore = s;
        final n = _norm(name);
        final nq = _norm(q);
        if (n == nq) hasExact = true;
        if (n.startsWith(nq)) hasPrefix = true;
      }

      // --- Couverture multi‑tokens : tous les mots de la requête sont-ils couverts par un item local ? ---
      final qTokens = _qtokens(q);
      final bool hasAllTokensCoveredLocally = localDedup.any((m) {
        final name = (m['product_name'] as String?) ?? '';
        return _allTokensCovered(name, q);
      });

      // --- Décision API ---
      final bool needApi = forceOnline
                        || localDedup.isEmpty
                        || (q.length >= 5 && !(hasExact || hasPrefix))
                        || (localDedup.length < 3)
                        || (topLocalScore < 90 && q.length >= 5)
                        || (qTokens.length >= 2 && !hasAllTokensCoveredLocally);

      // 2) API si besoin
      List<Map<String, dynamic>> apiResults = const [];
      if (needApi) {
        try {
          final List<Map<String, dynamic>> apiRaw = await _foodApiRepository.search(q);
          apiResults = apiRaw
              .map((r) {
                final nutr = (r['nutriments'] as Map?)?.cast<String, dynamic>()
                            ?? (r['nutriments_per_100g'] as Map?)?.cast<String, dynamic>()
                            ?? const <String, dynamic>{};
                return <String, dynamic>{
                  'product_name': (r['product_name'] ?? r['name'] ?? 'Aliment') as String,
                  'nutriments': {
                    'energy-kcal_100g':   nutr['energy-kcal_100g'] ?? nutr['kcal_100g'] ?? nutr['kcal'],
                    'proteins_100g':      nutr['proteins_100g'] ?? nutr['protein_100g'] ?? nutr['protein'],
                    'carbohydrates_100g': nutr['carbohydrates_100g'] ?? nutr['carbs_100g'] ?? nutr['carbs'],
                    'fat_100g':           nutr['fat_100g'] ?? nutr['fat'],
                  },
                  'id': r['id'] ?? r['code'],
                  'image_url': r['image_url'] ?? r['image_front_url'],
                  'source': 'api',
                };
              })
              .where((m) => ((m['product_name'] as String?) ?? '')
                  .toLowerCase()
                  .contains(qLower))
              .toList();
        } catch (_) {
          // on tolère l’échec API, on garde le local
        }
      }

      // 3) Fusion finale (priorité custom > api > local) + dédoublonnage + re‑ranking
      final combined = <Map<String, dynamic>>[
        ...customResults,
        ...apiResults,
        ...localResults,
      ];
      final dedup = _dedupApiLike(combined, limit: 50);

      // Booster le tri avec la couverture de tokens (prend effet via _scoreFor modifié plus bas)
      _rerank(dedup, q);

      if (mounted) {
        state = state.copyWith(searchSuggestions: dedup, status: SearchStatus.success);
      }
    } catch (e) {
      if (mounted) state = state.copyWith(status: SearchStatus.failure);
    }
  });
}




List<Map<String, dynamic>> _dedupApiLike(List<Map<String, dynamic>> items, {int limit = 50}) {
  final seenIds = <String>{};
  final seenNames = <String>{};
  final out = <Map<String, dynamic>>[];

  for (final m in items) {
    final id = (m['id'] ?? m['docId'])?.toString();
    final name = (m['product_name'] as String?) ?? '';
    final nameKey = normalize(name);

    // Unicité d’abord par id si présent (utile pour API), sinon par nom normalisé
    if (id != null && id.isNotEmpty) {
      if (seenIds.add(id)) {
        out.add(m);
      }
    } else {
      if (seenNames.add(nameKey)) {
        out.add(m);
      }
    }

    if (out.length >= limit) break;
  }
  return out;
}


  
  void clearSearch() {
      state = state.copyWith(searchSuggestions: [], status: SearchStatus.initial);
  }
  /// Lance une recherche sur l'API externe.
  Future<void> searchFoodFromAPI(String query) async {
  state = state.copyWith(status: SearchStatus.loading); 
  try {
    final raw = await _foodApiRepository.search(query);
    // Normalise en forme "API-like"
    final results = raw.map<Map<String, dynamic>>((r) {
      final nutr = r['nutriments'] ?? r['nutriments_per_100g'] ?? {};
      return {
        'product_name': r['product_name'] ?? r['name'] ?? 'Aliment',
        'nutriments': {
          'energy-kcal_100g': nutr['energy-kcal_100g'] ?? nutr['kcal_100g'] ?? nutr['kcal'],
          'proteins_100g':    nutr['proteins_100g']    ?? nutr['protein_100g'] ?? nutr['protein'],
          'carbohydrates_100g': nutr['carbohydrates_100g'] ?? nutr['carbs_100g'] ?? nutr['carbs'],
          'fat_100g':           nutr['fat_100g']           ?? nutr['fat'],
        },
        'id': r['id'] ?? r['code'],
        'image_url': r['image_url'],
        'source': 'api',
      };
    }).toList();

    state = state.copyWith(searchSuggestions: results, status: SearchStatus.success);
  } catch (e) {
    state = state.copyWith(status: SearchStatus.failure);
  }
}


  /// À appeler depuis l’UI quand l’utilisateur clique une suggestion.
/// Supporte :
/// - item "API-like"  => contient 'product_name' + 'nutriments' (OpenFoodFacts-like)
/// - item custom/local => même forme "API-like" mais avec 'source' = 'custom' | 'local'
Future<void> selectSuggestion(Map<String, dynamic> item, double qty) async {
  final source = (item['source'] as String?) ?? 'api'; // défaut: api
  if (item.containsKey('nutriments')) {
    await _addFromApiLike(item, qty, source: source);
  } else {
    //fallback: si jamais tu passes un Meal.toMap() brut
    await addFood(item, qty);
  }
}
Future<void> _addFromApiLike(Map<String, dynamic> item, double qty, {required String source}) async {
  final q = (qty <= 0) ? 100.0 : qty;

  // nom: accepte product_name OU name
  final name = (item['product_name'] as String?)?.trim()
      ?? (item['name'] as String?)?.trim()
      ?? 'Aliment';

  final nutr = (item['nutriments'] as Map?) ?? const {};

  double _toD(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
  }

  // helpers clés multiples
  double _pick(Map src, List<String> keys) {
    for (final k in keys) {
      if (src.containsKey(k) && src[k] != null) return _toD(src[k]);
    }
    return 0.0;
  }

  // kcal depuis nutriments (ou racine) ; si absent, tente kJ → kcal
  double kcal100 = _pick(nutr, ['energy-kcal_100g','kcal_100g','calories','kcal']);
  if (kcal100 == 0) {
    kcal100 = _pick(item, ['energy-kcal_100g','kcal_100g','calories','kcal']);
  }
  if (kcal100 == 0) {
    final kj = _pick(nutr, ['energy-kj_100g','kj_100g','energy_100g']);
    kcal100 = (kj > 0) ? (kj / 4.184) : 0.0;
  }
  if (kcal100 == 0) {
    final kj = _pick(item, ['energy-kj_100g','kj_100g','energy_100g']);
    kcal100 = (kj > 0) ? (kj / 4.184) : 0.0;
  }

  final p100 = _pick(nutr, ['proteins_100g','protein_100g','protein','proteins']);
  final c100 = _pick(nutr, ['carbohydrates_100g','carbs_100g','carbs','carbohydrates']);
  final f100 = _pick(nutr, ['fat_100g','fat']);

  // secours au niveau racine si tout est à 0
  final allZero = (kcal100 == 0 && p100 == 0 && c100 == 0 && f100 == 0);
  final pp100   = allZero ? _pick(item, ['proteins_100g','protein_100g','protein','proteins']) : p100;
  final cc100   = allZero ? _pick(item, ['carbohydrates_100g','carbs_100g','carbs','carbohydrates']) : c100;
  final ff100   = allZero ? _pick(item, ['fat_100g','fat']) : f100;
  final kk100   = kcal100; // déjà traité kJ -> kcal ci-dessus

  // si encore tout 0 → on sort proprement (pas d’insert 0/0/0/0)
  if (kk100 == 0 && pp100 == 0 && cc100 == 0 && ff100 == 0) {
    return;
  }

  // upsert fiche si ça vient de l’API (uniquement si valeurs valides)
  if (source == 'api') {
    await _mealRepository.upsertCustomFoodFromApi(
      name: name,
      kcalPer100: kk100,
      proteinPer100: pp100,
      carbsPer100: cc100,
      fatPer100: ff100,
      externalId: (item['id'] ?? item['code'] ?? item['_id'])?.toString(),
      source: 'api',
    );
  }

  final dateKey = DateService.formatStandard(state.selectedDate);
  final newMeal = Meal(
    name: name,
    calories: kk100 * q / 100.0,
    protein:  pp100 * q / 100.0,
    carbs:    cc100 * q / 100.0,
    fat:      ff100 * q / 100.0,
    quantity: q,
    type: state.selectedMealType,
    date: dateKey,
  );

  // Choisis UN seul flux : soit optimiste, soit reload.
  // 👉 je te conseille le reload (pas de flicker/doublon visuel)
  await _mealRepository.addMeal(newMeal);
  await _loadAddedFoods();
  await _loadRecentSuggestions();
  state = state.copyWith(searchSuggestions: []);
}



}

// Le provider.family reste le même
final mealInputProvider = StateNotifierProvider.autoDispose.family<MealInputNotifier, MealInputState, (String, String)>(
  (ref, params) => MealInputNotifier(ref, params.$1, params.$2),
);