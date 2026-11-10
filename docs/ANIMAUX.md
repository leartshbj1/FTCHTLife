# Animaux de compagnie

Le joueur peut adopter des animaux (refuge, animalerie, animaux exotiques). Chaque animal a une **espèce**,
un **caractère** (peureux, voleur, jaloux, génie…), un âge, un lien avec le joueur et une santé.
Il vieillit, tombe malade, peut fuguer ou mourir, et déclenche **ses propres événements** selon son caractère
et son espèce. Les animaux disparus restent dans « Au paradis des animaux ».

Code : `FTCHTLife/Animaux/`. Données : `FTCHTLife/Resources/Data/Animaux/`.
Vérification : `python3 tools/validate_animaux.py`.

## Données

| Dossier | Contenu |
|---|---|
| `Animaux/Especes/*.json` | espèces (tableau d'`AnimalEspece`) |
| `Animaux/Caracteres/*.json` | caractères (tableau d'`AnimalCaractere`) |
| `Animaux/Evenements/*.json` | événements d'animaux (tableau d'`AnimalEvenement`) |

### Espèce

```json
{ "id": "chat", "nom": "Chat", "article": "le", "emoji": "🐈", "categorie": "commun",
  "prix": 150, "prixRefuge": 60, "entretien": 600, "esperanceVie": [12, 20],
  "promenable": false, "cri": "miaule", "ageMinJoueur": 4,
  "description": "Te tolère chez lui.", "noms": ["Moustache", "Pistache"],
  "caracteres": null }
```

- `article` : `le`, `la` ou `l'` (sert à écrire « ton chat », « ta chèvre », « l'iguane »).
- `categorie` : `commun` (refuge et animalerie) ou `exotique` (vendeur d'animaux exotiques, 18 ans et plus).
- `entretien` : coût par an, payé par le joueur majeur (les parents paient avant 18 ans).
- `esperanceVie` : [âge où la vieillesse commence, âge maximal ordinaire].
- `caracteres` : liste des caractères possibles pour cette espèce (absent = tous).

### Événement d'animal

Un événement concerne **un** animal précis du joueur. Chaque année, chaque animal a environ une chance sur trois
d'en déclencher un (deux au plus par an pour tous les animaux).

```json
{
  "id": "ani_vol_0001",
  "especes": ["chat", "chien"],
  "caracteres": ["voleur"],
  "minAgeAnimal": 1, "maxAgeAnimal": 30,
  "minAge": 6, "maxAge": 120,
  "minLien": null, "maxLien": null,
  "malade": null, "vieux": null,
  "weight": 3,
  "unique": false,
  "conditions": { "tags": ["partner"] },
  "text": "{animal} a volé la culotte de la voisine et l'a posée sur ton paillasson.",
  "choices": [
    { "label": "La rendre en s'excusant",
      "outcomes": [
        { "chance": 0.6, "text": "La voisine a rougi et t'a invité{e} à boire un café.", "effects": { "happiness": 4 } },
        { "chance": 0.4, "text": "La voisine a appelé la police.", "effects": { "happiness": -6, "karma": -2 }, "pet": { "bond": -3 } }
      ] }
  ]
}
```

- Tous les champs sauf `id` et `text` sont facultatifs. `id` commence par `ani_` et est unique.
- `especes` / `caracteres` : l'animal doit avoir l'une des espèces / l'un des caractères listés (absent = tous).
- `minAgeAnimal` / `maxAgeAnimal` : âge de l'animal. `minAge` / `maxAge` : âge du joueur.
- `minLien` / `maxLien` : lien avec l'animal (0-100).
- `malade` : `true` = seulement si l'animal est malade, `false` = seulement s'il est en bonne santé.
- `vieux` : `true` = seulement si l'animal a dépassé le début de sa vieillesse (`esperanceVie[0]`).
- `weight` : fréquence relative (défaut 1). Les événements de caractère valent 3 à 5, les autres 1 à 3.
- `unique` : une fois par animal.
- `conditions` : mêmes conditions que les événements du moteur (`gender`, `minMoney`, `tags`…).
- Sans choix : `"effects"` et `"pet"` à la racine, le texte va dans le journal.
- `chance` d'une issue : poids relatif (défaut 1).

**Effets sur le joueur** (`effects`) : les mêmes que les événements du moteur (`happiness`, `health`, `smarts`,
`looks`, `karma`, `money`, `relationships`, `newFriend`, `death`).

**Effets sur l'animal** (`pet`) :

| Clé | Effet |
|---|---|
| `bond` | variation du lien (points) |
| `health` | variation de la santé de l'animal (points) |
| `sick` | l'animal tombe malade : `"sick": "une indigestion de chaussettes"` |
| `cure` | `true` : l'animal guérit |
| `death` | l'animal meurt : `"death": "en voulant attraper un drone"` (suit « … est mort/morte ») |
| `runaway` | `true` : l'animal fugue pour toujours |
| `newPet` | un nouvel animal de cette espèce arrive (ex. `"chat"` : il ramène un chaton) |
| `trait` | l'animal change de caractère (ex. `"genie"` après un dressage miracle) |

**Variables** : celles du moteur (`{prenom}`, `{ami}`, `{partenaire}`, `{e}`…) et :

| Variable | Devient |
|---|---|
| `{animal}` | nom de l'animal (« Moustache ») |
| `{espece}` | « chat », « chèvre » |
| `{le_espece}` | « le chat », « la chèvre », « l'iguane » |
| `{ton_espece}` | « ton chat », « ta chèvre », « ton iguane » |
| `{cri}` | « miaule », « aboie »… (verbe au présent) |
| `{a}` | « e » si l'animal est une femelle (« {animal} est parti{a} ») |
| `{il}` / `{Il}` | « il » / « elle » selon le sexe de l'animal |
| `{caractere}` | caractère en minuscules (« voleur ») |

Préfixes d'id conseillés : `ani_<car>_NNNN` pour un caractère (`ani_peu_`, `ani_vol_`, `ani_jal_`, `ani_gen_`…),
`ani_<espèce>_NNNN` pour une espèce (`ani_chat_`, `ani_chien_`…), `ani_gen_` est réservé à « génie », donc
`ani_vie_` pour la vie courante, `ani_sante_` pour santé et vieillesse.

## Mécanique annuelle (code)

- L'animal prend un an, le lien baisse un peu (−4 à +1) si on ne s'en occupe pas.
- Santé : stable jusqu'à la vieillesse, puis −3 à −10 par an. Un animal malade perd 5 à 15 points par an
  tant qu'on ne l'emmène pas chez le vétérinaire.
- Mort : rare avant la vieillesse, de plus en plus probable ensuite, certaine à santé 0.
- Un animal négligé (lien < 15) peut fuguer.
- L'entretien de tous les animaux est prélevé chaque année (joueur majeur).

Actions (une fois par an chacune) : câliner, jouer, promener (espèces `promenable`), friandises, vétérinaire,
dresser. On peut aussi l'abandonner (karma en baisse). Un enfant doit convaincre ses parents.

## Branchement dans le moteur (fil moteur)

Le module ne touche pas aux fichiers du moteur. Tout passe par un chemin de clé vers l'état des animaux,
donc il compile seul.

1. `Joueur` (`Models/Models.swift`) : `var animaux: AnimauxEtat? = nil`.
2. `GameEngine.vieillir()`, juste après `j.journal.append(Annee(age: j.age, lignes: lignes))` :
   ```swift
   animauxAnnee(&j, cle: \.animaux)
   ```
3. `GameEngine.tags(_:)`, avant `return t` (facultatif, pour que les événements du moteur parlent des animaux) :
   ```swift
   t.formUnion(tagsAnimaux(j, cle: \.animaux))   // "pet", "pet_chat", "pet_chien"…
   ```
4. `MainView` : un bouton ou une entrée de menu qui ouvre `AnimauxView(cle: \.animaux)` (feuille avec
   `.environmentObject(engine)`), et le modificateur qui affiche les événements d'animaux à choix
   entre les années, à placer après le `.sheet` des événements :
   ```swift
   .animauxEvenements(cle: \.animaux)
   ```
   Il n'affiche une carte que lorsqu'aucun événement du moteur n'est en cours.

Signaux pour les répercussions (quand ce module sera fusionné) : `adoption_animal`, `deces_animal`,
`fugue_animal`, `abandon_animal`.
