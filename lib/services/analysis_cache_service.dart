
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import '../models/analysis.dart';
import '/log.dart';

class AnalysisCacheService {
  final Box<Analysis> hiveBox = Hive.box<Analysis>('analyses');

  /// ✅ Utilitaire : génère un ID Firestore sûr
  String _safeId(String date) {
    // Firestore interdit '/' → remplace par '-'
    return date.replaceAll('/', '-');
  }

  /// ✅ Récupère depuis Hive
  String? getFromHive(String date) {
    final analysis = hiveBox.get(_safeId(date));
    return analysis?.result;
  }

  /// ✅ Sauvegarde dans Hive
  Future<void> saveToHive(String date, String result) async {
    final id = _safeId(date);
    final analysis = Analysis(date: id, result: result, createdAt: DateTime.now());
    await hiveBox.put(id, analysis);
  }

  /// ✅ Récupère depuis Firestore
  Future<String?> getFromFirestore(String date) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final id = _safeId(date);
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('analyses')
        .doc(id)
        .get();

    return doc.exists ? doc['result'] : null;
  }

  /// ✅ Sauvegarde dans Firestore
  Future<void> saveToFirestore(String date, String result) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final id = _safeId(date);
    print("📡 Firestore → save users/$uid/analyses/$id");

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('analyses')
        .doc(id)
        .set({
          'result': result,
          'createdAt': DateTime.now().toIso8601String(),
        });
  }

  /// ✅ Récupère depuis cache (Hive → Firestore)
  Future<String?> getCachedAnalysis(String date) async {
    final id = _safeId(date);

    // 🔹 1. Essaye Hive
    final local = getFromHive(id);
    if (local != null) {
      logger.d("✅ Analyse trouvée en cache Hive ($id)");
      return local;
    }

    // 🔹 2. Essaye Firestore
    final remote = await getFromFirestore(id);
    if (remote != null) {
      logger.d("✅ Analyse trouvée dans Firestore ($id), mise en cache Hive");
      await saveToHive(id, remote);
      return remote;
    }

    logger.d("❌ Aucune analyse trouvée pour $id");
    return null;
  }

  /// ✅ Sauvegarde dans Hive + Firestore
  Future<void> saveAnalysis(String date, String result) async {
    final id = _safeId(date);
    await saveToHive(id, result);
    await saveToFirestore(id, result);
  }
}
