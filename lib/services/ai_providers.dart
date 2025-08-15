// dans lib/services/ai_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_manager.dart';
import '../services/ai_service.dart';
import '../services/analysis_cache_service.dart'; // Ce service gère la mise en cache

// Provider pour le service de base qui appelle Firebase
final aiServiceProvider = Provider((ref) => AIService());

// Provider pour le service de cache (suppose que vous avez ce fichier)
final analysisCacheProvider = Provider((ref) => AnalysisCacheService());

// Provider pour le manager, qui dépend des deux autres
final aiManagerProvider = Provider((ref) {
  return AIManager(
    // Ici, on injecte les dépendances.
    // Votre AIManager devra être légèrement modifié pour accepter ces services
    // via son constructeur au lieu de les instancier lui-même.
    apiService: ref.watch(aiServiceProvider),
    cacheService: ref.watch(analysisCacheProvider),
  );
});