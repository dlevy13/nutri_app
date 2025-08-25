import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/onboarding_page.dart';   // ✅ casse corrigée
import 'pages/welcome_page.dart';
import 'dashboard/dashboard_page.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    _loadOnboardingFlag();
  }

  Future<void> _loadOnboardingFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_done') ?? false;
    if (!mounted) return;                 // ✅ sécurité
    setState(() => _showOnboarding = !seen);
  }

  @override
  Widget build(BuildContext context) {
    // Splash pendant le chargement
    if (_showOnboarding == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 1) Onboarding si jamais vu
    if (_showOnboarding!) {
      return const OnboardingPage();
    }

    // 2) Sinon, router selon l'état d'auth Firebase
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data != null) {
          return const DashboardPage();   // ✅ déjà connecté
        }
        return const WelcomePage();       // ❌ pas connecté
      },
    );
  }
}
