import 'package:flutter/material.dart';
import '../models/proposed_ingredient.dart';
import '../meal_input/meal_input_notifier.dart';

class DecompositionReviewSheet extends StatefulWidget {
  final List<ProposedIngredient> items;
  final String mealType;                // juste pour l’affichage
  final MealInputNotifier notifier;     // on utilise createAndAddFood()

  const DecompositionReviewSheet({
    super.key,
    required this.items,
    required this.mealType,
    required this.notifier,
  });

  @override
  State<DecompositionReviewSheet> createState() => _DecompositionReviewSheetState();
}

class _DecompositionReviewSheetState extends State<DecompositionReviewSheet> {
  void _nudgeQty(ProposedIngredient it, double delta) {
    final newQty = (it.quantity + delta).clamp(0.0, 500000.0);
    setState(() => it.quantity = newQty);
    // ⚠️ On ne touche PAS aux macros : elles sont calculées via getters
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Proposition d’ingrédients — ${widget.mealType}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final it = items[i];
                  return ListTile(
                    leading: Checkbox(
                      value: it.selected,
                      onChanged: (v) => setState(() => it.selected = v ?? true),
                    ),
                    title: Text(it.name),
                    subtitle: Text(
                      "${it.quantity.toStringAsFixed(0)} g • "
                      "conf. ${(it.confidence * 100).toStringAsFixed(0)}% • "
                      "${it.kcal.toStringAsFixed(0)} kcal", // total dynamique
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.remove), onPressed: () => _nudgeQty(it, -10)),
                        Text(it.quantity.toStringAsFixed(0)),
                        IconButton(icon: const Icon(Icons.add), onPressed: () => _nudgeQty(it, 10)),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("Valider et enregistrer"),
              onPressed: () async {
                try {
                  for (final it in items.where((x) => x.selected)) {
                    // createAndAddFood attend des valeurs /100g → on envoie per100
                    await widget.notifier.createAndAddFood(
                      name: it.name,
                      calories: it.kcalPer100,
                      protein: it.proteinPer100,
                      carbs: it.carbsPer100,
                      fat: it.fatPer100,
                      fibers: it.fibersPer100,
                      saturatedFat: it.saturatedFatPer100,
                      polyunsaturatedFat: it.polyunsaturatedFatPer100,
                      monounsaturatedFat: it.monounsaturatedFatPer100,
                      quantity: it.quantity, // quantité consommée en g
                    );
                  }

                  if (context.mounted) {
                    Navigator.pop(context, true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Ingrédients enregistrés ✅")),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Erreur enregistrement : $e")),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
