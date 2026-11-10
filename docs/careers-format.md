# Format des données : métiers et carrières

Tout le contenu des métiers vit dans des fichiers JSON, séparés du code Swift.
Ajouter un métier ou un événement = ajouter une entrée JSON, sans toucher au code.

- `FTCHTLife/Resources/Data/Careers/*.json` : un fichier par secteur, contenant un tableau de métiers (`CareerJob`).
- `FTCHTLife/Resources/Data/WorkEvents/*.json` : événements de travail (`CareerWorkEvent`).
- `FTCHTLife/Resources/Data/CareerMajors/majors.json` : filières d'études (`CareerMajor`).
- `FTCHTLife/Resources/Data/CareerCompanies/companies.json` : entreprises fictives par secteur (`CareerCompanyList`).
- `tools/validate_careers.py` : vérifie les fichiers (ids uniques, champs, références, chances, variables, permis).

## Code Swift (`FTCHTLife/Careers/`)

- `CareerModels.swift` : types décodés (`CareerJob`, `CareerWorkEvent`, `CareerEffects`…).
- `CareerCatalog.swift` : `CareerCatalog.shared` charge tout via `DonneesJSON.chargerTableaux`.
- `CareerState.swift` : `CareerProfile` (ce que le moteur fournit sur le joueur), `CareerJobState` (emploi en cours, à sauvegarder), `CareerRecord` (CV).
- `CareerEngine.swift` : fonctions pures : `eligibility`, `availableCareers`, `hiringChance`, `apply(to:)`, `advanceYear` (salaire, stress, célébrité, arrestation, licenciement, promotion), `perform(_ action:)` (travailler dur, glander, augmentation, promotion, fayoter, sympathiser, démissionner), `randomEvent`, `pickOutcome`, `applyEffects`, `pension`.
- `CareerText.swift` : accord en genre de l'écriture « Directeur·rice » selon `CareerProfile.isFemale`.
- `CareerBridge.swift` : correspondances avec `Diplome`/`Filiere` du moteur.
- `CareerViews.swift` : `CareerJobBoardView` (offres d'emploi filtrables) et `CareerCurrentJobSection` (mon travail), qui renvoient les choix par closures.

Le moteur applique lui-même les effets renvoyés (`CareerEffects`, `YearReport.income`) sur le joueur.

## Métier (`Career`)

```json
{
  "id": "medecin_generaliste",
  "name": "Médecin généraliste",
  "sector": "sante",
  "kind": "standard",
  "description": "Écouter des gens tousser pendant 40 ans.",
  "requirements": {
    "education": "doctorat",
    "majors": ["medecine"],
    "minAge": 25,
    "maxAge": null,
    "minSmarts": 70,
    "minLooks": 0,
    "minHealth": 0,
    "requiresLicense": null
  },
  "ladder": [
    { "title": "Interne", "salary": 26000, "yearsToPromote": 3 },
    { "title": "Médecin remplaçant", "salary": 52000, "yearsToPromote": 2 },
    { "title": "Médecin installé", "salary": 85000, "yearsToPromote": 0 }
  ],
  "stress": 70,
  "prestige": 80,
  "hiringDifficulty": 50
}
```

- `id` : snake_case, unique dans tout le jeu.
- `sector` : un des secteurs listés plus bas.
- `kind` :
  - `standard` : temps plein classique, avec échelons.
  - `partTime` : petit boulot (ados, étudiants, retraités), souvent un seul échelon, salaire annuel bas.
  - `freelance` : à son compte ; salaire = revenu moyen, très variable.
  - `special` : carrière spéciale (star, sportif pro, politique, influenceur…) avec règles propres (voir `special`).
  - `illegal` : carrière criminelle (risque d'arrestation, voir `special.arrestRisk`).
  - `military` : armée (engagement, grades).
- `requirements.education` : niveau minimum, dans l'ordre :
  `none` < `brevet` < `cap` < `bac` < `licence` < `master` < `doctorat`.
  `cap` couvre CAP/BEP/formation pro. Le moteur considère `cap` atteint si le perso a un CAP **ou** un niveau ≥ `bac`.
- `requirements.majors` : filières acceptées (vide = n'importe laquelle). Liste dans `majors.json`.
- `minSmarts`, `minLooks`, `minHealth` : stats 0–100.
- `requiresLicense` : `null`, un permis du module Permis (`permis_voiture`, `permis_moto`, `permis_poids_lourd`, `permis_bus`, `permis_bateau`, `licence_pilote`, `licence_helico`, `permis_armes`, `brevet_drone`, `permis_fusee`…), qui doit être obtenu avant, ou un concours/examen (`barreau`, `concours_*`, `examen_*`), passé pendant la candidature (il baisse la chance d'embauche et récompense l'intelligence).
- `ladder` : échelons du plus bas au plus haut. `salary` en euros par an. `yearsToPromote` = ancienneté minimum avant de pouvoir être promu (0 sur le dernier échelon).
- `stress`, `prestige`, `hiringDifficulty` : 0–100.

### Bloc `special` (facultatif, pour `special`, `illegal`, `freelance`)

```json
"special": {
  "fameGain": 10,
  "arrestRisk": 0,
  "skill": "talent",
  "audition": true,
  "incomeVariance": 0.6
}
```

- `fameGain` : célébrité gagnée par an (0–100).
- `arrestRisk` : % de risque d'arrestation par an.
- `skill` : stat clé qui pilote la progression (`smarts`, `looks`, `health`, `talent`, `charisma`, `athleticism`).
- `audition` : la candidature passe par une épreuve (casting, essai, élection…).
- `incomeVariance` : 0–1, part aléatoire du revenu annuel.

## Secteurs

`sante`, `education`, `droit`, `finance`, `tech`, `ingenierie`, `batiment`, `industrie`,
`transport`, `commerce`, `restauration`, `hotellerie_tourisme`, `art_culture`, `medias`,
`spectacle`, `sport`, `securite`, `armee`, `administration`, `politique`, `agriculture`,
`environnement`, `science`, `beaute_mode`, `services`, `religion`, `crime`, `insolite`.

## Événement de travail (`WorkEvent`)

```json
{
  "id": "we_sante_patient_wikipedia",
  "conditions": {
    "careers": [],
    "sectors": ["sante"],
    "kinds": ["standard"],
    "minLevel": 0,
    "minYearsInJob": 0
  },
  "weight": 10,
  "text": "Un patient arrive avec 14 pages imprimées de forums et t'explique ton métier.",
  "choices": [
    {
      "label": "L'écouter poliment",
      "outcomes": [
        { "chance": 70, "text": "Il repart content. Toi un peu moins.", "effects": { "happiness": -3, "performance": 2 } },
        { "chance": 30, "text": "Il avait raison. Tu ne le diras jamais à personne.", "effects": { "smarts": 2 } }
      ]
    },
    {
      "label": "Lui confisquer ses feuilles",
      "outcomes": [
        { "chance": 100, "text": "Il te note une étoile sur internet.", "effects": { "performance": -5, "happiness": 4 } }
      ]
    }
  ]
}
```

- `conditions` : listes vides = pas de filtre. Un événement s'applique si le métier actuel correspond à **toutes** les listes non vides.
- `weight` : fréquence relative.
- Chaque `choice` a 1 à 4 `outcomes` dont les `chance` font 100.
- `effects` (tous facultatifs) :
  - stats : `happiness`, `health`, `smarts`, `looks`, `karma`, `fame` (−100…100, ajoutés)
  - `money` : euros (+/−)
  - `performance` : jauge de performance au travail (0–100)
  - `bossRelation`, `coworkerRelation` : relation (−100…100)
  - `promoted: true`, `fired: true`, `quit: true`, `arrested: true`, `injured: true`
  - `salaryMultiplier` : ex. `1.1` = augmentation de 10 %
- Variables utilisables dans les textes : `{prenom}` (prénom du perso), `{e}` (« e » si le perso est une femme, pour les accords simples : `content{e}`), `{boss}`, `{coworker}`, `{company}`, `{title}` (intitulé de poste).
- L'écriture « Directeur·rice », « Joueur·se », « élu·e » est résolue selon le genre du perso (`CareerText`).
- `minLevel` compte les échelons à partir de 0.

## Ton

Français, humour décalé et absurde, phrases courtes, tutoiement. Original : aucun texte, nom ou événement copié d'un autre jeu.
