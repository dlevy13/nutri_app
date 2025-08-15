// dans lib/features/login/login_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import 'login_state.dart';

// D'abord, on crée un provider pour notre AuthService
final authServiceProvider = Provider((ref) => AuthService());

class LoginNotifier extends StateNotifier<LoginState> {
  final AuthService _authService;

  LoginNotifier(this._authService) : super(const LoginState());

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final credential = await _authService.signIn(email, password);
      if (credential != null) {
        state = state.copyWith(status: AuthStatus.success);
      } else {
        state = state.copyWith(status: AuthStatus.failure, errorMessage: "Email ou mot de passe incorrect.");
      }
    } catch (e) {
      state = state.copyWith(status: AuthStatus.failure, errorMessage: e.toString());
    }
  }
}

// Le provider pour ce notifier
final loginProvider = StateNotifierProvider.autoDispose<LoginNotifier, LoginState>((ref) {
  return LoginNotifier(ref.watch(authServiceProvider));
});