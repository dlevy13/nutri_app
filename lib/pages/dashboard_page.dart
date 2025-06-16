import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'profile_form_page.dart';
import 'training_planner_page.dart';
import 'meal_input_page.dart';
import '../services/meal_database_service.dart';
import 'package:hive/hive.dart';
import 'package:nutri_app/models/meal.dart';





class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final dbService = MealDatabaseService();

  Map<String, double> macros = {"Protéines": 0, "Glucides": 0, "Lipides": 0};
  final List<Color> colors = [
  Colors.orange, // Protéines
  Colors.green,  // Glucides
  Colors.blue,   // Lipides
  Colors.purple  // Calories
];
  Map<String, List<Map<String, dynamic>>> weeklyMeals = {};
  String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  double tdee = 0.0;


  @override
  void initState() {
    super.initState();
    _loadProfileAndCalculate();
    _loadMeals();
  }


  Future<void> _loadProfileAndCalculate() async {
    final prefs = await SharedPreferences.getInstance();

    final poids = prefs.getDouble('poids') ?? 70;
    final taille = prefs.getDouble('taille') ?? 175;
    final age = prefs.getInt('age') ?? 30;
    final sexe = prefs.getString('sexe') ?? 'Homme';
    final activite = prefs.getString('activite') ?? 'Modéré';

    double bmr = sexe == 'Femme'
        ? 655 + (9.563 * poids) + (1.850 * taille) - (4.676 * age)
        : 66.5 + (13.75 * poids) + (5.003 * taille) - (6.755 * age);

    final activityFactors = {
      'Sédentaire': 1.2,
      'Modéré': 1.375,
      'Actif': 1.55,
      'Très actif': 1.725,
    };

    final factor = activityFactors[activite] ?? 1.375;
    tdee = bmr * factor;

    await prefs.setDouble('tdee', tdee);

    _updateMacros(); // Recalculer les macros au cas où selectedDate est déjà chargé
  }

  Future<void> _loadMeals() async {
    final box = await Hive.openBox<Meal>('meals');
    final data = await dbService.getMealsForTheWeek(box);

    setState(() {
      weeklyMeals = data;
    });
    _updateMacros(); // Mettre à jour les macros pour la date sélectionnée
  }
    Future<Map<String, double>> _getDailyMacroNeedsWithTraining() async {
      final today = DateTime.parse(selectedDate);
      final tomorrow = today.add(const Duration(days: 1));

      final typeToday = await _getTrainingTypeForDate(today);
      final typeTomorrow = await _getTrainingTypeForDate(tomorrow);
      final adjustedTDEE = await _getAdjustedTDEE(); // Ne dépend que d'aujourd'hui

      double ratioProt = 0.30;
      double ratioGluc = 0.50;
      double ratioLip = 0.20;

      void adjustRatios(String type) {
        if (type == "Intensité") {
          ratioProt += 0.05;
          ratioGluc += 0.10;
        } else if (type == "Endurance") {
          ratioProt += 0.10;
          ratioGluc += 0.30;
        }
        // Sinon "Repos", aucun changement
      }

      adjustRatios(typeToday);
      adjustRatios(typeTomorrow);

      // Normalisation pour s'assurer que total = 1.0
      final totalRatio = ratioProt + ratioGluc + ratioLip;
      ratioProt /= totalRatio;
      ratioGluc /= totalRatio;
      ratioLip = 1.0 - ratioProt - ratioGluc;

      return {
        "Protéines": (adjustedTDEE * ratioProt) / 4,
        "Glucides": (adjustedTDEE * ratioGluc) / 4,
        "Lipides": (adjustedTDEE * ratioLip) / 9,
      };
    }



  Future<String> _getTrainingTypeForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final days = [
      "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"
    ];
    final weekday = days[date.weekday - 1];
    return prefs.getString("plan_$weekday") ?? "Repos";
  }
