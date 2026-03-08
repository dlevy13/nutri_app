import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'strava_service_shared.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StravaServiceMobile implements StravaServiceShared {
  final String proxyOAuth =
      "https://us-central1-nutriapp-4ea20.cloudfunctions.net/stravaTokenExchangeV2";

  final String proxyRefresh =
      "https://us-central1-nutriapp-4ea20.cloudfunctions.net/stravaRefreshTokenV2";

  @override
  Future<void> launchAuthUrl(String uid) async {
    final redirectUri = "https://nutriapp-4ea20.web.app/strava-callback";
    final scope = Uri.encodeComponent("read,activity:read_all");

    final url =
        "https://www.strava.com/oauth/authorize"
        "?client_id=170321"
        "&response_type=code"
        "&redirect_uri=$redirectUri"
        "&state=$uid"
        "&approval_prompt=force"
        "&scope=$scope";

    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Future<void> exchangeToken(String code) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final res = await http.get(Uri.parse("$proxyOAuth?code=$code&uid=$uid"));

    final data = jsonDecode(res.body);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("access_token", data["access_token"]);
    await prefs.setString("refresh_token", data["refresh_token"]);
  }

  @override
  Future<void> refreshAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final rt = prefs.getString("refresh_token");
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (rt == null || uid == null) return;

    final res = await http.post(
      Uri.parse(proxyRefresh),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'uid': uid, 'refresh_token': rt}),
    );

    final data = jsonDecode(res.body);
    await prefs.setString("access_token", data["access_token"]);
    await prefs.setString("refresh_token", data["refresh_token"]);
  }

  @override
  Future<String?> getAccessToken() async {
    return (await SharedPreferences.getInstance()).getString("access_token");
  }

  @override
  Future<String?> getRefreshToken() async {
    return (await SharedPreferences.getInstance()).getString("refresh_token");
  }

  @override
  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("access_token");
    await prefs.remove("refresh_token");
  }

  @override
  Future<bool> isConnected() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  @override
 Future<List<dynamic>> getActivitiesForDay(DateTime date) async {
  await refreshAccessToken();
  final token = await getAccessToken();
  if (token == null) return [];

  // ✅ CORRECT : local → UTC
  final startLocal = DateTime(date.year, date.month, date.day);
  final startUtc = startLocal.toUtc();
  final endUtc = startUtc.add(const Duration(days: 1));

  final url = Uri.https(
    "www.strava.com",
    "/api/v3/athlete/activities",
    {
      "after": (startUtc.millisecondsSinceEpoch ~/ 1000).toString(),
      "before": (endUtc.millisecondsSinceEpoch ~/ 1000).toString(),
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

    final url = Uri.https("www.strava.com", "/api/v3/activities/$id");
    final res = await http.get(url, headers: {"Authorization": "Bearer $token"});
    return jsonDecode(res.body);
  }
}
