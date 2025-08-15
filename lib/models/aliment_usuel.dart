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

  factory AlimentUsuel.fromJson(Map<String, dynamic> json) {
    return AlimentUsuel(
      aliment: json['aliment'],
      groupe: json['groupe'],
      poids: (json['poids'] as num).toDouble(),
      unite: json['unite'],
      commentaire: json['commentaire'],
    );
  }
}
