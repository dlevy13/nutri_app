# Stabilisation NutriApp - juillet 2026

## 1. Recherche aliments

### Problème
La recherche aliments n’était pas satisfaisante :
- certains aliments présents dans `assets/food_data.json` n’étaient pas remontés, par exemple `ratatouille`
- la recherche semblait parfois partir trop tard ou dépendre du distant
- un cache Supabase/API pouvait bloquer l’affichage des résultats locaux

### Diagnostic
La recherche était bien lancée pendant la saisie, mais avec un double délai :
- `500 ms` dans `meal_input_page.dart`
- `300 ms` dans `meal_input_notifier.dart`

En pratique, la recherche partait donc après environ `800 ms`.

Autre problème plus important :
- la recherche locale JSON était combinée avec une recherche distante/cache
- si le distant répondait lentement ou échouait, le local pouvait ne pas s’afficher, alors que l’entrée existait bien dans le JSON

### Correctifs
- suppression du double `debounce` inutile
- recherche lancée directement depuis la saisie vers le notifier
- priorité donnée à la recherche locale
- affichage immédiat des résultats issus du JSON local
- le cache Supabase et l’API deviennent optionnels et non bloquants
- amélioration du matching local accent-insensitive et tolérant

### Fichiers concernés
- `lib/meal_input/meal_input_page.dart`
- `lib/meal_input/meal_input_notifier.dart`
- `lib/meal_input/meal_search_helpers.dart`

### Tests ajoutés
- `test/meal_input/meal_search_helpers_test.dart`

### Cas couverts par les tests
- `ratatouille` matche bien des entrées du JSON
- le matching tolère les accents
- le fallback local fonctionne correctement

## 2. Produits sportifs et `serving_size`

### Problème
Dans le menu `Barres sportives`, lorsqu’un produit était sélectionné, le poids suggéré ne reprenait pas la valeur Supabase `sport_products.serving_size`.

### Diagnostic
Le repository récupérait bien `serving_size`, mais le dialogue de quantité l’ignorait et retombait sur :
- `poids_usuel`
- ou `100 g`

### Correctif
Pour les produits `sport_product` :
- si `serving_size > 0`, la quantité suggérée par défaut devient `serving_size`
- une unité `portion` utilisant `serving_size` est ajoutée

### Fichiers concernés
- `lib/repositories/sport_product_repository.dart`
- `lib/meal_input/meal_input_page.dart`
- `lib/meal_input/meal_search_helpers.dart`

### Tests ajoutés
- `test/meal_input/meal_search_helpers_test.dart`

### Cas couverts
- priorité à `serving_size`
- fallback sur poids de référence si `serving_size` absent

## 3. Rapport “Aliments à surveiller” et “Bénéfiques”

### Problèmes
Le rapport contenait parfois :
- des doublons
- des aliments d’un autre jour
- des occurrences séparées d’un même aliment consommé plusieurs fois

### Diagnostic
Le calcul exploitait une base trop large, avec des repas hors jour sélectionné, et une logique de dédoublonnage insuffisante.

### Correctifs
- filtrage strict sur `meal.date == selectedDate`
- suppression des doublons exacts
- agrégation par nom d’aliment sur la journée
- somme des quantités et des macros pour les aliments consommés plusieurs fois

### Résultat attendu
Exemple :
- banane 120 g le matin
- banane 80 g l’après-midi

devient :
- banane 200 g dans le rapport

### Fichiers concernés
- `lib/dashboard/widgets/food_analysis_section.dart`
- `lib/dashboard/food_analysis_helpers.dart`

### Tests ajoutés
- `test/dashboard/food_analysis_helpers_test.dart`

### Cas couverts
- filtrage au bon jour
- suppression des doublons exacts
- agrégation des quantités et macros par aliment

## 4. Historique CaloMètre / énergie sur 30-60-90 jours

### Problème
Le graphique du calomètre n’affichait parfois que 2 ou 3 points alors que l’historique réel était > 90 jours.

### Diagnostic
Le repository local `DailyCaloriesRepository` supprimait automatiquement les entrées de plus de `7 jours`.

Cela détruisait l’historique nécessaire aux graphes 30/60/90 jours.

### Correctif
La rétention locale a été portée à `180 jours`.

### Fichiers concernés
- `lib/repositories/daily_calories_repository.dart`

### Tests ajoutés
- `test/repositories/daily_calories_repository_test.dart`

### Cas couverts
- conservation correcte de l’historique utile

## 5. Bug de date backend

### Problème
La conversion de clé jour backend était erronée.

### Diagnostic
`toBackendDayKey()` pouvait retourner une date au mauvais format / mauvais ordre.

### Correctif
Correction de la conversion pour garantir le format backend attendu.

### Fichier concerné
- `lib/services/date_service.dart`

### Tests ajoutés
- `test/services/date_service_test.dart`

## 6. Matching alimentaire et poids usuel

