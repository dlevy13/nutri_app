import 'package:flutter/material.dart';

class MealDescriptionCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onAnalyze;
  const MealDescriptionCard(
      {super.key, required this.controller, required this.onAnalyze});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Icon(Icons.auto_awesome_outlined,
            color: Theme.of(context).colorScheme.primary),
        title: const Text('Décrire un plat avec l’IA'),
        subtitle: const Text('Une autre façon d’ajouter ton repas'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                        labelText: 'Ton plat',
                        hintText: 'Un bol de chili con carne avec du riz',
                        suffixIcon: value.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Effacer la description',
                                onPressed: controller.clear,
                                icon: const Icon(Icons.close_rounded))),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                      onPressed: value.text.trim().isEmpty ? null : onAnalyze,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Analyser le plat')),
                ]),
          ),
        ],
      ),
    );
  }
}
