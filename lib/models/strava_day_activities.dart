import 'package:hive/hive.dart';

part 'strava_day_activities.g.dart';

@HiveType(typeId: 3) // ⚠️ nouveau typeId
class StravaDayActivities extends HiveObject {
  @HiveField(0)
  String date; // yyyy-MM-dd

  @HiveField(1)
  List<Map<String, dynamic>> activities;

  @HiveField(2)
  DateTime fetchedAt;

  StravaDayActivities({
    required this.date,
    required this.activities,
    required this.fetchedAt,
  });
}
