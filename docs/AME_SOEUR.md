# Leart et Shkurta (easter egg « âme sœur »)

Une histoire d'amour cachée, qui ne s'active que pour deux prénoms.

| Prénom du perso (casse, espaces et accents ignorés) | Âge du coup de foudre | Âme sœur |
|---|---|---|
| `Leart` | 18 ans | Shkurta (une femme d'un an de moins) |
| `Shkurta` ou `Shkurte` | 17 ans | Leart (un homme d'un an de plus) |

Pour tous les autres prénoms, rien ne change.

## Ce qui se passe

- **La rencontre est obligatoire.** À l'âge prévu (ou au premier anniversaire suivant, pour une vie déjà
  commencée), l'âme sœur arrive dans les relations comme partenaire, lien 100. Si le perso était déjà en couple,
  ce couple s'arrête net (sans divorce ni perte d'argent). Signaux émis : `rencontre`, `couple`, `ame_soeur_rencontre`.
- **Une carte de leur histoire par an** (80 % de chance, la rencontre arrive toujours) : 31 cartes de chaque côté,
  `Data/Events/ame_soeur_leart.json` (`ame_l_0001`–`0031`) et `ame_soeur_shkurta.json` (`ame_s_0001`–`0031`).
  Resto Royal (accepter ou refuser), premier « je t'aime », les parents, emménager, voyage à Ksamil, demande en
  mariage au resto Royal (`"entourage": {"fiancailles": true}`), mariage (`"mariage": true`), lune de miel, bébé,
  maladie, galères d'argent, chômage, valle au mariage d'un cousin, vieillesse ensemble, parloir en prison…
  Les huit dernières cartes vues ne reviennent pas tout de suite. Ces cartes ne sortent jamais au tirage
  normal : seul ce module les tire. Refuser une carte ne fait jamais partir l'autre.
- **Ils ne peuvent jamais se quitter :**
  - `VieRelations.rompre` (rupture, divorce, lien trop bas, `"vie": {"breakup": true}`, module Cœur) est
    remplacé par une réconciliation immédiate ; les boutons « Rompre » et « Divorcer » disparaissent ;
  - la demande en mariage du menu Relations est toujours acceptée ;
  - les événements et suites qui menacent le couple ne sortent plus pour eux : rupture, divorce, mort du
    partenaire (`targetDies: "partner"`), tromperie (`emit` vers `tromperie`, `liaison_debut`…), et les cartes
    « amour » du module Cœur (`coe_*`, liaisons, tentations, crises) ;
  - l'âme sœur suit toujours le perso à l'étranger ;
  - elle ne meurt pas de vieillesse ni d'un événement avant le perso : ils vieillissent ensemble, et à la mort
    du perso le journal dit qu'elle lui tenait la main ;
  - filet de sécurité : si un module oublie la règle et la transforme en ex, elle revient l'année suivante.
  - le lien ne descend jamais sous 60.

## Code

- `FTCHTLife/AmeSoeur/AmeSoeur.swift` : tout le module. État `Joueur.ameSoeur` (`AmeSoeurEtat`, optionnel).
- Tags : `ame_soeur` (couple protégé) et `ame_soeur_leart` / `ame_soeur_shkurta` (côté de l'histoire).
- Branchements (une ligne chacun) : `tagsModules`, `modulesAnnee` (rencontre + lien), `modulesAvantTirage`
  (`ameSoeurAvantTirage()`), `modulesMort` ; `VieSysteme.evenementAutorise` et `VieSysteme.tuer` ;
  `VieRelations.rompre`, `actions`, `demanderEnMariage` ; mort naturelle des relations dans `GameEngine.vieillir` ;
  départ à l'étranger dans `ExpatMoteur.demenager`.
- Un autre module qui veut séparer un couple doit passer par `VieRelations.rompre`, ou tester
  `AmeSoeur.coupleProtege(j)` avant.
