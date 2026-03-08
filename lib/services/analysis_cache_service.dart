
import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/analysis.dart';

//refonte
/// 🔥 Service de cache 100% local (Hive)
/// ------------------------------------------------------------
/// Chaque analyse est stockée sous forme de JSON string :
/// {
///   "analysis": "...",
///   "input_hash": "...",
///   "source": "api/local",
///   "updated_at": "2025-01-01T12:00:00"
/// }
///
/// Le backend Cloud Function garde sa logique séparée.
/// Ici : seulement du stockage local et rapide.
class AnalysisCacheService {
  final Box<Analysis> hiveBox = Hive.box<Analysis>('analyses');

  // ------------------------------------------------------------
  // UTILS
  // ------------------------------------------------------------

  String _safeId(String key) => key.replaceAll('/', '-');

  // ------------------------------------------------------------
  // HIVE : READ
  // ------------------------------------------------------------

  String? getFromHive(String key) {
    final id = _safeId(key);
    final row = hiveBox.get(id);
    return row?.result; // JSON string {analysis,input_hash,...}
  }

  // ------------------------------------------------------------
  // HIVE : WRITE
  // ------------------------------------------------------------

  Future<void> saveToHive(String key, String jsonString) async {
    final id = _safeId(key);
    final row = Analysis(
      date: id,
      result: jsonString,
      createdAt: DateTime.now(),
    );
    await hiveBox.put(id, row);
  }

  Future<void> removeFromHive(String key) async {
    final id = _safeId(key);
    await hiveBox.delete(id);
  }

  // ------------------------------------------------------------
  // API PUBLIQUE — Récupération du cache
  // ------------------------------------------------------------

  Future<String?> getCachedAnalysis(String key) async {
    final id = _safeId(key);

    // 1) Hive local
    final local = getFromHive(id);
    if (local != null) {

      return local;
    }


    return null;
  }

  // ------------------------------------------------------------
  // API PUBLIQUE — Sauvegarde du cache
  // ------------------------------------------------------------

  Future<void> saveAnalysis(String key, String jsonString) async {
    await saveToHive(key, jsonString);

    // 🧹 purge automatique
    await purgeOldCache();
  }

  // ------------------------------------------------------------
  // PURGE AUTOMATIQUE (on garde seulement 30 jours)
  // ------------------------------------------------------------

  Future<void> purgeOldCache() async {
    final now = DateTime.now();
    final keysToDelete = <String>[];

    for (final key in hiveBox.keys) {
      final analysis = hiveBox.get(key);

      if (analysis == null) continue;

      final ageDays = now.difference(analysis.createdAt).inDays;

      if (ageDays > 30) {
        keysToDelete.add(key.toString());
      }
    }

    // Supprimer les vieilles entrées
    for (final k in keysToDelete) {
      await hiveBox.delete(k);
    }

    if (keysToDelete.isNotEmpty) {
          }
  }

  // ------------------------------------------------------------
  // UTILITAIRES
  // ------------------------------------------------------------

  Future<void> invalidateLocal(String key) async {
    await removeFromHive(key);
  }

  Future<void> clearLocalAll() async {
    await hiveBox.clear();
  }
}