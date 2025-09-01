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
      "https://us-central1-nutriapp-4ea20.cloudfunctions.net/stravaTokenExchangeV2";
  final String proxyRefresh =
      "https://us-central1-nutriapp-4ea20.cloudfunctions.net/stravaRefreshTokenV2";

  /// ✅ Récupère l’URL OAuth pour Strava
  String getAuthUrl({required String uid}) {
  final isWebDebug = kIsWeb && !kReleaseMode;

  final callback = isWebDebug
      ? "http://localhost:5280/strava-callback"
      : "https://nutriapp-4ea20.web.app/strava-callback";

  final redirectUri = Uri.encodeComponent(callback);
  final state = Uri.encodeComponent(uid); // anti-CSRF + pour t’aider côté callback

  return "https://www.strava.com/oauth/authorize"
      "?client_id=170321"
      "&response_type=code"
      "&redirect_uri=$redirectUri"
      "&state=$state"
      "&approval_prompt=force"
      "&scope=read,activity:read_all";
}

  /// ✅ Stockage sécurisé des tokens
  Future<void> _storeTokens(String accessToken, String refreshToken) async {
    if (kIsWeb) {
      web.window.localStorage.setItem("access_token", accessToken);
      web.window.localStorage.setItem("refresh_token", refreshToken);
      //logger.d("✅ Tokens stockés dans localStorage Web");
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("access_token", accessToken);
      await prefs.setString("refresh_token", refreshToken);
      //logger.d("✅ Tokens stockés dans SharedPreferences");
    }
  }

  /// ✅ Lecture refresh_token
  Future<String?> _getRefreshToken() async {
    if (kIsWeb) {
      final token = web.window.localStorage.getItem("refresh_token");
      //logger.d("🔍 Refresh token lu depuis localStorage Web : $token");
      return token;
    } else {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("refresh_token");
      //logger.d("🔍 Refresh token lu depuis SharedPreferences : $token");
      return token;
    }
  }

  /// ✅ Lecture access_token
  Future<String?> getAccessToken() async {
    if (kIsWeb) {
      final token = web.window.localStorage.getItem("access_token");
      //logger.d("🔍 Access token lu depuis localStorage Web : $token");
      return token;
    } else {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("access_token");
      //logger.d("🔍 Access token lu depuis SharedPreferences : $token");
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

  /// ✅ Rafraîchit le token via proxy Firebase (POST JSON)
Future<void> refreshAccessToken() async {
  logger.d("🚀 refreshAccessToken() appelée");

  final rt = await _getRefreshToken();
  if (rt == null || rt.isEmpty) {
    logger.d("❌ Aucun refresh_token trouvé → pas de refresh");
    return;
  }

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw Exception("Utilisateur non connecté");

  final res = await http.post(
    Uri.parse(proxyRefresh),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'uid': uid, 'refresh_token': rt}),
  );

  logger.d("📡 Réponse proxy refresh : ${res.statusCode} → ${res.body}");

  if (res.statusCode == 200) {
    final data = jsonDecode(res.body);
    final access = (data["access_token"] as String?) ?? "";
    final refresh = (data["refresh_token"] as String?) ?? "";

    if (access.isEmpty || refresh.isEmpty) {
      throw Exception("Réponse refresh incomplète");
    }

    // ⚠️ Très important : on remplace le refresh token local par le NOUVEAU
    await _storeTokens(access, refresh);
    //logger.d("✅ Nouveau token Strava rafraîchi avec succès");
  } else {
    throw Exception("❌ Échec refresh token Strava : ${res.statusCode} ${res.body}");
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

  /// ✅ Récupère les calories Strava pour une date donnée en utilisant le token rafraîchi
Future<double> getCaloriesForDate(DateTime date) async {
  // 1) Vérifie qu'on a au moins un token présent
  final existing = await getAccessToken();
  if (existing == null || existing.isEmpty) {
    logger.w("⛔ Aucun token trouvé → annulation de l'appel Strava");
    throw Exception("Utilisateur non connecté à Strava");
  }

  // 2) Rafraîchir avant l'appel (et donc mettre à jour localStorage/SharedPrefs)
  await refreshAccessToken();

  // 3) Récupérer le NOUVEAU token (celui qui vient d’être stocké)
  final token = await getAccessToken();
  if (token == null || token.isEmpty) {
    logger.w("⛔ Échec du refresh → token manquant");
    throw Exception("Token Strava invalide après refresh");
  }

  // 4) Calcul du début de semaine (local)
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final startOfWeek = DateTime(monday.year, monday.month, monday.day);
  final after = (startOfWeek.millisecondsSinceEpoch / 1000).round();

  final url = Uri.parse(
    "https://www.strava.com/api/v3/athlete/activities?after=$after&per_page=50"
  );

  final res = await http.get(url, headers: {"Authorization": "Bearer $token"});
  if (res.statusCode != 200) {
    logger.d("❌ Erreur API Strava : ${res.statusCode} → ${res.body}");
    throw Exception("Erreur API Strava");
  }

  final List<dynamic> activities = jsonDecode(res.body) as List<dynamic>;

  // 5) Filtrer sur la date demandée
  final String targetDay = date.toIso8601String().split("T")[0];
  double totalCalories = 0;

  for (final act in activities) {
    final map = act as Map<String, dynamic>;
    final startLocal = map["start_date_local"] as String?;
    if (startLocal == null) continue;

    final actDate = DateTime.parse(startLocal).toIso8601String().split("T")[0];
    if (actDate == targetDay) {
      final cals = map["calories"];
      if (cals is num) totalCalories += cals.toDouble();
    }
  }

  logger.d("🔥 Total calories Strava pour $targetDay : $totalCalories");
  return totalCalories;
}

Future<bool> isConnected() async {
  final token = await getAccessToken();
  return token != null && token.isNotEmpty;
}
 /// Lance l'URL d'autorisation Strava dans le navigateur.
  Future<void> launchAuthUrl() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw Exception("Utilisateur non connecté");

  final authUrl = getAuthUrl(uid: uid);

  if (kIsWeb) {
    web.window.location.href = authUrl; // PWA/web
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


