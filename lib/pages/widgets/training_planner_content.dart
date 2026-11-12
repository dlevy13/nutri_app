import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../training_planner/training_planner_state.dart';
import '../../ui/theme/app_theme.dart';
import '../../widget/adaptive_page_body.dart';
import '../../widget/card_shell.dart';

class TrainingPlannerContent extends StatelessWidget {
  final TrainingPlannerState state;
  final DateTime today;
  final ValueChanged<int> onChangeWeek;
  final VoidCallback onToday, onSync, onRetry;
  final void Function(String, String) onSelectActivity;
  const TrainingPlannerContent(
      {super.key,
      required this.state,
      required this.today,
      required this.onChangeWeek,
      required this.onToday,
      required this.onSync,
      required this.onRetry,
      required this.onSelectActivity});

  @override
  Widget build(BuildContext context) {
    final monday = DateTime(today.year, today.month,
        today.day - today.weekday + 1 + state.weekOffset * 7);
    final days = List.generate(
        7, (i) => DateTime(monday.year, monday.month, monday.day + i));
    final text = Theme.of(context).textTheme;
    return AdaptivePageBody(children: [
      Text('Mes entraînements', style: text.headlineLarge),
      const SizedBox(height: 8),
      Text('Prépare ta semaine et adapte tes besoins à tes efforts.',
          style: text.bodyLarge),
      const SizedBox(height: 24),
      CardShell(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
            '${DateFormat('d MMM', 'fr_FR').format(days.first)} – ${DateFormat('d MMM y', 'fr_FR').format(days.last)}',
            style: text.titleLarge),
        const SizedBox(height: 12),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton.outlined(
                  tooltip: 'Semaine précédente',
                  onPressed: () => onChangeWeek(-1),
                  icon: const Icon(Icons.chevron_left_rounded)),
              OutlinedButton.icon(
                  onPressed: onToday,
                  icon: const Icon(Icons.today_outlined),
                  label: const Text('Cette semaine')),
              IconButton.outlined(
                  tooltip: 'Semaine suivante',
                  onPressed: () => onChangeWeek(1),
                  icon: const Icon(Icons.chevron_right_rounded)),
              TextButton.icon(
                  onPressed:
                      state.status == PlannerStatus.loading ? null : onSync,
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Actualiser Garmin')),
            ]),
      ])),
      const SizedBox(height: 20),
      if (state.status == PlannerStatus.loading)
        const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()))
      else if (state.status == PlannerStatus.failure)
        CardShell(
            child: Column(children: [
          const Icon(Icons.cloud_off_outlined, size: 32),
          const SizedBox(height: 12),
          const Text('Le planning est indisponible pour le moment.',
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
        ]))
      else
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          final width =
              wide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
          return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: days.map((date) {
                // Preserve the key format used by the existing training repository.
                final key = '${date.year}-${date.month}-${date.day}';
                final events = state.garminEvents.where((e) =>
                    e['start'] is DateTime &&
                    DateUtils.isSameDay(e['start'] as DateTime, date));
                final isToday = DateUtils.isSameDay(date, today);
                return SizedBox(
                    width: width,
                    child: CardShell(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                    DateFormat('EEEE d MMMM', 'fr_FR')
                                        .format(date),
                                    style: text.titleMedium),
                                if (isToday)
                                  const Chip(
                                      label: Text('Aujourd’hui'),
                                      visualDensity: VisualDensity.compact),
                              ]),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            key: ValueKey('$key-${state.planning[key]}'),
                            initialValue: state.planning[key] ?? 'Repos',
                            isExpanded: true,
                            decoration: InputDecoration(
                                labelText:
                                    'Activité du ${DateFormat('d MMM', 'fr_FR').format(date)}',
                                prefixIcon:
                                    const Icon(Icons.directions_run_rounded)),
                            items: const [
                              'Repos',
                              'Endurance',
                              'Intensité',
                              'Affûtage'
                            ]
                                .map((v) =>
                                    DropdownMenuItem(value: v, child: Text(v)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) onSelectActivity(key, v);
                            },
                          ),
                          for (final event in events) ...[
                            const SizedBox(height: 12),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.event_outlined,
                                      color: AppColors.green, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(
                                          '${DateFormat.Hm('fr_FR').format(event['start'] as DateTime)} · ${event['summary'] ?? 'Entraînement Garmin'}',
                                          style: text.bodyMedium)),
                                ]),
                          ],
                        ])));
              }).toList());
        }),
    ]);
  }
}
