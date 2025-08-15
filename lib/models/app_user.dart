//Utilitaires pour traitement de texte (normalisation, raccourcissement, etc.)

class AppUser {
  final String uid;
  final String prenom;
  final int age;
  final double taille;
  final double poids;
  final String activite;
  final double tdee;
   final String? birthDate;

  AppUser({
    required this.uid,
    required this.prenom,
    required this.age,
    required this.taille,
    required this.poids,
    required this.activite,
    required this.tdee,
    this.birthDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'prenom': prenom,
      'age': age,
      'taille': taille,
      'poids': poids,
      'activite': activite,
      'tdee': tdee,
      'birthDate': birthDate,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'],
      prenom: map['prenom'],
      age: map['age'],
      taille: (map['taille'] ?? 0).toDouble(),
      poids: (map['poids'] ?? 0).toDouble(),
      activite: map['activite'],
      tdee: (map['tdee'] ?? 0).toDouble(),
      birthDate: map['birthDate'],
    );
  }
}
