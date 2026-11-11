# Carrière politique

Module `FTCHTLife/Politique/` (types préfixés `Pol`), données dans `FTCHTLife/Resources/Data/Politique/`.
Validateur : `python3 tools/validate_politique.py`.

Le joueur adhère (ou non) à un parti, milite, lève des fonds, fait campagne, débat à la télé,
gagne ou perd des élections, puis gouverne : dossiers sur le bureau, scandales, sondages,
et des **lois** qui changent les règles du jeu pour le reste de la vie.

**Ton** : la politique est **sérieuse à 80 %** (vrais enjeux, dilemmes crédibles, conséquences réalistes)
et **drôle à 20 %** seulement (ironie sèche, jamais d'absurde pur). Tout nouveau contenu suit cette règle.

## Le parcours

| Poste | Comment | Durée | Indemnité/an |
|---|---|---|---|
| Conseiller·ère municipal·e | élection, dès 18 ans | 6 ans | 2 400 € |
| Adjoint·e au maire | nomination, quand on est conseiller | jusqu'à la fin du mandat | 14 000 € |
| Maire | élection ; avoir été conseiller, ou influence ≥ 40 | 6 ans | 38 000 € |
| Député·e | élection ; avoir été maire ou adjoint, ou influence ≥ 55 | 5 ans | 92 000 € |
| Ministre | nomination ; être ou avoir été député, ou influence ≥ 75, et avoir un parti | jusqu'au remaniement | 135 000 € |
| Président·e | élection en deux tours ; 35 ans, avoir été député ou ministre, influence ≥ 60, 500 parrainages | 5 ans, 2 mandats max | 190 000 € |

Jauges politiques (0-100) : **popularité**, **influence**, **casseroles** (soupçons), **loyauté** au parti.
Plus la **caisse de campagne** (euros) et les **parrainages**.

Une candidature dure jusqu'au passage d'année suivant : le résultat tombe alors dans le journal.
Pendant la campagne : meetings, porte-à-porte, affiches, promesses, coups bas, débat télévisé.

## Données

Chaque fichier contient un **tableau**. Sous-dossiers :

- `Partis/*.json` : `PolParti` (`id`, `nom`, `sigle`, `slogan`, `description`, `couleur` "#RRGGBB", `bord`, `bonusElection`, `cotisation`, `influence`).
- `Ministeres/*.json` : `PolMinistere` (`id`, `nom`, `description`). Ids : `interieur`, `economie`, `sante`, `education`, `culture`, `transports`, `ecologie`, `sports`, `agriculture`, `numerique`, `justice`, `affaires_etrangeres`, `logement`, `armees`.
- `Dossiers/*.json` : `PolDossier` (dossiers, scandales, débats, campagne, vie de parti).
- `Lois/*.json` : `PolLoi`.

### Dossiers (`PolDossier`)

```json
{
  "id": "dos_0001",
  "kind": "dossier",
  "postes": ["maire"],
  "ministere": null,
  "weight": 1,
  "unique": false,
  "title": "Le rond-point de la discorde",
  "text": "Les habitants de {ville} veulent une statue au milieu du nouveau rond-point…",
  "choices": [
    {
      "label": "Une statue de toi",
      "outcomes": [
        { "chance": 0.6, "text": "…", "effects": { "happiness": 5 }, "pol": { "popularite": -6, "casseroles": 4 } },
        { "chance": 0.4, "text": "…", "pol": { "popularite": 3 } }
      ]
    }
  ]
}
```

- `kind` et préfixe d'id : `dossier` → `dos_`, `scandale` → `sca_`, `debat` → `deb_`, `campagne` → `cam_`, `militant` → `mil_`.
  - `dossier` : arrive sur le bureau d'un élu (1 à 2 par an). Non traité avant le passage d'année = malus de popularité.
  - `scandale` : arrive quand les casseroles montent ou le karma baisse. `postes` : le poste occupé, ou `militant`.
  - `debat` : débat télévisé pendant une campagne ; `postes` = poste visé.
  - `campagne` : imprévu de campagne (tiré quand on fait une action de campagne) ; `postes` = poste visé.
  - `militant` : vie de parti, pour un membre sans mandat ; `postes` : `["militant"]`.
- `postes` : `militant`, `conseiller`, `adjoint`, `maire`, `depute`, `ministre`, `president` ou `any`.
- `ministere` : seulement pour un dossier de ministre lié à un ministère.
- 2 à 4 choix. `chance` = poids relatif.
- `effects` : effets classiques du moteur (`happiness`, `health`, `smarts`, `looks`, `karma`, `money`, `relationships`, `newFriend`, `death`), voir `docs/ARCHITECTURE.md`.
- `pol` : `popularite`, `influence`, `casseroles`, `loyaute` (points, ±40 max), `caisse` (euros), `parrainages`,
  `campagne` (bonus d'élection, pendant une candidature, environ -10 à +10), `finMandat` (texte : fin du mandat, ex. « démission forcée »),
  `ineligibilite` (années), `loi` / `abroger` (id de loi), `exclusionParti` (true).
- Variables : `{prenom}`, `{nom}`, `{ville}`, `{e}`, `{parti}` (nom du parti du joueur), `{poste}` (poste du joueur, en minuscules),
  `{adversaire}` (adversaire de campagne), `{ministere}` (nom du ministère), `{mere}`, `{pere}`, `{partenaire}`, `{ami}`.
  `{e}` seulement pour un accord simple du joueur (`élu{e}`, `content{e}`).

### Lois (`PolLoi`)

```json
{
  "id": "mun_0001",
  "niveau": "municipal",
  "ministere": null,
  "titre": "Arrêté anti-lundi",
  "description": "À {ville}, le lundi est remplacé par un deuxième dimanche.",
  "difficulte": 60,
  "adoption": { "popularite": 8, "influence": -2 },
  "annuel": { "happiness": 3, "money": -200 },
  "prix": { "nourriture": 1.05 },
  "salaires": { "tout": 0.97 },
  "regles": { "prison": 0.5 },
  "tag": "loi_anti_lundi",
  "headline": "{ville} supprime officiellement les lundis",
  "texteAdoption": "…",
  "texteRejet": "…"
}
```

- `niveau` : `municipal` (id `mun_`, votée par un maire ou un adjoint) ou `national` (id `nat_`, votée par un député, un ministre via son ministère, ou le président).
- `ministere` : le ministère qui peut la porter par décret (absent = seulement députés et président).
- `difficulte` 0-100 : plus c'est haut, plus le vote est dur à gagner.
- `adoption` : effets politiques immédiats (même clés que `pol`).
- `annuel` : effets appliqués **au joueur chaque année** tant que la loi est en vigueur (argent ±5 000 max).
- `prix` / `salaires` : multiplicateurs, mêmes clés que le Journal du monde (`docs/MONDE_FORMAT.md`).
  Prix : `immobilier`, `voitures`, `bateaux`, `avions`, `bijoux`, `voyages`, `nourriture`, `tech`, `luxe`, `animaux`, `sante`, `etudes`, `loisirs`, `vetements`, `tout`.
  Secteurs : `restauration`, `commerce`, `transport`, `batiment`, `beaute`, `securite`, `administration`, `medias`, `immobilier`, `tech`, `finance`, `arts`, `science`, `education`, `droit`, `sante`, `sport`, `politique`, `tout`.
- `regles` : autres règles du jeu, lues par les modules concernés.
  - appliquées par ce module : `elections` (bonus au score du joueur), `mandatsIllimites` (1 = plus de limite de 2 mandats présidentiels), `popularite` (dérive annuelle de popularité), `impots` (part du salaire annuel prélevée en plus, ex. 0.05).
  - pour les autres modules : `prison` (multiplicateur des peines), `amendes`, `retraite` (multiplicateur de pension), `ageRetraite` (années en plus ou en moins), `permis`, `mortalite`, `fertilite`, `etudes` (frais), `chomage`, `loyer`, `casino`, `animaux`.
- `tag` : ajouté aux tags du joueur tant que la loi est en vigueur (les événements peuvent l'utiliser).
- `headline` : titre de presse (Journal du monde) quand la loi passe.
- `monde` (optionnel) : id d'un flash du Journal du monde (`mon_NNNN`) à publier quand la loi passe.

## Branchement dans le moteur (fil principal)

1. `Joueur` : ajouter `var politique: PolEtat?` (optionnel, les vieilles sauvegardes restent valides).
2. `GameEngine.vieillir()`, avant `j.journal.append(Annee(...))` :
   ```swift
   var pol = j.politique ?? PolEtat()
   lignes += PolMoteur.passerAnnee(&j, &pol)
   j.politique = pol
   ```
3. `GameEngine.tags(_:)` : `t.formUnion(PolMoteur.tags(j.politique))` (tags `pol_militant`, `pol_elu`, `pol_candidat`, `pol_<poste>`, `pol_scandale`, plus les tags des lois en vigueur).
4. Interface : un bouton « Politique » (onglet ou ligne dans Occupation, dès 16 ans) qui ouvre
   `PolitiqueView(etat: \.politique)`. La vue lit et écrit l'état par ce chemin, via `engine.modifier`.
5. Optionnel :
   - Journal du monde (après `passerAnnee`) : `PolMoteur.titresActualite(j.politique)` pour les titres (`MondeJournalView(titresExternes:)`),
     `PolMoteur.flashsMonde(j.politique)` : ids de flashs à publier avec `MondeJournal.forcer(id:etat:age:tagsJoueur:)`, `PolMoteur.facteursPrix(j.politique)` et `PolMoteur.facteursSalaires(j.politique)` à passer en `extra:`.
   - Autres modules : `PolMoteur.regle("prison", j.politique)` renvoie le produit des multiplicateurs des lois en vigueur (1 par défaut) ;
     pour une règle additive (`ageRetraite`), `PolMoteur.regleSomme("ageRetraite", j.politique)` (0 par défaut).
   - Métiers : les métiers politiques du fil métiers (`attache_parlementaire`, `lobbyiste`…, liste dans `PolMoteur.metiersPolitiques`) donnent +2 d'influence par an.
   - Nécrologie : `PolMoteur.resumeCarriere(j.politique, genre: j.genre)` (« Ancien maire de Lyon, auteur de 3 lois »).
   - Profil : `j.politique?.mandat` pour afficher le mandat en cours.

## Deuxième couche : politique très poussée

### Nouveaux postes (`postes` des dossiers)

| Poste (id) | Comment | Lois |
|---|---|---|
| `conseillerRegional` | élection directe, dès 18 ans | aucune |
| `presidentRegion` | élu par les conseillers régionaux (il faut être conseiller régional) | `regional` |
| `senateur` | élu par les grands électeurs (24 ans, avoir été maire ou élu régional, ou influence ≥ 60) | `national` |
| `presidentAssemblee` | élu par les députés (il faut être député) | `national` |
| `premierMinistre` | nomination | `national` |
| `commissaire` | nomination à l'Union des Pays Voisins (après ministre ou Premier ministre) | `international` |
| `secretaireGeneral` | élu par les pays des Nations Pas Très Unies (après président ou commissaire) | `international` |

Autres valeurs de `postes` : `chef_parti` (le joueur dirige un parti), `ancien` (plus de mandat, mais a été au moins maire).

### Nouveaux `kind` de dossiers

- `lobby` (id `lob_`) : un lobby fait une offre à un élu (argent, voyage, cadeau) contre une faveur. Postes : les postes d'élus.
- `proces` (id `pro_`) : procès après une mise en examen. Postes : `any`. Les pires issues : `finMandat`, `ineligibilite`, grosse amende.
- `crise` (id `cri_`) : crise nationale à gérer (grève, catastrophe, panne, crise diplomatique). Postes : `president`, `premierMinistre`, `ministre`.
- `parti` (id `par_`) : vie interne quand on dirige un parti. Postes : `["chef_parti"]`.
- `apres` (id `apr_`) : la vie d'ancien élu (mémoires, plateaux télé, conférences, retour raté). Postes : `["ancien"]`.

### Nouveaux niveaux de lois

`regional` (id `reg_`, votées par un président de région) et `international` (id `int_`, portées par un commissaire ou le secrétaire général).

### Nouvelles clés `pol` (et `adoption` des lois)

- `segments` : opinion de six groupes d'électeurs, ±20 max : `{"jeunes": 5, "retraites": -8, "ruraux": 0, "urbains": 3, "patrons": -4, "fonctionnaires": 6}`.
- `pays` : indicateurs du pays : `dette` (points de PIB, ±15), `chomage` (points, ±3), `croissance` (points, ±2), `securite` (±15), `moral` (±15).
- `mobilisation` : colère sociale (grèves, manifestations), ±40.
- `majorite` : sièges du camp du joueur à l'Assemblée, en points, ±40.
- `rival` : rancune du rival principal envers le joueur, ±40.

Variables en plus : `{rival}` (un rival du joueur), `{pm}` (le Premier ministre).

### Systèmes de la deuxième couche (code : `PolProfond.swift`)

- **Pays** (`PolEtat.pays`) : croissance, chômage, dette, moral, sécurité évoluent chaque année. Quand le joueur gouverne (ministre, Premier ministre, président), le bilan change sa popularité.
- **Électorat** (`PolEtat.segments`) : six groupes ; une élection directe compte moitié popularité, moitié groupes pondérés (retraités 24 %, urbains 22 %, fonctionnaires 19 %, ruraux 16 %, jeunes 12 %, patrons 7 %), plus les affinités du parti (`segments` dans `Partis/*.json`).
- **Élections indirectes** (président de région, sénateur, président de l'Assemblée, secrétaire général) : le réseau compte plus que la popularité.
- **Rivaux** (`PolEtat.rivaux`, 5 max) : reviennent comme adversaires, gardent rancune, peuvent faire fuiter des affaires. Actions : réconciliation, alliance, sortir un dossier.
- **Parti** : rang (adhérent, cadre, bureau national, chef), courants, congrès, investiture et primaire (sans investiture = dissidence et exclusion), fonder son propre parti (il prend de la force à chaque élection gagnée).
- **Équipe** : directeur de campagne, plume, conseiller com, trésorier, garde du corps ; salaires annuels ; un membre peu loyal peut trahir.
- **Gouvernement** : le joueur président nomme un Premier ministre (5 profils), peut organiser un référendum, dissoudre (cohabitation possible), passer une loi en force (49-trois-quarts, motion de censure). Grève générale si la colère sociale dépasse 60. Destitution possible.
- **Après-politique** : mémoires, conférences, chroniqueur télé, conseil d'administration, fondation ; dossiers `apres`.
- **Dynastie** : `PolMoteur.heritage(j.politique)` donne un `PolEtat` de départ pour un enfant qui reprend la vie (influence selon le rang atteint).
- Tags en plus : `pol_chef_parti`, `pol_gouverne`, `pol_ancien`.

## Soirée électorale

Chaque élection (municipale, régionale, législative, présidentielle, sénatoriale, perchoir, présidence de région,
secrétariat général) est tranchée au passage d'année par `PolMoteur.resoudreElection`, qui garde le résultat dans
`PolEtat.soiree` (`PolSoiree` : poste, victoire, scores, premier tour, participation, adversaire).
Au début de l'année suivante, `GameEngine.modulesAvantTirage` appelle `PolMoteur.soireeElectorale` et place en tête
de file un événement à choix `pol_soiree_victoire` ou `pol_soiree_defaite` (scène, scores, participation, réactions).
Le choix applique ses effets classiques, puis `modulesApresChoix` appelle `PolMoteur.apresChoixSoiree` pour
les effets politiques (popularité, influence, loyauté). Cet événement a la priorité maximale dans `limiterFileEvenements`.

## Selon le pays

La politique suit le pays où vit le personnage (`j.etatExpat.paysActuel`, module « vivre à l'étranger »).
Code : `Politique/PolSysteme.swift`. Données : `Data/Politique/Systemes/systemes.json` (26 pays, mêmes ids
que le module étranger).

### Format d'un système (`PolSysteme`)

| Champ | Rôle |
|---|---|
| `id`, `regime`, `resume` | `semi_presidentiel`, `presidentiel`, `parlementaire`, `monarchie_parlementaire`, `monarchie_executive`, `directorial`, `parti_unique` |
| `chefExecutif` | `president`, `premierMinistre` ou `ministre` (collège, Suisse). Si ce n'est pas `president`, le président est symbolique. |
| `chefEtat`, `pays`, `capitale`, `palais`, `siegeGouvernement`, `parlement`, `chambreHaute`, `union` | Textes des institutions. Les listes ont 3 formes : nom, « à … », « de … ». `union` = [nom, siège] ou null (pas de commissaire). |
| `postes` | Noms locaux `{poste: [masculin, féminin]}`. Absent = nom français. |
| `absents` | Postes qui n'existent pas dans ce pays (cachés, candidature refusée). |
| `election` | `{poste: "directe" | "indirecte" | "nomination"}`. Absent = règle française. |
| `durees`, `agesMin`, `mandatsMax` | Par poste. Absent = valeur française. |
| `deuxTours`, `passerEnForce`, `referendum`, `dissolution`, `coalitions`, `electionsControlees`, `partiUnique`, `parrainages` | Règles de la Constitution. `passerEnForce` = nom de la procédure (« l'article 49.3 », « un décret-loi ») ou null. |

### Variables de texte

Dans les dossiers, lois et textes du moteur : `{pays}`, `{au_pays}`, `{du_pays}`, `{capitale}`, `{chef_etat}`,
`{palais}`/`{au_palais}`/`{du_palais}`, `{siege_gouv}`/`{au_siege_gouv}`/`{du_siege_gouv}`,
`{parlement}`/`{au_parlement}`/`{du_parlement}`, `{senat}`/`{au_senat}`/`{du_senat}` (chambre haute, sinon le
parlement), `{union}`, `{siege_union}`. Elles commencent par un article minuscule : jamais en début de phrase.

### Champ `pays`

Sur un parti, une loi ou un dossier : `"pays": ["us", "gb"]`. Un parti sans `pays` est français ; une loi ou un
dossier sans `pays` sort partout. Hors de France, les dossiers propres au pays ont un poids ×4.

### Règles du moteur

- Candidature : le poste doit exister et être électif ; il faut la nationalité (ou être citoyen européen pour les
  municipales dans l'Union) ; âge et nombre de mandats du pays ; parrainages seulement si `parrainages`.
- Régime parlementaire (`premierMinistre: "directe"`) : le chef d'un parti se présente aux législatives ; s'il
  arrive en tête, il devient chef du gouvernement avec `majorite` = part des sièges. Sans majorité absolue dans
  un pays de coalitions, un dossier `coalition` (préfixe `coa_`) arrive.
- Président symbolique : pas de nomination de Premier ministre ni de gouvernement à diriger.
- Parti unique : candidatures réservées aux membres, pas de parti personnel, élections par délégués.
- `electionsControlees` : gros bonus pour le grand parti au pouvoir, malus pour les autres.
- Changement de pays (`verifierPays`, au passage d'année) : mandat terminé, parti quitté s'il n'existe pas dans
  le nouveau pays, lois, dossiers, rivaux et réseau remis à zéro ; le passé (titres, postes occupés) reste.
