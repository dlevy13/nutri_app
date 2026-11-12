import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_app/meal_input/meal_search_helpers.dart';

void main() {
  group('localFoodNameMatches', () {
    test('matches ratatouille entries from the local json dataset', () {
      final data = jsonDecode(
        File('assets/food_data.json').readAsStringSync(),
      ) as List<dynamic>;

      final matches = data
          .cast<Map<String, dynamic>>()
          .where(
            (item) => localFoodNameMatches(
              'ratatouille',
              (item['name'] as String?) ?? '',
            ),
          )
          .map((item) => item['name'] as String)
          .toList();

      expect(matches, isNotEmpty);
      expect(
        matches,
        contains('Ratatouille cuisinée préemballée'),
      );
    });

    test('matches accent-insensitive and tokenized names', () {
      expect(
        localFoodNameMatches('amandes grillees', 'Amandes grillées salées'),
        isTrue,
      );
    });
  });

  group('resolveSuggestedQuantity', () {
    test('prefers sport product serving_size over fallback weight', () {
      final result = resolveSuggestedQuantity(
        foodData: {
          'source': 'sport_product',
          'serving_size': 45,
          'product_name': 'Gel test',
        },
        fallbackWeightGrams: 100,
        fallbackUnitLabel: 'g',
      );

      expect(result.defaultGrams, 45);
      expect(result.unitLabel, 'portion');
      expect(result.gramsPerUnit, 45);
    });

    test('falls back to reference weight when there is no serving_size', () {
      final result = resolveSuggestedQuantity(
        foodData: {
          'source': 'local',
          'product_name': 'Pomme',
        },
        fallbackWeightGrams: 150,
        fallbackUnitLabel: 'piece',
      );

      expect(result.defaultGrams, 150);
      expect(result.unitLabel, 'piece');
      expect(result.gramsPerUnit, 150);
    });
  });
}
