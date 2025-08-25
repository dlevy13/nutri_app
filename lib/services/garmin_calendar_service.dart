import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:icalendar_parser/icalendar_parser.dart';
import '../log.dart'; // garde ton logger

class GarminCalendarService {
  static const String _cacheKey = 'garmin_calendar_cache';
  static const String _lastFetchKey = 'garmin_last_fetch';
  static const String _icalUrl = 'https://us-central1-nutriapp-4ea20.cloudfunctions.net/garminCalendarV2';


  /// ✅ Récupère l’URL Garmin sécurisée depuis Firestore
  static Future<String?> _getGarminLink() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    final link = doc['garminLink'] as String?;
    if (link != null && link.startsWith('https://') && link.contains('garmin.com')) {
      return doc.data()?['garminLink'];
    }
    return null;
  }

  /// ✅ Version mise à jour de loadCalendar : récupère lien Firestore + cache existant
  static Future<List<Map<String, dynamic>>> loadCalendar({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_cacheKey);
    final now = DateTime.now();
    final lastFetch = DateTime.tryParse(prefs.getString(_lastFetchKey) ?? '');

    final shouldRefresh = forceRefresh || lastFetch == null || now.difference(lastFetch).inHours > 12;

    if (cachedData != null && !shouldRefresh) {
      return _parseCalendarData(cachedData);
    }

    final garminUrl = await _getGarminLink();
    if (garminUrl == null) {
      logger.d('❌ Aucun lien Garmin valide trouvé dans Firestore');
      return [];
    }

    try {
      final garminLink = await _getGarminLink();
      if (garminLink == null || garminLink.isEmpty) {
        logger.d('⚠️ Aucun lien Garmin enregistré, tentative avec proxy sans paramètre');
      }

      // ✅ Construire URL avec le lien encodé
      final requestUrl = garminLink != null && garminLink.isNotEmpty
          ? '$_icalUrl?url=${Uri.encodeComponent(garminLink)}'
          : _icalUrl;

      logger.d('📡 Téléchargement calendrier via proxy: $requestUrl');

      final response = await http.get(Uri.parse(requestUrl));
      if (response.statusCode == 200) {
        await prefs.setString(_cacheKey, response.body);
        await prefs.setString(_lastFetchKey, now.toIso8601String());
        logger.d('✅ Calendrier téléchargé (${response.body.length} caractères)');
        return _parseCalendarData(response.body);
      } else {
        logger.d('❌ Erreur HTTP ${response.statusCode}');
        return [];
      }
    } catch (e) {
      logger.d('❗ Erreur lors de la requête : $e');
      return [];
    }
  }

  /// ✅ Parsing identique à avant
  static List<Map<String, dynamic>> _parseCalendarData(String icsString) {
    final calendar = ICalendar.fromString(icsString);

    if (calendar.data.isEmpty) {
      logger.d('⚠️ Aucun événement trouvé dans le .ics');
      return [];
    }

    final events = calendar.data
        .where((e) => e['type'] == 'VEVENT')
        .map((e) {
          final summary = e['summary']?.toString() ?? 'Sans titre';
          final dtstart = e['dtstart'];
          final dtend = e['dtend'];

          final DateTime? start = dtstart is IcsDateTime
              ? _convertIcsDateTime(dtstart)
              : _parseRawDate(dtstart?.toString());
          final DateTime? end = dtend is IcsDateTime
              ? _convertIcsDateTime(dtend)
              : _parseRawDate(dtend?.toString());

          return {'summary': summary, 'start': start, 'end': end};
        })
        .where((e) => e['start'] != null)
        .toList();

    logger.d('📅 ${events.length} événements parsés');
    for (var e in events.take(5)) {
      logger.d("• ${e['summary']} | ${e['start']} → ${e['end']}");
    }
    return events;
  }

  static DateTime? _convertIcsDateTime(IcsDateTime icsDateTime) {
    final raw = icsDateTime.dt;
    return _parseRawDate(raw);
  }

  static DateTime? _parseRawDate(String? raw) {
    if (raw == null) return null;
    try {
      if (raw.contains('T')) {
        return DateTime.parse(raw);
      } else if (RegExp(r'^\d{8}$').hasMatch(raw)) {
        final year = int.parse(raw.substring(0, 4));
        final month = int.parse(raw.substring(4, 6));
        final day = int.parse(raw.substring(6, 8));
        return DateTime(year, month, day);
      }
    } catch (e) {
      logger.d("Erreur parsing IcsDateTime: $raw");
    }
    return null;
  }
}
