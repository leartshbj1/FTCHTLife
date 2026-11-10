# FTCHTLife : architecture et règles pour contribuer

Jeu de simulation de vie original pour iOS (SwiftUI, iOS 16+). Textes en français.
Le jeu est **original** : on reprend le genre (vie année par année, stats, choix absurdes),
pas les textes, noms ou visuels d'un autre jeu.

## Projet Xcode

- Projet généré par **XcodeGen** depuis `project.yml` (le `.xcodeproj` n'est pas versionné).
- Une seule cible : `FTCHTLife`. **Tout fichier `.swift` placé n'importe où sous `FTCHTLife/` est compilé automatiquement.** Pas besoin de toucher `project.yml`.
- Le dossier `FTCHTLife/Resources/Data/` est copié **tel quel avec ses sous-dossiers** dans l'app (`Bundle.main.resourceURL/Data/...`).
- Le .ipa non signé est fabriqué par `scripts/build-ipa.sh` (XcodeGen + `xcodebuild` sans signature), lancé par **CircleCI** (`.circleci/config.yml`) à chaque push, sur toutes les branches. Le .ipa est dans les « Artifacts » du job. Plan B : `codemagic.yaml`. (GitHub Actions est inutilisable : compte bloqué.)
- Le script vérifie aussi que tous les JSON de `Resources/Data` sont valides.

## Où ranger quoi

| Dossier | Contenu | Fil responsable |
|---|---|---|
| `FTCHTLife/App`, `Engine`, `Models`, `Views` | moteur, modèle du joueur, écrans principaux | moteur (fil principal) |
| `FTCHTLife/CharacterCreation/` | création de perso | création de perso |
| `FTCHTLife/Careers/` | métiers, carrières | métiers |
| `FTCHTLife/Shop/` | boutique, biens, argent | boutique |
| `FTCHTLife/Systems/` | amour, crime, santé, générations | amour/crime/santé |
| `FTCHTLife/Shkurtaaa/` | mode triche | mode triche |
| `FTCHTLife/Resources/Data/Events/*.json` | événements aléatoires | événements |
| `FTCHTLife/Resources/Data/<Module>/*.json` | données de chaque module (`Careers`, `WorkEvents`, `Shop`, `Relationships`, `Crime`, `Health`, `Creation`) | chaque module |

Règles :
1. Un module ne modifie **pas** les fichiers de `App/`, `Engine/`, `Models/`, `Views/`. Le fil moteur fait le branchement.
2. Un module expose des types et fonctions **autonomes** (Foundation/SwiftUI seulement), qui compilent seuls dans la cible.
3. Préfixez vos types pour éviter les collisions de noms (deux fichiers qui déclarent `Job` ou `Character` = la compilation casse). Par ex. `CareerJob`, `ShopItem`, `CrimeAction`.
4. Noms de fichiers JSON uniques à l'intérieur d'un dossier ; n'importe quel nom ailleurs.
5. Chargez vos JSON avec `DonneesJSON.chargerTableaux(dossier: "Careers", type: VotreType.self)` (défini dans `Models/Evenement.swift`) : chaque fichier contient un **tableau**. Pour un autre format, lisez depuis `DonneesJSON.dossierData`.

## Modèle du joueur (moteur)

`Joueur` (`Models/Models.swift`) :
- `stats: Stats` avec `sante`, `bonheur`, `intelligence`, `apparence`, `karma` : **Int de 0 à 100**.
- `argent: Int` en **euros** (peut être négatif = dettes). Affichage via `Format.argent(_:)`.
- `age: Int`, `genre: Genre` (`.homme` / `.femme`), `prenom`, `nom`, `ville`.
- `diplome: Diplome` (`aucun`, `ecoleObligatoire`, `bac`, `licence`, `master`, `doctorat`), `filiereDiplome: Filiere?`.
- `emploi: Emploi?`, `etudes: Etudes?`, `relations: [Relation]`.
- `actionsAnnee: [String]` : clés d'actions déjà faites cette année (vidé à chaque +1 an), pratique pour limiter une action à une fois par an.

Le moteur est `GameEngine` (`Engine/GameEngine.swift`, `@MainActor ObservableObject`, injecté en `environmentObject`).
Pour brancher un module : `engine.modifier { j in ... }` modifie le joueur et sauvegarde ; `engine.ajouterLigne(&j, "texte")` écrit dans le journal de l'année.

Si votre module a besoin de stocker un état dans la sauvegarde, définissez une struct `Codable` (ex. `Possessions`) : je l'ajoute comme champ optionnel de `Joueur`.

## Format des événements (`Resources/Data/Events/<categorie>.json`)

Chaque fichier est un tableau d'objets :

```json
{
  "id": "enf_0001",
  "category": "enfance",
  "minAge": 3,
  "maxAge": 12,
  "weight": 10,
  "unique": false,
  "conditions": {
    "gender": "any",
    "minMoney": null,
    "maxMoney": null,
    "requiresJob": null,
    "requiresPartner": null,
    "requiresSchool": null,
    "tags": ["siblings"],
    "excludeTags": []
  },
  "text": "… {prenom} …",
  "choices": [
    {
      "label": "…",
      "outcomes": [
        { "chance": 0.6, "text": "…", "effects": { "happiness": 5, "money": -20 } }
      ]
    }
  ]
}
```

- Tous les champs de `conditions` sont optionnels ; `null` ou absent = pas de condition. `gender` : `"any"`, `"male"`, `"female"`.
- `requiresSchool: true` = à l'école ou à l'université.
- `weight` (défaut 1) : fréquence relative. `chance` (défaut 1) : poids relatif de l'issue, pas besoin que la somme fasse 1.
- Sans choix : `"choices": []` et `"effects"` à la racine.
- `unique: true` : n'arrive qu'une fois par vie.
- `id` unique dans tout le jeu (préfixe par catégorie conseillé).

**Effets** (tous optionnels, deltas en points sur 0-100, argent en euros) :
`happiness`, `health`, `smarts`, `looks`, `karma`, `money`, `stress`, `fame`
(`stress` et `fame` sont lus mais pas encore utilisés), plus :
- `"relationships": {"mother": 5, "father": -3, "parent": 2, "sibling": 4, "friend": 3, "partner": -10, "child": 6}`
- `"newFriend": true` : ajoute un ami au hasard.
- `"death": "écrasé par un distributeur de boissons"` : le joueur meurt (la phrase suit « Tu es mort/morte … »).

**Tags** utilisables dans `conditions.tags` / `excludeTags` :
`male`, `female`, `baby` (<6 ans), `school`, `university`, `job`, `adult` (18+), `unemployed`, `retired` (65+),
`rich` (≥ 100 000 €), `poor` (< 1 000 €), `friend`, `mother`, `father`, `siblings`, `partner`, `children`,
`sick` (santé < 30), `attractive` (apparence ≥ 75), `smart` (intelligence ≥ 75).
D'autres tags pourront être ajoutés par les modules (ex. `prison`, `owns_car`) : demandez-les au fil moteur.

**Variables dans les textes** :
`{prenom}`, `{nom}`, `{ville}`, `{mere}`, `{pere}`, `{parent}`, `{ami}`, `{fratrie}`, `{partenaire}`, `{metier}`,
et `{e}` qui devient « e » si le joueur est une fille/femme (ex. `content{e}`). N'utilisez `{e}` que pour des accords simples
(pas « mystérieux{e} »), et seulement pour le joueur, pas pour les autres personnages.

## Pull requests

- Une branche et une PR par fil, petites PR fréquentes.
- La PR doit passer la CI (compilation + JSON valides) avant d'être fusionnée.
- Le fil moteur relit et fusionne, puis branche le module dans l'interface.
