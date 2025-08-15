import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/common_providers.dart';
import '../models/meal.dart';

// Modèle simple pour le profil utilisateur pour éviter de passer des maps partout
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

class UserRepository {
  final FirebaseFirestore _firestore;
  final SharedPreferences _prefs;
  final FirebaseAuth _auth;

  UserRepository(this._firestore, this._prefs, this._auth);

  User? get _currentUser => _auth.currentUser;

  /// Charge le profil complet de l'utilisateur.
  /// Il essaie d'abord depuis Firestore, puis se rabat sur SharedPreferences.
  Future<UserProfile> getProfile() async {
    final uid = _currentUser?.uid;
    Map<String, dynamic>? data;

    // 1. Essayer de charger depuis Firestore si l'utilisateur est connecté
    if (uid != null) {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
      data = doc.data();
  
   
      } 
    } 

    // 2. Si Firestore échoue ou si l'utilisateur n'est pas connecté, utiliser SharedPreferences
    data ??= {
      'poids': _prefs.getDouble('poids') ?? 70.0,
      'taille': _prefs.getDouble('taille') ?? 175.0,
      'age': _prefs.getInt('age') ?? 30,
      'sexe': _prefs.getString('sexe') ?? 'Homme',
      'activite': _prefs.getString('activite') ?? 'Modéré',
      'prenom': _prefs.getString('prenom') ?? _currentUser?.displayName ?? '',
    };
    DateTime? birthDate;
    if (data['birthDate'] != null) {
      if (data['birthDate'] is Timestamp) {
        birthDate = (data['birthDate'] as Timestamp).toDate();
      } else if (data['birthDate'] is String) {
        birthDate = DateTime.tryParse(data['birthDate']);
      }
    }
    // Extraire les valeurs avec des valeurs par défaut robustes
    final double poids = double.tryParse(data['poids'].toString()) ?? 70.0;
    final double taille = double.tryParse(data['taille'].toString()) ?? 175.0;
    final int age = int.tryParse(data['age'].toString()) ?? 30;
    final String sexe = data['sexe'] as String? ?? 'Homme';
    final String activite = data['activite'] as String? ?? 'Modéré';
    final String prenom = data['prenom'] as String? ?? '';
    final String garminLink = data['garminLink'] as String? ?? '';
    
    // 3. Calculer le TDEE
    final double tdee = _calculateTDEE(poids, taille, age, sexe, activite);

    // 4. Mettre en cache les valeurs dans SharedPreferences pour un accès hors ligne
    _prefs.setDouble('poids', poids);
    _prefs.setDouble('taille', taille);
    _prefs.setInt('age', age);
    _prefs.setString('sexe', sexe);
    _prefs.setString('activite', activite);
    _prefs.setString('prenom', prenom);
    _prefs.setDouble('tdee', tdee);

    return UserProfile(
      weight: poids,
      height: taille,
      age: age,
      gender: sexe,
      activityLevel: activite,
      tdee: tdee,
      firstName: prenom,
      birthDate: birthDate,
      garminLink: garminLink,
      
    );
    
  }
/// Récupère les identifiants de l'application Strava de l'utilisateur.
  Future<Map<String, String>> getStravaCredentials() async {
    final uid = _currentUser?.uid;
    if (uid == null) return {};

    final doc = await _firestore.collection('users').doc(uid).collection('stravaApp').doc('credentials').get();
    if (doc.exists) {
      return {
        'clientId': doc.data()?['client_id'] as String? ?? '',
        'clientSecret': doc.data()?['client_secret'] as String? ?? '',
      };
    }
    return {};
  }
  /// Calcule le TDEE (Total Daily Energy Expenditure)
  double _calculateTDEE(double poids, double taille, int age, String sexe, String activite) {
    double bmr = sexe == 'Femme'
        ? 655.1 + (9.563 * poids) + (1.850 * taille) - (4.676 * age)
        : 66.5 + (13.75 * poids) + (5.003 * taille) - (6.755 * age);

    final activityFactors = {
      'Sédentaire': 1.2,
      'Modéré': 1.375,
      'Actif': 1.55,
      'Très actif': 1.725,
    };
    final factor = activityFactors[activite] ?? 1.375;
    return bmr * factor;
  }
  
  /// Sauvegarde les données du profil de l'utilisateur dans Firestore.
  Future<void> saveProfile(Map<String, dynamic> profileData) async {
    final uid = _currentUser?.uid;
    if (uid == null) throw Exception("Utilisateur non authentifié.");

    await _firestore.collection('users').doc(uid).set(
      profileData,
      SetOptions(merge: true),
    );
  }

  /// Sauvegarde les identifiants de l'application Strava de l'utilisateur.
  Future<void> saveStravaCredentials({required String clientId, required String clientSecret}) async {
    final uid = _currentUser?.uid;
    if (uid == null) throw Exception("Utilisateur non authentifié.");

    await _firestore.collection('users').doc(uid).collection('stravaApp').doc('credentials').set({
      'client_id': clientId,
      'client_secret': clientSecret,
    });
  }
 Future<void> createUserProfile(User user, Map<String, dynamic> profileData) async {
    // On utilise l'UID de l'utilisateur fraîchement créé
    final docRef = _firestore.collection('users').doc(user.uid);
    // On sauvegarde les données initiales du profil
    await docRef.set(profileData);
  }
  /// Sauvegarde un aliment personnalisé dans la sous-collection de l'utilisateur.
  Future<void> saveCustomFood(Meal meal) async {
    final uid = _currentUser?.uid;
    if (uid == null) throw Exception("Utilisateur non authentifié.");

    // Le document aura un ID basé sur le nom de l'aliment pour éviter les doublons
    final docId = meal.name.trim().toLowerCase(); 

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('custom_foods')
        .doc(docId)
        .set(meal.toMap());
  }

  /// Récupère tous les aliments personnalisés de l'utilisateur.
  Future<List<Meal>> getCustomFoods() async {
    final uid = _currentUser?.uid;
    if (uid == null) return [];

    final querySnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('custom_foods')
        .get();
        
    return querySnapshot.docs.map((doc) => Meal.fromMap(doc.data(), id: doc.id)).toList();
  }
}


// --- Providers Riverpod ---

// On suppose que tu as un provider pour SharedPreferences initialisé dans ton main.dart

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    FirebaseFirestore.instance,
    ref.watch(sharedPreferencesProvider),
    FirebaseAuth.instance,
  );
});