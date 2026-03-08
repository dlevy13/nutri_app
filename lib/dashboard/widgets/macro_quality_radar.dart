import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../widget/card_shell.dart';
import '../../../widget/section_title.dart';
import '../dashboard_notifier.dart';
import '../dashboard_state.dart';

// Enums top-level
enum _MacroBand { red, orange, yellow, green, blue }

// Provider local pour l’index touché (null = rien de sélectionné)
final _radarTouchedIndexProvider = StateProvider<int?>((ref) => null);

class MacroQualityRadar extends ConsumerWidget {
  const MacroQualityRadar({super.key});

  // Ordre des axes
  static const int axeLipides   = 0;
  static const int axeGlucides  = 1;
  static const int axeProteines = 2;
  static const int axeFibres    = 3;

  // Max par axe (référence pour normaliser 0..1)
  static const double maxLipides   = 3.0; // objectif visuel 2.0
  static const double maxGlucides  = 2.0; // objectif visuel 1.0
  static const double maxProteines = 1.5; // objectif visuel 1.0
  static const double maxFibres    = 1.5; // objectif visuel 1.0
  static const double goalRing = 0.75; // 75% du rayon

  // Seuils
  static const List<double> lipidesBands   = [1.0, 2.0, 3.0];
  static const List<double> glucidesBands  = [0.5, 1.0, 1.5];
  static const List<double> proteinesBands = [0.8, 1.1, 1.3];
  static const List<double> fibresBands    = [0.7, 1.0, 1.3];

  // Aliases utiles
  static const _kcalKeys   = ['Calories', 'kcal', 'Énergie', 'Energie'];
  static const _weightKeys = ['Poids', 'Poids (kg)', 'Weight', 'Weight (kg)', 'PoidsKg', 'WeightKg', 'weightKg'];

  // ---- Helpers ----
  double _norm(double v, double max) => max > 0 ? (v / max).clamp(0.0, 1.0) : 0.0;


  // ordre de sévérité (pire d'abord)
  int _severity(_MacroBand b) {
    switch (b) {
      case _MacroBand.red:    return 4;
      case _MacroBand.orange: return 3;
      case _MacroBand.yellow: return 2;
      case _MacroBand.green:  return 1;
      case _MacroBand.blue:   return 0;
    }
  }

  Color _colorForBand(ColorScheme cs, _MacroBand b) {
    switch (b) {
      case _MacroBand.red:    
        return Colors.red.shade600;       // fort danger, lisible sur fond clair
      case _MacroBand.orange: 
        return Colors.deepOrange.shade400; // alerte, mais moins dramatique
      case _MacroBand.yellow: 
        return Colors.amber.shade600;      // “attention / correct”
      case _MacroBand.green:  
        return Colors.teal.shade500;       // réussite sobre, moins “fluo” que green pur
      case _MacroBand.blue:   
        return Colors.indigo.shade500;     // excellent / surplus
    }
  }


  double _getByAliases(Map m, List<String> aliases) {
    if (m.isEmpty) return 0.0;
    for (final a in aliases) {
      final raw = m[a];
      if (raw == null) continue;
      if (raw is num) return raw.toDouble();
      final parsed = double.tryParse(raw.toString());
      if (parsed != null) return parsed;
    }
    return 0.0;
  }

  double _getFromNeedsThenConsumed(Map needs, Map consumed, List<String> aliases) {
    final n = _getByAliases(needs, aliases);
    if (n != 0.0) return n;
    return _getByAliases(consumed, aliases);
  }

