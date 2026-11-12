import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/date_service.dart';
import '../../ui/theme/app_theme.dart';
import '../../widget/card_shell.dart';
import '../dashboard_state.dart';

/// Présentation indépendante des services pour prévisualiser et vérifier le dashboard.
class DashboardContent extends StatelessWidget {
  final DashboardState state;
  final Widget journal;
  final Widget hydration;
  final Widget quality;
  final VoidCallback onAddMeal;
  final VoidCallback onTraining;
  final VoidCallback onToday;
  final VoidCallback onSync;
  final ValueChanged<int> onChangeWeek;
  final ValueChanged<DateTime> onSelectDate;

  const DashboardContent(
      {super.key,
      required this.state,
      required this.journal,
      required this.hydration,
      required this.quality,
      required this.onAddMeal,
      required this.onTraining,
      required this.onToday,
      required this.onSync,
      required this.onChangeWeek,
      required this.onSelectDate});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxWidth),
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 840;
          final secondary =
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            hydration,
            const SizedBox(height: AppLayout.gap),
            _MacroSummary(state: state, quality: quality),
          ]);
          final primary =
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _EnergySummary(state: state),
            const SizedBox(height: AppLayout.gap),
            Wrap(spacing: 12, runSpacing: 12, children: [
              FilledButton.icon(
                  onPressed: onAddMeal,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Ajouter un repas')),
              OutlinedButton.icon(
                  onPressed: onTraining,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Entraînement')),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: Text('Mon journal', style: text.titleLarge)),
              TextButton.icon(
                  onPressed: onSync,
                  icon: const Icon(Icons.sync_rounded, size: 20),
                  label: const Text('Strava')),
            ]),
            const SizedBox(height: 8),
            journal,
          ]);
          return Padding(
            padding:
                EdgeInsets.fromLTRB(wide ? 24 : 16, 16, wide ? 24 : 16, 32),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      state.prenom.trim().isEmpty
                          ? 'Bonjour !'
                          : 'Bonjour ${state.prenom.trim()} !',
                      style: text.headlineLarge),
                  const SizedBox(height: 4),
                  Text('Ta nutrition au rythme de tes efforts.',
                      style: text.bodyLarge?.copyWith(color: AppColors.muted)),
                  const SizedBox(height: 20),
                  _WeekSelector(
                      state: state,
                      onToday: onToday,
                      onChangeWeek: onChangeWeek,
                      onSelectDate: onSelectDate),
                  const SizedBox(height: 20),
                  Text(DateService.formatDayWithDate(state.selectedDate),
                      style: text.titleMedium),
                  const SizedBox(height: 12),
                  if (wide)
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: primary),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: secondary),
                        ])
                  else ...[primary, const SizedBox(height: 24), secondary],
                ]),
          );
        }),
      ),
    );
  }
}

class _WeekSelector extends StatelessWidget {
  final DashboardState state;
  final VoidCallback onToday;
  final ValueChanged<int> onChangeWeek;
  final ValueChanged<DateTime> onSelectDate;
  const _WeekSelector(
      {required this.state,
      required this.onToday,
      required this.onChangeWeek,
      required this.onSelectDate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final start = state.currentWeekStart;
    final dates = List.generate(
        7, (i) => DateTime(start.year, start.month, start.day + i));
    return CardShell(
      padding: const EdgeInsets.all(8),
      child: Column(children: [
        Row(children: [
          IconButton(
              tooltip: 'Semaine précédente',
              onPressed: () => onChangeWeek(-1),
              icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(
              child: Text(
                  '${DateFormat('d MMM', 'fr_FR').format(dates.first)} – ${DateFormat('d MMM y', 'fr_FR').format(dates.last)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge)),
          IconButton(
              tooltip: 'Semaine suivante',
              onPressed: () => onChangeWeek(1),
              icon: const Icon(Icons.chevron_right_rounded)),
          IconButton(
              tooltip: "Revenir à aujourd’hui",
              onPressed: onToday,
              icon: const Icon(Icons.today_outlined)),
        ]),
        Row(
            children: dates.map((date) {
          final selected = DateUtils.isSameDay(date, state.selectedDate);
          final hasMeals =
              (state.weeklyMeals[DateService.formatStandard(date)] ?? [])
                  .isNotEmpty;
          return Expanded(
              child: Semantics(
            selected: selected,
            label: DateService.formatDayWithDate(date),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Material(
                color: selected ? cs.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelectDate(date),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(children: [
                      Text(DateFormat('EEEEE', 'fr_FR').format(date),
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  selected ? cs.onPrimary : AppColors.muted)),
                      Text('${date.day}',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: selected ? cs.onPrimary : cs.onSurface)),
                      const SizedBox(height: 4),
                      Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasMeals
                                  ? (selected ? AppColors.lime : cs.primary)
                                  : Colors.transparent)),
                    ]),
                  ),
                ),
              ),
            ),
          ));
        }).toList()),
      ]),
    );
  }
}

