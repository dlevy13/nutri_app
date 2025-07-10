import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class ProfileFormPage extends StatefulWidget {
  const ProfileFormPage({super.key});

  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController poidsController = TextEditingController();
  final TextEditingController tailleController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController prenomController = TextEditingController();

  String selectedSexe = 'Homme';
  String selectedActivite = 'Modéré';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    prenomController.text = user?.displayName ?? '';

    final uid = user?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        poidsController.text = (data['poids'] ?? 70).toString();
        tailleController.text = (data['taille'] ?? 175).toString();
        ageController.text = (data['age'] ?? 30).toString();
        selectedSexe = data['sexe'] ?? 'Homme';
        selectedActivite = data['activite'] ?? 'Modéré';
        setState(() {});
      }
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.updateDisplayName(prenomController.text);

      await AuthService().updateUserProfileData(
        poids: double.tryParse(poidsController.text) ?? 70,
        age: int.tryParse(ageController.text) ?? 30,
        taille: double.tryParse(tailleController.text) ?? 175,
        sexe: selectedSexe,
        activite: selectedActivite,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil mis à jour")),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon Profil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: prenomController,
                decoration: const InputDecoration(labelText: 'Prénom'),
              ),
              TextFormField(
                controller: poidsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Poids (kg)'),
              ),
              TextFormField(
                controller: tailleController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Taille (cm)'),
              ),
              TextFormField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Âge'),
              ),
              DropdownButtonFormField<String>(
                value: selectedSexe,
                items: ['Homme', 'Femme'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => selectedSexe = val ?? 'Homme'),
                decoration: const InputDecoration(labelText: 'Sexe'),
              ),
              DropdownButtonFormField<String>(
                value: selectedActivite,
                items: ['Sédentaire', 'Modéré', 'Actif', 'Très actif']
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: (val) => setState(() => selectedActivite = val ?? 'Modéré'),
                decoration: const InputDecoration(labelText: 'Activité physique'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveProfile,
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
