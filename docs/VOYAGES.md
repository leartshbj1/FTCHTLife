# Voyages sur mesure

Le joueur organise lui-même son voyage : il choisit **le pays** (et la ville), **le moyen de transport** (dont ses propres
véhicules : voiture, moto, bateau, avion ou jet), **l'hébergement**, **la durée** et **les proches qui viennent**.
Pendant le voyage, 2 à 4 **moments** à choix arrivent (le trajet, le séjour, le retour) et changent les stats, l'argent,
les liens avec chaque proche présent et l'état du véhicule.

Ce module complète, sans les remplacer :

- l'**Agence de voyages** de la boutique (`Data/Shop/travel.json`) : des séjours tout faits, en un clic ;
- **Vivre à l'étranger** (`FTCHTLife/Etranger`) : s'installer dans un pays. Un voyage ajoute le pays à
  `ExpatEtat.paysConnus` et fait un peu progresser la langue locale.

Code : `FTCHTLife/Voyages/`. Données : `FTCHTLife/Resources/Data/Voyages/`. Vérification : `python3 tools/validate_voyages.py`.

## Où on le trouve

- Menu **Activités → Voyager → Voyage sur mesure** (`ModuleJeu.voyages`), dès 12 ans (avant 18 ans, un parent doit venir
  et ce sont les parents qui paient).
- Boutique → Chez toi → **Voyage sur mesure**, à côté de l'Agence de voyages.

Deux voyages sur mesure par an au plus (on n'a pas que ça à faire). Fermé en prison.

## Déroulé

1. **Destination** : 65 pays (`destinations.json`), puis une ville.
2. **Transport** : seuls les moyens possibles pour ce pays sont proposés (voir plus bas). Les véhicules du joueur
   apparaissent un par un, avec la raison s'ils ne peuvent pas y aller (pas de permis, trop loin, pas de côte…).
3. **Hébergement** : camping, auberge de jeunesse, chez l'habitant, hôtel, hôtel de luxe, palace.
4. **Durée** : week-end (3 jours), une semaine, deux semaines, un mois.
5. **Qui vient** : partenaire, parents, frères et sœurs, enfants, amis (6 au plus). « J'invite » (le joueur paie tout,
   liens +4 en plus) ou « Chacun paie sa part » (adultes seulement).
6. **Devis** puis départ. Les moments s'enchaînent dans une feuille. À la fin : le récit du voyage dans le journal et
   dans le **carnet de voyages** (pays visités, souvenirs).

## Transports

| id | Nom | Groupe | Accès | Prix |
|---|---|---|---|---|
| `train` | Train | `rail` | `route`, `ferry` ; ≤ 3 000 km | 0,12 €/km/pers. |
| `autocar` | Autocar | `route` | `route`, `ferry` ; ≤ 3 000 km | 0,06 €/km/pers. |
| `covoiturage` | Covoiturage | `route` | `route` ; ≤ 2 000 km ; 16 ans | 0,05 €/km/pers. |
| `autostop` | Auto-stop | `route` | `route` ; ≤ 2 500 km ; 16 ans ; 3 personnes max | gratuit |
| `voitureLocation` | Voiture de location | `route` | `route`, `ferry` ; permis voiture | 0,10 €/km + 45 €/jour (par voiture de 5) |
| `avionLowCost` | Avion low cost | `avion` | ≥ 300 km ; ≤ 4 500 km | 0,07 €/km/pers. |
| `avionEco` | Avion, classe éco | `avion` | ≥ 300 km | 0,11 €/km/pers. |
| `avionBusiness` | Avion, classe affaires | `avion`, `luxe` | ≥ 300 km | 0,35 €/km/pers. |
| `avionPremiere` | Avion, première classe | `avion`, `luxe` | ≥ 1 500 km | 0,80 €/km/pers. |
| `jetLocation` | Jet privé loué | `avion`, `luxe` | ≥ 300 km ; 18 ans | 6 €/km (12 places) |
| `ferry` | Ferry | `mer` | pays côtier ; `ferry` ou `mer` | 0,10 €/km/pers. |
| `croisiere` | Croisière | `mer`, `luxe` | pays côtier ; ≥ 800 km | 0,22 €/km/pers. |
| `maVoiture` | Ta voiture | `route`, `perso` | `route`, `ferry` ; permis voiture valide | carburant selon la voiture |
| `maMoto` | Ta moto (ou ton vélo) | `route`, `perso` | `route`, `ferry` ; permis moto ou scooter (pas pour vélo et trottinette) | carburant |
| `monBateau` | Ton bateau | `mer`, `perso` | pays côtier ; portée selon le prix du bateau ; skipper payé sans permis bateau | carburant + skipper |
| `monAvion` | Ton avion, jet, hélico | `avion`, `perso` | portée selon le type ; pilote payé sans licence | carburant + pilote |

Accès d'un pays (`acces`) : `route` (voiture, train, car), `ferry` (route + traversée), `mer` (bateau ou avion
seulement), `avion` (avion, ou bateau pour un pays côtier).

Les véhicules du joueur s'usent (état −3 à −25 selon la distance) et un véhicule en mauvais état peut tomber en panne
(moments `vehiculeUse`). Places : voiture 4 (sportive, supercar, hypercar, cabriolet : 1 ; monospace : 6 ; limousine : 7),
moto 1, avion selon le type (jet 12, gros-porteur 50…), bateau selon le prix.

## Fichiers

