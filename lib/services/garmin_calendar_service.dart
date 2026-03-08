import 'package:shared_preferences/shared_preferences.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:http/http.dart' as http;

import '../log.dart';
//refonte
final SupabaseClient supabase = Supabase.instance.client;
class GarminCalendarService {
  static const String _cacheKey = 'garmin_calendar_cache';
  static const String _edgeUrl =
    'https://jasofcbxjgnuydohlyzk.supabase.co/functions/v1/garminCalendarV2';

  static const String _lastFetchKey = 'garmin_last_fetch';
 static const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imphc29mY2J4amdudXlkb2hseXprIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY4MzMzNTAsImV4cCI6MjA4MjQwOTM1MH0.2_EJl6zbR-aY2ofpPIWqEylZYFcKDWX8lmGjpePzj9A';

  /// ---------------------------------------------------------------------------
  /// Charge le calendrier Garmin :
  /// - essaie d'abord le cache (max 12h)
  /// - sinon télécharge directement depuis le lien Garmin enregistré
  /// ---------------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> loadCalendar({
  bool forceRefresh = false,
}) async {
  final prefs = await SharedPreferences.getInstance();

  final cached = prefs.getString(_cacheKey);
  final lastFetchStr = prefs.getString(_lastFetchKey);
  final lastFetch =
      lastFetchStr != null ? DateTime.tryParse(lastFetchStr) : null;

  final now = DateTime.now();
  final shouldRefresh =
      forceRefresh || lastFetch == null || now.difference(lastFetch).inHours > 12;

  if (cached != null && !shouldRefresh) {
    logger.d('📄 Lecture calendrier Garmin depuis cache local');
    return _parseCalendarData(cached);
  }

  try {
    logger.d("📡 Téléchargement calendrier Garmin via Supabase");

    String icsString;

// 🌐 WEB / PWA → appel HTTP direct avec Authorization
// 🌐 WEB / PWA → appel HTTP direct
if (kIsWeb) {
  final res = await http.post(
    Uri.parse(_edgeUrl),
    headers: {
      'apikey': supabaseAnonKey,
      'Authorization': 'Bearer $supabaseAnonKey',
      'Content-Type': 'application/json',
    },
  );

  if (res.statusCode != 200) {
    logger.d("❌ Garmin Web error status=${res.statusCode}");
    return [];
  }

  icsString = res.body;
}


// 📱 MOBILE → Supabase SDK normal
else {
  final res =
      await Supabase.instance.client.functions.invoke('garminCalendarV2');

  if (res.status != 200) {
    logger.d("❌ Supabase error status=${res.status}");
    return [];
  }

  icsString = res.data as String;
}


    // Cache local
    await prefs.setString(_cacheKey, icsString);
    await prefs.setString(_lastFetchKey, now.toIso8601String());

    logger.d("✅ Calendrier Garmin chargé (${icsString.length} caractères)");

    return _parseCalendarData(icsString);
  } catch (e) {
    logger.d("❗ Erreur téléchargement calendrier : $e");
    return [];
  }
}



  /// ---------------------------------------------------------------------------
  /// PARSING ICS → événements
  /// ---------------------------------------------------------------------------
  static List<Map<String, dynamic>> _parseCalendarData(String icsString) {
    final calendar = ICalendar.fromString(icsString);

    if (calendar.data.isEmpty) {
      logger.d("⚠️ ICS vide ou invalide");
      return [];
    }

    final events = calendar.data
        .where((e) => e['type'] == 'VEVENT')
        .map((e) {
          final summary = e['summary']?.toString() ?? "Sans titre";

          final dtStart = e['dtstart'];
          final dtEnd = e['dtend'];

          DateTime? start;
          DateTime? end;

          if (dtStart is IcsDateTime) {
            start = _parseRawDate(dtStart.dt);
          } else {
            start = _parseRawDate(dtStart?.toString());
          }

          if (dtEnd is IcsDateTime) {
            end = _parseRawDate(dtEnd.dt);
          } else {
            end = _parseRawDate(dtEnd?.toString());
          }

          return {
            "summary": summary,
            "start": start,
            "end": end,
          };
        })
        .where((e) => e["start"] != null)
        .toList();

    logger.d("📅 ${events.length} événements Garmin parsés");

    return events;
  }

  /// ---------------------------------------------------------------------------
  /// PARSE RAW DATE FROM ICS
  /// ---------------------------------------------------------------------------
  static DateTime? _parseRawDate(String? raw) {
    if (raw == null) return null;

    try {
      if (raw.contains("T")) return DateTime.parse(raw);

      // Format AAAAMMJJ
      if (RegExp(r'^\d{8}$').hasMatch(raw)) {
        final y = int.parse(raw.substring(0, 4));
        final m = int.parse(raw.substring(4, 6));
        final d = int.parse(raw.substring(6, 8));
        return DateTime(y, m, d);
      }
    } catch (e) {
      logger.d("Erreur parsing date ICS : $raw");
    }

    return null;
  }
}
