import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../log.dart';

class StravaService {
  final String proxyOAuth =
      "https://us-central1-nutriapp-4ea20.cloudfunctions.net/stravaTokenExchange";
  final String proxyRefresh =
      "https://us-central1-nutriapp-4ea20.cloudfunctions.net/stravaRefreshToken";

  /// ✅ Récupère l’URL OAuth pour Strava
  String getAuthUrl() {
    // ✅ Détecte si on est en mode débogage web
  final isWebDebug = kIsWeb && !kReleaseMode;
  
  // On utilise l'URL de localhost pour le débogage, et l'URL de production sinon
  final redirectUri = isWebDebug 
      ? "http://localhost:5280/" // ❗️Adaptez le port si nécessaire
      : "https://nutriapp-4ea20.web.app/";

  return "https://www.strava.com/oauth/authorize"
      "?client_id=170321" // Remplacez par votre vrai Client ID si différent
      "&response_type=code"
      "&redirect_uri=$redirectUri"
      "&approval_prompt=force"
      "&scope=read,activity:read_all";
}

  /// ✅ Stockage sécurisé des tokens
  Future<void> _storeTokens(String accessToken, String refreshToken) async {
    if (kIsWeb) {
      web.window.localStorage.setItem("access_token", accessToken);
      web.window.localStorage.setItem("refresh_token", refreshToken);
      logger.d("✅ Tokens stockés dans localStorage Web");
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("access_token", accessToken);
      await prefs.setString("refresh_token", refreshToken);
      logger.d("✅ Tokens stockés dans SharedPreferences");
    }
  }

  /// ✅ Lecture refresh_token
  Future<String?> _getRefreshToken() async {
    if (kIsWeb) {
      final token = web.window.localStorage.getItem("refresh_token");
      logger.d("🔍 Refresh token lu depuis localStorage Web : $token");
      return token;
    } else {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("refresh_token");
      logger.d("🔍 Refresh token lu depuis SharedPreferences : $token");
      return token;
    }
  }

  /// ✅ Lecture access_token
  Future<String?> getAccessToken() async {
    if (kIsWeb) {
      final token = web.window.localStorage.getItem("access_token");
      logger.d("🔍 Access token lu depuis localStorage Web : $token");
      return token;
    } else {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("access_token");
      logger.d("🔍 Access token lu depuis SharedPreferences : $token");
      return token;
    }
  }

  /// ✅ Échange initial OAuth contre tokens via proxy Firebase
  Future<void> exchangeToken(String code) async {
    logger.d("🔄 Échange OAuth via proxy Firebase...");
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("Utilisateur non connecté");

    final res = await http.get(
      Uri.parse("$proxyOAuth?code=$code&uid=$uid"),
    );
    logger.d("📡 Réponse Proxy OAuth : ${res.statusCode} → ${res.body}");

    if (res.statusCode != 200) throw Exception("Échec OAuth Strava");

    final data = jsonDecode(res.body);
    final accessToken = data["access_token"] ?? "";
    final refreshToken = data["refresh_token"] ?? "";

    if (refreshToken.isEmpty) {
      logger.d("❌ Aucun refresh_token dans la réponse OAuth !");
    } else {
      logger.d("✅ refresh_token reçu : $refreshToken");
    }

    await _storeTokens(accessToken, refreshToken);
  }

