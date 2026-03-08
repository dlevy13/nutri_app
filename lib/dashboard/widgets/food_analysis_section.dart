import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/meal.dart';
import '../dashboard_notifier.dart';
import '../../services/date_service.dart';



// ===========================================================================
// == CONSTANTES D'ANALYSE (CENTRALISÉES)
// ===========================================================================

// --- Seuils pour "À surveiller" ---
const double _imbalancedRatioThreshold = 1.0;  // Ratio < 1 = "À surveiller"
const double _fiberCarbThreshold = 0.1;        // Moins d'1g de fibres pour 10g de glucides

// --- Seuils pour "Bénéfiques" ---
const double _beneficialLipidRatioThreshold = 2.0; // Ratio > 2 = "Bénéfique"
const double _beneficialCarbRatioThreshold = 2.0; // Ratio > 2 = "Bénéfique"
const double _proteinCalorieThreshold = 0.15; // 15% kcal en protéines
const double _fiberThreshold = 3.0;           // 3g fibres par portion


// ===========================================================================
// == WIDGET "ANALYSE ALIMENTS" (COMPOSANT PRINCIPAL)
// ===========================================================================

class FoodAnalysisSection extends ConsumerStatefulWidget {
  const FoodAnalysisSection({super.key});

  @override
  ConsumerState<FoodAnalysisSection> createState() => _FoodAnalysisSectionState();
}

