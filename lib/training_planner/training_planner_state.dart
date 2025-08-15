import 'package:equatable/equatable.dart';

enum PlannerStatus { loading, success, failure }

class TrainingPlannerState extends Equatable {
  final PlannerStatus status;
  final int weekOffset;
  final Map<String, String> planning; // Les activités sélectionnées
  final List<Map<String, dynamic>> garminEvents; // Les événements Garmin

  const TrainingPlannerState({
    this.status = PlannerStatus.loading,
    this.weekOffset = 0,
    this.planning = const {},
    this.garminEvents = const [],
  });

  TrainingPlannerState copyWith({
    PlannerStatus? status,
    int? weekOffset,
    Map<String, String>? planning,
    List<Map<String, dynamic>>? garminEvents,
  }) {
    return TrainingPlannerState(
      status: status ?? this.status,
      weekOffset: weekOffset ?? this.weekOffset,
      planning: planning ?? this.planning,
      garminEvents: garminEvents ?? this.garminEvents,
    );
  }

  @override
  List<Object?> get props => [status, weekOffset, planning, garminEvents];
}