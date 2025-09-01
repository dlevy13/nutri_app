import 'dart:convert';
import 'package:crypto/crypto.dart';
 import '../services/date_service.dart'; // assure-toi de l'import
import '../services/analysis_cache_service.dart';
import '../services/fonctions.dart'; // analyzeMealsLocal
import '../services/ai_service.dart';
import '/log.dart';

class AIManager {
  final AIService apiService;
  final AnalysisCacheService cacheService;

  AIManager({required this.apiService, required this.cacheService});

  /// [dateKey] : "week_YYYY-MM-DD" ou "DD-MM-YYYY"
  /// [preferApi] : tente l’API en priorité (fallback local si échec)
  /// [force]     : ignore le cache et recalcule
  /// [provider]  : "mistral" ou "openai" (actuellement ignoré côté backend)
  /// [cacheBySource] : si true, enregistre aussi sous api:<date> / local:<date>
  Future<String> getOrGenerateAnalysis(
    String dateKey,
    Map<String, dynamic> mealsData, {
    bool preferApi = false,
    bool force = false,
    String provider = "mistral",
    bool cacheBySource = true,
  }) async {
    final baseKey = dateKey.replaceAll('/', '-');          // ex: week_2025-08-11 ou 25-08-2025
    final latestKey = "latest:$baseKey";

    logger.d("🧭 getOrGenerateAnalysis(key=$baseKey, preferApi=$preferApi, force=$force)");

    // --- 0) Construire le payload EXACT pour le backend (scope/clé + data normalisée) ---
    final backendPayload = _buildBackendPayload(dateKey, mealsData);
    final List<Map<String, dynamic>> normalizedData = backendPayload["data"] as List<Map<String, dynamic>>;

    // Hash identique au backend : basé uniquement sur la DATA normalisée
    final payloadStr = _stableStringify(normalizedData);
    final inputHash  = _sha256(payloadStr);

    // --- 1) Lecture du cache si pas forcé ---
    if (!force) {
      final cached = await cacheService.getCachedAnalysis(latestKey);
      if (cached != null && cached.isNotEmpty) {
        try {
          final cachedJson = jsonDecode(cached) as Map<String, dynamic>;
          final cachedHash = cachedJson["input_hash"] as String?;
          final cachedAnalysis = cachedJson["analysis"] as String?;
          if (cachedHash == inputHash && cachedAnalysis != null && cachedAnalysis.isNotEmpty) {
            logger.d("📀 Cache hit avec hash identique → $latestKey");
            return cachedAnalysis;
          } else {
            logger.d("↪️ Cache présent mais hash différent → recalcul");
          }
        } catch (_) {
          logger.w("⚠️ Cache existant invalide ou ancien format → recalcul");
        }
      }
    } else {
      logger.d("⛔ force=true → ignore cache");
    }

    // --- 2) Génération (API → fallback local) ---
    String analysis;
    String source = "local";

    Future<String> tryApi() async {
      logger.i("🌐 Tentative API (provider=$provider)...");
      // IMPORTANT : on envoie exactement le payload backend (scope/keys/data)
      final txt = await apiService.analyzeMealsViaBackend(backendPayload, provider: provider);
      source = "api";
      return txt;
    }

    Future<String> tryLocal() async {
      logger.i("🧮 Analyse locale...");
      source = "local";
      // La version locale attend le brut (si besoin, adapte analyzeMealsLocal pour utiliser normalizedData)
      return await analyzeMealsLocal(mealsData);
    }

    try {
      if (preferApi) {
        analysis = await tryApi();
      } else {
        try {
          analysis = await tryApi();
        } catch (e) {
          logger.w("API KO en mode AUTO → fallback local : $e");
          analysis = await tryLocal();
        }
      }
    } catch (e, st) {
      logger.w("API KO (mode FORCÉ) → fallback local : $e", stackTrace: st);
      analysis = await tryLocal();
    }

    // --- 3) Sauvegarde : on stocke analyse + hash courant ---
    final wrapped = jsonEncode({
      "analysis": analysis,
      "input_hash": inputHash,
      "source": source,
      "updated_at": DateTime.now().toIso8601String(),
    });

    await cacheService.saveAnalysis(latestKey, wrapped);
    logger.d("💾 Cache écrit/écrasé → $latestKey");

    if (cacheBySource) {
      final sourceKey = "$source:$baseKey";
      await cacheService.saveAnalysis(sourceKey, wrapped);
      logger.d("🗂️  Cache source écrit → $sourceKey");
    }

    return analysis;
  }

