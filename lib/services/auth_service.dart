import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import 'fonctions.dart'; // pour saveUserToFirestore()

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential> registerUser({
    required String email,
    required String password,
    required String name,
    required int age,
    required double height,
    required double weight,
    required String activityLevel,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final newUser = AppUser(
      uid: credential.user!.uid,
      name: name,
      age: age,
      height: height,
      weight: weight,
      activityLevel: activityLevel,
      tdee: _calculateTDEE(weight, height, age, activityLevel),
    );

    await saveUserToFirestore(newUser);

    return credential;
  }

  double _calculateTDEE(double weight, double height, int age, String activityLevel) {
    double bmr = 10 * weight + 6.25 * height - 5 * age + 5; // formule de Mifflin
    switch (activityLevel) {
      case "low":
        return bmr * 1.4;
      case "moderate":
        return bmr * 1.6;
      case "high":
        return bmr * 1.8;
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

}
