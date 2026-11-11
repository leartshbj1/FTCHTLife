# Beauté : coiffeur et chirurgie esthétique

Menu **Activités → Prendre soin de soi** : deux entrées, **Coiffeur** et **Chirurgie esthétique**.
Elles remplacent l'ancienne activité rapide « Chirurgie esthétique » du moteur (un seul tirage, 80 % de réussite).

Code : `FTCHTLife/Beaute/` (types préfixés `Beaute`). Catalogue : `Resources/Data/Beaute/catalogue.json`.
Événements : `Resources/Data/Events/beaute_01.json` (ids `bea_NNNN`). Suites : `Resources/Data/Repercussions/beaute_01.json` (ids `rep_bea_NNNN`).
Vérification : `python3 tools/validate_beaute.py`, puis `tools/validate_events.py` et `tools/validate_repercussions.py`.

## Coiffeur

- Une visite par an. On choisit un **salon** (coupe maison, salon express, salon du quartier, barbier, salon chic,
  coiffeur des stars ; en prison, seulement le codétenu), une **coupe** (26, certaines réservées aux hommes) et,
  si le salon le fait, une **couleur** (12).
- Chance de réussite = talent du salon, moins l'audace de la coupe et de la couleur (et la calvitie).
  Réussi : apparence + (coupe + prestige du salon + couleur), bonheur +3 à +8. Moyen : petit bonus.
  Raté : malus d'apparence (plus fort si la coupe était audacieuse), bonheur -6 à -10.
- Le bonus (ou le malus) est **temporaire** : il disparaît quand la coupe repousse (1 à 3 ans selon la coupe),
  ou quand on retourne chez le coiffeur.
- Mineurs : les parents paient dans les salons simples, refusent le salon chic et le coiffeur des stars, et
  la couleur avant l'âge de la couleur (14 à 40 ans). Une coupe audacieuse fait baisser le lien avec les parents.
- Avec une calvitie, seulement les coupes rasées ou courtes.

## Chirurgie esthétique

- 20 interventions en 4 zones : injections (botox, lèvres, cernes : effet d'un an), visage (rhinoplastie, paupières,
  oreilles, menton, fossettes, lifting), silhouette (liposuccion, abdominoplastie, augmentation et réduction mammaires,
  BBL, implants pectoraux et de mollets, allongement des jambes), sourire et cheveux (blanchiment, facettes, greffe).
- 5 endroits : forfait tout compris à l'étranger (prix ×0,45, risque ×2), clinique de la zone commerciale (×0,8, ×1,35),
  chirurgien reconnu (×1, ×1), chirurgien des stars (×2,6, ×0,5, meilleur résultat), injections clandestines dans une
  chambre d'hôtel (×0,25, risque ×4, illégal, seulement injections et BBL).
- Risque = risque de l'intervention × clinique × (1 + 10 % par passage au bloc) × 1,5 si santé < 40 × 1,4 après 65 ans.
- Issues : **accident grave** (réanimation, santé -45, 45 % de mort hors mode Shkurtaaa ; texte sérieux, embolie
  graisseuse pour le BBL), **complication** (infection, cicatrice, asymétrie, nécrose, coque, nerf touché, réaction au
  produit, douleurs, séquelles : santé et bonheur perdus chaque année jusqu'au soin ou à la guérison ; une
  complication grave non soignée peut tuer, 8 % par an), **raté** (malus d'apparence jusqu'à la chirurgie réparatrice),
  **réussite** (gain d'apparence, réduit avant l'âge idéal du lifting ou des paupières, et à partir de la 5e opération).
- Une seule opération au bloc par an (les injections ne comptent pas). Un chirurgien sérieux refuse d'opérer avec une
  santé sous 25 ou une complication grave en cours ; le forfait et la clandestine, eux, opèrent quand même.
- La greffe de cheveux répare la calvitie.
- **Calvitie** : peut commencer chaque année (hommes 25-70 ans : 3,5 % par an ; femmes après 50 ans : 0,6 %).

## État et branchement

- `Joueur.beaute: BeauteEtat?` : coiffure en cours, opérations (avec gain, expiration, à réparer), complications,
  calvitie, compteurs.
- `modulesAnnee` appelle `BeauteMoteur.passerAnnee` (repousse, fin des injections, complications, calvitie, obsession
  du miroir après 5 opérations). Une mort renvoyée par le module respecte déjà `Shkurtaaa.peutMourir`.
- `tagsModules` ajoute `BeauteMoteur.tags`.
- `modulesAppliquer` appelle `beauteAppliquer(eff.beaute, &j)`.
- Écrans : `CoiffeurView`, `ChirurgieView`, `InterventionDetailView` (dans `EcranModule`). Pastille sur « Chirurgie
  esthétique » = nombre de complications en cours.

### Tags (`conditions.tags`)

`beaute_operee` (1 passage au bloc), `beaute_refaite` (3), `beaute_accro` (5), `beaute_ratee` (raté à réparer),
`beaute_complication`, `beaute_complication_grave`, `beaute_calvitie`, `beaute_bbl`, `beaute_seins`, `beaute_lifting`,
`beaute_greffe`, `beaute_jambes`, `beaute_injections` (effet d'injection en cours), `beaute_clandestin`,
`beaute_tourisme` (forfait à l'étranger), `beaute_gros_budget` (50 000 € et plus), `beaute_coupe_audacieuse`,
`beaute_coupe_ratee`, `beaute_couleur_vive`, `beaute_crane_rase`, `beaute_coiffeur_star`, `beaute_jamais_coiffeur`.

### Effets d'événements (`effects.beaute`)

```json
"beaute": {"reparer": true, "soigner": true, "calvitie": true, "coupeRatee": true, "operation": "botox", "clinique": "star"}
```

`reparer` : tous les ratés réparés ; `soigner` : toutes les complications soignées ; `calvitie` : true la déclenche,
false la guérit ; `coupeRatee` : la coupe actuelle tourne mal ; `operation` : fait l'intervention (le prix est à mettre
dans `money`), dans la clinique `clinique` (par défaut `reconnu`), avec tous ses risques.

### Signaux (répercussions)

`coiffeur`, `coiffure_ratee`, `coiffure_audacieuse`, `injections`, `chirurgie_esthetique` (chaque passage au bloc,
déjà utilisé par les suites santé, les trophées, les secrets et la réputation de la famille), `chirurgie_<id>`
(ex. `chirurgie_bbl`, `chirurgie_rhino`), `chirurgie_ratee`, `chirurgie_clandestine`, `chirurgie_forfait`, `hopital`,
`guerison`, `calvitie`.

## Ton

Le coiffeur peut être drôle. La chirurgie aussi, tant que tout va bien. Les complications, les accidents au bloc, les
injections clandestines et l'obsession du miroir sont écrits sérieusement.
