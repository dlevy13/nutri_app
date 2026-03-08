
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/user_repository.dart';
import '../services/strava_service_shared.dart';
import '../profile_form/profile_form_state.dart';
import '../repositories/strava_repository.dart'; 

class ProfileFormNotifier extends StateNotifier<ProfileFormState> {
  final Ref _ref;
  final UserRepository _userRepository;
  final StravaServiceShared _stravaService;
  bool _disposed = false;

  ProfileFormNotifier(this._ref, this._userRepository, this._stravaService) 
      : super(const ProfileFormState());

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
// Sécurité pour mettre à jour l'état
  void _safeUpdate(ProfileFormState newState) {
    if (!_disposed && mounted) {
      state = newState;
    }
  }
  Future<void> loadLocalData() async {
    _safeUpdate(state.copyWith(status: FormStatus.loading));
    try {
      final profile = await _userRepository.getProfile();
      _safeUpdate(state.copyWith(
        status: FormStatus.success,
        prenom: profile.firstName,
        poids: profile.weight.toString(),
        taille: profile.height.toString(),
        birthDate: profile.birthDate,
        sexe: profile.gender,
        activite: profile.activityLevel,
        garminLink: profile.garminLink,
      ));
    } catch (e) {
      _safeUpdate(state.copyWith(status: FormStatus.failure));
    }
  }

  // --- Setters inchangés ---
  void prenomChanged(String v) => _safeUpdate(state.copyWith(prenom: v));
  void poidsChanged(String v) => _safeUpdate(state.copyWith(poids: v));
  void tailleChanged(String v) => _safeUpdate(state.copyWith(taille: v));
  void birthDateChanged(DateTime d) => _safeUpdate(state.copyWith(birthDate: d));
  void sexeChanged(String v) => _safeUpdate(state.copyWith(sexe: v));
  void activiteChanged(String v) => _safeUpdate(state.copyWith(activite: v));
  void garminLinkChanged(String v) => _safeUpdate(state.copyWith(garminLink: v));
  // 💾 Sauvegarde simplifiée
  Future<void> saveProfile({bool autoSave = false}) async {
    if (!autoSave) {
      _safeUpdate(state.copyWith(status: FormStatus.loading));
    }
    try {
      // On délègue tout au repository (Parsing, SharedPreferences, Supabase)
      await _userRepository.saveProfile({
        "prenom": state.prenom,
        "poids": state.poids,
        "taille": state.taille,
        "sexe": state.sexe,
        "activite": state.activite,
        "birthDate": state.birthDate,
        "garminLink": state.garminLink,
      });

      if (!autoSave) {
        _safeUpdate(state.copyWith(status: FormStatus.success));
      }
    } catch (_) {
      if (!autoSave) {
        _safeUpdate(state.copyWith(status: FormStatus.failure));
      }
    }
  }

  Future<void> disconnectStrava() async {
    await _stravaService.disconnect();
    if (_disposed) return;
    _ref.invalidate(isStravaConnectedProvider);
    state = state.copyWith(isStravaConnected: false);
  }
}

final profileFormProvider =
    StateNotifierProvider<ProfileFormNotifier, ProfileFormState>(
  (ref) => ProfileFormNotifier(
    ref,
    ref.watch(userRepositoryProvider),
    ref.watch(stravaServiceProvider),
  ),
);