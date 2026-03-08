import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:async';
import '../models/meal.dart';
import '../meal_input/meal_input_notifier.dart';
import '../meal_input/meal_input_state.dart';
import '../widget/food_search_field.dart';
import '../widget/create_food_button.dart';
import '../services/date_service.dart';
import '../models/aliment_usuel.dart'; 
import '../services/decomposition_service.dart';
import '../services/num_safety.dart';
import '../models/proposed_ingredient.dart';
import '../widget/decomposition_review_sheet.dart';
import '../widget/quantity_page.dart';
import '../widget/suggestion_meal_card.dart';
import '../widget/added_food_tile.dart';
import '../widget/totals_bar.dart';
import '../widget/copy_yesterday_meal_sheet.dart';

import '../services/food_matching_service.dart';


class MealInputPage extends ConsumerStatefulWidget {
  final String selectedDate;
  final String mealType;
  final DateTime? fullTimestamp;

  const MealInputPage({
    super.key,
    required this.selectedDate,
    this.mealType = "Petit-déjeuner",
    this.fullTimestamp,
  });

  @override
  ConsumerState<MealInputPage> createState() => _MealInputPageState();
}

class _MealInputPageState extends ConsumerState<MealInputPage> {
  final TextEditingController _searchController = TextEditingController();
  final _decompCtrl = TextEditingController();
  final _decompSvc  = DecompositionService();
  final _recentScrollCtrl = ScrollController();
  List<AlimentUsuel> alimentsUsuels = [];
  late FoodMatchingService _matchingService;
  Timer? _debounce;
  bool _isDecomposing = false;

@override
  void initState() {
    super.initState(); 
    _matchingService = FoodMatchingService(alimentsUsuels: alimentsUsuels);
    _loadAlimentsUsuels();
  }

  @override
  void dispose() {
  _debounce?.cancel();
  _searchController.dispose();
  _decompCtrl.dispose();
  _recentScrollCtrl.dispose();
  super.dispose();
}

/// Construit la liste des résultats de l'historique (Firestore)
List<Widget> _buildHistorySearchResults(
  List<Meal> suggestions,
  MealInputNotifier notifier,
) {
  final theme = Theme.of(context);

  // Le notifier est censé avoir déjà filtré et dédoublé cette liste
  if (suggestions.isEmpty) return [];

  return [
    // Titre de la section
    Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Text(
        "Dans mon historique",
        style: theme.textTheme.titleMedium, // Style cohérent
      ),
    ),
    // Utilise la même logique de liste que _buildrecentSuggestions
    ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: suggestions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final meal = suggestions[i];
        return SuggestionMealCard(
          meal: meal,
          kcalPer100: meal.kcalPer100X,
          proteinPer100: meal.proteinPer100X,
          carbsPer100: meal.carbsPer100X,
          fatPer100: meal.fatPer100X,
          // ✅ ON PASSE LES NOUVEAUX CHAMPS À LA FONCTION D'AJOUT
          onAdd: () => _showQuantityDialogFromPer100(
            name: meal.name,
            kcalPer100: meal.kcalPer100X,
            proteinPer100: meal.proteinPer100X,
            carbsPer100: meal.carbsPer100X,
            fatPer100: meal.fatPer100X,
            fibersPer100: meal.fibersPer100X,
            sucresPer100: meal.sucresPer100X,
            saturatedFatPer100: meal.saturatedFatPer100X,
            polyunsaturatedFatPer100: meal.polyunsaturatedFatPer100X,
            monounsaturatedFatPer100: meal.monounsaturatedFatPer100X,
            notifier: notifier,
            clearSearchAfter: true, // Nettoie la recherche après ajout
          ),
        );
      },
    ),
    // Séparateur avant la section suivante
    const Divider(height: 24),
  ];
}


  // decomposition des plats en aliments
