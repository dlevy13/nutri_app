import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../repositories/strava_repository.dart';
import 'firebase_options.dart'; 
import 'models/meal.dart';
import 'models/analysis.dart';
import 'providers/common_providers.dart';
import '../dashboard/dashboard_notifier.dart';
import '../dashboard/dashboard_page.dart';
import 'pages/welcome_page.dart';
import 'pages/onboarding_page.dart';
import 'startup_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Chargement config env + Firebase
  await EnvLoader.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Hive
  await Hive.initFlutter();
  Hive.registerAdapter(MealAdapter());
  Hive.registerAdapter(AnalysisAdapter());
  final mealBox = await Hive.openBox<Meal>('meals');
  final analysisBox = await Hive.openBox<Analysis>('analyses');
  // Locale dates
  await initializeDateFormatting('fr_FR', null);
// SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // On crée le "conteneur" de providers en avance
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      mealBoxProvider.overrideWithValue(mealBox),
      analysisBoxProvider.overrideWithValue(analysisBox),
    ],
  );
  // 🔑 Callback OAuth Strava (Web)
  final uri = Uri.base;
  if (uri.queryParameters.containsKey("code")) {
    final code = uri.queryParameters["code"]!;
    try {
      await container.read(stravaServiceProvider).exchangeToken(code);
      container.invalidate(dashboardProvider); // force rafraîchissement

       // 🔒 Persistance de session côté Web
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        // Retour à la racine pour nettoyer l’URL
        web.window.location.href = "/";
        return;
      }
    } catch (e) {
      debugPrint("❌ Error exchanging Strava token: $e");
    }
  }
  if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const _AppRoot(),
    ),
  );
}
/// Racine unique de l’app : un seul MaterialApp
class _AppRoot extends StatelessWidget {
  // ignore: unused_element_parameter
  const _AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriPerform AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const StartupGate(), // ✅ décide Onboarding / Welcome / Dashboard
    );
  }
}
// page welcom
class MyApp extends StatelessWidget {
  final bool showOnboarding;
  const MyApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: showOnboarding ? const OnboardingPage() : const WelcomePage(),
    );
  }
}
// AuthWrapper redevient un simple StatelessWidget
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          return const DashboardPage();
        } else {
          return const WelcomePage();
        }
      },
    );
  }
}

// NutriFitApp redevient aussi très simple
class NutriFitApp extends StatelessWidget {
  const NutriFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriPerform AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const AuthWrapper(),
    );
  }
}