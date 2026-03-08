import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;


class FoodAPIRepository {
  Future<List<Map<String, dynamic>>> search(String query) async {
    final url = Uri.parse(
      'https://world.openfoodfacts.org/cgi/search.pl'
      '?search_terms=$query'
      '&search_simple=1'
      '&action=process'
      '&json=1'
      '&page_size=20'
      '&fields=product_name,nutriments,id,code,image_url' // réduit la charge
    );

    final resp = await http.get(url);
    if (resp.statusCode != 200) {
      throw Exception("Erreur de l'API de recherche d'aliments");
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final List products = (data['products'] as List?) ?? const [];

   // --- Helpers parse ---
double _num(dynamic v) {
  if (v == null) return double.nan;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? double.nan;
  return double.nan;
}
bool _gt(double x, [double th = 0.1]) => x.isFinite && !x.isNaN && x > th;

// --- Filtrage sélectif (avec inférence insaturés si absents) ---
final filtered = <Map<String, dynamic>>[];
int rejMacros0 = 0, rejLipides = 0, rej100 = 0;

for (final raw in products.whereType<Map>()) {
  final m = Map<String, dynamic>.from(raw);
  final nutr = (m['nutriments'] as Map?)?.cast<String, dynamic>() ?? const {};
  final name = (m['product_name'] ?? 'Inconnu').toString();

  final fat  = _num(nutr['fat_100g']);
  final sat  = _num(nutr['saturated-fat_100g']);
  final mono = _num(nutr['monounsaturated-fat_100g']);
  final poly = _num(nutr['polyunsaturated-fat_100g']);
  final prot = _num(nutr['proteins_100g']);
  final carb = _num(nutr['carbohydrates_100g']);

  // 0) valeurs "tout à 100"
  final vals = <double>[
    fat, sat, mono, poly, prot, carb,
    _num(nutr['fiber_100g']), _num(nutr['sugars_100g']),
  ].where((x) => x.isFinite && !x.isNaN).toList();
  final all100 = vals.isNotEmpty && vals.every((v) => (v - 100.0).abs() < 1e-9);
  if (all100) { rej100++; continue; }

  // 1) rejeter si macros principales toutes à 0
  final fatZ  = fat.isFinite ? fat : 0.0;
  final protZ = prot.isFinite ? prot : 0.0;
  final carbZ = carb.isFinite ? carb : 0.0;
  if (fatZ <= 0 && carbZ <= 0 && protZ <= 0) { rejMacros0++; continue; }
  

  // 2) exiger sat > 0 (ta contrainte)
  //if (!_gt(sat)) { rejLipides++; continue; }

  // 3) insaturés : (mono>0 || poly>0) OU, à défaut, (fat - sat) >= 1g/100g
  final hasMonoPoly = _gt(mono) || _gt(poly);
  final inferredUnsat = (fat.isFinite ? fat : 0) - (sat.isFinite ? sat : 0); // peut être négatif si données bruitées
  final hasUnsatByInference = inferredUnsat >= 1.0; // seuil tolérant

  //if (!hasMonoPoly && !hasUnsatByInference) {
    //rejLipides++; continue;
  //}


  // → garder au format OFF attendu par l’UI
  filtered.add({
    'product_name': name,
    'source': 'api',
    'id': m['id'],
    'code': m['code'],
    'image_url': m['image_url'],
    'nutriments': {
      'energy-kcal_100g': _num(nutr['energy-kcal_100g']).isNaN
          ? (_num(nutr['energy_100g']).isNaN ? 0.0 : _num(nutr['energy_100g']) / 4.184)
          : _num(nutr['energy-kcal_100g']),
      'proteins_100g':          protZ,
      'carbohydrates_100g':     carbZ,
      'fat_100g':               fatZ,
      'fiber_100g':             _num(nutr['fiber_100g']).isNaN ? 0.0 : _num(nutr['fiber_100g']),
      'sugars_100g':            _num(nutr['sugars_100g']).isNaN ? 0.0 : _num(nutr['sugars_100g']),
      'saturated-fat_100g':     sat.isFinite ? sat : 0.0,
      'monounsaturated-fat_100g': mono.isFinite ? mono : 0.0,
      'polyunsaturated-fat_100g': poly.isFinite ? poly : 0.0,
      'trans-fat_100g':         _num(nutr['trans-fat_100g']).isNaN ? 0.0 : _num(nutr['trans-fat_100g']),
    }
  });
}


    return filtered;
  }
}

// Provider inchangé
final foodApiRepositoryProvider = Provider<FoodAPIRepository>(
  (ref) => FoodAPIRepository(),
);
