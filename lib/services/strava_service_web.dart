import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as web;

import 'strava_service_shared.dart';

class StravaServiceWeb implements StravaServiceShared {
  final String proxyOAuth =
      "https://us-central1-nutriapp-4ea20.cloudfunctions.net/stravaTokenExchangeV2";

  final String proxyRefresh =
      "https://us-central1-nutriapp-4ea20.cloudfunctions.net/stravaRefreshTokenV2";

  final bool isWebDebug = kIsWeb && !kReleaseMode;

late final String redirectUri = isWebDebug
    ? "http://localhost:5280/strava-callback"
    : "https://nutriapp-4ea20.web.app/strava-callback";


  // ----------------------------------------------------------
  // 🚀 OAuth
  // ----------------------------------------------------------
  @override
  Future<void> launchAuthUrl(String uid) async {
    final scope = Uri.encodeComponent("read,activity:read_all");

    final url =
        "https://www.strava.com/oauth/authorize"
        "?client_id=170321"
        "&response_type=code"
        "&redirect_uri=$redirectUri"
        "&state=$uid"
        "&approval_prompt=force"
        "&scope=$scope";

    web.window.location.href = url;
  }

  // ----------------------------------------------------------
  // 🔁 Exchange OAuth → tokens (STOCKÉS LOCAL WEB)
  // ----------------------------------------------------------
  @override
  Future<void> exchangeToken(String code) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("Utilisateur non connecté");

    final res =
        await http.get(Uri.parse("$proxyOAuth?code=$code&uid=$uid"));

    if (res.statusCode != 200) {
      throw Exception("Échec OAuth Strava Web");
    }

    final data = jsonDecode(res.body);

    web.window.localStorage["access_token"] =
        data["access_token"] ?? "";
    web.window.localStorage["refresh_token"] =
        data["refresh_token"] ?? "";
  }

  // ----------------------------------------------------------
  // 🔄 Refresh token (via Cloud Function)
  // ----------------------------------------------------------
  @override
  Future<void> refreshAccessToken() async {
    final refreshToken = web.window.localStorage["refresh_token"];
    if (refreshToken == null || refreshToken.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final res = await http.post(
      Uri.parse(proxyRefresh),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'uid': uid,
        'refresh_token': refreshToken,
      }),
    );

    if (res.statusCode != 200) return;

    final data = jsonDecode(res.body);

    web.window.localStorage["access_token"] =
        data["access_token"] ?? "";
    web.window.localStorage["refresh_token"] =
        data["refresh_token"] ?? "";
  }

  // ----------------------------------------------------------
  // 🔐 Tokens (localStorage)
  // ----------------------------------------------------------
  @override
  Future<String?> getAccessToken() async {
    return web.window.localStorage["access_token"];
  }

  @override
  Future<String?> getRefreshToken() async {
    return web.window.localStorage["refresh_token"];
  }

  // ----------------------------------------------------------
  // ❌ Déconnexion
  // ----------------------------------------------------------
  @override
  Future<void> disconnect() async {
    web.window.localStorage.remove("access_token");
    web.window.localStorage.remove("refresh_token");
  }

  // ----------------------------------------------------------
  // ✅ Statut connexion
  // ----------------------------------------------------------
  @override
  Future<bool> isConnected() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ----------------------------------------------------------
  // 🏃 Activités (API Strava DIRECT — comme avant)
  // ----------------------------------------------------------
  @override
  Future<List<dynamic>> getActivitiesForDay(DateTime date) async {
    await refreshAccessToken();
    final token = await getAccessToken();
    if (token == null) return [];

    final startLocal = DateTime(date.year, date.month, date.day);
    final endLocal = startLocal.add(const Duration(days: 1));

    final after = startLocal.toUtc().millisecondsSinceEpoch ~/ 1000;
    final before = endLocal.toUtc().millisecondsSinceEpoch ~/ 1000;

    final url = Uri.https(
      "www.strava.com",
      "/api/v3/athlete/activities",
      {
        "after": after.toString(),
        "before": before.toString(),
        "per_page": "50",
      },
    );

    final res = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) return [];

    return jsonDecode(res.body) as List<dynamic>;
  }

  @override
  Future<Map<String, dynamic>?> getActivityDetails(int id) async {
    await refreshAccessToken();
    final token = await getAccessToken();
    if (token == null) return null;

    final url = Uri.https(
      "www.strava.com",
      "/api/v3/activities/$id",
    );

    final res =
        await http.get(url, headers: {"Authorization": "Bearer $token"});

    if (res.statusCode != 200) return null;

    return jsonDecode(res.body);
  }
}
