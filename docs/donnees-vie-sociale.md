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

# Le Milieu : crime organisé (drogue, gangs, mafias)

Ton **sérieux** en priorité (comme la politique) : violence, peur, loyauté, argent facile qui coûte cher. Un peu d'ironie noire est permise, pas de gags. Jamais de détail réaliste de fabrication de drogue, d'armes ou de mode opératoire : on reste au niveau du récit (« tu récupères un lot », « la livraison se passe mal »). Organisations, villes et personnages fictifs.

Code : `FTCHTLife/Systems/VieMilieu.swift`. État : `VieEtat.milieu` (`VieMilieuEtat?`).

## Organisations (`Data/Milieu/*.json`)

```json
{
  "id": "les_corbeaux",
  "nom": "Les Corbeaux",
  "type": "gang",
  "description": "Un gang de cité qui tient trois halls d'immeubles et rêve de la ville entière.",
  "rangs": ["Guetteur", "Vendeur", "Gérant de point", "Lieutenant", "Chef"],
  "minAge": 14,
  "notorieteMin": 0,
  "dangerosite": 2,
  "specialites": ["trafic", "racket"],
  "rivaux": ["clan_sabatier"],
  "textesRecrutement": ["Un grand du quartier t'observe depuis des semaines. Aujourd'hui, il te fait signe d'approcher."],
  "textesRefus": ["« Reviens quand t'auras fait tes preuves. » La porte se referme."]
}
```

`type` : `gang`, `mafia`, `cartel`, `clan`, `reseau`. `rangs` : exactement 5, du plus bas au chef. `dangerosite` 1–5 (risques et gains). `specialites` parmi `trafic`, `racket`, `braquage`, `contrebande`, `cyber`, `jeux`, `blanchiment`.

## Missions (`Data/MilieuMissions/*.json`)

```json
{
  "id": "livraison_nocturne",
  "nom": "Livraison de nuit",
  "icon": "car.fill",
  "type": "livraison",
  "rangMin": 0,
  "specialite": "trafic",
  "difficulte": 0.3,
  "risqueArrestation": 0.15,
  "risqueBlessure": 0.05,
  "gainMin": 300, "gainMax": 1500,
  "respect": 4, "chaleur": 6, "karma": -3,
  "peineMinMois": 6, "peineMaxMois": 24,
  "textesReussite": ["…"], "textesEchec": ["…"], "textesArrestation": ["…"], "textesBlessure": ["…"]
}
```

`type` : `livraison`, `guet`, `vente`, `racket`, `intimidation`, `braquage`, `contrebande`, `cyber`, `recouvrement`, `guerre`, `blanchiment`, `evasion_fiscale`, `protection`. `rangMin` 0–4. `specialite` facultative (mission réservée aux organisations qui l'ont). Gains en **argent sale** (à blanchir).

## Marchandises (`Data/MilieuProduits/*.json`)

```json
{ "id": "cannabis", "nom": "Cannabis", "prixLot": 2000, "reventeMin": 2600, "reventeMax": 4500, "chaleur": 8, "peineMinMois": 6, "peineMaxMois": 36, "rangMin": 1, "description": "…" }
```

## Événements du Milieu (`Data/Events/vie3_*.json`)

Format commun des événements (docs/ARCHITECTURE.md). Tags ajoutés : `gang` (membre d'une organisation), `gang_haut` (lieutenant ou chef), `dealer` (a un trafic en cours), `sous_enquete` (enquête de police en cours), `chaleur` (attention policière ≥ 60), `ancien_gang` (a quitté le milieu), `balance` (a témoigné contre son organisation), `argent_sale` (≥ 10 000 € à blanchir).
Variables en plus : `{organisation}`, `{chef}`, `{rival}`, `{rang}`.

Effets en plus, dans le sous-objet `"vie"` : `milieuRespect` (±), `milieuChaleur` (±), `milieuLoyaute` (±), `argentSale` (±, euros), `enquete` (`true` ouvre une enquête, `false` la classe), `quitterMilieu` (`true`), `promotion` (`true`), `saisie` (`true` : le stock du trafic est saisi), plus les effets existants (`jailMonths`, `fine`, `record`, `targetDies`…).

Signaux émis (Répercussions) : `gang_entree`, `gang_promotion`, `gang_trahison`, `gang_sortie`, `gang_chef`, `trafic_debut`, `trafic_saisie`, `enquete_ouverte`, `enquete_classee`, `guerre_territoire`, `blanchiment`, `balance`, `mission_reussie`, `mission_ratee`.

## Le business du trafic et les casses

Code : `FTCHTLife/Systems/VieTrafic.swift` (business), `VieCoups.swift` (casses), `VieTraficVue.swift` (écrans « Ton business » et « Monter un coup », ouverts depuis « Le Milieu »).

### Données

- `Data/MilieuZones/*.json` : quartiers `{id, nom (avec l'article), description, taille, police, prix, entree, rangMin, clientele, preferences: {produitId: multiplicateur}}`.
- `Data/MilieuConcurrents/*.json` : concurrents `{id, nom, style (agressif|discount|premium|discret), description, force, prix (écart en %), qualite (coupee|standard|premier), zones: [ids, vide = partout]}`.
- `Data/MilieuProduits` : champ en plus `demandeBase` (lots demandés par an dans un quartier moyen).
- `Data/MilieuCoups/*.json` : cibles de casse `{id, nom, description, icon, minAge, notorieteMin, difficulte, butinMin, butinMax, peineMinMois, peineMaxMois, chaleur, roles, reperageCout}`. Rôles : chauffeur, guetteur, perceur, informaticien, gros_bras, infiltre.

### Mécanique (chaque année)

Pour chaque marchandise et chaque quartier : demande (base × taille du quartier × préférence × cours du marché), part de marché (qualité du fournisseur, prix choisi, fidélité, stratégie, face au prix et à la force du concurrent), puis limite par la capacité du réseau (4 lots par revendeur, payés 1 500 € par an plus 12 % des ventes) et par le stock. Chiffre d'affaires moins salaires et sécurité = bénéfice en argent sale. Les concurrents réagissent (baisse de prix, renforts), la tension monte et peut finir en attaque. Au plus un dilemme par an (revendeur arrêté, vol interne, overdose, pénurie, gros client, policier corrompu, mineurs, taxe d'une organisation pour les indépendants, accord de partage). Sans réponse, il se règle tout seul l'année suivante, avec l'option par défaut.

Limites : indépendant 1 marchandise, 2 quartiers, 4 revendeurs ; membre 1 + rang marchandises (max 4), 1 + rang + territoires quartiers (max 6), 4 + 4 × rang + 2 × territoires revendeurs (max 30).

### Pour les événements

- Tags : `dealer`, `dealer_gros`, `guerre_prix`, `rupture_stock`, `independant`, `a_revendeurs`, `produit_drogue` (marchandise principale = drogue), `coup_prepare`, `braqueur`.
- Effets `vie` en plus : `clients`, `revendeurs`, `tension`, `stock` (entiers, en plus ou en moins).
- Variables : `{produit}`, `{zone}`, `{concurrent}` (les noms de quartiers et de concurrents portent leur article : écrire « dans {zone} », « chez {concurrent} », jamais « de {zone} »).
- Signaux : `trafic_zone`, `trafic_guerre_prix`, `trafic_revendeur_arrete`, `trafic_overdose`, `coup_reussi`, `coup_rate`, `coup_trahison`.
