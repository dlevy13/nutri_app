import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;

  static const List<_Slide> slides = [
    _Slide(
      title: "Optimise tes performances",
      text:
          "NutriPerform t’aide à mieux performer en contrôlant ton alimentation et en l’adaptant à tes activités.",
      icon: Icons.speed,
    ),
    _Slide(
      title: "Analyse & adaptation",
      text:
          "Analyse tes repas, ajuste les apports aux entraînements passés ou prévus et progresse plus vite.",
      icon: Icons.insights,
    ),
    _Slide(
      title: "Planifie sereinement",
      text:
          "Fixe des objectifs, suis tes calories et macros au quotidien, et garde le cap simplement.",
      icon: Icons.event_available,
    ),
    _Slide(
      title: "Connecté à Strava",
      text:
          "Relie ton compte Strava pour récupérer automatiquement tes calories dépensées "
          "et adapter tes besoins caloriques du jour.",
      icon: Icons.directions_bike,
    ),
    _Slide(
      title: "Anticipe avec Garmin",
      text:
          "Connecte Garmin pour importer tes entraînements prévus. "
          "NutriPerform calcule alors une vision globale de tes besoins caloriques à venir.",
      icon: Icons.watch, 
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
  void dispose() {
    _controller.dispose(); // ✅ important
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Dégradé de fond pour rester cohérent avec la WelcomePage
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF43A047), Color(0xFF1E88E5)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header : logo centré + bouton Passer à droite
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      "assets/icons/icon-512.png", // ✅ logo de l'app centré
                      height: 100,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _finish,
                        child: const Text(
                          "Passer",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Slides
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _OnboardingSlideCard(slide: slides[i]),
                ),
              ),

              // Dots + actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    _Dots(current: _index, length: slides.length),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (_index > 0)
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                            ),
                            onPressed: () {
                              _controller.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            },
                            child: const Text("Retour"),
                          )
                        else
                          const SizedBox(width: 88),

                        const Spacer(),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (_index == slides.length - 1) {
                              _finish();
                            } else {
                              _controller.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                          child: Text(_index == slides.length - 1 ? "Commencer" : "Suivant"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlideCard extends StatelessWidget {
  final _Slide slide;
  const _OnboardingSlideCard({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(slide.icon, size: 96, color: Colors.white),
          const SizedBox(height: 24),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
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
          width: active ? 22 : 8,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white54,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

class _Slide {
  final String title;
  final String text;
  final IconData icon;
  const _Slide({required this.title, required this.text, required this.icon});
}
