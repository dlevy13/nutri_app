import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nutri_app/dashboard/dashboard_state.dart';
import 'package:nutri_app/dashboard/widgets/dashboard_content.dart';
import 'package:nutri_app/dashboard/widgets/hydration_summary.dart';
import 'package:nutri_app/ui/theme/app_theme.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));
  final day = DateTime(2026, 11, 12);
  DashboardState data({bool noGoal = false, double calories = 1850}) =>
      DashboardState(
        selectedDate: day,
        currentWeekStart: DateTime(2026, 11, 9),
        prenom: 'David',
        consumedMacros: {
          'Calories': calories,
          'Protéines': 92,
          'Glucides': 210,
          'Lipides': 65,
          'Fibres': 22
        },
        macroNeeds: noGoal
            ? {}
            : {
                'Calories': 2400,
                'Protéines': 140,
                'Glucides': 280,
                'Lipides': 80,
                'Fibres': 30
              },
      );
  Widget screen(DashboardState state,
          {double scale = 1,
          VoidCallback? onAdd,
          ValueChanged<DateTime>? onDate,
          ValueChanged<int>? onWeek,
          VoidCallback? onToday,
          ValueChanged<double>? onWater}) =>
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
            builder: (context) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                      body: SingleChildScrollView(
                          child: DashboardContent(
                    state: state,
                    journal: const SizedBox(
                        height: 200, child: Text('Journal de test')),
                    hydration: HydrationSummary(
                        goalMl: 2500,
                        consumedMl: 750,
                        onAdd: onWater ?? (_) {},
                        onRemove: (_) {}),
                    quality: const Text('Radar détaillé'),
                    onAddMeal: onAdd ?? () {},
                    onTraining: () {},
                    onToday: onToday ?? () {},
                    onSync: () {},
                    onChangeWeek: onWeek ?? (_) {},
                    onSelectDate: onDate ?? (_) {},
                  ))),
                )),
      );

  for (final width in [320.0, 390.0, 768.0, 1280.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('dashboard fits width $width with text scale $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(screen(data(), scale: scale));
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
            find.text('Qualité nutritionnelle'), 250);
        await tester.tap(find.text('Qualité nutritionnelle'));
        await tester.pumpAndSettle();
        expect(find.text('Radar détaillé'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('actions send the selected day, week direction and water amount',
      (tester) async {
    DateTime? selected;
    int? direction;
    double? amount;
    var added = false;
    var today = false;
    await tester.pumpWidget(screen(data(),
        onAdd: () => added = true,
        onDate: (d) => selected = d,
        onWeek: (v) => direction = v,
        onToday: () => today = true,
        onWater: (v) => amount = v));
    await tester.tap(find.byTooltip('Semaine précédente'));
    expect(direction, -1);
    await tester.tap(find.byTooltip('Semaine suivante'));
    expect(direction, 1);
    await tester.tap(find.byTooltip('Revenir à aujourd’hui'));
    expect(today, isTrue);
    await tester.tap(find.text('13'));
    expect(selected, DateTime(2026, 11, 13));
    await tester.ensureVisible(find.text('Ajouter un repas'));
    await tester.tap(find.text('Ajouter un repas'));
    expect(added, isTrue);
    await tester.scrollUntilVisible(find.text('+ 250 ml'), 200);
    await tester.tap(find.text('+ 250 ml'));
    expect(amount, 250);
  });

  testWidgets('energy handles missing targets and exceeding the goal',
      (tester) async {
    await tester.pumpWidget(screen(data(noGoal: true)));
    expect(find.text('consommées · objectif à définir'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(screen(data(calories: 2600)));
    expect(find.text('200 kcal au-dessus de l’objectif'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
