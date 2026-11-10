# Événements albanais

Des événements très albanais (raki du père, mère surprotectrice, ménage du samedi, çaj pour les invités,
mariages à 600 invités, diaspora, café, voisins…) qui n'arrivent qu'aux joueurs **nés en Albanie**
(pays `al` choisi à la création du personnage).

## Fichiers

- `FTCHTLife/Resources/Data/Events/albanie_NN.json` : format standard des événements (`docs/EVENTS_FORMAT.md`).
- `id` : `alb_NNNN`, `category` : `"albanie"`.
- Vérification : `python3 tools/validate_events.py` (accepte les tags `origine_xx`, `pays_xx`, `etranger`…).

| Fichier | Thème | Âges |
|---|---|---|
| `albanie_01.json` | bébé et enfance (alb_0001-0050) | 0-12 |
| `albanie_02.json` | adolescence (alb_0051-0100) | 12-17 |
| `albanie_03.json` | raki, père, famille adulte (alb_0101-0150) | 18-64 |
| `albanie_04.json` | mariages, fiançailles, belle-famille (alb_0151-0200) | 18-70 |
| `albanie_05.json` | diaspora (alb_0201-0250) | tous |
| `albanie_06.json` | quotidien au pays, voisins, café, fêtes, vieillesse (alb_0251-0300) | 18-100 |

## Tags utilisés

Chaque événement exige `origine_al`. Certains ajoutent :

| Tags | Quand l'événement arrive |
|---|---|
| `["origine_al"]` | né en Albanie, où qu'il vive (famille albanaise) |
| `["origine_al", "pays_al"]` | né en Albanie et vit en Albanie |
| `["origine_al", "etranger"]` | né en Albanie et vit à l'étranger (diaspora) |

`pays_al` et `etranger` viennent du module « Vivre à l'étranger » (PR #29, `ExpatMoteur.tags`).

## Branchement (fil moteur)

Un seul ajout : le tag `origine_<pays de naissance>`. Avec le module « Vivre à l'étranger » branché
(`j.etatExpat`, voir `docs/ETRANGER.md`), dans `GameEngine.tags(_:)` :

```swift
t.insert("origine_\(j.etatExpat.paysNaissance)")
```

Le pays de naissance vient de la création de perso (`draft.countryID`, PR #2), id `"al"` pour l'Albanie.
Tant que ce tag n'est pas posé, ces événements ne sortent jamais (aucun effet sur les autres vies).
Le même tag servira pour d'autres pays (`origine_xk`, `origine_ma`…) si on écrit des événements d'origine pour eux.
