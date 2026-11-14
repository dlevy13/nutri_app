import '../services/fonctions.dart';
import '../services/num_safety.dart';

/// Search-only normalization: keep word boundaries before removing punctuation.
/// The shared normalize() also builds other keys and is deliberately unchanged.
String normalizeFoodSearch(String value) =>
    normalize(value.replaceAll(RegExp(r"[-‐‑‒–—―'’‘/\\]+"), ' '));

List<String> foodSearchTokens(String value) => normalizeFoodSearch(value)
    .split(' ')
    .where((token) => token.isNotEmpty)
    .toList();

String searchRoot(String s) {
  final n = normalizeFoodSearch(s);
  if (n.endsWith('aux')) return '${n.substring(0, n.length - 3)}al';
  if (n.endsWith('eux')) return '${n.substring(0, n.length - 3)}eu';
  if (n.endsWith('x')) return n.substring(0, n.length - 1);
  if (n.endsWith('s')) return n.substring(0, n.length - 1);
  return n;
}

List<String> _roots(String value) => foodSearchTokens(value)
    .map(searchRoot)
    .where((token) => token.isNotEmpty)
    .toList();

bool _allWordsMatch(List<String> query, List<String> name) =>
    query.isNotEmpty &&
    query.every(
        (q) => name.any((n) => n == q || (q.length >= 2 && n.startsWith(q))));

List<String> searchGroupTokens(String? group) => foodSearchTokens(group ?? '');

String searchGroupFirstToken(String? group) {
  final tokens = searchGroupTokens(group);
  return tokens.isNotEmpty ? tokens.first : '';
}

/// Higher tiers always outrank lower tiers, independently of the source.
/// No substring-only match: 'pot' must not match 'compote'.
int foodNameMatchScore(String query, String name) {
  final q = normalizeFoodSearch(query);
  final n = normalizeFoodSearch(name);
  if (q.isEmpty || n.isEmpty) return 0;
  if (q == n) return 500;
  if (n.startsWith('$q ')) return 400;
  if (' $n '.contains(' $q ')) return 350;
  final queryRoots = _roots(query);
  final nameRoots = _roots(name);
  if (queryRoots.isNotEmpty && queryRoots.every(nameRoots.contains)) return 300;
  return _allWordsMatch(queryRoots, nameRoots) ? 250 : 0;
}

bool localFoodNameMatches(String query, String name) =>
    foodNameMatchScore(query, name) > 0;

/// Category searches must cover the entire query, including compound queries.
bool localFoodGroupMatches(String query, dynamic group) =>
    _allWordsMatch(_roots(query), _roots((group as String?) ?? ''));

int foodSearchEntryScore(Map<String, dynamic> item, String query) {
  final nameScore =
      foodNameMatchScore(query, (item['product_name'] as String?) ?? '');
  if (nameScore > 0) {
    final bonus = item['source'] == 'custom'
        ? 20
        : item['source'] == 'api'
            ? 2
            : 0;
    return nameScore + bonus;
  }
  return localFoodGroupMatches(query, item['group']) ? 150 : 0;
}

/// Also used for the first local response, before waiting for remote sources.
/// Stable ties retain input order (custom entries and local data come first).
List<Map<String, dynamic>> rankFoodSearchResults(
    Iterable<Map<String, dynamic>> items, String query) {
  final ranked = items
      .toList()
      .asMap()
      .entries
      .map((entry) => (
            index: entry.key,
            item: entry.value,
            score: foodSearchEntryScore(entry.value, query),
          ))
      .where((entry) => entry.score > 0)
      .toList();
  ranked.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.index.compareTo(b.index);
  });
  return ranked.map((entry) => entry.item).toList();
}

/// Broad categories and incomplete prefixes must not suppress online discovery.
/// Equivalent names from different sources count as a single strong candidate.
bool hasEnoughFoodNameMatches(
    Iterable<Map<String, dynamic>> items, String query,
    {int minimum = 5}) {
  final names = items
      .where((item) =>
          foodNameMatchScore(query, (item['product_name'] as String?) ?? '') >=
          300)
      .map((item) => normalizeFoodSearch(item['product_name'] as String))
      .toSet();
  return names.length >= minimum;
}

class SuggestedQuantity {
  final double defaultGrams;
  final String? unitLabel;
  final double? gramsPerUnit;

  const SuggestedQuantity({
    required this.defaultGrams,
    this.unitLabel,
    this.gramsPerUnit,
  });
}

SuggestedQuantity resolveSuggestedQuantity({
  required dynamic foodData,
  required double fallbackWeightGrams,
  required String? fallbackUnitLabel,
}) {
  final source = foodData is Map<String, dynamic>
      ? ((foodData['source'] as String?) ?? '').trim()
      : '';
  final servingSize = foodData is Map<String, dynamic>
      ? asDouble(foodData['serving_size'])
      : 0.0;

  if (source == 'sport_product' && servingSize > 0) {
    return SuggestedQuantity(
      defaultGrams: servingSize,
      unitLabel: 'portion',
      gramsPerUnit: servingSize,
    );
  }

  if (fallbackWeightGrams > 0) {
    return SuggestedQuantity(
      defaultGrams: fallbackWeightGrams,
      unitLabel: fallbackUnitLabel,
      gramsPerUnit: fallbackWeightGrams,
    );
  }

  return const SuggestedQuantity(defaultGrams: 100.0);
}
