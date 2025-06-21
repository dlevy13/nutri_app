
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Renvoie l'IP à utiliser pour joindre l'API backend
String getHostIP() {
  if (kIsWeb) {
    return dotenv.env['API_HOST'] ?? 'localhost';
  }
  if (Platform.isAndroid) {
    return '10.0.2.2';
  }
  return 'localhost';
}
