import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileFormPage extends StatefulWidget {
  const ProfileFormPage({super.key});

  @override
  ProfileFormPageState createState() => ProfileFormPageState();
}

class ProfileFormPageState extends State<ProfileFormPage> {
  final _formKey = GlobalKey<FormState>();
  double poids = 70;
  double taille = 175;
  int age = 30;
  String sexe = 'Homme';
  String activite = 'Modéré';
  String? derniereMiseAJour;

  final List<String> niveauxActivite = [
    'Sédentaire',
    'Modéré',
    'Actif',
    'Très actif'
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  void _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      poids = prefs.getDouble('poids') ?? 70;
      taille = prefs.getDouble('taille') ?? 175;
      age = prefs.getInt('age') ?? 30;
      sexe = prefs.getString('sexe') ?? 'Homme';
      activite = prefs.getString('activite') ?? 'Modéré';
      derniereMiseAJour = prefs.getString('tdee_updated_at');
    });
  }

  // Fonction qui calcule et enregistre les données
  Future<void> _savePrefsAndTDEE() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('poids', poids);
    await prefs.setDouble('taille', taille);
    await prefs.setInt('age', age);
    await prefs.setString('sexe', sexe);
    await prefs.setString('activite', activite);

    // Calcul du TDEE
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
    final tdee = bmr * factor;

    await prefs.setDouble('tdee', tdee);
    await prefs.setString('tdee_updated_at', DateTime.now().toIso8601String());
  }

  @override
  Widget build(BuildContext context) {
    DateTime? miseAJourDate;
    if (derniereMiseAJour != null) {
      try {
        miseAJourDate = DateTime.parse(derniereMiseAJour!).toLocal();
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Profil utilisateur")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (miseAJourDate != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    "Dernière mise à jour : ${miseAJourDate.day}/${miseAJourDate.month}/${miseAJourDate.year} à ${miseAJourDate.hour}h${miseAJourDate.minute.toString().padLeft(2, '0')}",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              _slider("Poids (kg)", poids, 40, 150, (v) => setState(() => poids = v)),
              _slider("Taille (cm)", taille, 140, 220, (v) => setState(() => taille = v)),
              _slider("Âge", age.toDouble(), 12, 100, (v) => setState(() => age = v.toInt())),
              const SizedBox(height: 12),
              _dropdown<String>(
                label: "Sexe",
                value: sexe,
                items: ['Homme', 'Femme'],
                onChanged: (val) => setState(() => sexe = val!),
              ),
              _dropdown<String>(
                label: "Niveau d'activité",
                value: activite,
                items: niveauxActivite,
                onChanged: (val) => setState(() => activite = val!),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("Enregistrer"),
                onPressed: () async {
                  await _savePrefsAndTDEE();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, void Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label : ${value.toStringAsFixed(0)}"),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        DropdownButtonFormField<T>(
          value: value,
          items: items.map((item) => DropdownMenuItem<T>(
            value: item,
            child: Text(item.toString()),
          )).toList(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
