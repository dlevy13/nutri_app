// dans lib/features/register/register_notifier.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repositories/user_repository.dart';
import 'register_state.dart';

// On peut créer un provider simple pour FirebaseAuth
final firebaseAuthProvider = Provider((ref) => FirebaseAuth.instance);

class RegisterNotifier extends StateNotifier<RegisterState> {
  final FirebaseAuth _auth;
  final UserRepository _userRepository;

  RegisterNotifier(this._auth, this._userRepository) : super(const RegisterState());

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> register({
    required String email, required String password, required String prenom,
    required String taille, required String poids, required String activite,
    required DateTime? birthDate,
  }) async {
    state = state.copyWith(status: RegisterStatus.loading);
    try {
      // 1. Créer l'utilisateur avec Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception("La création de l'utilisateur a échoué.");
      }

      // 2. Préparer les données du profil
      final int age = birthDate != null ? _calculateAge(birthDate) : 0;
      final profileData = {
        'uid': user.uid,
        'prenom': prenom,
        'email': email,
        'age': age,
        'taille': double.tryParse(taille) ?? 0,
        'poids': double.tryParse(poids) ?? 0,
        'activite': activite,
        'birthDate': birthDate?.toIso8601String(),
      };

      // 3. Sauvegarder le profil via le UserRepository
      await _userRepository.createUserProfile(user, profileData);

      state = state.copyWith(status: RegisterStatus.success);
    } catch (e) {
      state = state.copyWith(status: RegisterStatus.failure, errorMessage: e.toString());
    }
  }
}

// Le provider pour ce notifier
final registerProvider = StateNotifierProvider.autoDispose<RegisterNotifier, RegisterState>((ref) {
  return RegisterNotifier(
    ref.watch(firebaseAuthProvider),
    ref.watch(userRepositoryProvider),
  );
});