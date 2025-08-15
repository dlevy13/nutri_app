// dans lib/features/profile_form/profile_form_state.dart
import 'package:equatable/equatable.dart';

enum FormStatus { initial, loading, success, failure }

class ProfileFormState extends Equatable {
  final FormStatus status;
  final String prenom;
  final String poids;
  final String taille;
  final DateTime? birthDate;
  final String sexe;
  final String activite;
  final String garminLink;
  final String stravaClientId;
  final String stravaClientSecret;
  final bool isStravaConnected;
  

  const ProfileFormState({
    this.status = FormStatus.initial,
    this.prenom = '',
    this.poids = '',
    this.taille = '',
    this.birthDate,
    this.sexe = 'Homme',
    this.activite = 'Modéré',
    this.garminLink = '',
    this.stravaClientId = '',
    this.stravaClientSecret = '',
    this.isStravaConnected = false,
  });

  ProfileFormState copyWith({
    FormStatus? status,
    String? prenom,
    String? poids,
    String? taille,
    DateTime? birthDate,
    String? sexe,
    String? activite,
    String? garminLink,
    String? stravaClientId,
    String? stravaClientSecret,
    bool? isStravaConnected,
  }) {
    return ProfileFormState(
      status: status ?? this.status,
      prenom: prenom ?? this.prenom,
      poids: poids ?? this.poids,
      taille: taille ?? this.taille,
      birthDate: birthDate ?? this.birthDate,
      sexe: sexe ?? this.sexe,
      activite: activite ?? this.activite,
      garminLink: garminLink ?? this.garminLink,
      stravaClientId: stravaClientId ?? this.stravaClientId,
      stravaClientSecret: stravaClientSecret ?? this.stravaClientSecret,
      isStravaConnected: isStravaConnected ?? this.isStravaConnected,
    );
  }

  @override
  List<Object?> get props => [
    status, prenom, poids, taille, birthDate, sexe, activite, 
    garminLink, stravaClientId, stravaClientSecret, isStravaConnected
  ];
}