import 'package:flutter/material.dart';
import '../models/meal.dart';

class MealSummaryPage extends StatelessWidget {
  final List<Meal> meals;

  const MealSummaryPage({super.key, required this.meals});

  // ✅ On met à jour la méthode pour qu'elle puisse calculer tous les nutriments
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
      // ✅ Ajout du calcul pour les graisses saturées
      case 'fatSaturated':
        return meals.fold(0.0, (sum, meal) => sum + (meal.fatSaturated ?? 0.0));
      default:
        return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 1. On calcule les totaux nécessaires
    final totalFat = _calculateTotal('fat');
    final totalSaturatedFat = _calculateTotal('fatSaturated');

    // ✅ 2. On calcule le pourcentage (en évitant la division par zéro)
    final saturatedFatPercentage = totalFat > 0 ? (totalSaturatedFat / totalFat) * 100 : 0.0;

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
                      "${meal.quantity.toStringAsFixed(0)}g - ${meal.calories.toStringAsFixed(0)} kcal\n"
                      "P: ${meal.protein.toStringAsFixed(1)}g | "
                      "G: ${meal.carbs.toStringAsFixed(1)}g | "
                      "L: ${meal.fat.toStringAsFixed(1)}g (dont sat. ${(meal.fatSaturated ?? 0).toStringAsFixed(1)}g)",
                    ),
                    trailing: Text(meal.type),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text("Totaux nutritionnels :", style: Theme.of(context).textTheme.titleMedium),
            Text("Calories : ${_calculateTotal('calories').toStringAsFixed(0)} kcal"),
            Text("Protéines : ${_calculateTotal('protein').toStringAsFixed(1)} g"),
            Text("Glucides : ${_calculateTotal('carbs').toStringAsFixed(1)} g"),
            // ✅ 3. On met à jour l'affichage des lipides avec le pourcentage
            Text("Lipides : ${totalFat.toStringAsFixed(1)} g (${saturatedFatPercentage.toStringAsFixed(0)}% saturés)"),
          ],
        ),
      ),
    );
  }
}