### Problème
Certaines requêtes alimentaires claires ne retrouvaient pas le bon aliment de référence, donc pas le bon poids usuel.

Exemple :
- `yaourt sans sucre` ne retombait pas sur `yaourt nature`

### Correctif
Renforcement de la logique de matching après nettoyage de la requête.

### Fichier concerné
- `lib/services/food_matching_service.dart`

### Tests ajoutés
- `test/services/food_matching_service_test.dart`

## 7. Jauge énergie / charge et objectifs selon le type d’entraînement

### Problème
Sur le dashboard, la jauge énergie n’utilisait pas le même objectif que la page rapport :
- en `Affûtage`, le rapport affichait un objectif corrigé
- la jauge restait sur une base non corrigée

### Diagnostic
- la page rapport lisait `state.macroNeeds['Calories']`
- la jauge recalculait son objectif via `tdee + stravaCaloriesForDay`

Donc incohérence entre les deux vues.

### Correctifs
- la jauge utilise désormais la même valeur que le rapport : `macroNeeds['Calories']`
- alignement du `dailyCaloriesForDay` recalculé dans le notifier

### Fichiers concernés
- `lib/dashboard/widgets/energy_gauge_card.dart`
- `lib/dashboard/dashboard_notifier.dart`

## 8. Nouvelle grille de calcul des besoins macro/caloriques

### Ancienne logique
La logique précédente :
- fixait les protéines à `2 g/kg`
- répartissait le reste en `60% glucides / 40% lipides`
- ne donnait pas de vrai comportement spécifique à `Intensité`
- modifiait seulement le total calorique pour certains cas

### Nouvelle grille implémentée
Extraction de la logique dans un helper dédié.

### Règles actuelles
#### Repos
- calories : `100%`
- protéines : `2.0 g/kg`
- glucides : `45%` du reliquat
- lipides : `55%` du reliquat
- fibres : `30 g`

#### Affûtage
- calories : `90%`
- protéines : `2.0 g/kg`
- glucides : `50%`
- lipides : `50%`
- fibres : `25 g`

#### Intensité
- calories : `105%`
- protéines : `2.1 g/kg`
- glucides : `55%`
- lipides : `45%`
- fibres : `30 g`

#### Endurance
- calories : `110%`
- protéines : `2.0 g/kg`
- glucides : `60%`
- lipides : `40%`
- fibres : `35 g`

#### Veille d’endurance
- si `today == Repos` et `tomorrow == Endurance`
- calories : `105%`
- glucides : `55%`
- fibres : `30 g`

### Fichiers concernés
- `lib/dashboard/macro_needs_helper.dart`
- `lib/dashboard/dashboard_notifier.dart`

### Tests ajoutés
- `test/dashboard/macro_needs_helper_test.dart`

### Cas couverts
- Repos
- Affûtage
- Intensité
- Endurance
- veille d’endurance

## 9. Historique Supabase et graphes “Tendances énergie & macros”

### Symptôme
Après récupération du bon déploiement web, le calomètre affichait bien l’historique, mais :
- les autres graphes étaient vides
- aucun repas local n’était enregistré

### Diagnostic
Deux sources de données différentes étaient utilisées :
- calomètre : lit `DailyCalories`, donc historique journalier hydraté depuis Supabase
- autres graphes :
  - `macro_providers.dart`
  - `unsaturated_ratio_providers.dart`
  lisaient encore les `Meal` locaux Hive

Donc si les repas locaux avaient disparu :
- le calomètre restait rempli
- les graphes macros et lipides devenaient vides

### Correctifs
Les graphes suivants lisent maintenant en priorité `daily_nutrition_snapshots` depuis Supabase :
- part des macros (%)
- ratio insaturés / saturés

Ils gardent un fallback sur les repas locaux si le distant est vide.

### Fichiers concernés
- `lib/courbe/macro_providers.dart`
- `lib/courbe/unsaturated_ratio_providers.dart`

### Vérification
- analyse ciblée : OK

## 10. Payload de snapshot journalier Supabase

### Point corrigé
Le modèle `DaySnapshot` contenait `updatedAt`, mais ce champ n’était pas sérialisé dans `toJson()`.

### Correctif
- ajout de `updated_at` dans le payload JSON si présent
- ajout de `updatedAt: DateTime.now()` sur les snapshots envoyés depuis le dashboard

### Fichiers concernés
- `lib/models/day_snapshot.dart`
- `lib/dashboard/dashboard_notifier.dart`

### Test ajouté
- `test/models/day_snapshot_test.dart`

## 11. Déploiement web Firebase / cache iPhone PWA

### Problème
Le déploiement Firebase affichait `Deploy complete`, mais l’iPhone web app restait parfois sur une ancienne version.

### Diagnostic
Le problème venait très probablement du cache web/PWA :
- `main.dart.js` était servi avec un cache long
- sur iPhone / Safari / app ajoutée à l’écran d’accueil, cela peut conserver un ancien bundle

