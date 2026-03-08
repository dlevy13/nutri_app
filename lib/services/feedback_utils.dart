import 'package:url_launcher/url_launcher.dart';

Future<void> sendFeedbackEmail() async {
  final uri = Uri(
    scheme: 'mailto',
    path: 'contact@nutriwatt.fr',
    query: Uri.encodeQueryComponent(
      'subject=Feedback NutriWatt&body=Bonjour,%0D%0A%0D%0A',
    ),
  );

  if (!await launchUrl(uri)) {
    throw Exception('Impossible d’ouvrir le client mail');
  }
}
