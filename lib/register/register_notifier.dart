import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'register_state.dart';
import '../repositories/user_repository.dart';

class RegisterNotifier extends StateNotifier<RegisterState> {
  final UserRepository _userRepository;

  RegisterNotifier(this._userRepository) : super(const RegisterState()) {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    // On utilise le repository pour charger les données initiales si elles existent
    final profile = await _userRepository.getProfile();
    
    state = state.copyWith(
      prenom: profile.firstName,
      taille: profile.height.toString(),
      poids: profile.weight.toString(),
      activite: profile.activityLevel,
      birthDate: profile.birthDate,
      age: profile.age,
      status: RegisterStatus.initial,
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required String prenom,
    required String taille,
    required String poids,
    required String activite,
    required DateTime? birthDate,
  }) async {
    state = state.copyWith(status: RegisterStatus.loading);

    try {
      // 1️⃣ Création du compte Auth
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      final user = authResponse.user;
      if (user == null) throw Exception("Inscription échouée");

      // 2️⃣ Sauvegarde Hybride via Repository (Local + Supabase)
      await _userRepository.saveProfile({
        "prenom": prenom,
        "taille": taille,
        "poids": poids,
        "activite": activite,
        "birthDate": birthDate,
        "sexe": "Homme", // Valeur par défaut à l'inscription
        "garminLink": "",
      });

      state = state.copyWith(
        userId: user.id,
        email: email,
        prenom: prenom,
        taille: taille,
        poids: poids,
        activite: activite,
        birthDate: birthDate,
        status: RegisterStatus.success,
      );
    } on AuthException catch (e) {
      state = state.copyWith(status: RegisterStatus.failure, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(status: RegisterStatus.failure, errorMessage: e.toString());
    }
  }
}

final registerProvider = StateNotifierProvider<RegisterNotifier, RegisterState>((ref) {
  return RegisterNotifier(ref.watch(userRepositoryProvider));
});