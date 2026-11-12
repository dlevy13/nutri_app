# Recherche et ajout de repas

## Changements

- Page « Composer mon repas » : contexte du repas et date lisibles, choix du repas
  dans un champ du thème, contenu limité à 960 px sur grand écran.
- Recherche placée avant la description du plat. L’aide IA est dépliable ; son
  action n’est disponible qu’avec une description non vide.
- Résultats locaux et sportifs présentés par `FoodListItem`. Les valeurs sont
  indiquées par 100 g et les marques restent visibles, sans libellés techniques.
- Recherche externe et création d’aliment accessibles par des boutons qui
  reviennent à la ligne sur petit écran.
- Suggestions et aliments ajoutés harmonisés : surfaces claires, noms sur deux
  lignes et contrôles de quantité de 48 px avec libellés accessibles.
- Totaux avec noms complets des nutriments et couleurs du dashboard. La barre
  passe de quatre à deux colonnes suivant la largeur et la taille du texte ;
  elle est masquée pendant la saisie au clavier dans la page repas.
- Écran de quantité défilant, largeur limitée, portions usuelles et suggestions
  rapides conservées. Le bouton d’ajout reste dans la zone redimensionnée
  au-dessus du clavier. Les quantités avec virgule sont acceptées ; les valeurs
  vides, nulles, négatives, non finies ou supérieures à 999999 sont refusées.
- Les noms contenant une apostrophe sont conservés lors du choix de quantité.

La recherche, les calculs nutritionnels, les écritures des repas, la copie du
repas d’hier et les appels aux services utilisent les mécanismes existants.

## Vérification

SDK utilisé : Flutter 3.44.6 dans
`/Users/davidlevy/Documents/David/NutriFlutter/flutter`.

- 43 tests réussis, dont 9 nouveaux tests de présentation et d’interaction.
- Largeurs de 320, 768 et 1280 px, texte à 160 % et clavier simulé pour les quantités.
- Recherche et effacement, activation de l’action IA, demi-portion, saisie
  décimale française, validation et retour de la quantité en grammes.
- Actions de portion et suppression des aliments.
- Analyse Flutter : aucune erreur ni avertissement ; 4 informations existantes
  dans des fichiers hors chantier.
- Compilation web debug réussie et `git diff --check` sans erreur.

Les tests des composants n’appellent pas les services distants : les réponses
réelles de recherche, d’IA et de stockage nécessitent une session connectée pour
une vérification de bout en bout. Aucun déploiement n’a été effectué.
