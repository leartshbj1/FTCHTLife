# Fêtes de l'année

Chaque année, le joueur vit une fête (parfois deux) : son anniversaire, Noël, le Nouvel An, la Saint-Valentin,
la fête des mères… Chaque fête est une **carte à choix** (quel cadeau offrir, avec qui réveillonner, présenter
son copain à la famille…). Les cadeaux ratés et les repas qui dégénèrent changent les relations, et la famille
**s'en souvient** l'année suivante.

Code : `FTCHTLife/Fetes/Fetes.swift`. Vérification : `python3 tools/validate_fetes.py` (`--couverture` affiche
les fêtes possibles à chaque âge).

## Données

- `Resources/Data/FetesCalendrier/*.json` : la liste des fêtes.

  ```json
  { "id": "noel", "nom": "Noël", "emoji": "🎄", "mois": 12, "jour": 25, "poids": 3 }
  ```

  `mois` sert à ranger les fêtes d'une même année (0 = date variable, pour les anniversaires).
  `poids` = fréquence relative dans le tirage.

- `Resources/Data/Fetes/<fete>.json` : les **variantes** de chaque fête, au **format des événements**
  (voir `docs/ARCHITECTURE.md`), avec `"category"` = id de la fête et un id `fet_<3 lettres>_NNNN`.

| Fête | id | préfixe |
|---|---|---|
| Ton anniversaire | `anniversaire` | `fet_ann_` |
| Anniversaire d'un proche (parent, partenaire, enfant, ami) | `anniv_proche` | `fet_apr_` |
| Nouvel An | `nouvel_an` | `fet_nva_` |
| Galette des rois | `galette` | `fet_gal_` |
| Chandeleur | `chandeleur` | `fet_cha_` |
| Saint-Valentin | `saint_valentin` | `fet_val_` |
| Carnaval | `carnaval` | `fet_car_` |
| 1er avril | `poisson_avril` | `fet_avr_` |
| Pâques | `paques` | `fet_paq_` |
| 1er mai | `premier_mai` | `fet_mai_` |
| Fête des mères | `fete_meres` | `fet_mer_` |
| Fête des pères | `fete_peres` | `fet_per_` |
| Fête de la musique | `fete_musique` | `fet_mus_` |
| 14 juillet | `quatorze_juillet` | `fet_jul_` |
| Halloween | `halloween` | `fet_hal_` |
| Noël | `noel` | `fet_noe_` |

La fête des voisins appartient au module Voisins et quartier.

## Tirage

- 75 % de chance d'avoir une fête dans l'année, 15 % d'en avoir une deuxième.
- Une fête vécue est mise de côté pendant 3 ans (sauf s'il n'y a rien d'autre de possible).
- Dans une fête, on ne revoit pas une variante avant d'avoir vu toutes les autres.
- **Anniversaires marquants** : une variante avec `minAge == maxAge` (ex. 18 ans, 30 ans, 100 ans) passe
  **toujours** l'année de cet âge, en plus du tirage normal (au plus une autre fête cette année-là).
- **Souvenirs** : une variante peut exiger un drapeau posé par une fête précédente (`conditions.flags`).
  Quand un souvenir est prêt, sa fête a 4 fois plus de chances d'être tirée et la variante souvenir passe en priorité.
- Le texte de la carte est préfixé par l'emoji et le nom : « 🎄 Noël : … ».

## Souvenirs (drapeaux)

On utilise les drapeaux du module Répercussions (`docs/REPERCUSSIONS.md`), préfixés `fete_` :

```json
"effects": { "relationships": { "mother": -6 }, "setFlags": ["fete_cadeau_rate_mere"] }
```

puis, dans une autre variante (même fête ou une autre) :

```json
"conditions": { "tags": ["mother"], "flags": ["fete_cadeau_rate_mere"] },
"text": "Ta mère a ressorti le presse-agrumes de l'an dernier. Toujours dans son emballage. Elle te le rend.",
... chaque issue : "clearFlags": ["fete_cadeau_rate_mere"]
```

Tant que le module Répercussions n'est pas branché, les variantes souvenir ne sortent jamais et `setFlags` est ignoré :
rien ne casse.

## Règles d'écriture

- Mêmes règles que les événements (`docs/EVENTS_STYLE.md`) : tutoiement, humour décalé, original, 2 à 4 choix
  courts, 1 à 3 issues par choix, somme des `chance` = 1.
- **Toujours un petit choix** : cadeau, avec qui fêter, présenter quelqu'un, quoi cuisiner, comment réagir.
- **Les relations bougent** : cadeau raté ou repas qui dégénère = `relationships` négatif, beau geste = positif.
- Une variable de personne exige sa condition : `{mere}`→tag `mother`, `{pere}`→`father`, `{fratrie}`→`siblings`,
  `{ami}`→`friend`, `{partenaire}`→`requiresPartner: true`, `{metier}`→`requiresJob: true`.
  Pareil pour `relationships` : `mother`, `father`, `sibling`, `friend`, `partner`, `child` (tag `children`).
- Pas d'argent négatif dans une variante accessible avant 16 ans (un enfant n'a pas de compte en banque).
- Couvrir tous les âges : bébé (0-2), enfant (3-12), ado (13-17), adulte, senior (65+).
- Ne jamais changer l'`id` ni l'ordre des choix d'une variante publiée (les répercussions s'y réfèrent).

## Branchement dans le moteur (fil moteur)

1. `Joueur` : `var fetes: FetesEtat?` (optionnel, les anciennes sauvegardes restent lisibles).
2. Dans `vieillir()`, juste avant `tirerEvenements()` :

   ```swift
   var etatFetes = j.fetes ?? FetesEtat()
   let t = tags(j)
   let fetes = Fetes.evenementsDeLAnnee(age: j.age, etat: &etatFetes,
                                        drapeaux: nil /* ou Set(j.repercussions?.flags.keys ?? []) */) {
       conditionsRemplies($0, j, tags: t)
   }
   j.fetes = etatFetes
   joueur = j
   fetes.forEach { declencher($0) }
   ```

3. Dans `tirerEvenements()`, le `guard !candidats.isEmpty else { return }` sort avant d'afficher la file :
   il faut afficher la file même sans événement aléatoire (sinon une fête mise en file ne s'affiche pas).
4. Quand le module Répercussions est branché, passer `drapeaux: Set(j.repercussions?.flags.keys ?? [])`.
   Les `setFlags` / `clearFlags` des fêtes passent par `appliquer` comme pour les événements.
