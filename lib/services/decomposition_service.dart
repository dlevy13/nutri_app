import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DecompositionService {
  final SupabaseClient _supabase;

  static const _edgeUrl =
      'https://jasofcbxjgnuydohlyzk.supabase.co/functions/v1/decompose-meal';

  DecompositionService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<Map<String, dynamic>> decompose(
    String text, {
    int servings = 1,
  }) async {
    final payload = {
      'description': text.trim(),
      'servings': servings,
    };

    // 🌐 WEB / PWA
    if (kIsWeb) {
      final res = await http.post(
        Uri.parse(_edgeUrl),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      // ❗ IMPORTANT : ne jamais throw avant d’avoir parsé
      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode != 200 || data['ok'] != true) {
        throw Exception(
          '❌ Edge error (WEB ${res.statusCode}): ${data['error'] ?? res.body}',
        );
      }

      return data;
    }

    // 📱 ANDROID / IOS NATIF
    final FunctionResponse res =
        await _supabase.functions.invoke(
      'decompose-meal',
      body: payload,
    );

    Map<String, dynamic> data;

    if (res.data is Map<String, dynamic>) {
      data = res.data as Map<String, dynamic>;
    } else if (res.data is String) {
      data = jsonDecode(res.data as String) as Map<String, dynamic>;
    } else {
      throw Exception('❌ Format de réponse inattendu');
    }

    if (res.status != 200 || data['ok'] != true) {
      throw Exception(
        '❌ Edge error (MOBILE ${res.status}): ${data['error'] ?? data}',
      );
    }

    return data;
  }
}
