import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../meal_input/meal_search_helpers.dart';

final foodCacheRepositoryProvider = Provider<FoodCacheRepository>((ref) {
  return FoodCacheRepository(Supabase.instance.client);
});

class FoodCacheRepository {
  final SupabaseClient _supabase;
  FoodCacheRepository(this._supabase);

  // Exact normalized keys prevent unrelated first-word buckets from mixing.
  Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    final key = normalizeFoodSearch(query);
    if (key.length < 3) return [];

    final response = await _supabase
        .from('food_search_cache')
        .select('data')
        .eq('query', key)
        .limit(20);

    final results = response
        .map<Map<String, dynamic>>(
          (row) => Map<String, dynamic>.from(row['data']),
        )
        .toList();
    return rankFoodSearchResults(results, key);
  }

  // 💾 SAVE (safe + no duplicates)
  Future<void> saveMany(String query, List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;

    final key = normalizeFoodSearch(query);
    if (key.length < 3) return;

    final rows = rankFoodSearchResults(items, key).map((item) {
      final code = (item['code'] ?? item['id'] ?? '').toString();
      return {
        'query': key,
        'product_name': (item['product_name'] ?? '').toString(),
        'code': code,
        'data': item,
      };
    }).where((row) {
      final name = (row['product_name'] as String).trim();
      final code = (row['code'] as String).trim();
      return name.isNotEmpty && code.isNotEmpty;
    }).toList();

    if (rows.isEmpty) return;

    await _supabase
        .from('food_search_cache')
        .upsert(rows, onConflict: 'query,code');
  }
}
