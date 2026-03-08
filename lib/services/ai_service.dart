import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_config.dart';

final supabase = Supabase.instance.client;

class AIService {

  /// Analyse via Supabase Edge Function
  Future<String> analyzeMealsViaBackend(
    Map<String, dynamic> mealsData, {
    String provider = ApiConfig.defaultProvider,
  }) async {
    try {
      final res = await supabase.functions.invoke(
        ApiConfig.analyzeMeals,
        body: {
          'data': mealsData,
          'provider': provider,
        },
      );

      if (res.status != 200) {
        throw Exception('analyze-meals failed (status ${res.status})');
      }

      final Map<String, dynamic> json =
          Map<String, dynamic>.from(res.data);

      return json['analysis'] as String;

    } catch (e) {
      throw Exception('Supabase analyze-meals unavailable: $e');
    }
  }
}
