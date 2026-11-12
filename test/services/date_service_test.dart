import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_app/services/date_service.dart';

void main() {
  test('startOfWeek returns monday at local midnight', () {
    final value = DateService.startOfWeek(DateTime(2026, 7, 15, 18, 42));

    expect(value, DateTime(2026, 7, 13));
  });

  test('toBackendWeekKey strips prefix and normalizes separators', () {
    expect(DateService.toBackendWeekKey('week_2026/07/13'), '2026-07-13');
  });

  test('toBackendDayKey converts dd-mm-yyyy to yyyy-mm-dd', () {
    expect(DateService.toBackendDayKey('5-7-2026'), '2026-07-05');
  });

  test('toBackendDayKey keeps backend-formatted day keys unchanged', () {
    expect(DateService.toBackendDayKey('2026-07-15'), '2026-07-15');
  });
}
