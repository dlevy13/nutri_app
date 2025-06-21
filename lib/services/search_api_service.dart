
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';

Future<List<Map<String, dynamic>>> searchFoodOnAPI(String query) async {
  final uri = Uri.http(
    '\${getHostIP()}:3000',
    '/off/cgi/search.pl',
    {
      'search_terms': query,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '15',
      'fields': 'product_name,nutriments',
    },
  );

  final response = await http.get(uri);

  if (response.statusCode != 200) {
    throw Exception('Échec API (\${response.statusCode})');
  }

  return compute(_parseOpenFood, response.body);
}

List<Map<String, dynamic>> _parseOpenFood(String body) {
  final data = jsonDecode(body);
  final List products = data['products'] ?? [];
  return products.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
}
