class DaySnapshot {
  final DateTime date;

  // Énergie
  final double objectiveKcal; // objectif SANS Strava
  final double activityKcal;  // Strava
  final double consumedKcal;  // total consommé

  // Macros
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sugarsG;

  // Qualité des lipides
  final double fatSaturatedG;
  final double fatMonounsaturatedG;
  final double fatPolyunsaturatedG;

  // Meta (optionnel mais utile)
  final DateTime? updatedAt;

  const DaySnapshot({
    required this.date,
    required this.objectiveKcal,
    required this.activityKcal,
    required this.consumedKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.sugarsG,
    required this.fatSaturatedG,
    required this.fatMonounsaturatedG,
    required this.fatPolyunsaturatedG,
    this.updatedAt,
  });

  // ===========================================================================
  // == JSON → MODEL (Supabase → Flutter)
  // ===========================================================================

  factory DaySnapshot.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) =>
        (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

    DateTime parseDate(dynamic v) =>
        v is DateTime ? v : DateTime.parse(v.toString());

    return DaySnapshot(
      date: parseDate(json['date']),
      objectiveKcal: d(json['objective_kcal']),
      activityKcal: d(json['activity_kcal']),
      consumedKcal: d(json['consumed_kcal']),

      proteinG: d(json['protein_g']),
      carbsG: d(json['carbs_g']),
      fatG: d(json['fat_g']),
      fiberG: d(json['fiber_g']),
      sugarsG: d(json['sugars_g']),

      fatSaturatedG: d(json['fat_saturated_g']),
      fatMonounsaturatedG: d(json['fat_monounsaturated_g']),
      fatPolyunsaturatedG: d(json['fat_polyunsaturated_g']),

      updatedAt: json['updated_at'] != null
          ? parseDate(json['updated_at'])
          : null,
    );
  }

  // ===========================================================================
  // == MODEL → JSON (Flutter → Supabase)
  // ===========================================================================

  Map<String, dynamic> toJson() {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    return {
      'date': fmt(date),

      'objective_kcal': objectiveKcal,
      'activity_kcal': activityKcal,
      'consumed_kcal': consumedKcal,

      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'fiber_g': fiberG,
      'sugars_g': sugarsG,

      'fat_saturated_g': fatSaturatedG,
      'fat_monounsaturated_g': fatMonounsaturatedG,
      'fat_polyunsaturated_g': fatPolyunsaturatedG,
    };
  }
}
