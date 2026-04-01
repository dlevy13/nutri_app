import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
//   SEARCH FATSECRET (NECESSITE CLOUD FUNCTION)
//      → On garde pour protéger ton secret API (FatSecret interdit côté client)
// ---------------------------------------------------------------------------

final supabase = Supabase.instance.client;

Future<List<Map<String, dynamic>>> searchFoodOnFatSecret_OFFCompatible(
  String query,
) async {
  query = query.trim();
  if (query.isEmpty) return [];

  try {
    final res = await supabase.functions.invoke(
      'fs-search-clean', // nom exact de l’Edge Function
      body: {
        'q': query,
        'page': 1,
        'max': 10,
      },
    );

    if (res.status != 200) {
      throw Exception('Erreur FatSecret (status ${res.status})');
    }

    // invoke() peut renvoyer String ou Map
    final String rawBody =
        res.data is String ? res.data as String : jsonEncode(res.data);

    return _parseFatSecret_OFFCompatible(rawBody);

  } catch (e) {
    throw Exception('FatSecret indisponible: $e');
  }
}


// ---------------------------------------------------------------------------
//  PARSE FATSECRET → FORMAT UI IDENTIQUE À OFF
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _parseFatSecret_OFFCompatible(String body) {
  Map<String, dynamic> data;

  try {
    data = jsonDecode(body);
  } catch (_) {
    return [];
  }

  final items = (data["items"] as List?) ?? [];

  final out = <Map<String, dynamic>>[];

  double _d(v) => (v is num) ? v.toDouble() : double.tryParse("$v") ?? double.nan;

  for (final item in items) {
    if (item is! Map) continue;

    final name = (item["name"] ?? "").toString().trim();
    if (name.isEmpty) continue;

    final per100 = (item["per100"] as Map?) ?? {};

    final kcal = _d(per100["kcal"]);
    final prot = _d(per100["protein"]);
    final carbs = _d(per100["carbs"]);
    final fat = _d(per100["fat"]);
    final fiber = _d(per100["fibers"]);
    final sugar = _d(per100["sugars"]);
    final sat = _d(per100["saturatedFat"]);
    final mono = _d(per100["monounsaturatedFat"]);
    final poly = _d(per100["polyunsaturatedFat"]);

    if ((kcal.isNaN) && prot.isNaN && carbs.isNaN && fat.isNaN) continue;

    out.add({
      "product_name": name,
      "source": "fatsecret",
      "nutriments": {
        "energy-kcal_100g": kcal.isNaN ? 0 : kcal,
        "proteins_100g": prot.isNaN ? 0 : prot,
        "carbohydrates_100g": carbs.isNaN ? 0 : carbs,
        "fat_100g": fat.isNaN ? 0 : fat,
        "fiber_100g": fiber.isNaN ? 0 : fiber,
        "sugars_100g": sugar.isNaN ? 0 : sugar,
        "saturated-fat_100g": sat.isNaN ? 0 : sat,
        "monounsaturated-fat_100g": mono.isNaN ? 0 : mono,
        "polyunsaturated-fat_100g": poly.isNaN ? 0 : poly,
      }
    });
  }

  return out;
}
