/// Helpers pour parser num solide
double asDouble(dynamic v, {double fallback = 0.0}) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) {
    final s = v.trim().replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.');
    return double.tryParse(s) ?? fallback;
  }
  return fallback;
}

// Certains items n'ont pas energy-kcal_100g mais ont energy-kj_100g
double energyKcal100g(Map<String, dynamic> n) {
  final kcal = asDouble(n['energy-kcal_100g']);
  if (kcal > 0) return kcal;
  final kj = asDouble(n['energy-kj_100g']);
  return kj > 0 ? kj * 0.239005736 : 0.0;
}