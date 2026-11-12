import 'package:supabase_flutter/supabase_flutter.dart';

class SportProductRepository {
  SportProductRepository(this._supabase);

  final SupabaseClient _supabase;
  static const String _tableName = 'sport_products';
  static const String _selectColumns =
      'id, created_at, magnesium, caffeine, serving_size, calories, protein, '
      'carbs, fat, sucres, fibres, fat_sa, sodium, potassium, name, brand, groupe';

  static const int _maxResults = 50;
  static const int _pageSize = 500;

  Future<List<String>> fetchGroups() async {
    final rows = await _fetchAllRows();

    final groups = rows
        .map<String>(_extractGroup)
        .where((group) => group.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return groups;
  }

  Future<List<String>> fetchBrands({String? group}) async {
    final normalizedGroup = (group ?? '').trim();
    final rows = await _fetchAllRows();

    final brands = rows
        .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
        .where((row) {
          if (normalizedGroup.isEmpty) return true;
          return _extractGroup(row).toLowerCase() ==
              normalizedGroup.toLowerCase();
        })
        .map<String>(_extractBrand)
        .where((brand) => brand.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return brands;
  }

  Future<List<Map<String, dynamic>>> searchProducts({
    required String query,
    String? group,
    String? brand,
  }) async {
    final trimmedQuery = query.trim();
    final normalizedGroup = (group ?? '').trim();
    final normalizedBrand = (brand ?? '').trim();

    final response = await _fetchAllRows();

    final normalizedQuery = trimmedQuery.toLowerCase();

    final items = response
        .map<Map<String, dynamic>>((row) => _toSearchItem(
              Map<String, dynamic>.from(row),
            ))
        .where((item) {
      if (normalizedQuery.isEmpty) return true;
      final name = _extractName(item).toLowerCase();
      final itemBrand = _extractBrand(item).toLowerCase();
      return name.contains(normalizedQuery) ||
          itemBrand.contains(normalizedQuery);
    }).where((item) {
      if (normalizedGroup.isEmpty) return true;
      return _extractGroup(item).toLowerCase() == normalizedGroup.toLowerCase();
    }).where((item) {
      if (normalizedBrand.isEmpty) return true;
      return _extractBrand(item).toLowerCase() == normalizedBrand.toLowerCase();
    }).toList();

    items.sort(
        (a, b) => _score(b, trimmedQuery).compareTo(_score(a, trimmedQuery)));
    if (trimmedQuery.isEmpty || items.length <= _maxResults) {
      return items;
    }
    return items.sublist(0, _maxResults);
  }

  Future<List<Map<String, dynamic>>> _fetchAllRows() async {
    final rows = <Map<String, dynamic>>[];
    var from = 0;

    while (true) {
      final page = await _supabase
          .from(_tableName)
          .select(_selectColumns)
          .range(from, from + _pageSize - 1);

      final mappedPage = (page as List)
          .map<Map<String, dynamic>>(
              (row) => Map<String, dynamic>.from(row as Map))
          .toList();

      if (mappedPage.isEmpty) {
        break;
      }

      rows.addAll(mappedPage);

      if (mappedPage.length < _pageSize) {
        break;
      }

      from += _pageSize;
    }

    return rows;
  }

  Map<String, dynamic> _toSearchItem(Map<String, dynamic> row) {
    return {
      ...row,
      'id': row['id'],
      'product_name': _extractName(row),
      'brand': _extractBrand(row),
      'groupe': _extractGroup(row),
      'group': _extractGroup(row),
      'source': 'sport_product',
      'nutriments': {
        'energy-kcal_100g': _num(
          row['energy-kcal_100g'] ??
              row['energy_kcal_100g'] ??
              row['kcal_100g'] ??
              row['calories'],
        ),
        'proteins_100g': _num(
          row['proteins_100g'] ?? row['protein_100g'] ?? row['protein'],
        ),
        'carbohydrates_100g': _num(
          row['carbohydrates_100g'] ?? row['carbs_100g'] ?? row['carbs'],
        ),
        'fat_100g': _num(
          row['fat_100g'] ?? row['lipids_100g'] ?? row['fat'],
        ),
        'fiber_100g': _num(
          row['fiber_100g'] ?? row['fibers_100g'] ?? row['fibres_100g'],
        ),
        'sugars_100g': _num(
          row['sugars_100g'] ?? row['sucres_100g'] ?? row['sugars'],
        ),
        'saturated-fat_100g': _num(
          row['saturated-fat_100g'] ??
              row['saturated_fat_100g'] ??
              row['fat_saturated_100g'],
        ),
        'monounsaturated-fat_100g': _num(
          row['monounsaturated-fat_100g'] ??
              row['monounsaturated_fat_100g'] ??
              row['fat_monounsaturated_100g'],
        ),
        'polyunsaturated-fat_100g': _num(
          row['polyunsaturated-fat_100g'] ??
              row['polyunsaturated_fat_100g'] ??
              row['fat_polyunsaturated_100g'],
        ),
      },
    };
  }

  String _extractName(Map<String, dynamic> row) {
    return (row['name'] ?? row['product_name'] ?? row['libelle'] ?? '')
        .toString()
        .trim();
  }

  String _extractBrand(Map<String, dynamic> row) {
    return (row['brand'] ?? row['marque'] ?? '').toString().trim();
  }

  String _extractGroup(Map<String, dynamic> row) {
    return (row['groupe'] ??
            row['group'] ??
            row['product_group'] ??
            row['category'])
        .toString()
        .trim();
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0.0;
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
  }

  int _score(Map<String, dynamic> item, String query) {
    if (query.isEmpty) return 0;

    final q = query.toLowerCase();
    final name = (item['product_name'] ?? '').toString().toLowerCase();
    final brand = (item['brand'] ?? '').toString().toLowerCase();

    if (name.startsWith(q)) return 100;
    if (brand.startsWith(q)) return 90;
    if (name.contains(q) && brand.contains(q)) return 80;
    if (name.contains(q)) return 70;
    if (brand.contains(q)) return 60;
    return 0;
  }
}
