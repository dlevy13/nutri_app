
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import '../models/analysis.dart';
import '/log.dart';

/// Service de cache pour les analyses.
/// - Source de vérité IA (serveur) : users/{uid}/analyses/{docId} (WRITE = Functions only)
/// - Cache client sync : users/{uid}/analyses_client_cache/{docId} (READ/WRITE app)
/// - Cache local rapide : Hive (box 'analyses'), valeur = JSON string {analysis,input_hash,source,updated_at}
class AnalysisCacheService {
  final Box<Analysis> hiveBox = Hive.box<Analysis>('analyses');

  // ---------- Utils clés ----------
  String _safeId(String key) => key.replaceAll('/', '-');

  /// Extrait un docId serveur valide depuis une clé applicative.
  /// - "latest:week_2025-08-11" -> "week_2025-08-11"
  /// - "latest:25-08-2025"      -> "25-08-2025"
  /// - "week_2025-08-11"        -> idem
  /// - "25-08-2025"             -> idem
  String? _extractServerDocId(String key) {
    final k = _safeId(key);
    final latestPrefix = 'latest:';
    final base = k.startsWith(latestPrefix) ? k.substring(latestPrefix.length) : k;

    final isWeek = RegExp(r'^week_\d{4}-\d{2}-\d{2}$').hasMatch(base);
    final isDay  = RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(base);
    if (isWeek || isDay) return base;
    return null; // la clé ne mappe pas un docId serveur
  }

  /// Access Firestore helpers
  FirebaseFirestore get _fs => FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ---------- HIVE ----------
  String? getFromHive(String key) {
    final id = _safeId(key);
    final row = hiveBox.get(id);
    return row?.result; // JSON string
  }

  Future<void> saveToHive(String key, String jsonString) async {
    final id = _safeId(key);
    final row = Analysis(date: id, result: jsonString, createdAt: DateTime.now());
    await hiveBox.put(id, row);
  }

  Future<void> removeFromHive(String key) async {
    final id = _safeId(key);
    await hiveBox.delete(id);
  }

  // ---------- FIRESTORE (READ — serveur) ----------
  /// Lit users/{uid}/analyses/{docId} et renvoie un JSON string {analysis,input_hash,...}
  Future<String?> _readServerAnalysis(String serverDocId) async {
    final uid = _uid;
    if (uid == null) return null;

    final doc = await _fs
        .collection('users').doc(uid)
        .collection('analyses').doc(serverDocId)
        .get();

    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;

    final analysis  = data['analysis'];
    final inputHash = data['input_hash'];
    final updatedAt = data['updated_at'];
    final scope     = data['scope'];
    final model     = data['model'];

    if (analysis is String && analysis.isNotEmpty) {
      // Format standardisé pour l’app (wrapper JSON string)
      return jsonEncode({
        "analysis": analysis,
        "input_hash": inputHash ?? "",
        "source": "server",
        "updated_at": updatedAt,
        "scope": scope,
        "model": model,
      });
    }

    // Compat ancien format éventuel
    if (data['result'] is String) {
      return jsonEncode({
        "analysis": data['result'],
        "input_hash": "",
        "source": "server-legacy",
        "updated_at": updatedAt ?? data['createdAt'],
      });
    }

    return null;
  }

  // ---------- FIRESTORE (READ/WRITE — cache client sync) ----------
  /// Lit users/{uid}/analyses_client_cache/{docId} (clé applicative acceptée)
  Future<String?> _readClientCache(String key) async {
    final uid = _uid;
    if (uid == null) return null;

    final id = _safeId(key);
    final doc = await _fs
        .collection('users').doc(uid)
        .collection('analyses_client_cache').doc(id)
        .get();

    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;

    // on stocke dans ce champ notre JSON string
    final stored = data['result_json'];
    if (stored is String && stored.isNotEmpty) {
      return stored;
    }

    // Compat format brut
    final analysis = data['analysis'];
    final inputHash = data['input_hash'];
    if (analysis is String && analysis.isNotEmpty) {
      return jsonEncode({
        "analysis": analysis,
        "input_hash": inputHash ?? "",
        "source": "client-local",
        "updated_at": data['updated_at'],
      });
    }

    return null;
  }

  /// Écrit/merge users/{uid}/analyses_client_cache/{docId} avec un JSON string
  Future<void> saveToClientCache(String key, String jsonString) async {
    final uid = _uid;
    if (uid == null) return;

    final id = _safeId(key);
    await _fs
        .collection('users').doc(uid)
        .collection('analyses_client_cache').doc(id)
        .set({
          'result_json': jsonString,                      // JSON string complet
          'updated_at': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
  }

  // ---------- API publique ----------
  /// Lecture unifiée :
  /// 1) Hive → 2) Serveur analyses → 3) Cache client sync
  /// Retourne toujours un JSON string {analysis,input_hash,source,updated_at}
  Future<String?> getCachedAnalysis(String key) async {
    final id = _safeId(key);

    // 1) Hive
    final fromHive = getFromHive(id);
    if (fromHive != null) {
      logger.d("✅ Cache Hive hit: $id");
      return fromHive;
    }

    // 2) Serveur
    final serverDocId = _extractServerDocId(id);
    if (serverDocId != null) {
      final fromServer = await _readServerAnalysis(serverDocId);
      if (fromServer != null) {
        logger.d("✅ Cache serveur hit: users/{uid}/analyses/$serverDocId → Hive($id)");
        await saveToHive(id, fromServer);
        return fromServer;
      }
    }

    // 3) Cache client sync
    final fromClient = await _readClientCache(id);
    if (fromClient != null) {
      logger.d("✅ Cache client sync hit: analyses_client_cache/$id → Hive($id)");
      await saveToHive(id, fromClient);
      return fromClient;
    }

    logger.d("❌ Aucun cache pour $id");
    return null;
  }

  /// Écriture côté app :
  /// - Écrit en local (Hive)
  /// - Optionnel : copie dans Firestore client sync (analyses_client_cache)
  ///
  /// ⚠️ Ne JAMAIS écrire dans users/{uid}/analyses ici (réservé au serveur).
  Future<void> saveAnalysis(String key, String jsonString, {bool syncToFirestore = true}) async {
    final id = _safeId(key);
    await saveToHive(id, jsonString);
    if (syncToFirestore) {
      await saveToClientCache(id, jsonString);
    }
  }

  /// Purge locale d’une clé (utile si tu veux forcer une relecture serveur)
  Future<void> invalidateLocal(String key) async {
    await removeFromHive(key);
  }

  /// Purge totale locale (attention !)
  Future<void> clearLocalAll() async {
    await hiveBox.clear();
  }
}
