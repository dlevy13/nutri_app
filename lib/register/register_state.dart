// dans lib/features/register/register_state.dart
import 'package:equatable/equatable.dart';
//refonte
enum RegisterStatus { initial, loading, success, failure }

class RegisterState extends Equatable {
  final RegisterStatus status;
  final String? errorMessage;
  final String userId;

  // 🔥 Champs nécessaires pour stocker les préférences utilisateurs
  final String prenom;
  final String email;
  final String taille;
  final String poids;
  final String activite;
  final DateTime? birthDate;
  final int age;

  const RegisterState({
    this.status = RegisterStatus.initial,
    this.errorMessage,
    this.userId = "",
    this.prenom = "",
    this.email = "",
    this.taille = "",
    this.poids = "",
    this.activite = "",
    this.birthDate,
    this.age = 0,
  });

  RegisterState copyWith({
    RegisterStatus? status,
    String? errorMessage,
    String? userId,
    String? prenom,
    String? email,
    String? taille,
    String? poids,
    String? activite,
    DateTime? birthDate,
    int? age,
  }) {
    return RegisterState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      userId: userId ?? this.userId,
      prenom: prenom ?? this.prenom,
      email: email ?? this.email,
      taille: taille ?? this.taille,
      poids: poids ?? this.poids,
      activite: activite ?? this.activite,
      birthDate: birthDate ?? this.birthDate,
      age: age ?? this.age,
    );
  }

  @override
  List<Object?> get props => [
        status,
        errorMessage,
        prenom,
        taille,
        poids,
        activite,
        birthDate,
        age,
      ];
}
