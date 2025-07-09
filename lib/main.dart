import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';      // Web (IndexedDB + Wasm) :contentReference[oaicite:1]{index=1}
import 'pages/splash_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/meal.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'pages/dashboard_page.dart';
import 'pages/welcome_page.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();
  // Charge le bon fichier .env selon le mode
  await dotenv.load(fileName: kReleaseMode ? 'assets/env.production' : 'assets/env');

  // ✅ Enregistrement de l'adaptateur Meal
  Hive.registerAdapter(MealAdapter());
  await Hive.openBox<Meal>('meals');

  // 2) Initialisation du formatage des dates (locale FR)
  await initializeDateFormatting('fr_FR');

  runApp(const NutriFitApp());
}


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
          return const DashboardPage(); // utilisateur connecté
        } else {
          return const WelcomePage(); // non connecté
        }
      },
    );
  }
}


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
