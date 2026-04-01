import 'package:stacked/stacked.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:flutter/material.dart';
import 'home_view_model.dart';

part 'home_mobile.dart';
part 'home_tablet.dart';
part 'home_desktop.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<HomeViewModel>.reactive(
      viewModelBuilder: () => HomeViewModel(),
      onViewModelReady: (viewModel) {
        // initialization
      },
      builder: (context, viewModel, child) {
        return ScreenTypeLayout.builder(
          mobile: (_) => _HomeMobile(viewModel: viewModel),
          tablet: (_) => _HomeTablet(viewModel: viewModel),
          desktop: (_) => _HomeDesktop(viewModel: viewModel),
        );
      },
    );
  }
}
