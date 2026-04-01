// lib/widget/added_food_tile.dart

import 'package:flutter/material.dart';
import '../models/meal.dart';

class AddedFoodTile extends StatelessWidget {
  final Meal meal;
  final VoidCallback onRemove;
  final void Function(double newQty) onQtyChange;
  final double? unitStepGrams;
  final String? unitLabel;

  const AddedFoodTile({
    super.key,
    required this.meal,
    required this.onRemove,
    required this.onQtyChange,
    this.unitStepGrams,
    this.unitLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final double kcal = meal.calories;
    final double qty = meal.quantity;
    final double step = (unitStepGrams ?? 10.0);
    final int units = (unitStepGrams != null && unitStepGrams! > 0)
        ? (qty / unitStepGrams!).round()
        : 0;
    final String? label = unitLabel;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text("${kcal.toStringAsFixed(0)} kcal",
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                        _MiniBadge(
                            text: "P ${meal.protein.toStringAsFixed(0)}g"),
                        _MiniBadge(text: "G ${meal.carbs.toStringAsFixed(0)}g"),
                        _MiniBadge(text: "L ${meal.fat.toStringAsFixed(0)}g"),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: "Supprimer",
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 12, thickness: 0.6, color: cs.outlineVariant),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _RoundIconSmall(
                onTap: () {
                  final newQty = (qty - step).clamp(0.0, 999999.0);
                  onQtyChange(newQty);
                },
                icon: Icons.remove,
                bg: cs.surfaceContainerHigh,
                fg: cs.onSurface,
              ),
              const SizedBox(width: 8),
              _RoundIconSmall(
                onTap: () {
                  final newQty = (qty + step).clamp(0.0, 999999.0);
                  onQtyChange(newQty);
                },
                icon: Icons.add,
                bg: cs.primary,
                fg: cs.onPrimary,
              ),
              Text(
                label != null
                    ? "$units $label${units > 1 ? 's' : ''} (~${qty.toStringAsFixed(0)} g)"
                    : "${qty.toStringAsFixed(0)} g",
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---- Sous-widgets utilisés par AddedFoodTile ----

class _RoundIconSmall extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color bg;
  final Color fg;

  const _RoundIconSmall({
    required this.onTap,
    required this.icon,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onTap,
      tooltip:
          icon == Icons.add ? 'Augmenter la quantité' : 'Réduire la quantité',
      style: IconButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          minimumSize: const Size(48, 48)),
      icon: Icon(icon),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  const _MiniBadge({required this.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 12, color: cs.onSecondaryContainer)),
    );
  }
}

class _Thumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.restaurant, color: cs.onPrimaryContainer),
    );
  }
}
