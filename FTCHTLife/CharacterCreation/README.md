# Création de personnage

Module autonome : il ne dépend du moteur que pour `DonneesJSON.dossierData`.
Tous les types sont préfixés `Creation…` pour éviter les collisions entre modules.

## Brancher sur le moteur

```swift
CharacterCreationView(onCancel: { dismiss() }) { draft in
    engine.startNewLife(from: draft)   // à écrire côté moteur
}
```

`CharacterDraft` contient tout ce que le joueur a choisi :

| Champ | Contenu |
|---|---|
| `firstName`, `lastName`, `gender` | identité |
| `countryID`, `city` | origine (`catalog.country(id)` donne drapeau, devise, prénoms) |
| `birthYear` | année en cours par défaut |
| `appearance` | peau, coiffure, couleur des cheveux, yeux, taches de rousseur, lunettes |
| `wealth` | milieu familial ; `wealth.familyMoney` = argent des parents |
| `traitIDs` | 0 à 2 traits (ids de `creation_data.json`) |
| `talentID` | talent inné ; `CreationTalent.careerTags` sert aux bonus de carrière |
| `finalStats(catalog:)` | santé, bonheur, intelligence, apparence (0-100), bonus inclus |

`AvatarPersoView(appearance:age:size:)` peut être réutilisée partout dans le jeu ; elle
gère le bébé (< 3 ans), les rides (55+) et les cheveux gris (65+).

## Ajouter du contenu

Tout est dans `Resources/Data/Creation/creation_data.json` : pays (villes, prénoms, noms, devise),
traits (avec `modifiers` et `excludes`) et talents (avec `careerTags`). Pas besoin de
toucher au code.

## Correspondance avec `Joueur`

- `CreationGender.male/.female` → `Genre.homme/.femme`. `.nonBinary` existe côté création ; à mapper selon ce que le moteur prévoit.
- `finalStats(catalog:)` → `Stats` (`sante`, `bonheur`, `intelligence`, `apparence`) ; le karma n'est pas choisi à la création.
- `wealth.familyMoney` = argent des parents (le joueur naît à 0 €).
