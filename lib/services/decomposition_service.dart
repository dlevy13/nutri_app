import 'dart:convert';
import 'package:http/http.dart' as http;

class DecompositionService {
  // ⚠️ remplace par l’URL de ta function si la région/projet changent
  static final Uri _endpoint = Uri.parse(
    "https://us-central1-nutriapp-4ea20.cloudfunctions.net/decomposeMeal",
  );

  final http.Client _client;
  DecompositionService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> decompose(String text, {int servings = 1}) async {
    final payload = {
      "description": text.trim(), // nouvelle TS
      "text": text.trim(),        // ancienne Python
      "servings": servings,
    };

    final resp = await _client
        .post(
          _endpoint,
          headers: const {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      throw Exception("decomposeMeal ${resp.statusCode}: ${resp.body}");
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
