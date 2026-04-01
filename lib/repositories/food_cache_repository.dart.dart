import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


final foodCacheRepositoryProvider = Provider<FoodCacheRepository>((ref) {
  return FoodCacheRepository(Supabase.instance.client);
});

class FoodCacheRepository {
  final SupabaseClient _supabase;
  FoodCacheRepository(this._supabase);

  String _normalize(String q) {
    return q.trim().toLowerCase().split(' ').first;
  }

  // 🔍 SEARCH (rapide + pertinent)
  Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 3) return [];

    final root = _normalize(q);

    final response = await _supabase
        .from('food_search_cache')
        .select('data')
        .or('query.ilike.%$root%,product_name.ilike.%$q%')
        .limit(20);

    final results = response
        .map<Map<String, dynamic>>(
          (row) => Map<String, dynamic>.from(row['data']),
        )
        .toList();

    // 🔥 tri intelligent (les meilleurs résultats en haut)
    results.sort((a, b) {
      final nameA = (a['product_name'] ?? '').toString().toLowerCase();
      final nameB = (b['product_name'] ?? '').toString().toLowerCase();

      final scoreA = nameA.startsWith(q) ? 2 : nameA.contains(q) ? 1 : 0;
      final scoreB = nameB.startsWith(q) ? 2 : nameB.contains(q) ? 1 : 0;

      return scoreB.compareTo(scoreA);
    });

    return results;
  }

  // 💾 SAVE (safe + no duplicates)
  Future<void> saveMany(String query, List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;

    final root = _normalize(query);

    final rows = items.map((item) {
      final code = (item['code'] ?? item['id'] ?? '').toString();
      return {
        'query': root,
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