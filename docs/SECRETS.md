# Secrets et chantage

Tes proches ont des secrets (une liaison, une dette cachée, un enfant caché, un passé en prison…). Toi aussi.
On les découvre par hasard (indices dans le journal, puis découverte) ou en **fouillant** les affaires de quelqu'un.
Une fois un secret connu, on peut :

- **le garder** pour soi (et peut-être le ressortir au **pire moment** : un mariage, un repas de Noël, un enterrement…) ;
- **dire à la personne qu'on sait** (elle peut être reconnaissante… ou gênée) ;
- **tout révéler** ;
- **la faire chanter** : elle te verse une « pension » chaque année, jusqu'au jour où elle se révolte (elle avoue d'elle-même ou te dénonce).

L'inverse arrive aussi : un proche découvre **ton** secret. S'il t'aime bien, il se tait. Sinon il te fait chanter :
tu peux **payer** (le tarif monte), **refuser** (il balance tout), **avouer toi-même** (moins grave) ou
**contre-menacer** si tu connais un de ses secrets à lui (équilibre de la terreur).

Code : `FTCHTLife/Secrets/`. Données : `FTCHTLife/Resources/Data/Secrets/`. Vérification : `python3 tools/validate_secrets.py`.

## Données

Trois sous-dossiers, chacun contenant des fichiers JSON qui sont des **tableaux** :

| Dossier | Type Swift | Contenu |
|---|---|---|
| `Secrets/Modeles/` | `SecretModele` | les secrets possibles |
| `Secrets/Moments/` | `SecretMoment` | les « pires moments » pour révéler un secret gardé |
| `Secrets/Textes/` | `SecretTextes` | textes génériques (fouille, chantage, aveu…) par clé |

### Un secret (`Secrets/Modeles/*.json`)

```json
{
  "id": "sec_0001",
  "titre": "Liaison cachée",
  "gravite": 4,
  "porteurs": ["pere", "mere", "partenaire", "ex", "ami", "frere", "soeur", "enfant", "joueur"],
  "minAge": 25,
  "maxAge": null,
  "genre": "any",
  "poids": 1,
  "complice": true,
  "blesse": ["partenaire"],
  "signalRevelation": "tromperie_decouverte",
  "signaux": ["tromperie"],
  "resume": "{cible} a une liaison avec {complice}, rencontré{eX} au cours de salsa.",
  "indices": ["{Cible} rentre tard en sentant un parfum qui n'est pas le sien."],
  "decouvertes": ["En empruntant le téléphone de {cible}, tu tombes sur 412 messages à « Mon petit cornichon ». Ce n'est pas toi."],
  "revelations": ["Toute la famille sait maintenant pour {complice}. {Cible} a changé de numéro."],
  "chantages": ["{Cible} est devenu{eC} tout blanc{heC} et t'a tendu {montant} sans un mot."],
  "resumeJoueur": "Tu as une liaison avec {complice}.",
  "naissances": ["Tu as commencé à voir {complice} en cachette. Tu dis que tu vas « à la piscine »."],
  "demasques": ["{Cible} t'a vu{e} sortir d'un hôtel avec {complice}."],
  "revelationsJoueur": ["Tout le monde sait pour {complice}. Même la boulangère te regarde de travers."]
}
```

| Champ | Rôle | Défaut |
|---|---|---|
| `id` | unique, `sec_NNNN` | obligatoire |
| `titre` | nom court affiché dans les listes (« Dette cachée ») | obligatoire |
| `gravite` | 1 (gênant) à 5 (explosif). Règle les montants du chantage et les dégâts d'une révélation | obligatoire |
| `porteurs` | qui peut avoir ce secret : `mere`, `pere`, `frere`, `soeur`, `ami`, `partenaire`, `enfant`, `ex`, et `joueur` (toi) | obligatoire |
| `minAge`, `maxAge` | âge du porteur | 0 / aucun |
| `genre` | genre du porteur : `any`, `male`, `female` | `any` |
| `poids` | fréquence relative | 1 |
| `complice` | `true` : un prénom au hasard remplace `{complice}` | false |
| `blesse` | types de proches **du joueur** que la révélation d'un secret **du joueur** blesse beaucoup plus (`partenaire`, `mere`, `pere`, `parent`, `fratrie`, `ami`, `enfant`) | aucun |
| `signalRevelation` | signal de répercussion émis quand ce secret est révélé (en plus de `secret_revele` / `secret_expose`) | aucun |
| `signaux` | signaux du jeu qui **créent** ce secret chez le joueur (ex. `tromperie`, `prison_sortie`) | aucun |
| `seulementSignal` | `true` : ce secret du joueur n'apparaît jamais au hasard, seulement via `signaux` | false |

