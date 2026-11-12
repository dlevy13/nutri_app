Map<String, double> calculateMacroNeeds({
  required double weightKg,
  required double tdee,
  required double stravaCals,
  required String typeToday,
  required String typeTomorrow,
}) {
  double calorieMultiplier = 1.0;
  double proteinPerKg = 2.0;
  double carbShare = 0.45;
  double fiberTarget = 30.0;

  switch (typeToday) {
    case 'Affûtage':
      calorieMultiplier = 0.90;
      carbShare = 0.50;
      fiberTarget = 25.0;
      break;
    case 'Intensité':
      calorieMultiplier = 1.05;
      proteinPerKg = 2.1;
      carbShare = 0.55;
      fiberTarget = 30.0;
      break;
    case 'Endurance':
      calorieMultiplier = 1.10;
      carbShare = 0.60;
      fiberTarget = 35.0;
      break;
    case 'Repos':
    default:
      calorieMultiplier = 1.0;
      carbShare = 0.45;
      fiberTarget = 30.0;
      break;
  }

  if (typeTomorrow == 'Endurance' && typeToday == 'Repos') {
    calorieMultiplier = 1.05;
    carbShare = 0.55;
    fiberTarget = 30.0;
  }

  final adjustedTdee = tdee * calorieMultiplier;
  final tdeeFinal = adjustedTdee + stravaCals;

  final proteins = weightKg * proteinPerKg;
  final remainingCalories = tdeeFinal - (proteins * 4);
  final fatShare = 1.0 - carbShare;
  final carbs = (remainingCalories > 0 ? remainingCalories * carbShare : 0) / 4;
  final fats = (remainingCalories > 0 ? remainingCalories * fatShare : 0) / 9;

  return {
    'Calories': tdeeFinal,
    'Protéines': proteins,
    'Glucides': carbs,
    'Lipides': fats,
    'Fibres': fiberTarget,
  };
}
