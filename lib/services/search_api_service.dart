import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
//   SEARCH FATSECRET (NECESSITE CLOUD FUNCTION)
//      → On garde pour protéger ton secret API (FatSecret interdit côté client)
// ---------------------------------------------------------------------------

typedef FoodSearchRequest = Future<List<Map<String, dynamic>>> Function(String);

final fatSecretFoodSearchProvider = Provider<FoodSearchRequest>(
  (ref) => searchFoodOnFatSecretOffCompatible,
);

final supabase = Supabase.instance.client;

Future<List<Map<String, dynamic>>> searchFoodOnFatSecretOffCompatible(
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

    return parseFatSecretOffCompatible(rawBody);
  } catch (e) {
    throw Exception('FatSecret indisponible: $e');
  }
}

// ---------------------------------------------------------------------------
//  PARSE FATSECRET → FORMAT UI IDENTIQUE À OFF
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> parseFatSecretOffCompatible(String body) {
  Map<String, dynamic> data;

  try {
    data = jsonDecode(body);
  } catch (_) {
    return [];
  }

  final items = (data["items"] as List?) ?? [];

  final out = <Map<String, dynamic>>[];

  double parseDoubleValue(v) =>
      (v is num) ? v.toDouble() : double.tryParse('$v') ?? double.nan;

  for (final item in items) {
    if (item is! Map) continue;

    final name = (item["name"] ?? "").toString().trim();
    if (name.isEmpty) continue;

    final per100 = (item["per100"] as Map?) ?? {};

    final kcal = parseDoubleValue(per100["kcal"]);
    final prot = parseDoubleValue(per100["protein"]);
    final carbs = parseDoubleValue(per100["carbs"]);
    final fat = parseDoubleValue(per100["fat"]);
    final fiber = parseDoubleValue(per100["fibers"]);
    final sugar = parseDoubleValue(per100["sugars"]);
    final sat = parseDoubleValue(per100["saturatedFat"]);
    final mono = parseDoubleValue(per100["monounsaturatedFat"]);
    final poly = parseDoubleValue(per100["polyunsaturatedFat"]);

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
