# Vie au collège et au lycée

De 11 à 17 ans, l'école n'est plus juste une ligne dans le journal : le joueur a une **popularité**,
une **faveur des profs**, peut entrer dans un **groupe** (sportifs, intellos, rebelles, gamers, artistes,
stars du couloir), se présenter à l'**élection de délégué·e**, ramasser des **colles**, faire
**convoquer ses parents**, partir en **voyage scolaire**, passer l'**oral de français** (1re) et le
**grand oral** (terminale) en mini-jeu, et reçoit chaque fin d'année un **bulletin du conseil de classe**
avec des appréciations de profs.

Code : `FTCHTLife/VieScolaire/` (types préfixés `Scol`). Données : `FTCHTLife/Resources/Data/Scolarite/`.
Vérification : `python3 tools/validate_scolarite.py`.

## Calendrier

| Âge | Classe | Ce qui arrive |
|---|---|---|
| 11 | 6e | rentrée au collège, popularité de départ selon l'apparence |
| 12 | 5e | |
| 13 | 4e | voyage scolaire (collège) |
| 14 | 3e | brevet à la fin de l'année |
| 15 | 2nde | rentrée au lycée, la réputation se remet à moitié à zéro |
| 16 | 1re | voyage scolaire (lycée), oral de français |
| 17 | Terminale | grand oral (bonus sur le bac) |

Chaque année scolaire : 1 ou 2 situations (cartes à choix), une élection de délégué·e possible,
des actions (une fois par an chacune), et à la fin le conseil de classe.
Trois colles dans l'année = convocation des parents.

## Branchement (fil moteur)

Le module ne touche pas aux fichiers du moteur. Pour le brancher :

1. `Models/Models.swift`, dans `Joueur` : `var scolarite: ScolEtat?`
   puis au lancement (par ex. dans `GameEngine.init`) : `ScolStockage.chemin = \Joueur.scolarite`.
   Sans ça, l'état est gardé à part dans `UserDefaults` (une entrée par vie), ce qui marche aussi.
2. `GameEngine.vieillir()` :
   - garder `let actionsPassees = j.actionsAnnee` **avant** `j.actionsAnnee = []` ;
   - dans le calcul du bac (âge 18) : `let reussite = ... + scolBonusBac(j)` ;
   - après le `switch` de la scolarité : `lignes += scolPasserAnnee(&j, actionsPassees: actionsPassees)`.
3. `GameEngine.tags(_:)` : `t.formUnion(ScolRegles.tags(j))` (tags `scol_*`, voir plus bas).
4. `OccupationView`, dans la section de l'école (11 à 18 ans) :
   `NavigationLink { ScolVieView() } label: { ScolLienLabel() }` (affiche le nombre de choses à faire).
5. Facultatif, `MainView` : `.scolPresentationAuto()` sur la vue principale ouvre tout seul les cartes
   en attente (situations, convocation, voyage, oral) après « +1 an ».

## Tags ajoutés (`ScolRegles.tags`)

`scol_college`, `scol_lycee`, `scol_6e`, `scol_5e`, `scol_4e`, `scol_3e`, `scol_2nde`, `scol_1re`, `scol_terminale`,
`scol_populaire` (popularité ≥ 70), `scol_impopulaire` (< 30), `scol_chouchou` (faveur des profs ≥ 70),
`scol_bete_noire` (faveur < 30), `scol_delegue`, `scol_colle` (au moins une colle cette année),
`scol_sans_groupe`, `scol_groupe_<id>` (`sportifs`, `intellos`, `rebelles`, `gamers`, `artistes`, `stars`).

Ces tags marchent dans les conditions des événements classiques une fois le point 3 branché, et
dans toutes les données de ce module, en plus des tags du moteur (`male`, `siblings`, `smart`…).

## Formats des données

Chaque dossier de `Resources/Data/Scolarite/` contient des fichiers `.json` qui sont **des tableaux**.

### Effets (`effects`)

Les effets des événements (`happiness`, `health`, `smarts`, `looks`, `karma`, `money`, `relationships`,
`newFriend`) plus un sous-objet `"school"` :

| Clé | Rôle |
|---|---|
| `popularity` | variation de popularité (0-100) |
| `teachers` | variation de la faveur des profs (0-100) |
| `detention` | nombre de colles prises (1, 2…) |
| `summonParents` | `true` : convocation des parents |
| `grades` | bonus/malus sur la moyenne de l'année, en points sur 20 (ex. `0.5`, `-1`) |
| `joinGroup` | id du groupe rejoint |
| `leaveGroup` | `true` : le joueur quitte son groupe |
| `loseDelegate` | `true` : le joueur perd son mandat de délégué·e |

```json
"effects": { "happiness": 4, "school": { "popularity": 6, "detention": 1 } }
```

### Scène (situations, convocations, scènes de voyage)

Même forme qu'un événement à choix :

```json
{
  "id": "scl_0001",
  "minAge": 11, "maxAge": 14,
  "weight": 5,
  "unique": true,
  "conditions": { "gender": "any", "tags": ["scol_college"], "excludeTags": ["scol_populaire"] },
  "text": "En cours de {matiere}, {prof} te demande de lire ta rédaction à voix haute. Tu ne l'as pas écrite.",
  "choices": [
    { "label": "Improviser", "outcomes": [
      { "chance": 0.6, "text": "…", "effects": { "smarts": 2, "school": { "popularity": 5 } } },
      { "chance": 0.4, "text": "…", "effects": { "school": { "detention": 1, "teachers": -5 } } }
    ] }
  ]
}
```

`weight` (défaut 1), `unique` (défaut false), `conditions` (tous les champs optionnels) ;
2 à 4 choix, chaque choix a 1 à 3 issues dont les `chance` font 1.

