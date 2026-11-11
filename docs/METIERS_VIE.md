# Métiers qui changent la vie

Chaque métier a ses propres moments de vie privée : le regard des proches, le couple, les enfants, la santé,
la réputation, l'argent. Ces moments suivent le métier **actuel** du joueur, et certains laissent une trace
qui le suit **après** (ancien flic, ancienne actrice X, ancien prêtre défroqué…).

Complète l'idée 43 (`Data/Events/vivant_metier_*.json`, par **secteur**) : ici, c'est **un métier précis**.

Données : `FTCHTLife/Resources/Data/Repercussions/metiers_vie_*.json`. Aucun code Swift : tout passe par
les états durables du module Répercussions (`"on": "chaque_annee"`, voir `docs/REPERCUSSIONS.md`).
Vérification : `python3 tools/validate_metiers_vie.py` (lance aussi `validate_repercussions.py`).

## Comment ça marche

Une carte est une règle `"on": "chaque_annee"` qui exige le tag du métier actuel (`metier_<id>`, posé par le
module Jeu vivant à partir de `j.carriere`). Chaque année, chaque carte possible a sa `chance` d'arriver.

```json
{
  "id": "rep_met_0001",
  "on": "chaque_annee",
  "chance": 0.07,
  "unique": true,
  "conditions": { "tags": ["metier_policier", "children"] },
  "text": "Ton fils raconte à toute sa classe que tu « mets les méchants en prison ». Un camarade répond que son oncle y est.",
  "choices": [ … ]
}
```

- `unique: true` sur toutes les cartes : une carte n'arrive qu'une fois par vie.
- `chance` : 0,06 à 0,08 pour une carte ordinaire. Un métier a 4 à 6 cartes : environ une carte tous les 3 ou
  4 ans pendant qu'on l'exerce. Une carte rare et lourde : 0,03.
- Le moteur garde au plus 3 événements à choix par an (`GameEngine.maxEvenementsAChoix`) et au plus 3 états
  durables affichés par an (`Repercussions.maxEtatsParAn`) : les cartes en trop attendent les années suivantes.
- En prison, aucune carte (le métier s'arrête de toute façon).

### Après le métier

Pour qu'un métier suive le joueur après l'avoir quitté :

1. Une règle **sans texte** pose un drapeau tant qu'on exerce le métier (elle ne compte pas dans les 3 états) :
   `{"id": "rep_met_0002", "on": "chaque_annee", "conditions": {"tags": ["metier_policier"]}, "remember": ["a_ete_policier"]}`.
2. Des cartes « après » exigent ce drapeau et excluent le métier :
   `"conditions": {"flags": ["a_ete_policier"], "excludeTags": ["metier_policier"]}`, avec `chance` 0,04 à 0,06.

Nom du drapeau : `a_ete_<id du métier>`. Les cartes peuvent aussi poser des drapeaux d'état communs
(`honte_publique`, `celebre_localement`, `burn_out`, `traumatise`, `dos_fragile`, `heros_local`… liste en bas
de `docs/REPERCUSSIONS.md`) qui ont déjà leurs suites, ou des drapeaux propres au métier réutilisés par une
autre carte (`flags` + `flagMinYears`).

## Écriture

- Français, tutoiement, `{e}` pour les accords du joueur (`fier{e}`). Pas d'écriture « ·rice » dans les textes.
- Variables : `{prenom}`, `{nom}`, `{ville}`, `{mere}`, `{pere}`, `{parent}`, `{ami}`, `{fratrie}`, `{partenaire}`,
  `{enfant}`, `{metier}` (intitulé du poste). Une carte qui nomme `{partenaire}` exige le tag `partner`,
  `{enfant}` → `children`, `{ami}` → `friend`, `{mere}` → `mother`, `{pere}` → `father`, `{fratrie}` → `siblings`.
- Le métier **déborde sur la vie privée** : famille, couple, enfants, amis, voisins, santé, corps, argent,
  réputation, morale. Pas de scène au bureau (ça, ce sont les événements de travail `Data/WorkEvents`).
- Ton : au moins 60 % ancré et sérieux (vrais dilemmes, vraies conséquences), le reste avec de l'humour.
  Métiers du crime, de la police, de l'armée, de la santé, de la religion et de la politique : sérieux à 80 %.
- Contenu adulte (acteur ou actrice X, effeuillage) : suggéré, jamais explicite. On parle du regard des
  autres, du couple, de la famille, de l'argent, de la santé et du consentement, jamais de scènes.
- 2 ou 3 choix par carte, labels courts (1 à 5 mots), 1 à 3 issues par choix (`chance`, somme 1).
- Effets marqués (consignes de `docs/EVENTS_STYLE.md`) : chaque issue touche au moins une stat centrale ;
  petit tracas ±3 à ±6, vrai coup dur ±8 à ±15, carte rare jusqu'à ±25. `relationships` pour les proches.
  Environ une carte sur trois laisse une trace (`setFlags`).
- Pas de doublon avec `vivant_metier_*.json` (cartes par secteur, et 40 cartes `metier_<id>` déjà écrites).

## Plages d'identifiants

| Plage | Métiers |
|---|---|
| `rep_met_0001-0999` | acteur ou actrice X, effeuilleur ou effeuilleuse de cabaret (métiers ajoutés) |
| `rep_met_1000-1999` | santé, éducation, droit, administration, religion |
| `rep_met_2000-2999` | carrières spéciales (stars, sportifs…), art et culture, médias, beauté et mode |
| `rep_met_3000-3999` | sécurité, armée, crime, politique, science |
| `rep_met_4000-4999` | finance, tech, commerce, services, hôtellerie et tourisme |
| `rep_met_5000-5999` | bâtiment, industrie, transport, restauration, agriculture, environnement |
| `rep_met_6000-6999` | ingénierie, métiers insolites |

## Métiers ajoutés

- `acteur_films_adultes` (Acteur ou actrice de films pour adultes, secteur `spectacle`, carrière spéciale, 18 ans minimum).
- `effeuilleur_cabaret` (Effeuilleur ou effeuilleuse de cabaret burlesque, secteur `spectacle`, 18 ans minimum).

Leurs événements de travail sont dans `Data/WorkEvents/spectacle_adulte.json`.
