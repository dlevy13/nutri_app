import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart'; // pour openDatabase et databaseFactory global
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    as sqflite_ffi;           // desktop / mobile :contentReference[oaicite:0]{index=0}
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    as sqflite_ffi_web;       // Web (IndexedDB + Wasm) :contentReference[oaicite:1]{index=1}
import 'pages/splash_screen.dart';
import 'package:intl/date_symbol_data_local.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Initialisation de sqflite pour chaque plateforme
  if (kIsWeb) {
    // PWA / Web → IndexedDB via Wasm
    databaseFactory = sqflite_ffi_web.databaseFactoryFfiWeb;
  } else {
    // iOS, Android, macOS, Windows, Linux → sqlite via FFI
    sqflite_ffi.sqfliteFfiInit();
    databaseFactory = sqflite_ffi.databaseFactoryFfi;
  }

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
