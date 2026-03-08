// dans lib/pages/register_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../register/register_notifier.dart';
import '../register/register_state.dart';
import 'profile_form_page.dart';


class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  late final ProviderSubscription<RegisterState> _registerSub;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final prenomController = TextEditingController();
  final tailleController = TextEditingController();
  final poidsController = TextEditingController();

  String activite = "Modéré";
  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();

    _registerSub = ref.listenManual<RegisterState>(
      registerProvider,
      (previous, next) {
        if (!mounted) return;

      if (next.status == RegisterStatus.success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const ProfileFormPage(),
          ),
          (_) => false,
        );
      }

      if (next.status == RegisterStatus.failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage ?? "Erreur inconnue")),
        );
      }
    });
  }

  @override
  void dispose() {
    _registerSub.close();
    emailController.dispose();
    passwordController.dispose();
    prenomController.dispose();
    tailleController.dispose();
    poidsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Créer un compte")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ───── EMAIL ─────
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "Email"),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "Email requis";
                  }
                  final reg = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                  if (!reg.hasMatch(v.trim())) {
                    return "Email invalide";
                  }
                  return null;
                },
              ),

              // ───── MOT DE PASSE ─────
              TextFormField(
                controller: passwordController,
                decoration:
                    const InputDecoration(labelText: "Mot de passe"),
                obscureText: true,
                validator: (v) =>
                    v == null || v.length < 6
                        ? "6 caractères minimum"
                        : null,
              ),

              // ───── PRÉNOM ─────
              TextFormField(
                controller: prenomController,
                decoration:
                    const InputDecoration(labelText: "Prénom"),
                validator: (v) =>
                    v == null || v.trim().isEmpty
                        ? "Champ obligatoire"
                        : null,
              ),

              const SizedBox(height: 12),

              // ───── DATE DE NAISSANCE ─────
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _birthDate ?? DateTime(2000),
                    firstDate: DateTime(1920),
                    lastDate: DateTime.now(),
                    locale: const Locale('fr', 'FR'),
                  );
                  if (picked != null) {
                    setState(() => _birthDate = picked);
                  }
                },
                child: Text(
                  _birthDate == null
                      ? "Sélectionner la date de naissance"
                      : DateFormat('dd/MM/yyyy').format(_birthDate!),
                ),
              ),

              const SizedBox(height: 12),

              // ───── TAILLE ─────
              TextFormField(
                controller: tailleController,
                decoration:
                    const InputDecoration(labelText: "Taille (cm)"),
                keyboardType: TextInputType.number,
              ),

              // ───── POIDS ─────
              TextFormField(
                controller: poidsController,
                decoration:
                    const InputDecoration(labelText: "Poids (kg)"),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 12),

              // ───── ACTIVITÉ ─────
              DropdownButtonFormField<String>(
                value: activite,
                decoration: const InputDecoration(
                  labelText: "Niveau d'activité",
                ),
                items: const [
                  'Sédentaire',
                  'Modéré',
                  'Actif',
                  'Très actif',
                ]
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => activite = v);
                  }
                },
              ),

              const SizedBox(height: 20),

              // ───── SUBMIT ─────
              ElevatedButton(
                onPressed: state.status == RegisterStatus.loading
                    ? null
                    : () {
                        if (!_formKey.currentState!.validate()) return;

                        ref.read(registerProvider.notifier).register(
                              email: emailController.text.trim(),
                              password:
                                  passwordController.text.trim(),
                              prenom:
                                  prenomController.text.trim(),
                              taille: tailleController.text,
                              poids: poidsController.text,
                              activite: activite,
                              birthDate: _birthDate,
                            );
                      },
                child: state.status == RegisterStatus.loading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : const Text("Créer le compte"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