class _EnergySummary extends StatelessWidget {
  final DashboardState state;
  const _EnergySummary({required this.state});

  @override
  Widget build(BuildContext context) {
    final consumed = state.consumedMacros['Calories'] ??
        state.dailyCaloriesForDay?.total ??
        0;
    final goal = state.macroNeeds['Calories'] ??
        state.dailyCaloriesForDay?.objectif ??
        0;
    final remaining = goal - consumed;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: AppColors.green,
          borderRadius: BorderRadius.circular(AppLayout.radius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.bolt_rounded, color: AppColors.lime),
          SizedBox(width: 8),
          Expanded(
              child: Text('MON ÉNERGIE',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontSize: 12)))
        ]),
        const SizedBox(height: 20),
        Text('${consumed.toStringAsFixed(0)} kcal',
            style: text.headlineLarge
                ?.copyWith(color: Colors.white, fontSize: 36)),
        Text(
            goal > 0
                ? 'consommées sur ${goal.toStringAsFixed(0)} kcal'
                : 'consommées · objectif à définir',
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        const SizedBox(height: 20),
        Semantics(
          label: 'Progression énergétique',
          child: LinearProgressIndicator(
              value: goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0,
              minHeight: 10,
              borderRadius: BorderRadius.circular(8),
              color: AppColors.lime,
              backgroundColor: Colors.white24),
        ),
        const SizedBox(height: 12),
        Text(
            goal <= 0
                ? 'Complète ton profil pour personnaliser ton objectif.'
                : remaining >= 0
                    ? '${remaining.toStringAsFixed(0)} kcal restantes'
                    : '${remaining.abs().toStringAsFixed(0)} kcal au-dessus de l’objectif',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        Wrap(spacing: 20, runSpacing: 8, children: [
          Text(
              'Base ajustée : ${(goal - state.stravaCaloriesForDay).clamp(0, double.infinity).toStringAsFixed(0)} kcal',
              style: const TextStyle(color: Colors.white, fontSize: 12)),
          Text(
              'Activité : ${state.stravaCaloriesForDay.toStringAsFixed(0)} kcal',
              style: const TextStyle(
                  color: AppColors.lime,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

class _MacroSummary extends StatelessWidget {
  final DashboardState state;
  final Widget quality;
  const _MacroSummary({required this.state, required this.quality});

  @override
  Widget build(BuildContext context) {
    const colors = [
      AppColors.green,
      AppColors.orange,
      AppColors.blue,
      Color(0xFF785399)
    ];
    const names = ['Protéines', 'Glucides', 'Lipides', 'Fibres'];
    return CardShell(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Mes nutriments', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 20),
      for (var i = 0; i < names.length; i++) ...[
        Builder(builder: (context) {
          final name = names[i];
          final consumed = state.consumedMacros[name] ?? 0;
          final goal = state.macroNeeds[name] ?? 0;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    children: [
                      Text(name,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                          '${consumed.toStringAsFixed(0)} / ${goal > 0 ? goal.toStringAsFixed(0) : '—'} g'),
                    ]),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                    value: goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0,
                    semanticsLabel:
                        '$name : ${consumed.toStringAsFixed(0)} grammes sur ${goal.toStringAsFixed(0)}',
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(8),
                    color: colors[i],
                    backgroundColor: colors[i].withValues(alpha: 0.12)),
              ]);
        }),
        const SizedBox(height: 20),
      ],
      ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('Qualité nutritionnelle'),
          children: [quality]),
    ]));
  }
}
