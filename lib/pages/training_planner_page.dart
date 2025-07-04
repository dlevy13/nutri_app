import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrainingPlannerPage extends StatefulWidget {
  const TrainingPlannerPage({super.key});

  @override
  TrainingPlannerPageState createState() => TrainingPlannerPageState();
}

class TrainingPlannerPageState extends State<TrainingPlannerPage> {
  final List<String> days = [
    "Lundi",
    "Mardi",
    "Mercredi",
    "Jeudi",
    "Vendredi",
    "Samedi",
    "Dimanche"
  ];

  final List<String> activities = [
      "Repos",
      "Intensité",
      "Endurance",
      "Affûtage"
    ];
  Map<String, String> selectedActivities = {};

  @override
  void initState() {
    super.initState();
    _loadPlanning();
  }

  // Fonction pour charger les activités enregistrées depuis les SharedPreferences
  Future<void> _loadPlanning() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedActivities = {
        for (var day in days) day: prefs.getString("plan_$day") ?? "Repos",
      };
    });
  }

  // Fonction pour enregistrer les activités dans SharedPreferences
  Future<void> _savePlanning(String day, String activity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("plan_$day", activity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Planning d'entraînement")),
      body: ListView.builder(
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          return Card(
            child: ListTile(
              title: Text(day),
              trailing: DropdownButton<String>(
                value: selectedActivities[day],
                items: activities
                    .map((act) => DropdownMenuItem(
                          value: act,
                          child: Text(act),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedActivities[day] = value;
                    });
                    _savePlanning(day, value);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
