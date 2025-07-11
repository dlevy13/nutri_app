import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/meal_database_service.dart';
import '../services/search_api_service.dart';

import 'meal_summary_page.dart';
import 'package:intl/intl.dart';
import '../log.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show compute;
import 'dart:async'; // pour Timer
import '../widget/food_search_field.dart';
import 'package:nutri_app/models/meal.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_config.dart'; 
import 'package:hive/hive.dart';
// importe le fichier ci-dessus

//import '../widget/create_food_button.dart';

class MealInputPage extends StatefulWidget {
  final String selectedDate;
  const MealInputPage({super.key, required this.selectedDate});

  @override
  State<MealInputPage> createState() => _MealInputPageState();
}

class _MealInputPageState extends State<MealInputPage> {
  List<Meal> selectedFoods = [];

  List<dynamic> foodList = [];
 
  List<dynamic> suggestions = [];
  List<Meal> mostFrequentSuggestions = [];
  String search = "";
  String selectedMealType = "Petit-déjeuner";
 final dbService = MealDatabaseService(Hive.box<Meal>('meals'));

    
  bool isLoading = false;
  DateTime selectedDate = DateTime.now();
  Timer? _debounce;
  bool isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.parse(widget.selectedDate);
    _loadFoodData();
    //dbService.init().then((_) => _loadMealsFromDatabase());
    dbService.getMostFrequentMealsByType(selectedMealType).then((meals) {
       setState(() {
       mostFrequentSuggestions = meals;
  });
});

  }

  Future<void> _loadFoodData() async {
    final customFoods = await dbService.getCustomFoods();
    setState(() {
      foodList = customFoods; // Charger les aliments personnalisés
    });
  }

 Future<void> _addFood(dynamic food, double quantity) async {
  logger.d("🧪 Type de food : ${food.runtimeType}");

  final date = DateFormat('yyyy-MM-dd').format(selectedDate);

  final String name = food is Meal ? food.name : (food['name'] ?? '');
  final double baseCalories = food is Meal ? food.calories : (food['calories'] ?? 0).toDouble();
  final double baseProtein  = food is Meal ? food.protein  : (food['protein'] ?? 0).toDouble();
  final double baseCarbs    = food is Meal ? food.carbs    : (food['carbs'] ?? 0).toDouble();
  final double baseFat      = food is Meal ? food.fat      : (food['fat'] ?? 0).toDouble();

  final calories = baseCalories * quantity / 100;
  final protein = baseProtein * quantity / 100;
  final carbs = baseCarbs * quantity / 100;
  final fat = baseFat * quantity / 100;

  await dbService.addMeal(
    name: name,
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
    quantity: quantity,
    mealType: selectedMealType,
    date: date,
  );
}


  Future<void> _loadMealsFromDatabase() async {
    setState(() {
      isLoading = true;
    });
  //final date = DateFormat('yyyy-MM-dd').format(selectedDate); //pour tester la date
  //logger.d("Chargement des repas pour la date : $date");
    final meals = await dbService.getMeals(
      mealType: selectedMealType,
      date: DateFormat('yyyy-MM-dd').format(selectedDate),
    );

    setState(() {
      selectedFoods = meals;
      isLoading = false;
    });
  }

  Future<void> _removeFood(Meal meal) async {
  setState(() {
    isLoading = true;
  });

  await meal.delete(); // supprimé directement
  await _loadMealsFromDatabase();

  setState(() {
    isLoading = false;
  });
}


  Future<void> _resetDatabase() async {
    try {
      setState(() {
        isLoading = true;
      });

      await dbService.deleteDatabaseFile();
      //await dbService.init();
      await _loadMealsFromDatabase();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      logger.d("Erreur lors de la réinitialisation de la base de données : $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  double get totalCalories => selectedFoods.fold(0.0, (sum, f) => sum + f.calories);
  double get totalProteins => selectedFoods.fold(0.0, (sum, f) => sum + f.protein);
  double get totalCarbs => selectedFoods.fold(0.0, (sum, f) => sum + f.carbs);
  double get totalFats => selectedFoods.fold(0.0, (sum, f) => sum + f.fat);


  void _showCreateFoodDialog(BuildContext context, String nameSuggestion) {
    final nameController = TextEditingController(text: nameSuggestion);
    final calController = TextEditingController();
    final protController = TextEditingController();
    final carbController = TextEditingController();
    final fatController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Créer un aliment"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: "Nom")),
              TextField(controller: calController, decoration: const InputDecoration(labelText: "Calories / 100g"), keyboardType: TextInputType.number),
              TextField(controller: protController, decoration: const InputDecoration(labelText: "Protéines / 100g"), keyboardType: TextInputType.number),
              TextField(controller: carbController, decoration: const InputDecoration(labelText: "Glucides / 100g"), keyboardType: TextInputType.number),
              TextField(controller: fatController, decoration: const InputDecoration(labelText: "Lipides / 100g"), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
            final newMeal = Meal(
              name: nameController.text,
              calories: double.tryParse(calController.text) ?? 0,
              protein: double.tryParse(protController.text) ?? 0,
              carbs: double.tryParse(carbController.text) ?? 0,
              fat: double.tryParse(fatController.text) ?? 0,
              quantity: 1,
              type: selectedMealType,
              date: DateFormat('yyyy-MM-dd').format(selectedDate),
            );

            // Étape 1 : ajouter le repas

            await dbService.addCustomFood(newMeal);

            // Vérifie si le widget est encore monté
            if (!mounted) return;

            // Étape 2 : recharger les données
            await _loadMealsFromDatabase();

            // Vérifie encore une fois si le widget est monté
            if (!mounted) return;

            // Étape 3 : fermeture de la page
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },

            child: const Text("Créer"),
          ),
        ],
      ),
    );
  }

  Future<void> _searchFoodLocally(String searchQuery) async {
  if (_debounce?.isActive ?? false) _debounce!.cancel();

  _debounce = Timer(const Duration(milliseconds: 100), () async {
    if (searchQuery.length < 3) {
      if (!mounted) return;
      setState(() {
        suggestions = [];
        isSearching = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
    });

    try {
      final lowerQuery = searchQuery.toLowerCase();

      /// 1. Cherche dans custom_foods
      final customResults = await dbService.searchFoods(searchQuery);
      if (customResults.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          suggestions = customResults;
          isSearching = false;
        });
        return;
      }

      /// 2. Cherche dans JSON local
      final data = await rootBundle.loadString('assets/food_data.json');
      final jsonList = jsonDecode(data);

      final List<Map<String, dynamic>> localResults = jsonList
          .whereType<Map<String, dynamic>>()
          .where((food) => food['name'] != null)
          .toList();

      localResults.sort((a, b) {
        final nameA = (a['name'] as String).toLowerCase();
        final nameB = (b['name'] as String).toLowerCase();
        final startsWithA = nameA.startsWith(lowerQuery) ? 0 : 1;
        final startsWithB = nameB.startsWith(lowerQuery) ? 0 : 1;
        return startsWithA.compareTo(startsWithB);
      });

      final filteredResults = localResults
          .where((food) => (food['name'] as String).toLowerCase().contains(lowerQuery))
          .toList();

      if (!mounted) return;
      setState(() {
        suggestions = filteredResults;
        isSearching = false;
      });

    } catch (e) {
      logger.d("Erreur recherche locale : $e");
      if (!mounted) return;
      setState(() {
        suggestions = [];
        isSearching = false;
      });
    }
  });
}