- `destinations.json` : les pays. Champs : `id` (les ids de Vivre à l'étranger quand le pays y est), `nom`, `enPays` (« au Japon »), `drapeau`,
  `continent` (`europe`, `afrique`, `asie`, `amerique`, `oceanie`, `antarctique`), `distance` (km depuis Paris, aller),
  `acces`, `cotier`, `ile`, `climat` (`tempere`, `chaud`, `tropical`, `froid`, `desert`), `langue` (id de langue de
  Vivre à l'étranger, facultatif), `competence` (id de compétence travaillée, facultatif), `prixJour` (€ par personne et
  par jour à l'hôtel), `danger` (0 à 3), `villes`, `incontournables`, `specialites`, `presentation`.
- `moments_*.json` : les moments du voyage (tableau).

## Format d'un moment

```json
{
  "id": "voy_sej_0001",
  "phase": "sejour",
  "weight": 1,
  "minAge": 0,
  "maxAge": 120,
  "unique": false,
  "avec": ["parent"],
  "seul": false,
  "groupe": false,
  "transports": ["avionEco"],
  "groupes": ["avion"],
  "destinations": ["it"],
  "continents": ["europe"],
  "climats": ["chaud"],
  "hebergements": ["camping"],
  "minJours": 7,
  "vehiculeUse": false,
  "conditions": { "tags": ["riche"] },
  "text": "{compagnon_qui} veut absolument voir {incontournable}…",
  "choices": [
    { "label": "Y aller", "outcomes": [
      { "chance": 0.7, "text": "…", "effects": { "happiness": 5 }, "compagnon": 6 },
      { "chance": 0.3, "text": "…", "effects": { "money": -80 }, "compagnon": -4, "souvenir": "Un selfie flou devant {incontournable}" }
    ]},
    { "label": "Parler italien au guide", "requiresSkill": { "italien": 2 }, "outcomes": [ … ] }
  ]
}
```

Seuls `id`, `phase`, `text` et `choices` sont obligatoires. Tous les filtres sont des « l'un de » : `transports`,
`groupes` (`rail`, `route`, `avion`, `mer`, `perso`, `luxe`), `destinations`, `continents`, `climats`, `hebergements`.

- `phase` : `trajet` (l'aller), `sejour` (sur place), `retour`.
- `avec` : il faut au moins un proche présent de l'un de ces types : `partenaire`, `parent`, `enfant`, `fratrie`, `ami`.
  `{compagnon}` désigne alors l'un d'eux. Sans `avec`, `{compagnon}` est un proche présent au hasard (évitez-le si `seul`
  est possible).
- `seul: true` : seulement si personne ne vient. `groupe: true` : au moins 3 proches.
- `minJours` : durée minimale du voyage (3, 7, 14, 30).
- `vehiculeUse: true` : le joueur voyage avec son propre véhicule et celui-ci est à 50 % d'état ou moins.
- `conditions` : les conditions habituelles des événements (`tags`, `excludeTags`, `flags`, `gender`, `minMoney`…).
- `unique: true` : une fois par vie.
- `choices` : 2 ou 3 choix. Un choix peut avoir `requiresSkill` (caché si le niveau manque). Toujours au moins un choix
  sans `requiresSkill`.

Une issue a `chance`, `text`, `effects` (les effets habituels : `happiness`, `health`, `smarts`, `looks`, `karma`, `money`,
`skills`, `setFlags`, `followUps`, `casier`, `death`… mais **pas** `relationships`) et, en plus :

- `compagnon` : variation du lien avec le proche désigné par `{compagnon}` ;
- `compagnons` : variation du lien avec **tous** les proches présents ;
- `vehicule` : variation de l'état du véhicule personnel utilisé (sans effet si le joueur n'a pas pris le sien) ;
- `souvenir` : une ligne gardée dans le carnet de voyages (variables autorisées) ;
- `signal` : un signal envoyé aux répercussions (ex. `voyage_arnaque`).

### Variables

`{prenom}`, `{e}` (accord du joueur), `{compagnon}` (prénom), `{compagnon_qui}` (« ta mère », « ton ami »…),
`{Compagnon_qui}` (« Ta mère »), `{compagnon_e}` (accord du proche), `{il}` / `{Il}` (il ou elle, pour le proche),
`{pays}` (« Italie »), `{en_pays}` (« en Italie », « au Japon »), `{destination}` (la ville choisie),
`{incontournable}`, `{specialite}`, `{vehicule}` (« ta Rouillette 1.1 », « le train »), `{hebergement}` (« ton hôtel »,
« le camping »…), `{nb}` (nombre de voyageurs, toi compris). Les variables du moteur (`{mere}`, `{partenaire}`…)
marchent aussi.

### Ids

`voy_tra_NNNN` (trajet), `voy_sej_NNNN` (séjour), `voy_ret_NNNN` (retour). Une fois poussé, un id ne change plus.

## État sauvegardé

`Joueur.voyages: VoyagesEtat?` : récits (âge, pays, ville, transport, hébergement, durée, compagnons, coût, souvenirs),
compte par pays, moments uniques déjà vus. Le voyage ajoute aussi une ligne dans `Possessions.travels` (tag
`grand_voyageur` existant), le pays dans `ExpatEtat.paysConnus`, et un peu de la langue locale dans `ExpatEtat.langues`.

## Signaux et tags

Signaux à chaque voyage : `voyage` (déjà utilisé par les répercussions), plus `voyage_couple`, `voyage_famille`,
`voyage_amis`, `voyage_seul`, `voyage_luxe` selon le cas.

Tags : `voyageur` (5 voyages sur mesure), `globe_trotter` (15 pays visités), `voyage_cette_annee`.
