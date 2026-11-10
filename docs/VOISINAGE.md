# Voisinage : voisins récurrents et vie de quartier

Chaque logement a ses voisins : le retraité curieux derrière son rideau, la famille bruyante, le voisin
mystérieux qui reçoit des colis lourds, la charmante voisine de palier… Ils vieillissent avec toi, se
souviennent de ce que tu leur as fait, déménagent, meurent, et sont remplacés par d'autres. Le quartier a
une **ambiance** (0 à 100) qui monte avec les fêtes des voisins et descend avec les guerres de haies.

Code : `FTCHTLife/Voisinage/`. Données : `FTCHTLife/Resources/Data/Voisinage/`.
Vérification : `python3 tools/validate_voisinage.py`.

## Ce que fait le module

- **À la naissance**, le joueur grandit dans le quartier de ses parents (appartement ou maison selon leur argent).
- **Quand il déménage** (module boutique : achat ou location), il arrive dans un nouveau quartier avec 2 à 5
  nouveaux voisins tirés selon le type de logement. Les anciens voisins restent dans les souvenirs.
- **Chaque année** : les voisins vieillissent, une phrase d'ambiance d'un voisin tombe souvent dans le journal,
  un voisin peut déménager ou mourir (remplacé l'année suivante), les charges de copro sont payées si le joueur
  est propriétaire en appartement, et un **événement de quartier** peut arriver (≈ 45 %).
- **Écran Voisins** : la liste des voisins avec leur lien, leur statut (voisin, ami, ennemi juré, amour de palier),
  ce qu'ils retiennent de toi, et des **interactions** (discuter, apporter un gâteau, se plaindre, espionner,
  draguer, faire une farce, appeler la police…) et des actions de **quartier** (fête des voisins, AG de copro,
  candidature au conseil syndical, voisins vigilants, concours de décorations).
- **Amours de palier** : un voisin peut devenir ton copain / ta copine (ajouté à tes relations).
  Un voisin ami peut devenir un vrai ami (ajouté à tes relations).

## Logements

`appartement` (immeuble : palier, ascenseur, syndic, colis, dégâts des eaux), `maison` (pavillon : haies,
parking, tondeuse, barbecue), `villa` (quartier chic : piscines, jalousie, gardiens, alarmes), `campagne`
(ferme, chalet : tracteurs, poules, voisins à 800 m), `caravane` (camping, mobil-home, péniche).

`VoisinageLogement.depuis("Studio en centre-ville")` devine le type à partir du nom ou de l'id d'un bien.

## Archétypes (`Data/Voisinage/Archetypes/*.json`)

```json
{
  "id": "retraite_curieux",
  "titreM": "le retraité curieux", "titreF": "la retraitée curieuse",
  "description": "…",
  "logements": ["appartement", "maison"],
  "ageMin": 66, "ageMax": 92, "weight": 3,
  "bruit": 15, "curiosite": 98, "gentillesse": 55, "celibat": 0.5,
  "phrases": ["Le rideau de {voisin_nom} a bougé trois fois…"]
}
```

Les titres portent l'article (`{voisin_qui}` → « la retraitée curieuse »). `bruit`, `curiosite`, `gentillesse`
(0 à 100) changent les chances des interactions. `celibat` : probabilité d'être célibataire.

Ids des archétypes : `retraite_curieux`, `famille_bruyante`, `voisin_mysterieux`, `etudiant_fetard`,
`couple_parfait`, `bricoleur_dimanche`, `commere`, `complotiste`, `sportif_matinal`, `dame_aux_chats`,
`musicien_rate`, `jardinier_obsessionnel`, `influenceur`, `ancien_militaire`, `nouveau_riche`,
`agriculteur_bourru`, `voisin_parfait`, `colocation_dj`, `prof_yoga`, `petite_vieille_gateaux`,
`fantome_boite`, `voisine_de_palier_charmante`, `camping_eternel`.

