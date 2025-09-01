// food_search_field.dart

import 'package:flutter/material.dart';

// 1. On transforme le widget en StatelessWidget : plus simple et plus léger.
class FoodSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const FoodSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    // 2. On utilise ValueListenableBuilder pour écouter le controller
    //    sans avoir besoin de setState ou de listeners manuels.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: "ex: Poulet, riz, pomme...",
            border: const OutlineInputBorder(),
            // 3. La logique d'affichage de l'icône est ici,
            //    basée sur la `value` fournie par le builder.
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: onClear,
                  )
                : const Icon(Icons.search),
          ),
        );
      },
    );
  }
}