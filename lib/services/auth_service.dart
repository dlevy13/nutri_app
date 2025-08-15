import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import 'fonctions.dart'; // pour saveUserToFirestore()
import '../log.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential> registerUser({
    required String email,
    required String password,
    required String prenom,
    required int age,
    required double taille,
    required double poids,
    required String activite,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final newUser = AppUser(
      uid: credential.user!.uid,
      prenom: prenom,
      age: age,
      taille: taille,
      poids: poids,
      activite: activite,
      tdee: _calculateTDEE(poids, taille, age, activite),
    );

    await saveUserToFirestore(newUser);

    return credential;
  }

  double _calculateTDEE(double poids, double taille, int age, String activite) {
    double bmr = 10 * poids + 6.25 * taille - 5 * age + 5; // formule de Mifflin
    switch (activite) {
        case "Sédentaire":
          return bmr * 1.4;
        case "Modéré":
          return bmr * 1.6;
        case "Actif":
          return bmr * 1.8;
        case "Très actif":
          return bmr * 2.0;
        default:
          return bmr * 1.5;
    }
  }

  Future<void> updateUserProfileData({
      required double poids,
      required int age,
      required String sexe,
      required double taille,
      required String activite,
    }) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      await userRef.set({
        'poids': poids,
        'age': age,
        'sexe': sexe,
        'taille': taille,
        'activite': activite,
      }, SetOptions(merge: true));
    }
Future<UserCredential?> signIn(String email, String password) async {
  try {
    logger.d("📌 Tentative connexion : $email");
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    logger.d("✅ Connexion réussie UID: ${credential.user!.uid}");
    return credential;
  } catch (e) {
    logger.d("❌ Erreur connexion : $e");
    return null;
  }
}

}
