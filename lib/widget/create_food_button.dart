import 'package:flutter/material.dart';

class CreateFoodButton extends StatelessWidget {
  final String label;
  final Color color;
  final String nameSuggestion;
  final void Function(BuildContext, String) onPressed;

  const CreateFoodButton({
    super.key,
    required this.label,
    required this.color,
    required this.nameSuggestion,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => onPressed(context, nameSuggestion),
      icon: const Icon(Icons.add),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
