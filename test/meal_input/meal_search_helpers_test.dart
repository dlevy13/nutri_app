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

  group('food search relevance', () {
    late List<Map<String, dynamic>> localFoods;
    setUpAll(() {
      localFoods =
          (jsonDecode(File('assets/food_data.json').readAsStringSync()) as List)
              .map((row) => <String, dynamic>{
                    'product_name': row['name'],
                    'group': row['group'] ?? row['groupe'] ?? '',
                    'source': 'local',
                  })
              .toList();
    });

    test('pot-au-feu ranks first for spaces, Unicode hyphens and extra spaces',
        () {
      List<String>? expected;
      for (final query in [
        'pot au feu',
        'pot-au-feu',
        'pot–au–feu',
        'Pot‑au‑feu',
        '  POT   AU FEU  '
      ]) {
        final results = rankFoodSearchResults(localFoods, query);
        final names = results.map((r) => r['product_name'] as String).toList();
        expect(names.first, 'Pot-au-feu préemballé', reason: query);
        expect(names, isNot(contains('Petit pot légumes dès 4-6 mois')));
        expect(
            results.any(
                (r) => r['group'] == 'petits pots salés et plats infantiles'),
            isFalse);
        expected ??= names;
        expect(names, expected, reason: query);
      }
    });

    test('the same ranking filters unrelated remote and cached candidates', () {
      final entries = [
        {
          'product_name': 'Petit pot légumes',
          'source': 'api',
          'group': 'petits pots salés et plats infantiles'
        },
        {
          'product_name': 'Plat légumes avec féculent',
          'group': 'petits pots salés et plats infantiles'
        },
        {'product_name': 'Pot-au-feu préemballé', 'source': 'local'},
        {'product_name': 'Bouillon de viande type pot au feu', 'source': 'api'},
      ];
      expect(
          rankFoodSearchResults(entries, 'pot au feu')
              .map((r) => r['product_name']),
          ['Pot-au-feu préemballé', 'Bouillon de viande type pot au feu']);
    });

    test('match quality always outranks source preference', () {
      final entries = [
        {'product_name': 'Bouillon de pot-au-feu', 'source': 'custom'},
        {'product_name': 'Pot-au-feu aux légumes', 'source': 'custom'},
        {'product_name': 'Pot au feu', 'source': 'api'},
        {'product_name': 'Pot-au-feu', 'source': 'local'},
        {'product_name': 'Feu et pot au menu', 'source': 'custom'},
      ];
      expect(
          rankFoodSearchResults(entries, 'pot au feu')
              .map((r) => r['product_name']),
          [
            'Pot au feu',
            'Pot-au-feu',
            'Pot-au-feu aux légumes',
            'Bouillon de pot-au-feu',
            'Feu et pot au menu'
          ]);
    });

    test('a category must match the entire compound query', () {
      expect(
          localFoodGroupMatches(
              'pot au feu', 'petits pots salés et plats infantiles'),
          isFalse);
      expect(
          localFoodGroupMatches(
              'plats composes', 'plats composés avec féculents'),
          isTrue);
      expect(
          localFoodGroupMatches(
              'plats legumes', 'plats composés avec féculents'),
          isFalse);
      expect(
          localFoodGroupMatches('pot', 'petits pots salés et plats infantiles'),
          isTrue);
    });

    test('name matches outrank category matches, even for a single word', () {
      final results = rankFoodSearchResults([
        {'product_name': 'Plat préparé', 'group': 'riz et pâtes'},
        {'product_name': 'Riz complet', 'group': 'céréales'},
      ], 'riz');
      expect(results.first['product_name'], 'Riz complet');
    });

    test('accents, ligatures, apostrophes and plural forms are equivalent', () {
      expect(localFoodNameMatches("huile d'olive", 'Huile d’olive vierge'),
          isTrue);
      expect(
          localFoodNameMatches('huile olive', 'Huile d’olive vierge'), isTrue);
      expect(localFoodNameMatches('boeuf bourguignon', 'Bœuf bourguignon'),
          isTrue);
      expect(
          localFoodNameMatches('pomme cuite', 'Pommes cuites au four'), isTrue);
      expect(
          localFoodNameMatches(
              'yaourt demi ecreme', 'Yaourt demi-écrémé nature'),
          isTrue);
    });

    test('all words, including negative and numeric qualifiers, must match',
        () {
      expect(
          localFoodNameMatches('yaourt sans sucre', 'Yaourt sans sucre ajouté'),
          isTrue);
      expect(
          localFoodNameMatches('yaourt sans sucre', 'Yaourt sucré'), isFalse);
      expect(localFoodNameMatches('yaourt 0%', 'Yaourt nature 0 %'), isTrue);
      expect(localFoodNameMatches('yaourt 0%', 'Yaourt nature'), isFalse);
      expect(localFoodNameMatches('pot', 'Compote de pommes'), isFalse);
      expect(
          localFoodNameMatches('pot au feu', 'Petit pot aux légumes'), isFalse);
    });

    test('blank queries and equal scores remain predictable', () {
      expect(localFoodNameMatches(' --- ', 'Riz'), isFalse);
      expect(localFoodGroupMatches(' ', 'plats préparés'), isFalse);
      expect(rankFoodSearchResults(localFoods, ''), isEmpty);
      final entries = [
        {'product_name': 'Riz blanc'},
        {'product_name': 'Riz complet'},
      ];
      expect(rankFoodSearchResults(entries, 'riz'), entries);
    });
  });

  group('online search decision', () {
    test('categories and incomplete prefixes do not count as strong candidates',
        () {
      expect(
          hasEnoughFoodNameMatches(
              List.generate(
                  10,
                  (i) => {
                        'product_name': 'Plat $i',
                        'group': 'riz et pâtes',
                      }),
              'riz'),
          isFalse);
      expect(
          hasEnoughFoodNameMatches(
              List.generate(
                  10,
                  (i) => {
                        'product_name': 'Amandes grillées $i',
                      }),
              'amand'),
          isFalse);
    });

    test(
        'five distinct strong names are sufficient, duplicate variants are not',
        () {
      final strong = List.generate(
          5, (i) => <String, dynamic>{'product_name': 'Riz complet $i'});
      expect(hasEnoughFoodNameMatches(strong, 'riz complet'), isTrue);
      expect(hasEnoughFoodNameMatches(strong.take(4), 'riz complet'), isFalse);
      expect(
          hasEnoughFoodNameMatches([
            {'product_name': 'Pot-au-feu'},
            {'product_name': 'Pot au feu'},
            {'product_name': 'POT–AU–FEU'},
            {'product_name': 'Pot au feu'},
            {'product_name': 'pot  au  feu'},
          ], 'pot au feu'),
          isFalse);
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
