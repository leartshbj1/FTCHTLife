# Journal du monde : format des flashs info

Chaque année, le journal du monde publie un **flash info** fictif et absurde. Certains ne sont que pour rire,
d'autres **changent vraiment le jeu** pendant un an ou plus : prix de la boutique, salaires d'un secteur,
fréquence de certains événements, mortalité, retraites, marchés (bourse, crypto), effets sur le joueur chaque année,
et événements spéciaux qui n'existent que pendant la crise.

Code : `FTCHTLife/Monde/` (types préfixés `Monde…`). Données : `FTCHTLife/Resources/Data/Monde/*.json`,
chaque fichier est un **tableau** de flashs. Validateur : `python3 tools/validate_monde.py`.

## Un flash

```json
{
  "id": "mon_0001",
  "rubrique": "economie",
  "titre": "PÉNURIE MONDIALE DE CROISSANTS",
  "texte": "Un champignon a ravagé les champs de beurre. Le croissant s'échange désormais au marché noir.",
  "poids": 6,
  "duree": 2,
  "unique": true,
  "minAge": 0,
  "modificateurs": {
    "prix": { "nourriture": 1.4, "tout": 1.03 },
    "salaires": { "restauration": 1.15 },
    "evenements": { "categories": { "crime": 1.2 }, "prefixes": { "eco_": 1.5 } },
    "marches": { "bourse": 0.95 },
    "mortalite": 1.0,
    "retraite": 1.0
  },
  "effetsImmediats": [
    { "text": "Ton petit-déjeuner coûte désormais un rein.", "effects": { "happiness": -3 } }
  ],
  "effetsAnnuels": [
    { "tags": ["poor"], "text": "Tu rêves de croissants la nuit.", "effects": { "happiness": -2 } }
  ],
  "evenements": [ { "id": "mon_0001_e1", "category": "monde", "minAge": 6, "maxAge": 99, "weight": 6,
                    "text": "Un inconnu te propose un croissant sous le manteau.", "choices": [] , "effects": {"money": -50} } ],
  "tagsMonde": ["penurie_croissants"],
  "texteFin": "Fin de la pénurie : le croissant redevient un droit humain.",
  "suites": ["mon_0002"],
  "chanceSuite": 0.3
}
```

### Champs

| Champ | Obligatoire | Sens |
|---|---|---|
| `id` | oui | unique dans tout le jeu. Préfixe `mon_` + 4 chiffres. Les événements internes : `<id du flash>_e1`, `_e2`… |
| `rubrique` | oui | `economie`, `politique`, `science`, `insolite`, `meteo`, `sport`, `people`, `sante`, `tech`, `international` |
| `titre` | oui | le gros titre, en MAJUSCULES, court (≤ 60 caractères) |
| `texte` | oui | 1 à 3 phrases, ton de JT décalé |
| `poids` | non (1) | fréquence relative : 1 très rare, 10 courant |
| `duree` | non (0) | nombre d'années où les effets durent. **0 = flash pour rire, aucun effet durable** |
| `unique` | non (true) | une seule fois par vie |
| `minAge` / `maxAge` | non | âge du joueur entre lesquels le flash peut sortir |
| `requiertTagsMonde` | non | ne sort que si ces tags monde sont actifs (pour une suite) |
| `excluTagsMonde` | non | ne sort pas si un de ces tags monde est actif |
| `suiteSeulement` | non (false) | ne sort jamais au hasard, seulement comme suite d'un autre flash ou déclenché par un module (politique, bourse) |
| `modificateurs` | non | voir plus bas, valables pendant `duree` années |
| `effetsImmediats` | non | appliqués une fois, l'année du flash |
| `effetsAnnuels` | non | appliqués chaque année tant que le flash est actif (y compris la première) |
| `evenements` | non | événements au format habituel (`docs/ARCHITECTURE.md`) qui ne peuvent arriver **que** pendant le flash |
| `tagsMonde` | non | tags actifs pendant le flash. Ils deviennent des tags joueur `monde_<tag>` utilisables dans `conditions.tags` de n'importe quel événement |
| `texteFin` | non | ligne écrite dans le journal quand les effets s'arrêtent |
| `suites` / `chanceSuite` | non | à la fin, `chanceSuite` (défaut 0.5) de publier un de ces flashs l'année suivante |

### Modificateurs

Ce sont des **multiplicateurs** (1.0 = rien ne change, 1.3 = +30 %, 0.5 = moitié prix). Bornés entre 0.1 et 10.
Quand plusieurs flashs sont actifs, les multiplicateurs se multiplient. `tout` s'applique à toutes les clés de la table.

- `prix` : `immobilier`, `voitures`, `bateaux`, `avions`, `bijoux`, `voyages`, `nourriture`, `tech`, `luxe`, `animaux`, `sante`, `etudes`, `loisirs`, `vetements`, `tout`
- `salaires` (secteurs) : `restauration`, `commerce`, `transport`, `batiment`, `beaute`, `securite`, `administration`, `medias`, `immobilier`, `tech`, `finance`, `arts`, `science`, `education`, `droit`, `sante`, `sport`, `politique`, `tout`
- `evenements.categories` : catégorie d'événement (`category`), ex. `travail`, `argent`, `amour`, `sante`, `crime`, `absurde`, `ecole`, `vieillesse`…
- `evenements.prefixes` : début d'`id` d'événement, ex. `"tra_"`
- `marches` : `bourse`, `crypto`, `or`, `immobilier_locatif` (pour le futur module placements)
- `mortalite` : multiplie la chance de mourir chaque année
- `retraite` : multiplie la pension

### Effets sur le joueur (`effetsImmediats`, `effetsAnnuels`)

Liste d'objets `{ "tags": [...], "excludeTags": [...], "text": "...", "effects": { ... } }`.
`effects` = mêmes clés que les événements (`happiness`, `health`, `smarts`, `looks`, `karma`, `money`, `relationships`…).
`tags` / `excludeTags` = tags joueur (`job`, `rich`, `poor`, `retired`, `baby`…), pour viser une partie des joueurs.
Pour `money`, préférez des montants modestes (le jeu est en euros, un salaire va de 28 000 à 280 000 €/an).

## Ton

Original, absurde, jamais méchant envers un groupe réel. Pas de vraies personnes ni de vraies marques.
Pays et villes inventés bienvenus (la Bordurie du Nord, Saint-Glinglin-sur-Mer…). Français, phrases courtes, chute drôle.
