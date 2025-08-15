import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/common_providers.dart';

class TrainingRepository {
  final SharedPreferences _prefs;

  TrainingRepository(this._prefs);

  /// Récupère le type d'entraînement pour une date donnée.
  Future<String> getTrainingTypeForDate(DateTime date) async {
    final String dayKey = "${date.year}-${date.month}-${date.day}";
    return _prefs.getString("plan_$dayKey") ?? "Repos";
  }

  // =======================================================================
  // == NOUVELLES MÉTHODES POUR LA PAGE DE PLANNING
  // =======================================================================

  /// ✅ Récupère l'intégralité du planning depuis SharedPreferences.
  Future<Map<String, String>> getFullPlanning() async {
    final Map<String, String> planning = {};
    
    // On parcourt toutes les clés pour trouver celles du planning
    final planKeys = _prefs.getKeys().where((key) => key.startsWith('plan_'));
    
    for (var key in planKeys) {
      final dateKey = key.replaceFirst('plan_', '');
      planning[dateKey] = _prefs.getString(key) ?? 'Repos';
    }
    
    return planning;
  }

  /// ✅ Sauvegarde un type d'entraînement pour un jour donné.
  Future<void> saveTraining(String dayKey, String activity) async {
    await _prefs.setString('plan_$dayKey', activity);
  }
}

// --- Providers Riverpod ---


// Le provider pour notre TrainingRepository.
final trainingRepositoryProvider = Provider((ref) {
  return TrainingRepository(ref.watch(sharedPreferencesProvider));
});