import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import '../models/meal.dart';
import '../meal_input/meal_input_notifier.dart';
import '../meal_input/meal_input_state.dart';
import '../widget/food_search_field.dart';
import '../widget/create_food_button.dart';
import '../services/date_service.dart';
import '../services/fonctions.dart';
import '../models/aliment_usuel.dart'; 



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



class _MealInputPageState extends ConsumerState<MealInputPage> {
  final TextEditingController _searchController = TextEditingController();
  List<AlimentUsuel> alimentsUsuels = [];

@override
  void initState() {
    super.initState(); // C'est une ligne standard et obligatoire
    // On appelle la méthode de chargement ici
    _loadAlimentsUsuels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      print("❌ Erreur de chargement de poids_usuel.json: $e");
    }
  }
  @override
  Widget build(BuildContext context) {
    final provider = mealInputProvider((widget.mealType, widget.selectedDate));
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    

    return Scaffold(
      appBar: AppBar(title: const Text("Saisie des repas")),
      // ✅ On utilise un unique ListView qui gère tout
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- PARTIE HAUTE (FIXE) ---
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
          FoodSearchField(
            controller: _searchController,
            onChanged: (value) => notifier.searchFood(value),
            onClear: () {
              _searchController.clear();
              notifier.clearSearch();
            },
          ),
          const SizedBox(height: 16),

          // --- PARTIE CENTRALE (SUGGESTIONS / RÉSULTATS) ---
          // On utilise l'opérateur "..." pour insérer la liste de widgets directement
          ..._buildSuggestionsOrResults(state, notifier),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // --- PARTIE BASSE (ALIMENTS AJOUTÉS) ---
          _buildAddedFoodsSection(
              context,
              meals: state.addedFoodsForDay,
              onRemove: (meal) => notifier.removeFood(meal),
              onQtyChange: (meal, q) => notifier.updateFoodQuantity(meal, q), // adapte le nom si différent
            ),
        ],
      ),
    );
  }

  // ✅ Ces méthodes retournent maintenant des List<Widget>
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
                  // ✅ ON REMPLACE LE WRAP PAR UN ROW
                  child: Row(
                    children: [
                      // ✅ On enveloppe chaque bouton dans un Expanded
                      Expanded(
                        child: CreateFoodButton(
                          label: "Créer", // Un label plus court pour les petits écrans
                          color: Colors.orange,
                          nameSuggestion: _searchController.text,
                          onPressed: (context, suggestion) => _showCreateFoodDialog(notifier),
                        ),
                      ),
                      const SizedBox(width: 12), // Espace entre les boutons
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: state.status == SearchStatus.loading
                              ? null
                              : () => notifier.searchFoodFromAPI(_searchController.text),
                          icon: state.status == SearchStatus.loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.cloud_download),
                          label: const Text("Internet"), // Un label plus court
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
    return _buildFrequentSuggestions(state.frequentSuggestions, notifier);
  }

  List<Widget> _buildFrequentSuggestions(
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
              Text("Suggestions fréquentes", style: theme.textTheme.titleSmall),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filtered.map((meal) {
                return _SuggestionMealCardCompact(
                  meal: meal,
                  onAdd: () => _showQuantityDialog(meal, notifier),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ),
  ];
}




  List<Widget> _buildSearchResults(List<dynamic> suggestions, MealInputNotifier notifier) {
     if (suggestions.isEmpty) return [const Center(child: Text("Aucun résultat."))];
     return [
      Text("Résultats de la recherche", style: Theme.of(context).textTheme.titleLarge),
      ...suggestions.map((foodData) {
          final name = foodData['product_name'] as String? ?? 'Nom inconnu';
          final isCustom = foodData['isCustom'] == true;
          final nutriments = foodData['nutriments'] as Map<String, dynamic>? ?? {};
          final calories = nutriments['energy-kcal_100g'] as num? ?? 0.0;
          return ListTile(
            leading: isCustom ? const Icon(Icons.star, color: Colors.amber) : null,
            title: Text(name),
            subtitle: Text("${calories.toStringAsFixed(0)} kcal / 100g"),
            trailing: const Icon(Icons.add_circle_outline),
            onTap: () {
              _searchController.clear();
              notifier.clearSearch();
              _showQuantityDialog(foodData, notifier);
            },
          );
        }),
     ];
  }
  

  /// Affiche le dialogue pour entrer la quantité
  // dans la classe _MealInputPageState
AlimentUsuel? _getPoidsUsuel(String nom) {
  final lowerName = nom.trim().toLowerCase();
  if (alimentsUsuels.isEmpty) return null;
  
  

  // --- PASSE 1 : Correspondance Exacte ---
  // Cherche si un aliment du JSON correspond exactement au nom.
  for (var a in alimentsUsuels) {
    if (lowerName == a.aliment.trim().toLowerCase()) {
      
      return a;
    }
  }

  // --- PASSE 2 : Correspondance avec le Premier Mot ---
  // Cherche si un aliment du JSON correspond au premier mot du nom.
  final firstWord = lowerName.split(' ').first;
  if (firstWord.isNotEmpty && firstWord != lowerName) {
    for (var a in alimentsUsuels) {
      if (firstWord == a.aliment.trim().toLowerCase()) {
        
        return a;
      }
    }
  }

  // --- PASSE 3 : Meilleure Correspondance Partielle (Fallback) ---
  // Trouve toutes les correspondances partielles et choisit la meilleure.
  AlimentUsuel? bestPartialMatch;
  int bestMatchIndex = -1;

  for (var a in alimentsUsuels) {
    final keyword = a.aliment.trim().toLowerCase();
    if (keyword.isNotEmpty && lowerName.contains(keyword)) {
      final matchIndex = lowerName.indexOf(keyword);
      // On garde la correspondance qui apparaît le plus tôt dans la chaîne
      if (bestPartialMatch == null || matchIndex < bestMatchIndex) {
        bestPartialMatch = a;
        bestMatchIndex = matchIndex;
      }
    }
  }

  if (bestPartialMatch != null) return bestPartialMatch;
  

  
  return null;
}


Future<void> _showQuantityDialog(dynamic foodData, MealInputNotifier notifier) async {
  final String name = foodData is Meal ? foodData.name : (foodData['product_name'] as String? ?? 'Aliment');
  final AlimentUsuel? refAliment = _getPoidsUsuel(name);
  final double poidsDefaut = refAliment?.poids.toDouble() ?? 100.0;

  if (!mounted) return;

  final result = await Navigator.of(context).push<double>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _QuantityPage(
        title: "Quantité pour '$name'",
        unite: refAliment?.unite ?? 'g',
        commentaire: refAliment?.commentaire,
        defaultValue: poidsDefaut,
      ),
    ),
  );

  if (result != null && mounted) {
    notifier.addFood(foodData, result);
  }
}



  /// Affiche le dialogue pour créer un nouvel aliment
  Future<void> _showCreateFoodDialog(MealInputNotifier notifier) async {
    // ✅ On ajoute une GlobalKey pour la validation du formulaire
    final formKey = GlobalKey<FormState>(); 
    // On crée des controllers pour chaque champ du formulaire
    final nameController = TextEditingController(text: _searchController.text);
    final calController = TextEditingController();
    final protController = TextEditingController();
    final carbController = TextEditingController();
    final fatController = TextEditingController();
    final qtyController = TextEditingController(text: "100");

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Créer un nouvel aliment"),
        // Le SingleChildScrollView évite les erreurs de dépassement quand le clavier apparaît
        content: SingleChildScrollView(
          child: Form(
          key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField( // ✅ On utilise un TextFormField pour la validation
                controller: nameController,
                decoration: const InputDecoration(labelText: "Nom"),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le nom est obligatoire.';
                  }
                  return null;
                },
                autofocus: true,
              ),
                TextField(controller: calController, decoration: const InputDecoration(labelText: "Calories / 100g"), keyboardType: TextInputType.number),
                TextField(controller: protController, decoration: const InputDecoration(labelText: "Protéines / 100g"), keyboardType: TextInputType.number),
                TextField(controller: carbController, decoration: const InputDecoration(labelText: "Glucides / 100g"), keyboardType: TextInputType.number),
                TextField(controller: fatController, decoration: const InputDecoration(labelText: "Lipides / 100g"), keyboardType: TextInputType.number),
                TextField(controller: qtyController, decoration: const InputDecoration(labelText: "Quantité consommée (g)"), keyboardType: TextInputType.number),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              // On appelle la méthode du Notifier pour créer et ajouter le repas
              if (formKey.currentState!.validate()) {
              await notifier.createAndAddFood(
                name: nameController.text,
                calories: double.tryParse(calController.text) ?? 0,
                protein: double.tryParse(protController.text) ?? 0,
                carbs: double.tryParse(carbController.text) ?? 0,
                fat: double.tryParse(fatController.text) ?? 0,
                quantity: double.tryParse(qtyController.text) ?? 100,
              );

              // On nettoie la recherche et on ferme la pop-up
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
// Widget _quantityPage pour ne pas avoir l'écran de saisie qui saute
class _QuantityPage extends StatefulWidget {
  final String title;
  final String unite;
  final String? commentaire;
  final double defaultValue;

  const _QuantityPage({
    required this.title,
    required this.unite,
    this.commentaire,
    required this.defaultValue,
  });

  @override
  State<_QuantityPage> createState() => _QuantityPageState();
}

class _QuantityPageState extends State<_QuantityPage> {
  late final TextEditingController _controller;
  double _value = 0;

  @override
  void initState() {
    super.initState();
    _value = widget.defaultValue;
    _controller = TextEditingController(text: _fmt(_value));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _fmt(double v) => v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  double _parse(String s) => double.tryParse(s.replaceAll(',', '.')) ?? _value;
  void _setValue(double v) {
    setState(() {
      _value = v.clamp(0, 999999);
      final t = _fmt(_value);
      _controller.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
    });
  }
  void _nudge(double d) => _setValue(_value + d);
  void _submit() => Navigator.of(context).pop(_value);

  // Récupère le nom d'aliment depuis le title "Quantité pour 'xxx'"
  String get _foodName {
    final t = widget.title;
    if (t.contains("'")) {
      final parts = t.split("'");
      if (parts.length >= 2) return parts[1];
    }
    return t;
  }

  List<double> _suggestions() {
    final base = <double>{widget.defaultValue, 50, 100, 150, 200};
    final list = base.where((e) => e > 0).toList()..sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Quantité"),
        actions: [TextButton(onPressed: _submit, child: const Text("OK"))],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nom aliment — petit, multi-lignes
              Text(
                _foodName,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                maxLines: 3,
                softWrap: true,
              ),
              const SizedBox(height: 8),

              // Carte compacte valeur + unité
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: cs.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.done,
                          autofocus: true, // mets à false si un micro-saut au focus
                          onChanged: (s) => _setValue(_parse(s)),
                          onSubmitted: (_) => _submit(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, height: 1.0),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: "0",
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(widget.unite, style: theme.textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Stepper compact
              Row(
                children: [
                  _MiniBtn(label: "-10", onTap: () => _nudge(-10)),
                  const SizedBox(width: 6),
                  _MiniBtn(label: "-1", onTap: () => _nudge(-1)),
                  const Spacer(),
                  _MiniBtn(label: "+1", onTap: () => _nudge(1), filled: true),
                  const SizedBox(width: 6),
                  _MiniBtn(label: "+10", onTap: () => _nudge(10), filled: true),
                ],
              ),

              const SizedBox(height: 10),

              // Chips suggestions — denses
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _suggestions().map((s) {
                  final selected = (_value - s).abs() < 0.0001;
                  return ChoiceChip(
                    selected: selected,
                    label: Text("${_fmt(s)} ${widget.unite}"),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (_) => _setValue(s),
                    selectedColor: cs.primaryContainer,
                    labelStyle: TextStyle(color: selected ? cs.onPrimaryContainer : null, fontSize: 12),
                  );
                }).toList(),
              ),

              const Spacer(),

              // CTA collé bas
              SafeArea(
                top: false,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Ajouter ${_fmt(_value)} ${widget.unite}"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Bouton compact (Outlined / Tonal)
class _MiniBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  const _MiniBtn({required this.label, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    if (filled) {
      return FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: shape),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: shape,
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Text(label),
    );
  }
}
class _SuggestionMealCardCompact extends StatelessWidget {
  final Meal meal;
  final VoidCallback onAdd;
  const _SuggestionMealCardCompact({required this.meal, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final kcal  = (meal.calories ?? 0).toDouble();
    final prot  = (meal.protein  ?? 0).toDouble();
    final carbs = (meal.carbs    ?? 0).toDouble();
    final fat   = (meal.fat      ?? 0).toDouble();

    return LayoutBuilder(
      builder: (ctx, cons) {
        final maxW = cons.maxWidth.isFinite ? cons.maxWidth : 220.0;

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onAdd,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: 140, maxWidth: maxW),
            child: Container(
              padding: const EdgeInsets.all(8), // 📏 compact
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom (2 lignes max, petit)
                  Text(
                    meal.name.cap(max: 30),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),

                  // Ligne info + bouton compressible (peut passer dessous si trop étroit)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_dining, size: 16, color: cs.primary),
                          const SizedBox(width: 4),
                          Text(
                            "${kcal.toStringAsFixed(0)} kcal / 100g",
                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: FilledButton.tonalIcon(
                          onPressed: onAdd,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text("Ajouter"),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 30),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Macros en ligne compacte (1 ligne)
                  Text(
                    "P ${prot.toStringAsFixed(0)}g • G ${carbs.toStringAsFixed(0)}g • L ${fat.toStringAsFixed(0)}g",
                    style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}




List<Meal> _filterSuggestions(List<Meal> items) {
  // 1) nettoie / filtre
  final cleaned = items.where((m) {
    final name = (m.name).trim();
    final kcal = (m.calories ?? 0).toDouble();
    final p = (m.protein ?? 0).toDouble();
    final g = (m.carbs ?? 0).toDouble();
    final l = (m.fat ?? 0).toDouble();

    if (name.isEmpty) return false;
    if (!kcal.isFinite || kcal <= 0) return false;                  // 🔎 exclut 0 kcal
    if (kcal > 1200) return false;                                   // bornes réalistes /100g
    if (p < 0 || g < 0 || l < 0 || p > 100 || g > 100 || l > 100) return false;
    if (p == 0 && g == 0 && l == 0) return false;                    // évite les fiches vides
    return true;
  });

  // 2) dé-doublonne par nom "normalisé" (garde la 1re occurrence)
  final seen = <String>{};
  final dedup = <Meal>[];
  for (final m in cleaned) {
    final key = _normalizeKey(m.name);
    if (seen.add(key)) dedup.add(m);
  }

  // 3) trie léger (kcal décroissant → items “parlants” en premier)
  dedup.sort((a, b) => ((b.calories ?? 0).compareTo(a.calories ?? 0)));

  return dedup;
}

String _normalizeKey(String s) {
  final lower = s.toLowerCase();
  // simple normalisation: supprime ponctuation/espaces multiples
  return lower.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}
Widget _buildAddedFoodsSection(
  BuildContext context, {
  required List<Meal> meals,
  required void Function(Meal meal) onRemove,
  required void Function(Meal meal, double newQty) onQtyChange,
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
                return Dismissible(
                  key: ValueKey("${m.name}-${m.quantity}-${i}"),
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
                  child: _AddedFoodTilePretty(
                    meal: m,
                    onRemove: () => onRemove(m),
                    onQtyChange: (q) => onQtyChange(m, q),
                  ),
                );
              },
            ),

          if (meals.isNotEmpty) ...[
            const SizedBox(height: 10),
            _TotalsBar(
              calories: meals.fold<double>(0, (a, b) => a + (b.calories ?? 0)),
              prot:     meals.fold<double>(0, (a, b) => a + (b.protein  ?? 0)),
              carbs:    meals.fold<double>(0, (a, b) => a + (b.carbs    ?? 0)),
              fat:      meals.fold<double>(0, (a, b) => a + (b.fat      ?? 0)),
            ),
          ],
        ],
      ),
    ),
  );
}

class _AddedFoodTilePretty extends StatelessWidget {
  final Meal meal;
  final VoidCallback onRemove;
  final void Function(double newQty) onQtyChange;

  const _AddedFoodTilePretty({
    required this.meal,
    required this.onRemove,
    required this.onQtyChange,
  });

  @override
  @override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  final kcal = (meal.calories ?? 0).toDouble();
  final q = (meal.quantity ?? 100).toDouble();

  return Container(
    decoration: BoxDecoration(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: cs.outlineVariant),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ligne 1 : vignette + titre + supprimer
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumb(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.name.cap(max: 30),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: theme.textTheme.bodySmall,

                  ),
                  const SizedBox(height: 2),
                  // macros + kcal en dessous, petite typo
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text("${kcal.toStringAsFixed(0)} kcal",
                          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      _MiniBadge(text: "P ${(meal.protein ?? 0).toStringAsFixed(0)}g"),
                      _MiniBadge(text: "G ${(meal.carbs   ?? 0).toStringAsFixed(0)}g"),
                      _MiniBadge(text: "L ${(meal.fat     ?? 0).toStringAsFixed(0)}g"),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: "Supprimer",
              icon: const Icon(Icons.close),
              onPressed: onRemove,
            ),
          ],
        ),

        const SizedBox(height: 8),
        // ─── trait séparateur au-dessus des boutons ───
        Divider(height: 12, thickness: 0.6, color: cs.outlineVariant),

        // Ligne 2 : boutons ± (petits) + quantité
        Row(
          children: [
            // – 10
            _RoundIconSmall(
              onTap: () {
                final current = (meal.quantity ?? 0).toDouble();
                final double nq = (current - 10).clamp(0.0, 999999.0).toDouble();
                onQtyChange(nq);
              },
              icon: Icons.remove,
              bg: cs.surfaceContainerHigh,
              fg: cs.onSurface,
            ),
            const SizedBox(width: 8),
            // + 10
            _RoundIconSmall(
              onTap: () {
                final current = (meal.quantity ?? 0).toDouble();
                final double nq = (current + 10).clamp(0.0, 999999.0).toDouble();
                onQtyChange(nq);
              },
              icon: Icons.add,
              bg: cs.primary,
              fg: cs.onPrimary,
            ),
            const Spacer(),
            Text("${q.toStringAsFixed(0)} g", style: theme.textTheme.labelLarge),
          ],
        ),
      ],
    ),
  );
}

}

class _QtyStepperTiny extends StatelessWidget {
  final VoidCallback onDown;
  final VoidCallback onUp;
  const _QtyStepperTiny({required this.onDown, required this.onUp});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        _RoundIcon(onTap: onDown, icon: Icons.remove, bg: cs.surfaceContainerHigh, fg: cs.onSurface),
        const SizedBox(width: 6),
        _RoundIcon(onTap: onUp, icon: Icons.add, bg: cs.primary, fg: cs.onPrimary),
      ],
    );
  }
}
class _RoundIconSmall extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color bg;
  final Color fg;
  final double size; // diamètre

  const _RoundIconSmall({
    required this.onTap,
    required this.icon,
    required this.bg,
    required this.fg,
    this.size = 28, // ← plus petit qu'avant
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: size / 2 + 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: fg, size: size * 0.6),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color bg;
  final Color fg;
  const _RoundIcon({required this.onTap, required this.icon, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: fg, size: 18),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  const _MiniBadge({required this.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: cs.onSecondaryContainer)),
    );
  }
}

class _Thumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.restaurant, color: cs.onPrimaryContainer),
    );
  }
}

class _TotalsBar extends StatelessWidget {
  final double calories, prot, carbs, fat;
  const _TotalsBar({required this.calories, required this.prot, required this.carbs, required this.fat});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.summarize, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text("Total", style: theme.textTheme.titleSmall)),
          Text("${calories.toStringAsFixed(0)} kcal"),
          const SizedBox(width: 10),
          _MiniBadge(text: "P ${prot.toStringAsFixed(0)}g"),
          const SizedBox(width: 4),
          _MiniBadge(text: "G ${carbs.toStringAsFixed(0)}g"),
          const SizedBox(width: 4),
          _MiniBadge(text: "L ${fat.toStringAsFixed(0)}g"),
        ],
      ),
    );
  }
}
