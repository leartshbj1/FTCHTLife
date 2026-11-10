# Carrière politique

Module `FTCHTLife/Politique/` (types préfixés `Pol`), données dans `FTCHTLife/Resources/Data/Politique/`.
Validateur : `python3 tools/validate_politique.py`.

Le joueur adhère (ou non) à un parti, milite, lève des fonds, fait campagne, débat à la télé,
gagne ou perd des élections, puis gouverne : dossiers sur le bureau, scandales, sondages,
et surtout des **lois absurdes** qui changent les règles du jeu pour le reste de la vie.

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
   - Journal du monde : `PolMoteur.titresActualite(j.politique)` pour les titres, `PolMoteur.facteursPrix(j.politique)` et `PolMoteur.facteursSalaires(j.politique)` à passer en `extra:`.
   - Autres modules : `PolMoteur.regle("prison", j.politique)` renvoie le produit des multiplicateurs des lois en vigueur (1 par défaut) ;
     pour une règle additive (`ageRetraite`), `PolMoteur.regleSomme("ageRetraite", j.politique)` (0 par défaut).
   - Métiers : les métiers politiques du fil métiers (`attache_parlementaire`, `lobbyiste`…, liste dans `PolMoteur.metiersPolitiques`) donnent +2 d'influence par an.
   - Nécrologie : `PolMoteur.resumeCarriere(j.politique, genre: j.genre)` (« Ancien maire de Lyon, auteur de 3 lois absurdes »).
   - Profil : `j.politique?.mandat` pour afficher le mandat en cours.
