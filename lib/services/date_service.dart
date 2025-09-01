import 'package:intl/intl.dart';



/// Une classe utilitaire pour toutes les opérations liées aux dates.
/// Utilise le package `intl` pour une gestion robuste et localisée des dates.
class DateService {

  // =======================================================================
  // == FORMATAGE (DateTime -> String)
  // =======================================================================

  /// ✅ Formate une date en "yyyy-MM-dd".
  /// C'est le format STANDARD à utiliser pour la logique interne, les clés de base de données, etc.
  
  /// ✅ Formate une date en "dd/MM/yyyy".
  /// À n'utiliser que pour l'AFFICHAGE à l'utilisateur.
  static String formatFrenchShort(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
  
  /// ✅ Formate une date en "Lundi 28 juillet".
  static String formatDayWithDate(DateTime date) {
    // 'fr_FR' assure que les noms des jours et mois sont en français.
    return DateFormat('EEEE d MMMM', 'fr_FR').format(date);
  }

  /// ✅ Formate une date longue avec heure : "28 juillet 2025 à 14:05"
  static String formatFull(DateTime date) {
    return DateFormat('d MMMM yyyy \'à\' HH:mm', 'fr_FR').format(date);
  }

  // =======================================================================
  // == PARSING (String -> DateTime)
  // =======================================================================
  
  /// ✅ Lit ("parse") un String au format standard "yyyy-MM-dd".
  static DateTime parseStandard(String dateStr) {
    try {
      return DateTime.parse(dateStr.trim());
    } catch (e) {
      //print("Erreur de parsing standard pour la date: '$dateStr'. Erreur: $e");
      // Retourne une date par défaut pour éviter un crash
      return DateTime.now();
    }
  }

  /// ✅ Lit ("parse") un String au format français "dd/MM/yyyy".
  static DateTime parseFrench(String dateStr) {
    try {
      return DateFormat('dd/MM/yyyy').parse(dateStr.trim());
    } catch (e) {
      //print("Erreur de parsing français pour la date: '$dateStr'. Erreur: $e");
      // Retourne une date par défaut pour éviter un crash
      return DateTime.now();
    }
  }
  
  // =======================================================================
  // == MANIPULATION
  // =======================================================================

  /// ✅ Renvoie le lundi de la semaine pour une date donnée.
 static DateTime startOfLocalDay(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}
static DateTime startOfWeek(DateTime d) {
  final day = startOfLocalDay(d);
  final delta = day.weekday - DateTime.monday; // 0 si lundi
  return day.subtract(Duration(days: delta));
}
/// ✅ Formate une date en "yyyy-MM-dd".
  /// C'est le format STANDARD à utiliser pour la logique interne, les clés de base de données, etc.
  
static String formatStandard(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
  
  /// ✅ Renvoie la date du jour + un offset en jours.
  /// ✅ Aujourd’hui + offset, **ancré** à 00:00 local pour un comportement cohérent.
static DateTime dayWithOffset(int offset) {
  return startOfLocalDay(DateTime.now()).add(Duration(days: offset));
}
/// ✅ Clé jour **canonique** pour Firestore : "yyyy-MM-dd" (local).
static String firestoreDayKey(DateTime date) {
  return formatStandard(startOfLocalDay(date));
}
/// ✅ Clé semaine moderne : "week_yyyy-MM-dd" (lundi local).
static String firestoreWeekKey(DateTime date) {
  final monday = startOfWeek(date);
  return "week_${formatStandard(monday)}";
}

  /// Génère une clé jour au format Firestore : "DD_MM_YYYY"
  /// ⚠️ Legacy: "DD_MM_YYYY" (évite de l'utiliser pour du nouveau code)
@Deprecated('Utilise firestoreDayKey(...)')
static String dayKey(DateTime date) {
  final d = startOfLocalDay(date);
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final yyyy = d.year.toString();
  return "${dd}_${mm}_${yyyy}";
}

  /// Génère une clé semaine au format Firestore : "week_YYYY_MM_DD" (lundi de la semaine)
  /// ⚠️ Legacy: "week_YYYY_MM_DD"
@Deprecated('Utilise firestoreWeekKey(...)')
static String weekKey(DateTime date) {
  final monday = startOfWeek(date);
  final dd = monday.day.toString().padLeft(2, '0');
  final mm = monday.month.toString().padLeft(2, '0');
  final yyyy = monday.year.toString();
  return "week_${yyyy}_${mm}_${dd}";
}
  /// "week_YYYY_MM_DD" | "week_YYYY-MM-DD" -> "YYYY-MM-DD"
  /// "week_YYYY_MM_DD" | "week_YYYY-MM-DD" | "YYYY-MM-DD" -> "YYYY-MM-DD" (backend)
static String toBackendWeekKey(String weekDocId) {
  final r = RegExp(r'^(?:week_)?(\d{4})[-_](\d{2})[-_](\d{2})$');
  final m = r.firstMatch(weekDocId.trim());
  if (m == null) {
    throw ArgumentError('weekDocId invalide: $weekDocId (attendu: week_YYYY_MM_DD)');
  }
  return "${m.group(1)}-${m.group(2)}-${m.group(3)}";
}

/// "DD_MM_YYYY" | "DD-MM-YYYY" | "YYYY-MM-DD" -> "DD-MM-YYYY" (backend jour)
static String toBackendDayKey(String dayDocId) {
  final s = dayDocId.trim();

  // 1) DD[-_]MM[-_]YYYY -> DD-MM-YYYY
  final rDMY = RegExp(r'^(\d{2})[-_](\d{2})[-_](\d{4})$');
  final mDMY = rDMY.firstMatch(s);
  if (mDMY != null) {
    return "${mDMY.group(1)}-${mDMY.group(2)}-${mDMY.group(3)}";
  }

  // 2) YYYY[-_]MM[-_]DD -> DD-MM-YYYY
  final rYMD = RegExp(r'^(\d{4})[-_](\d{2})[-_](\d{2})$');
  final mYMD = rYMD.firstMatch(s);
  if (mYMD != null) {
    return "${mYMD.group(3)}-${mYMD.group(2)}-${mYMD.group(1)}";
  }

  throw ArgumentError('dayDocId invalide: $dayDocId (attendu: DD_MM_YYYY ou YYYY-MM-DD)');
}
  
}