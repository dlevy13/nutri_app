// lib/widget/suggestion_meal_card.dart

import 'package:flutter/material.dart';
import '../models/meal.dart';
import '../services/fonctions.dart'; // Pour l'extension .cap()

class SuggestionMealCard extends StatefulWidget {
  final Meal meal;
  final double kcalPer100;
  final double proteinPer100;
  final double carbsPer100;
  final double fatPer100;
  final VoidCallback onAdd;

  const SuggestionMealCard({
    super.key,
    required this.meal,
    required this.kcalPer100,
    required this.proteinPer100,
    required this.carbsPer100,
    required this.fatPer100,
    required this.onAdd,
  });

  @override
  State<SuggestionMealCard> createState() => _SuggestionMealCardState();
}

class _SuggestionMealCardState extends State<SuggestionMealCard> {
  bool _hovered = false;

  String _fmt(num x, {int d = 1}) => x.toStringAsFixed(d);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0.5,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onAdd,
        onHover: (v) => setState(() => _hovered = v),
        onFocusChange: (v) => setState(() => _hovered = v),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      widget.meal.name.cap(max: 35),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IgnorePointer(
                    ignoring: true,
                    child: AnimatedScale(
                      scale: _hovered ? 1.12 : 1.0,
                      duration: const Duration(milliseconds: 130),
                      curve: Curves.easeOut,
                      child: Icon(
                        Icons.add,
                        size: 18,
                        color: _hovered ? Colors.green.shade700 : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "${widget.kcalPer100.toStringAsFixed(0)} kcal / 100 g",
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                "${_fmt(widget.proteinPer100)} g P · "
                "${_fmt(widget.carbsPer100)} g G · "
                "${_fmt(widget.fatPer100)} g L / 100 g",
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}