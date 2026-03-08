import 'package:hive/hive.dart';

part 'daily_calories.g.dart';

//refonte
@HiveType(typeId: 2) // ⚠️ UNIQUE : 0 = Meal, 1 = Analysis, ici 2
class DailyCalories extends HiveObject {
  @HiveField(0)
  String date;      // "yyyy-MM-dd"

  @HiveField(1)
  double objectif;  // calories cibles (TDEE ajusté)

  @HiveField(2)
  double strava;    // kcal activité (Strava)

  @HiveField(3)
  double total;     // kcal consommées (ou autre mesure)

  @HiveField(4)
  DateTime? stravaFetchedAt;


  DailyCalories({
    required this.date,
    required this.objectif,
    required this.strava,
    required this.total,
    this.stravaFetchedAt,
  });

  Map<String, dynamic> toMap() => {
        "date": date,
        "objectif": objectif,
        "strava": strava,
        "total": total,
      };

  factory DailyCalories.fromMap(Map<String, dynamic> map) {
    return DailyCalories(
      date: map["date"] as String,
      objectif: (map["objectif"] as num).toDouble(),
      strava: (map["strava"] as num).toDouble(),
      total: (map["total"] as num).toDouble(),
    );
  }
}
