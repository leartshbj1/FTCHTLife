# Format des événements aléatoires

Fichiers : `FTCHTLife/Resources/Data/Events/<categorie>_<NN>.json`, chacun un tableau JSON d'événements.

```json
{
  "id": "enf_0001",
  "category": "enfance",
  "minAge": 3,
  "maxAge": 12,
  "weight": 10,
  "conditions": { "gender": "any", "minMoney": null, "requiresJob": null, "requiresPartner": null, "requiresSchool": null },
  "text": "{prenom}, ton voisin te propose d'échanger ton goûter contre un caillou « magique ».",
  "choices": [
    { "label": "Accepter", "outcomes": [
      { "chance": 0.7, "text": "Le caillou n'est pas magique. Tu as faim.", "effects": { "happiness": -3 } },
      { "chance": 0.3, "text": "Tu le revends 2 € à ta sœur. Génie.", "effects": { "happiness": 5, "money": 2 } }
    ]},
    { "label": "Refuser", "outcomes": [
      { "chance": 1.0, "text": "Tu manges ton goûter en le regardant dans les yeux.", "effects": { "happiness": 2 } }
    ]}
  ]
}
```

- `id` : unique dans tout le jeu, préfixe de catégorie + numéro.
- `category` : `bebe`, `enfance`, `ecole`, `ado`, `etudiant`, `adulte`, `travail`, `amour`, `famille`, `sante`, `argent`, `vieillesse`, `absurde`, …
- `weight` : fréquence relative (1 rare, 10 courant).
- `unique: true` (optionnel) : n'arrive qu'une fois par vie.
- `conditions` : toutes optionnelles. `gender` ∈ `any|male|female`. `requiresJob`, `requiresPartner`, `requiresSchool` : `true|false|null`. `minMoney`, `maxMoney` en euros. `tags` / `excludeTags` : listes parmi `male female baby school university job adult unemployed retired rich poor friend mother father siblings partner children sick attractive smart`.
- `choices` : 1 à 4 choix ; dans chaque choix la somme des `chance` vaut 1. Un événement sans choix a `"choices": []` et `effects` à la racine.
- `effects` : deltas. `happiness`, `health`, `smarts`, `looks`, `money`, `karma`, `stress`, `fame` (stats en points -100..100, `money` en euros), plus :
  - `"relationships": {"mother": 5, "father": -3, "parent": 2, "sibling": 4, "friend": 3, "partner": -10, "child": 6}`
  - `"newFriend": true` (ajoute un ami), `"death": "cause"` (la phrase suit « Tu es mort/morte … »).
  - Aucune autre clé (pas de licenciement, prison, objets : gérés par d'autres modules).
- Placeholders : `{prenom}`, `{nom}`, `{ville}`, `{mere}`, `{pere}`, `{parent}`, `{ami}`, `{fratrie}`, `{partenaire}`, `{metier}`, et `{e}` = accord féminin du joueur seulement (`content{e}`, pas `mystérieux{e}`). Pas de variable pour patron/collègue/enfant : écris « ton patron », « ta collègue Sandrine », « ton fils ».
- Drapeaux (suites différées, voir `docs/REPERCUSSIONS.md`) : `"effects": {"setFlags": ["fume"]}` pose un drapeau ; `"conditions": {"flags": [...], "excludeFlags": [...]}` les exige ou les exclut.
- **Une fois un événement publié, ne change plus son `id` ni l'ordre de ses choix et issues** : les répercussions s'y réfèrent par index.
- Une variable de personne exige sa condition : {mere}→tag mother, {pere}→father, {fratrie}→siblings, {ami}→friend, {partenaire}→requiresPartner, {metier}→requiresJob (le validateur le vérifie).
- Talents (module compétences) : un choix peut avoir `"requiresSkill": {"cuisine": 3}` (caché si le joueur n'a pas ce niveau, 1 à 5) ; `conditions.skills` réserve l'événement ; `effects.skills: {"code": 5}` donne de l'XP. Ids : anglais espagnol allemand italien albanais japonais guitare piano chant danse dessin photo cuisine bricolage mecanique jardinage sport survie code echecs seduction eloquence humour marchandage magie. Toujours au moins un choix sans `requiresSkill`. Saupoudre des choix cachés (« Répondre en allemand », « Réparer toi-même ») pour rendre les talents visibles.
- Tags train de vie (moteur) : `millionaire milliardaire endette gros_salaire petit_salaire chez_parents locataire proprietaire voiture voiture_luxe moto bateau avion_prive bijoux collection_art multi_proprietaire vie_de_luxe grand_voyageur`, politique : `pol_candidat pol_elu pol_chef_parti pol_gouverne pol_militant pol_scandale pol_ancien`. Le moteur limite à 3 événements à choix par an et favorise ceux aux conditions précises.
- Drapeaux d'état communs (ont déjà des effets annuels, voir `docs/REPERCUSSIONS.md`) : `fume boit_trop mange_mal sportif_regulier sedentaire insomniaque dos_fragile accro_aux_ecrans zen deprime anxieux burn_out coeur_brise solitaire optimiste complexe traumatise menteur_notoire populaire honte_publique heros_local endette econome panier_perce dette_louche surendette lecteur_assidu polyglotte tatoue coupe_ratee refait_de_partout benevole voleur rancunier genereux`. Les poser via `setFlags` donne des conséquences qui durent des années.
- Scènes à choix enchaînés (docs/SCENES.md) : une issue peut avoir `"then": {"id": "<id>_b", "text": "…", "choices": [...]}` pour enchaîner 2 ou 3 choix dans la même carte (pour les grands moments ; compte pour un seul événement). Un choix peut forcer le risque affiché avec `"risk": "none|low|medium|high|extreme"` (sinon calculé à partir des issues).
