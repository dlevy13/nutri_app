import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutri_app/repositories/food_cache_repository.dart.dart';

void main() {
  test('cache reads use the full canonical query, never a first-word OR',
      () async {
    final requests = <http.Request>[];
    final client = SupabaseClient('https://example.test', 'test-key',
        httpClient: MockClient((request) async {
      requests.add(request);
      return http.Response(
          jsonEncode([
            {
              'data': {
                'product_name': 'Petit pot légumes',
                'group': 'petits pots salés'
              }
            },
            {
              'data': {'product_name': 'Pot-au-feu préemballé', 'code': '123'}
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request);
    }));
    addTearDown(client.dispose);
    final repository = FoodCacheRepository(client);
    for (final query in [
      'pot au feu',
      'pot-au-feu',
      'Pot–au–feu',
      '  POT   AU FEU '
    ]) {
      final results = await repository.searchFoods(query);
      expect(requests.last.url.queryParameters['query'], 'eq.pot au feu');
      expect(requests.last.url.queryParameters.containsKey('or'), isFalse);
      expect(results.map((r) => r['product_name']), ['Pot-au-feu préemballé']);
    }
  });

  test(
      'cache upserts store the full normalized key and only relevant identified products',
      () async {
    final requests = <http.Request>[];
    final client = SupabaseClient('https://example.test', 'test-key',
        httpClient: MockClient((request) async {
      requests.add(request);
      return http.Response('', 201, request: request);
    }));
    addTearDown(client.dispose);
    final repository = FoodCacheRepository(client);
    final products = [
      {'product_name': 'Pot-au-feu préemballé', 'code': '123'},
      {
        'product_name': 'Petit pot légumes',
        'code': '456',
        'group': 'petits pots salés'
      },
      {'product_name': 'Pot au feu sans identifiant'},
    ];
    for (final query in ['pot-au-feu', 'Pot au feu']) {
      await repository.saveMany(query, products);
      final rows = jsonDecode(requests.last.body) as List;
      expect(rows, hasLength(1));
      expect(rows.single['query'], 'pot au feu');
      expect(rows.single['code'], '123');
      expect(requests.last.url.queryParameters['on_conflict'], 'query,code');
    }
  });

  test('empty and short normalized queries do not access the cache', () async {
    var requests = 0;
    final client = SupabaseClient('https://example.test', 'test-key',
        httpClient: MockClient((request) async {
      requests++;
      return http.Response('[]', 200);
    }));
    addTearDown(client.dispose);
    final repository = FoodCacheRepository(client);
    for (final query in ['', ' - ', ' a ']) {
      expect(await repository.searchFoods(query), isEmpty);
      await repository.saveMany(query, [
        {'product_name': 'Aliment', 'code': '1'}
      ]);
    }
    expect(requests, 0);
  });
}
