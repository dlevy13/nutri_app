
import 'package:flutter/material.dart';

class LegalNoticePage extends StatelessWidget {
  const LegalNoticePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentions légales'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Mentions légales',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('Éditeur : NutriApp\nEmail : contact@nutriapp.com\nHébergeur : Firebase / Google LLC'),
            SizedBox(height: 24),

            Text(
              'Politique de confidentialité',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Les données collectées via l\'application (nom, email, poids, repas) sont utilisées uniquement '
              'dans le cadre de votre suivi nutritionnel personnalisé. Conformément au RGPD, vous pouvez demander '
              'la suppression ou modification de vos données personnelles à tout moment en nous contactant.',
            ),
            SizedBox(height: 24),

            Text(
              'Utilisation des cookies',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'L\'application peut utiliser des cookies ou traceurs à des fins de mesure d\'audience ou de personnalisation. '
              'Aucun cookie publicitaire n\'est utilisé sans votre consentement explicite.',
            ),
          ],
        ),
      ),
    );
  }
}
