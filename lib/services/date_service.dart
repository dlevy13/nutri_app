import 'package:intl/intl.dart';



/// Une classe utilitaire pour toutes les opérations liées aux dates.
/// Utilise le package `intl` pour une gestion robuste et localisée des dates.
class DateService {

  // =======================================================================
  // == FORMATAGE (DateTime -> String)
  // =======================================================================

  /// ✅ Formate une date en "yyyy-MM-dd".
  /// C'est le format STANDARD à utiliser pour la logique interne, les clés de base de données, etc.
  static String formatStandard(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

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
      print("Erreur de parsing standard pour la date: '$dateStr'. Erreur: $e");
      // Retourne une date par défaut pour éviter un crash
      return DateTime.now();
    }
  }

  /// ✅ Lit ("parse") un String au format français "dd/MM/yyyy".
  static DateTime parseFrench(String dateStr) {
    try {
      return DateFormat('dd/MM/yyyy').parse(dateStr.trim());
    } catch (e) {
      print("Erreur de parsing français pour la date: '$dateStr'. Erreur: $e");
      // Retourne une date par défaut pour éviter un crash
      return DateTime.now();
    }
  }
  
  // =======================================================================
  // == MANIPULATION
  // =======================================================================

  /// ✅ Renvoie le lundi de la semaine pour une date donnée.
  static DateTime startOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }
  
  /// ✅ Renvoie la date du jour + un offset en jours.
  static DateTime dayWithOffset(int offset) {
    return DateTime.now().add(Duration(days: offset));
  }
}