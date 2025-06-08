import 'package:flutter/material.dart';
import '../services/fonctions.dart';  // Importer la fonction getShortenedName

class MealSummaryPage extends StatelessWidget {
  final List<Map<String, dynamic>> meals;

  const MealSummaryPage({super.key, required this.meals});

  // Calcul des totaux pour chaque nutriment
  double _calculateTotal(String nutrient) {
    return meals.fold(0.0, (sum, meal) {
      return sum + meal[nutrient];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Synthèse des repas'),
      ),
      body: SingleChildScrollView(  // Ajout du scroll vertical
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre de la page
            Text(
              'Synthèse des repas',
              style: Theme.of(context).textTheme.headlineMedium, // Style headline pour une meilleure lisibilité
            ),
            const SizedBox(height: 16),
            
            // Tableau des repas avec un défilement horizontal
            SingleChildScrollView(
              scrollDirection: Axis.horizontal, // Permet de défiler horizontalement si nécessaire
              child: DataTable(
                columnSpacing: 10.0,  // Espace entre les colonnes
                headingRowHeight: 30.0,  // Hauteur des entêtes
                dataRowHeight: 30.0,  // Hauteur des données
                columns: [
                  DataColumn(
                    label: Text(
                      'Nom',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), // Taille de police réduite
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Kcal',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Prot. (g)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Gluc. (g)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Grais. (g)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: meals.map((meal) {
                  return DataRow(cells: [
                    DataCell(Text(
                      getShortenedName(meal['name'], wordCount: 3), // Réduction du nom avec 3 mots max
                      overflow: TextOverflow.ellipsis, // Réduit le texte en cas de débordement
                      maxLines: 1, // Limite le texte à une seule ligne
                      style: TextStyle(fontSize: 12), // Taille de la police réduite
                    )),
                    DataCell(Text(
                      meal['calories'].toStringAsFixed(1),
                      style: TextStyle(fontSize: 12), // Taille de la police réduite
                    )),
                    DataCell(Text(
                      meal['protein'].toStringAsFixed(1),
                      style: TextStyle(fontSize: 12), // Taille de la police réduite
                    )),
                    DataCell(Text(
                      meal['carbs'].toStringAsFixed(1),
                      style: TextStyle(fontSize: 12), // Taille de la police réduite
                    )),
                    DataCell(Text(
                      meal['fat'].toStringAsFixed(1),
                      style: TextStyle(fontSize: 12), // Taille de la police réduite
                    )),
                  ]);
                }).toList(),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Total des nutriments avec un Wrap pour éviter l'overflow horizontal
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('🔥 ${_calculateTotal("calories").toStringAsFixed(1)} kcal',
                    style: TextStyle(fontSize: 12)),
                Text('🍗 ${_calculateTotal("protein").toStringAsFixed(1)} g',
                    style: TextStyle(fontSize: 12)),
                Text('🍞 ${_calculateTotal("carbs").toStringAsFixed(1)} g',
                    style: TextStyle(fontSize: 12)),
                Text('🥑 ${_calculateTotal("fat").toStringAsFixed(1)} g',
                    style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
