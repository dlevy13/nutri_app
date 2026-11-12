import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nutri_app/profile_form/profile_form_state.dart';
import 'package:nutri_app/pages/widgets/profile_content.dart';
import 'package:nutri_app/pages/widgets/training_planner_content.dart';
import 'package:nutri_app/training_planner/training_planner_state.dart';
import 'package:nutri_app/ui/theme/app_theme.dart';
import 'package:nutri_app/widget/chart_section_header.dart';
import 'package:nutri_app/widget/app_navigation_bar.dart';
import 'package:nutri_app/dashboard/widgets/report_energy_card.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));
  Widget app(Widget body, {double scale = 1.6}) => MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Scaffold(body: body));
  void size(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final width in [320.0, 768.0, 1280.0]) {
    testWidgets('profile fits $width and every action remains reachable',
        (tester) async {
      size(tester, width);
      final controllers = List.generate(4, (_) => TextEditingController());
      for (final c in controllers) {
        addTearDown(c.dispose);
      }
      var saved = false;
      ProfileField? field;
      String? value;
      await tester.pumpWidget(app(ProfileContent(
        state: const ProfileFormState(),
        email: 'david@example.com',
        formKey: GlobalKey<FormState>(),
        firstName: controllers[0],
        height: controllers[1],
        weight: controllers[2],
        garmin: controllers[3],
        onTextChanged: (f, v) {
          field = f;
          value = v;
        },
        onSexChanged: (_) {},
        onActivityChanged: (_) {},
        onBirthDate: () {},
        onSave: () => saved = true,
        onOpenGarmin: () {},
        onLogout: () {},
        onLegal: () {},
        strava: const Text('Compte Strava connecté'),
      )));
      expect(tester.takeException(), isNull);
      final firstName = find.widgetWithText(TextFormField, 'Prénom');
      await tester.scrollUntilVisible(firstName, 150,
          scrollable: find.byType(Scrollable).first);
      await tester.enterText(firstName, 'David');
      expect(field, ProfileField.firstName);
      expect(value, 'David');
      await tester.scrollUntilVisible(find.text('Enregistrer mon profil'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer mon profil'));
      expect(saved, isTrue);
      expect(tester.takeException(), isNull);
    });
    testWidgets('training planning fits $width and saves the existing date key',
        (tester) async {
      size(tester, width);
      String? key;
      String? activity;
      int? offset;
      var synced = false;
      await tester.pumpWidget(app(TrainingPlannerContent(
        state:
            TrainingPlannerState(status: PlannerStatus.success, garminEvents: [
          {
            'start': DateTime(2026, 11, 9, 8),
            'summary': 'Sortie longue en endurance avec le club et récupération'
          }
        ]),
        today: DateTime(2026, 11, 12),
        onChangeWeek: (v) => offset = v,
        onToday: () {},
        onSync: () => synced = true,
        onRetry: () {},
        onSelectActivity: (k, v) {
          key = k;
          activity = v;
        },
      )));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.byTooltip('Semaine suivante'), 120,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Semaine suivante'));
      expect(offset, 1);
      await tester.ensureVisible(find.text('Actualiser Garmin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualiser Garmin'));
      expect(synced, isTrue);
      await tester.scrollUntilVisible(
          find.byType(DropdownButtonFormField<String>).first, 150,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Endurance').last);
      await tester.pumpAndSettle();
      expect(key, '2026-11-9');
      expect(activity, 'Endurance');
      expect(tester.takeException(), isNull);
    });
    testWidgets('chart controls, explanations and report energy fit $width',
        (tester) async {
      size(tester, width);
      int? range;
      await tester.pumpWidget(
          app(ListView(padding: const EdgeInsets.all(20), children: [
        Builder(
            builder: (context) => ChartSectionHeader(
                title: 'Ratio insaturés / saturés',
                icon: Icons.waves,
                days: 60,
                onRangeChanged: (v) => range = v,
                onInfo: () => showChartInfo(context,
                    title: 'À propos du ratio insaturés / saturés',
                    children: List.generate(
                        20,
                        (i) => Text(
                            'Explication $i du graphique et des valeurs affichées.'))))),
        const ReportEnergyCard(consumed: 1850, needed: 2400),
      ])));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('90 jours').last);
      await tester.pumpAndSettle();
      expect(range, 90);
      await tester.tap(find.byTooltip('À propos de Ratio insaturés / saturés'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(
          find.byType(SingleChildScrollView).last, const Offset(0, -1600));
      await tester.pumpAndSettle();
      expect(find.text('Explication 19 du graphique et des valeurs affichées.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('planning failure has a working retry action', (tester) async {
    var retry = false;
    await tester.pumpWidget(app(
        TrainingPlannerContent(
            state: const TrainingPlannerState(status: PlannerStatus.failure),
            today: DateTime(2026, 11, 12),
            onChangeWeek: (_) {},
            onToday: () {},
            onSync: () {},
            onRetry: () => retry = true,
            onSelectActivity: (_, __) {}),
        scale: 1));
    await tester.tap(find.text('Réessayer'));
    expect(retry, isTrue);
  });
  testWidgets('navigation exposes all destinations and correct active tab',
      (tester) async {
    int? selected;
    await tester.pumpWidget(app(AppNavigationBar(
        currentIndex: 1, onDestinationSelected: (v) => selected = v)));
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1);
    await tester.tap(find.text('Profil'));
    expect(selected, 3);
    await tester.tap(find.text('Rapport'));
    expect(selected, 2);
  });
}
