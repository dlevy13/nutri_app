import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_app/models/day_snapshot.dart';

void main() {
  test('DaySnapshot.toJson includes updated_at when provided', () {
    final snapshot = DaySnapshot(
      date: DateTime(2026, 7, 17),
      objectiveKcal: 2400,
      activityKcal: 350,
      consumedKcal: 2100,
      proteinG: 140,
      carbsG: 260,
      fatG: 70,
      fiberG: 30,
      sugarsG: 45,
      fatSaturatedG: 18,
      fatMonounsaturatedG: 22,
      fatPolyunsaturatedG: 12,
      updatedAt: DateTime.parse('2026-07-17T14:30:00.000'),
    );

    final json = snapshot.toJson();

    expect(json['date'], '2026-07-17');
    expect(json['updated_at'], '2026-07-17T14:30:00.000');
  });
}
