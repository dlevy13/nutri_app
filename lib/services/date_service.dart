import 'package:intl/intl.dart';
//refonte
/// Service centralisé pour toutes les opérations liées aux dates.
/// Compatible Hive, format interne unique : "yyyy-MM-dd".
class DateService {

  // =======================================================================
  // == FORMATAGE
  // =======================================================================

  /// Format interne standard : "yyyy-MM-dd"
  static String formatStandard(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Format français court : "dd/MM/yyyy"
  static String formatFrenchShort(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Format "Lundi 28 juillet"
  static String formatDayWithDate(DateTime date) {
    return DateFormat('EEEE d MMMM', 'fr_FR').format(date);
  }

  /// Format complet : "28 juillet 2025 à 14:05"
  static String formatFull(DateTime date) {
    return DateFormat('d MMMM yyyy \'à\' HH:mm', 'fr_FR').format(date);
  }

  // =======================================================================
  // == PARSING
  // =======================================================================

  /// Lit une date "yyyy-MM-dd".
  static DateTime parseStandard(String dateStr) {
    try {
      return DateTime.parse(dateStr.trim());
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Lit une date "dd/MM/yyyy".
  static DateTime parseFrench(String dateStr) {
    try {
      return DateFormat('dd/MM/yyyy').parse(dateStr.trim());
    } catch (_) {
      return DateTime.now();
    }
  }

  // =======================================================================
  // == MANIPULATION
  // =======================================================================

  /// Renvoie le début du jour local (00:00)
  static DateTime startOfLocalDay(DateTime d) {
    final l = d.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  /// Renvoie le lundi de la semaine locale
  static DateTime startOfWeek(DateTime d) {
    final day = startOfLocalDay(d);
    final delta = day.weekday - DateTime.monday;
    return day.subtract(Duration(days: delta));
  }

  /// Aujourd’hui + offset (ancré à 00:00)
  static DateTime dayWithOffset(int offset) {
    return startOfLocalDay(DateTime.now()).add(Duration(days: offset));
  }

  // =======================================================================
  // == CLÉS POUR HIVE
  // =======================================================================

  /// Clé du jour "yyyy-MM-dd"
  static String todayKey() {
    return formatStandard(startOfLocalDay(DateTime.now()));
  }

  /// Clé date "yyyy-MM-dd"
  static String dayKey(DateTime date) {
    return formatStandard(startOfLocalDay(date));
  }

  /// Clé semaine "week_yyyy-MM-dd"
  static String weekKey(DateTime date) {
    final monday = startOfWeek(date);
    return "week_${formatStandard(monday)}";
  }

  // =======================================================================
  // == 🔥 MÉTHODES MANQUANTES POUR AIManager
  // =======================================================================

  /// Convertit "week_2025-02-10" → "2025-02-10"
  /// (clé semaine envoyée au backend)
  static String toBackendWeekKey(String raw) {
    return raw
        .replaceAll("week_", "")
        .replaceAll("/", "-");
  }

  /// Convertit "11-02-2025" → "2025-02-11"
  /// (clé jour envoyée au backend)
  static String toBackendDayKey(String raw) {
    final cleaned = raw.replaceAll("/", "-");
    final parts = cleaned.split("-");

    if (parts.length != 3) return cleaned; // fallback

    final day = parts[0].padLeft(2, '0');
    final month = parts[1].padLeft(2, '0');
    final year = parts[2];

    return "$year-$month-$day";
  }
}
