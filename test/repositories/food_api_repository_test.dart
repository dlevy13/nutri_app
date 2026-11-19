import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_app/meal_input/meal_search_helpers.dart';
import 'package:nutri_app/repositories/food_api_repository.dart';

void main() {
  test('OFF brands survive parsing and relevance filtering', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['fields']!.split(','),
          contains('brands'));
      return http.Response(
          jsonEncode({
            'products': [
              {
                'product_name': 'Figue et son',
                'brands': 'Gerblé',
                'code': '123',
                'nutriments': {
                  'energy-kcal_100g': 400,
                  'carbohydrates_100g': 60
                },
              },
            ],
          }),
          200);
    });
    addTearDown(client.close);
    final results = await FoodAPIRepository(client: client).search('Gerblé');
    expect(results.single['brands'], 'Gerblé');
    expect(rankFoodSearchResults(results, 'gerble'), hasLength(1));
    expect(rankFoodSearchResults(results, 'figue et son'), hasLength(1));
  });

  test('brand is also retained for products without nutrition data', () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({
          'products': [
            {'product_name': 'Figue et son', 'brands': 'Gerblé', 'code': '123'}
          ],
        }),
        200));
    addTearDown(client.close);
    final results = await FoodAPIRepository(client: client).search('Gerblé');
    expect(rankFoodSearchResults(results, 'gerble'), hasLength(1));
  });
}
