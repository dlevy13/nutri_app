// Run explicitly with: flutter test --platform chrome test/browser/analysis_pages_web.dart
// These pages import the application's web services, so use the browser runner.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nutri_app/courbe/bej_chart.dart';
import 'package:nutri_app/courbe/bej_providers.dart' as energy;
import 'package:nutri_app/courbe/macro_chart.dart';
import 'package:nutri_app/courbe/macro_providers.dart' as macros;
import 'package:nutri_app/courbe/unsaturated_ratio_chart.dart';
import 'package:nutri_app/courbe/unsaturated_ratio_providers.dart' as ratios;
import 'package:nutri_app/dashboard/old_dashboard_page.dart' as report;
import 'package:nutri_app/dashboard/dashboard_notifier.dart';
import 'package:nutri_app/dashboard/dashboard_state.dart';
import 'package:nutri_app/repositories/daily_calories_repository.dart';
import 'package:nutri_app/repositories/daily_snapshot_remote_repository.dart';
import 'package:nutri_app/repositories/strava_repository.dart' as strava;
import 'package:nutri_app/services/strava_service_shared.dart';
import 'package:nutri_app/ui/theme/app_theme.dart';

class _Local extends Fake implements DailyCaloriesRepository {}

class _Remote extends Fake implements DailySnapshotRemoteRepository {}

class _Strava extends Fake implements StravaServiceShared {
  @override
  Future<bool> isConnected() async => false;
}

class _Dashboard extends DashboardNotifier {
  int selections = 0;
  _Dashboard(Ref ref) : super(ref, _Local(), _Remote()) {
    state = DashboardState(
        status: ViewStatus.success,
        selectedDate: DateTime(2026, 11, 12),
        currentWeekStart: DateTime(2026, 11, 9),
        prenom: 'David',
        consumedMacros: const {
          'Calories': 1850,
          'Protéines': 90,
          'Glucides': 200,
          'Lipides': 65,
          'Fibres': 20
        },
        macroNeeds: const {
          'Calories': 2400,
          'Protéines': 140,
          'Glucides': 280,
          'Lipides': 80,
          'Fibres': 30
        });
  }
  @override
  Future<void> selectDate(DateTime date) async {
    selections++;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));
  final series = List.generate(
      10, (i) => MapEntry(DateTime(2026, 11, i + 1), i * 30.0 - 100));
  for (final width in [320.0, 1280.0]) {
    testWidgets('real analysis charts render and expand explanations at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            energy.bejSeriesProvider.overrideWithValue(AsyncData(series)),
            energy.bejSma5Provider.overrideWithValue(AsyncData(series)),
            macros.macroPctSma5Provider.overrideWith((ref) async =>
                List.generate(
                    10,
                    (i) => macros.MacroPctPoint(
                        DateTime(2026, 11, i + 1), 30, 40, 30))),
            ratios.unsatRatioSma5Provider.overrideWithValue(AsyncData(
                List.generate(10,
                    (i) => MapEntry(DateTime(2026, 11, i + 1), 1.5 + i / 10)))),
          ],
          child: MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(1.6)),
                  child: child!),
              home: Scaffold(
                  body: ListView(children: const [
                BejChart(),
                MacroPctSmaChart(),
                UnsaturatedRatioChart()
              ])))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final title in [
        'CaloMètre',
        'Part des macros (%)',
        'Ratio insaturés / saturés'
      ]) {
        final info = find.byWidgetPredicate(
            (w) => w is IconButton && (w.tooltip ?? '').contains(title));
        await tester.scrollUntilVisible(info, 150,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(info);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Fermer'));
        await tester.pumpAndSettle();
      }
    });
    testWidgets('real report fits $width and selects its date once',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previousHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        // Preserve renderer diagnostics omitted by the browser test runner.
        // ignore: avoid_print
        print(
            'REPORT_RENDER_ERROR: ${details.toDiagnosticsNode().toStringDeep()}');
        previousHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousHandler);
      late _Dashboard dashboard;
      await tester.pumpWidget(ProviderScope(
          overrides: [
            dashboardProvider
                .overrideWith((ref) => dashboard = _Dashboard(ref)),
            strava.stravaServiceProvider.overrideWithValue(_Strava()),
          ],
          child: MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(1.6)),
                  child: child!),
              home: report.OldDashboardPage(
                  selectedDate: DateTime(2026, 11, 12)))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(dashboard.selections, 1);
      await tester.scrollUntilVisible(
          find.byTooltip('Afficher le détail des calories'), 180,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Afficher le détail des calories'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(dashboard.selections, 1);
      for (final tooltip in [
        'Afficher les activités Strava',
        'Afficher la répartition détaillée'
      ]) {
        await tester.scrollUntilVisible(find.byTooltip(tooltip), 180,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(tooltip));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.scrollUntilVisible(find.text('Lancer l’analyse'), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
