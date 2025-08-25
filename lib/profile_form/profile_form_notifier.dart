
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/user_repository.dart';
import '../services/strava_service.dart';
import '../profile_form/profile_form_state.dart';
import '../repositories/strava_repository.dart'; 

class ProfileFormNotifier extends StateNotifier<ProfileFormState> {
  final Ref _ref;
  final UserRepository _userRepository;
  final StravaService _stravaService;

  ProfileFormNotifier(this._ref, this._userRepository, this._stravaService) 
      : super(const ProfileFormState()) {
    loadInitialData();
  }

  // dans la classe ProfileFormNotifier

Future<void> loadInitialData() async {
  state = state.copyWith(status: FormStatus.loading);

  try {
    // On charge toutes les données en parallèle
    final results = await Future.wait([
      _userRepository.getProfile(),
      _userRepository.getStravaCredentials(),
      _stravaService.isConnected(),
    ]);

    // On extrait les résultats
    final profile = results[0] as UserProfile;
    final stravaCreds = results[1] as Map<String, String>;
    final isConnected = results[2] as bool;

    // On met à jour l'état avec les données chargées
    state = state.copyWith(
      status: FormStatus.success,
      prenom: profile.firstName,
      poids: profile.weight.toString(),
      taille: profile.height.toString(),
      birthDate: profile.birthDate,
      sexe: profile.gender,
      activite: profile.activityLevel,
      stravaClientId: stravaCreds['clientId'] ?? '',
      stravaClientSecret: stravaCreds['clientSecret'] ?? '',
      isStravaConnected: isConnected,
      garminLink: profile.garminLink,
    );
  } catch (e) {
    print("Erreur de chargement du profil: $e");
    state = state.copyWith(status: FormStatus.failure);
  }
}
  
  // Méthodes pour mettre à jour les champs du formulaire
  void prenomChanged(String value) => state = state.copyWith(prenom: value);
  void poidsChanged(String value) => state = state.copyWith(poids: value);
  void tailleChanged(String value) => state = state.copyWith(taille: value);
  // ... créez une méthode pour chaque champ ...
  void birthDateChanged(DateTime date) => state = state.copyWith(birthDate: date);
  void sexeChanged(String value) => state = state.copyWith(sexe: value);
  void activiteChanged(String value) => state = state.copyWith(activite: value);
  void garminLinkChanged(String value) => state = state.copyWith(garminLink: value);


  Future<void> saveProfile() async {
    state = state.copyWith(status: FormStatus.loading);
    try {
      int age = 0;
      if (state.birthDate != null) {
        final today = DateTime.now();
        age = today.year - state.birthDate!.year;
        if (today.month < state.birthDate!.month || (today.month == state.birthDate!.month && today.day < state.birthDate!.day)) {
          age--;
        }
      }

      await _userRepository.saveProfile({
        'prenom': state.prenom,
        'poids': state.poids,
        'taille': state.taille,
        'birthDate': state.birthDate?.toIso8601String(),
        'age': age,
        'sexe': state.sexe,
        'activite': state.activite,
        'garminLink': state.garminLink,
      });
      state = state.copyWith(status: FormStatus.success);
    } catch (e) {
      state = state.copyWith(status: FormStatus.failure);
    }
  }
  
  // ✅ AJOUTEZ CES MÉTHODES POUR METTRE À JOUR L'ÉTAT DEPUIS L'INTERFACE
  void stravaClientIdChanged(String value) => state = state.copyWith(stravaClientId: value);
  void stravaClientSecretChanged(String value) => state = state.copyWith(stravaClientSecret: value);
  
  // ✅ AJOUTEZ LA LOGIQUE DE SAUVEGARDE
  Future<bool> saveStravaCredentials() async {
    state = state.copyWith(status: FormStatus.loading);

    final clientId = state.stravaClientId.trim();
    final clientSecret = state.stravaClientSecret.trim();

    if (clientId.isEmpty || clientSecret.isEmpty) {
      // On peut gérer l'erreur ici si on veut, mais la validation du formulaire est préférable
      state = state.copyWith(status: FormStatus.failure);
      return false;
    }

    try {
      await _userRepository.saveStravaCredentials(
        clientId: clientId,
        clientSecret: clientSecret,
      );
      state = state.copyWith(status: FormStatus.success);
      return true;
    } catch (e) {
      state = state.copyWith(status: FormStatus.failure);
      return false;
    }
  }

  Future<void> disconnectStrava() async {
    await _stravaService.disconnect();
    _ref.invalidate(isStravaConnectedProvider);
    // On met à jour l'état pour que l'UI change immédiatement
    state = state.copyWith(isStravaConnected: false);
  }
}

// Le Provider pour ce notifier
final profileFormProvider = StateNotifierProvider.autoDispose<ProfileFormNotifier, ProfileFormState>((ref) {
  return ProfileFormNotifier(
    ref,
    ref.watch(userRepositoryProvider),
    ref.watch(stravaServiceProvider),
  );
});