Future<void> onDecompose() async {
  if (_isDecomposing) return;

  final description = _decompCtrl.text.trim();
  if (description.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Écris d’abord la description du plat.")),
      );
    }
    return;
  }

  setState(() {
    _isDecomposing = true;
  });

  try {
    final data = await _decompSvc.decompose(description);

    final items = (data["ingredients"] as List)
        .map((e) => ProposedIngredient.fromJson(e as Map<String, dynamic>))
        .toList();

    if (!mounted) return;

    final provider = mealInputProvider((
      mealType: widget.mealType,
      selectedDate: widget.selectedDate,
      fullTimestamp: widget.fullTimestamp,
    ));
    final notifier = ref.read(provider.notifier);
    final selectedMealType = ref.read(provider).selectedMealType;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DecompositionReviewSheet(
        items: items,
        mealType: selectedMealType,
        notifier: notifier,
      ),
    );

    if (saved == true) {
      ref.invalidate(mealInputProvider((
        mealType: widget.mealType,
        selectedDate: widget.selectedDate,
        fullTimestamp: widget.fullTimestamp,
      )));
      _decompCtrl.clear();
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur décomposition : $e")),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isDecomposing = false;
      });
    }
  }
}




// Ouvre le picker puis appelle le Notifier en passant les valeurs /100 g
// ✅ MISE À JOUR DE LA SIGNATURE ET DU CORPS DE LA FONCTION
Future<void> _showQuantityDialogFromPer100({
  required String name,
  required double kcalPer100,
  required double proteinPer100,
  required double carbsPer100,
  required double fatPer100,
  required double fibersPer100,
  required double sucresPer100,
  required double saturatedFatPer100,
  required double polyunsaturatedFatPer100,
  required double monounsaturatedFatPer100,
  required MealInputNotifier notifier,
  bool clearSearchAfter = false,
}) async {
  final AlimentUsuel? refAliment = _matchingService.getPoidsUsuel(name);
  final List<UsualUnit> usualUnits = [];
  if (refAliment != null && refAliment.poids > 0) {
    usualUnits.add(UsualUnit(
      label: refAliment.unite,
      gramsPerUnit: refAliment.poids.toDouble(),
    ));
  }

  final double defaultGrams =
      usualUnits.isNotEmpty ? usualUnits.first.gramsPerUnit : (refAliment?.poids.toDouble() ?? 100.0);

  if (!mounted) return;

  final resultInGrams = await Navigator.of(context).push<double>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => QuantityPage(
        title: "Quantité pour '$name'",
        unite: 'g',
        defaultValue: defaultGrams,
        usualUnits: usualUnits,
      ),
    ),
  );

  if (resultInGrams != null && mounted) {
    await notifier.addFromPer100(
      name: name,
      kcalPer100: kcalPer100,
      proteinPer100: proteinPer100,
      carbsPer100: carbsPer100,
      fatPer100: fatPer100,
      fibersPer100: fibersPer100,
      sucresPer100: sucresPer100,
      saturatedFatPer100: saturatedFatPer100,
      polyunsaturatedFatPer100: polyunsaturatedFatPer100,
      monounsaturatedFatPer100: monounsaturatedFatPer100,
      qty: resultInGrams,
    );

    if (clearSearchAfter) {
      _searchController.clear();
      notifier.clearSearch();
    }
  }
}


