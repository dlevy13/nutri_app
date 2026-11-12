import 'package:flutter/material.dart';
import '../ui/theme/app_theme.dart';

/// A single scrolling surface, with readable line lengths on large screens.
class AdaptivePageBody extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;
  const AdaptivePageBody(
      {super.key, required this.children, this.maxWidth = AppLayout.maxWidth});

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: children,
              ),
            )),
      );
}