  // ===========================================================================
  // === FENÊTRE D'INFORMATION (MODALE) ===
  // ===========================================================================
  void _showRadarInfoModal(BuildContext context) {
    final t = Theme.of(context).textTheme;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permet à la modale de grandir
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Titre ---
              Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 8),
                  Text('À propos du Radar de Qualité', style: t.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // --- Objectif ---
              const Text(
                'Objectif du Radar\n'
                'Ce radar évalue la *qualité* de vos apports sur 4 axes, au-delà des simples calories. L\'objectif est d\'atteindre 100% (le bord extérieur) sur chaque branche.',
              ),
              const SizedBox(height: 16),
              
              // --- Description des Axes ---
              const Text(
                'Description des Seuils (Branches)\n'
                'Chaque branche est notée de 0% (centre) à 100% (extérieur) :',
              ),
              const SizedBox(height: 8),
              
              // On utilise les vrais calculs du fichier pour la description
              RichText(
                text: TextSpan(
                  style: t.bodyMedium, // Style par défaut du thème
                  children: const [
                    TextSpan(text: '• Lipides (Ratio) : ', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: 'Rapport "bonnes" graisses (insaturées) / "mauvaises" (saturées). 100% = ratio de 2.0 ou plus.\n'),
                    
                    TextSpan(text: '• Glucides (Ratio) : ', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: 'Rapport glucides complexes / sucres simples. 100% = ratio de 1.0 ou plus.\n'),
                    
                    TextSpan(text: '• Protéines (Couverture) : ', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: 'Couverture de votre besoin en protéines. 100% = objectif atteint (ratio de 1.0).\n'),
                    
                    TextSpan(text: '• Fibres (Couverture) : ', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: 'Couverture de votre besoin en fibres. 100% = objectif atteint (ratio de 1.0).'),
                  ],
                ),
              ),
// --- NOUVELLE SECTION : COULEURS ---
              const Text(
                'Signification des Couleurs (Labels)\n'
                'Les titres des axes (Lipides, Glucides...) changent de couleur selon votre score :',
              ),
              const SizedBox(height: 8),
              
              RichText(
                text: TextSpan(
                  style: t.bodyMedium,
                  children: [
                    const TextSpan(text: '• ', style: TextStyle(color: Color(0xFF3949AB))), // indigo[500]
                    const TextSpan(
                      text: 'Bleu : ',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3949AB)),
                    ),
                    const TextSpan(text: 'Excellent ou surplus (au-dessus de l’objectif).\n'),

                    const TextSpan(text: '• ', style: TextStyle(color: Color(0xFF009688))), // teal[500]
                    const TextSpan(
                      text: 'Vert : ',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF009688)),
                    ),
                    const TextSpan(text: 'Bon (objectif atteint ou presque, ≈ 90%).\n'),

