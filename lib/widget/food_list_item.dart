
import 'package:flutter/material.dart';

class FoodListItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const FoodListItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell( // InkWell pour un effet visuel au clic
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(
                Icons.restaurant_menu_outlined,
                color: theme.colorScheme.primary,
                size: 30,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.add_circle_outline, color: theme.colorScheme.secondary),
            ],
          ),
        ),
      ),
    );
  }
}