  /// ✅ Rafraîchit le token via proxy Firebase (avec CORS actif)
  Future<void> refreshAccessToken() async {
    logger.d("🚀 refreshAccessToken() appelée");

    final refreshToken = await _getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      logger.d("❌ Aucun refresh_token trouvé → pas de refresh");
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("Utilisateur non connecté");

    final uri = Uri.parse(proxyRefresh).replace(queryParameters: {
      "refresh_token": refreshToken,
      "uid": uid,
    });

  final res = await http.get(uri);

    logger.d("📡 Réponse proxy refresh : ${res.statusCode} → ${res.body}");

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      await _storeTokens(data["access_token"], data["refresh_token"]);
      logger.d("✅ Nouveau token Strava rafraîchi avec succès");
    } else {
      logger.d("❌ Échec refresh token Strava");
    }
  }

  /// ✅ Récupère activités Strava (rafraîchit avant)
  Future<List<dynamic>> getActivities() async {
    await refreshAccessToken(); // 🔹 Garantit un token valide
    final token = await getAccessToken();
    if (token == null) throw Exception("Utilisateur non connecté à Strava");

    final res = await http.get(
      Uri.parse("https://www.strava.com/api/v3/athlete/activities?per_page=10"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      final activities = jsonDecode(res.body);
      logger.d("✅ Activités Strava récupérées : ${activities.length}");
      return activities;
    } else {
      logger.d("❌ Erreur API Strava : ${res.statusCode} → ${res.body}");
      throw Exception("Erreur API Strava");
    }
  }

  /// ✅ Récupère les calories brûlées Strava pour un jour donné
Future<double> getCaloriesForDate(DateTime date) async {
  // ✅ 1. Vérifie d'abord s'il y a un token
  final token = await getAccessToken();
  if (token == null || token.isEmpty) {
    logger.w("⛔ Aucun token trouvé → annulation de l'appel Strava");
    throw Exception("Utilisateur non connecté à Strava");
  }

  // ✅ 2. Ne rafraîchit qu’après validation du token
  await refreshAccessToken();

  // ✅ 3. Récupère à nouveau le token rafraîchi
  final refreshedToken = await getAccessToken();
  if (refreshedToken == null || refreshedToken.isEmpty) {
    logger.w("⛔ Échec du refresh → token manquant");
    throw Exception("Token Strava invalide après refresh");
  }

  // ✅ Récupération des activités de la semaine
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final startOfWeek = DateTime(monday.year, monday.month, monday.day);
  final after = (startOfWeek.millisecondsSinceEpoch / 1000).round();

  final url = Uri.parse(
    "https://www.strava.com/api/v3/athlete/activities?after=$after&per_page=50"
  );

  final res = await http.get(url, headers: {"Authorization": "Bearer $token"});
  if (res.statusCode != 200) throw Exception("Erreur API Strava : ${res.body}");

  final List<dynamic> activities = jsonDecode(res.body);

  // ✅ Filtrer les activités du jour sélectionné
  final String selectedDay = date.toIso8601String().split("T")[0];
  double totalCalories = 0;

  for (var act in activities) {
    final actDate = DateTime.parse(act["start_date_local"]).toIso8601String().split("T")[0];
    if (actDate == selectedDay) {
      // ✅ Strava renvoie parfois "calories", parfois non
      if (act.containsKey("calories") && act["calories"] != null) {
        totalCalories += act["calories"];
      }
    }
  }

  logger.d("🔥 Total calories Strava pour $selectedDay : $totalCalories");
  return totalCalories;
}
Future<bool> isConnected() async {
  final token = await getAccessToken();
  return token != null && token.isNotEmpty;
}
 /// Lance l'URL d'autorisation Strava dans le navigateur.
  Future<void> launchAuthUrl() async {
    final authUrl = getAuthUrl();

    if (kIsWeb) {
      // Sur PWA, on redirige l'onglet courant → fiable et évite les popups
      web.window.location.href = authUrl;
    } else {
      final uri = Uri.parse(authUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Impossible de lancer URL : $authUrl';
      }
    }
}
Future<Map<String, dynamic>?> getActivityDetails(int id) async {
  final token = await getAccessToken();
  if (token == null || token.isEmpty) return null;

  final uri = Uri.https('www.strava.com', '/api/v3/activities/$id');
  final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

  if (res.statusCode == 200) {
    return jsonDecode(res.body) as Map<String, dynamic>;
  } else {
    logger.e("❌ getActivityDetails($id) → ${res.statusCode} ${res.body}");
    return null;
  }
}
/// Supprime les tokens Strava du stockage local.
  Future<void> disconnect() async {
    if (kIsWeb) {
      web.window.localStorage.removeItem("access_token");
      web.window.localStorage.removeItem("refresh_token");
      logger.d("✅ Tokens Strava supprimés du localStorage Web");
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("access_token");
      await prefs.remove("refresh_token");
      logger.d("✅ Tokens Strava supprimés des SharedPreferences");
    }
  }
}


