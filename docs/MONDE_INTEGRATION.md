# Journal du monde : branchement dans le moteur

Le module (`FTCHTLife/Monde/`) compile seul et ne touche pas au moteur. Voici ce que le fil moteur ajoute
pour qu'il agisse vraiment sur la partie. Toutes les fonctions sont des fonctions pures sur un `MondeEtat`.

## 1. Sauvegarde

Dans `Joueur` (`Models/Models.swift`) :

```swift
var monde: MondeEtat?   // optionnel : les anciennes sauvegardes restent lisibles
```

Et dans `GameEngine` :

```swift
@Published var flashMonde: MondeFlash?            // la une à afficher cette année
private var monde: MondeEtat { joueur?.monde ?? MondeEtat() }
```

## 2. Chaque année (`vieillir()`)

Juste après `j.journal.append(Annee(age: j.age, lignes: lignes))` :

```swift
var monde = j.monde ?? MondeEtat()
let rapport = MondeJournal.nouvelleAnnee(&monde, age: j.age, tagsJoueur: tags(j), remplir: { self.remplir($0, j) })
j.monde = monde
for ligne in rapport.lignes { ajouterLigne(&j, ligne) }
for eff in rapport.effets { appliquer(eff, &j) }
flashMonde = rapport.flash
```

Les effets du monde doivent ensuite peser sur le reste de l'année (les appels ci-dessous lisent `j.monde`) :

| Où | Remplacer | Par |
|---|---|---|
| Emploi (salaire versé) | `e.salaire` | `MondeJournal.salaire(e.salaire, metierId: e.metierId, titre: e.titre, etat: monde)` |
| Retraite | `18000` | `Int(18000 * MondeJournal.multiplicateurRetraite(monde))` |
| Frais d'université | `e.filiere.fraisAnnuels` | `MondeJournal.prix(e.filiere.fraisAnnuels, categorie: "etudes", etat: monde)` |
| `chanceDeces` du joueur | `Self.chanceDeces(...)` | `Self.chanceDeces(...) * MondeJournal.multiplicateurMortalite(monde)` |
| `tags(_:)` | – | `t.formUnion(MondeJournal.tagsJoueur(j.monde ?? MondeEtat()))` |
| `tirerEvenements()` candidats | `BibliothequeEvenements.tous` | `BibliothequeEvenements.tous + MondeJournal.evenementsActifs(monde)` |
| `tirerEvenements()` poids | `{ $0.weight ?? 1 }` | `{ MondeJournal.poidsEvenement($0, etat: monde) }` |

Le hasard du journal tourne avant `tirerEvenements()`, donc une crise publiée cette année change déjà les événements de l'année.

## 3. Afficher la une

Dans `MainView` :

```swift
.sheet(item: $engine.flashMonde) { f in
    MondeFlashSheet(flash: f, age: engine.joueur?.age ?? 0)
        .presentationDetents([.medium, .large])
}
```

Attention à ne pas l'ouvrir en même temps que `evenementEnCours` : le plus simple est de ne mettre `flashMonde`
que si `evenementEnCours == nil`, ou d'afficher la une en premier puis la file d'événements à sa fermeture.

Et un accès permanent, par exemple un bouton dans l'en-tête ou une ligne dans Activités :

```swift
MondeJournalView(etat: j.monde ?? MondeEtat(), age: j.age,
                 titresExternes: [] /* + PolMoteur.titresActualite(...) quand la politique est branchée */)
```

## 4. Autres modules

- **Boutique** : `ShopHooks.priceMultiplier` prend une catégorie déjà traduite (`ShopCategory.mondeKey`). Après chaque
  `nouvelleAnnee` et au chargement d'une sauvegarde :
  ```swift
  let m = j.monde ?? MondeEtat()
  ShopHooks.priceMultiplier = { MondeJournal.multiplicateurPrix($0, etat: m) }
  ```
  (on capture une copie de l'état, pas le moteur, pour rester hors du MainActor.)
- **Métiers** : `MondeJournal.salaire(report.income, secteur: CareerCatalog.shared.career(id)?.sector, etat: monde)`.
  Les secteurs du module Métiers (`beaute_mode`, `art_culture`…) sont traduits par `MondeSecteurs.normaliser`.
- **Placements** : passer `MondeJournal.marches(monde)` (dictionnaire `bourse`, `crypto`, `or`, `immobilier_locatif`,
  `epargne`, `bourse_<secteur>`).
- **Politique** : les tables de prix et salaires des lois se combinent avec `extra:`
  (`MondeJournal.multiplicateurPrix(cat, etat: monde, extra: [tablePrixDesLois])`). Une loi peut publier un flash
  avec `MondeJournal.forcer("mon_0xxx", etat: &monde, age: j.age, tagsJoueur: tags(j))` (flashs `suiteSeulement`).
- **Événements** : n'importe quel événement peut exiger une crise avec `"conditions": {"tags": ["monde_<tag>"]}`
  (liste des tags monde : `grep -h tagsMonde -A3 FTCHTLife/Resources/Data/Monde/*.json`).
- **Mode Shkurtaaa** : rien à faire, le journal ne touche pas au plancher d'argent.