                    const TextSpan(text: '• ', style: TextStyle(color: Color(0xFFFFA000))), // amber[600]
                    const TextSpan(
                      text: 'Jaune : ',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFA000)),
                    ),
                    const TextSpan(text: 'Correct mais en-dessous (≈ 70%).\n'),

                    const TextSpan(text: '• ', style: TextStyle(color: Color(0xFFFF7043))), // deepOrange[400]
                    const TextSpan(
                      text: 'Orange : ',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF7043)),
                    ),
                    const TextSpan(text: 'À surveiller (≈ 50%).\n'),

                    const TextSpan(text: '• ', style: TextStyle(color: Color(0xFFE53935))), // red[600]
                    const TextSpan(
                      text: 'Rouge : ',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE53935)),
                    ),
                    const TextSpan(text: 'Insuffisant (loin de la cible).'),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'La couleur de remplissage du graphique prend la couleur de votre "pire" score pour attirer votre attention sur l\'axe à améliorer.',
                style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              
              // --- Interprétation ---
              const Text(
                'Interprétation\n'
                '• Une branche "creusée" (proche de 0%) indique un axe de progression.\n'
                '• Une branche "pleine" (proche de 100%) indique que l\'objectif est atteint.',
              ),
              
              // Espace pour la barre de navigation système (safe area)
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8), 
            ],
          ),
        );
      },
    );
  }
  // ===========================================================================


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final cs = Theme.of(context).colorScheme;

    // --- Données ---
    final consumed = state.consumedMacros;
    final needs = state.macroNeeds;

    // Lipides : (mono+poly)/sat 
    final sat  = (consumed['Saturés'] ?? 0.0).toDouble();
    final mono = (consumed['Monoinsaturés'] ?? 0.0).toDouble();
    final poly = (consumed['Polyinsaturés'] ?? 0.0).toDouble();
    final unsat = mono + poly;
    final bool lipidesHasData = (sat > 0) || (unsat > 0);
    final double lipidesRatio = (sat > 0) ? (unsat / sat) : (unsat > 0 ? maxLipides : 0.0);

    // Glucides (hors fibres) : complexes / sucres
    final fibres = (consumed['Fibres'] ?? 0.0).toDouble();
    final sucres = (consumed['Sucres'] ?? 0.0).toDouble();

    // Glucides totaux : essaie plusieurs clés possibles
    final totalCarbs = (consumed['Glucides'] ??
                        consumed['Carbohydrates'] ??
                        consumed['Carbs'] ??
                        0.0).toDouble();

    // Glucides nets = hors fibres (>= 0)
    final carbsNet = (totalCarbs - fibres) > 0 ? (totalCarbs - fibres) : 0.0;

    // Glucides complexes = glucides nets - sucres (>= 0)
    final complexes = (carbsNet - sucres) > 0 ? (carbsNet - sucres) : 0.0;

    final bool glucidesHasData = (sucres > 0) || (complexes > 0);

    // Ratio visé (plus c'est haut, mieux c'est) : complexes / sucres
    final double glucidesRatio = (sucres > 0)
        ? (complexes / sucres)
        : (complexes > 0 ? maxGlucides : 0.0);
    // Protéines : consommé / besoin
    final prot = (consumed['Protéines'] ?? 0.0).toDouble();
    final protGoal = (needs['Protéines'] ?? 1.0).toDouble();
    final bool proteinesHasData = protGoal > 0 && prot > 0;
    final double protRatio = protGoal > 0 ? prot / protGoal : 0.0;

    // Objectif Fibres : (14 g / 1000 kcal) & (0,35 g / kg) → moyenne si 2, sinon celui dispo, sinon 25 g
    final kcalNeed = _getFromNeedsThenConsumed(needs, consumed, _kcalKeys);
    final weightKg = _getFromNeedsThenConsumed(needs, consumed, _weightKeys);
    final fiberByKcal   = (kcalNeed > 0) ? (kcalNeed / 1000.0) * 14.0 : 0.0;
    final fiberByWeight = (weightKg > 0) ? (weightKg * 0.35) : 0.0;
    final double fiberGoal = (fiberByKcal > 0 && fiberByWeight > 0)
        ? (fiberByKcal + fiberByWeight) / 2.0
        : (fiberByKcal > 0 ? fiberByKcal : (fiberByWeight > 0 ? fiberByWeight : 25.0));
    final bool fibresHasData = fiberGoal > 0 && fibres > 0;
    final double fiberRatio = fiberGoal > 0 ? (fibres / fiberGoal) : 0.0;

    // Banding par axe
   _MacroBand _bandRelativeToGoal({
      required double value,
      required double objective,
      bool allowYellow = false,
    }) {
      if (objective <= 0) return _MacroBand.red;
      final r = value / objective; // ratio vs objectif

      if (r >= 1.0) return _MacroBand.blue;          // ≥ objectif → Bleu
      if (r >= 0.90) return _MacroBand.green;        // ~ à 90% de l’objectif
      if (allowYellow && r >= 0.70) return _MacroBand.yellow; // “correct”
      if (r >= 0.50) return _MacroBand.orange;       // à surveiller
      return _MacroBand.red;                         // insuffisant
    }


    final bLip = _bandRelativeToGoal(value: lipidesRatio,  objective: 2.0, allowYellow: false);
    final bGlu = _bandRelativeToGoal(value: glucidesRatio, objective: 1.0, allowYellow: false);
    final bPro = _bandRelativeToGoal(value: protRatio,     objective: 1.0, allowYellow: true);  // garde le jaune possible
    final bFib = _bandRelativeToGoal(value: fiberRatio,    objective: 1.0, allowYellow: false);


    // Couleur dynamique globale = pire band (pour polygone + légende), en ignorant les axes sans données
    final candidates = <_MacroBand>[
      if (lipidesHasData) bLip,
      if (glucidesHasData) bGlu,
      if (proteinesHasData) bPro,
      if (fibresHasData) bFib,
    ];
    final worst = candidates.isEmpty
        ? _MacroBand.blue
        : candidates.reduce((a, b) => _severity(a) >= _severity(b) ? a : b);
    final consumedColor = _colorForBand(cs, worst);

    // Couleurs par axe (pour nos labels custom)
    final colorLip = _colorForBand(cs, bLip);
    final colorGlu = _colorForBand(cs, bGlu);
    final colorPro = _colorForBand(cs, bPro);
    final colorFib = _colorForBand(cs, bFib);

    // --- Normalisation 0..1 par axe ---
    double _normToGoal(
      double v, {
      required double objective,
      required double max,
      required double goalRing,
    }) {
      if (max <= 0) return 0.0;
      final x = (v / max).clamp(0.0, 1.0);          // v exprimé en [0..max]
      final o = (objective / max).clamp(0.0, 1.0);  // objectif exprimé en [0..max]

      if (o <= 0) return x; // object. non défini → fallback simple

      if (x <= o) {
        // segment 0..objectif : on mappe linéairement jusqu’à goalRing
        return (x / o) * goalRing;
      } else {
        // segment objectif..max : on mappe de goalRing à 1.0
        final denom = (1.0 - o);
        if (denom <= 0) return 1.0;
        return goalRing + ((x - o) / denom) * (1.0 - goalRing);
      }
    }

    // Objectif : même rayon partout (polygone régulier)
    final goalEntries = List.generate(4, (_) => RadarEntry(value: goalRing));

    // Consommé : on garde ta logique par axe avec _norm(...)
   final consumedEntries = <RadarEntry>[
  // Lipides : objectif 2.0, max 3.0
      RadarEntry(value: _normToGoal(lipidesRatio,  objective: 2.0, max: maxLipides,   goalRing: goalRing)),
      // Glucides : objectif 1.0, max 2.0
      RadarEntry(value: _normToGoal(glucidesRatio, objective: 1.0, max: maxGlucides,  goalRing: goalRing)),
      // Protéines : objectif 1.0, max 1.5
      RadarEntry(value: _normToGoal(protRatio,     objective: 1.0, max: maxProteines, goalRing: goalRing)),
      // Fibres : objectif 1.0, max 1.5
      RadarEntry(value: _normToGoal(fiberRatio,    objective: 1.0, max: maxFibres,    goalRing: goalRing)),
    ];


    // --- DataSets ---
    final goalDataSet = RadarDataSet(
      dataEntries: goalEntries,
      borderColor: Colors.green,
      fillColor: Colors.green.withOpacity(0.20),
      borderWidth: 2,
      entryRadius: 2,
    );
    final consumedDataSet = RadarDataSet(
      dataEntries: consumedEntries,
      borderColor: Colors.blue, 
      fillColor: consumedColor.withOpacity(0.28),
      borderWidth: 2,
      entryRadius: 2,
    );

    // Styles réduits
    final axisLabelStyleBase = TextStyle(
      fontSize: 11,
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.80),
      fontWeight: FontWeight.w600,
    );
    final tickLabelStyle = TextStyle(fontSize: 9, color: Colors.grey.shade600);

    // --- Tooltip state (index touché) ---
    final touchedIndex = ref.watch(_radarTouchedIndexProvider);

    // Helper d’affichage des infos réelles selon l’axe
    Widget _tooltipPanel(int index) {
      String title; List<InlineSpan> lines;
      switch (index) {
        case axeLipides:
          title = 'Lipides';
          lines = [
            const TextSpan(text: 'Mono + Poly : ', style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: '${(mono + poly).toStringAsFixed(1)} g\n'),
            const TextSpan(text: 'Saturés : ', style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: '${sat.toStringAsFixed(1)} g\n'),
            const TextSpan(text: 'Ratio (Uns/Sat) : ', style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: lipidesRatio.isFinite ? lipidesRatio.toStringAsFixed(2) : '—'),
          ];
          break;
        case axeGlucides:
          title = 'Glucides (hors fibres)';
          lines = [
            const TextSpan(text: 'Glucides totaux : ', style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: '${totalCarbs.toStringAsFixed(1)} g\n'),

            const TextSpan(text: 'Glucides nets : ', style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: '${carbsNet.toStringAsFixed(1)} g\n'),

            const TextSpan(text: 'Sucres : ', style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: '${sucres.toStringAsFixed(1)} g\n'),

            const TextSpan(text: 'Complexes : ', style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: '${complexes.toStringAsFixed(1)} g\n'),

            const TextSpan(text: 'Ratio (Comp/Sim) : ', style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: glucidesRatio.isFinite ? glucidesRatio.toStringAsFixed(2) : '—'),
          ];
          break;
        case axeProteines:
          title = 'Protéines';
          lines = [
            const TextSpan(text: 'Consommé : ', style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: '${prot.toStringAsFixed(1)} g\n'),
            const TextSpan(text: 'Objectif : ', style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: '${protGoal.toStringAsFixed(1)} g\n'),
            const TextSpan(text: 'Couverture : ', style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: protRatio.isFinite ? protRatio.toStringAsFixed(2) : '—'),
          ];
          break;
        case axeFibres:
          title = 'Fibres';
          lines = [
            const TextSpan(text: 'Consommé : ', style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: '${fibres.toStringAsFixed(1)} g\n'),
            const TextSpan(text: 'Objectif : ', style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: '${fiberGoal.toStringAsFixed(1)} g\n'),
            const TextSpan(text: 'Couverture : ', style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: fiberRatio.isFinite ? fiberRatio.toStringAsFixed(2) : '—'),
          ];
          break;
        default:
          title = '';
          lines = const [TextSpan(text: '')];
      }
      return AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: consumedColor.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.25,
              ),
              children: [
                TextSpan(text: '• $title\n', style: TextStyle(fontWeight: FontWeight.w700, color: consumedColor)),
                ...lines,
              ],
            ),
          ),
        ),
      );
    }

    // === ANGLES pour nos labels custom ===
    // On suppose un départ en haut (−π/2), puis clockwise. Ajuste startAngle si besoin.
    const int axesCount = 4;
    final double startAngle = -math.pi / 2; // top
    final double step = (2 * math.pi) / axesCount;
    final List<double> angles = List.generate(axesCount, (i) => startAngle + i * step);

    return CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- TITRE + BOUTON INFO  ---
          Row(
            children: [
              const SectionTitle("🎯 Objectifs du jour"),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.grey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: "À propos du Radar de Qualité",
                onPressed: () {
                  _showRadarInfoModal(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Radar + overlay labels colorés + touch
          SizedBox(
            height: 260,
            child: Stack(
              children: [
                // --- RADAR ---
                RadarChart(
                  RadarChartData(
                    dataSets: [goalDataSet, consumedDataSet],
                    radarShape: RadarShape.polygon,

                    borderData: FlBorderData(show: false), // pas de bordure extérieure
                    radarBorderData: BorderSide.none,
                    gridBorderData: BorderSide(color: Colors.grey.shade300, width: 0.8),

                    // Ticks (anneaux) plus petits
                    tickCount: 4,
                    ticksTextStyle: tickLabelStyle,
                    tickBorderData: BorderSide(color: Colors.grey.shade300, width: 0.6),

                    // On masque les titres intégrés (on met une couleur transparente)
                    titleTextStyle: const TextStyle(color: Colors.transparent, fontSize: 1),
                    titlePositionPercentageOffset: 0.18,
                    getTitle: (index, angle) => RadarChartTitle(text: ''),

                    // Touch : mémorise l’index touché pour afficher le “tooltip” sous le graphe
                    radarTouchData: RadarTouchData(
                      enabled: true,
                      touchSpotThreshold: 30,
                      touchCallback: (event, response) {
                        final spot = response?.touchedSpot;
                        if (spot == null || !(event.isInterestedForInteractions)) {
                          ref.read(_radarTouchedIndexProvider.notifier).state = null;
                        } else {
                          ref.read(_radarTouchedIndexProvider.notifier).state = spot.touchedRadarEntryIndex;
                        }
                      },
                    ),
                  ),
                ),

                // --- OVERLAY : labels colorés par axe ---
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;
                      final r = math.min(w, h) / 2 * 0.92; // rayon approx. du radar
                      final rx = r / (w / 2);
                      final ry = r / (h / 2);
                      final style = (Color c) => axisLabelStyleBase.copyWith(color: c);

                      // Légers décalages vers l’extérieur pour éviter les chevauchements
                      const double push = 10.0;

                      Widget labelAt({
                        required double angle,
                        required String text,
                        required Color color,
                      }) {
                        final dx = math.cos(angle);
                        final dy = math.sin(angle);
                        // Position via Alignment (−1..1), puis petit translate le long du vecteur
                        return Align(
                          alignment: Alignment(dx * rx * 1.08, dy * ry * 1.08),
                          child: Transform.translate(
                            offset: Offset(dx * push, dy * push),
                            child: Text(text, style: style(color)),
                          ),
                        );
                      }

                      return Stack(
                        children: [
                          labelAt(angle: angles[axeLipides],   text: 'Lipides',   color: colorLip),
                          labelAt(angle: angles[axeGlucides],  text: 'Glucides',  color: colorGlu),
                          labelAt(angle: angles[axeProteines], text: 'Protéines', color: colorPro),
                          labelAt(angle: angles[axeFibres],    text: 'Fibres',    color: colorFib),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // “Tooltip” sous le graphe (texte + valeurs réelles)
          if (touchedIndex != null) Center(child: _tooltipPanel(touchedIndex!)),

          const SizedBox(height: 10),
          // Légende (Consommé prend la couleur dynamique globale)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _legendItem(Colors.green, "Objectif"),
              _legendItem(Colors.blue, "Consommé"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}