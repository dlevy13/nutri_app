import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // ✅ L'URL de votre fonction Firebase
  final String backendUrl = "https://us-central1-nutriapp-4ea20.cloudfunctions.net/analyzeMealsV2";

  /// Appelle votre backend Firebase pour obtenir l'analyse.
  Future<String> analyzeMealsViaBackend(
    Map<String, dynamic> mealsData, {
    String provider = "mistral", // "mistral" ou "openai"
  }) async {
    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "data": mealsData,
          "provider": provider,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['analysis'] as String;
      } else {
        // Gère les erreurs renvoyées par la fonction Firebase
        final errorData = jsonDecode(response.body);
        print("Erreur du backend (${response.statusCode}): ${errorData['error']}");
        throw Exception("Erreur du backend: ${errorData['error']}");
      }
    } catch (e) {
      print("Erreur de communication avec le service d'IA : $e");
      throw Exception("Analyse IA indisponible. (${e.toString()})");
    }
  }
}