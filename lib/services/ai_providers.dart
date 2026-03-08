// dans lib/services/ai_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_manager.dart';
import '../services/ai_service.dart';
import '../services/analysis_cache_service.dart';
//refonte
/// Service pour appeler l’API (ou backend)
final aiServiceProvider = Provider((ref) => AIService());

/// Service local pour gérer le cache de l'analyse
final analysisCacheProvider = Provider((ref) => AnalysisCacheService());

/// Manager central qui combine l’API + le cache + les normalisations
final aiManagerProvider = Provider((ref) {
  return AIManager(
    apiService: ref.watch(aiServiceProvider),
    cacheService: ref.watch(analysisCacheProvider),
  );
});
