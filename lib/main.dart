import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';      // Web (IndexedDB + Wasm) :contentReference[oaicite:1]{index=1}
import 'pages/splash_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'models/meal.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  //await dotenv.load(fileName: "assets/env");
  // Charge le bon fichier .env selon le mode
  await dotenv.load(fileName: kReleaseMode ? 'assets/env.production' : 'assets/env');

  // ✅ Enregistrement de l'adaptateur Meal
  Hive.registerAdapter(MealAdapter());
  

  // 2) Initialisation du formatage des dates (locale FR)
  await initializeDateFormatting('fr_FR');

  runApp(const NutriFitApp());
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
      home: const SplashScreen(),
    );
  }
}
