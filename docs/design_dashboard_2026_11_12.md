# Thème NutriWatt et tableau de bord

## Direction visuelle

Palette inspirée de l’image fournie : vert profond pour les actions et les textes,
vert vif pour la progression énergétique, orange pour les glucides et bleu pour
l’hydratation. Fond blanc cassé, surfaces blanches bordées, arrondis de 24 px.
Les couleurs, la typographie et les styles de boutons et de champs sont définis
dans `lib/ui/theme/app_theme.dart`. Le composant `CardShell` partage ces styles.

L’image originale est conservée dans `assets/icons/nutriwatt_brand.png` et utilisée
dans l’en-tête, l’accueil et l’onboarding. Les icônes de lancement natives et PWA
ne sont pas remplacées dans ce chantier ; l’image fournie comprend un décor et
le nom de l’application et est utilisée telle quelle.

## Tableau de bord

- Salutation personnalisée et semaine compacte dans le contenu défilant.
- Bilan énergétique : consommé, objectif, restant, base ajustée et activité.
- Ajout de repas : choix du type puis saisie sur la date consultée.
- Accès à la planification des entraînements et actualisation au retour.
- Journal chronologique et synchronisation Strava conservés.
- Hydratation : progression, ajouts de 250/500 ml, retrait de 250 ml.
- Macronutriments : barres quantitatives et radar qualitatif dépliable.
- Deux colonnes à partir de 840 px, largeur totale limitée à 1120 px.
- État d’erreur avec possibilité de réessayer.

Les calculs nutritionnels, le stockage et les appels aux services restent ceux
du projet. Les composants de présentation `DashboardContent` et
`HydrationSummary` peuvent être rendus sans initialiser Firebase ou Supabase.

## Vérification

- `flutter test --no-pub --reporter expanded` : 34 tests réussis.
- Les tests du dashboard couvrent les largeurs 320, 390, 768 et 1280 px,
  le texte à 100 % et 160 %, les actions de calendrier, l’ajout de repas,
  l’ajout d’eau et les objectifs absents ou dépassés.
- `flutter analyze --no-pub` : aucune erreur ni avertissement ; une information
  préexistante sur le nom `envLoader.dart`.
- `flutter build web --no-pub --output /tmp/nutriwatt-design-web` : réussi.
- `git diff --check` : réussi.

Les tests de présentation utilisent un journal de substitution : ils ne valident
pas les échanges réels avec Strava, Firebase ou Supabase. La compilation web
vérifie l’intégration du dashboard réel ; aucun déploiement n’a été effectué.

## SDK local et lancement debug

L’IDE utilise Flutter 3.44.6 dans
`/Users/davidlevy/Documents/David/NutriFlutter/flutter`. Une autre installation
3.32.0 existe dans `/Users/davidlevy/flutter`. Ne pas alterner les SDK sur le même
répertoire `.dart_tool` : cela mélange les sources du framework, `sky_engine` et
les artefacts web.

La configuration a été régénérée avec `flutter clean` puis `flutter pub get`
depuis le SDK 3.44.6. La compilation web debug et le lancement via
`flutter run -d web-server --no-pub` ont réussi avec ce SDK. Les 34 tests ont été
relancés et passent sous 3.44.6. Les cartes utilisent désormais une surface
`Material` pour préserver l’encre des listes, et les descriptions des barres
utilisent `semanticsLabel`, avec le pourcentage numérique automatique.

Pour le terminal local :

```sh
export PATH="/Users/davidlevy/Documents/David/NutriFlutter/flutter/bin:$PATH"
./run_web.sh
```

Le script existant conserve les paramètres Supabase nécessaires au démarrage.
