# Données : relations, crime, santé, générations

Ce document décrit le **format d'écriture** du contenu du module amour / crime / santé / générations.
Le contenu brut est converti vers les formats du jeu par `python3 tools/convertir_vie.py <dossier_brut>` :

| Contenu brut | Fichier du jeu | Format |
|---|---|---|
| `relations/events*.json`, `crime/events.json`, `crime/prison_events.json`, `health/events.json` | `Data/Events/vie_*.json` | événements (docs/ARCHITECTURE.md), drapeaux → tags, `bond` → `relationships`, effets en plus → sous-objet `"vie"` (`VieEffets`) |
| événements `followUpOnly` | `Data/Repercussions/vie_suites.json` | règles de Répercussions (`rep_vie_NNNN`, signal `vie_suite`), programmées par `"followUps"` |
| `crime/crimes.json` | `Data/Crime/crimes.json` | `CrimeDefinition` |
| `crime/prison_activities.json` | `Data/CrimePrison/activites.json` | `CrimeActivitePrison` |
| `health/diseases.json`, `alternatives.json`, `addictions.json` | `Data/Health/`, `Data/HealthAlternatives/`, `Data/HealthAddictions/` | `SanteMaladie`, `SanteAlternative`, `SanteAddiction` |
| `relations/milestones.json` | `Data/Relationships/etapes.json` | `VieEtape` (petits messages d'après) |
| `relations/names.json`, `dialogues.json` | `Data/RelationshipsTexts/` | objets (prénoms, répliques) |

On peut aussi éditer directement les fichiers du jeu. Textes en français, ton décalé et original.

Tags ajoutés par le module (`VieSysteme.tags`) : `prison`, `record`, `malade`, `bien_portant`, `addiction`, `pregnant`, `ex`,
`parents`, `grandparents`, `grandchildren`, `dating`, `engaged`, `married`, `single`. Variables de texte en plus : `{enfant}`, `{ex}`, `{codetenu}`, `{grandparent}`.

## Événements (`relations/events*.json`, `crime/events*.json`, `crime/prison_events*.json`, `health/events*.json`)

Tableau d'objets :

```json
{
  "id": "rel_partenaire_karaoke",
  "category": "relation",
  "minAge": 18,
  "maxAge": 120,
  "weight": 1.0,
  "requires": ["hasPartner"],
  "excludes": ["inPrison"],
  "text": "{partenaire} veut absolument chanter un duo au karaoké du camping.",
  "choices": [
    {
      "label": "Chanter à fond",
      "outcomes": [
        { "chance": 0.7, "text": "Standing ovation. {partenaire} t'aime encore plus.", "effects": { "happiness": 6, "bond": 10 } },
        { "chance": 0.3, "text": "Tu as raté toutes les notes. Le camping s'en souviendra.", "effects": { "happiness": -4, "looks": -1 } }
      ]
    },
    { "label": "Prétendre une extinction de voix", "outcomes": [ { "chance": 1.0, "text": "{partenaire} boude.", "effects": { "bond": -6 } } ] }
  ]
}
```

- `category` : `relation`, `crime`, `prison`, `sante`.
- `requires` / `excludes` : drapeaux (voir plus bas). Tous les `requires` doivent être vrais, aucun `excludes`.
- `choices` : 1 à 4 choix. Un événement sans choix à faire a un seul choix `"label": "OK"`.
- `outcomes` : les `chance` d'un choix totalisent 1.0.
- Variables de texte : `{prenom}` (le joueur), `{partenaire}`, `{enfant}`, `{ami}`, `{parent}`, `{fratrie}`, `{ex}`, `{codetenu}`. Une variable n'est utilisable que si le drapeau correspondant est dans `requires` (`hasPartner`, `hasChildren`, `hasFriends`, `hasParents`, `hasSiblings`, `hasEx`, `inPrison`).

### Drapeaux

`hasPartner`, `isDating`, `isEngaged`, `isMarried`, `single`, `hasChildren`, `hasFriends`, `hasParents`, `hasSiblings`, `hasEx`, `inPrison`, `hasRecord` (casier judiciaire), `isSick`, `isHealthy`, `lowHealth` (santé < 30), `rich` (argent > 100000), `poor` (argent < 1000), `male`, `female`, `hasAddiction`.

### Effets (tous optionnels, entiers)

| clé | effet |
| --- | --- |
| `health`, `happiness`, `smarts`, `looks`, `karma` | statistique du joueur (0–100) |
| `money` | argent en euros (peut être négatif) |
| `bond` | lien avec la personne citée dans le texte (0–100) |
| `jailMonths` | envoie en prison (mois) |
| `fine` | amende en euros |
| `record` | `1` ajoute une ligne au casier |

Effets spéciaux (chaînes) : `"disease": "grippe"` (attrape la maladie), `"cure": true` (guérit une maladie au hasard), `"breakup": true` (rupture avec le partenaire), `"newFriend": true`, `"newPartner": true`, `"pregnancy": true`, `"addiction": "alcool"`, `"death": "texte de la cause"`, `"targetDies": true` (la personne citée meurt).

## Crimes (`crime/crimes.json`)

```json
{
  "id": "vol_etalage",
  "name": "Vol à l'étalage",
  "icon": "cart",
  "minAge": 8,
  "difficulty": 0.25,
  "arrestChance": 0.25,
  "lootMin": 5, "lootMax": 150,
  "karma": -3,
  "sentenceMinMonths": 0, "sentenceMaxMonths": 6,
  "fineMin": 100, "fineMax": 800,
  "successTexts": ["Tu repars avec un paquet de chips et ta dignité intacte."],
  "failTexts": ["Le vigile t'a vu. Il a juste soupiré."],
  "arrestTexts": ["Le vigile ancien rugbyman t'a plaqué sur les surgelés."]
}
```

`difficulty` 0–1 (réduite par l'intelligence et l'expérience criminelle). `icon` = nom SF Symbol.

## Maladies (`health/diseases.json`)

```json
{
  "id": "grippe",
  "name": "Grippe",
  "description": "Fièvre, courbatures et envie de mourir sous la couette.",
  "minAge": 0, "maxAge": 120,
  "yearlyChance": 0.06,
  "severity": 1,
  "chronic": false,
  "contagious": true,
  "healthPerYear": -6,
  "happinessPerYear": -4,
  "deathChancePerYear": 0.001,
  "selfHealChance": 0.6,
  "cure": { "doctor": 0.8, "hospital": 0.95, "alternative": 0.15 },
  "costDoctor": 50, "costHospital": 2000
}
```

`severity` 1–5. `chronic: true` = ne guérit jamais, on ne peut que soulager.

## Médecines alternatives (`health/alternatives.json`)

```json
{ "id": "chaman", "name": "Chaman du parking", "cost": 300, "cureBonus": 0.05, "texts": ["Il a soufflé de la fumée de sauge sur ta carte Vitale."] }
```

## Noms (`relations/names.json`)

`{ "male": [...], "female": [...], "last": [...] }`

## Suites d'événements (`*/followups.json`)

Même format que les événements, avec en plus `"followUpOnly": true` : ces événements ne sont jamais tirés au hasard, ils n'arrivent que parce qu'une issue les a programmés.

Une issue programme une suite avec deux effets :

```json
"effects": { "happiness": 5, "followUp": "rel_suite_karaoke_video_virale", "followUpYears": 1 }
```

`followUpYears` : dans combien d'années (0 = à la fin de l'année en cours, défaut 1). La suite garde la même personne ciblée si elle est encore en vie. Une suite peut elle-même programmer une autre suite (chaînes d'histoires).

## Petits messages d'après (`relations/milestones.json`)

Messages courts sans choix, ajoutés au journal quand une étape est atteinte :

```json
{ "id": "ms_enfant_premiers_pas", "kind": "child", "trigger": "age", "value": 1, "texts": ["{nom} a fait ses premiers pas. Direct vers la prise électrique."], "effects": { "happiness": 2 } }
```

- `kind` : `child`, `grandchild`, `spouse`, `partner`, `fiance`, `friend`, `bestFriend`, `ex`, `mother`, `father`, `brother`, `sister`, `self`.
- `trigger` : `age` (âge de la personne, ou du joueur pour `self`), `years` (années passées ensemble, pour `partner`/`fiance`/`spouse`), `chance` (`value` = probabilité par an, message aléatoire de vie quotidienne).
- `{nom}` = prénom de la personne, `{prenom}` = le joueur. `effects` facultatif (même clés, `bond` vise la personne).
