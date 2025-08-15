import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class FoodAPIRepository {
  Future<List<dynamic>> search(String query) async {
    // Note : C'est un exemple avec OpenFoodFacts. Adaptez l'URL à votre service.
    final url = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl?search_terms=$query&search_simple=1&action=process&json=1&page_size=20');
    
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['products'] as List<dynamic>? ?? [];
    } else {
      throw Exception("Erreur de l'API de recherche d'aliments");
    }
  }
}

// Le provider pour ce repository
final foodApiRepositoryProvider = Provider((ref) => FoodAPIRepository());