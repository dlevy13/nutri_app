import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvLoader {
  static Map<String, dynamic> _webEnv = {};

  static Future<void> load() async {
    if (kIsWeb) {
      final data = await rootBundle.loadString('assets/env.json');
      _webEnv = json.decode(data);
    } else {
      await dotenv.load(fileName: ".env");
    }
  }

  static String get(String key) {
    return kIsWeb ? (_webEnv[key] ?? '') : (dotenv.env[key] ?? '');
  }

  // ✅ SUPABASE (FIX FINAL)
  static String get supabaseUrl =>
      get('SUPABASE_URL');

  static String get supabaseAnonKey =>
      get('SUPABASE_ANON_KEY');
}