### Correctifs
#### `firebase.json`
Les headers de cache ont été corrigés :
- `index.html` : `no-cache`
- `main.dart.js` : `no-cache`
- `flutter_bootstrap.js` : `no-cache`
- `flutter_service_worker.js` : `no-cache`
- `version.json` : `no-cache`

#### `deploiement.sh`
Le script a été modifié pour :
- `set -euo pipefail`
- `flutter clean`
- `flutter pub get`
- `flutter build web --pwa-strategy=none`
- copie propre des routes statiques
- message final pour le cas iPhone web app

### Fichiers concernés
- `firebase.json`
- `deploiement.sh`

### Procédure recommandée iPhone web app
Après redéploiement :
1. fermer complètement la web app
2. supprimer l’icône de l’écran d’accueil si nécessaire
3. rouvrir l’URL dans Safari
4. vérifier la bonne version
5. réajouter à l’écran d’accueil

## 12. Tests et stabilité

### Vérifications exécutées
- `flutter test` complet : OK
- `23 tests` passaient au moment du dernier run large
- plusieurs tests ciblés ajoutés ensuite

### Couverture ajoutée sur :
- recherche locale d’aliments
- priorité `serving_size`
- agrégation du rapport aliments
- conservation de l’historique `DailyCalories`
- calcul des macros selon les types d’entraînement
- conversion de dates backend
- matching alimentaire
- payload `DaySnapshot`

### Niveau de stabilité
L’app est significativement plus stable qu’au départ sur :
- cohérence des objectifs énergétiques
- recherche alimentaire
- exploitation de l’historique journalier
- robustesse des graphes
- non-régression métier sur les zones touchées

### Limites restantes
- les repas détaillés ne sont pas récupérables depuis Supabase si le local Hive est perdu
- Supabase stocke des snapshots journaliers agrégés, pas la liste détaillée des `Meal`
- donc :
  - historique journalier global : récupérable
  - repas détaillés jour par jour : non, sans vraie sync distante des `Meal`

## 13. Point d’architecture important

### État actuel
- `Meal` détaillés : stockés localement dans Hive
- `DailyCalories` / `DaySnapshot` : utilisés pour les historiques journaliers et certains graphes
- Supabase ne suffit pas à reconstruire les repas détaillés

### Conséquence
Si le stockage local Hive est perdu :
- on conserve des courbes et des totaux journaliers
- on ne retrouve pas automatiquement les aliments / repas détaillés

### Correctif structurel recommandé
Si l’objectif est de ne jamais perdre l’historique détaillé :
1. créer une table Supabase pour les `Meal`
2. synchroniser add/update/delete de repas vers Supabase
3. réhydrater Hive depuis Supabase au démarrage si besoin

## 14. Fichiers principaux ajoutés ou modifiés

### Nouveaux helpers / logique extraite
- `lib/dashboard/food_analysis_helpers.dart`
- `lib/dashboard/macro_needs_helper.dart`
- `lib/meal_input/meal_search_helpers.dart`

### Fichiers métier modifiés
- `lib/dashboard/dashboard_notifier.dart`
- `lib/dashboard/widgets/energy_gauge_card.dart`
- `lib/dashboard/widgets/food_analysis_section.dart`
- `lib/courbe/bej_providers.dart`
- `lib/courbe/macro_providers.dart`
- `lib/courbe/unsaturated_ratio_providers.dart`
- `lib/repositories/daily_calories_repository.dart`
- `lib/repositories/daily_snapshot_remote_repository.dart`
- `lib/services/date_service.dart`
- `lib/services/food_matching_service.dart`
- `lib/models/day_snapshot.dart`
- `lib/meal_input/meal_input_notifier.dart`
- `lib/meal_input/meal_input_page.dart`
- `firebase.json`
- `deploiement.sh`

### Tests ajoutés
- `test/services/date_service_test.dart`
- `test/services/food_matching_service_test.dart`
- `test/dashboard/food_analysis_helpers_test.dart`
- `test/dashboard/macro_needs_helper_test.dart`
- `test/repositories/daily_calories_repository_test.dart`
- `test/meal_input/meal_search_helpers_test.dart`
- `test/models/day_snapshot_test.dart`

## 15. Conclusion opérationnelle

### Ce qui est rétabli
- recherche locale fiable
- objectifs énergie cohérents entre dashboard et rapport
- logique macro explicitée selon les types d’entraînement
- historique calomètre conservé
- graphes macros/lipides capables de relire Supabase
- déploiement web iPhone plus fiable

### Ce qui n’est pas rétabli automatiquement
- récupération des repas détaillés jour par jour si le local Hive est vide

### Prochaine étape structurante
Mettre en place une synchronisation distante des repas si l’historique détaillé doit survivre :
- aux nettoyages locaux
- aux changements d’appareil
- aux réinstallations
