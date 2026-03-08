
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../dashboard/dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus(); 
    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final session = supabase.auth.currentSession;

      if (session == null) {
        throw Exception("Session non créée");
      }

      // ✅ LOGIN RÉUSSI → NAVIGATION
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
        (_) => false,
      );

    } on AuthException catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur ${e.statusCode ?? 'Inconnue'}: ${e.message}"),
          backgroundColor: Colors.red,
        ),
      );
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur réseau ou inconnue")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  Future<void> _resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez saisir votre email"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://nutriapp-4ea20.web.app/reset-password',
        // ⬆️ page web ou deep link (voir section 3)
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Email de réinitialisation envoyé. Vérifiez votre boîte mail.",
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
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
          child: Column(
            children: [
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "Email"),
                validator: (v) =>
                    v == null || v.isEmpty ? "Email requis" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                decoration:
                    const InputDecoration(labelText: "Mot de passe"),
                obscureText: true,
                validator: (v) =>
                    v == null || v.isEmpty ? "Mot de passe requis" : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Se connecter"),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading ? null : _resetPassword,
                  child: const Text("Mot de passe oublié ?"),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