Variables : celles des événements (`{prenom}`, `{nom}`, `{ville}`, `{mere}`, `{pere}`, `{parent}`, `{ami}`,
`{fratrie}`, `{partenaire}`, `{e}`) plus `{prof}` (nom d'un prof, ex. « Mme Vasseur »), `{matiere}`
(« maths », « français »…, en minuscules, la même que celle de `{prof}`), `{classe}` (« 4e B »),
`{groupe}` (« les gamers », ou « personne » sans groupe), `{camarade}` (prénom d'un·e élève de la classe).

- `Situations/` : préfixe `scl_`, situations de l'année (1 ou 2 tirées à la rentrée).
- `Convocations/` : préfixe `scv_`, scène jouée quand les parents sont convoqués. Âges 11-17.

### Groupes (`Groupes/`)

```json
{
  "id": "sportifs",
  "nom": "Les sportifs",
  "icone": "figure.run",
  "description": "…",
  "requis": { "stat": "health", "min": 55 },
  "accepte": "Texte quand le groupe t'accepte.",
  "refuse": "Texte quand il te refuse.",
  "quitte": "Texte quand tu pars.",
  "parAn": { "health": 3, "school": { "popularity": 3, "grades": -0.5 } }
}
```

`requis` est facultatif ; `stat` : `health`, `happiness`, `smarts`, `looks`, `karma` ou `popularity`.
`parAn` : effets appliqués à chaque fin d'année passée dans le groupe.

### Actions (`Actions/`)

Une action est faisable une fois par an depuis l'écran « Vie au bahut » ; résultat tiré au hasard.

```json
{
  "id": "sca_fayoter",
  "titre": "Fayoter",
  "icone": "hand.raised.fill",
  "description": "Porter le cartable du prof. Littéralement.",
  "groupe": null,
  "minAge": 11, "maxAge": 17,
  "conditions": { "tags": ["scol_lycee"] },
  "outcomes": [ { "chance": 0.7, "text": "…", "effects": { "school": { "teachers": 8, "popularity": -4 } } } ]
}
```

`groupe` : `null` = action ouverte à tous, sinon id du groupe qui la débloque.

### Voyages (`Voyages/`)

```json
{
  "id": "voy_berlin",
  "destination": "Berlin",
  "niveau": "college",
  "cout": 450,
  "intro": "Le voyage en 4e, c'est Berlin : 14 heures de car, 3 musées, 0 sommeil.",
  "retour": "Tu rentres avec un bonnet, une angine et des souvenirs pour la vie.",
  "scenes": [ { scène }, { scène }, { scène } ]
}
```

`niveau` : `college`, `lycee` ou `tous`. Le joueur vit 2 scènes tirées parmi `scenes` (ids `voy_<ville>_N`).
`cout` est payé par les parents si le joueur est mineur (rien n'est débité, mais un parent fauché râle).

### Oraux (`Oraux/`)

```json
{
  "id": "orf_001",
  "examen": "francais",
  "sujet": "Explique un poème sur un albatros qui n'arrive pas à marcher.",
  "intro": "Le jury te regarde comme un poisson regarde un vélo.",
  "questions": [
    { "question": "…", "reponses": [
      { "text": "…", "points": 5, "reaction": "Le jury hoche la tête. Un exploit." },
      { "text": "…", "points": 1, "reaction": "…" }
    ] }
  ]
}
```

`examen` : `francais` (oral de 1re, ids `orf_`) ou `grand_oral` (terminale, ids `ogo_`).
Exactement 3 questions, 3 ou 4 réponses chacune, `points` de 0 à 5, au moins une réponse à 4 ou 5.
Le joueur a 15 secondes par question. Note sur 20 = points + bonus de révision et d'intelligence.

### Textes (`Textes/`)

Tableau d'objets `{ "type": …, "text": … }` plus des champs selon le type :

| `type` | Champs | Utilisé pour |
|---|---|---|
| `appreciation` | `matiere` (ou `*`), `tranche` | appréciation d'une matière au bulletin |
| `comportement` | `trait` | phrase ajoutée à l'appréciation générale |
| `generale` | `mention` | appréciation générale du conseil de classe |
| `delegue` | | ce que le joueur délégué a dit au conseil |
| `colle` | | ce qui se passe pendant une colle |
| `prof` | `matiere` | nom d'un prof (« M. Lemoine ») |
| `adversaire` | | slogan d'un·e autre candidat·e à l'élection |
| `promesse` | `id`, `discours`, `bonus`, `realiste`, `bilan` | promesse de campagne |

- `matiere` : `francais`, `maths`, `histoire`, `anglais`, `svt`, `physique`, `eps`, `arts`, `musique`,
  `techno`, `philo`, `ses`, `espagnol`, `allemand`.
- `tranche` : `excellent` (≥ 16), `bien` (13 à 16), `moyen` (10 à 13), `faible` (7 à 10), `nul` (< 7).
- `trait` : `bavard`, `insolent`, `absent`, `chouchou`, `populaire`, `invisible`, `delegue`, `colles`,
  ou un id de groupe.
- `mention` : `felicitations`, `compliments`, `encouragements`, `rien`, `avertissement_travail`,
  `avertissement_conduite`.
- `promesse` : `text` est le libellé du bouton, `discours` la phrase dite en campagne, `bonus` l'effet
  sur les votes (-10 à +20), `realiste` (`true` si on peut la tenir), `bilan` la phrase de fin de mandat
  si `realiste` est faux (« Le toboggan entre le CDI et la cantine n'a jamais vu le jour. »).

Les appréciations n'utilisent pas `{e}` (le prof parle de l'élève à la 3e personne) : on écrit
« Élève agréable » et non « Agréable{e} ». Seules variables autorisées dans `Textes/` : `{prenom}`.
