import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // NOUVEAU
import 'package:intl/date_symbol_data_local.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NOUVEAU
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'firebase_options.dart'; 
import 'log.dart';
import 'models/meal.dart';
import 'models/analysis.dart';
import 'services/strava_service.dart';
import '../providers/common_providers.dart';
import 'repositories/strava_repository.dart';
import '/dashboard/dashboard_notifier.dart';
// NOUVEAU : Importer les fichiers où les providers sont définis

import 'repositories/meal_repository.dart';


// NOUVEAU : On importe la page depuis son nouveau dossier
import 'dashboard/dashboard_page.dart';
import 'pages/welcome_page.dart'; // 'welcome_page' reste sûrement dans 'pages'

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvLoader.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  Hive.registerAdapter(MealAdapter());
  Hive.registerAdapter(AnalysisAdapter());

  final mealBox = await Hive.openBox<Meal>('meals');
  final analysisBox = await Hive.openBox<Analysis>('analyses');
  final prefs = await SharedPreferences.getInstance();

  await initializeDateFormatting('fr_FR', null);

  // On crée le "conteneur" de providers en avance
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      mealBoxProvider.overrideWithValue(mealBox),
      analysisBoxProvider.overrideWithValue(analysisBox),
    ],
  );
  
  final uri = Uri.base;

if (uri.queryParameters.containsKey("code")) {
  final code = uri.queryParameters["code"]!;
  logger.d("📥 Strava OAuth code detected: $code");

  try {
    // ✅ Attendre que Firebase Auth ait rechargé l'utilisateur (UID non nul)
    await FirebaseAuth.instance.authStateChanges().firstWhere((u) => u != null);

    await StravaService().exchangeToken(code);
    logger.d("✅ Strava token exchanged and stored successfully.");

    if (kIsWeb) {
      // ✅ nettoie l’URL et évite de revenir sur l’URL avec ?code=
      web.window.location.replace("/");
      return;
    }
  } catch (e) {
    logger.e("❌ Error exchanging Strava token: $e");
  }
}

  runApp(
    // Ce widget permet à l'application d'utiliser le conteneur que nous avons créé
    UncontrolledProviderScope(
      container: container,
      child: const NutriFitApp(),
    ),
  );
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
      title: 'NutriFit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const AuthWrapper(),
    );
  }
}
