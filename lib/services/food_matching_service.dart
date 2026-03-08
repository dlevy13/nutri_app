import 'package:characters/characters.dart';
import '../models/aliment_usuel.dart';
import 'fonctions.dart';
//refonte
class FoodMatchingService {
  final List<AlimentUsuel> alimentsUsuels;

  // --- Scores constants ---
  static const int _kExactMatchScore = 3000;
  static const int _kWordSetMatchBaseScore = 2400;
  static const int _kHighCoverageBaseScore = 2000;
  static const int _kMediumCoverageBaseScore = 1500;
  static const int _kStartsWithScore = 900;
  static const int _kMatchThreshold = 1200;

  FoodMatchingService({required this.alimentsUsuels});

  // ===========================================================================
  // PUBLIC API : poids usuel pour un nom donné
  // ===========================================================================
  AlimentUsuel? getPoidsUsuel(String nom) {
    final raw = nom.trim();
    if (raw.isEmpty || alimentsUsuels.isEmpty) return null;

    final cleaned = _stripNoSugarMentions(raw);
    final normalized = normalize(cleaned);
    final tokens = _tokens(cleaned);
    if (tokens.isEmpty) return null;

    final sugarLead = _isSugarLead(cleaned);

    AlimentUsuel? best;
    int bestScore = -1;

    for (final a in alimentsUsuels) {
      final keyRaw = a.aliment.trim();
      if (keyRaw.isEmpty) continue;

      final keyNorm = normalize(keyRaw);
      final keyTokens = _tokens(keyRaw);

      // Empêcher "sucre" de matcher tout le reste
      if (!sugarLead && keyNorm.startsWith("sucre")) continue;

      // Garde-fou lexical : intersection obligatoire
      final nameSet = _tokenSet(normalized);
      final keySet = _tokenSet(keyNorm);
      if (nameSet.intersection(keySet).isEmpty) continue;

      // === Score matching ===
      int score = _computeMatchScore(
        nameNorm: normalized,
        nameWords: tokens,
        keyNorm: keyNorm,
        keyWords: keyTokens,
      );

      if (score > bestScore) {
        bestScore = score;
        best = a;
      }
    }

    if (best != null && bestScore >= _kMatchThreshold) return best;
    return null;
  }

  // ===========================================================================
  // SCORE MATCHING LOGIC
  // ===========================================================================
  int _computeMatchScore({
    required String nameNorm,
    required List<String> nameWords,
    required String keyNorm,
    required List<String> keyWords,
  }) {
    // Exact match
    if (nameNorm == keyNorm) return _kExactMatchScore;

    // Word sets identical
    final setName = nameWords.toSet();
    final setKey = keyWords.toSet();
    if (setName.length == setKey.length && setName.containsAll(setKey)) {
      return _kWordSetMatchBaseScore + keyWords.length;
    }

    // Coverage (token overlap)
    final cov = _coverageScore(
      nameWords: nameWords,
      keyWords: keyWords,
      nameNorm: nameNorm,
    );

    if (cov >= 0.9) return _kHighCoverageBaseScore + keyWords.length;
    if (cov >= 0.7) return _kMediumCoverageBaseScore + (cov * 100).round();

    // Starts with single word
    if (keyWords.length == 1) {
      final k = keyWords.first;
      if (nameNorm.startsWith("$k ") || nameNorm == k) {
        return _kStartsWithScore;
      }
    }

    return 0;
  }

  // ===========================================================================
  // TOKENS / STEMS / NORMALIZATION
  // ===========================================================================

  List<String> _tokens(String s) {
    return normalize(s)
        .split(RegExp(r'[^a-z0-9%]+'))
        .where((w) => w.isNotEmpty && w.length > 1)
        .map(_stem)
        .toList();
  }

  String _stem(String w) {
    if (w.length >= 3 && w.endsWith('s')) {
      return w.substring(0, w.length - 1);
    }
    return w;
  }

  Set<String> _tokenSet(String s) => _tokens(s).toSet();

  // ===========================================================================
  // COVERAGE SCORE
  // ===========================================================================
  double _coverageScore({
    required List<String> nameWords,
    required List<String> keyWords,
    required String nameNorm,
  }) {
    if (keyWords.isEmpty) return 0;

    final nameSet = _tokenSet(nameNorm);
    final keySet = keyWords.toSet();

    int hits = 0;
    for (final w in keySet) {
      if (nameSet.contains(w)) hits++;
    }

    return hits / keySet.length;
  }

  // ===========================================================================
  // SUCRE → règles métiers
  // ===========================================================================
  bool _isSugarLead(String input) {
    final s = normalize(input);
    return RegExp(r'^sucre(s|e|es)?\b').hasMatch(s);
  }

  String _stripNoSugarMentions(String input) {
    var s = normalize(input);
    s = s
        .replaceAll(RegExp(r'\b(sans|0|zero)\s+sucre(s)?\b'), '')
        .replaceAll(RegExp(r'\bnon\s+sucre(e|es|s)?\b'), '')
        .replaceAll(RegExp(r'\bpeu\s+sucre(e|es|s)?\b'), '')
        .replaceAll(RegExp(r'\bunsweetened\b'), '')
        .replaceAll(RegExp(r'\bsugar[-\s]?free\b'), '')
        .trim();

    return s.isEmpty ? input : s;
  }
}
