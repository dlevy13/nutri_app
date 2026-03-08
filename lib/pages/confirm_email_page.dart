import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dashboard/dashboard_page.dart';

class ConfirmEmailPage extends StatefulWidget {
  const ConfirmEmailPage({super.key});

  @override
  State<ConfirmEmailPage> createState() => _ConfirmEmailPageState();
}

class _ConfirmEmailPageState extends State<ConfirmEmailPage> {
  Timer? _timer;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startSessionPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 🔄 Vérifie régulièrement si la session est devenue active
  void _startSessionPolling() {
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        final session = Supabase.instance.client.auth.currentSession;

        if (session != null) {
          _timer?.cancel();

          if (!mounted) return;

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const DashboardPage(),
            ),
            (_) => false,
          );
        }
      },
    );
  }

  Future<void> _resendEmail() async {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email;

    if (email == null) return;

    setState(() => _loading = true);

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email de confirmation renvoyé."),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email;

    return Scaffold(
      appBar: AppBar(title: const Text("Confirmation requise")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mark_email_unread_outlined, size: 72),
            const SizedBox(height: 24),
            const Text(
              "Confirmez votre adresse email",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Un email de confirmation vous a été envoyé.\n"
              "Dès que votre adresse est validée,\n"
              "vous serez automatiquement connecté.\n"
              "Surveillez vos spams",
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: (email == null || _loading) ? null : _resendEmail,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Renvoyer l’email"),
            ),

            if (email != null) ...[
              const SizedBox(height: 12),
              Text(
                email,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],

            const SizedBox(height: 24),

            const Text(
              "En attente de validation…",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
