import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../startup_gate.dart';

Future<void> logout(BuildContext context) async {
  final supabase = Supabase.instance.client;
  final prefs = await SharedPreferences.getInstance();

  await supabase.auth.signOut();

  await prefs.remove('email');
  await prefs.remove('has_profile');
  // ✅ indique que l'utilisateur est déjà passé
  await prefs.setBool('has_logged_out', true);

  if (!context.mounted) return;

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const StartupGate()),
    (_) => false,
  );
}

