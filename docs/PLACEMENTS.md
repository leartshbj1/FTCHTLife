# Module Placements

Livret d'épargne, bourse (actions, fonds, or), cryptos absurdes (×100 ou zéro) et immobilier locatif avec crédit.

Code : `FTCHTLife/Placements/` (types préfixés `Placement…`). Données : `FTCHTLife/Resources/Data/Placements/<Sous-dossier>/*.json`.
Validateur : `python3 tools/validate_placements.py`.

## Ce que fait le joueur

- **Livret de l'Écureuil Prévoyant** (dès la naissance) : dépôt et retrait, plafond 50 000 €, taux entre 0,5 et 4,5 % qui bouge chaque année.
- **Bourse** (18 ans et plus) : 45 actions d'entreprises inventées dans 9 secteurs, 8 fonds, 3 « or ». Achat au montant (parts fractionnées), vente 25 / 50 / 100 %, frais de 1 %. Dividendes versés chaque année. Une action peut faire faillite.
- **Cryptos** : 30 cryptos absurdes. 8 existent au départ, les autres sont lancées au fil des années. Chaque année, chacune peut faire ×10 à ×100 (rare) ou mourir pour toujours. Cimetière des cryptos dans l'écran.
- **Immobilier locatif** : 28 biens, du parking au château en passant par le phare et la maison hantée. Achat comptant ou à crédit (20 % d'apport + 8 % de notaire, 20 ans à 3,5 %, la banque refuse si les remboursements dépassent 35 % du salaire). Chaque année : valeur qui bouge, loyer indexé, charges, locataires (45 profils) qui paient ou non et partent, pépins (incidents), remboursement du crédit. Actions : hausse de loyer (karma −2), expulsion (karma −4), remboursement anticipé, vente (5 % de frais).
- **Nouvelles du marché** : 1 à 3 par an (« Les échos de la Corbeille »), qui font bouger un secteur, un titre ou tout le marché. Celles qui touchent les titres du joueur vont aussi dans son journal.

## Branchement dans le moteur (fil moteur)

1. Ajouter à `Joueur` : `var placements: PlacementsEtat?` (optionnel, les anciennes sauvegardes restent valides). Le créer dans `nouvelleVie` avec `PlacementsMoteur.nouveau()`.

2. Dans `vieillir()`, après l'emploi :

```swift
var pl = j.placements ?? PlacementsMoteur.nouveau()
let ctx = PlacementsContexte(
    age: j.age,
    salaireAnnuel: j.emploi?.salaire ?? 0,
    multiplicateurs: multiplicateursMarche,   // voir « Journal du monde » plus bas
    triche: false                             // true si le mode Shkurtaaa est actif
)
let bilan = PlacementsMoteur.passerAnnee(&pl, argent: &j.argent, contexte: ctx)
j.placements = pl
lignes += bilan.lignes
j.stats.bonheur += bilan.bonheur
j.stats.karma += bilan.karma
```

`passerAnnee` applique déjà l'argent (dividendes, loyers nets, crédits) à `j.argent`. Le marché tourne chaque année même si le joueur n'a rien placé, pour que les cours aient une histoire quand il arrive à 18 ans.

3. Dans `tags(_:)` : `t.formUnion(PlacementsMoteur.tags(j.placements ?? PlacementsEtat()))`.
Tags posés : `investisseur` (actions, fonds ou or), `crypto`, `proprietaire_bailleur`, `epargnant` (livret ≥ 1 000 €), `ruine_crypto` (a déjà perdu une crypto). Les événements de `Events/placements_01.json` en dépendent.

4. Écran : une ligne « Placements » (icône `chart.line.uptrend.xyaxis`) dans les activités ou un onglet, qui ouvre :

```swift
PlacementsView(
    etat: Binding(get: { engine.joueur?.placements ?? PlacementsEtat() },
                  set: { v in engine.modifier { $0.placements = v } }),
    argent: Binding(get: { engine.joueur?.argent ?? 0 },
                    set: { v in engine.modifier { $0.argent = v } }),
    contexte: PlacementsContexte(age: j.age, salaireAnnuel: j.emploi?.salaire ?? 0, multiplicateurs: multiplicateursMarche),
    surKarma: { k in engine.modifier { $0.stats.karma += k } }
)
```

5. À la mort : `PlacementsMoteur.patrimoine(etat)` donne la valeur totale (livret + titres + biens − crédits), pour l'héritage et la nécrologie.

## Journal du monde

`PlacementsContexte.multiplicateurs` reçoit les multiplicateurs de marché du Journal du monde (`MondeJournal.multiplicateurMarche(cle, etat:)`), 1.0 = neutre, 1.3 = +30 % cette année-là, en plus du mouvement normal :

| Clé | Effet |
|---|---|
| `bourse` | actions et fonds |
| `bourse_<secteur>` | un secteur : `tech`, `alimentation`, `energie`, `luxe`, `sante`, `transport`, `loisirs`, `finance`, `industrie` |
| `crypto` | toutes les cryptos (mouvement normal, pas les ×100) |
| `or` | métaux précieux |
| `immobilier_locatif` | valeur des biens |
| `epargne` | taux du livret (2.0 = doublé) |

```swift
let cles = ["bourse", "crypto", "or", "immobilier_locatif", "epargne"] + PlacementSecteur.allCases.map { "bourse_" + $0.rawValue }
let multiplicateursMarche = Dictionary(uniqueKeysWithValues: cles.map { ($0, MondeJournal.multiplicateurMarche($0, etat: monde)) })
```

## Format des données

Chaque fichier est un **tableau**. Un sous-dossier par type (le chargeur lit tous les fichiers d'un dossier avec le même type).

### `Actifs/*.json`

```json
{ "id": "act_kebab", "nom": "Kebab Capital", "ticker": "KBAB", "type": "action", "secteur": "alimentation",
  "description": "…", "prixInitial": 48, "rendement": 0.06, "volatilite": 0.22, "dividende": 0.03,
  "texteZero": "{nom} ({ticker}) fait faillite…" }
```

- `type` : `action` (secteur obligatoire), `fonds`, `or`, `crypto`.
- `rendement` : tendance annuelle moyenne ; `volatilite` : écart type annuel ; `dividende` : part du prix versée par an.
- Cryptos : `chanceLune` (par an, ×10 à ×100, garder ≤ 0,01 pour l'équilibre), `chanceZero`, `texteLune`, `texteZero`, `depart` (présente dès le début).

### `Nouvelles/*.json`

`{ "id": "nou_0001", "texte": "…", "cible": "tech", "variationMin": -0.2, "variationMax": -0.05, "poids": 5 }`
`cible` : `tout`, `bourse`, `crypto`, `or`, `immobilier`, un secteur, ou l'id d'un actif.

### `Biens/*.json`

`{ "id": "bie_phare", "nom": "Phare désaffecté", "designation": "ton phare désaffecté", "description": "…", "prix": 380000, "loyerAnnuel": 13800, "charges": 9500, "risque": 0.3, "icone": "lighthouse.fill" }`

### `Locataires/*.json`

`{ "id": "loc_escargots", "description": "qui élève des escargots dans la baignoire", "fiabilite": 0.8, "depart": 0.15, "poids": 5 }`
La description suit un prénom tiré au hasard : écrire au neutre.

### `Incidents/*.json`

`{ "id": "inc_0001", "texte": "Dégât des eaux dans {bien}…", "coutMin": 800, "coutMax": 3000, "bonheur": -3, "karma": 0, "locatairePart": false, "valeur": 0.95, "condition": "loue", "poids": 6 }`
`{bien}` = designation du bien, `{locataire}` = prénom (seulement avec `"condition": "loue"`). Coût négatif = gain.

## Équilibrage

- Une crypto a en moyenne une espérance légèrement positive mais un risque énorme : c'est une loterie. Ne pas monter `chanceLune` au-dessus de 0,01, sinon acheter toutes les cryptos devient une machine à millions.
- Les montants passent par `PlacementsMoteur.entier` qui borne les valeurs : pas de crash même avec 100 milliards (mode Shkurtaaa) placés sur une crypto qui fait ×100.
- En mode triche (`contexte.triche = true`) : cryptos immortelles, pas de pépins locatifs, la banque prête toujours, les locataires paient toujours.