## Événements de quartier (`Data/Voisinage/Evenements/*.json`)

Même format que les événements du moteur (`docs/ARCHITECTURE.md`), plus trois blocs : `quartier`, `cible`
et `voisin`.

```json
{
  "id": "vsn_imm_0001",
  "minAge": 18, "maxAge": 99, "weight": 3, "unique": false,
  "conditions": { "tags": ["adult"] },
  "quartier": { "logements": ["appartement"], "chezParents": false },
  "cible": { "archetypes": ["etudiant_fetard", "colocation_dj"], "maxLien": 70 },
  "text": "3 h du matin. Chez {voisin}, {voisin_qui}, la musique fait trembler tes verres.",
  "choices": [
    {
      "label": "Frapper à sa porte",
      "outcomes": [
        { "chance": 2, "text": "{voisin} s'excuse et baisse le son. Un peu.",
          "effects": { "happiness": 2 }, "voisin": { "lien": 5 } },
        { "chance": 1, "text": "{voisin} t'invite à entrer. Tu ressors à 7 h avec un tatouage de dauphin.",
          "effects": { "happiness": 6, "health": -4 }, "voisin": { "lien": 15, "souvenir": ["a_fait_la_fete_avec_toi"] } }
      ]
    },
    {
      "label": "Appeler la police",
      "outcomes": [
        { "text": "La police vient. {voisin} sait que c'est toi.",
          "voisin": { "lien": -25, "statut": "ennemi", "signaux": ["voisin_ennemi"] } }
      ]
    }
  ]
}
```

### `quartier` (conditions de quartier, toutes optionnelles)

| Champ | Rôle |
|---|---|
| `logements` | types de logement acceptés (absent = tous) |
| `chezParents` | `true` = seulement chez les parents (enfance), `false` = seulement chez soi |
| `proprietaire` | `true` = le joueur est propriétaire (AG de copro, charges…) |
| `president` | `true` = le joueur est président(e) du conseil syndical |
| `minAmbiance`, `maxAmbiance` | ambiance du quartier (0-100) |
| `drapeaux`, `sansDrapeaux` | drapeaux du quartier requis / interdits (`guerre_des_haies`…) |
| `minCompteurs` | ex. `{ "colis_voles": 3 }` |
| `minAnnees` | années minimum à cette adresse |

### `cible` (le voisin concerné)

Si `cible` est présent, un voisin qui correspond est tiré au hasard ; sans voisin qui correspond, l'événement
ne peut pas arriver. Sans `cible`, l'événement concerne le quartier entier et les variables `{voisin…}` sont
interdites.

| Champ | Rôle |
|---|---|
| `archetypes` | un de ces archétypes (absent = n'importe lequel) |
| `statuts` | `neutre`, `ami`, `ennemi`, `amour` |
| `minLien`, `maxLien` | lien avec le joueur (0-100) |
| `celibataire` | voisin célibataire, adulte, âge proche du joueur (± 12 ans) |
| `opposite` | voisin de genre opposé au joueur |
| `gender` | `any`, `male`, `female` (genre du voisin) |
| `minAge`, `maxAge` | âge du voisin |
| `souvenirs`, `sansSouvenirs` | souvenirs que le voisin a / n'a pas (suites d'histoires) |

### `voisin` (effets, dans une issue ou à la racine d'un événement sans choix)

