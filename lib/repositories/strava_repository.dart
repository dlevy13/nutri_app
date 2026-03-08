// ---------------- IMPORTS FIRST (mandatory in Dart) ----------------

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../services/strava_service.dart';
import '../services/strava_service_mobile.dart';
import '../services/strava_service_web.dart';

import '../services/date_service.dart';
import '../providers/common_providers.dart'; // dailyCaloriesRepositoryProvider
import '../services/strava_service_shared.dart';
import '../models/strava_day_activities.dart';



// ---------------- REPOSITORY ----------------

class StravaRepository {
  final StravaServiceShared _stravaService;
  final Ref _ref;

  StravaRepository(this._stravaService, this._ref);

  StravaServiceShared getStravaService() => _stravaService;

  Future<({List<dynamic> activities, double totalCalories})>
    getActivitiesAndCaloriesForDate(
      DateTime date, {
      bool forceRefresh = false,
    }) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (date.isAfter(today)) {
        return (activities: [], totalCalories: 0.0);
      }

      if (!await _stravaService.isConnected()) {
        return (activities: [], totalCalories: 0.0);
      }

      final dateKey = DateService.formatStandard(date);

      final caloriesRepo = _ref.read(dailyCaloriesRepositoryProvider);
      final activitiesRepo = _ref.read(stravaActivitiesRepositoryProvider);

      // 🔒 1️⃣ CACHE HIT → Hive
      final cachedActivities = activitiesRepo.getForDate(dateKey);
      final cachedCalories = caloriesRepo.getForDate(dateKey);

      if (!forceRefresh &&
        cachedActivities != null &&
        activitiesRepo.isFresh(cachedActivities) &&
        cachedCalories != null &&
        caloriesRepo.isStravaFresh(cachedCalories)) {
        return (
          activities: cachedActivities.activities,
          totalCalories: cachedCalories.strava,
        );
      }

      // 🌐 2️⃣ CACHE MISS → réseau
      final activities = await _stravaService.getActivitiesForDay(date);

      if (activities.isEmpty) {
        await caloriesRepo.upsert(
          date: dateKey,
          objectif: cachedCalories?.objectif ?? 0,
          total: cachedCalories?.total ?? 0,
          strava: 0.0,
          stravaFetchedAt: DateTime.now(),
        );

        return (activities: [], totalCalories: 0.0);
      }

      // 🔍 détails + calories
      final details = await Future.wait(
        activities.map((a) {
          final id = a['id'] as int;
          return _stravaService.getActivityDetails(id);
        }),
      );

      double totalCalories = 0.0;
      final List<Map<String, dynamic>> enriched =
          List<Map<String, dynamic>>.from(activities);

      for (int i = 0; i < enriched.length; i++) {
        double calories = _parseDouble(details[i]?['calories']);

        if (calories == 0.0) {
          final kj = _parseDouble(details[i]?['kilojoules']);
          if (kj > 0) calories = kj * 0.239006;
        }

        enriched[i]['calories'] = calories;
        totalCalories += calories;
      }

      // 💾 3️⃣ Sauvegarde Hive
      await activitiesRepo.upsert(
        dateKey: dateKey,
        activities: enriched,
      );

      await caloriesRepo.upsert(
        date: dateKey,
        objectif: cachedCalories?.objectif ?? 0,
        total: cachedCalories?.total ?? 0,
        strava: totalCalories,
        stravaFetchedAt: DateTime.now(),
      );

      await activitiesRepo.cleanup();
      await caloriesRepo.cleanupOldEntries();

      return (activities: enriched, totalCalories: totalCalories);
    }


}


// ---------------- UTILITIES ----------------

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }
  return 0.0;
}

class StravaActivitiesRepository {
  final Box<StravaDayActivities> _box;

  StravaActivitiesRepository(this._box);

  StravaDayActivities? getForDate(String dateKey) {
        try {
      return _box.values.firstWhere((e) => e.date == dateKey);
    } catch (_) {
      return null;
    }

  }

  bool isFresh(StravaDayActivities e) {
    return e.fetchedAt.isAfter(
      DateTime.now().subtract(const Duration(hours: 12)),
    );
  }

  Future<void> upsert({
    required String dateKey,
    required List<Map<String, dynamic>> activities,
  }) async {
    final existing = getForDate(dateKey);

    if (existing != null) {
      existing.activities = activities;
      existing.fetchedAt = DateTime.now();
      await existing.save();
      return;
    }

    await _box.add(
      StravaDayActivities(
        date: dateKey,
        activities: activities,
        fetchedAt: DateTime.now(),
      ),
    );
  }

  Future<void> cleanup({int keepDays = 7}) async {
    final cutoff = DateTime.now().subtract(Duration(days: keepDays));

    final keysToDelete = _box.values
        .where((e) => e.fetchedAt.isBefore(cutoff))
        .map((e) => e.key)
        .toList();

    if (keysToDelete.isNotEmpty) {
      await _box.deleteAll(keysToDelete);
    }
  }
}

// ---------------- PROVIDERS ----------------

final stravaServiceProvider = Provider<StravaServiceShared>((ref) {
  if (kIsWeb) {
    return StravaServiceWeb();
  } else {
    return StravaServiceMobile();
  }
});

final stravaRepositoryProvider = Provider((ref) {
  final service = ref.watch(stravaServiceProvider);
  return StravaRepository(service, ref);
});

final isStravaConnectedProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(stravaServiceProvider).isConnected();
});

final stravaActivitiesRepositoryProvider =
    Provider<StravaActivitiesRepository>((ref) {
  final box = Hive.box<StravaDayActivities>('stravaActivities');
  return StravaActivitiesRepository(box);
});

