import 'package:universal_html/html.dart' as html;

void redirectToHome() {
  // ✅ Nettoyage URL SANS reload (indispensable iOS PWA)
  html.window.history.replaceState(null, '', '/');
}
