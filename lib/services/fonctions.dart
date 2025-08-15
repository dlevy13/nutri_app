import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
 import '../log.dart';
 import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:characters/characters.dart';

 

String normalize(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r"œ"), "oe")
      .replaceAll(RegExp(r"[àáâãäå]"), "a")
      .replaceAll(RegExp(r"[èéêë]"), "e")
      .replaceAll(RegExp(r"[ìíîï]"), "i")
      .replaceAll(RegExp(r"[òóôõö]"), "o")
      .replaceAll(RegExp(r"[ùúûü]"), "u")
      .replaceAll(RegExp(r"[ç]"), "c")
      .replaceAll(RegExp(r"[ñ]"), "n")
      .replaceAll(RegExp(r"[^a-z0-9\s]"), "") // supprime caractères spéciaux
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

// ==== FIRESTORE UTILISATEURS ====

String getShortenedName(String name, {int wordCount = 5}) {
  return name.split(' ').take(wordCount).join(' ');
}
Future<void> saveUserToFirestore(AppUser user) async {
  final usersRef = FirebaseFirestore.instance.collection('users');

  // ✅ Calcul de l’âge depuis birthDate si présent
  int computedAge = user.age;
  if (user.birthDate != null) {
    final birth = DateTime.tryParse(user.birthDate!);
    if (birth != null) {
      final today = DateTime.now();
      computedAge = today.year - birth.year;
      if (today.month < birth.month ||
          (today.month == birth.month && today.day < birth.day)) {
        computedAge--;
      }
    }
  }

  // ✅ Construire la map Firestore
  final userMap = user.toMap();
  userMap['age'] = computedAge;

  logger.d("📤 Sauvegarde Firestore pour ${user.uid} avec âge=$computedAge");

  // ✅ Sauvegarde dans Firestore
  await usersRef.doc(user.uid).set(userMap, SetOptions(merge: true));

  // ✅ Stockage dans SharedPreferences pour usage offline
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('uid', user.uid);
  await prefs.setString('prenom', user.prenom);
  await prefs.setDouble('poids', user.poids);
  await prefs.setDouble('taille', user.taille);
  await prefs.setString('activite', user.activite);
  await prefs.setInt('age', computedAge);
  if (user.birthDate != null) {
    await prefs.setString('birthDate', user.birthDate!);
  }
  await prefs.setDouble('tdee', user.tdee);

  logger.d("💾 Données utilisateur enregistrées dans SharedPreferences");
}


Future<AppUser?> getUserFromFirestore(String uid) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

  if (doc.exists && doc.data() != null) {
    return AppUser.fromMap(doc.data()!);
  } else {
    return null;
  }
}
/// 🔹 Fallback local : analyse avancée sans IA
String _fallbackLocalAnalysis(Map<String, dynamic> data) {
  double totalCal = 0, totalProt = 0, totalCarb = 0, totalFat = 0;

  // 🔸 Extraction des données selon format
  if (data.containsKey("jour")) {
    for (var meal in data["jour"]["repas"]) {
      totalCal += meal["calories"];
      totalProt += meal["protein"];
      totalCarb += meal["carbs"];
      totalFat += meal["fat"];
    }
  } else if (data.containsKey("semaine")) {
    for (var day in data["semaine"]) {
      totalCal += day["totaux"]["calories"];
      totalProt += day["totaux"]["proteins"];
      totalCarb += day["totaux"]["carbs"];
      totalFat += day["totaux"]["fats"];
    }
  }

  if (totalCal == 0) return "⚠️ Aucun repas enregistré, analyse impossible.";

  // 🔸 Calcul des ratios (% des calories totales)
  final protPct = ((totalProt * 4) / totalCal) * 100;
  final carbPct = ((totalCarb * 4) / totalCal) * 100;
  final fatPct = ((totalFat * 9) / totalCal) * 100;

  // 🔸 Analyse des ratios vs recommandations
  String interpretation = "📊 **Analyse locale des repas :**\n";
  interpretation += "- Calories : ${totalCal.toStringAsFixed(0)} kcal\n";
  interpretation += "- Répartition : Prot. ${protPct.toStringAsFixed(1)}% | Gluc. ${carbPct.toStringAsFixed(1)}% | Lip. ${fatPct.toStringAsFixed(1)}%\n\n";

  List<String> observations = [];
  if (protPct < 15) {
    observations.add("🔹 Apport en protéines trop faible pour soutenir la masse musculaire.");
  } else if (protPct > 30) {
    observations.add("🔹 Protéines très élevées, attention à l’excès.");
  }

  if (carbPct > 60) {
    observations.add("🔹 Glucides élevés, privilégie des sources complexes.");
  } else if (carbPct < 40) {
    observations.add("🔹 Glucides bas, risque de manque d’énergie.");
  }

  if (fatPct > 35) {
    observations.add("🔹 Lipides élevés, surveille les graisses saturées.");
  } else if (fatPct < 20) {
    observations.add("🔹 Lipides un peu bas, veille à consommer de bonnes graisses.");
  }

  if (observations.isEmpty) observations.add("✅ Ton profil nutritionnel est bien équilibré.");

  // 🔸 Conseils pratiques
  List<String> conseils = [
    "🥗 Varie tes sources de protéines (viande, poisson, légumineuses).",
    "🥑 Favorise les bonnes graisses (huile d’olive, noix).",
    "🍞 Choisis des glucides complexes (riz complet, patate douce)."
  ];

      interpretation += "**Observations :**\n";
      for (var o in observations) {
      interpretation += "- $o\n";
    }

    interpretation += "\n**Conseils pratiques :**\n";
    for (var c in conseils) {
      interpretation += "- $c\n";
}


  return interpretation;
}


