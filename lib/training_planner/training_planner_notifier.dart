import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/training_repository.dart'; 
import '../services/garmin_calendar_service.dart';
import 'training_planner_state.dart';


class TrainingPlannerNotifier extends StateNotifier<TrainingPlannerState> {
  final Ref _ref;
  late final TrainingRepository _trainingRepository = _ref.read(trainingRepositoryProvider);

  TrainingPlannerNotifier(this._ref) : super(const TrainingPlannerState()) {
    loadData();
  }

  Future<void> loadData() async {
    state = state.copyWith(status: PlannerStatus.loading);
    try {
      // On charge les deux sources de données en parallèle
      final results = await Future.wait([
        _trainingRepository.getFullPlanning(),
        GarminCalendarService.loadCalendar(forceRefresh: false),
      ]);
      
      final planning = results[0] as Map<String, String>;
      final garminEvents = results[1] as List<Map<String, dynamic>>;

      state = state.copyWith(
        status: PlannerStatus.success,
        planning: planning,
        garminEvents: garminEvents,
      );
    } catch (e) {
      //print("Erreur de chargement du planning: $e");
      state = state.copyWith(status: PlannerStatus.failure);
    }
  }

  /// Change la semaine affichée
  void changeWeek(int offset) {
    state = state.copyWith(weekOffset: state.weekOffset + offset);
  }

  /// Remet à la semaine actuelle
  void resetToToday() {
    state = state.copyWith(weekOffset: 0);
  }
  
  /// Sauvegarde une activité et met à jour l'état localement
  Future<void> selectActivity(String dayKey, String activity) async {
    // Met à jour l'UI instantanément
    final newPlanning = Map<String, String>.from(state.planning);
    newPlanning[dayKey] = activity;
    state = state.copyWith(planning: newPlanning);
    
    // Sauvegarde en arrière-plan
    await _trainingRepository.saveTraining(dayKey, activity);
  }
  
  /// Recharge les événements Garmin
  Future<void> reloadGarminEvents() async {
    state = state.copyWith(status: PlannerStatus.loading);
    try {
      final garminEvents = await GarminCalendarService.loadCalendar(forceRefresh: true);
      state = state.copyWith(status: PlannerStatus.success, garminEvents: garminEvents);
    } catch (e) {
      state = state.copyWith(status: PlannerStatus.failure);
    }
  }
}

// Le provider pour ce notifier
final trainingPlannerProvider = StateNotifierProvider.autoDispose<TrainingPlannerNotifier, TrainingPlannerState>(
  (ref) => TrainingPlannerNotifier(ref),
);