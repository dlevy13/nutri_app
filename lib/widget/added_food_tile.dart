// lib/widget/added_food_tile.dart

import 'package:flutter/material.dart';
import '../models/meal.dart';
import '../services/fonctions.dart'; // Pour l'extension .cap()

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
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
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
                      meal.name.cap(max: 30),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: theme.textTheme.bodySmall,
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
                        _MiniBadge(text: "P ${meal.protein.toStringAsFixed(0)}g"),
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
          Row(
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
              const Spacer(),
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
  final double size;

  const _RoundIconSmall({
    required this.onTap,
    required this.icon,
    required this.bg,
    required this.fg,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: size / 2 + 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: fg, size: size * 0.6),
      ),
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
          style: TextStyle(fontSize: 11, color: cs.onSecondaryContainer)),
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

class TotalsBar extends StatelessWidget {
  final double calories, prot, carbs, fat;

  // Le constructeur est maintenant corrigé
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
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.summarize, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text("Total", style: theme.textTheme.titleSmall)),
          Text("${calories.toStringAsFixed(0)} kcal"),
          const SizedBox(width: 10),
          _MiniBadge(text: "P ${prot.toStringAsFixed(0)}g"),
          const SizedBox(width: 4),
          _MiniBadge(text: "G ${carbs.toStringAsFixed(0)}g"),
          const SizedBox(width: 4),
          _MiniBadge(text: "L ${fat.toStringAsFixed(0)}g"),
        ],
      ),
    );
  }

}