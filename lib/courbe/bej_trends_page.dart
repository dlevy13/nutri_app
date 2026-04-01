import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bej_chart.dart';
import 'macro_chart.dart';
import 'unsaturated_ratio_chart.dart';
import '../pages/profile_form_page.dart';
import '../dashboard/dashboard_notifier.dart';
import '../dashboard/old_dashboard_page.dart';
import '../widget/adaptive_page_body.dart';
import '../widget/app_navigation_bar.dart';

class BejTrendsPage extends ConsumerWidget {
  const BejTrendsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Tendances')),
        body: AdaptivePageBody(maxWidth: 1000, children: [
          Text('Mes tendances',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
              'Prends du recul sur ton énergie et tes apports au fil des semaines.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          const BejChart(),
          const SizedBox(height: 20),
          const MacroPctSmaChart(),
          const SizedBox(height: 20),
          const UnsaturatedRatioChart(),
        ]),
        bottomNavigationBar: AppNavigationBar(
            currentIndex: 1,
            onDestinationSelected: (i) {
              switch (i) {
                case 0:
                  Navigator.popUntil(context, (route) => route.isFirst);
                case 1:
                  break;
                case 2:
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => OldDashboardPage(
                              selectedDate:
                                  ref.read(dashboardProvider).selectedDate)));
                case 3:
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProfileFormPage()));
              }
            }),
      );
}
