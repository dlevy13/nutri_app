
class AlimentUsuel {
  final String aliment;
  final String groupe;
  final double poids;
  final String unite;
  final String commentaire;

  AlimentUsuel({
    required this.aliment,
    required this.groupe,
    required this.poids,
    required this.unite,
    required this.commentaire,
  });

  // Le constructeur fromJson a été rendu plus robuste
  factory AlimentUsuel.fromJson(Map<String, dynamic> json) {
    return AlimentUsuel(
      // L'opérateur '??' signifie : "utilise la valeur de gauche si elle n'est pas nulle, sinon utilise celle de droite".
      aliment: json['aliment'] as String? ?? 'Aliment inconnu',
      groupe: json['groupe'] as String? ?? '',
      poids: (json['poids'] as num? ?? 0).toDouble(),
      unite: json['unite'] as String? ?? 'g',
      commentaire: json['commentaire'] as String? ?? '',
    );
  }
}
