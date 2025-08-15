// dans lib/pages/register_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../register/register_notifier.dart';
import '../register/register_state.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final prenomController = TextEditingController();
  final tailleController = TextEditingController();
  final poidsController = TextEditingController();

  String activite = "Modéré";
  DateTime? _birthDate;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    prenomController.dispose();
    tailleController.dispose();
    poidsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(registerProvider, (previous, next) {
      if (next.status == RegisterStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Inscription réussie !")),
        );
        Navigator.of(context).pop();
      }
      if (next.status == RegisterStatus.failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : ${next.errorMessage}")),
        );
      }
    });

    final state = ref.watch(registerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Inscription")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: passwordController, decoration: const InputDecoration(labelText: "Mot de passe"), obscureText: true),
            TextField(controller: prenomController, decoration: const InputDecoration(labelText: "Prénom")),

            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                DateTime initial = _birthDate ?? DateTime(2000);
                final DateTime? picked = await showDatePicker(
                  context: context, initialDate: initial,
                  firstDate: DateTime(1920), lastDate: DateTime.now(),
                  locale: const Locale('fr', 'FR'),
                );
                if (picked != null) setState(() => _birthDate = picked);
              },
              child: Text(_birthDate == null
                  ? "Sélectionner la date de naissance"
                  : "Date de naissance : ${DateFormat('dd/MM/yyyy').format(_birthDate!)}"),
            ),

            TextField(controller: tailleController, decoration: const InputDecoration(labelText: "Taille (cm)"), keyboardType: TextInputType.number),
            TextField(controller: poidsController, decoration: const InputDecoration(labelText: "Poids (kg)"), keyboardType: TextInputType.number),

            DropdownButton<String>(
              value: activite,
              onChanged: (value) => setState(() => activite = value!),
              isExpanded: true,
              items: ['Sédentaire', 'Modéré', 'Actif', 'Très actif']
                  .map((level) => DropdownMenuItem(value: level, child: Text(level)))
                  .toList(),
            ),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: state.status == RegisterStatus.loading ? null : () {
                ref.read(registerProvider.notifier).register(
                  email: emailController.text.trim(),
                  password: passwordController.text.trim(),
                  prenom: prenomController.text.trim(),
                  taille: tailleController.text,
                  poids: poidsController.text,
                  activite: activite,
                  birthDate: _birthDate,
                );
              },
              child: state.status == RegisterStatus.loading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("Créer le compte"),
            )
          ],
        ),
      ),
    );
  }
}