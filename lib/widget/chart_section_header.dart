import 'package:flutter/material.dart';

class ChartSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final int days;
  final VoidCallback onInfo;
  final ValueChanged<int> onRangeChanged;
  const ChartSectionHeader(
      {super.key,
      required this.title,
      required this.icon,
      required this.days,
      required this.onInfo,
      required this.onRangeChanged});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Text(title, style: Theme.of(context).textTheme.titleMedium)),
          IconButton(
              tooltip: 'À propos de $title',
              onPressed: onInfo,
              icon: const Icon(Icons.info_outline_rounded)),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey(days),
          initialValue: days,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Période affichée'),
          items: const [30, 60, 90]
              .map((d) => DropdownMenuItem(value: d, child: Text('$d jours')))
              .toList(),
          onChanged: (v) {
            if (v != null) onRangeChanged(v);
          },
        ),
      ]);
}

/// Explanations remain scrollable on a phone, including with enlarged text.
Future<void> showChartInfo(BuildContext context,
        {required String title, required List<Widget> children}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
          child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(title,
                          style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                      tooltip: 'Fermer',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context))
                ]),
                const SizedBox(height: 16),
                ...children,
              ],
            )),
      )),
    );