  // ---------- Helpers ----------

  /// Déduit scope + clé Firestore à partir de dateKey, et prépare DATA normalisée.
  /// - dateKey "week_YYYY-MM-DD"  → scope="week", weekKey="YYYY-MM-DD"
  /// - dateKey "DD-MM-YYYY"       → scope="day",  dayKey="DD-MM-YYYY"
  /// mealsData peut être une List ou un Map contenant 'meals' ou 'data'
 

Map<String, dynamic> _buildBackendPayload(String dateKey, Map<String, dynamic> mealsData) {
  final baseKey = dateKey.replaceAll('/', '-'); // hygiène

  late final String scope;
  String? weekKey; // "YYYY-MM-DD" pour le backend
  String? dayKey;  // "DD-MM-YYYY" pour le backend

  if (baseKey.startsWith("week_")) {
    scope = "week";
    weekKey = DateService.toBackendWeekKey(baseKey);
  } else {
    scope = "day";
    dayKey = DateService.toBackendDayKey(baseKey);
  }

  final dataList = _extractMeals(mealsData);
  final normalized = _normalizeMeals(dataList);

  return {
    "scope": scope,
    if (weekKey != null) "weekKey": weekKey,
    if (dayKey  != null) "dayKey": dayKey,
    "data": normalized,
  };
}


  /// Extrait la liste de repas depuis mealsData (souple : List directe ou Map avec meals/data)
 List<Map<String, dynamic>> _extractMeals(Object? mealsData) {
  if (mealsData is List) {
    return mealsData
        .whereType<Map>()
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  if (mealsData is Map) {
    final raw = mealsData["meals"] ?? mealsData["data"];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    final days = mealsData["jours"] ?? mealsData["days"];
    if (days is List) {
      final out = <Map<String, dynamic>>[];
      for (final d in days.whereType<Map>()) {
        final repas = d["repas"] ?? d["meals"];
        if (repas is List) {
          for (final m in repas.whereType<Map>()) {
            out.add(Map<String, dynamic>.from(m));
          }
        }
      }
      return out;
    }
    // 4) 🔧 Format journalier: 'jour'/'day' -> 'repas'/'meals'
  final oneDay = mealsData["jour"] ?? mealsData["day"];
  if (oneDay is Map) {
    final repas = oneDay["repas"] ?? oneDay["meals"];
    if (repas is List) {
      return repas
          .whereType<Map>()
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }
  }

  return <Map<String, dynamic>>[];
}


  /// Ne garder que les champs utiles et stabiliser les nombres (comme backend)
  List<Map<String, dynamic>> _normalizeMeals(List<Map<String, dynamic>> meals) {
    return meals.map((m) {
      final mm = Map<String, dynamic>.from(m);
      return {
        "name": mm["name"],
        "calories": mm["calories"],
        if (mm["protein"] != null) "protein": mm["protein"],
        if (mm["carbs"]   != null) "carbs":   mm["carbs"],
        if (mm["fat"]     != null) "fat":     mm["fat"],
        if (mm["time"]    != null) "time":    mm["time"],
      };
    }).toList();
  }

  // Stable stringify = tri des clés récursif + arrondi 3 décimales (aligné backend)
  String _stableStringify(dynamic input) {
    dynamic normalize(dynamic v) {
      if (v == null) return null;
      if (v is num) return (v * 1000).round() / 1000;     // 3 décimales
      if (v is List) return v.map(normalize).toList();
      if (v is Map) {
        final out = <String, dynamic>{};
        final keys = v.keys.map((e) => e.toString()).toList()..sort();
        for (final k in keys) {
          out[k] = normalize(v[k]);
        }
        return out;
      }
      return v;
    }
    return jsonEncode(normalize(input));
  }

  String _sha256(String s) => sha256.convert(utf8.encode(s)).toString();
}
