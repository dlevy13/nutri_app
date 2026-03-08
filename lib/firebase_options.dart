import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'envloader.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return android;
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: EnvLoader.get('FIREBASE_API_KEY'),
        appId: EnvLoader.get('FIREBASE_APP_ID_WEB'),
        messagingSenderId: EnvLoader.get('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: EnvLoader.get('FIREBASE_PROJECT_ID'),
        storageBucket: EnvLoader.get('FIREBASE_STORAGE_BUCKET'),
        authDomain: EnvLoader.get('FIREBASE_AUTH_DOMAIN'),
      );

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: EnvLoader.get('FIREBASE_API_KEY'),
        appId: EnvLoader.get('FIREBASE_APP_ID_ANDROID'),
        messagingSenderId: EnvLoader.get('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: EnvLoader.get('FIREBASE_PROJECT_ID'),
        storageBucket: EnvLoader.get('FIREBASE_STORAGE_BUCKET'),
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: EnvLoader.get('FIREBASE_API_KEY'),
        appId: EnvLoader.get('FIREBASE_APP_ID_IOS'),
        messagingSenderId: EnvLoader.get('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: EnvLoader.get('FIREBASE_PROJECT_ID'),
        storageBucket: EnvLoader.get('FIREBASE_STORAGE_BUCKET'),
        iosBundleId: EnvLoader.get('FIREBASE_IOS_BUNDLE_ID'),
      );

  static FirebaseOptions get macos => ios;
}
