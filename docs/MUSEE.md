# Nécrologie et musée des vies

Module autonome dans `FTCHTLife/Museum/` (types préfixés `Musee…` / `Necro…`).
Données dans `FTCHTLife/Resources/Data/Museum/` : `surnoms*.json` et `necro_*.json`.
Validateur : `python3 tools/validate_musee.py`.

À la mort, le jeu génère une nécrologie de journal à partir de la vie (titre, paragraphes,
épitaphe) avec un surnom absurde, puis range la vie dans le **musée**, consultable depuis
l'accueil. Le score « vie réussie » (Rêves de vie) s'y affiche s'il est fourni.

## Branchement (fil moteur)

```swift
// DeathView : en haut du ScrollView / VStack
NecrologieView(joueur: j, dernierMetier: j.dernierEmploi?.titre, scoreVieReussie: nil) // dernierEmploi : voir plus bas

// N'importe où (accueil, nouvelle vie, réglages) :
Button("Musée des vies") { montrerMusee = true }
    .sheet(isPresented: $montrerMusee) { MuseeView() }
```

- La nécrologie fait 6 à 8 paragraphes : mettre le contenu de `DeathView` dans un `ScrollView`.
- `MuseeView` a sa propre `NavigationStack` : la présenter en `.sheet`, pas dans un `NavigationLink`.
- `NecrologieView` enregistre la vie dans le musée à son apparition (une seule fois par vie :
  l'identifiant est l'`id` de la première année du journal) et affiche la nécrologie.
- `MuseeStore.shared.enregistrer(joueur:dernierMetier:scoreVieReussie:)` fait la même chose sans
  interface, si on préfère l'appeler depuis `GameEngine.mourir`.
- `mourir` vide `emploi` : pour que la nécrologie parle du métier, il faut garder le titre
  (par ex. un champ `dernierEmploi` dans `Joueur`, rempli avant `j.emploi = nil`).
- Score « vie réussie » : le module Rêves de vie (`FTCHTLife/Dreams/`) expose
  `RevesMoteur.scoreVieReussie(j.reves, joueur: j) -> Int` (0 à 100). Le passer en `scoreVieReussie:`
  une fois `Joueur.reves` branché (voir docs/reves-format.md sur sa branche).
- Carte de vie à partager (`FTCHTLife/CarteVie/`) : `CarteVieBouton(joueur: j, surnom: MuseeStore.shared.enregistrer(joueur: j).surnom)`
  se pose sous `NecrologieView`. Même surnom garanti (enregistrement idempotent).
- Sauvegarde du musée : `Documents/ftchtlife-musee.json`, indépendante de la vie en cours
  (`effacerVie()` ne la touche pas).

## Format des surnoms (`surnoms*.json`)

```json
[
  { "id": "sur_0001", "text": "le Roi du canapé", "textFemale": "la Reine du canapé",
    "weight": 1, "conditions": { "tags": ["chomeur"], "excludeTags": [] } }
]
```

Le surnom s'affiche entre guillemets : `Jean « le Roi du canapé » Dupont`. Il commence en minuscule
(article compris) sauf nom propre. `textFemale` est optionnel (sinon `text` sert aux deux genres).

## Format des phrases (`necro_*.json`)

```json
[
  { "id": "nec_intro_0001", "section": "intro",
    "text": "{prenom} {nom}, {age} ans, a quitté {ville} pour de bon.",
    "textFemale": null, "weight": 1,
    "conditions": { "tags": ["vieux"], "excludeTags": ["riche"], "minAge": 65, "maxAge": null } }
]
```

Sections, dans l'ordre d'affichage :
`titre` (manchette du journal, courte), `intro`, `enfance`, `etudes`, `carriere`, `argent`, `amour`,
`famille`, `caractere`, `fin` (comment c'est fini, utilise `{cause}`), `epitaphe` (gravée sur la tombe, une phrase).

Le générateur prend une phrase par section ; parmi les sections du milieu (`enfance` à `caractere`)
il en garde au plus 4. Une phrase avec des `tags` requis pèse plus lourd (poids × (1 + nombre de tags)),
donc les phrases précises passent devant les génériques. Chaque section doit avoir au moins une phrase
sans condition pour `titre`, `intro`, `fin` et `epitaphe`.

### Tags (calculés à la mort)

| Tag | Sens |
|---|---|
| `male`, `female` | genre |
| `bebe` (<3 ans), `enfant` (3-12), `ado` (13-17), `jeune` (18-39), `adulte` (40-64), `vieux` (65-89), `tres_vieux` (90+), `centenaire` (100+) | âge à la mort |
| `endette` (<0 €), `fauche` (<1 000 €), `aise` (≥100 000 €), `riche` (≥1 M€), `milliardaire` (≥1 Md€) | fortune finale |
| `sans_diplome` (adulte sans bac), `bachelier` (bac exactement), `diplome_sup` (licence ou plus), `doctorat` | diplôme |
| `filiere_medecine`, `filiere_droit`, `filiere_informatique`, `filiere_commerce`, `filiere_arts`, `filiere_sciences` | filière du diplôme |
| `travailleur` (avait un métier à la mort), `chomeur` (18-64 sans métier ni études), `retraite` (65+ sans métier), `etudiant` | occupation |
| `intelligent`, `bete`, `beau`, `moche`, `gentil`, `mechant`, `heureux`, `deprime`, `malade` | stats (≥75 ou ≤25 ; `malade` = santé <30) |
| `populaire` (≥5 amis), `solitaire` (0 ami, 13 ans+), `en_couple`, `celibataire` (18+ sans partenaire), `ex_nombreux` (≥3 ex) | social |
| `parent`, `famille_nombreuse` (≥4 enfants), `fratrie`, `enfant_unique`, `orphelin` (les deux parents morts) | famille |
| `mort_naturelle`, `mort_maladie`, `mort_absurde` | type de mort |
| `vie_reussie` (score ≥75), `vie_ratee` (score ≤25) | seulement si le score Rêves de vie est fourni |

### Variables

`{prenom}`, `{nom}`, `{surnom}`, `{ville}`, `{age}`, `{cause}` (ex. « de vieillesse, dans son sommeil » :
s'écrit après « est mort{e} »), `{metier}` (en minuscules), `{fortune}`, `{diplome}`, `{filiere}`,
`{nbAmis}`, `{nbEnfants}`, `{nbEx}`, `{partenaire}`, `{mere}`, `{pere}`,
`{e}` (« e » au féminin), `{il}` / `{Il}` (il/elle), `{le}` (le/la).
N'utilisez `{metier}` qu'avec le tag `travailleur`, `{partenaire}` qu'avec `en_couple`, `{filiere}` qu'avec `diplome_sup`.

### Ton

Humour décalé, absurde, jamais méchant envers un groupe réel. Textes originaux, en français, tutoiement
interdit ici (c'est un journal : 3e personne). Pas de copie d'un autre jeu.
