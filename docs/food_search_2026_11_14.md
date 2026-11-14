# Recherche d’aliments : normalisation et pertinence

## Problème reproduit

Dans les 3216 aliments locaux, `pot au feu` plaçait les petits pots infantiles
(score 55) avant « Pot-au-feu préemballé » (score 20, 15e position).
Avec `pot-au-feu`, ce dernier passait en première position (score 100).
La suppression des tirets fusionnait les mots, tandis que les catégories étaient
évaluées à partir du seul premier mot de la saisie.

## Corrections autorisées : points 1 et 2

- Une normalisation dédiée à la recherche remplace les tirets (dont les variantes
  Unicode), les apostrophes droites/courbes et les barres obliques par des espaces
  avant la normalisation des accents et de la casse.
- La fonction générale `normalize()` reste inchangée pour préserver ses autres
  usages et les clés existantes.
- Classement : nom exact, expression complète au début du nom, expression complète
  ailleurs dans le nom, tous les mots avec gestion des pluriels, tous les préfixes,
  puis catégorie couvrant tous les mots de la requête.
- Le bonus d’un aliment personnalisé reste inférieur à l’écart entre deux niveaux
  de pertinence ; il ne peut donc pas dépasser un nom exact d’une autre source.
- Suppression des correspondances par simple sous-chaîne : `pot` ne suffit plus
  pour trouver `compote`.
- Les catégories doivent couvrir la requête entière ; `pot` seul peut rechercher
  des petits pots, tandis que `pot au feu` n’admet plus cette catégorie.
- Le même classement est appliqué à la première réponse locale et à la liste
  fusionnée après le cache ou la recherche externe. Les entrées hors sujet sont
  retirées, y compris lorsqu’elles viennent d’un ancien cache.
- L’historique utilise les mêmes règles de normalisation et de correspondance.
  La pertinence prime sur la récence ; la récence départage les mêmes niveaux.
- Les mentions `sans sucre` et les indications numériques ne sont pas retirées
  comme des mots vides.

## Points 3 et 4 : cache et réponses tardives

- Les lectures et écritures du cache utilisent la requête complète normalisée :
  `pot au feu`, `pot-au-feu` et leurs variantes partagent la clé `pot au feu`.
  Les lectures se font par égalité, sans recherche élargie sur le premier mot.
- Les anciennes lignes du cache ne sont pas supprimées. Une ancienne clé `pot`
  ne sert plus à répondre à `pot au feu` ; le cache se remplit avec les nouvelles
  clés au fil des recherches externes. Le schéma et la clé unique `query,code`
  restent ceux du dépôt existant, sans migration SQL ni opération distante directe.
- Le cache filtre les résultats hors sujet et n’enregistre que les correspondances
  pertinentes possédant un identifiant.
- Le seuil de cinq candidats s’applique maintenant à des **noms distincts** avec
  correspondance complète des mots (ou d’une expression), après normalisation.
  Les catégories seules, les noms équivalents répétés et les préfixes incomplets
  ne suffisent pas à bloquer la recherche externe. `forceOnline` reste disponible.
- Les résultats utiles du cache s’affichent avant la fin de l’appel externe.
- Chaque saisie invalide immédiatement la génération de recherche précédente,
  avant les 300 ms de temporisation. Une ancienne réponse locale, de cache ou
  d’API ne peut plus publier ses résultats ou son erreur sur la saisie actuelle.
- Effacer le champ, réduire la saisie à moins de trois caractères, changer de
  repas ou fermer l’écran invalide aussi la recherche et annule le timer prévu.
- L’action « Élargir la recherche » utilise la même protection et le même classement.
- Les appels réseau déjà partis peuvent se terminer ; leurs réponses obsolètes
  sont ignorées. Une écriture de cache déjà partie peut finir sous sa propre clé,
  sans remplacer les résultats affichés.

Ces protections concernent la recherche alimentaire et son extension FatSecret.
La recherche dédiée aux produits sportifs reste un parcours séparé.

## Vérification

Flutter 3.44.6, même SDK que l’IDE.

- 67 tests standards réussis : pertinence, décision de recherche externe et
  requêtes HTTP simulées du véritable dépôt de cache, en plus des tests existants.
- Le jeu réel CIQUAL/local est testé pour `pot au feu`, `pot-au-feu`, les tirets
  Unicode, la casse et les espaces multiples : classement identique et plat en tête.
- Tests des catégories, des sources, des pluriels, des ligatures, des apostrophes,
  des mentions négatives, des indications numériques et des requêtes vides.
- 16 tests Chrome du véritable `MealInputNotifier` avec services simulés : réponse
  locale immédiate, ordre de l’historique, cache tardif, seuil de pertinence,
  affichage pendant l’API, inversion des réponses, erreurs obsolètes, effacement,
  saisie courte, changement de repas, fermeture, annulation du timer, action
  FatSecret tardive et forçage de la recherche externe.
  Commande : `flutter test --no-pub --platform chrome test/browser/food_search_web.dart`.
- Le dépôt de cache est vérifié via un client HTTP simulé, sans accès à la base
  réelle : égalité sur la clé complète, clé canonique des écritures, exclusion
  des produits hors sujet ou non identifiés et maintien de `on_conflict=query,code`.
- Compilation web debug réussie.
- Analyse Flutter : aucune erreur ni avertissement ; deux informations
  préexistantes (`envLoader.dart` et `register_page.dart`).
- `git diff --check` réussi. Aucun déploiement effectué.
