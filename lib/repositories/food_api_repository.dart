import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class FoodAPIRepository {
  Future<List<Map<String, dynamic>>> search(String query) async {
    final url = Uri.parse(
      'https://world.openfoodfacts.org/cgi/search.pl'
      '?search_terms=$query&search_simple=1&action=process&json=1&page_size=20'
      // bonus possible : &fields=product_name,nutriments,id,code,image_url&lc=fr
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception("Erreur de l'API de recherche d'aliments");
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final List products = (data['products'] as List?) ?? const [];
    // typage fort
    return products
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

// Provider (avec type explicite, facultatif mais clair)
final foodApiRepositoryProvider = Provider<FoodAPIRepository>((ref) => FoodAPIRepository());
