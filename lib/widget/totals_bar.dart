import 'package:flutter/material.dart';
import '../ui/theme/app_theme.dart';

class TotalsBar extends StatelessWidget {
  final double calories;
  final double prot;
  final double carbs;
  final double fat;
  const TotalsBar(
      {super.key,
      required this.calories,
      required this.prot,
      required this.carbs,
      required this.fat});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: LayoutBuilder(builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                final columns = constraints.maxWidth >= 560 * scale ? 4 : 2;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                final values = [
                  ('Énergie', calories, 'kcal', AppColors.green),
                  ('Protéines', prot, 'g', AppColors.green),
                  ('Glucides', carbs, 'g', AppColors.orange),
                  ('Lipides', fat, 'g', AppColors.blue),
                ];
                return Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: values
                        .map((v) => SizedBox(
                              width: width,
                              child: Semantics(
                                label:
                                    '${v.$1} : ${v.$2.toStringAsFixed(0)} ${v.$3}',
                                excludeSemantics: true,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(v.$1,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium),
                                      Text('${v.$2.toStringAsFixed(0)} ${v.$3}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(color: v.$4)),
                                    ]),
                              ),
                            ))
                        .toList());
              }),
            )),
      ),
    );
  }
}
