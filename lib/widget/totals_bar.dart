import 'package:flutter/material.dart';

class TotalsBar extends StatelessWidget {
  final double calories;
  final double prot;
  final double carbs;
  final double fat;

  const TotalsBar({
    super.key,
    required this.calories,
    required this.prot,
    required this.carbs,
    required this.fat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _AnimatedMacro(
            label: "Kcal",
            value: calories,
            unit: "",
            color: cs.primary,
            big: true,
          ),
          _AnimatedMacro(label: "P", value: prot, unit: "g", color: Colors.redAccent),
          _AnimatedMacro(label: "G", value: carbs, unit: "g", color: Colors.blueAccent),
          _AnimatedMacro(label: "L", value: fat, unit: "g", color: Colors.orangeAccent),
        ],
      ),
    );
  }
}

class _AnimatedMacro extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;
  final bool big;

  const _AnimatedMacro({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    final styleValue = TextStyle(
      fontSize: big ? 20 : 16,
      fontWeight: FontWeight.bold,
      color: color,
    );

    final styleLabel = TextStyle(
      fontSize: 12,
      color: Colors.grey.shade600,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.25),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Text(
            "${value.toStringAsFixed(0)}$unit",
            key: ValueKey(value.toStringAsFixed(0)),
            style: styleValue,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: styleLabel),
      ],
    );
  }
}
