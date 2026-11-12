# Profil, entraînements et analyses

## Profil

- Sections « Mes informations », « Mon activité et mes mesures » et « Mes connexions ».
- Formulaire défilant limité à 800 px, champs taille/poids côte à côte quand la
  largeur le permet, empilés sur petit écran.
- Email consultable en lecture seule, champs numériques avec clavier décimal,
  bouton de date de naissance et actions explicites.
- État de sauvegarde annoncé par une région accessible dynamique.
- Sauvegarde automatique, sauvegarde manuelle, connexions et déconnexion
  conservent leurs callbacks existants.

## Entraînements

- Navigation de semaine dans une carte dont les commandes reviennent à la ligne.
- Cartes de jours en une ou deux colonnes, avec sélection d’activité pleine largeur.
- Événements Garmin lisibles sur plusieurs lignes et repère « Aujourd’hui ».
- États de chargement et d’erreur, avec action « Réessayer ».
- Format des clés de planning conservé, y compris les jours non complétés par un zéro.

## Tendances et rapport

- Titres de graphiques flexibles et sélecteurs de période nommés.
- Explications dans des fenêtres défilantes, adaptées au texte agrandi.
- Cartes du thème, palette partagée et légendes de macros explicites.
- Rapport limité en largeur, bilan énergétique harmonisé et répartition des
  repas sans hauteur de cellule fixe. Les légendes et les détails reviennent
  à la ligne au lieu de déborder.
- Carte commune pour l’analyse des aliments, sans ombre propre supplémentaire.
- Navigation Accueil / Tendances / Rapport / Profil commune, avec onglet actif
  et destinations corrigés sur les pages d’analyse.
- La date du rapport est sélectionnée à l’ouverture (ou si la date de la page
  change), plutôt qu’après chaque reconstruction du widget.

## Vérification

SDK Flutter 3.44.6 : `/Users/davidlevy/Documents/David/NutriFlutter/flutter`.

- `flutter test --no-pub --reporter expanded` : 54 tests réussis.
- Nouveaux tests sur profil, planning, période de graphique, explications,
  énergie du rapport et navigation : largeurs 320, 768 et 1280 px, texte à 160 %.
- Vérification des callbacks de saisie, activité, changement de semaine,
  synchronisation, réessai et sélection de période.
- Tests explicites du navigateur :
  `flutter test --no-pub --platform chrome test/browser/analysis_pages_web.dart`.
  Quatre tests réussis sur les graphiques réels et le rapport réel, à 320 et
  1280 px avec texte à 160 %, données de test et services remplacés.
- Le rapport est testé avec nutrition, activités et répartition dépliées ;
  l’ouverture des explications des trois graphiques est aussi testée.
- Analyse Flutter : aucune erreur ni avertissement ; deux informations préexistantes
  (`envLoader.dart` et un champ de `register_page.dart`).
- Compilation web debug réussie avec le même SDK que l’IDE.
- `git diff --check` : réussi.

Les tests navigateur n’effectuent pas d’appels réels à Strava, Garmin, Firebase,
Supabase ou l’IA. Ils vérifient le rendu et les interactions locales. La lecture
avec un lecteur d’écran réel n’a pas fait l’objet d’un audit complet.
Aucun déploiement n’a été effectué.
