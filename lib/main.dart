import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'models/meal.dart';
import 'models/daily_calories.dart';
import 'models/analysis.dart';
import 'models/strava_day_activities.dart';
import 'providers/common_providers.dart';
import 'repositories/strava_repository.dart';
import 'dashboard/dashboard_notifier.dart';
import 'startup_gate.dart';
import 'package:app_links/app_links.dart';
import 'envloader.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


// Import redirection Web uniquement
import 'redirect_stub.dart'
    if (dart.library.html) 'web_redirect.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------
  // 🔥 INIT FIREBASE (OBLIGATOIRE pour Strava + Auth)
  // -------------------------------------------------------
  await EnvLoader.load();
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
// -------------------------------------------------------
  // 🔥 INIT SUPABASE (OBLIGATOIRE pour Edge Functions)
  // -------------------------------------------------------
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  // -------------------------------------------------------
  // Hive init
  // -------------------------------------------------------
  await Hive.initFlutter();
  Hive.registerAdapter(MealAdapter());
  Hive.registerAdapter(AnalysisAdapter());
  Hive.registerAdapter(DailyCaloriesAdapter());
  Hive.registerAdapter(StravaDayActivitiesAdapter());

  final mealBox = await Hive.openBox<Meal>('meals');
  final analysisBox = await Hive.openBox<Analysis>('analyses');
  final dailyCaloriesBox = await Hive.openBox<DailyCalories>('daily_calories');
  final customFoodsBox = await Hive.openBox<Meal>("custom_foods_box");
  await Hive.openBox<StravaDayActivities>('stravaActivities');

  // -------------------------------------------------------
  // Date locale FR
  // -------------------------------------------------------
  await initializeDateFormatting('fr_FR', null);

  // -------------------------------------------------------
  // SharedPreferences
  // -------------------------------------------------------
  final prefs = await SharedPreferences.getInstance();

  // -------------------------------------------------------
  // Riverpod container
  // -------------------------------------------------------
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      mealBoxProvider.overrideWithValue(mealBox),
      analysisBoxProvider.overrideWithValue(analysisBox),
      dailyCaloriesBoxProvider.overrideWithValue(dailyCaloriesBox),
      customFoodsBoxProvider.overrideWithValue(customFoodsBox),
    ],
  );


  // -------------------------------------------------------
// OAuth STRAVA — CALLBACK WEB (Desktop + iOS PWA)
// -------------------------------------------------------
if (kIsWeb) {
  final uri = Uri.base;

  // ✅ Important : on vérifie aussi le PATH pour éviter des faux positifs
  if (uri.path.contains("strava-callback") &&
      uri.queryParameters.containsKey("code")) {
    final code = uri.queryParameters["code"]!;

    try {
      await container.read(stravaServiceProvider).exchangeToken(code);

      // ✅ Invalide ce qui dépend de Strava
      container.invalidate(dashboardProvider);
      container.invalidate(isStravaConnectedProvider);

      // ✅ CRITIQUE iOS PWA : on nettoie l’URL sans quitter l’app
      redirectToHome(); // doit faire un history.replaceState('/')

      // ❌ surtout pas return; on laisse runApp se lancer
    } catch (e) {
      debugPrint("❌ Error exchanging Strava token (WEB): $e");

      // Nettoyage optionnel pour éviter un retry infini
      redirectToHome();
    }
  }
}


  // -------------------------------------------------------
  // OAuth STRAVA — DEEP LINK ANDROID
  // -------------------------------------------------------
  if (!kIsWeb) {
    final appLinks = AppLinks();

    final initialUri = await appLinks.getInitialAppLink();
    if (initialUri != null) {
      await _handleStravaDeepLink(initialUri, container);
    }

    appLinks.uriLinkStream.listen((uri) async {
      await _handleStravaDeepLink(uri, container);
    });
  }

  // -------------------------------------------------------
  // RUN APP
  // -------------------------------------------------------
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NutriWattApp(),
    ),
  );
}


// -------------------------------------------------------
// 🧠 FONCTION UTILITAIRE : gérer le deep link Strava
// -------------------------------------------------------
Future<void> _handleStravaDeepLink(
  Uri uri,
  ProviderContainer container,
) async {
  debugPrint("📥 Deep link reçu : $uri");

  if (uri.scheme == "nutriwatt" &&
      uri.host == "strava-callback" &&
      uri.queryParameters.containsKey("code")) {
    
    final code = uri.queryParameters["code"]!;
    debugPrint("🔥 Code OAuth Strava (Android) : $code");

    try {
      await container.read(stravaServiceProvider).exchangeToken(code);
      container.invalidate(dashboardProvider);
      debugPrint("🎉 Tokens Strava stockés !");
    } catch (e) {
      debugPrint("❌ Erreur lors de exchangeToken Android : $e");
    }
  }

}

// -------------------------------------------------------
// APP ROOT
// -------------------------------------------------------
class NutriWattApp extends StatelessWidget {
  const NutriWattApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriWatt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [
        Locale('fr', 'FR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const StartupGate(),
    );
  }
}
