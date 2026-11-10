# Jeux télé et téléréalité

Module : `FTCHTLife/Tele/`. Données : `FTCHTLife/Resources/Data/Tele/` et `FTCHTLife/Resources/Data/Events/tele_*.json`.
Vérification des données : `python3 tools/validate_tele.py`.

Toutes les émissions sont **inventées** (noms, présentateurs, candidats, marques). On parodie le genre, pas une émission réelle.

## Ce que le joueur peut faire

Un écran « Télévision » (`TeleView`) qui propose :

| Émission | Type | Âge | Casting testé sur |
|---|---|---|---|
| **Cerveau ou Râteau** | quiz de culture générale, 10 questions, chrono, 3 jokers, palier à 5 000 €, jusqu'à 250 000 € | 10+ | intelligence et bonheur |
| **Les Naufragés de l'Île Moustique** | survie sur une île, épreuves, conseil d'élimination | 18–60 | santé |
| **Villa Paillettes** | téléréalité en villa, clashs, couples, vote du public | 18–35 | apparence |
| **Toque ou Toc** | concours de cuisine, jury, épreuves | 16+ | talent caché de cuisine |
| **Star d'un Soir** | télé-crochet, auditions, buzzers | 12+ | talent caché de voix |

Chaque émission se tente **une fois par an** (clé `tele_<id>` dans `actionsAnnee`).

**Célébrité éphémère** : chaque passage à la télé donne de la célébrité (0–100), qui **fond de 35 % par an**.
Tant qu'elle est haute, des **offres** arrivent (placement de produit, inauguration de supermarché, autobiographie, single de l'été…),
et des événements de retombées peuvent arriver.

**Moments cultes** : certains résultats (souvent humiliants) restent dans la mémoire du public (`momentsCultes`),
rapportent un peu de célébrité, et ressortent dans les événements de retombées via `{culte}`.

**Talents cachés** : chaque vie tire une voix et un talent de cuisine (0–100), invisibles. On les découvre en passant les castings.

**Couple à l'écran** : dans la villa, on peut finir en couple avec `{crush}`. À la sortie, ça devient un vrai partenaire
(ou un drame si le joueur était déjà en couple).

## Branchement dans le moteur (fil moteur)

1. **Ouvrir l'écran** : ajouter une activité, par ex.
   `Activite(id: "tele", titre: "Télévision", icone: "tv.fill", ageMin: 10, cout: 0, description: "Quiz, téléréalité et gloire éphémère.")`
   et présenter `TeleView().environmentObject(engine)` au lieu d'appeler `faireActivite` pour cette activité.
2. **Sauvegarde** (conseillé) : ajouter `var tele: TeleEtat?` dans `Joueur`, puis au lancement de l'app :
   ```swift
   TeleStockage.lire = { $0.tele ?? TeleEtat() }
   TeleStockage.ecrire = { j, etat in j.tele = etat }
   ```
   En attendant, le module range son état dans `UserDefaults`, une entrée par vie : il marche sans ce changement.
3. **Tags** pour les événements de retombées : dans `tags(_:)`, ajouter `t.formUnion(GameEngine.teleTags(j))`.
   Tags : `tv_candidat` (déjà passé à la télé), `tv_star` (célébrité ≥ 40), `tv_has_been` (déjà passé, célébrité < 15),
   `tv_winner` (a déjà gagné une émission), `tv_culte` (a au moins un moment culte).
   Sans ce branchement, les événements `Events/tele_*.json` ne sortent simplement jamais.
4. **Variable `{culte}`** dans les événements : dans `remplir`, appeler d'abord `t = GameEngine.teleRemplir(t, j)`.
5. Optionnel : l'effet `fame` des événements peut alimenter la célébrité avec
   `var e = TeleStockage.lire(j); e.ajouterCelebrite(fame, age: j.age); TeleStockage.ecrire(&j, e)`.

Le module n'a pas besoin de crochet annuel : la célébrité fond toute seule (calculée à partir de l'âge).

## Format : émission à manches (`Data/Tele/Emissions/*.json`)

Chaque fichier est un tableau d'émissions.

```json
{
  "id": "ile",
  "nom": "Les Naufragés de l'Île Moustique",
  "slogan": "40 jours, 12 inconnus, 1 noix de coco.",
  "icone": "leaf.fill",
  "ageMin": 18,
  "ageMax": 60,
  "casting": {
    "stat": "sante",
    "difficulte": 35,
    "acceptes": ["La production t'appelle : tu pars dans 3 jours. Prends un maillot et ta dignité, on te rendra l'un des deux."],
    "refus": ["Au casting, tu as demandé s'il y avait le wifi sur l'île. Refusé·e."]
  },
  "prix": 100000,
  "cachet": 2000,
  "celebriteVictoire": 35,
  "intro": ["Un hélicoptère te largue sur une plage avec onze inconnus et un caméraman qui a déjà le mal de mer."],
  "manches": [
    {
      "titre": "Semaine 1",
      "situations": [
        {
          "id": "ile_s1_01",
          "texte": "Il faut construire un abri avant la nuit. {rival} a déjà pris le commandement et la seule bâche.",
          "choix": [
            {
              "label": "Construire seul·e une cabane",
              "stat": "sante",
              "difficulte": 45,
              "reussite": [
                { "texte": "Ta cabane tient debout. Elle a même une fenêtre. Le camp te regarde comme un dieu.", "points": 2, "effets": { "fame": 3 } }
              ],
              "echec": [
                { "texte": "Ta cabane s'effondre sur toi en direct.", "points": -1, "effets": { "health": -5 }, "culte": "la cabane qui s'effondre sur {prenom}" }
              ]
            }
          ]
        }
      ]
    }
  ],
  "eliminations": ["Le conseil a parlé. Tu repars avec ton sac, une barbe de 3 semaines et une rancune de 30 ans."],
  "victoires": ["Tu gagnes « {emission} » ! {gain} et un collier de coquillages."],
  "defaitesFinale": ["Tu perds la finale contre {rival} sur une épreuve d'équilibre. Tu en rêveras jusqu'à ta mort."]
}
```

