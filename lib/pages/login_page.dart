// dans lib/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../login/login_notifier.dart';
import '../login/login_state.dart';
import '../main.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ On écoute les changements d'état pour les "effets de bord" (navigation, snackbar)
    ref.listen(loginProvider, (previous, next) {
      if (next.status == AuthStatus.success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
      if (next.status == AuthStatus.failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage ?? "Une erreur est survenue.")),
        );
      }
    });

    // ✅ On "watch" l'état pour reconstruire l'UI (ex: le bouton de chargement)
    final state = ref.watch(loginProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Connexion")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Mot de passe"),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              // On désactive le bouton pendant le chargement
              onPressed: state.status == AuthStatus.loading
                  ? null
                  : () {
                      // On appelle simplement la méthode du Notifier
                      ref.read(loginProvider.notifier).login(
                            emailController.text.trim(),
                            passwordController.text.trim(),
                          );
                    },
              child: state.status == AuthStatus.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("Se connecter"),
            ),
          ],
        ),
      ),
    );
  }
}