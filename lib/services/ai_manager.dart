import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../services/date_service.dart';
import '../services/analysis_cache_service.dart';
import '../services/fonctions.dart'; // analyzeMealsLocal
import '../services/ai_service.dart';
import '../models/meal.dart';
import '/log.dart';
//refonte
class AIManager {
  final AIService apiService;
  final AnalysisCacheService cacheService;

  AIManager({
    required this.apiService,
    required this.cacheService,
  });

  // ===========================================================================
  //  PUBLIC : GET OR GENERATE
  // ===========================================================================

  Future<String> getOrGenerateAnalysis(
    String dateKey,
    Map<String, dynamic> mealsData, {
    bool preferApi = false,
    bool force = false,
    String provider = "mistral",
  }) async {

    final cleanKey = dateKey.replaceAll('/', '-');
    final latestKey = "latest:$cleanKey";

    logger.d("🧭 getOrGenerateAnalysis($cleanKey)");

    // -------------------------------------------------------
    // 1) Préparer payload + hash
    // -------------------------------------------------------
    final payload = _buildBackendPayload(dateKey, mealsData);
    final normalized = payload["data"] as List<Map<String, dynamic>>;

    final hash = _sha256(_stableStringify(normalized));

    // -------------------------------------------------------
    // 2) Lire cache
    // -------------------------------------------------------
    if (!force) {
      final cached = await cacheService.getCachedAnalysis(latestKey);
      if (cached != null && cached.isNotEmpty) {
        try {
          final map = jsonDecode(cached);
          final cachedHash = map["input_hash"];
          final analysis = map["analysis"];

          if (cachedHash == hash && analysis != null && analysis.toString().isNotEmpty) {
            logger.d("📀 Cache hit (hash identique) → $latestKey");
            return analysis;
          }
        } catch (_) {
          logger.w("⚠️ Cache invalide, recalcul…");
        }
      }
    }

    // -------------------------------------------------------
    // 3) Génération : API → fallback local
    // -------------------------------------------------------
    String source = "local";
    String finalAnalysis;

    Future<String> tryApi() async {
      final res = await apiService.analyzeMealsViaBackend(payload, provider: provider);
      source = "api";
      return res;
    }

    Future<String> tryLocal() async {
      source = "local";
      return analyzeMealsLocal(mealsData);
    }

    try {
      if (preferApi) {
        finalAnalysis = await tryApi();
      } else {
        try {
          finalAnalysis = await tryApi();
        } catch (e) {
          logger.w("API KO → fallback local : $e");
          finalAnalysis = await tryLocal();
        }
      }
    } catch (_) {
      finalAnalysis = await tryLocal();
    }

    // -------------------------------------------------------
    // 4) Sauvegarde cache (local only)
    // -------------------------------------------------------
    final wrapped = jsonEncode({
      "analysis": finalAnalysis,
      "input_hash": hash,
      "source": source,
      "updated_at": DateTime.now().toIso8601String(),
    });

    await cacheService.saveAnalysis(latestKey, wrapped);

    return finalAnalysis;
  }

  // ===========================================================================
  //  PAYLOAD
  // ===========================================================================

  Map<String, dynamic> _buildBackendPayload(
    String dateKey,
    Map<String, dynamic> mealsData,
  ) {
    final base = dateKey.replaceAll('/', '-');

    late String scope;
    String? weekKey;
    String? dayKey;

    if (base.startsWith("week_")) {
      scope = "week";
      weekKey = DateService.toBackendWeekKey(base);
    } else {
      scope = "day";
      dayKey = DateService.toBackendDayKey(base);
    }

    final extracted = _extractMeals(mealsData);
    final normalized = _normalizeMeals(extracted);

    return {
      "scope": scope,
      if (weekKey != null) "weekKey": weekKey,
      if (dayKey != null) "dayKey": dayKey,
      "data": normalized,
    };
  }

  // ===========================================================================
  //  EXTRACTION COMPAT MAP + HIVE
  // ===========================================================================

  List<Map<String, dynamic>> _extractMeals(Object? mealsData) {
    if (mealsData is List<Meal>) {
      return mealsData.map(_mealToMap).toList();
    }

    if (mealsData is Map<String, List<Meal>>) {
      return mealsData.values.expand((m) => m.map(_mealToMap)).toList();
    }

    if (mealsData is List) {
      return mealsData
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (mealsData is Map) {
      final raw = mealsData["meals"] ?? mealsData["data"];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _mealToMap(Meal m) {
    return {
      "name": m.name,
      "calories": m.calories,
      "protein": m.protein,
      "carbs": m.carbs,
      "fat": m.fat,
      "time": m.timestamp,
    };
  }

  // ===========================================================================
  //  NORMALISATION
  // ===========================================================================

  List<Map<String, dynamic>> _normalizeMeals(List<Map<String, dynamic>> meals) {
    return meals.map((m) {
      return {
        "name": m["name"],
        "calories": m["calories"],
        if (m["protein"] != null) "protein": m["protein"],
        if (m["carbs"] != null) "carbs": m["carbs"],
        if (m["fat"] != null) "fat": m["fat"],
        if (m["time"] != null) "time": m["time"],
      };
    }).toList();
  }

  // ===========================================================================
  //  HASH STABLE
  // ===========================================================================

  String _stableStringify(dynamic input) {
    dynamic normalize(dynamic v) {
      if (v == null) return null;
      if (v is num) return (v * 1000).round() / 1000;
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