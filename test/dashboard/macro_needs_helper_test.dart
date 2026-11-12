import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_app/dashboard/macro_needs_helper.dart';

void main() {
  group('calculateMacroNeeds', () {
    test('uses repos baseline distribution', () {
      final result = calculateMacroNeeds(
        weightKg: 70,
        tdee: 2500,
        stravaCals: 0,
        typeToday: 'Repos',
        typeTomorrow: 'Repos',
      );

      expect(result['Calories'], 2500);
      expect(result['Protéines'], 140);
      expect(result['Glucides'], closeTo(218.25, 0.0001));
      expect(result['Lipides'], closeTo(118.5556, 0.0001));
      expect(result['Fibres'], 30);
    });

    test('applies Affûtage calorie and fiber reduction', () {
      final result = calculateMacroNeeds(
        weightKg: 70,
        tdee: 2500,
        stravaCals: 0,
        typeToday: 'Affûtage',
        typeTomorrow: 'Repos',
      );

      expect(result['Calories'], 2250);
      expect(result['Protéines'], 140);
      expect(result['Glucides'], closeTo(211.25, 0.0001));
      expect(result['Lipides'], closeTo(93.8889, 0.0001));
      expect(result['Fibres'], 25);
    });

    test('applies Intensité increase with higher proteins', () {
      final result = calculateMacroNeeds(
        weightKg: 70,
        tdee: 2500,
        stravaCals: 0,
        typeToday: 'Intensité',
        typeTomorrow: 'Repos',
      );

      expect(result['Calories'], 2625);
      expect(result['Protéines'], 147);
      expect(result['Glucides'], closeTo(280.0875, 0.0001));
      expect(result['Lipides'], closeTo(101.85, 0.0001));
      expect(result['Fibres'], 30);
    });

    test('applies Endurance increase with high carb share', () {
      final result = calculateMacroNeeds(
        weightKg: 70,
        tdee: 2500,
        stravaCals: 0,
        typeToday: 'Endurance',
        typeTomorrow: 'Repos',
      );

      expect(result['Calories'], 2750);
      expect(result['Protéines'], 140);
      expect(result['Glucides'], closeTo(328.5, 0.0001));
      expect(result['Lipides'], closeTo(97.3333, 0.0001));
      expect(result['Fibres'], 35);
    });

    test('uses endurance-eve loading only when today is Repos', () {
      final result = calculateMacroNeeds(
        weightKg: 70,
        tdee: 2500,
        stravaCals: 0,
        typeToday: 'Repos',
        typeTomorrow: 'Endurance',
      );

      expect(result['Calories'], 2625);
      expect(result['Protéines'], 140);
      expect(result['Glucides'], closeTo(283.9375, 0.0001));
      expect(result['Lipides'], closeTo(103.25, 0.0001));
      expect(result['Fibres'], 30);
    });
  });
}
