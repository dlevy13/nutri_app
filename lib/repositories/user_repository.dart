import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/common_providers.dart';
import 'package:hive/hive.dart';
import '../models/meal.dart';
import '../log.dart';

// -----------------------------------------------------------
// Modèle de profil utilisateur
// -----------------------------------------------------------

const String customFoodsBoxName = "custom_foods_box";

// -----------------------------------------------------------
// USER PROFILE MODEL
// -----------------------------------------------------------

class UserProfile {
  final double weight;
  final double height;
  final int age;
  final String gender;
  final String activityLevel;
  final double tdee;
  final String firstName;
  final DateTime? birthDate;
  final String garminLink;

  UserProfile({
    required this.weight,
    required this.height,
    required this.age,
    required this.gender,
    required this.activityLevel,
    required this.tdee,
    required this.firstName,
    this.birthDate,
    required this.garminLink,
  });
}

// -----------------------------------------------------------
// USER REPOSITORY (SharedPreferences + Hive pour custom foods)
// -----------------------------------------------------------

class UserRepository {
  final SharedPreferences _prefs;
  final Box<Meal> _customFoodsBox;
  final SupabaseClient _supabase;

  UserRepository(this._prefs, this._customFoodsBox, this._supabase);

  // -----------------------------------------------------------
  // PROFIL UTILISATEUR (LOGIQUE HYBRIDE)
  // -----------------------------------------------------------

  Future<UserProfile> getProfile() async {
    final user = _supabase.auth.currentUser;

    // 1. Tenter de récupérer les données Supabase (Priorité PWA/iOS)
    if (user != null) {
      try {
        final data = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (data != null) {
          // Mapping avec conversion des types numeric (num) vers double
          final double poids = (data['poids_kg'] as num?)?.toDouble() ?? (_prefs.getDouble("poids") ?? 70.0);
          final double taille = (data['taille_cm'] as num?)?.toDouble() ?? (_prefs.getDouble("taille") ?? 175.0);
          final String sexe = data['sexe'] ?? (_prefs.getString("sexe") ?? "Homme");
          final String activ = data['activite'] ?? (_prefs.getString("activite") ?? "Modéré");
          final String prenom = data['prenom'] ?? (_prefs.getString("prenom") ?? "");
          final String garmin = data['garminLink'] ?? (_prefs.getString("garminLink") ?? "");
          
          final birthDate = data['birth_date'] != null
              ? DateTime.parse(data['birth_date'])
              : (DateTime.tryParse(_prefs.getString("birthDate") ?? ""));

          final age = birthDate != null
              ? _calculateAge(birthDate)
              : (_prefs.getInt("age") ?? 30);

          final tdee = _calculateTDEE(poids, taille, age, sexe, activ);

          // 🔹 Mise à jour du cache local pour rester synchro
          await _syncLocalCache(
            prenom: prenom,
            poids: poids,
            taille: taille,
            sexe: sexe,
            activite: activ,
            age: age,
            birthDate: birthDate,
            garmin: garmin,
          );

          return UserProfile(
            weight: poids,
            height: taille,
            age: age,
            gender: sexe,
            activityLevel: activ,
            tdee: tdee,
            firstName: prenom,
            birthDate: birthDate,
            garminLink: garmin,
          );
        }
      } catch (e) {
        logger.d("Erreur Supabase getProfile: $e");
      }
    }

    // 2. Fallback local si offline ou pas de données distantes
    return _getLocalProfile();
  }

  UserProfile _getLocalProfile() {
    final poids = _prefs.getDouble("poids") ?? 70.0;
    final taille = _prefs.getDouble("taille") ?? 175.0;
    final age = _prefs.getInt("age") ?? 30;
    final sexe = _prefs.getString("sexe") ?? "Homme";
    final activ = _prefs.getString("activite") ?? "Modéré";
    final prenom = _prefs.getString("prenom") ?? "";
    final garmin = _prefs.getString("garminLink") ?? "";
    final birthStr = _prefs.getString("birthDate");
    final birthDate = (birthStr != null) ? DateTime.tryParse(birthStr) : null;

    return UserProfile(
      weight: poids,
      height: taille,
      age: age,
      gender: sexe,
      activityLevel: activ,
      tdee: _calculateTDEE(poids, taille, age, sexe, activ),
      firstName: prenom,
      birthDate: birthDate,
      garminLink: garmin,
    );
  }

