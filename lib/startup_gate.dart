import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/onboarding_page.dart';
import 'pages/welcome_page.dart';
import 'dashboard/dashboard_page.dart';
import 'pages/profile_form_page.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool? _showOnboarding;
  bool? _hasUserProfile;
  bool? _hasLoggedOut;
  bool? _hasActiveSession; // ✅ auto-login

  @override
  void initState() {
    super.initState();
    _initStartup();
  }

  Future<void> _initStartup() async {
    final prefs = await SharedPreferences.getInstance();
    final supabase = Supabase.instance.client;

    // 🔐 SESSION SUPABASE
    final hasSession = supabase.auth.currentSession != null;

    // 🎯 FLAGS LOCAUX
    final seenOnboarding = prefs.getBool('onboarding_done') ?? false;
    final hasProfile = prefs.getBool('has_profile') ?? false;
    final hasLoggedOut = prefs.getBool('has_logged_out') ?? false;

    if (!mounted) return;

    setState(() {
      _hasActiveSession = hasSession;
      _showOnboarding = !seenOnboarding;
      _hasUserProfile = hasProfile;
      _hasLoggedOut = hasLoggedOut;
    });
  }

  @override
Widget build(BuildContext context) {
  if (_showOnboarding == null ||
      _hasUserProfile == null ||
      _hasLoggedOut == null ||
      _hasActiveSession == null) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  // 1️⃣ Onboarding jamais vu
  if (_showOnboarding!) {
    return const OnboardingPage();
  }

  // 2️⃣ Session active MAIS profil pas encore créé → ProfileForm
  if (_hasActiveSession! && !_hasUserProfile!) {
    return const ProfileFormPage();
  }

  // 3️⃣ Session active + profil OK → Dashboard
  if (_hasActiveSession! && _hasUserProfile!) {
    return const DashboardPage();
  }

  // 4️⃣ Pas connecté → Welcome
  return const WelcomePage();
}


}
