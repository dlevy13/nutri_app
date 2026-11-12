import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_app/models/aliment_usuel.dart';
import 'package:nutri_app/services/food_matching_service.dart';

void main() {
  AlimentUsuel item(String aliment) => AlimentUsuel(
        aliment: aliment,
        groupe: '',
        poids: 100,
        unite: 'g',
        commentaire: '',
      );

  group('FoodMatchingService.getPoidsUsuel', () {
    test('ignores sugar items when the query is not about sugar', () {
      final service = FoodMatchingService(
        alimentsUsuels: [
          item('sucre blanc'),
          item('yaourt nature'),
        ],
      );

      final result = service.getPoidsUsuel('yaourt sans sucre');

      expect(result?.aliment, 'yaourt nature');
    });

    test('still allows sugar matches when sugar leads the query', () {
      final service = FoodMatchingService(
        alimentsUsuels: [
          item('sucre blanc'),
          item('yaourt nature'),
        ],
      );

      final result = service.getPoidsUsuel('Sucre blanc');

      expect(result?.aliment, 'sucre blanc');
    });

    test('matches despite accents and plural forms', () {
      final service = FoodMatchingService(
        alimentsUsuels: [
          item('amande grillee'),
        ],
      );

      final result = service.getPoidsUsuel('Amandes grillées');

      expect(result?.aliment, 'amande grillee');
    });
  });
}
