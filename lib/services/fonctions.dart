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

String getShortenedName(String name, {int wordCount = 5}) {
  return name.split(' ').take(wordCount).join(' ');
}
