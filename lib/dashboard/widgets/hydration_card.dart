import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widget/card_shell.dart';
import '../../widget/section_title.dart';
import '../dashboard_notifier.dart';

class HydrationCard extends ConsumerWidget {
  const HydrationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dashboardProvider.notifier);
    final goalMl = ref.watch(dashboardProvider.select((s) => s.waterGoalMl));
    final consumedMl = ref.watch(dashboardProvider.select((s) => s.waterConsumedMl));

    final double progress = (goalMl > 0) ? (consumedMl / goalMl).clamp(0.0, 1.0) : 0.0;

    return CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle("💧 Boisson de la journée"),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- La Bouteille (visuel progression) ---
              _WaterBottle(progress: progress),
              const SizedBox(width: 16),

              // --- Infos + Boutons ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${(consumedMl / 1000).toStringAsFixed(1)} / ${(goalMl / 1000).toStringAsFixed(1)} L",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${(progress * 100).toStringAsFixed(0)}% de l'objectif",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),

                    // ---- Boutons responsives (2 puis 1 en dessous sur petit écran) ----
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 360; // ajuste si besoin
                        final btnPadding = EdgeInsets.symmetric(
                          horizontal: isNarrow ? 8 : 12,
                          vertical: isNarrow ? 8 : 10,
                        );
                        final minHeight = isNarrow ? 36.0 : 40.0;
                        final iconSize = isNarrow ? 18.0 : 20.0;
                        final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: isNarrow ? 12 : 13.5,
                        );

                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [                         
                            _AddWaterButton(
                              // Verre = +250 ml
                              icon: Icons.local_cafe_rounded,
                              iconSize: iconSize,
                              amountMl: 250,
                              isAdd: true,
                              textStyle: textStyle,
                              padding: btnPadding,
                              minHeight: minHeight,
                              onPressed: () => notifier.addWater(250),
                            ),
                            _AddWaterButton(
                              // Petite bouteille = +500 ml
                              icon: Icons.local_drink_rounded,
                              iconSize: iconSize,
                              amountMl: 500,
                              isAdd: true,
                              textStyle: textStyle,
                              padding: btnPadding,
                              minHeight: minHeight,
                              onPressed: () => notifier.addWater(500),
                            ),
                             _AddWaterButton(
                              icon: Icons.remove_circle_outline,
                              iconSize: iconSize,
                              amountMl: 250,
                              isAdd: false,
                              textStyle: textStyle,
                              padding: btnPadding,
                              minHeight: minHeight,
                              onPressed: () => notifier.removeWater(250),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Visuel bouteille remplissage ---
class _WaterBottle extends StatefulWidget {
  final double progress;
  const _WaterBottle({required this.progress});

  @override
  State<_WaterBottle> createState() => _WaterBottleState();
}

class _WaterBottleState extends State<_WaterBottle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // vague animée en continu
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress.clamp(0.0, 1.0);

    return SizedBox(
      width: 68,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // --- Silhouette grise ---
          Icon(Icons.local_drink_rounded, size: 68, color: Colors.grey.shade300),

          // --- Remplissage bleu avec vague ---
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return ClipPath(
                clipper: _WaveClipper(
                  progress: p,
                  wavePhase: _controller.value * 2 * pi,
                ),
                child: Icon(
                  Icons.local_drink_rounded,
                  size: 68,
                  color: Colors.blue.shade300,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Clipper qui dessine une vague sinusoïdale en haut du remplissage
class _WaveClipper extends CustomClipper<Path> {
  final double progress; // 0..1
  final double wavePhase; // animation

  _WaveClipper({required this.progress, required this.wavePhase});

  @override
  Path getClip(Size size) {
    final path = Path();
    final fillHeight = size.height * progress;

    final waveHeight = 6.0; // amplitude vague
    final waveLength = size.width / 1.2;

    // Base du rectangle (fond bleu)
    path.addRect(Rect.fromLTWH(0, size.height - fillHeight, size.width, fillHeight));

    // Supprimer le haut rectangulaire et le remplacer par une vague
    path.reset();
    path.moveTo(0, size.height - fillHeight);

    for (double x = 0; x <= size.width; x++) {
      final y = sin((x / waveLength * 2 * pi) + wavePhase) * waveHeight;
      path.lineTo(x, size.height - fillHeight + y);
    }

    // fermer la zone
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant _WaveClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.wavePhase != wavePhase;
}

// --- Bouton réutilisable ---
class _AddWaterButton extends StatelessWidget {
  final IconData icon;
  final double amountMl;
  final VoidCallback onPressed;
  final bool isAdd;
  final EdgeInsetsGeometry padding;
  final double minHeight;
  final double iconSize;
  final TextStyle? textStyle;

  const _AddWaterButton({
    required this.icon,
    required this.amountMl,
    required this.onPressed,
    this.isAdd = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.minHeight = 40,
    this.iconSize = 20,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final label = "${isAdd ? "+" : "−"}${amountMl.toStringAsFixed(0)} ml";

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize),
        label: Text(label, style: textStyle),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.blue.shade800,
          backgroundColor: Colors.blue.shade50,
          elevation: 0,
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          visualDensity: VisualDensity.compact,
          minimumSize: const Size(0, 0), // laisse Wrap optimiser la largeur
        ),
      ),
    );
  }
}

// --- Clipper remplissage ---
class _BottleClipper extends CustomClipper<Path> {
  final double fillPercent;
  _BottleClipper({required this.fillPercent});

  @override
  Path getClip(Size size) {
    final path = Path();
    final fillHeight = size.height * fillPercent;
    path.addRect(Rect.fromLTWH(0, size.height - fillHeight, size.width, fillHeight));
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}
