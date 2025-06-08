import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../services/meal_database_service.dart';

class MealInputPage extends StatefulWidget {
  const MealInputPage({super.key});

  @override
  State<MealInputPage> createState() => _MealInputPageState();
}

class _MealInputPageState extends State<MealInputPage> {
  List<dynamic> foodList = [];
  List<Map<String, dynamic>> selectedFoods = [];
  String search = "";
  String selectedMealType = "Petit-déjeuner";  // Par défaut, Petit-déjeuner
  DateTime selectedDate = DateTime.now(); // Définir une date par défaut (aujourd'hui)
  final dbService = MealDatabaseService();  // Instance de la classe MealDatabaseService
  bool isLoading = false;  // Déclaration de isLoading pour gérer l'état de chargement

  @override
  void initState() {
    super.initState();
    _loadFoodData();
    dbService.init().then((_) => _loadMealsFromDatabase());  // Initialisation de la base de données
  }

  Future<void> _loadFoodData() async {
    final data = await rootBundle.loadString('assets/food_data.json');
    setState(() {
      foodList = jsonDecode(data);
    });
  }

 Future<void> _addFood(Map<String, dynamic> food, double quantity) async {
  // Convertir selectedDate en String au format 'yyyy-MM-dd'
  String formattedDate = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

  // Extraire les données nécessaires depuis le Map food
  String name = food['name'] ?? '';
  double calories = (food['calories'] ?? 0) * quantity / 100;
  double protein = (food['proteins'] ?? 0) * quantity / 100;
  double carbs = (food['carbs'] ?? 0) * quantity / 100;
  double fat = (food['fats'] ?? 0) * quantity / 100;

  // Appeler la méthode addMeal avec des arguments individuels
  await dbService.addMeal(
    name,        // Nom de l'aliment
    calories,    // Calories
    protein,     // Protéines
    carbs,       // Glucides
    fat,         // Graisses
    quantity,    // Quantité
    selectedMealType,  // Type de repas
    formattedDate // Date formatée
  );

  _loadMealsFromDatabase();  // Recharger les repas après ajout
}


  Future<void> _loadMealsFromDatabase() async {
    setState(() {
      isLoading = true;  // Mettre isLoading à true pendant le chargement
    });

    // Convertir selectedDate en String au format 'yyyy-MM-dd'
    String formattedDate = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
    final meals = await dbService.getMeals(
      mealType: selectedMealType,
      date: formattedDate,  // Passer la date formatée
    );

    setState(() {
      selectedFoods = meals;
      isLoading = false;  // Mettre isLoading à false après le chargement
    });
  }

  Future<void> _removeFood(int id) async {
    await dbService.removeMeal(id);  // Supprimer un repas de la base de données
    _loadMealsFromDatabase();  // Recharger les repas depuis la base
  }

  void _resetDatabase() async {
    await dbService.resetDatabase();  // Appel de la méthode de réinitialisation
    _loadMealsFromDatabase();  // Recharger les repas depuis la base de données après la réinitialisation
  }

  @override
  Widget build(BuildContext context) {
    final filtered = foodList
        .where((f) => f['name'].toLowerCase().contains(search.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Saisie des repas"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _resetDatabase,  // Appel à la méthode de réinitialisation de la base de données
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())  // Afficher un indicateur de progression
          : SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Sélection du type de repas (Petit-déjeuner, Déjeuner, Dîner)
                        DropdownButton<String>(
                          value: selectedMealType,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedMealType = value;
                              });
                            }
                          },
                          items: [
                            "Petit-déjeuner",
                            "Déjeuner",
                            "Dîner",
                            "Collation"
                          ].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: "Rechercher un aliment",
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (value) {
                              search = value;
                              Future.delayed(const Duration(milliseconds: 300), () {
                                if (mounted) setState(() {});  // Simple debounce
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final food = filtered[i];
                      return ListTile(
                        title: Text(food['name']),
                        subtitle: Text("${food['calories']} kcal / 100g"),
                        trailing: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _showQuantityDialog(context, food),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text("Total : ${selectedFoods.fold(0.0, (sum, f) => sum + f["calories"]).toStringAsFixed(0)} kcal"),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: selectedFoods.length,
                            itemBuilder: (_, i) {
                              final food = selectedFoods[i];
                              return ListTile(
                                title: Text(food['name']),
                                subtitle: Text("${food['quantity']} g"),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: () => _removeFood(food['id']),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showQuantityDialog(BuildContext context, Map<String, dynamic> food) {
    final controller = TextEditingController(text: "100");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Quantité pour ${food["name"]}"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: "g"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              final quantity = double.tryParse(controller.text);
              if (quantity != null) {
                await _addFood(food, quantity);  // Ajouter un aliment avec la quantité
              }
              Navigator.pop(context);
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
  }
}
