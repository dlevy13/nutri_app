import 'package:equatable/equatable.dart';

enum FormStatus { initial, loading, success, failure }

class ProfileFormState extends Equatable {
  final FormStatus status;
  final String prenom;
  final String email;
  final String poids;
  final String taille;
  final DateTime? birthDate;   // <<< Champ correct
  final String sexe;
  final String activite;
  final String garminLink;
  final bool isStravaConnected;

  const ProfileFormState({
    this.status = FormStatus.initial,
    this.prenom = '',
    this.email = "",
    this.poids = '',
    this.taille = '',
    this.birthDate,           // <<< pas de typo !!
    this.sexe = 'Homme',
    this.activite = 'Modéré',
    this.garminLink = '',
    this.isStravaConnected = false,
  });

  ProfileFormState copyWith({
    FormStatus? status,
    String? prenom,
    String? email,
    String? poids,
    String? taille,
    DateTime? birthDate,
    String? sexe,
    String? activite,
    String? garminLink,
    bool? isStravaConnected,
  }) {
    return ProfileFormState(
      status: status ?? this.status,
      prenom: prenom ?? this.prenom,
      email: email ?? this.email,
      poids: poids ?? this.poids,
      taille: taille ?? this.taille,
      birthDate: birthDate ?? this.birthDate,
      sexe: sexe ?? this.sexe,
      activite: activite ?? this.activite,
      garminLink: garminLink ?? this.garminLink,
      isStravaConnected: isStravaConnected ?? this.isStravaConnected,
    );
  }

  @override
  List<Object?> get props => [
        status,
        prenom,
        poids,
        taille,
        birthDate,
        sexe,
        activite,
        garminLink,
        isStravaConnected,
      ];
}