/// 🔹 Analyse IA des repas avec fallback local si API indisponible


Future<String> analyzeMealsWithAI(Map<String, dynamic> mealsData) async {
  final String? apiKey = dotenv.env['MISTRAL_API_KEY'];
  final Uri url = Uri.parse("https://api.mistral.ai/v1/chat/completions");

  if (apiKey == null || apiKey.isEmpty) {
      throw Exception("❌ Clé API Mistral manquante dans .env");
    }

  try {
    final response = await http.post(
      url,
      headers: const {
        "Content-Type": "application/json",
        // Mistral utilise aussi "Bearer"
      }..addAll({"Authorization": "Bearer $apiKey"}),
      body: jsonEncode({
        "model": "mistral-small-latest", // ou "mistral-large-latest"
        "temperature": 0.6,
        "messages": [
          {
            "role": "system",
            "content": "Tu es un coach nutrition. Fournis un résumé clair et des conseils simples."
          },
          {
            "role": "user",
            "content": "Analyse ces repas : ${jsonEncode(mealsData)}. "
                "1) Résume en 3 phrases. "
                "2) Fournis 3 conseils pratiques (avec puces). "
                "3) Mentionne tout déséquilibre détecté."
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      return _fallbackLocalAnalysis(mealsData);
    }
  } catch (e) {
    return _fallbackLocalAnalysis(mealsData);
  }
}
Future<String> analyzeMealsViaBackend(
  Map<String, dynamic> mealsData, {
  String provider = "mistral",
}) async {
  // ⚠️ remplace par l’URL réelle : région + ID projet
  final uri = Uri.parse(
    "https://us-central1-nutriapp-4ea20.cloudfunctions.net/analyzeMeals",
  );

  final resp = await http
      .post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "data": mealsData,
          "provider": provider,
        }),
      )
      .timeout(const Duration(seconds: 50));

  if (resp.statusCode != 200) {
    throw Exception("Server ${resp.statusCode}: ${resp.body}");
  }

  final body = jsonDecode(resp.body);
  final text = (body["analysis"] as String?)?.trim() ?? "";
  if (text.isEmpty) {
    throw Exception("Empty analysis from server");
  }

  return "[API $provider] $text"; // le tag [API] sert juste à vérifier visuellement la source
}
/// Analyse locale = ton code fallback actuel
Future<String> analyzeMealsLocal(Map<String, dynamic> mealsData) async {
  // Ici, tu réutilises exactement ton code de fallback local
  // Actuellement c’est sûrement dans _fallbackLocalAnalysis
  return _fallbackLocalAnalysis(mealsData);
}
// lib/utils/fonctions.dart


extension StringCap on String {
  String cap({int max = 30}) {
    final t = trim();
    final chars = t.characters;
    return (chars.length <= max) ? t : chars.take(max).toString() + '…';
  }
}


