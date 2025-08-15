import '../services/analysis_cache_service.dart';
import '../services/fonctions.dart'; // analyzeMealsViaBackend / analyzeMealsLocal
import '../services/ai_service.dart'; 

import '/log.dart';

class AIManager {
  final AnalysisCacheService cache = AnalysisCacheService();
  final AIService apiService;
  final AnalysisCacheService cacheService;
  AIManager({required this.apiService, required this.cacheService});

  /// [preferApi] : tente l’API en priorité (fallback local si échec)
  /// [force]     : ignore le cache et recalcule
  /// [provider]  : "mistral" ou "openai"
  /// [cacheBySource] : si true, enregistre aussi sous api:date / local:date
  Future<String> getOrGenerateAnalysis(
    String dateKey,
    Map<String, dynamic> mealsData, {
    bool preferApi = false,
    bool force = false,
    String provider = "mistral",
    bool cacheBySource = true,
  }) async {
    final baseKey = dateKey.replaceAll('/', '-');
    final latestKey = "latest:$baseKey";

    logger.d("🧭 getOrGenerateAnalysis(key=$baseKey, preferApi=$preferApi, force=$force)");

    // 1) Cache (clé "latest") si pas forcé
    if (!force) {
      final cached = await cacheService.getCachedAnalysis(latestKey);
      if (cached != null && cached.isNotEmpty) {
        logger.d("📀 Cache hit → $latestKey");
        return cached;
      }
    } else {
      logger.d("⛔ force=true → ignore cache");
    }

    // 2) Calcul (API → fallback local)
    String analysis;
    String source = "local";

    Future<String> tryApi() async {
      logger.i("🌐 Tentative API (provider=$provider)...");
     final txt = await apiService.analyzeMealsViaBackend(mealsData, provider: provider);
      source = "api";
      return txt;
    }

    Future<String> tryLocal() async {
      logger.i("🧮 Analyse locale...");
      source = "local";
      return await analyzeMealsLocal(mealsData);
    }

    try {
      if (preferApi) {
        // API d’abord
        analysis = await tryApi();
      } else {
        // AUTO : tente API, sinon local
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

    // 3) Sauvegarde
   await cache.saveAnalysis(baseKey, analysis);



    return analysis;
  }
}
