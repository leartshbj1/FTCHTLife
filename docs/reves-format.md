# Rêves de vie : format des données et branchement

À 16 ans, le perso tire **3 rêves secrets** : un sérieux, un ambitieux, un absurde.
Chaque rêve réalisé donne un gros bonus de bonheur. Certains rêves ont une date limite : passé l'âge, le rêve est raté.
À la mort, le jeu calcule un score « vie réussie » sur 100 (60 points pour les rêves, 40 pour la vie en général).

Code : `FTCHTLife/Dreams/` (types préfixés `Reve`/`Reves`).
Données : `FTCHTLife/Resources/Data/Dreams/*.json` (catalogue) et `FTCHTLife/Resources/Data/Events/reves_*.json` (événements « occasion »).
Vérification : `python3 tools/validate_reves.py`.

## Un rêve (`Data/Dreams/<fichier>.json`, un tableau par fichier)

```json
{
  "id": "reve_chirurgien",
  "level": "serieux",
  "title": "Devenir chirurgien·ne",
  "description": "Tenir un bistouri sans trembler, et sans le perdre dans un patient.",
  "achievedText": "Tu as opéré ton premier patient. Il a survécu, et il t'a même dit merci.",
  "failedText": null,
  "happiness": 25,
  "points": 30,
  "weight": 1,
  "gender": "any",
  "requires": [],
  "deadlineAge": null,
  "conditions": { "jobTitleContains": ["chirurg"] },
  "marks": []
}
```

| Clé | Obligatoire | Sens |
|---|---|---|
| `id` | oui | unique, commence par `reve_`. C'est aussi le **tag** actif tant que le rêve est en cours. |
| `level` | oui | `serieux`, `ambitieux` ou `absurde`. Un rêve de chaque niveau est tiré. |
| `title` | oui | court, s'affiche dans le profil (« Ouvrir un kebab »). |
| `description` | oui | une phrase drôle sous le titre. |
| `achievedText` | oui | ligne du journal quand le rêve est réalisé. |
| `failedText` | non | ligne du journal quand la date limite passe (sinon texte par défaut). |
| `happiness` | non | bonus de bonheur à la réalisation (défaut : sérieux 20, ambitieux 30, absurde 25). |
| `points` | non | poids dans le score final (défaut : sérieux 20, ambitieux 35, absurde 25). |
| `weight` | non | fréquence relative au tirage (défaut 1). |
| `gender` | non | `any`, `male`, `female`. |
| `requires` | non | situation nécessaire **au moment du tirage** : `mother`, `father`, `siblings`, `friend`. |
| `deadlineAge` | non | âge limite : si le rêve n'est pas réalisé à cet âge, il est raté. |
| `conditions` | * | le rêve est réalisé dès que **toutes** ces conditions sont vraies (vérifié à chaque année et après chaque choix). |
| `marks` | * | le rêve est réalisé dès qu'**une** de ces marques est posée (par un événement ou un autre module). |

\* Il faut au moins un moyen de réaliser le rêve : `conditions`, `marks`, ou un événement occasion qui marque l'`id` du rêve.
Un rêve est aussi toujours réalisé quand la marque égale à son propre `id` est posée.

Textes : `{prenom}`, `{nom}`, `{ville}`, `{mere}`, `{pere}`, `{fratrie}` et `{e}` (accord féminin simple du joueur, ex. `connu{e}`, jamais `heureux{e}`).
Pour les titres de métiers, l'écriture `chirurgien·ne` est acceptée.

### Conditions possibles (`conditions`)

Toutes optionnelles, toutes doivent être vraies.

