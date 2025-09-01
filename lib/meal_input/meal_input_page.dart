import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import '../models/meal.dart';
import '../repositories/enrichir_poids_usuel.dart';
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



class MealInputPage extends ConsumerStatefulWidget {
  final String selectedDate;
  final String mealType;

  const MealInputPage({
    super.key,
    required this.selectedDate,
    this.mealType = "Petit-déjeuner",
  });

  @override
  ConsumerState<MealInputPage> createState() => _MealInputPageState();
}

/// apparence des boutons - / + 
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final double diameter;     // plus petit par défaut
  final Color? color;        // couleur d’accent

  const _RoundIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.enabled = true,
    this.diameter = 30, // ← plus petit (ex 28–32)
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final Color base = color ?? Theme.of(context).colorScheme.primary;
    // Pastel doux (fond clair, icône lisible)
    final Color bg = enabled 
        ? base.withValues(alpha: 0.18) 
        : Colors.grey.withValues(alpha: 0.22);
    final Color fg = enabled 
        ? base.withValues(alpha: 0.95) 
        : Colors.grey;

    final double iconSize = diameter * 0.55;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: Border.all(color: base.withValues(alpha: 0.22)), // anneau pastel
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: iconSize, color: fg),
        ),
      ),
    );
  }
}




class _MealInputPageState extends ConsumerState<MealInputPage> {
  final TextEditingController _searchController = TextEditingController();
  final _decompCtrl = TextEditingController();
  final _decompSvc  = DecompositionService();
  final _recentScrollCtrl = ScrollController();
  final _poidsRepo = PoidsUsuelsRepository();
  List<AlimentUsuel> alimentsUsuels = [];



@override
  void initState() {
    super.initState(); 
    _loadAlimentsUsuels();
  }

