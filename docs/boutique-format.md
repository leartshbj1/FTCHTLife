# Boutique et biens : format des données

Toutes les données de la boutique sont dans `FTCHTLife/Resources/Data/Shop/`.
Tous les montants sont en **euros entiers** (`Int`). Les textes sont en français,
avec un humour décalé et absurde, 100 % originaux. Les marques sont **fictives**
(jeux de mots bienvenus), jamais de vraies marques ni de vrais noms de personnes.

Placeholders autorisés dans les textes : `{item}` (nom du bien), `{name}` (prénom du perso),
`{city}` (ville du bien ou du voyage), `{amount}` (montant en jeu, formaté par le code).

## 1. Catalogue des biens : `catalog_*.json`

Chaque fichier est un tableau JSON d'objets `CatalogItem` :

```json
{
  "id": "car_citadine_pomme_3",
  "category": "car",
  "subcategory": "citadine",
  "name": "Pomme 3 Turbo-Diesel",
  "brand": "Pommeau",
  "description": "Une citadine si petite que tu te gares dans ta propre poche.",
  "icon": "car.fill",
  "price": 14500,
  "minAge": 18,
  "upkeep": 900,
  "appreciation": -0.12,
  "volatility": 0.03,
  "wear": 6,
  "happiness": 3,
  "looks": 1,
  "health": 0,
  "prestige": 1,
  "rentIncome": 0,
  "financing": "carLoan",
  "usedMarket": true,
  "tags": ["essence"],
  "city": null
}
```

| Champ | Sens |
|---|---|
| `id` | unique dans tout le jeu, préfixé par la catégorie, `snake_case` ascii |
| `category` | `realEstate`, `car`, `moto`, `boat`, `aircraft`, `jewelry`, `watch`, `art`, `fashion`, `gadget`, `collection` |
| `subcategory` | libre (ex. `studio`, `villa`, `chateau`, `citadine`, `supercar`, `yacht`, `bague`, `collier`, `bracelet`…) |
| `icon` | nom de symbole SF Symbols existant (ex. `house.fill`, `building.2.fill`, `car.fill`, `sailboat.fill`, `airplane`, `crown.fill`, `sparkles`, `watch.analog`, `paintpalette.fill`, `tshirt.fill`, `iphone`, `gamecontroller.fill`, `bicycle`) |
| `price` | prix neuf |
| `minAge` | âge minimum pour acheter (souvent 18, 16 pour une mobylette, 0 pour un gadget) |
| `upkeep` | coût d'entretien annuel (charges, assurance, carburant, taxe foncière…) |
| `appreciation` | évolution moyenne de la valeur par an (`0.03` = +3 %/an, `-0.15` = -15 %/an) |
| `volatility` | écart aléatoire autour de l'évolution moyenne (0.01 à 0.3) |
| `wear` | perte d'état par an, sur 100 (0 pour un bijou, 3 à 8 pour une voiture, 1 à 3 pour une maison) |
| `happiness` `looks` `health` | effet appliqué une fois à l'achat (de -10 à +20) |
| `prestige` | 0 à 10, statut social (sert aux événements et aux relations) |
| `rentIncome` | loyer annuel possible si le bien est mis en location (immobilier uniquement, sinon 0) |
| `financing` | `none`, `carLoan` (5 ans), `mortgage` (20 ans) |
| `usedMarket` | `true` si le bien peut apparaître d'occasion avec un état et un prix réduits |
| `tags` | mots-clés libres (`luxe`, `insolite`, `ecolo`, `hante`, `vintage`…) |
| `city` | ville pour l'immobilier (fictive ou réelle), sinon `null` |

## 2. Locations (logement en location) : `rentals.json`

```json
{ "id": "rent_chambre_bonne", "name": "Chambre de bonne", "description": "...",
  "icon": "bed.double.fill", "rentPerYear": 5400, "happiness": -2, "prestige": 0, "city": "Paris" }
```

## 3. Voyages : `travel.json`

```json
{
  "id": "trip_islande_volcan",
  "name": "Islande : bivouac au pied d'un volcan",
  "destination": "Islande",
  "description": "...",
  "icon": "airplane",
  "price": 2400,
  "minAge": 18,
  "happiness": 12,
  "health": 0,
  "outcomes": [
    { "weight": 60, "text": "Tu as vu une aurore boréale ...", "effects": { "happiness": 5 } },
    { "weight": 10, "text": "Le volcan s'est réveillé ...", "effects": { "health": -10, "money": -500 } }
  ]
}
```