  // user_repository.dart

Future<void> saveProfile(Map<String, dynamic> data) async {
  // 1. Sauvegarde Locale SharedPreferences
  if (data.containsKey("prenom")) _prefs.setString("prenom", data["prenom"]);
  if (data.containsKey("sexe")) _prefs.setString("sexe", data["sexe"]);
  if (data.containsKey("activite")) _prefs.setString("activite", data["activite"]);
  if (data.containsKey("garminLink")) _prefs.setString("garminLink", data["garminLink"]);

  double? p;
  if (data.containsKey("poids")) {
    p = _parseToDouble(data["poids"]);
    if (p != null) _prefs.setDouble("poids", p);
  }

  double? t;
  if (data.containsKey("taille")) {
    t = _parseToDouble(data["taille"]);
    if (t != null) _prefs.setDouble("taille", t);
  }

  if (data.containsKey("birthDate") && data["birthDate"] is DateTime) {
    final d = data["birthDate"] as DateTime;
    _prefs.setString("birthDate", d.toIso8601String());
    _prefs.setInt("age", _calculateAge(d));
  }

  // 2. Sauvegarde Supabase (Distante)
  final user = _supabase.auth.currentUser;
  if (user == null) return;

  try {
    await _supabase.from('profiles').upsert({
      'id': user.id,
     'email': user.email,
      if (data.containsKey("prenom")) 'prenom': data["prenom"],
      if (p != null) 'poids_kg': p,
      if (t != null) 'taille_cm': t,
      if (data.containsKey("sexe")) 'sexe': data["sexe"],
      if (data.containsKey("activite")) 'activite': data["activite"],
      if (data.containsKey("garminLink")) 'garminLink': data["garminLink"],
      if (data.containsKey("birthDate") && data["birthDate"] is DateTime)
        // Format YYYY-MM-DD pour le type 'date' SQL
        'birth_date': (data["birthDate"] as DateTime).toIso8601String().split('T')[0],
      'updated_at': DateTime.now().toIso8601String(), // Corrigé : updated avec un 'd'
    });
  } catch (e) {
    logger.d("ERREUR SUPABASE : $e");
    rethrow;
  }
}

  // --- Helpers ---

  double? _parseToDouble(dynamic value) {
    if (value is double) return value;
    if (value == null) return null;
    final s = value.toString().replaceAll(',', '.').trim();
    return double.tryParse(s);
  }

  int _calculateAge(DateTime birth) {
    final now = DateTime.now();
    int age = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) age--;
    return age;
  }

  Future<void> _syncLocalCache({
    required String prenom, required double poids, required double taille,
    required String sexe, required String activite, required int age,
    DateTime? birthDate, required String garmin,
  }) async {
    await _prefs.setString("prenom", prenom);
    await _prefs.setDouble("poids", poids);
    await _prefs.setDouble("taille", taille);
    await _prefs.setString("sexe", sexe);
    await _prefs.setString("activite", activite);
    await _prefs.setInt("age", age);
    await _prefs.setString("garminLink", garmin);
    if (birthDate != null) await _prefs.setString("birthDate", birthDate.toIso8601String());
  }

  double _calculateTDEE(double poids, double taille, int age, String sexe, String activite) {
    double bmr = (sexe == 'Femme')
        ? 655.1 + (9.563 * poids) + (1.850 * taille) - (4.676 * age)
        : 66.5  + (13.75 * poids) + (5.003 * taille) - (6.755 * age);

    final activityFactors = {
      'Sédentaire': 1.2,
      'Modéré': 1.375,
      'Actif': 1.55,
      'Très actif': 1.725,
    };
    return bmr * (activityFactors[activite] ?? 1.375);
  }

  // -----------------------------------------------------------
  // STRAVA (clé locale)
  // -----------------------------------------------------------

  Future<Map<String, String>> getStravaCredentials() async {
    return {
      "clientId": _prefs.getString("strava_clientId") ?? "",
      "clientSecret": _prefs.getString("strava_clientSecret") ?? "",
    };
  }

  Future<void> saveStravaCredentials({
    required String clientId,
    required String clientSecret,
  }) async {
    await _prefs.setString("strava_clientId", clientId);
    await _prefs.setString("strava_clientSecret", clientSecret);
  }

  // -----------------------------------------------------------
  // CUSTOM FOODS (HIVE)
  // -----------------------------------------------------------

  Future<List<Meal>> getCustomFoods() async {
    return _customFoodsBox.values.whereType<Meal>().toList();
  }

  Future<void> saveCustomFood(Meal meal) async {
    final key = meal.name.toLowerCase().trim();
    await _customFoodsBox.put(key, meal);
  }

  Future<void> deleteCustomFood(String name) async {
    final key = name.toLowerCase().trim();
    await _customFoodsBox.delete(key);
  }
}

// -----------------------------------------------------------
// PROVIDER
// -----------------------------------------------------------

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final customBox = ref.watch(customFoodsBoxProvider); // <-- injection propre
  final supabase = Supabase.instance.client;
  return UserRepository(prefs, customBox,supabase);
});
