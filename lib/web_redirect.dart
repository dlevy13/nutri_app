import 'package:web/web.dart' as web;

void redirectToHome() {
  // ✅ Nettoyage URL SANS reload (indispensable iOS PWA)
  web.window.history.replaceState(null, '', '/');
}
