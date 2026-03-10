import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _index = 0;

  static const List<_Slide> slides = [
    _Slide(
      title: "Optimise tes performances",
      text:
          "NutriPerform t’aide à mieux performer en contrôlant ton alimentation et en l’adaptant à tes activités.",
      imageAsset: 'assets/onboarding/performance.png',
    ),
    _Slide(
      title: "Analyse & adaptation",
      text:
          "Analyse tes repas, ajuste les apports aux entraînements passés ou prévus et progresse plus vite.",
      imageAsset: 'assets/onboarding/analysis.png',
    ),
    _Slide(
      title: "Planifie sereinement",
      text:
          "Fixe des objectifs, suis tes calories et macros au quotidien, et garde le cap simplement.",
      imageAsset: 'assets/onboarding/planner.png',
    ),
    _Slide(
      title: "Connecté à Strava",
      text:
          "Relie ton compte Strava pour récupérer automatiquement tes calories dépensées "
          "et adapter tes besoins caloriques du jour.",
      imageAsset: 'assets/onboarding/strava.png',
      titlePrefixForLogo: "Connecté à ",
      titleLogoAsset: 'assets/onboarding/logo_strava.png',
    ),
    _Slide(
      title: "Anticipe avec Garmin",
      text:
          "Connecte Garmin pour importer tes entraînements prévus. "
          "NutriPerform calcule alors une vision globale de tes besoins caloriques à venir.",
      imageAsset: 'assets/onboarding/garmin.png',
      titlePrefixForLogo: "Anticipe avec ",
      titleLogoAsset: 'assets/onboarding/logo_garmin.png',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    // On bascule vers Welcome ; StartupGate gèrera la suite (si user déjà connecté → Dashboard)
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: Passer (secondary action, top-right)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, top: 8),
                    child: TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black54,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fast_forward_rounded,
                            size: 16,
                            color: Colors.black45,
                          ),
                          const SizedBox(width: 6),
                          const Text("Passer"),
                        ],
                      ),
                    ),
                  ),
                ),
                // Contenu principal ancré vers le bas (illustration + titre + texte).
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _OnboardingSlideCard(slide: slides[_index]),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                _OnboardingBottomSection(
                  currentIndex: _index,
                  totalSlides: slides.length,
                  onPrevious: () => setState(() => _index = (_index - 1).clamp(0, slides.length - 1)),
                  onNext: () {
                    if (_index == slides.length - 1) {
                      _finish();
                    } else {
                      setState(() => _index++);
                    }
                  },
                  onFinish: _finish,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Contenu d’une slide (illustration + titre + description).
/// Scroll géré par le parent [SingleChildScrollView].
class _OnboardingSlideCard extends StatelessWidget {
  final _Slide slide;

  const _OnboardingSlideCard({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, -80),
              child: Image.asset(
                slide.imageAsset,
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: slide.titleLogoAsset != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      slide.titlePrefixForLogo!,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Transform.translate(
                      offset: slide.titleLogoAsset == 'assets/onboarding/logo_garmin.png'
                          ? const Offset(0, -4)
                          : Offset.zero,
                      child: Image.asset(
                        slide.titleLogoAsset!,
                        height: slide.titleLogoAsset == 'assets/onboarding/logo_garmin.png' ? 28 : 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                )
              : Text(
                  slide.title,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            slide.text,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

String _ctaLabel(int index, int total) {
  if (index == 0) return "Découvrir";
  if (index == total - 1) return "Commencer";
  return "Continuer";
}

/// Bloc fixe en bas : Retour (slot fixe pour ne pas déplacer le CTA) + CTA + Stepper.
/// Le CTA reste toujours à la même position verticale.
class _OnboardingBottomSection extends StatelessWidget {
  final int currentIndex;
  final int totalSlides;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  const _OnboardingBottomSection({
    required this.currentIndex,
    required this.totalSlides,
    required this.onPrevious,
    required this.onNext,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slot fixe pour Retour : quand index > 0 on affiche le bouton, sinon vide → CTA ne bouge pas
          SizedBox(
            height: 44,
            child: currentIndex > 0
                ? Center(
                    child: TextButton(
                      onPressed: onPrevious,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        "Retour",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 12), // Retour → CTA = 12
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {
                if (currentIndex == totalSlides - 1) {
                  onFinish();
                } else {
                  onNext();
                }
              },
              child: Text(
                _ctaLabel(currentIndex, totalSlides),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12), // CTA → Stepper = 12
          _Dots(current: currentIndex, length: totalSlides),
          // Stepper → bottom = 24 (via Padding bottom: 24)
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int current;
  final int length;
  const _Dots({required this.current, required this.length});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: active ? 24 : 8,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF43A047) : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _Slide {
  final String title;
  final String text;
  final String imageAsset;
  final String? titlePrefixForLogo;
  final String? titleLogoAsset;

  const _Slide({
    required this.title,
    required this.text,
    required this.imageAsset,
    this.titlePrefixForLogo,
    this.titleLogoAsset,
  });
}
