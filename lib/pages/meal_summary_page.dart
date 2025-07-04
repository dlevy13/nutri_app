import 'package:flutter/material.dart';
import '../models/meal.dart';
import '../services/fonctions.dart';  // si getShortenedName est toujours utile

class MealSummaryPage extends StatelessWidget {
  final List<Meal> meals;

  const MealSummaryPage({super.key, required this.meals});

  // Calcul des totaux pour chaque nutriment
  double _calculateTotal(String nutrient) {
    switch (nutrient) {
      case 'calories':
        return meals.fold(0.0, (sum, meal) => sum + meal.calories);
      case 'protein':
        return meals.fold(0.0, (sum, meal) => sum + meal.protein);
      case 'carbs':
        return meals.fold(0.0, (sum, meal) => sum + meal.carbs);
      case 'fat':
        return meals.fold(0.0, (sum, meal) => sum + meal.fat);
      default:
        return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Synthèse des repas')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Synthèse des repas', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: meals.length,
              itemBuilder: (context, index) {
                final meal = meals[index];
                return Card(
                  child: ListTile(
                    title: Text(meal.name),
                    subtitle: Text(
                      "${meal.quantity}g - ${meal.calories.toStringAsFixed(1)} kcal\n"
                      "P: ${meal.protein.toStringAsFixed(1)}g | "
                      "G: ${meal.carbs.toStringAsFixed(1)}g | "
                      "L: ${meal.fat.toStringAsFixed(1)}g",
                    ),
                    trailing: Text(meal.type),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text("Totaux nutritionnels :", style: Theme.of(context).textTheme.titleMedium),
            Text("Calories : ${_calculateTotal('calories').toStringAsFixed(1)} kcal"),
            Text("Protéines : ${_calculateTotal('protein').toStringAsFixed(1)} g"),
            Text("Glucides : ${_calculateTotal('carbs').toStringAsFixed(1)} g"),
            Text("Lipides : ${_calculateTotal('fat').toStringAsFixed(1)} g"),
          ],
        ),
      ),
    );
  }
}