- **Une manche = une situation** tirée au hasard dans `situations`. Mettez-en plusieurs par manche pour varier les parties.
- **Choix** : `stat` est testée contre `difficulte`. Chance de réussite = 50 % quand stat = difficulté, ±1 % environ par point d'écart, bornée à 8 %–92 %.
- **Stats** : `sante`, `bonheur`, `intelligence`, `apparence`, `karma`, `charisme` (moyenne apparence et bonheur),
  `voix` et `cuisine` (talents cachés), `celebrite`, `hasard` (toujours 50 : pile ou face).
- **Résultat** : un tiré au hasard dans `reussite` ou `echec`.
  - `points` de -3 à 3 : à la fin de la manche, chance de rester = 55 % + 15 % par point. En finale (dernière manche),
    chance de gagner = 35 % + 12 % par point de la manche + 3 % par point cumulé.
  - `effets` : mêmes clés que les événements (`happiness`, `health`, `smarts`, `looks`, `karma`, `money`, `relationships`, `death`…).
    `fame` = célébrité gagnée ou perdue.
  - `culte` : groupe nominal qui décrit un moment culte, vu par le public, par ex. « la cabane qui s'effondre sur {prenom} ».
    Il sera réutilisé dans d'autres phrases (« Internet ressort encore {culte} », jamais « de {culte} » ni « à {culte} » qui donneraient « de le », « à le »), donc : pas de majuscule, pas de point final.
  - `couple: true` : le joueur se met en couple avec `{crush}` ; `rupture: true` : le couple explose.
- **Variables** : celles des événements (`{prenom}`, `{e}`, `{mere}`, `{partenaire}`…) plus
  `{emission}` (nom de l'émission), `{rival}` (un·e autre candidat·e, le même pendant toute l'émission),
  `{crush}` (le crush de l'émission), `{gain}` (dans `victoires`).
  `{rival}` et `{crush}` peuvent être des hommes ou des femmes : **pas d'accord** qui dépend d'eux (écrire « {rival} te fixe », pas « {rival} est furieux »).
  Pour le joueur, utilisez `{e}` (accords simples) ou des tournures neutres ; « ·e » est accepté dans les textes courts.
- **Mort** : `"death": "…"` dans `effets` est permis, très rarement (une ou deux fois par émission, et seulement sur des choix stupides).

## Format : quiz (`Data/Tele/Quiz/*.json`)

```json
{ "id": "qz_0001", "niveau": 1, "theme": "Géographie", "question": "Quelle est la capitale de l'Italie ?",
  "bonne": "Rome", "mauvaises": ["Milan", "Naples", "Pizza"] }
```

- `niveau` 1 (facile, questions 1–3), 2 (moyen, 4–7), 3 (difficile, 8–10).
- Exactement 3 mauvaises réponses, toutes différentes de la bonne. Une mauvaise réponse absurde par question, au maximum, pour l'humour.
- Faits **vérifiés** et stables dans le temps (pas de « actuel président », pas de records qui changent).

## Format : offres de célébrité (`Data/Tele/Offres/*.json`)

```json
{ "id": "of_inauguration", "titre": "Inaugurer un supermarché", "description": "Couper un ruban devant 40 retraités.",
  "icone": "scissors", "celebriteMin": 20, "ageMin": 16, "gain": [800, 3000],
  "textes": ["Tu coupes le ruban du Hyper Discount de Saint-Glinglin. On te paie {gain} et un bon d'achat pour des lardons."],
  "effets": { "happiness": 3 },
  "risque": 0.1, "textesRates": ["Le ruban était en fait le câble de la sono."], "effetsRates": { "fame": -3, "happiness": -5 } }
```

Gain réel = tirage dans `gain` × (célébrité actuelle / 50), au moins 30 %. Une offre se prend une fois par an.

## Événements de retombées (`Data/Events/tele_*.json`)

Format normal des événements (voir `docs/ARCHITECTURE.md`), ids `tel_NNNN`, catégorie `tele`,
avec un des tags `tv_candidat`, `tv_star`, `tv_has_been`, `tv_winner`, `tv_culte` dans `conditions.tags`.
`{culte}` n'est utilisable qu'avec le tag `tv_culte`.