`effects` accepte : `money`, `happiness`, `health`, `looks`, `smarts`, `karma` (entiers, positifs ou négatifs).

## 4. Événements liés aux biens : `events_*.json`

Tirés chaque année pour chaque bien possédé (ou pour le perso, selon `scope`).

```json
{
  "id": "ev_car_pneu_creve",
  "scope": "item",
  "categories": ["car"],
  "subcategories": [],
  "tags": [],
  "chance": 0.06,
  "minAge": 0,
  "minPrestige": 0,
  "maxCondition": 100,
  "text": "Un pneu de ta {item} a crevé sur une crotte de pigeon fossilisée.",
  "choices": [
    { "label": "Changer le pneu toi-même",
      "outcomes": [
        { "weight": 70, "text": "Tu as réussi, avec seulement trois doigts écrasés.", "effects": { "health": -2 } },
        { "weight": 30, "text": "La roue a roulé jusqu'à la rivière. Dépanneuse.", "effects": { "money": -250 } }
      ] },
    { "label": "Appeler une dépanneuse", "outcomes": [ { "weight": 100, "text": "...", "effects": { "money": -180 } } ] }
  ]
}
```

| Champ | Sens |
|---|---|
| `scope` | `item` (concerne un bien précis, `{item}` remplacé), `owner` (concerne le perso parce qu'il possède au moins un bien des catégories) , `trip` (pendant un voyage) |
| `categories` / `subcategories` / `tags` | filtres (vide = tout) ; il suffit qu'une valeur corresponde |
| `chance` | probabilité par an et par bien correspondant (0.01 à 0.15) |
| `maxCondition` | ne se déclenche que si l'état du bien est ≤ cette valeur (pannes sur biens usés) |
| `choices` | 1 à 4 choix ; un seul choix = événement simple sans décision |

Effets supplémentaires possibles dans un résultat d'événement de scope `item` :
`condition` (± état du bien), `valuePct` (± % de la valeur, ex. `-0.3`), `destroy` (`true` : bien perdu),
`stolen` (`true` : bien volé, remboursé par l'assurance si assuré).

## 5. Branchement dans le moteur

Tout le code est dans `FTCHTLife/Shop/`. Le seul changement hors de ce dossier est le champ
`var possessions: Possessions?` de `Joueur` (`Models/Models.swift`), nil tant que le perso n'a rien acheté.

- **Ouvrir la boutique** : `ShopView()` dans une feuille, avec `GameEngine` en `environmentObject`.
  Elle a sa propre `NavigationStack` et un bouton Fermer.
- **+1 an** : dans la boucle annuelle, après le vieillissement, appeler `passageAnneeBoutique(&j)`
  (extension de `GameEngine`). Elle paie entretien, assurances, crédits et loyer, encaisse les loyers,
  fait évoluer valeur et état des biens, saisit les biens après deux échéances impayées,
  renouvelle les annonces d'occasion et tire jusqu'à 2 événements liés aux biens.
- **Badge** : `engine.evenementsBoutiqueEnAttente` donne le nombre d'événements de biens en attente
  (ils se règlent dans la boutique, section « À régler »).
- **Crochets** (`ShopHooks`) pour les autres modules, sans dépendance de compilation :
  - `ShopHooks.money = { Shkurtaaa.argent($0) }` et `ShopHooks.canAfford = { Shkurtaaa.peutPayer($0, solde: $1) }` (mode Shkurtaaa) ;
  - `ShopHooks.happiness` / `ShopHooks.health` pour borner bonheur et santé ;
  - `ShopHooks.priceMultiplier = { MondeJournal.multiplicateurPrix($0, etat: …) }` (Journal du monde),
    avec les clés de `ShopCategory.mondeKey` et `"voyages"`.
- **Cadeaux** : `ShopEngine.removeForGift(id, &j)` retire un bijou, une montre, un vêtement, un gadget ou une œuvre
  pour l'offrir (module amour).

## 6. Vérifier les données

`python3 scripts/validate_shop.py` vérifie champs, catégories, ids uniques et effets.
