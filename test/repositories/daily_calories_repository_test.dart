import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nutri_app/models/daily_calories.dart';
import 'package:nutri_app/repositories/daily_calories_repository.dart';

void main() {
  late Directory tempDir;
  late Box<DailyCalories> box;
  late DailyCaloriesRepository repository;

  setUpAll(() {
    Hive.registerAdapter(DailyCaloriesAdapter());
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('daily_calories_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<DailyCalories>('daily_calories_test_box');
    repository = DailyCaloriesRepository(box);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('daily_calories_test_box');
    await tempDir.delete(recursive: true);
  });

  test('cleanupOldEntries keeps entries within the default 180-day window',
      () async {
    final withinWindow = DateTime.now().subtract(const Duration(days: 90));
    final olderThanWindow = DateTime.now().subtract(const Duration(days: 181));

    await box.add(DailyCalories(
      date: withinWindow.toIso8601String().substring(0, 10),
      objectif: 2000,
      strava: 300,
      total: 2100,
    ));
    await box.add(DailyCalories(
      date: olderThanWindow.toIso8601String().substring(0, 10),
      objectif: 1900,
      strava: 200,
      total: 1800,
    ));

    await repository.cleanupOldEntries();

    final remainingDates = box.values.map((e) => e.date).toList();
    expect(remainingDates, hasLength(1));
    expect(
      remainingDates.single,
      withinWindow.toIso8601String().substring(0, 10),
    );
  });
}
