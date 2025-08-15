import 'package:flutter/material.dart';
import '../dashboard/dashboard_page.dart'; // Assurez-vous d'importer la page vers laquelle vous voulez naviguer

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTimer());
  }

  // Fonction asynchrone qui démarre le compte à rebours et gère la navigation
  void _startTimer() async {
    // Attente de 2 secondes
    await Future.delayed(const Duration(seconds: 2));

    // Vérifie si le widget est toujours monté avant de naviguer
    if (mounted) {
      // Retirer le mot-clé 'const' pour créer l'instance sans const
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DashboardPage()), // Retirer `const` ici
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
