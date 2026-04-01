import 'package:flutter/material.dart';
import '../ui/theme/app_theme.dart';

class CardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const CardShell(
      {required this.child,
      this.padding = const EdgeInsets.all(20),
      super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.radius),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
