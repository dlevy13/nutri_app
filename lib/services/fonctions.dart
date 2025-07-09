import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
 import '../log.dart';
 // ajuste le chemin si besoin
//Utilitaires pour traitement de texte (normalisation, raccourcissement, etc.)

String normalize(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r"œ"), "oe")
      .replaceAll(RegExp(r"[àáâãäå]"), "a")
      .replaceAll(RegExp(r"[èéêë]"), "e")
      .replaceAll(RegExp(r"[ìíîï]"), "i")
      .replaceAll(RegExp(r"[òóôõö]"), "o")
      .replaceAll(RegExp(r"[ùúûü]"), "u")
      .replaceAll(RegExp(r"[ç]"), "c")
      .replaceAll(RegExp(r"[ñ]"), "n")
      .replaceAll(RegExp(r"[^a-z0-9\s]"), "") // supprime caractères spéciaux
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

// ==== FIRESTORE UTILISATEURS ====

String getShortenedName(String name, {int wordCount = 5}) {
  return name.split(' ').take(wordCount).join(' ');
}
Future<void> saveUserToFirestore(AppUser user) async {
  final usersRef = FirebaseFirestore.instance.collection('users');
  logger.d("📤 Tentative de sauvegarde Firestore pour ${user.uid}");
  await usersRef.doc(user.uid).set(user.toMap());
}

Future<AppUser?> getUserFromFirestore(String uid) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

  if (doc.exists && doc.data() != null) {
    return AppUser.fromMap(doc.data()!);
  } else {
    return null;
  }
}

