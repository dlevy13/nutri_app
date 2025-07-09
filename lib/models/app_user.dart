//Utilitaires pour traitement de texte (normalisation, raccourcissement, etc.)

class AppUser {
  final String uid;
  final String name;
  final int age;
  final double height;
  final double weight;
  final String activityLevel;
  final double tdee;

  AppUser({
    required this.uid,
    required this.name,
    required this.age,
    required this.height,
    required this.weight,
    required this.activityLevel,
    required this.tdee,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'age': age,
      'height': height,
      'weight': weight,
      'activityLevel': activityLevel,
      'tdee': tdee,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'],
      name: map['name'],
      age: map['age'],
      height: (map['height'] ?? 0).toDouble(),
      weight: (map['weight'] ?? 0).toDouble(),
      activityLevel: map['activityLevel'],
      tdee: (map['tdee'] ?? 0).toDouble(),
    );
  }
}
