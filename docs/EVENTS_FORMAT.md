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
