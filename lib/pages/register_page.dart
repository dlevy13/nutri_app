import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../services/fonctions.dart'; // pour saveUserToFirestore
import '../services/auth_service.dart'; // si tu utilises AuthService

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  String activityLevel = "moderate";

  bool isLoading = false;

  Future<void> register() async {
    setState(() => isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = AppUser(
        uid: credential.user!.uid,
        name: nameController.text.trim(),
        age: int.tryParse(ageController.text) ?? 0,
        height: double.tryParse(heightController.text) ?? 0,
        weight: double.tryParse(weightController.text) ?? 0,
        activityLevel: activityLevel,
        tdee: 2500, // tu peux appeler une fonction pour calculer ici
      );

      await saveUserToFirestore(user);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Inscription réussie")));
      Navigator.of(context).pop(); // ou rediriger vers dashboard
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inscription")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: passwordController, decoration: const InputDecoration(labelText: "Mot de passe"), obscureText: true),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Nom")),
            TextField(controller: ageController, decoration: const InputDecoration(labelText: "Âge"), keyboardType: TextInputType.number),
            TextField(controller: heightController, decoration: const InputDecoration(labelText: "Taille (cm)"), keyboardType: TextInputType.number),
            TextField(controller: weightController, decoration: const InputDecoration(labelText: "Poids (kg)"), keyboardType: TextInputType.number),
            DropdownButton<String>(
              value: activityLevel,
              onChanged: (value) => setState(() => activityLevel = value!),
              items: ["low", "moderate", "high"].map((level) {
                return DropdownMenuItem(value: level, child: Text("Activité : $level"));
              }).toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading ? null : register,
              child: isLoading ? CircularProgressIndicator() : const Text("Créer le compte"),
            )
          ],
        ),
      ),
    );
  }
}
