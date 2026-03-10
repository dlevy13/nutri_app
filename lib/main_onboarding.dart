// Point d'entrée minimal pour travailler uniquement sur l'UI de l'onboarding.
// Aucune init Firebase / Supabase / Hive → démarrage très rapide.
//
// Lancer avec (--release évite le 404 AssetManifest sur le web) :
//   flutter run -d chrome -t lib/main_onboarding.dart --release
//
// En debug (sans --release), le serveur web Flutter peut renvoyer 404 pour
// assets/AssetManifest.bin.json ; utiliser --release pour prévisualiser correctement.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/onboarding_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _OnboardingApp());
}

class _OnboardingApp extends StatelessWidget {
  const _OnboardingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriWatt – Onboarding',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        textTheme: GoogleFonts.robotoTextTheme(),
      ),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const OnboardingPage(),
    );
  }
}
