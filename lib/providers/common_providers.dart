// dans lib/providers/common_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal.dart'; // Adaptez le chemin
import '../models/analysis.dart'; // Adaptez le chemin

// ✅ On définit le provider pour SharedPreferences ICI et nulle part ailleurs.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

// ✅ On peut aussi centraliser les providers pour Hive ici.
final mealBoxProvider = Provider<Box<Meal>>((ref) {
  throw UnimplementedError();
});

final analysisBoxProvider = Provider<Box<Analysis>>((ref) {
  throw UnimplementedError();
});