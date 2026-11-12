import '../services/fonctions.dart';
import '../services/num_safety.dart';

String searchRoot(String s) {
  final n = normalize(s);
  if (n.endsWith('aux')) return '${n.substring(0, n.length - 3)}al';
  if (n.endsWith('eux')) return '${n.substring(0, n.length - 3)}eu';
  if (n.endsWith('x')) return n.substring(0, n.length - 1);
  if (n.endsWith('s')) return n.substring(0, n.length - 1);
  return n;
}

List<String> searchGroupTokens(String? g) =>
    normalize(g ?? '').split(' ').where((t) => t.isNotEmpty).toList();

String searchGroupFirstToken(String? g) {
  final toks = searchGroupTokens(g);
  return toks.isNotEmpty ? toks.first : '';
}

bool localFoodNameMatches(String query, String name) {
  final qRoots =
      query.split(' ').map(searchRoot).where((t) => t.isNotEmpty).toList();
  final tokens =
      name.split(' ').map(searchRoot).where((t) => t.isNotEmpty).toList();
  final nameOk = qRoots.every((qt) => tokens.any((mt) =>
      mt.startsWith(qt) ||
      (mt.length >= 3 && qt.startsWith(mt)) ||
      mt.contains(qt)));
  return nameOk || normalize(name).contains(normalize(query));
}

bool localFoodGroupMatches(String query, dynamic group) {
  final qr = searchRoot(query.trim().split(' ').first);
  final grpRaw = (group as String?) ?? '';
  final firstRoot = searchRoot(searchGroupFirstToken(grpRaw));
  if (firstRoot.isEmpty) return false;
  if (firstRoot == qr || firstRoot.startsWith(qr)) return true;
  final toks = searchGroupTokens(grpRaw).map(searchRoot);
  return toks.any((t) => t == qr || t.startsWith(qr));
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