class _FoodAnalysisSectionState extends ConsumerState<FoodAnalysisSection> {
  // 0 = À surveiller, 1 = Bénéfiques
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // --- Le corps (la liste) ---
    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _selectedIndex == 0
          ? const ImbalancedFoodsList(key: ValueKey('imbalanced'))
          : const BeneficialFoodsList(key: ValueKey('beneficial')),
    );

    return Column(
      children: [
        // L'en-tête avec les boutons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             SectionTitle('Analyse des Aliments'),
            ToggleButtons(
              isSelected: [_selectedIndex == 0, _selectedIndex == 1],
              onPressed: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              borderRadius: BorderRadius.circular(8),
              selectedColor: Colors.white,
              fillColor: theme.colorScheme.primary,
              constraints: const BoxConstraints(minHeight: 32, minWidth: 40),
              children: [
                Tooltip(
                  message: "Aliments à surveiller",
                  child: Icon(Icons.warning_amber_rounded, size: 18),
                ),
                Tooltip(
                  message: "Aliments bénéfiques",
                  child: Icon(Icons.health_and_safety_outlined, size: 18),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Le corps est dans un CardShell
        CardShell(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sous-titre dynamique
              Text(
                _selectedIndex == 0 ? "Aliments à surveiller" : "Aliments bénéfiques",
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                 _selectedIndex == 0 
                    ? "Aliments riches en sucres (et pauvres en fibres) ou en graisses saturées."
                    : "Aliments qui se distinguent par leurs apports et bons ratios.",
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              body,
            ],
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// == WIDGET POUR LES ALIMENTS IMPACTANT LES RATIOS
// ===========================================================================

class ImbalancedFoodsList extends ConsumerWidget {
  const ImbalancedFoodsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // --- 1. Récupérer les totaux de la journée ---
    final consumedMacros = ref.watch(dashboardProvider.select((s) => s.consumedMacros));
    final totalSaturatedFat = consumedMacros['Saturés'] ?? 0.0;
    final totalSugars = consumedMacros['Sucres'] ?? 0.0;

    // --- 2. Récupérer les aliments de la journée ---
    final selectedDate = ref.watch(dashboardProvider.select((s) => s.selectedDate));
    final weeklyMeals = ref.watch(dashboardProvider.select((s) => s.weeklyMeals));
    final dateStr = DateService.formatStandard(selectedDate);
    final dailyAliments = weeklyMeals[dateStr] ?? [];

    // --- 3. Analyser chaque aliment et filtrer les problématiques ---
    final analyses = dailyAliments.map((aliment) {
      
      // --- Analyse Lipidique ---
      final unsaturatedFat = aliment.fatUnsaturated;
      final saturatedFat = aliment.fatSaturated ?? 0.0;
      final lipidRatio = (saturatedFat > 0) ? (unsaturatedFat / saturatedFat) : 999.0;
      final saturatedContribution = (totalSaturatedFat > 0) ? (saturatedFat / totalSaturatedFat) : 0.0;
      
      final isLipidProblem = lipidRatio < _imbalancedRatioThreshold; 
      
      
      // --- Analyse Glucidique ---
      final totalCarbs = aliment.carbs;
      final sugars = aliment.sucres ?? 0.0;
      final fiber = aliment.fiber ?? 0.0; 

      final complexCarbs = totalCarbs - sugars;
      final carbRatio = (sugars > 0) ? (complexCarbs / sugars) : 999.0;
      final sugarContribution = (totalSugars > 0) ? (sugars / totalSugars) : 0.0;
      
      final double fiberToCarbRatio = (totalCarbs > 0) ? (fiber / totalCarbs) : 0.0;

      // ✅ On utilise les constantes définies en haut du fichier
      final bool isHighSugar = carbRatio < _imbalancedRatioThreshold;
      final bool isLowInFiber = fiberToCarbRatio < _fiberCarbThreshold;

      final isCarbProblem = isHighSugar && isLowInFiber;

      // On stocke les résultats de l'analyse
      return {
        'aliment': aliment,
        'lipidRatio': lipidRatio,
        'isLipidProblem': isLipidProblem,
        'saturatedContribution': saturatedContribution,
        'carbRatio': carbRatio,
        'isCarbProblem': isCarbProblem,
        'sugarContribution': sugarContribution,
      };
    }).where((data) {
      // On garde l'aliment si l'un OU l'autre ratio pose problème
      return (data['isLipidProblem'] as bool) || (data['isCarbProblem'] as bool);
    }).toList();

    // Trier pour montrer les plus gros contributeurs en premier
    analyses.sort((a, b) {
      final contribA = (a['saturatedContribution'] as double) + (a['sugarContribution'] as double);
      final contribB = (b['saturatedContribution'] as double) + (b['sugarContribution'] as double);
      return contribB.compareTo(contribA); // Tri descendant
    });
    
    // Affichage conditionnel
    if (analyses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green.shade700),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Bravo ! Aucun aliment ne déséquilibre vos ratios aujourd'hui.",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    // Affiche la liste des aliments
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          children: analyses.map((data) {
            final aliment = data['aliment'] as Meal;
            final isEven = analyses.indexOf(data) % 2 == 0;
            
            final isLipidProblem = data['isLipidProblem'] as bool;
            final isCarbProblem = data['isCarbProblem'] as bool;

            // On construit le sous-titre dynamique
            List<Widget> details = [];

            if (isLipidProblem) {
              final lipidRatio = data['lipidRatio'] as double;
              final contribution = data['saturatedContribution'] as double;
              details.add(
                Text(
                  'Ratio L: ${lipidRatio.toStringAsFixed(1)} (Apporte ${(contribution * 100).toStringAsFixed(0)}% des saturés)',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                )
              );
            }

            if (isCarbProblem) {
              final carbRatio = data['carbRatio'] as double;
              final contribution = data['sugarContribution'] as double;
              details.add(
                Text(
                  'Ratio G: ${carbRatio.toStringAsFixed(1)} (Apporte ${(contribution * 100).toStringAsFixed(0)}% des sucres)',
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                )
              );
            }

            return Container(
              color: isEven ? Colors.orange.shade50.withOpacity(0.5) : Colors.transparent,
              child: ListTile(
                leading: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                title: Text("${aliment.name} (${aliment.quantity.toStringAsFixed(0)}g)"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: details,
                ),
                dense: true,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ===========================================================================
// == WIDGET POUR LES ALIMENTS BÉNÉFIQUES
// ===========================================================================

class BeneficialFoodsList extends ConsumerWidget {
  const BeneficialFoodsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // --- 1. Récupérer les totaux de la journée ---
    final consumedMacros = ref.watch(dashboardProvider.select((s) => s.consumedMacros));
    final totalProtein = consumedMacros['Protéines'] ?? 0.0;
    final totalFiber = consumedMacros['Fibres'] ?? 0.0;
    
    final totalCarbs = consumedMacros['Glucides'] ?? 0.0;
    final totalSugars = consumedMacros['Sucres'] ?? 0.0;
    final totalComplexCarbs = (totalCarbs - totalSugars).clamp(0.0, double.infinity);

    final totalFat = consumedMacros['Lipides'] ?? 0.0;
    final totalSaturatedFat = consumedMacros['Saturés'] ?? 0.0;
    final totalUnsaturatedFat = (totalFat - totalSaturatedFat).clamp(0.0, double.infinity);

    // --- 2. Récupérer les aliments de la journée ---
    final selectedDate = ref.watch(dashboardProvider.select((s) => s.selectedDate));
    final weeklyMeals = ref.watch(dashboardProvider.select((s) => s.weeklyMeals));
    final dateStr = DateService.formatStandard(selectedDate);
    final dailyAliments = weeklyMeals[dateStr] ?? [];

    // --- 3. Analyser chaque aliment et filtrer les bénéfiques ---
    final analyses = dailyAliments.map((aliment) {
      
      // --- 1. Analyse Lipidique ---
      final unsaturatedFat = aliment.fatUnsaturated;
      final saturatedFat = aliment.fatSaturated ?? 0.0;
      final lipidRatio = (saturatedFat > 0) ? (unsaturatedFat / saturatedFat) : 999.0;
      // ✅ On utilise la constante du fichier ET la vérification (unsaturatedFat > 0)
      final isLipidBenefit = (lipidRatio > _beneficialLipidRatioThreshold) && (unsaturatedFat > 0);
      final unsaturatedContribution = (totalUnsaturatedFat > 0) ? (unsaturatedFat / totalUnsaturatedFat) : 0.0;
      // --- 2. Analyse Glucidique ---
      final totalCarbs = aliment.carbs;
      final sugars = aliment.sucres ?? 0.0;
      final fiber = aliment.fiber ?? 0.0;
      
      final complexCarbs = (totalCarbs - sugars).clamp(0.0, double.infinity);
      final carbRatio = (sugars > 0) ? (complexCarbs / sugars) : 999.0;
      final complexCarbContribution = (totalComplexCarbs > 0) ? (complexCarbs / totalComplexCarbs) : 0.0;

      final double fiberToCarbRatio = (totalCarbs > 0) ? (fiber / totalCarbs) : 0.0;

      // ✅ On utilise les constantes du fichier
      final bool isLowSugar = carbRatio > _beneficialCarbRatioThreshold;
      final bool isHighFiber = fiberToCarbRatio >= _fiberCarbThreshold;

      final isCarbBenefit = isLowSugar || isHighFiber; 

      // --- 3. Analyse Protéines ---
      final protein = aliment.protein;
      final calories = aliment.calories;
      final proteinCalorieRatio = (calories > 0) ? (protein * 4) / calories : 0.0;
      // ✅ On utilise la constante du fichier
      final isProteinBenefit = proteinCalorieRatio > _proteinCalorieThreshold;
      final proteinContribution = (totalProtein > 0) ? (protein / totalProtein) : 0.0;

      // --- 4. Analyse Fibres ---
      // ✅ On utilise la constante du fichier
      final isFiberBenefit = fiber > _fiberThreshold;
      final fiberContribution = (totalFiber > 0) ? (fiber / totalFiber) : 0.0;

// --- 5. CONTRE-VÉRIFICATION : Est-il "À surveiller" ? ---  // ✅ <-- BLOC À AJOUTER
      // On ne veut pas qu'un aliment "à surveiller" se retrouve ici.

      // Problème lipidique (reprise logique ImbalancedFoodsList)
      final isLipidProblem = lipidRatio < _imbalancedRatioThreshold; 
      
      // Problème glucidique (reprise logique ImbalancedFoodsList)
      final bool isHighSugar = carbRatio < _imbalancedRatioThreshold;
      final bool isLowInFiber = fiberToCarbRatio < _fiberCarbThreshold;
      final isCarbProblem = isHighSugar && isLowInFiber;

      final bool isImbalanced = isLipidProblem || isCarbProblem;
      // On stocke les résultats de l'analyse
      return {
        'aliment': aliment,
        'isLipidBenefit': isLipidBenefit,
        'unsaturatedContribution': unsaturatedContribution,
        'isCarbBenefit': isCarbBenefit,
        'complexCarbContribution': complexCarbContribution,
        'isProteinBenefit': isProteinBenefit,
        'proteinContribution': proteinContribution,
        'isFiberBenefit': isFiberBenefit,
        'fiberContribution': fiberContribution,
        'isLowSugar': isLowSugar,
        'isHighFiber': isHighFiber,
        'isImbalanced': isImbalanced,
      };
    }).where((data) {
      // On garde l'aliment si AU MOINS UN critère est respecté
      final bool isBeneficial = (data['isLipidBenefit'] as bool) ||
                                (data['isCarbBenefit'] as bool) ||
                                (data['isProteinBenefit'] as bool) ||
                                (data['isFiberBenefit'] as bool);
      
      final bool isImbalanced = data['isImbalanced'] as bool;
      
      // ✅ On ne garde que les aliments bénéfiques QUI NE SONT PAS problématiques
      return isBeneficial && !isImbalanced;
    }).toList();

    // Trier pour montrer les plus gros contributeurs en premier
    analyses.sort((a, b) {
      final contribA = (a['unsaturatedContribution'] as double) + (a['complexCarbContribution'] as double) + (a['proteinContribution'] as double) + (a['fiberContribution'] as double);
      final contribB = (b['unsaturatedContribution'] as double) + (b['complexCarbContribution'] as double) + (b['proteinContribution'] as double) + (b['fiberContribution'] as double);
      return contribB.compareTo(contribA); // Tri descendant
    });
    
    // --- 4. Retirer les doublons ---
    final Map<String, Map<String, dynamic>> uniqueAnalyses = {};
    for (var data in analyses) {
      final aliment = data['aliment'] as Meal;
      if (!uniqueAnalyses.containsKey(aliment.name)) {
        uniqueAnalyses[aliment.name] = data;
      }
    }
    final finalAnalyses = uniqueAnalyses.values.toList();


    // Affichage conditionnel
    if (finalAnalyses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade700),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Aucun aliment ne se distingue particulièrement aujourd'hui.",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }
    
    // Affiche la liste des aliments
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          children: finalAnalyses.map((data) {
            final aliment = data['aliment'] as Meal;
            final isEven = finalAnalyses.indexOf(data) % 2 == 0;
            
            // On construit le sous-titre dynamique
            List<Widget> details = [];

            if (data['isLipidBenefit'] as bool) {
              final contribution = data['unsaturatedContribution'] as double;
              details.add(
                Text(
                  '👍 Bon Ratio L (Apporte ${(contribution * 100).toStringAsFixed(0)}% des insaturés)',
                  style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                )
              );
            }
            if (data['isCarbBenefit'] as bool) {
              final contribution = data['complexCarbContribution'] as double;
              final bool isLowSugar = data['isLowSugar'] as bool;
              final String label = isLowSugar ? "Bon Ratio G" : "Bons Glucides (Fibres)";
              details.add(
                Text(
                  '👍 $label (Apporte ${(contribution * 100).toStringAsFixed(0)}% des G. complexes)',
                  style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                )
              );
            }
            if (data['isProteinBenefit'] as bool) {
              final contribution = data['proteinContribution'] as double;
              details.add(
                Text(
                  '💪 Source Prot. (Apporte ${(contribution * 100).toStringAsFixed(0)}% des protéines)',
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                )
              );
            }
            if (data['isFiberBenefit'] as bool) {
              final contribution = data['fiberContribution'] as double;
              details.add(
                Text(
                  '🌿 Source Fibres (Apporte ${(contribution * 100).toStringAsFixed(0)}% des fibres)',
                  style: TextStyle(color: Colors.brown.shade600, fontSize: 12, fontWeight: FontWeight.w500),
                )
              );
            }

            return Container(
              color: isEven ? Colors.green.shade50.withOpacity(0.5) : Colors.transparent,
              child: ListTile(
                leading: Icon(Icons.health_and_safety_outlined, color: Colors.green.shade700),
                title: Text("${aliment.name} (${aliment.quantity.toStringAsFixed(0)}g)"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: details,
                ),
                dense: true,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ===========================================================================
// == WIDGETS UTILITAIRES (PUBLICS)
// ===========================================================================

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class CardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const CardShell({required this.child, this.padding = const EdgeInsets.all(16), super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}