| Clé | Exemple | Vrai si |
|---|---|---|
| `minMoney` / `maxMoney` | `1000000` | argent ≥ / ≤ |
| `minDiploma` | `"bac"` | diplôme ≥ (`ecoleObligatoire`, `bac`, `licence`, `master`, `doctorat`) |
| `diplomaField` | `"medecine"` | filière du diplôme (`medecine`, `droit`, `informatique`, `commerce`, `arts`, `sciences`) |
| `jobs` | `["medecin", "chirurgien"]` | métier actuel parmi ces identifiants |
| `jobTitleContains` | `["chirurg"]` | l'intitulé du poste contient un de ces bouts de mot (sans accents ni majuscules). À préférer à `jobs`, car le module métiers ajoute beaucoup de postes. |
| `minJobLevel` | `4` | niveau de promotion ≥ (0 à 4, 4 = directeur·rice) |
| `minJobYears` | `10` | années dans le poste actuel ≥ |
| `minSalary` | `200000` | salaire annuel ≥ |
| `unemployed` | `true` | adulte sans emploi ni études (ou `false` : en emploi ou en études) |
| `minHappiness` `maxHappiness` `minHealth` `maxHealth` `minSmarts` `maxSmarts` `minLooks` `maxLooks` `minKarma` `maxKarma` | `90` | stat (0-100) ≥ / ≤ |
| `minAge` | `100` | âge ≥ |
| `partner` | `true` | a (ou n'a pas) un·e partenaire vivant·e |
| `minChildren` | `3` | nombre d'enfants vivants ≥ |
| `minFriends` | `10` | nombre d'amis vivants ≥ |
| `seenEvents` | `["base_0012"]` | tous ces événements `unique` ont eu lieu |

Métiers existants dans le moteur (`jobs`) : plongeur, caissier, livreur, agent_entretien, mannequin, macon, chauffeur, coiffeur, vendeur,
policier, secretaire, influenceur, agent_immo, dev, comptable, marketing, graphiste, chercheur, prof, avocat, juge, medecin, chirurgien.

## Événements occasion (`Data/Events/reves_<theme>.json`)

Format standard des événements (voir `docs/ARCHITECTURE.md`). Pour qu'un événement n'arrive qu'aux joueurs qui ont ce rêve en cours,
mettez l'`id` du rêve dans `conditions.tags`. Pour réaliser le rêve, ajoutez dans les effets de l'issue gagnante :

```json
"effects": { "happiness": 5, "dreamMarks": ["reve_ping_pong_pere"] }
```

`dreamMarks` est une liste de marques. Une marque égale à l'`id` d'un rêve le réalise. D'autres marques (ex. `"bateau"`) servent
aux rêves qui listent cette marque dans `marks`.

Conseils : `"unique": false` (on peut retenter l'année suivante), `weight` entre 3 et 8 (le tag limite déjà beaucoup),
plusieurs choix dont un qui peut réussir avec une chance raisonnable (0.3 à 0.7), et des échecs drôles.
Identifiants : `reve_occ_<nom>_<n>`.

## Marques que les autres modules peuvent poser

Un module appelle `RevesMoteur.marquer(&joueur.reves, ["bateau"])` (ou un événement met `"dreamMarks"`).
Marques déjà utilisées par le catalogue : voir la sortie de `python3 tools/validate_reves.py --marks`.

## Branchement dans le moteur (fil moteur)

1. `Models/Models.swift`, dans `Joueur` : `var reves: RevesDeVie?`
2. `Models/Evenement.swift`, dans `Effets` : `var dreamMarks: [String]?`
3. `GameEngine.appliquer` : `if let m = eff.dreamMarks { RevesMoteur.marquer(&j.reves, m) }`
4. `GameEngine.tags` : `t.formUnion(RevesMoteur.tags(j.reves))`
5. Mise à jour (tirage à 16 ans, rêves réalisés ou ratés, bonus de bonheur, lignes du journal), une ligne :
   `revesMettreAJour(&j, etat: \.reves)`
   - dans `vieillir()` juste après `j.journal.append(Annee(...))` (avant `joueur = j`) ;
   - dans `choisir(_:)` après `appliquer` ;
   - dans `modifier(_:)` après `action(&j)`.
6. `ProfilView` : `RevesSection(etat: j.reves, joueur: j)` dans la `List`.
7. `DeathView` : `RevesScoreCarte(etat: j.reves, joueur: j)` sous le résumé.

Le score est aussi disponible pour la nécrologie : `RevesMoteur.score(j.reves, joueur: j)`.
