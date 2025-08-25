class CustomFood {
  final String id; // docId Firestore
  final String name;
  final double kcalPer100;
  final double proteinPer100;
  final double carbsPer100;
  final double fatPer100;
  final String? imageUrl;

  CustomFood({
    required this.id,
    required this.name,
    required this.kcalPer100,
    required this.proteinPer100,
    required this.carbsPer100,
    required this.fatPer100,
    this.imageUrl,
  });

  factory CustomFood.fromMap(Map<String, dynamic> data, String id) {
    return CustomFood(
      id: id,
      name: data['name'] ?? '',
      kcalPer100: (data['kcalPer100'] ?? 0).toDouble(),
      proteinPer100: (data['proteinPer100'] ?? 0).toDouble(),
      carbsPer100: (data['carbsPer100'] ?? 0).toDouble(),
      fatPer100: (data['fatPer100'] ?? 0).toDouble(),
      imageUrl: data['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'kcalPer100': kcalPer100,
        'proteinPer100': proteinPer100,
        'carbsPer100': carbsPer100,
        'fatPer100': fatPer100,
        'imageUrl': imageUrl,
      };
}
