import 'package:flutter/material.dart';
import 'legal_notice_page.dart';
import 'register_page.dart';
import '../pages/login_page.dart';




class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF43A047),
              Color(0xFF1E88E5),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    "assets/icons/nutriWatt_logo.png",
                    height: 140,
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    "Bienvenue dans NutriWatt",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    "Votre nutrition, vos performances, vos progrès.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ───── CRÉER UN COMPTE ─────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green,
                        minimumSize: const Size(double.infinity, 55),
                      ),
                      child: const Text(
                        "Créer un compte",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ───── LOGIN (TOUJOURS DISPONIBLE) ─────
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginPage(),
                        ),
                      );
                    },
                    child: const Text(
                      "J’ai déjà un compte",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LegalNoticePage(),
                        ),
                      );
                    },
                    child: const Text(
                      "Mentions légales",
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
