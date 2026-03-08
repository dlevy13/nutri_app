import 'package:shared_preferences/shared_preferences.dart';
import '../log.dart';
//refonte
class AuthService {
  // ------------------------------------------------------------
  //  REGISTER LOCAL (inscription locale)
  // ------------------------------------------------------------
  Future<void> registerUser({
    required String prenom,
    required int age,
    required double taille,
    required double poids,
    required String activite,
    required DateTime? birthDate,
    String sexe = "Homme",
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("prenom", prenom);
    await prefs.setInt("age", age);
    await prefs.setDouble("taille", taille);
    await prefs.setDouble("poids", poids);
    await prefs.setString("activite", activite);
    await prefs.setString("sexe", sexe);

    if (birthDate != null) {
      await prefs.setString("birthDate", birthDate.toIso8601String());
    }

    // Calcul automatique du TDEE
    final tdee = _calculateTDEE(poids, taille, age, sexe, activite);
    await prefs.setDouble("tdee", tdee);

    logger.d("📝 Profil utilisateur initial enregistré localement.");
  }

  // ------------------------------------------------------------
  //  UPDATE PROFIL LOCAL
  // ------------------------------------------------------------
  Future<void> updateUserProfileData({
    String? prenom,
    int? age,
    double? taille,
    double? poids,
    String? sexe,
    String? activite,
    DateTime? birthDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (prenom != null)   await prefs.setString("prenom", prenom);
    if (age != null)      await prefs.setInt("age", age);
    if (taille != null)   await prefs.setDouble("taille", taille);
    if (poids != null)    await prefs.setDouble("poids", poids);
    if (sexe != null)     await prefs.setString("sexe", sexe);
    if (activite != null) await prefs.setString("activite", activite);
    if (birthDate != null) {
      await prefs.setString("birthDate", birthDate.toIso8601String());
    }

    // Recalcul auto du TDEE si poids/taille/age/sexe/activite changent
    final currentPoids    = prefs.getDouble("poids") ?? 70.0;
    final currentTaille   = prefs.getDouble("taille") ?? 175.0;
    final currentAge      = prefs.getInt("age") ?? 30;
    final currentSexe     = prefs.getString("sexe") ?? "Homme";
    final currentActivite = prefs.getString("activite") ?? "Modéré";

    final tdee = _calculateTDEE(
      currentPoids,
      currentTaille,
      currentAge,
      currentSexe,
      currentActivite,
    );

    await prefs.setDouble("tdee", tdee);

    logger.d("🔄 Profil utilisateur mis à jour localement.");
  }

  // ------------------------------------------------------------
  //  TDEE
  // ------------------------------------------------------------
  double _calculateTDEE(
    double poids,
    double taille,
    int age,
    String sexe,
    String activite,
  ) {
    // Mifflin-St Jeor
    double bmr = sexe == 'Femme'
        ? 10 * poids + 6.25 * taille - 5 * age - 161
        : 10 * poids + 6.25 * taille - 5 * age + 5;

    switch (activite) {
      case "Sédentaire":  return bmr * 1.4;
      case "Modéré":      return bmr * 1.6;
      case "Actif":       return bmr * 1.8;
      case "Très actif":  return bmr * 2.0;
      default:            return bmr * 1.5;
    }
  }
}