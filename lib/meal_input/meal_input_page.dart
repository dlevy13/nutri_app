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
import '../services/decomposition_service.dart';
import '../models/proposed_ingredient.dart';
import '../widget/decomposition_review_sheet.dart';



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
  final _decompCtrl = TextEditingController();
  final _decompSvc  = DecompositionService();
  
  List<AlimentUsuel> alimentsUsuels = [];


@override
  void initState() {
    super.initState(); 
    // On appelle la méthode de chargement ici
    _loadAlimentsUsuels();
  }

  @override
  void dispose() {
  _searchController.dispose();
  _decompCtrl.dispose(); // ✅ important
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
    // 1) Appel API
    final data = await _decompSvc.decompose(description);
    final items = (data["ingredients"] as List)
        .map((e) => ProposedIngredient.fromJson(e as Map<String, dynamic>))
        .toList();

    if (!mounted) return;

    // 2) Récupère notifier + type courant depuis Riverpod
    final provider = mealInputProvider((widget.mealType, widget.selectedDate));
    final notifier = ref.read(provider.notifier);
    final selectedMealType = ref.read(provider).selectedMealType; // suit ton Dropdown du haut

    // 3) Ouvre le sheet (on lui passe le notifier)
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DecompositionReviewSheet(
        items: items,
        mealType: selectedMealType, // "Petit-déjeuner"/"Déjeuner"/...
        notifier: notifier,
      ),
    );

    // 4) Rafraîchir l’UI si on a enregistré
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
          // ⬇️⬇️⬇️ AJOUTE ICI LA CARTE DECOMPOSITION
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

                  // Champ de description avec croix pour effacer
                  TextField(
                    controller: _decompCtrl,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "ex. bol de chili con carne avec riz",
                      border: const OutlineInputBorder(),
                      suffixIcon: _decompCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _decompCtrl.clear();
                                setState(() {}); // 🔄 force le rebuild pour cacher la croix
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}), // 🔄 affiche la croix dès qu’il y a du texte
                    onSubmitted: (_) => onDecompose(),
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

  // ⬆️⬆️⬆️ FIN DU BLOC DECOMPOSITION
          // 🔎 Recherche d’aliments harmonisée
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
            setState(() {}); // pour cacher la croix
          },
        ),
      ],
    ),
  ),
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
              onQtyChange: (meal, q) => notifier.updateFoodQuantity(meal, q),
              alimentsUsuels: alimentsUsuels,
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
                              : () => notifier.searchFood(_searchController.text),
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
    //**************** */
           

            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (theme.textTheme.bodyMedium?.fontSize ?? 14) *
                          (theme.textTheme.bodyMedium?.height ?? 1.2) *
                          15, // 🔹 15 lignes
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  primary: false,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final meal = filtered[i];
                    final p100 = per100From(meal);
                    return _SuggestionMealCardCompact(
                      meal: meal,
                      kcalPer100: p100.kcal,
                      proteinPer100: p100.pro,
                      carbsPer100: p100.carb,
                      fatPer100: p100.fat,
                      onAdd: () => _showQuantityDialog(meal, notifier),
                    );
                  },
                ),
              ),
            )



  //**************** */
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
          final isCustom = foodData['isCustom'] == true;
          final nutriments = foodData['nutriments'] as Map<String, dynamic>? ?? {};
          final calories = nutriments['energy-kcal_100g'] as num? ?? 0.0;
          return ListTile(
            leading: isCustom ? const Icon(Icons.star, color: Colors.amber) : null,
            title: Text(name),
            subtitle: Text("${calories.toStringAsFixed(0)} kcal / 100g • ${source.toUpperCase()}"),
            trailing: const Icon(Icons.add_circle_outline),
            onTap: () {
              _showQuantityDialog(foodData, notifier);
            },
          );
        }),
     ];
  }
  

  /// Affiche le dialogue pour entrer la quantité

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
  final String name = foodData is Meal
      ? foodData.name
      : ((foodData['name'] ?? foodData['product_name']) as String? ?? 'Aliment');

  // 1) Récupère une unité/usuel si dispo
  final AlimentUsuel? refAliment = _getPoidsUsuel(name);
  final List<UsualUnit> usualUnits = [];
  if (refAliment != null && refAliment.poids > 0) {
    usualUnits.add(UsualUnit(
      label: refAliment.unite,
      gramsPerUnit: refAliment.poids.toDouble(),
    ));
  }

  // 2) Valeur par défaut : 1 unité si dispo, sinon 100 g
  final double defaultGrams =
      usualUnits.isNotEmpty ? usualUnits.first.gramsPerUnit : (refAliment?.poids.toDouble() ?? 100.0);

  if (!mounted) return;

  // 3) Ouvre la page quantité
  final resultInGrams = await Navigator.of(context).push<double>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _QuantityPage(
        title: "Quantité pour '$name'",
        unite: 'g',
        defaultValue: defaultGrams,
        usualUnits: usualUnits,
      ),
    ),
  );

  // 4) Ajout (normalisation /100 g gérée dans MealInputNotifier.addFood)
  if (resultInGrams != null && mounted) {
    await notifier.addFood(foodData, resultInGrams);

    // Nettoyage de la recherche
    _searchController.clear();
    notifier.clearSearch();
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
// Optionnel : simple POJO si pas déjà défini chez toi
class UsualUnit {
  final String label;        // ex. "morceau", "tranche", "càs"
  final double gramsPerUnit; // ex. 12.0
  const UsualUnit({required this.label, required this.gramsPerUnit});
}

// --- ton widget (ajouts marqués "🔹") ---

class _QuantityPage extends StatefulWidget {
  const _QuantityPage({
    super.key,
    required this.title,
    required this.unite,          // ex. "g" (toujours utilisé comme libellé quand pas d’unités usuelles)
    required this.defaultValue,   // en GRAMMES
    this.usualUnits = const [],   // 🔹 liste d’unités usuelles (facultatif)
    this.initialUnitIndex = 0,    // 🔹 si plusieurs unités, laquelle sélectionner par défaut
  });

  final String title;
  final String unite;
  final double defaultValue;          // toujours en grammes
  final List<UsualUnit> usualUnits;   // 🔹
  final int initialUnitIndex;         // 🔹

  @override
  State<_QuantityPage> createState() => _QuantityPageState();
}

class _QuantityPageState extends State<_QuantityPage> {
  late final TextEditingController _controller;
  double _value = 0; // en grammes
  int _unitIndex = 0; // 🔹 index unité usuelle sélectionnée

  bool get _hasUsualUnits => widget.usualUnits.isNotEmpty;                // 🔹
  UsualUnit get _unit => widget.usualUnits[_unitIndex];                   // 🔹
  double get _gramsPerUnit => _hasUsualUnits ? _unit.gramsPerUnit : 1.0;  // 🔹

  @override
  void initState() {
    super.initState();
    _value = widget.defaultValue; // en grammes
    _controller = TextEditingController(text: _fmt(_value));
    final maxIndex = widget.usualUnits.isNotEmpty ? widget.usualUnits.length - 1 : 0;
      _unitIndex = _hasUsualUnits
       ? widget.initialUnitIndex.clamp(0, maxIndex)
        : 0;
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

  // 🔹 nudge “générique” : en grammes si pas d’unités usuelles ; sinon en unités usuelles (converti en grammes)
  void _nudgeGeneric(double step) {
    if (_hasUsualUnits) {
      // step est en unités → converti en grammes
      _setValue(_value + step * _gramsPerUnit);
    } else {
      // step est en grammes
      _setValue(_value + step);
    }
  }

  void _submit() => Navigator.of(context).pop(_value); // on renvoie des grammes

  // Récupère le nom d'aliment depuis le title "Quantité pour 'xxx'"
  String get _foodName {
    final t = widget.title;
    if (t.contains("'")) {
      final parts = t.split("'");
      if (parts.length >= 2) return parts[1];
    }
    return t;
  }

  // 🔹 suggestions adaptées : si unités usuelles → en unités [1,2,3,5], sinon grammes (comme avant)
  List<double> _suggestions() {
    if (_hasUsualUnits) {
      const units = [1, 2, 3, 5];
      return units.map((u) => u * _gramsPerUnit).toList(); // retourne des grammes (valeur interne)
    }
    final base = <double>{widget.defaultValue, 50, 100, 150, 200};
    final list = base.where((e) => e > 0).toList()..sort();
    return list;
  }

  String _suggestionLabel(double grams) {
    if (_hasUsualUnits) {
      final u = (grams / _gramsPerUnit);
      final uInt = u.round();
      // On affiche “<unité> x N (~Y g)”
      return "${_unit.label} x $uInt (~${_fmt(grams)} g)";
    }
    return "${_fmt(grams)} ${widget.unite}";
  }

  // 🔹 compteur en unités usuelles (arrondi)
  int get _currentUnits => _hasUsualUnits ? (_value / _gramsPerUnit).round() : 0;

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
              // Nom aliment
              Text(
                _foodName,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                maxLines: 3,
                softWrap: true,
              ),
              const SizedBox(height: 8),

              // 🔹 Si plusieurs unités usuelles, sélecteur
              if (_hasUsualUnits && widget.usualUnits.length > 1) ...[
                DropdownButton<int>(
                  value: _unitIndex,
                  items: List.generate(widget.usualUnits.length, (i) {
                    final u = widget.usualUnits[i];
                    return DropdownMenuItem<int>(
                      value: i,
                      child: Text("${u.label} (~${_fmt(u.gramsPerUnit)} g)"),
                    );
                  }),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _unitIndex = v);
                  },
                ),
                const SizedBox(height: 8),
              ],

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
                          autofocus: true,
                          onChanged: (s) => _setValue(_parse(s)), // toujours des grammes
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
                      // 🔹 libellé à droite : “g” si pas d’unités usuelles, sinon “≈ X u”
                      if (_hasUsualUnits)
                        Text("≈ ${_currentUnits} ${_unit.label}${_currentUnits > 1 ? 's' : ''}",
                            style: theme.textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant))
                      else
                        Text(widget.unite, style: theme.textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Stepper compact
              if (_hasUsualUnits) ...[
                // 🔹 uniquement –1 / +1 “unité”
                Row(
                  children: [
                    _MiniBtn(label: "-1 ${_unit.label}", onTap: () => _nudgeGeneric(-1)),
                    const Spacer(),
                    _MiniBtn(label: "+1 ${_unit.label}", onTap: () => _nudgeGeneric(1), filled: true),
                  ],
                ),
              ] else ...[
                // fallback grammes (ton stepper actuel)
                Row(
                  children: [
                    _MiniBtn(label: "-10", onTap: () => _nudgeGeneric(-10)),
                    const SizedBox(width: 6),
                    _MiniBtn(label: "-1", onTap: () => _nudgeGeneric(-1)),
                    const Spacer(),
                    _MiniBtn(label: "+1", onTap: () => _nudgeGeneric(1), filled: true),
                    const SizedBox(width: 6),
                    _MiniBtn(label: "+10", onTap: () => _nudgeGeneric(10), filled: true),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              // Chips suggestions — adaptées
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _suggestions().map((grams) {
                  final selected = (_value - grams).abs() < 0.0001;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(_suggestionLabel(grams)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (_) => _setValue(grams),
                    selectedColor: cs.primaryContainer,
                    labelStyle: TextStyle(color: selected ? cs.onPrimaryContainer : null, fontSize: 12),
                  );
                }).toList(),
              ),

              const Spacer(),

              // CTA
              SafeArea(
                top: false,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _hasUsualUnits
                        ? "Ajouter ~${_currentUnits} ${_unit.label}${_currentUnits > 1 ? 's' : ''} (${_fmt(_value)} g)"
                        : "Ajouter ${_fmt(_value)} ${widget.unite}",
                  ),
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
class _SuggestionMealCardCompact extends StatefulWidget {
  final Meal meal;
  final double kcalPer100;
  final double proteinPer100;
  final double carbsPer100;
  final double fatPer100;
  final VoidCallback onAdd;

  const _SuggestionMealCardCompact({
    super.key,
    required this.meal,
    required this.kcalPer100,
    required this.proteinPer100,
    required this.carbsPer100,
    required this.fatPer100,
    required this.onAdd,
  });

  @override
  State<_SuggestionMealCardCompact> createState() => _SuggestionMealCardCompactState();
}

class _SuggestionMealCardCompactState extends State<_SuggestionMealCardCompact> {
  bool _hovered = false;

  String _fmt(num x, {int d = 1}) => x.toStringAsFixed(d);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0.5,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onAdd, // ✅ tap sur toute la carte
        onHover: (v) => setState(() => _hovered = v), // hover desktop
        onFocusChange: (v) => setState(() => _hovered = v), // focus clavier
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LIGNE 1 : Nom + + vert à côté (réagit au hover/focus)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      widget.meal.name.cap(max: 35),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IgnorePointer(
                    ignoring: true, // n'intercepte pas le tap global
                    child: AnimatedScale(
                      scale: _hovered ? 1.12 : 1.0,
                      duration: const Duration(milliseconds: 130),
                      curve: Curves.easeOut,
                      child: Icon(
                        Icons.add,
                        size: 18,
                        color: _hovered ? Colors.green.shade700 : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // LIGNE 2 : kcal / 100 g
              Text(
                "${widget.kcalPer100.toStringAsFixed(0)} kcal / 100 g",
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),

              // LIGNE 3 : macros / 100 g
              Text(
                "${_fmt(widget.proteinPer100)} g P · "
                "${_fmt(widget.carbsPer100)} g G · "
                "${_fmt(widget.fatPer100)} g L / 100 g",
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _ChipStat extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ChipStat({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceContainerHigh,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14),
        const SizedBox(width: 4),
        Text(text, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}





// ⚠️ Conserve l'ordre d'entrée (donc la récence) et coupe à 15.
List<Meal> _filterSuggestions(List<Meal> items) {
  // 1) nettoie / filtre les fiches incohérentes
  final cleaned = items.where((m) {
    final name = (m.name).trim();
    final kcal = (m.calories ?? 0).toDouble();
    final p = (m.protein ?? 0).toDouble();
    final g = (m.carbs ?? 0).toDouble();
    final l = (m.fat ?? 0).toDouble();

    if (name.isEmpty) return false;
    if (!kcal.isFinite || kcal <= 0) return false; // exclut 0 kcal
    if (kcal > 1200) return false;                 // borne haute réaliste (≈/100g)
    if (p < 0 || g < 0 || l < 0 || p > 100 || g > 100 || l > 100) return false;
    if (p == 0 && g == 0 && l == 0) return false;  // évite fiches vides
    return true;
  });

  // 2) dédoublonne par nom "normalisé" en CONSERVANT le 1er (donc le plus récent)
  final seen = <String>{};
  final dedup = <Meal>[];
  for (final m in cleaned) {
    final key = _normalizeKey(m.name);
    if (seen.add(key)) dedup.add(m);
  }

  // 3) ❌ pas de tri → on garde l’ordre d’arrivée (récence) ; et on coupe à 15
  return dedup.take(15).toList();
}

// Helper robuste pour dédoublonner intelligemment
String _normalizeKey(String s) {
  var t = s.trim().toLowerCase();

  // enlève accents
  const withAccents = 'àâäáãåçéèêëíìîïñóòôöõúùûüŷýÿœæ';
  const noAccents   = 'aaaaaaceeeeiiiinooooouuuuyyyoeae';
  for (var i = 0; i < withAccents.length; i++) {
    t = t.replaceAll(withAccents[i], noAccents[i]);
  }

  // supprime ponctuation/espaces multiples
  t = t.replaceAll(RegExp(r'[^\w\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ');

  // singularise très léger (banal) – optionnel
  t = t.replaceAll(RegExp(r's\b'), '');

  return t;
}


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
final double? step  = refAl?.poids.toDouble(); // ex. 12.0 g par "morceau"
final String? label = refAl?.unite; 
                
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
                    unitStepGrams: step,
                    unitLabel: label,
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
  final double? unitStepGrams; 
  final String? unitLabel;  

  const _AddedFoodTilePretty({
    required this.meal,
    required this.onRemove,
    required this.onQtyChange,
    this.unitStepGrams,
    this.unitLabel,
  });

  @override

Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  final kcal = (meal.calories ?? 0).toDouble();
  final q = (meal.quantity ?? 100).toDouble();
  final double qty = (meal.quantity ?? 0).toDouble();
  final double step = (unitStepGrams ?? 10.0); // fallback 10 g si pas d’unité usuelle
  final int units = (unitStepGrams != null && unitStepGrams! > 0)
    ? (qty / unitStepGrams!).round()
    : 0;
  final String? label = unitLabel; // ex. "morceau"

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
              _RoundIconSmall(
                onTap: () {
                  final newQty = (qty - step).clamp(0.0, 999999.0);
                  onQtyChange(newQty);
                },
                icon: Icons.remove,
                bg: cs.surfaceContainerHigh,
                fg: cs.onSurface,
              ),
              const SizedBox(width: 8),
              _RoundIconSmall(
                onTap: () {
                  final newQty = (qty + step).clamp(0.0, 999999.0);
                  onQtyChange(newQty);
                },
                icon: Icons.add,
                bg: cs.primary,
                fg: cs.onPrimary,
              ),
              const Spacer(),
              Text(
                label != null
                ? "$units $label${units > 1 ? 's' : ''} (~${qty.toStringAsFixed(0)} g)"
                : "${qty.toStringAsFixed(0)} g",
                style: theme.textTheme.labelLarge,
              ),
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
AlimentUsuel? poidsUsuelForName(List<AlimentUsuel> base, String nom) {
      final lowerName = nom.trim().toLowerCase();
      if (base.isEmpty) return null;

      // Passe 1 : exact
      for (var a in base) {
        if (lowerName == a.aliment.trim().toLowerCase()) return a;
      }

      // Passe 2 : premier mot
      final firstWord = lowerName.split(' ').first;
      if (firstWord.isNotEmpty && firstWord != lowerName) {
        for (var a in base) {
          if (firstWord == a.aliment.trim().toLowerCase()) return a;
        }
      }

      // Passe 3 : meilleure partielle
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