Future<double> _getAdjustedTDEE() async {
  String trainingType = await _getTrainingTypeForDate(DateTime.parse(selectedDate));

  if (trainingType == "Intensité") {
    return tdee * 1.10;
  } else if (trainingType == "Endurance") {
    return tdee * 1.30;
  } else {
    return tdee; // Repos
  }
}

  void _updateMacros() {
    final meals = weeklyMeals[selectedDate] ?? [];

    double calories = 0;
    double prot = 0, gluc = 0, lip = 0;

    for (var meal in meals) {
      calories += meal["calories"] ?? 0;
      prot += meal["protein"] ?? 0;
      gluc += meal["carbs"] ?? 0;
      lip += meal["fat"] ?? 0;
    }

    setState(() {
      macros = {
        "Protéines": prot,
        "Glucides": gluc,
        "Lipides": lip,
        "Calories": calories,
      };
    });
  }

  List<DateTime> _getWeekDates() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    //final total = macros.entries
      //.where((e) => e.key != "Calories")
      //.fold(0.0, (sum, e) => sum + e.value);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileFormPage()),
            ).then((_) {
              _loadProfileAndCalculate();
              _loadMeals();
            }),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Semaine en cours",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _getWeekDates().map((date) {
              final dateStr = DateFormat('yyyy-MM-dd').format(date);
              final hasMeals = (weeklyMeals[dateStr] ?? []).isNotEmpty;
              final isSelected = dateStr == selectedDate;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDate = dateStr;
                    _updateMacros();
                  });
                },
                child: Column(
                  children: [
                    Text(DateFormat.E().format(date)), // LUN, MAR, ...
                    const SizedBox(height: 4),
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: hasMeals ? Colors.green : Colors.grey[400],
                      child: isSelected
                          ? const CircleAvatar(radius: 5, backgroundColor: Colors.white)
                          : null,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            "Macros du ${DateFormat('EEEE dd MMMM', 'fr_FR').format(DateTime.parse(selectedDate))}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          FutureBuilder<double>(
          future: _getAdjustedTDEE(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            return Text(
              "Calories nécessaires : ${snapshot.data!.toStringAsFixed(0)} kcal",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            );
          },
        ),
          const SizedBox(height: 12),
          Row(
  children: [
    Expanded(
      child: Column(
        children: [
          const SizedBox(
            height: 40, // Ajuste selon la taille max du titre
            child: Center(
              child: Text(
                "Consommé",
                style: TextStyle(fontSize: 10,fontWeight: FontWeight.bold),
              ),
            ),
          ),          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sections: macros.entries
                    .where((e) => e.key != "Calories")
                    .toList()
                    .asMap()
                    .entries
                    .map((entry) {
                  int i = entry.key;
                  final e = entry.value;
                  final total = macros.entries
                      .where((e) => e.key != "Calories")
                      .fold(0.0, (sum, e) => sum + e.value);
                  final percentage = total > 0
                      ? (e.value / total * 100).toStringAsFixed(1)
                      : "0";
                  return PieChartSectionData(
                    color: colors[i % colors.length],
                    value: e.value,
                    title: '$percentage%',
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 14, color: Colors.white),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
        ],
      ),
    ),
    Expanded(
  child: FutureBuilder<Map<String, double>>(
    future: _getDailyMacroNeedsWithTraining(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final macroNeeds = snapshot.data!;
      final total = macroNeeds.values.fold(0.0, (a, b) => a + b);
      return Column(
        children: [
          const SizedBox(
            height: 40,
            child: Center(
              child: Text(
                "Besoins (adaptés : entraînement aujourd’hui + demain)", // même hauteur que le titre précédent
                style: TextStyle(fontSize: 10,fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sections: macroNeeds.entries
                    .toList()
                    .asMap()
                    .entries
                    .map((entry) {
                  int i = entry.key;
                  final e = entry.value;
                  final percentage = total > 0
                      ? (e.value / total * 100).toStringAsFixed(1)
                      : "0";
                  return PieChartSectionData(
                    color: colors[i % colors.length],
                    value: e.value,
                    title: '$percentage%',
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 14, color: Colors.white),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
        ],
      );
    },
  ),
),

  ],
),

          const SizedBox(height: 10),
          ...macros.entries.toList().asMap().entries.map(
            (entry) {
              final key = entry.value.key;
              final value = entry.value.value;
              final isCalorie = key == "Calories";
              return Card(
                child: ListTile(
                  leading: Icon(Icons.circle, color: colors[entry.key % colors.length]),
                  title: Text(key),
                  trailing: Text(
                    isCalorie
                        ? "${value.toStringAsFixed(0)} kcal"
                        : "${value.toStringAsFixed(0)} g",
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
      Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const SizedBox(height: 8),
    Text(
      "Comparaison consommé vs besoin",
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
    Wrap(
  alignment: WrapAlignment.center,
  spacing: 12,
  runSpacing: 2,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: const [
    Icon(Icons.square, color: Colors.orange, size: 12),
    Text("Protéines"),
    Icon(Icons.square, color: Colors.green, size: 12),
    Text("Glucides"),
    Icon(Icons.square, color: Colors.blue, size: 12),
    Text("Lipides"),

    SizedBox(width: double.infinity), // ↩️ Force le retour à la ligne

    Icon(Icons.circle, color: Colors.black, size: 8),
    Text("Consommé"),
    Icon(Icons.circle, color: Colors.black12, size: 8),
    Text("Besoin"),
  ],
),
    
    const SizedBox(height: 12),
    FutureBuilder<Map<String, double>>(
  future: _getDailyMacroNeedsWithTraining(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    final macroNeeds = snapshot.data!;
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          barGroups: [
            BarChartGroupData(x: 0, barRods: [
              BarChartRodData(toY: macros["Protéines"] ?? 0, color: Colors.orange, width: 7),
              BarChartRodData(toY: macroNeeds["Protéines"] ?? 0, color: Colors.orange.shade100, width: 7),
            ]),
            BarChartGroupData(x: 1, barRods: [
              BarChartRodData(toY: macros["Glucides"] ?? 0, color: Colors.green, width: 7),
              BarChartRodData(toY: macroNeeds["Glucides"] ?? 0, color: Colors.green.shade100, width: 7),
            ]),
            BarChartGroupData(x: 2, barRods: [
              BarChartRodData(toY: macros["Lipides"] ?? 0, color: Colors.blue, width: 7),
              BarChartRodData(toY: macroNeeds["Lipides"] ?? 0, color: Colors.blue.shade100, width: 7),
            ]),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  switch (value.toInt()) {
                    case 0:
                      return const Text('Protéines');
                    case 1:
                      return const Text('Glucides');
                    case 2:
                      return const Text('Lipides');
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, interval: 50),
            ),
          ),
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
        ),
      ),
    );
  },
),

  ],
),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: const Text("Planning d'entraînement"),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TrainingPlannerPage()),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.restaurant),
            label: const Text("Saisie des repas"),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MealInputPage(selectedDate: selectedDate), // Passer la date sélectionnée
              ),
            ).then((_) => _loadMeals()),
          ),
        ],
      ),
    );
  }
}