| Champ | Rôle |
|---|---|
| `lien` | variation du lien avec le voisin ciblé |
| `statut` | nouveau statut du voisin : `neutre`, `ami`, `ennemi`, `amour` |
| `souvenir`, `oublie` | souvenirs ajoutés / retirés au voisin ciblé (`a_vole_son_colis`) |
| `demenage` | le voisin déménage (remplacé l'année suivante) |
| `meurt` | le voisin meurt (rare) |
| `devientAmi` | le voisin est ajouté à tes relations comme ami(e) |
| `devientPartenaire` | le voisin devient ton copain / ta copine (mettre `"conditions": {"requiresPartner": false}` sur l'événement) |
| `lienTous` | variation du lien avec tous les voisins |
| `ambiance` | variation de l'ambiance du quartier |
| `drapeaux`, `retireDrapeaux` | drapeaux du quartier posés / retirés |
| `compteurs` | ex. `{ "colis_voles": 1 }` (ajoute) |
| `president` | `true` / `false` : le joueur devient / n'est plus président(e) du conseil syndical |
| `charges` | variation des charges annuelles de copro |
| `travaux` | travaux votés en AG (texte affiché dans l'écran Voisins) |
| `signaux` | signaux envoyés au module Répercussions (voir plus bas) |

Les `effects` restent ceux du moteur (`happiness`, `money`, `relationships`, `newFriend`, `death`…).

### Variables

Toutes celles du moteur (`{prenom}`, `{e}`, `{ville}`, `{partenaire}`, `{mere}`…) plus :

| Variable | Devient |
|---|---|
| `{voisin}` | prénom du voisin (« Josiane ») |
| `{voisin_nom}` | « Mme Rossi », « M. Gashi » |
| `{voisin_complet}` | « Josiane Rossi » |
| `{voisin_qui}` | titre avec article : « la retraitée curieuse » |
| `{voisin_age}` | âge du voisin |
| `{emplacement}` | où il habite : « sur ton palier », « dans la maison d'en face »… |
| `{il}`, `{Il}`, `{lui}` | il / elle, Il / Elle, lui / elle (pour le voisin) |
| `{ve}` | accord féminin pour le voisin (« parti{ve} ») |
| `{quartier}`, `{adresse}` | nom du quartier, adresse du joueur |
| `{syndic}` | nom du syndic de copro (appartement) |

`{e}` accorde le **joueur**, `{ve}` accorde le **voisin**. Même règle que `{e}` : accords simples seulement.

### Ids

`vsn_<thème>_NNNN`, uniques dans tout le jeu :
`vsn_imm` (immeuble, copro, syndic, bruit, colis), `vsn_ext` (maison, villa, campagne, caravane : haies, parking,
barbecue, piscine), `vsn_rel` (relations : arrivée, fête des voisins, amitiés, rivalités, amours de palier),
`vsn_enf` (enfance chez les parents), `vsn_his` (petites histoires en plusieurs étapes via les souvenirs).

## Interactions (`Data/Voisinage/Interactions/*.json`)

```json
{
  "id": "vsi_gateau",
  "titre": "Apporter un gâteau", "icone": "birthday.cake.fill",
  "description": "Le chemin le plus court vers le cœur d'un voisin.",
  "portee": "voisin", "minAge": 8, "cout": 15,
  "cible": { "statuts": ["neutre", "ami", "amour", "ennemi"] },
  "outcomes": [
    { "chance": 3, "trait": "gentillesse", "sens": "haut", "text": "{voisin} est ravi{ve}.", "voisin": { "lien": 10 } }
  ]
}
```

`portee` : `voisin` (bouton sur la fiche d'un voisin) ou `quartier` (bouton dans la section Quartier).
Chaque interaction est faisable une fois par an (par voisin pour `voisin`). Le poids d'une issue est
multiplié selon un trait du voisin (`trait` + `sens` : `haut` = plus le trait est fort, plus c'est probable)
et doublé si le lien est au moins `bonusLien`.

## Signaux pour le module Répercussions

Le module renvoie des signaux que le moteur transmet à `Repercussions.signaler` :
`demenagement`, `nouveau_voisin`, `voisin_ami`, `voisin_ennemi`, `voisin_mort`, `amour_de_palier`,
`fete_des_voisins`, `fete_des_voisins_ratee`, `colis_vole`, `guerre_des_haies`, `president_copro`,
`conflit_parking`, plus ceux écrits dans `voisin.signaux`.

## Tags pour les autres événements

`VoisinageMoteur.tags(etat)` : `vit_en_appartement`, `vit_en_maison`, `vit_en_villa`, `vit_a_la_campagne`,
`vit_en_caravane`, `chez_parents`, `proprietaire`, `voisin_ennemi`, `voisin_ami`, `amour_de_palier`,
`president_copro`, `quartier_sympa` (ambiance ≥ 70), `quartier_tendu` (ambiance < 30).

## Style

- Une à trois phrases, humour décalé, absurde, un peu méchant, jamais copié d'un autre jeu.
- Les voisins sont **récurrents** : on les nomme (`{voisin}`), on rappelle ce qu'ils sont (`{voisin_qui}`),
  et on utilise les souvenirs pour que les histoires aient une suite (le colis volé l'an dernier ressort).
- Toujours plusieurs choix aux conséquences différentes (gentil, mesquin, absurde), avec parfois une issue surprise.
- Les effets restent modestes (± 2 à 10 en stats, ± 5 à 25 en lien), sauf les grands moments.

## Branchement dans le moteur (fil moteur)

Le module compile seul et ne modifie aucun fichier du moteur. Tout passe par `FTCHTLife/Voisinage/GameEngine+Voisinage.swift`.
En attendant le branchement, l'état est gardé en mémoire (perdu à la fermeture de l'app).

1. **Sauvegarde** : `Joueur` reçoit `var voisinage: VoisinageEtat?` (optionnel, anciennes sauvegardes compatibles),
   puis dans `VoisinageStockage` (`Voisinage/VoisinageMoteur.swift`) les deux lignes marquées ⚙️ deviennent
   `return j.voisinage` et `j.voisinage = etat`.
2. **Année** : dans `vieillir()`, juste avant `tirerEvenements()` (après `joueur = j`) :
   ```swift
   voisinageAnnee()
   ```
   Le quartier vit (voisins qui vieillissent, partent, arrivent, charges, loyer, phrase d'ambiance) et un événement
   de quartier à choix peut s'afficher en premier ; les événements classiques suivent dans la file.
3. **Choix** : dans `choisir(_:)`, juste après `if let eff = issue?.effects { appliquer(eff, &j) }` :
   ```swift
   voisinageApresChoix(aff.evenement, choix: index, issue: issue, &j)
   ```
   (ne fait rien pour un événement qui n'est pas de catégorie `voisinage`).
4. **Écran** : un bouton « Voisins » (icône `house.and.flag.fill` ou `person.3.fill`) qui ouvre `VoisinageView()`
   avec `.environmentObject(engine)`, comme `ActivitesView`.
5. Optionnel :
   - fin de `nouvelleVie` : `voisinageNouvelleVie()` (sinon le quartier des parents est créé au premier anniversaire) ;
   - `tags(_:)` : `if let v = VoisinageStockage.lire(j) { t.formUnion(VoisinageMoteur.tags(v)) }` ;
   - Répercussions : `VoisinageStockage.signaler = { s, j in … Repercussions.signaler(s, age: j.age, etat: &e) … }`.

## Branchement avec la boutique (fil boutique)

Quand le joueur achète ou loue un logement :

```swift
engine.voisinageEmmenager(logement: .depuis(bien.nom), proprietaire: true)          // achat
engine.voisinageEmmenager(logement: .depuis(bien.nom), proprietaire: false)         // location gérée par la boutique
```

La boutique (PR #5) expose déjà un crochet `ShopHooks.emmenagement`, appelé à chaque achat, location ou
emménagement. Au branchement, une ligne suffit :

```swift
ShopHooks.emmenagement = { nom, _, proprio in engine.voisinageEmmenager(logement: .depuis(nom), proprietaire: proprio) }
```

L'écran Voisins propose aussi un déménagement simple en location (« Quitter le nid » / « Déménager ») avec un loyer
annuel prélevé par le module (`loyerAnnuel`). Si la boutique gère tous les logements, on pourra retirer ce bouton.
