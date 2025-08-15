// dans lib/features/login/login_state.dart
import 'package:equatable/equatable.dart';

enum AuthStatus { initial, loading, success, failure }

class LoginState extends Equatable {
  final AuthStatus status;
  final String? errorMessage;

  const LoginState({
    this.status = AuthStatus.initial,
    this.errorMessage,
  });

  LoginState copyWith({
    AuthStatus? status,
    String? errorMessage,
  }) {
    return LoginState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}