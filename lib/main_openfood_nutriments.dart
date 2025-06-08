import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NutrientsPage extends StatefulWidget {
  final String barcode;

  const NutrientsPage({Key? key, required this.barcode}) : super(key: key);

  @override
  _NutrientsPageState createState() => _NutrientsPageState();
}

class _NutrientsPageState extends State<NutrientsPage> {
  Map<String, dynamic>? nutrients;
  String? productName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProductNutrients();
  }

  Future<void> fetchProductNutrients() async {
    final url = Uri.parse(
        'https://world.openfoodfacts.org/api/v0/product/${widget.barcode}.json');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 1) {
        final product = data['product'];
        setState(() {
          nutrients = product['nutriments'];
          productName = product['product_name'];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } else {
      throw Exception('Erreur lors du chargement');
    }
  }

  @override
  Widget build(BuildContext context) {
    final nutrimentsToShow = {
      'Calories': nutrients?['energy-kcal_100g'],
      'Protéines': nutrients?['proteins_100g'],
      'Glucides': nutrients?['carbohydrates_100g'],
      'Lipides': nutrients?['fat_100g'],
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(productName ?? 'Données nutritionnelles'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Nutriment')),
                  DataColumn(label: Text('Pour 100g')),
                ],
                rows: nutrimentsToShow.entries.map((entry) {
                  final value = entry.value;
                  final formattedValue =
                      value != null ? value.toString() : 'Non dispo';
                  return DataRow(cells: [
                    DataCell(Text(entry.key)),
                    DataCell(Text(formattedValue)),
                  ]);
                }).toList(),
              ),
            ),
    );
  }
}


void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: NutrientsPage(barcode: '3017620422003'), // Exemple : Nutella
  ));
}