  @override
  void dispose() {
  _searchController.dispose();
  _decompCtrl.dispose();
  _recentScrollCtrl.dispose();
  super.dispose();
}
  // decomposition des plats en aliments
Future<void> onDecompose() async {
  final description = _decompCtrl.text.trim();
  if (description.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Écris d’abord la description du plat.")),
      );
    }
    return;
  }

  try {
    final data = await _decompSvc.decompose(description);
    final items = (data["ingredients"] as List)
        .map((e) => ProposedIngredient.fromJson(e as Map<String, dynamic>))
        .toList();

    if (!mounted) return;

    final provider = mealInputProvider((widget.mealType, widget.selectedDate));
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
      ref.invalidate(mealInputProvider((widget.mealType, widget.selectedDate)));
      _decompCtrl.clear();
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur décomposition : $e")),
      );
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
  required double saturatedFatPer100,
  required double polyunsaturatedFatPer100,
  required double monounsaturatedFatPer100,
  required MealInputNotifier notifier,
  bool clearSearchAfter = false,
}) async {
  final AlimentUsuel? refAliment = _getPoidsUsuel(name);
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
      // ✅ ON PASSE LES NOUVEAUX CHAMPS AU NOTIFIER
      fibersPer100: fibersPer100,
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
          
        });
      }
    } catch (e) {
      //print("❌ Erreur de chargement de poids_usuel.json: $e");
    }
  }
  @override
  Widget build(BuildContext context) {
    final provider = mealInputProvider((widget.mealType, widget.selectedDate));
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
   

    return Scaffold(
      appBar: AppBar(title: const Text("Saisie des repas")),
      
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text("Repas pour le ${DateService.formatFrenchShort(state.selectedDate)}", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          DropdownButton<String>(
            value: state.selectedMealType,
            isExpanded: true,
            onChanged: (value) => value != null ? notifier.changeMealType(value) : null,
            items: ["Petit-déjeuner", "Déjeuner", "Dîner", "Collation", "Activité"]
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
          ),
          const SizedBox(height: 16),
          _buildYesterdayMealSection(state, notifier),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "🍽️ Décrire le plat",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          hintText: "ex. bol de chili con carne avec riz",
                          border: const OutlineInputBorder(),
                          suffixIcon: value.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => _decompCtrl.clear(),
                                )
                              : null,
                        ),
                        onSubmitted: (_) => onDecompose,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: onDecompose,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text("Décomposer"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
Card(
  margin: const EdgeInsets.only(bottom: 16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "🔎 Rechercher un aliment",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        FoodSearchField(
          controller: _searchController,
          onChanged: (value) => notifier.searchFood(value),
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
              onQtyChange: (meal, q) => notifier.updateFoodQuantity(meal, q),
              alimentsUsuels: alimentsUsuels,
            ),
        ],
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
        onTap: () => _showYesterdayMealDialog(
          context: context,
          meals: state.yesterdayMealSuggestions,
          notifier: notifier,
          alimentsUsuels: alimentsUsuels,
        ),
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

  // NOUVELLE MÉTHODE : Affiche la feuille de sélection
  // Dans votre fichier : meal_input_page.dart

Future<void> _showYesterdayMealDialog({
  required BuildContext context,
  required List<Meal> meals,
  required MealInputNotifier notifier,
  required List<AlimentUsuel> alimentsUsuels,
}) async {
  final Map<String, double> selectedMeals = {};

  // Pré-sélection : toutes les quantités d’hier
  for (final meal in meals) {
    final key = meal.key ?? meal.name;
    selectedMeals[key] = meal.quantity;
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          const double step = 10.0;
          const double controlsWidth = 148; // largeur réservée pour "- qty +"

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            builder: (_, scrollController) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text("Repas d'hier", style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text("Cochez les aliments à ajouter et ajustez les quantités."),
                  const Divider(height: 24),

                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: meals.length,
                      itemBuilder: (context, index) {
                        final meal = meals[index];
                        final key = meal.key ?? meal.name;
                        final isSelected = selectedMeals.containsKey(key);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Checkbox à gauche
                              Checkbox(
                                value: isSelected,
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      selectedMeals[key] = meal.quantity;
                                    } else {
                                      selectedMeals.remove(key);
                                    }
                                  });
                                },
                              ),

                              const SizedBox(width: 8),

                              // Titre + sous-titre au centre (ellipsés pour ne pas empiéter)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      meal.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                    Text(
                                      "Hier : ${meal.quantity.toStringAsFixed(0)}g",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                            ),

                              const SizedBox(width: 8),

                              // Bloc de droite à largeur FIXE -> jamais clippé
                              SizedBox(
                                width: controlsWidth,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    _RoundIconButton(
                                      icon: Icons.remove, // plein, contraste fort
                                      enabled: isSelected,
                                      onTap: !isSelected ? null : () {
                                        setState(() {
                                          final currentQty = selectedMeals[key]!;
                                          final newQty = currentQty - step;
                                          if (newQty <= 0) {
                                            selectedMeals.remove(key);
                                          } else {
                                            selectedMeals[key] = newQty;
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    // Quantité à largeur FIXE (ne pousse pas les icônes)
                                    SizedBox(
                                      width: 56,
                                      child: Text(
                                        isSelected
                                            ? "${selectedMeals[key]?.toStringAsFixed(0)}g"
                                            : "- g",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.black87 : Colors.grey,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _RoundIconButton(
                                      icon: Icons.add, // plein, contraste fort
                                      enabled: isSelected,
                                      onTap: !isSelected ? null : () {
                                        setState(() {
                                          final currentQty = selectedMeals[key]!;
                                          selectedMeals[key] = currentQty + step;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bouton d'ajout
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: selectedMeals.isEmpty
                        ? null
                        : () async {
                            final itemsToAdd = meals
                                .where((m) => selectedMeals.containsKey(m.key ?? m.name))
                                .map((m) => (meal: m, quantity: selectedMeals[m.key ?? m.name]!))
                                .toList();

                            await notifier.addMultipleFoods(itemsToAdd);
                            if (context.mounted) Navigator.pop(context);
                          },
                    child: Text("Ajouter ${selectedMeals.length} aliment(s)"),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  
  List<Widget> _buildSuggestionsOrResults(MealInputState state, MealInputNotifier notifier) {
    if (state.status == SearchStatus.loading) {
      return [const Center(child: CircularProgressIndicator())];
    }
    if (_searchController.text.length > 2) {
      if (state.searchSuggestions.isEmpty) {
        return [
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: CreateFoodButton(
                          label: "Créer",
                          color: Colors.orange,
                          nameSuggestion: _searchController.text,
                          onPressed: (context, suggestion) => _showCreateFoodDialog(notifier),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: state.status == SearchStatus.loading
                              ? null
                              : () => notifier.searchFood(_searchController.text, forceOnline: true),
                          icon: state.status == SearchStatus.loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.cloud_download),
                          label: const Text("Internet"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
        ];    
      }
      return _buildSearchResults(state.searchSuggestions, notifier);
    }
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
      Text("Résultats de la recherche", style: Theme.of(context).textTheme.titleLarge),
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
  

String _normalize(String s) {
  final lower = s.trim().toLowerCase();
  const repl = {
    'à':'a','á':'a','â':'a','ä':'a','ã':'a','å':'a', 'ç':'c', 'è':'e','é':'e','ê':'e','ë':'e',
    'ì':'i','í':'i','î':'i','ï':'i', 'ñ':'n', 'ò':'o','ó':'o','ô':'o','ö':'o','õ':'o',
    'ù':'u','ú':'u','û':'u','ü':'u', 'ÿ':'y'
  };
  final sb = StringBuffer();
  for (final ch in lower.characters) {
    sb.write(repl[ch] ?? ch);
  }
  return sb.toString().replaceAll(RegExp(r'\s+'), ' ');
}

List<String> _tokens(String s) {
  return _normalize(s)
      .split(RegExp(r'[^a-z0-9%]+'))
      .where((w) => w.isNotEmpty && w.length > 1)
      .toList();
}

bool _wordBoundaryContains(String haystack, String needle) {
  final re = RegExp(r'\b' + RegExp.escape(needle) + r'\b');
  return re.hasMatch(haystack);
}

double _coverageScore({
  required List<String> nameWords,
  required List<String> keyWords,
  required String nameNorm,
}) {
  if (keyWords.isEmpty) return 0;
  int hits = 0;
  for (final w in keyWords) {
    if (_wordBoundaryContains(nameNorm, w)) hits++;
  }
  return hits / keyWords.length;
}

AlimentUsuel? _getPoidsUsuel(String nom) {
  final rawName   = nom.trim();
  if (rawName.isEmpty || alimentsUsuels.isEmpty) return null;

  final nameNorm  = _normalize(rawName);
  final nameWords = _tokens(rawName);
  if (nameWords.isEmpty) return null;

  AlimentUsuel? best;
  int bestScore = -1;

  for (final a in alimentsUsuels) {
    final keyRaw   = a.aliment.trim();
    if (keyRaw.isEmpty) continue;
    final keyNorm  = _normalize(keyRaw);
    final keyWords = _tokens(keyRaw);
    if (keyWords.isEmpty) continue;
    int score = 0;
    if (nameNorm == keyNorm) {
      score = 3000;
    } else {
      final setName = nameWords.toSet();
      final setKey  = keyWords.toSet();
      if (setName.length == setKey.length && setName.containsAll(setKey)) {
        score = 2400 + keyWords.length;
      }
      if (score == 0) {
        final cov = _coverageScore(nameWords: nameWords, keyWords: keyWords, nameNorm: nameNorm);
        if (cov >= 0.9) score = 2000 + keyWords.length;
        else if (cov >= 0.7) score = 1500 + (cov * 100).round();
      }
      if (score == 0 && keyWords.length == 1) {
        final k = keyWords.first;
        if (nameNorm.startsWith(k + ' ') || nameNorm == k) score = 900;
      }
    }
    if (score > bestScore) {
      bestScore = score;
      best = a;
    }
  }

  if (best != null && bestScore >= 1200) return best;

  _poidsRepo.addMissingIfNeeded(rawName);
  return null;
}



Future<void> _showQuantityDialog(dynamic foodData, MealInputNotifier notifier) async {
  final String name = foodData is Meal
      ? foodData.name
      : ((foodData['name'] ?? foodData['product_name']) as String? ?? 'Aliment');

  final AlimentUsuel? refAliment = _getPoidsUsuel(name);
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
                final refAl = poidsUsuelForName(alimentsUsuels, m.name);
                final double? step  = refAl?.poids.toDouble();
                final String? label = refAl?.unite; 
                
                return Dismissible(
                  key: ValueKey(m.firestoreId ?? m.key ?? '${m.name}-${m.date}-${m.type}'),
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

          if (meals.isNotEmpty) ...[
            const SizedBox(height: 10),
            // ✅ ON PASSE LES NOUVEAUX TOTAUX À LA BARRE
            TotalsBar(
              calories: meals.fold<double>(0.0, (a, m) => a + m.calories),
              prot:     meals.fold<double>(0.0, (a, m) => a + m.protein),
              carbs:    meals.fold<double>(0.0, (a, m) => a + m.carbs),
              fat:      meals.fold<double>(0.0, (a, m) => a + m.fat),
            ),
          ],
        ],
      ),
    ),
  );
}



AlimentUsuel? poidsUsuelForName(List<AlimentUsuel> base, String nom) {
      final lowerName = nom.trim().toLowerCase();
      if (base.isEmpty) return null;
      for (var a in base) {
        if (lowerName == a.aliment.trim().toLowerCase()) return a;
      }
      final firstWord = lowerName.split(' ').first;
      if (firstWord.isNotEmpty && firstWord != lowerName) {
        for (var a in base) {
          if (firstWord == a.aliment.trim().toLowerCase()) return a;
        }
      }
      AlimentUsuel? best;
      int bestIndex = -1;
      for (var a in base) {
        final keyword = a.aliment.trim().toLowerCase();
        if (keyword.isNotEmpty && lowerName.contains(keyword)) {
          final idx = lowerName.indexOf(keyword);
          if (best == null || idx < bestIndex) {
            best = a; bestIndex = idx;
          }
        }
      }
      return best;
    }