Textes pour un secret d'un **proche** (obligatoires si `porteurs` contient un autre type que `joueur`) :
`resume` (une phrase, affichée dans le carnet), `indices` (≥ 2, rumeurs dans le journal avant la découverte),
`decouvertes` (≥ 2, comment tu l'apprends), `revelations` (≥ 2, ce qui se passe quand tu balances),
`chantages` (≥ 1, la personne accepte de payer).

Textes pour un secret **du joueur** (obligatoires si `porteurs` contient `joueur`) :
`resumeJoueur` (« Tu as… »), `naissances` (≥ 1, le secret commence, journal), `demasques` (≥ 1, un proche le découvre),
`revelationsJoueur` (≥ 1, tout le monde l'apprend).

### Un pire moment (`Secrets/Moments/*.json`)

```json
{
  "id": "mom_0001",
  "porteurs": ["pere", "mere", "frere", "soeur", "ami", "enfant"],
  "minAge": 18,
  "multiplicateur": 2.0,
  "texte": "C'est le mariage de {cible}. Le micro arrive dans tes mains pour « un petit mot ». Tu connais son secret : {resume}",
  "resultats": ["Tu as tout balancé entre la pièce montée et le lâcher de colombes. Les colombes sont parties plus vite que les invités."]
}
```

`porteurs`, `minAge`, `maxAge` : comme ci-dessus (âge du porteur). `multiplicateur` (1 à 3) : amplifie les dégâts
et la honte. `texte` : la carte (mettre `{resume}` pour rappeler le secret). `resultats` (≥ 1) : quand tu balances.

### Textes génériques (`Secrets/Textes/*.json`)

```json
[{ "cle": "fouille_rien", "textes": ["Tu as fouillé les tiroirs de {cible}. Tu as trouvé 14 élastiques et une dent de lait. Pas la sienne."] }]
```

Clés utilisées par le code (chaque clé ≥ 3 textes) :

| Clé | Quand |
|---|---|
| `fouille_rien` | fouille sans rien trouver |
| `fouille_pris` | fouille, et la personne te surprend |
| `garder` | tu décides de garder le secret |
| `dire_bien` / `dire_mal` | tu dis à la personne que tu sais : elle est reconnaissante / gênée |
| `reveler_soi` | phrase d'ouverture quand tu balances le secret d'un proche (suivie du texte du secret) |
| `chantage_refus_aveu` | la personne refuse de payer et avoue d'elle-même |
| `chantage_refus_denonce` | la personne refuse et te dénonce |
| `chantage_versement` | versement annuel reçu (`{montant}`) |
| `chantage_revolte` | la personne arrête de payer et avoue tout |
| `chantage_fin` | tu arrêtes le chantage par bonté |
| `taire` | pire moment : tu choisis de te taire |
| `proche_se_tait` | un proche découvre ton secret mais se tait |
| `proche_chantage` | carte : un proche te fait chanter (`{montant}`, `{resume}`) |
| `proche_augmente` | carte : le maître chanteur augmente son tarif |
| `payer` | tu paies |
| `paiement_annuel` | versement annuel payé au maître chanteur |
| `refuser` | tu refuses de payer, il balance |
| `avouer` | tu avoues toi-même |
| `contre_ok` / `contre_rate` | contre-menace réussie / ratée |
| `pas_les_moyens` | tu ne peux plus payer, il balance |
| `chanteur_mort` | ton maître chanteur est mort |
| `victime_morte` | la personne que tu faisais chanter est morte |

### Variables dans les textes

- `{cible}` : prénom du porteur du secret, ou de la personne qui te fait chanter. `{Cible}` : idem (pour le début de phrase, c'est le même prénom).
- `{designation}` / `{Designation}` : « ta mère », « ton ami » / « Ta mère », « Ton ami ».
- `{il}` / `{Il}` : il ou elle (la cible). `{le}` : le ou la. `{eC}` : « e » si la cible est une femme (`content{eC}`). `{heC}` : « he » si la cible est une femme (`blanc{heC}` → blanche).
- `{complice}` : prénom du complice. `{eX}` : « e » si le complice est une femme.
- `{montant}` : montant du chantage (déjà formaté, « 3'000 € »).
- `{resume}` : la phrase `resume` du secret (dans les moments et la carte de chantage). Dans la carte de chantage, c'est `resumeJoueur`.
- `{titre}` : titre du secret, en minuscules.
- Variables du joueur : `{prenom}`, `{nom}`, `{ville}`, `{e}` (accord du joueur), `{mere}`, `{pere}`, `{partenaire}`.

## Règles du jeu

- Chaque année, un proche vivant a ~3 % de chances d'avoir un nouveau secret (2 au plus). Toi ~4 % dès 14 ans (4 au plus en cours).
- Secret inconnu : 25 % de chances par an d'un indice dans le journal. Au 3e indice (ou 8 % de chance chaque année),
  tu le découvres : carte avec **Garder**, **Lui dire que tu sais**, **Tout révéler**, **Faire chanter** (16 ans et plus).
- **Fouiller** (une fois par an et par proche, section Secrets de la fiche d'un proche) : 45 % (+ intelligence) de trouver son secret
  s'il en a un ; sinon 25 % qu'on trouve quand même quelque chose ; 20 % de se faire prendre (relation −15).
- Un secret gardé peut ressortir : 20 % par an d'une carte « pire moment » (au plus une par an). Révéler à ce moment
  multiplie les dégâts.
- Chantage : montant selon la gravité (300 € à 20 000 €/an, plus si la personne est riche, argent de poche pour un mineur).
  Chaque année : versement, puis risque de révolte (10 % + 5 % par année de chantage) : aveu ou dénonciation
  (karma −15, amende, signal `chantage_denonce`).
- Ton secret : chaque année ~3 % × gravité qu'un proche le découvre. Relation ≥ 50 : il se tait. Sinon, souvent, chantage :
  tu paies chaque année ; 30 % de chances par an qu'il augmente le tarif (nouvelle carte). Pas les moyens = il balance.
- Au plus 2 cartes de secrets par an.

## Signaux émis (pour les répercussions)

`secret_decouvert`, `secret_revele` (tu balances le secret d'un proche), `secret_garde`, `chantage` (tu fais chanter),
`chantage_echoue`, `chantage_denonce`, `chantage_fin`, `victime_chantage`, `secret_expose` (ton secret est révélé),
`aveu`, `contre_menace`, plus le `signalRevelation` du secret.

## Tags (pour `conditions.tags` des événements)

`secret` (tu as un secret pas encore révélé), `maitre_chanteur` (tu fais chanter quelqu'un), `victime_chantage`
(quelqu'un te fait chanter), `secret_expose` (un de tes secrets a éclaté), `connait_secret` (tu connais le secret d'un proche).

## Branchement dans le moteur (fil moteur)

1. `Joueur` : `var secrets: SecretsEtat?` (déjà ajouté par ce module ; optionnel, les anciennes sauvegardes restent lisibles).
2. Signaux vers les répercussions (une seule fois, par ex. dans `init()` du moteur) :
   ```swift
   Secrets.surSignal = { signal, j in
       var etat = j.repercussions ?? RepercussionsEtat()
       Repercussions.signaler(signal, age: j.age, etat: &etat)
       j.repercussions = etat
   }
   ```
   Toutes les actions du module passent par là (les résultats contiennent aussi `signaux`, pour info).
3. `vieillir()`, juste avant `tirerEvenements()` :
   ```swift
   let annee = Secrets.passerAnnee(joueur: &j)
   annee.lignes.forEach { ajouterLigne(&j, $0) }
   joueur = j
   fileEvenements += annee.evenements.map { EvenementAffiche(evenement: $0, texte: $0.text) }
   ```
   Les cartes ont déjà leurs textes remplis. Elles passent avant les événements aléatoires (au plus 2 par an).
4. `choisir(_:)`, juste après le `guard`, pour une carte de secret :
   ```swift
   if Secrets.estCarte(aff.evenement.id) {
       let r = Secrets.resoudre(evenementId: aff.evenement.id, choix: index, joueur: &j)
       ajouterLigne(&j, aff.texte + " → " + c.label + ". " + r.texte)
       joueur = j
       aff.resultat = r.texte
       evenementEnCours = aff
       sauvegarder()
       return
   }
   ```
5. `tags(j)` : `t.formUnion(Secrets.tags(j))`.
6. Quand un autre module émet `tromperie`, `prison_sortie`, `faillite`, `addiction`, `casino_ruine`, `casino_triche`,
   `chirurgie_esthetique`, `faux_permis_achete`, `crime_reussi`, `abandon_etudes` ou `licenciement` :
   `if let l = Secrets.signaler(signal, joueur: &j) { ajouterLigne(&j, l) }` (crée le secret correspondant chez le joueur).
7. Écrans :
   - `RelationDetailView` : dans la `List`, après la section Actions, `SecretsRelationSection(relationId: r.id, message: $message)`
     (elle n'affiche rien si le proche est mort).
   - Un lien vers `CarnetSecretsView()` (« Carnet des secrets », icône `lock.fill`), par ex. dans Activités ou Profil.
     La vue n'a pas de `NavigationStack` : la pousser avec un `NavigationLink`, ou l'entourer d'un `NavigationStack` dans une sheet.