Future<void> _loadAlimentsUsuels() async {
    try {
      final String response = await rootBundle.loadString('assets/poids_usuel.json');
      final List<dynamic> data = json.decode(response);
      if (mounted) {
        setState(() {
          alimentsUsuels = data.map((e) => AlimentUsuel.fromJson(e)).toList();
         _matchingService = FoodMatchingService(alimentsUsuels: alimentsUsuels);
 
        });
      }
    } catch (e) {
      //print("❌ Erreur de chargement de poids_usuel.json: $e");
    }
  }
  @override
  Widget build(BuildContext context) {
    final provider = mealInputProvider((
      mealType: widget.mealType,
      selectedDate: widget.selectedDate,
      fullTimestamp: widget.fullTimestamp,
      ));
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
   

    return Scaffold(
  appBar: AppBar(
    title: const Text("Saisie des repas"),
  ),

  body: Stack(
    children: [
      // =========================
      // 🧩 CONTENU PRINCIPAL
      // =========================
      ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            "Repas pour le ${DateService.formatFrenchShort(state.selectedDate)}",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          DropdownButton<String>(
            value: state.selectedMealType,
            isExpanded: true,
            onChanged: (value) =>
                value != null ? notifier.changeMealType(value) : null,
            items: const [
              "Petit-déjeuner",
              "Déjeuner",
              "Dîner",
              "Collation",
              "Activité",
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          ),

          const SizedBox(height: 16),

          _buildYesterdayMealSection(state, notifier),

          // =========================
          // 🍽️ DÉCOMPOSITION IA
          // =========================
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "🍽️ Décrire le plat",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _decompCtrl,
                    builder: (context, value, _) {
                      return TextField(
                        controller: _decompCtrl,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText:
                              "ex. bol de chili con carne avec riz",
                          border: const OutlineInputBorder(),
                          suffixIcon: value.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => _decompCtrl.clear(),
                                )
                              : null,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed:
                            _isDecomposing ? null : onDecompose,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text("Décomposer"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // =========================
          // 🔎 RECHERCHE ALIMENT
          // =========================
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "🔎 Rechercher un aliment",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  FoodSearchField(
                    controller: _searchController,
                    onChanged: (value) {
                      _debounce?.cancel();
                      _debounce =
                          Timer(const Duration(milliseconds: 500), () {
                        notifier.searchFood(value);
                      });
                    },
                    onClear: () {
                      _searchController.clear();
                      notifier.clearSearch();
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          ..._buildSuggestionsOrResults(state, notifier),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          _buildAddedFoodsSection(
            context,
            meals: state.addedFoodsForDay,
            onRemove: (meal) => notifier.removeFood(meal),
            onQtyChange: (meal, q) =>
                notifier.updateFoodQuantity(meal, q),
            alimentsUsuels: alimentsUsuels,
          ),
        ],
      ),

      // =========================
      // 🔄 OVERLAY LOADING IA
      // =========================
      if (_isDecomposing)
        Positioned.fill(
          child: AbsorbPointer(
            absorbing: true,
            child: Container(
              color: Colors.black.withOpacity(0.35),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      "Analyse du repas…",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  ),

  // =========================
  // 📊 BARRE DE TOTAUX
  // =========================
  bottomNavigationBar: state.addedFoodsForDay.isEmpty
      ? null
      : SafeArea(
          child: TotalsBar(
            calories: state.addedFoodsForDay
                .fold(0.0, (a, m) => a + m.calories),
            prot: state.addedFoodsForDay
                .fold(0.0, (a, m) => a + m.protein),
            carbs: state.addedFoodsForDay
                .fold(0.0, (a, m) => a + m.carbs),
            fat: state.addedFoodsForDay
                .fold(0.0, (a, m) => a + m.fat),
          ),
        ),
);

  }

List<Meal> _filterSuggestions(List<Meal> items) {
  final cleaned = items.where((m) {
    final name = (m.name).trim();
    if (name.isEmpty) return false;
    final kcal = m.calories;
    if (!kcal.isFinite || kcal <= 0 || kcal > 1200) return false;
    final p = m.protein; final g = m.carbs; final l = m.fat;
    if (p < 0 || g < 0 || l < 0 || p > 100 || g > 100 || l > 100) return false;
    if (p == 0 && g == 0 && l == 0) return false;
    return true;
  });

  final seen = <String>{};
  final dedup = <Meal>[];
  for (final m in cleaned) {
    final key = _normalizeKey(m.name);
    if (seen.add(key)) dedup.add(m);
  }
  return dedup.take(15).toList();
}

String _normalizeKey(String s) {
  var t = s.trim().toLowerCase();
  const withAccents = 'àâäáãåçéèêëíìîïñóòôöõúùûüŷýÿœæ';
  const noAccents   = 'aaaaaaceeeeiiiinooooouuuuyyyoeae';
  for (var i = 0; i < withAccents.length; i++) {
    t = t.replaceAll(withAccents[i], noAccents[i]);
  }
  t = t.replaceAll(RegExp(r'[^\w\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ');
  t = t.replaceAll(RegExp(r's\b'), '');
  return t;
}

// ✅ MISE À JOUR DE LA SECTION DES ALIMENTS AJOUTÉS
Widget _buildAddedFoodsSection(
  BuildContext context, {
    required List<Meal> meals,
    required void Function(Meal meal) onRemove,
    required void Function(Meal meal, double newQty) onQtyChange,
    required List<AlimentUsuel> alimentsUsuels,
  }) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  
  return Card(
    elevation: 1,
    color: cs.surfaceContainerHigh,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.checklist, size: 18),
            const SizedBox(width: 6),
            Text("Aliments ajoutés", style: theme.textTheme.titleSmall),
          ]),
          const SizedBox(height: 8),

          if (meals.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Aucun aliment ajouté pour ce repas.",
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: meals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final m = meals[i];
                final refAl = _matchingService.getPoidsUsuel(m.name);
                final double? step  = refAl?.poids.toDouble();
                final String? label = refAl?.unite; 
                
                return Dismissible(
                  key: ValueKey(m.timestamp ?? '${m.name}-${m.date}-${m.type}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => onRemove(m),
                  child: AddedFoodTile(
                    meal: m,
                    onRemove: () => onRemove(m),
                    onQtyChange: (q) => onQtyChange(m, q),
                    unitStepGrams: step,
                    unitLabel: label,
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}
Widget _buildYesterdayMealSection(MealInputState state, MealInputNotifier notifier) {
    if (state.yesterdayMealSuggestions.isEmpty) {
      return const SizedBox.shrink(); // Ne rien afficher si pas de repas hier
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => CopyYesterdayMealSheet(
                      meals: state.yesterdayMealSuggestions,
                      onValidate: (selectedMeals) async {
                        final itemsToAdd = state.yesterdayMealSuggestions
                            .where((m) {
                              final key = '${m.date}_${m.type}_${m.name}';
                              return selectedMeals.containsKey(key);
                            })
                            .map((m) {
                              final key = '${m.date}_${m.type}_${m.name}';
                              return (
                                meal: m,
                                quantity: selectedMeals[key]!,
                              );
                            })
                            .toList();

                        await notifier.addMultipleFoods(itemsToAdd);

                        ref.invalidate(
                          mealInputProvider((
                            mealType: widget.mealType,
                            selectedDate: widget.selectedDate,
                            fullTimestamp: widget.fullTimestamp,
                          )),
                        );
                      },

                    )
            );
          },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              const Icon(Icons.history, color: Colors.blueAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Copier le ${state.selectedMealType.toLowerCase()} d'hier",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }


/// Construit la carte d'actions [Créer] + [FatSecret]
Widget _buildActionCard(MealInputState state, MealInputNotifier notifier) {
  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Bouton Créer (toujours un callback NON-nullable)
          Expanded(
            child: CreateFoodButton(
              label: "Créer",
              color: Colors.orange,
              nameSuggestion: _searchController.text,
              onPressed: (context, suggestion) => _showCreateFoodDialog(notifier),
            ),
          ),
          const SizedBox(width: 12),
          // Bouton FatSecret
          Expanded(
            child: ElevatedButton.icon(
              onPressed: state.status == SearchStatus.loading
                  ? null
                  : () => notifier.searchFoodFatSecret(_searchController.text),
              icon: state.status == SearchStatus.loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: const Text("FatSecret"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
  
  List<Widget> _buildSuggestionsOrResults(MealInputState state, MealInputNotifier notifier) {
  // 1) Loading : on garde ta logique d'origine (spinner seul)
  if (state.status == SearchStatus.loading) {
    return [const Center(child: CircularProgressIndicator())];
  }

  // 2) Si l'utilisateur a tapé assez de caractères
  if (_searchController.text.length > 2) {
    
    // On vérifie les deux listes de résultats (en supposant que le Notifier les a remplies)
    final bool hasHistoryResults = state.historySearchSuggestions.isNotEmpty;
    final bool hasLocalResults = state.searchSuggestions.isNotEmpty;

    return [
      // La carte d'actions est toujours là
      _buildActionCard(state, notifier),

      // === PRIORITÉ 1 : RÉSULTATS DE L'HISTORIQUE (FIRESTORE) ===
      if (hasHistoryResults)
        ..._buildHistorySearchResults(state.historySearchSuggestions, notifier),

      // === PRIORITÉ 2 : RÉSULTATS LOCAUX (OFF) ===
      if (hasLocalResults)
        ..._buildSearchResults(state.searchSuggestions, notifier),

      // === CAS : AUCUN RÉSULTAT NULLE PART ===
      if (!hasHistoryResults && !hasLocalResults)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Center(child: Text("Aucun résultat trouvé.")),
        ),
    ];
  }

  // 3) Sinon : suggestions récentes (logique inchangée)
  return _buildrecentSuggestions(state.recentSuggestions, notifier);
}

  List<Widget> _buildrecentSuggestions(
  List<Meal> suggestions,
  MealInputNotifier notifier,
) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  final filtered = _filterSuggestions(suggestions);

  if (filtered.isEmpty) {
    return [
      Card(
        elevation: 1,
        color: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text("Aucune suggestion pertinente pour l’instant."),
        ),
      ),
    ];
  }

  return [
    Card(
      elevation: 1,
      color: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.lightbulb, size: 16),
              const SizedBox(width: 6),
              Text("Mes aliments récents", style: theme.textTheme.titleSmall),
            ]),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (theme.textTheme.bodyMedium?.fontSize ?? 14) *
                          (theme.textTheme.bodyMedium?.height ?? 1.2) *
                          15,
              ),
              child: Scrollbar(
                controller: _recentScrollCtrl,
                thumbVisibility: true,
                child: ListView.separated(
                  controller: _recentScrollCtrl,
                  padding: EdgeInsets.zero,
                  primary: false,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final meal = filtered[i];
                    return SuggestionMealCard(
                      meal: meal,
                      kcalPer100: meal.kcalPer100X,
                      proteinPer100: meal.proteinPer100X,
                      carbsPer100: meal.carbsPer100X,
                      fatPer100: meal.fatPer100X,
                      // ✅ ON PASSE LES NOUVEAUX CHAMPS À LA FONCTION D'AJOUT
                      onAdd: () => _showQuantityDialogFromPer100(
                        name: meal.name,
                        kcalPer100: meal.kcalPer100X,
                        proteinPer100: meal.proteinPer100X,
                        carbsPer100: meal.carbsPer100X,
                        fatPer100: meal.fatPer100X,
                        fibersPer100: meal.fibersPer100X,
                        sucresPer100: meal.sucresPer100X,
                        saturatedFatPer100: meal.saturatedFatPer100X,
                        polyunsaturatedFatPer100: meal.polyunsaturatedFatPer100X,
                        monounsaturatedFatPer100: meal.monounsaturatedFatPer100X,
                        notifier: notifier,
                      ),
                    );
                  },
                ),
              ),
            )
          ],
        ),
      ),
    ),
  ];
}



// résultat de la recherche
  List<Widget> _buildSearchResults(List<dynamic> suggestions, MealInputNotifier notifier) {
     if (suggestions.isEmpty) return [const Center(child: Text("Aucun résultat."))];
     return [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8), // Padding ajusté
        child: Text(
          "Résultats de la recherche locale", // Titre plus clair
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      ...suggestions.map((foodData) {
          final name = foodData['product_name'] as String? ?? 'Nom inconnu';
          final source = (foodData['source'] as String?) ?? 'api';
          final Map<String, dynamic> nutriments = (foodData is Map && foodData['nutriments'] is Map)
            ? (foodData['nutriments'] as Map).map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{};
          final double calories = energyKcal100g(nutriments);
          final double prot     = asDouble(nutriments['proteins_100g']);
          final double carb     = asDouble(nutriments['carbohydrates_100g']);
          final double fat      = asDouble(nutriments['fat_100g']);
          return ListTile(
            title: Text(name),
            subtitle: Text("${calories.toStringAsFixed(0)} kcal | P:${prot}g C:${carb}g F:${fat}g • ${source.toUpperCase()}"),
            trailing: const Icon(Icons.add_circle_outline),
            onTap: () {
              _showQuantityDialog(foodData, notifier);
            },
          );
        }),
     ];
     
  }
  

Future<void> _showQuantityDialog(dynamic foodData, MealInputNotifier notifier) async {
  final String name = foodData is Meal
      ? foodData.name
      : ((foodData['name'] ?? foodData['product_name']) as String? ?? 'Aliment');

  final AlimentUsuel? refAliment = _matchingService.getPoidsUsuel(name);
  final List<UsualUnit> usualUnits = [];
  if (refAliment != null && refAliment.poids > 0) {
    usualUnits.add(UsualUnit(
      label: refAliment.unite,
      gramsPerUnit: refAliment.poids.toDouble(),
    ));
  }

  final double defaultGrams =
      usualUnits.isNotEmpty ? usualUnits.first.gramsPerUnit : (refAliment?.poids.toDouble() ?? 100.0);

  if (!mounted) return;

  final resultInGrams = await Navigator.of(context).push<double>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => QuantityPage(
        title: "Quantité pour '$name'",
        unite: 'g',
        defaultValue: defaultGrams,
        usualUnits: usualUnits,
      ),
    ),
  );

  if (resultInGrams != null && mounted) {
    await notifier.addFood(foodData, resultInGrams);
    _searchController.clear();
    notifier.clearSearch();
  }
}

  /// Affiche le dialogue pour créer un nouvel aliment
  // ✅ MISE À JOUR COMPLÈTE DU DIALOGUE DE CRÉATION
  Future<void> _showCreateFoodDialog(MealInputNotifier notifier) async {
    final formKey = GlobalKey<FormState>(); 
    final nameController = TextEditingController(text: _searchController.text);
    final calController = TextEditingController();
    final protController = TextEditingController();
    final carbController = TextEditingController();
    final fatController = TextEditingController();
    // ✅ NOUVEAUX CONTROLLERS
    final fiberController = TextEditingController();
    final sucresController = TextEditingController();
    final satFatController = TextEditingController();
    final polyFatController = TextEditingController();
    final monoFatController = TextEditingController();

    final qtyController = TextEditingController(text: "100");

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Créer un nouvel aliment"),
        content: SingleChildScrollView(
          child: Form(
          key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Nom"),
                  validator: (value) => (value?.trim().isEmpty ?? true) ? 'Le nom est obligatoire.' : null,
                  autofocus: true,
                ),
                TextField(controller: calController, decoration: const InputDecoration(labelText: "Calories / 100g"), keyboardType: TextInputType.number),
                TextField(controller: protController, decoration: const InputDecoration(labelText: "Protéines / 100g"), keyboardType: TextInputType.number),
                TextField(controller: carbController, decoration: const InputDecoration(labelText: "Glucides / 100g"), keyboardType: TextInputType.number),
                TextField(controller: fatController, decoration: const InputDecoration(labelText: "Lipides / 100g"), keyboardType: TextInputType.number),
                // ✅ NOUVEAUX CHAMPS DE SAISIE
                TextField(controller: fiberController, decoration: const InputDecoration(labelText: "Fibres / 100g"), keyboardType: TextInputType.number),
                TextField(controller: sucresController, decoration: const InputDecoration(labelText: "Sucres / 100g"), keyboardType: TextInputType.number),
                TextField(controller: satFatController, decoration: const InputDecoration(labelText: "dont Ac. gras saturés / 100g"), keyboardType: TextInputType.number),
                TextField(controller: polyFatController, decoration: const InputDecoration(labelText: "dont Ac. gras polyinsaturés / 100g"), keyboardType: TextInputType.number),
                TextField(controller: monoFatController, decoration: const InputDecoration(labelText: "dont Ac. gras monoinsaturés / 100g"), keyboardType: TextInputType.number),
                
                TextField(controller: qtyController, decoration: const InputDecoration(labelText: "Quantité consommée (g)"), keyboardType: TextInputType.number),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                // ✅ ON PASSE LES NOUVELLES VALEURS AU NOTIFIER
                await notifier.createAndAddFood(
                  name: nameController.text,
                  calories: double.tryParse(calController.text) ?? 0,
                  protein: double.tryParse(protController.text) ?? 0,
                  carbs: double.tryParse(carbController.text) ?? 0,
                  fat: double.tryParse(fatController.text) ?? 0,
                  fibers: double.tryParse(fiberController.text) ?? 0,
                  sucres: double.tryParse(sucresController.text) ?? 0,
                  saturatedFat: double.tryParse(satFatController.text) ?? 0,
                  polyunsaturatedFat: double.tryParse(polyFatController.text) ?? 0,
                  monounsaturatedFat: double.tryParse(monoFatController.text) ?? 0,
                  quantity: double.tryParse(qtyController.text) ?? 100,
                );

                _searchController.clear();
                notifier.clearSearch();
                if (mounted) Navigator.of(context).pop();
             }
            },
            child: const Text("Créer et Ajouter"),
          ),
        ],
      ),
    );
  }
}






