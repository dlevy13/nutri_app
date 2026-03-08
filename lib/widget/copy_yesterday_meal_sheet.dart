import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/meal.dart';


class CopyYesterdayMealSheet extends StatefulWidget {
  final List<Meal> meals;
  final double step;
  final double controlsWidth;
  final void Function(Map<String, double> selectedMeals) onValidate;

  const CopyYesterdayMealSheet({
    super.key,
    required this.meals,
    required this.onValidate,
    this.step = 10,
    this.controlsWidth = 132,
  });

  @override
  State<CopyYesterdayMealSheet> createState() =>
      _CopyYesterdayMealSheetState();
}

class _CopyYesterdayMealSheetState extends State<CopyYesterdayMealSheet> {
  final Map<String, double> selectedMeals = {};

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                "Repas d'hier",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                "Cochez les aliments à ajouter et ajustez les quantités.",
              ),
              const Divider(height: 24),

              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: widget.meals.length,
                  itemBuilder: (context, index) {
                    final meal = widget.meals[index];
                    final key = '${meal.date}_${meal.type}_${meal.name}';
                    final isSelected = selectedMeals.containsKey(key);
return Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ───────── Ligne 1 : Checkbox + texte
      Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() {
                if (value == true) {
                  selectedMeals[key] = meal.quantity;
                } else {
                  selectedMeals.remove(key);
                }
              });
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  "Hier : ${meal.quantity.toStringAsFixed(0)}g",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),

      // ───────── Ligne 2 : contrôles quantité (si sélectionné)
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: !isSelected
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(left: 48, top: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _RoundIconButton(
                      icon: Icons.remove,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          final q =
                              selectedMeals[key]! - widget.step;
                          if (q <= 0) {
                            selectedMeals.remove(key);
                          } else {
                            selectedMeals[key] = q;
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 56,
                      child: Text(
                        "${selectedMeals[key]!.toStringAsFixed(0)}g",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoundIconButton(
                      icon: Icons.add,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          selectedMeals[key] =
                              selectedMeals[key]! + widget.step;
                        });
                      },
                    ),
                  ],
                ),
              ),
      ),
    ],
  ),
);

                    
                  },
                ),
              ),

              const SizedBox(height: 12),

              SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedMeals.isEmpty
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            widget.onValidate(selectedMeals);
                            Navigator.of(context).pop();
                          },
                    child: Text(
                      "Ajouter ${selectedMeals.length} aliment(s)",
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
              : Colors.grey.withOpacity(0.1),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? Theme.of(context).colorScheme.primary
              : Colors.grey,
        ),
      ),
    );
  }
}
