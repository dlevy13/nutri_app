class DailyCalories {
  final String date;
  final double objectif;
  final double strava;
  final double total;

  DailyCalories({
    required this.date,
    required this.objectif,
    required this.strava,
    required this.total,
  });

  Map<String, dynamic> toMap() => {
    "date": date,
    "objectif": objectif,
    "strava": strava,
    "total": total,
  };

  factory DailyCalories.fromMap(Map<String, dynamic> map) {
    return DailyCalories(
      date: map["date"],
      objectif: map["objectif"],
      strava: map["strava"],
      total: map["total"],
    );
  }
}
