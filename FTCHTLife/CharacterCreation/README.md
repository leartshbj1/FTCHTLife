# Création de personnage

Module autonome : il ne dépend pas du moteur.

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
| `talentID` | talent inné ; `Talent.careerTags` sert aux bonus de carrière |
| `finalStats(catalog:)` | santé, bonheur, intelligence, apparence (0-100), bonus inclus |

`AvatarView(appearance:age:size:)` peut être réutilisée partout dans le jeu ; elle
gère le bébé (< 3 ans), les rides (55+) et les cheveux gris (65+).

## Ajouter du contenu

Tout est dans `Resources/creation_data.json` : pays (villes, prénoms, noms, devise),
traits (avec `modifiers` et `excludes`) et talents (avec `careerTags`). Pas besoin de
toucher au code.
