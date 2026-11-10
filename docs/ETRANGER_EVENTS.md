# Événements « Vivre à l'étranger » : consignes d'écriture

Fichiers : `FTCHTLife/Resources/Data/Events/etranger_<groupe>.json` (format standard du moteur, voir `docs/ARCHITECTURE.md`).
Vérification : `python3 tools/validate_etranger.py`.

## Ton

- Français, tutoiement, humour décalé et absurde du jeu. 100 % original.
- **On rit de la situation et de la maladresse du joueur, jamais d'un peuple.** Le joueur est l'étranger
  qui ne comprend pas encore : c'est lui le ridicule, et les habitants sont accueillants, drôles, malins.
- Pas de clichés blessants : rien sur la pauvreté, la criminalité, la saleté, la corruption, la religion
  tournée en dérision, la politique, la guerre, les accents moqués, l'apparence physique d'un peuple.
  On peut parler de nourriture, de météo, de transports, de paperasse, de fêtes, de sport, de langue,
  de coutumes de politesse, de musique, de cinéma, de familles envahissantes et accueillantes.
- Les coutumes réelles sont décrites avec justesse et tendresse (voir `coutumes` et `lois` dans
  `Data/Etranger/pays.json`) ; ne recopie pas ces phrases, invente des situations autour.
- Les habitants peuvent avoir le dernier mot et être plus drôles que le joueur.

## Structure

- `id` : `etr_<pays>_NNN` (ex. `etr_jp_001`), `etr_gen_NNN` (générique), `etr_lng_NNN` (langue), `etr_ret_NNN` (retour au pays).
- `category` : `"etranger"`.
- `minAge` 18, `maxAge` 100 en général (adapter si le sujet l'exige : boîte de nuit ≤ 45, etc.).
- `weight` : 6 à 10 pour les événements courants, 2 à 4 pour les rares.
- 2 à 3 choix (labels de 1 à 5 mots), 1 à 3 issues par choix avec `chance` (somme = 1).
- Effets modestes (±1 à ±8), `money` en euros réalistes (−20 à −500 en général, plus rarement ±2 000).
- Placeholders autorisés : `{prenom}`, `{nom}`, `{ville}` (ville où vit le joueur), `{mere}`, `{pere}`, `{parent}`, `{ami}`,
  `{fratrie}`, `{partenaire}`, `{metier}`, `{e}` (accord simple du joueur, ex. `perdu{e}`).
- Pas de `{e}` sur des mots irréguliers (pas « heureux{e} »).

## Tags du module (dans `conditions.tags` / `excludeTags`)

| Tag | Quand |
|---|---|
| `etranger` | le joueur vit dans un pays qui n'est pas son pays de naissance |
| `pays_<id>` | pays où vit le joueur (`pays_jp`, `pays_de`…) |
| `zone_<zone>` | zone du pays : `ue`, `europe`, `amerique`, `afrique`, `asie`, `oceanie` |
| `expat_nouveau` | étranger, arrivé il y a moins de 2 ans |
| `expat_installe` | étranger, installé depuis 5 ans ou plus |
| `langue_faible` | étranger, parle mal la langue du pays (< 40/100) |
| `bilingue` / `polyglotte` | 2 / 3 langues ou plus à 60+ |
| `binational` | a obtenu une deuxième nationalité |
| `de_retour` | rentré dans son pays de naissance depuis moins de 3 ans, après 2 ans ou plus ailleurs |
| `loi_<id>` | une loi ou règle du pays (`loi_conduite_gauche`, `loi_tri_dechets`…, voir pays.json) |

Plus les tags du moteur (`job`, `partner`, `children`, `rich`, `poor`, …).

Chaque événement exige au moins un tag du module.
- Événement d'un pays : `"tags": ["etranger", "pays_jp"]`.
- Malentendu de langue : ajouter `langue_faible`.
- Événement générique d'expatrié : `"tags": ["etranger"]` (+ `expat_nouveau`, `expat_installe`…).

## Exemple

```json
{
  "id": "etr_de_001",
  "category": "etranger",
  "minAge": 18, "maxAge": 100, "weight": 8, "unique": false,
  "conditions": { "tags": ["etranger", "pays_de"] },
  "text": "Dimanche matin, à {ville}. Tu as très envie de passer l'aspirateur.",
  "choices": [
    { "label": "Passer l'aspirateur", "outcomes": [
      { "chance": 0.7, "text": "Un mot plastifié apparaît sur ta porte dans l'heure. Il est poli, daté et signé.", "effects": { "happiness": -3, "karma": -2 } },
      { "chance": 0.3, "text": "Personne n'a rien dit. Tu ne sauras jamais si c'est pire.", "effects": { "happiness": -1 } }
    ]},
    { "label": "Attendre lundi", "outcomes": [
      { "chance": 1, "text": "Tu passes la journée à lire en silence. Tu deviens un peu allemand de l'intérieur.", "effects": { "happiness": 2, "smarts": 1 } }
    ]}
  ]
}
```
