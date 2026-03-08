import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dashboard/dashboard_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;

      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user == null) {
        throw Exception("Connexion échouée");
      }

      // ✅ Sauvegarde locale minimale (UX uniquement)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('email', email);
      await prefs.setBool('has_profile', true);

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur de connexion")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Se connecter")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // EMAIL
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "Email"),
                validator: (v) =>
                    v == null || v.trim().isEmpty
                        ? "Email requis"
                        : null,
              ),

              const SizedBox(height: 12),

              // PASSWORD
              TextFormField(
                controller: passwordController,
                decoration:
                    const InputDecoration(labelText: "Mot de passe"),
                obscureText: true,
                validator: (v) =>
                    v == null || v.isEmpty
                        ? "Mot de passe requis"
                        : null,
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _loading ? null : () => _login(context),
                child: _loading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : const Text("Se connecter"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
