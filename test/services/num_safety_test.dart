import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_app/services/num_safety.dart';

void main() {
  group('asDouble', () {
    test('parses num and strings safely', () {
      expect(asDouble(12), 12.0);
      expect(asDouble(' 12,5 '), 12.5);
      expect(asDouble('1 234,5'), 1234.5);
    });

    test('falls back for null and invalid values', () {
      expect(asDouble(null), 0.0);
      expect(asDouble('abc', fallback: 7.5), 7.5);
    });
  });

  group('energyKcal100g', () {
    test('prefers kcal when present', () {
      expect(energyKcal100g({'energy-kcal_100g': '89'}), 89.0);
    });

    test('converts kj to kcal when needed', () {
      expect(
        energyKcal100g({'energy-kj_100g': 100}),
        closeTo(23.9005736, 0.000001),
      );
    });
  });
}
