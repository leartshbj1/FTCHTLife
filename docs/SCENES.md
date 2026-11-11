# Scènes à choix enchaînés, risque affiché, rappels (idées 58 et 59)

## Scènes à choix enchaînés (idée 58)

Pour les grands moments, une carte peut enchaîner 2 ou 3 choix à la suite au lieu d'un seul.
Une scène reste **un seul événement** : elle compte pour 1 dans la limite de 3 événements à choix par an.

Une issue peut porter `then` : l'étape suivante, avec son texte et ses choix. Après le résultat, le bouton devient
« Et ensuite… » et la même carte affiche l'étape suivante. Les étapes déjà jouées restent en petit au-dessus.

```json
{ "label": "T'arrêter", "outcomes": [
  { "chance": 1.0, "text": "Tu te gares, warnings allumés…",
    "then": { "id": "scn_0003_b", "text": "La portière est coincée.", "choices": [
      { "label": "La sortir toi-même", "outcomes": [ … ] },
      { "label": "Appeler les secours", "outcomes": [ … ] }
    ] } }
] }
```

- `then.id` (conseillé) : commence par l'id de l'événement. Les répercussions peuvent viser une étape avec
  `"on": "event:scn_0003_b"`, `"choice"` et `"outcome"` comme pour un événement. Sans id, le signal est `event:<id>#<n° d'étape>`.
- `then.text`, `then.choices` : mêmes règles que les événements (1 à 4 choix, chances qui font 1, au moins un choix sans `requiresSkill`).
- 3 étapes au plus par scène (le validateur le vérifie).
- Les variables (`{ami}`, `{parent}`…) des étapes doivent être couvertes par les conditions de l'événement.
- Marche aussi dans les choix d'une suite (`Data/Repercussions`).

Données : `Data/Events/scenes_01.json` (21 scènes, ids `scn_NNNN`) et `Data/Repercussions/scenes_suites.json`
(4 scènes après un signal : premier soir en prison, obsèques d'un parent, garde des enfants au divorce, annoncer un licenciement).

Code : `Issue.then` et `EtapeScene` (Models/Evenement.swift), `GameEngine.choisir` (garde l'étape en attente),
`GameEngine.fermerEvenement` (passe à l'étape suivante dans la même carte), `EvenementAffiche.choixCourants`.

## Risque affiché avant de choisir (idée 59)

Sous chaque choix, un badge : « Sans risque », « Risque faible », « Risqué », « Très risqué », « Danger de mort »,
ou « Quitte ou double » / « Gros pari » quand un gros gain et une grosse perte sont tous deux probables.
Des icônes disent ce qui est en jeu (vie, liberté, santé, argent, couple, proches, moral, réputation).

- Calcul : `Engine/Risques.swift`, à partir des chances et des effets des issues (santé, argent rapporté à ce que
  possède le joueur, prison, casier, maladie, rupture, drapeaux néfastes comme `fume` ou `endette`…).
- « Sans risque » n'est affiché que si un autre choix de la carte est risqué (pour comparer).
- Rien n'est affiché sur les cartes résolues par du code (secrets, successions, soirées électorales, cartes de métier).
- Un auteur peut forcer le niveau : `"risk": "none" | "low" | "medium" | "high" | "extreme"` sur un choix.

## « Parce que tu as fait X il y a N ans » (idée 59)

Quand une suite arrive, la carte affiche un bandeau « Ça vient de là » : « Parce que tu as choisi « Accepter » il y a 6 ans,
à 14 ans », avec le début du texte de la carte d'origine. Une suite sans choix ajoute la même phrase dans le journal.
Les états durables (`"on": "chaque_annee"`) rappellent leur origine (« Parce que tu fumes depuis 8 ans »).
Après un choix qui programme une suite ou pose un drapeau, la carte dit « Ce choix laissera des traces. »

- `Souvenir` (Engine/Souvenirs.swift) : âge, phrase au passé, extrait de la carte d'origine.
- Pendant `choisir`, `Repercussions.souvenirCourant` contient le choix : chaque suite programmée
  (`RepercussionProgrammee.souvenir`) et chaque drapeau posé (`RepercussionsEtat.origines`) s'en souvient.
- Un signal de module hors carte (« mariage », « promotion »…) donne une phrase par défaut (`Souvenir.phrasesSignaux`).
  Ajouter un signal à cette table pour qu'il ait son rappel.
- Les drapeaux d'état sans origine connue ont une phrase dans `Souvenir.phrasesEtats`.
- Les anciennes sauvegardes restent valables : tous les nouveaux champs sont optionnels.
