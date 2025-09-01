import 'package:cloud_firestore/cloud_firestore.dart';
class PoidsUsuelsRepository {
  final FirebaseFirestore _db;
  PoidsUsuelsRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('missing_poids_usuels');

  String slugify(String input) {
    final lower = input.toLowerCase().trim();
    final replaced = lower
        .replaceAll(RegExp(r"[^\p{L}\p{N}\s-]", unicode: true), "")
        .replaceAll(RegExp(r"\s+"), "-")
        .replaceAll(RegExp(r"-+"), "-");
    return replaced.isEmpty ? "unknown" : replaced;
  }

  Future<void> addMissingIfNeeded(String rawName) async {
  final name = rawName.trim();
  if (name.isEmpty) return;

  try {
    await FirebaseFirestore.instance
        .collection('missing_poids_usuels')
        .add({
          'name': name,
          'createdAt': FieldValue.serverTimestamp(),
        });
  } catch (e) {
    print('missing_poids_usuels create failed: $e');
  }
}

}
