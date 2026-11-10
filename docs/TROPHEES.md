# Trophées

Collection gardée d'une vie à l'autre : « Mourir le jour de son anniversaire », « Se marier 5 fois »,
« Club des 27 »… Certains trophées débloquent un **bonus de départ** que le joueur équipe (3 maximum)
pour ses prochaines naissances.

- Code : `FTCHTLife/Trophees/` (`TropheesModele.swift`, `TropheesSuivi.swift`, `TropheesView.swift`).
- Données : `FTCHTLife/Resources/Data/Trophees/trophees_<categorie>.json` (380 trophées au départ).
- Vérification : `python3 tools/validate_trophees.py` (ajouter `--signaux` pour lister les signaux utilisés).
- Sauvegarde : fichier à part, `Documents/ftchtlife-trophees.json`, jamais effacé par « Nouvelle vie ».

## Branchement dans l'app (fil moteur)

1. Racine : `ContentView()` → ajouter `.suiviTrophees()` (dans `FTCHTLifeApp`, après `.environmentObject(engine)`,
   ou à la fin du `body` de `ContentView`). Ce modificateur observe `engine.joueur`, débloque les trophées,
   applique les bonus à la naissance et affiche le bandeau « Trophée obtenu ».
2. Un bouton qui ouvre `TropheesView()` en feuille : dans le menu `…` de `MainView`, sur `DeathView` et sur `NewLifeView`.
3. Au lancement de l'app (optionnel mais recommandé), relier les autres modules :
   ```swift
   TropheesBranchements.compteurs = { $0.repercussions?.compteurs ?? [:] }
   TropheesBranchements.drapeaux = { Set(($0.repercussions?.flags ?? [:]).keys) }
   TropheesBranchements.modeShkurtaaa = { Shkurtaaa.actif }
   TropheesBranchements.tags = { _ in [] }                           // tags des modules s'ils ne sont pas déjà dans engine.tags
   ```
   Sans ces branchements, le module marche quand même avec ce qu'il déduit tout seul du joueur (voir plus bas).

Rien d'autre à toucher : pas de champ à ajouter dans `Joueur`.

## Comment un trophée se débloque

À chaque changement du joueur, chaque trophée non obtenu est testé. Les compteurs de la vie en cours viennent :

- des **signaux du module répercussions** (`Repercussions.signaler("mariage", …)`), via `TropheesBranchements.compteurs` ;
- des signaux que le module **déduit tout seul** en comparant le joueur d'une fois sur l'autre :
  `annee`, `embauche`, `promotion`, `licenciement`, `demission`, `retraite`, `bac_obtenu`, `diplome`, `couple`,
  `rupture`, `naissance_enfant`, `nouvel_ami`, `deces_parent`, `deces_proche`, `veuvage`, `mort_anniversaire` ;
- de `Trophees.shared.signaler("nom")`, pour un module qui veut signaler quelque chose aux trophées seulement.

Pour un même signal, on garde **le plus grand** des compteurs (pas de double comptage si le moteur émet aussi `promotion`).
Les compteurs **sur toutes les vies** (`compteursTotal`) cumulent tous les signaux, plus `vie` (vies commencées),
`mort` et `abandon` (vie effacée avant la mort).

Donc : **un module n'a rien à faire de spécial pour les trophées**. Il émet ses signaux comme pour les répercussions,
et les trophées qui les attendent tombent tout seuls. La liste des signaux attendus par les trophées est donnée par
`python3 tools/validate_trophees.py --signaux`. Les signaux qui ne sont pas encore dans docs/REPERCUSSIONS.md sont
repris en bas de ce fichier : les fils concernés peuvent les émettre quand ils le veulent.

## Format

```json
{
  "id": "tro_mariage_5",
  "nom": "Se marier 5 fois",
  "description": "Le maire te demande si c'est une blague.",
  "categorie": "amour",
  "rarete": "or",
  "secret": false,
  "condition": { "compteurs": { "mariage": 5 } },
  "bonus": { "titre": "Charme naturel", "description": "+10 apparence à la naissance.", "apparence": 10 }
}
```

- `id` : unique, préfixe `tro_`. `rarete` : `bronze`, `argent`, `or`, `legendaire`.
- `categorie` : `vie`, `mort`, `argent`, `amour`, `famille`, `ecole`, `travail`, `crime`, `sante`, `loisirs`, `casino`,
  `permis`, `boutique`, `celebrite`, `monde`, `animaux`, `etrange`, `collection`.
- `secret: true` : affiché « ??? » tant qu'il n'est pas obtenu.

### Conditions (toutes optionnelles, toutes doivent être remplies)

