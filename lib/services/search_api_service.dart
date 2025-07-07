
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';

Future<List<Map<String, dynamic>>> searchFoodOnAPI(String query) async {
  final uri = Uri.parse(
    'https://us-central1-nutriapp-4ea20.cloudfunctions.net/proxy'
    '?search_terms=$query'
    '&search_simple=1'
    '&action=process'
    '&json=1'
    '&page_size=15'
    '&fields=product_name,nutriments',
  );

  final response = await http.get(uri);
  if (response.statusCode != 200) {
    throw Exception('Erreur API : ${response.statusCode}');
  }

  return compute(_parseOpenFood, response.body);
}


List<Map<String, dynamic>> _parseOpenFood(String body) {
  final data = jsonDecode(body) as Map<String, dynamic>;
  final List products = data['products'] ?? [];

  double parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  return products.map<Map<String, dynamic>>((product) {
    final nutr = (product['nutriments'] ?? {}) as Map<String, dynamic>;

    final rawKcal = parseDouble(nutr['energy-kcal_100g']);
    final calories = rawKcal > 0
        ? rawKcal
        : parseDouble(nutr['energy_100g']) / 4.184;

    return {
      'name':     product['product_name'] ?? 'Inconnu',
      'calories': calories,
      'protein':  parseDouble(nutr['proteins_100g']),
      'carbs':    parseDouble(nutr['carbohydrates_100g']),
      'fat':      parseDouble(nutr['fat_100g']),
    };
  }).toList();
}