/// 3. Cherche dans API


// 2) Requête avec compute




Future<void> _searchFoodFromAPIButton() async {
  if (search.length < 3 || isSearching) return;
  setState(() => isSearching = true);

  try {
    final apiResults = await searchFoodOnAPI(search);

    if (apiResults.isNotEmpty) {
      // 4) Insertion en parallèle pour gagner du temps
      await Future.wait(apiResults.map((foodMap) {
        final meal = Meal.fromMap(foodMap);
        return dbService.addCustomFood(meal);
      }));

      // 5) Puis on recharge les suggestions locales
      await _searchFoodLocally(search);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aliments ajoutés depuis Internet !")),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aucun aliment trouvé via Internet.")),
        );
      }
    }
  } catch (e, st) {
    logger.d("Erreur API: $e\n$st");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la recherche Internet.")),
      );
    }
  } finally {
    if (mounted) setState(() => isSearching = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Saisie des repas"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : () async {
              await _resetDatabase();
            },
          ),
        ],
      ),
      
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Date sélectionnée : ${widget.selectedDate}",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      const SizedBox(height: 20),
                        Row(
                          children: [
                            DropdownButton<String>(
                              value: selectedMealType,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    selectedMealType = value;
                                  });
                                  _loadMealsFromDatabase();
                                  dbService.getMostFrequentMealsByType(value).then((meals) {
                                    setState(() {
                                      mostFrequentSuggestions = meals;
                                    });
                                  });
                                }
                              },
                              items: ["Petit-déjeuner", "Déjeuner", "Dîner", "Collation"]
                                  .map((value) => DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Champ de recherche
                        FoodSearchField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              search = value;
                              _searchFoodLocally(search);
                            });
                          },
                          onClear: () {
                            _searchController.clear();
                            setState(() {
                              search = '';
                              suggestions = [];
                            });
                          },
                        ),
                        if (mostFrequentSuggestions.isNotEmpty && search.length < 3)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Card(
                              color: Colors.green.shade50,
                              elevation: 3,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("💡 Suggestions fréquentes",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                    const SizedBox(height: 8),
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: mostFrequentSuggestions.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (_, i) {
                                        final meal = mostFrequentSuggestions[i];
                                        return ListTile(
                                          title: Text(meal.name),
                                          subtitle: Text("${meal.calories} kcal / 100g"),
                                          trailing: const Icon(Icons.add_circle_outline, color: Colors.green),
                                          onTap: () async {
                                            final result = await _showQuantityDialog(context, meal.toMap());
                                            if (result == true) {
                                              await _loadMealsFromDatabase();
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        if (isSearching)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          if (!isSearching && search.length >= 3 && suggestions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    // BOUTON "Créer cet aliment" (ORANGE)
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        _showCreateFoodDialog(context, search);
                                      },
                                      icon: const Icon(Icons.add_circle_outline),
                                      label: const Text("Créer cet aliment"),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(double.infinity, 48),
                                        backgroundColor: Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // BOUTON "Rechercher sur Internet" (BLEU)
                                    ElevatedButton.icon(
                                      onPressed: isSearching ? null : _searchFoodFromAPIButton,
                                      icon: isSearching
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Icon(Icons.cloud_download),
                                      label: Text(isSearching ? "Recherche..." : "Rechercher sur Internet"),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(double.infinity, 48),
                                        backgroundColor: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),


                      ],
                    ),
                  ),

                  // Suggestions de recherche
                  if (search.length >= 3 && suggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Card(
                        color: Colors.blue.shade50,
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("🔍 Suggestions",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(height: 8),
                              ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: suggestions.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final suggestion = suggestions[i];

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    suggestion is Meal ? suggestion.name : suggestion['name'],
                                  ),
                                  subtitle: Text(
                                    suggestion is Meal
                                        ? "${suggestion.calories} kcal / 100g"
                                        : "${suggestion['calories']} kcal / 100g",
                                  ),
                                  trailing: const Icon(Icons.add_circle_outline, color: Colors.green),
                                  onTap: () async {
                                    final item = suggestions[i]; // ou ton élément dans la liste
                                    final food = item is Meal ? item.toMap() : item;
                                    
                                    final result = await _showQuantityDialog(context, food);

                                    if (result == true) {
                                      await _loadMealsFromDatabase();
                                    }
                                    setState(() {
                                      search = "";
                                      suggestions = [];
                                    });
                                  },
                                );
                              },
                            ),

                            ],
                          ),
                        ),
                      ),
                    ),

                  // Liste des aliments ajoutés
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "🥘 Aliments ajoutés",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          if (selectedFoods.isNotEmpty) ...[
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: selectedFoods.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final meal = selectedFoods[i];
                                return ListTile(
                                  title: Text(meal.name),
                                  subtitle: Text("${meal.quantity}g - ${meal.calories} kcal"),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeFood(meal),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.summarize),
                              label: const Text('Synthèse du repas'),
                              
                              onPressed: () {
                              
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MealSummaryPage(meals: selectedFoods),
                                ),
                              );

                            },
                            ),
                          ] else
                            const Text("Aucun aliment ajouté. Ajoutez-en un !"),
                        ],
                      ),
                    ),
                  ),
                ),

                ],
              ),
            ),
    );
  }

  Future<bool?> _showQuantityDialog(BuildContext context, Map<String, dynamic> food) {
  final quantityController = TextEditingController(text: "100");

  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text("Ajouter ${food['name']}"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Calories : ${food['calories']} kcal / 100g"),
          const SizedBox(height: 12),
          TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Quantité (g)",
              hintText: "100g",
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // ⛔ annulation = null
          child: const Text("Annuler"),
        ),
        ElevatedButton(
          onPressed: () async {
            final quantityText = quantityController.text;
            final parsedQuantity = double.tryParse(quantityText);

            if (parsedQuantity != null && parsedQuantity > 0) {
              await _addFood(food, parsedQuantity);
              await _loadMealsFromDatabase();
              Navigator.pop(context, true); // ✅ on retourne true
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Veuillez entrer une quantité valide.")),
              );
            }
          },
          child: const Text("Ajouter"),
        ),
      ],
    ),
  );
}

}