| Champ | Sens |
|---|---|
| `moment` | `"mort"` = testé seulement au moment de la mort. Par défaut, testé pendant toute la vie (et à la mort). |
| `compteurs` / `maxCompteurs` | signaux de la vie en cours, minimum / maximum : `{"mariage": 5}`, `{"arrestation": 0}` |
| `compteursTotal` | signaux sur toutes les vies : `{"mort": 10}` |
| `apresAge` / `avantAge` | le signal est arrivé au moins une fois à cet âge ou après / avant : `{"crime_reussi": 80}` |
| `drapeaux` / `sansDrapeaux` | drapeaux du module répercussions |
| `tags` / `excludeTags` | tags du moteur (`rich`, `partner`, `prison`…) |
| `gender` | `"male"` / `"female"` |
| `minAge`, `maxAge`, `minArgent`, `maxArgent` | âge, argent en euros |
| `minSante` … `maxKarma` | stats (`Sante`, `Bonheur`, `Intelligence`, `Apparence`, `Karma`), 0 à 100 |
| `diplome` / `maxDiplome` | `aucun`, `ecoleObligatoire`, `bac`, `licence`, `master`, `doctorat` |
| `filiere` | filière du diplôme obtenu |
| `emploi`, `metiers`, `minNiveau`, `minAnneesEmploi` | emploi actuel (`metiers` = ids de métiers) |
| `minRelations` / `maxRelations` | proches vivants par type : `mere`, `pere`, `frere`, `soeur`, `ami`, `partenaire`, `enfant`, `ex`, `fratrie`, `parents` |
| `minRelationsTotal` | pareil en comptant les morts |
| `causeContient` | la cause de la mort contient un de ces mots |
| `prenomCommencePar` | le prénom commence par un de ces textes |
| `minCausesDifferentes` | causes de mort différentes sur toutes les vies |
| `minTrophees` | nombre de trophées déjà obtenus |
| `shkurtaaa` | mode Shkurtaaa actif (`true`) ou coupé (`false`) |

### Bonus de départ

`titre`, `description` + au choix : `argent`, `sante`, `bonheur`, `intelligence`, `apparence`, `karma` (points ajoutés
à la naissance), `argentParents` (argent ajouté à chaque parent), `lienParents`, `ami` (un ami d'enfance dès la naissance).
Un bonus doit rester modeste : c'est une petite aide, pas le mode Shkurtaaa.

## Mode Shkurtaaa

Les trophées restent obtenables en Shkurtaaa, mais ils sont marqués « en Shkurtaaa » dans la vitrine. Quelques trophées
demandent `"shkurtaaa": false` (le milliard « légal », « Puriste »).

## Signaux nouveaux attendus par les trophées

Ces signaux ne sont pas encore dans le tableau de docs/REPERCUSSIONS.md. Chaque fil peut les émettre
(`Repercussions.signaler(...)` ou `Trophees.shared.signaler(...)`) :

- Famille : `jumeaux`, `petit_enfant`, `arriere_petit_enfant`, `jouer_heritier`, `reputation_legendaire`, `reputation_honteuse`,
  `testament`, `guerre_heritage`, `voisin_ami`, `voisin_conflit`, `fete_voisins`, `noel`, `cadeau_rate`
- École : `bac_rate`, `delegue`, `lycee_populaire`, `harcelement`, `conseil_classe_rate`, `oral_bluff`, `colle`, `renvoi_ecole`
- Travail, compétences, entreprise : `entreprise_creee`, `entreprise_faillite`, `entreprise_licorne`, `employes_100`,
  `competence_max`, `langue_apprise`
- Argent, placements : `placement`, `crypto_gain`, `crypto_ruine`, `bourse_krach`, `location_bien`, `gros_impots`
- Crime : `casier_efface`, `tig`, `chantage`, `chantage_subi`, `secret_revele`
- Santé : `psy`, `regime`, `vaccin`, `reanimation`
- Loisirs, voyages : `activite` (à chaque activité, en plus de son nom), `tour_du_monde`, `demenagement_etranger`, `vacances`
- Achats : `achat_bateau`, `achat_yacht`, `achat_bijou`, `achat_diamant`, `achat_avion`, `achat_ile`, `achat_chateau`,
  `achat_arnaque`, `saisie`, `revente`
- Célébrité, télé, téléphone : `jeu_tele`, `jeu_tele_gagne`, `telerealite`, `telerealite_gagne`, `buzz`, `bad_buzz`,
  `abonnes_million`, `paparazzi`, `autographe`, `musee`, `telephone`
- Monde, politique, rêves : `election_maire`, `election_depute`, `election_president`, `election_perdue`, `loi_absurde`,
  `scandale`, `manifestation`, `actu_monde`, `crise_economique`, `pandemie`, `reve_realise`, `reve_abandonne`,
  `evasion_ehpad`, `loto_ehpad`
- Animaux : `animal_adopte`, `animal_morsure`, `animal_exotique`, `animal_mort`, `animal_fugue`, `animal_celebre`
- Paranormal : `maison_hantee`, `voyante`, `ovni`, `enlevement_alien`, `tresor`, `exorcisme`, `deja_vu`, `malediction`, `sosie`

Tags de modules utilisés : `prison`, `licence_pilote`, `chauffard`. Drapeaux : `fume`, `casier_judiciaire`, `sevre_du_jeu`.

## Ajouter des trophées

Ajouter des objets dans un fichier de `Data/Trophees/` (ou un nouveau fichier `trophees_<theme>.json`), puis lancer
`python3 tools/validate_trophees.py`. Style : nom court et absurde, description d'une phrase qui dit clairement quoi faire,
humour décalé, jamais repris d'un autre jeu.
