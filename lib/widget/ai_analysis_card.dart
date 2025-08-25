import 'package:flutter/material.dart';

class AiAnalysisCard extends StatelessWidget {
  final String title;
  final String content;
  final bool expanded;
  final VoidCallback onToggle;
  final bool isLoading;
  final String? error;
  final int collapsedLines;

  const AiAnalysisCard({
    super.key,
    required this.title,
    required this.content,
    required this.expanded,
    required this.onToggle,
    this.isLoading = false,
    this.error,
    this.collapsedLines = 4,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget body;
    if (isLoading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if ((error ?? '').isNotEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          error!,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red),
        ),
      );
    } else if (content.trim().isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          "Aucune analyse pour l’instant.",
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
        ),
      );
    } else {
  final bg = Theme.of(context).cardColor;

  body = AnimatedSize(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeInOut,
    alignment: Alignment.topCenter,
    child: Stack(
      children: [
        // Le texte (replié sur N lignes)
        Text(
          content.trim(),
          maxLines: expanded ? null : collapsedLines,
          overflow: expanded ? TextOverflow.visible : TextOverflow.clip,
          softWrap: true,
          style: theme.textTheme.bodyMedium,
        ),

        // Dégradé de fade en bas (visible seulement quand replié)
        if (!expanded)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: true, // pour ne pas bloquer les taps
              child: Container(
                height: 36, // épaisseur du fade
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      bg.withValues(alpha: 0.0),  // transparent
                      bg.withValues(alpha: 0.7),  // semi-opaque
                      bg,                          // opaque (couleur de la Card)
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}


    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                
              ],
            ),
            const SizedBox(height: 6),
            // Corps
            body,
            // Bouton texte (optionnel, pour accessibilité)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onToggle,
                icon: Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                label: Text(expanded ? "Réduire" : "Afficher plus"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
