# Secte et agence de détective privé

Deux activités « à ton compte », dans le menu **Carrière → À ton compte** :

- **Ma secte** : fonder un mouvement spirituel, attirer des membres, gérer leurs dons, choisir jusqu'où aller dans l'emprise… et faire face à la presse, aux familles et à la justice.
- **Agence de détective** : ouvrir son agence (avec ou sans carte professionnelle), prendre des affaires, choisir ses méthodes d'enquête, recruter des enquêteurs et décider quoi faire de la vérité.

Ton : sérieux à 80 %. Les dérives sectaires et les méthodes illégales ont de vraies conséquences (karma, casier, prison, dissolution).

## Code et données

| Module | Code | Données | Préfixes |
|---|---|---|---|
| Secte | `FTCHTLife/Secte/` | `Data/Secte/doctrines.json`, `Data/SecteEvents/*.json` | événements `sec_`, suites `rep_sec_` |
| Agence | `FTCHTLife/Detective/` | `Data/Detective/affaires.json`, `Data/DetectiveEvents/*.json` | événements `det_`, suites `rep_det_` |

Vérification : `python3 tools/validate_secte_detective.py` (et `tools/validate_repercussions.py` pour les suites).

## Règles de la secte

- Dès 18 ans, une seule à la fois. État : `Joueur.sectes` (`SectesEtat`, avec les anciennes sectes).
- Jauges : **ferveur** (dévotion), **dérive** (emprise, abus), **surveillance** (presse, familles, autorités), **notoriété**. Caisse du mouvement séparée de l'argent du joueur.
- **Contribution** : libre, modérée, dîme, « tout donner ». Plus elle est forte, plus les dons montent… avec les départs, la dérive et la surveillance.
- **Lieux** : salon (30 membres), local (300), temple (5 000), domaine (les membres vivent sur place). Au-delà de 300 membres ou au domaine, la secte prend tout le temps du joueur : il quitte son emploi (`empechementActivite`).
- **Actions** (une fois par an chacune) : prêcher, retraite payante, campagne de communication, durcir les règles / ouvrir les portes, engager des avocats, se verser de l'argent, faire entrer un proche, dissoudre (en rendant la caisse ou en en gardant une partie).
- **Enquête** en 4 stades : articles et plaintes → enquête préliminaire → perquisition → procès. Elle avance selon la surveillance et la dérive, recule si la surveillance retombe. Chaque nouveau stade montre une carte `kind: "enquete"` ; au procès, une carte chaque année jusqu'au verdict. Les issues avec `prisonMois` sont pondérées par la dérive et la défense (avocats).
- Condamnation : casier (module Casier) + prison (module Vie). Dissolution judiciaire possible.

## Règles de l'agence

- Avec carte professionnelle : 21 ans, bac, pas de casier lourd, formation (gratuite avec un diplôme de droit). Sans : 18 ans, moins cher, illégal. C'est un métier à plein temps (le joueur quitte son emploi).
- Chaque année : nouvelles **offres** (plus nombreuses et mieux payées avec la réputation et le bureau). Accepter = acompte de 30 %. Capacité : 2 affaires + 2 par enquêteur.
- Pour chaque affaire : une **méthode** (filature, planque, enquête de voisinage, recherches, infiltration, méthodes limites) et une personne (le joueur ou un enquêteur). Les points d'enquête dépendent de la compétence liée (sport, photo, éloquence, code, séduction, bricolage), du matériel et du bonus du type d'affaire. Les méthodes limites vont vite mais peuvent valoir plainte, suspension de la carte ou condamnation.
- Affaire résolue : le solde est payé, ou une carte de **dénouement** (dilemme) décide du paiement. Délai dépassé : affaire ratée.
- Charges annuelles : loyer du bureau, entretien du matériel, salaires. Faillite si l'argent du joueur plonge trop bas.

## Une carte par module et par an

Au passage d'année (`modulesAvantTirage`), chaque module ajoute **au plus une** carte : stade d'enquête ou événement de la secte, dénouement ou événement de l'agence. La limite générale de 3 événements à choix par an s'applique (`limiterFileEvenements`) ; les cartes d'enquête et les dénouements passent en priorité.

## Formats

### Doctrine (`Data/Secte/doctrines.json`)

`id`, `nom`, `icone` (SF Symbol), `description`, `adeptesNom`, `titreGourou` ([masculin, féminin]), `donMoyen`, `attrait`, `risque`, `nomsSuggeres`, `preches`.

### Événement de secte (`Data/SecteEvents/*.json`)

Comme un événement classique, avec : `kind` (`vie`, `derive`, `exterieur`, `enquete`), `doctrines` (optionnel), `conditions` propres (`minAdeptes`, `maxAdeptes`, `minFerveur`, `maxFerveur`, `minDerive`, `maxDerive`, `minSurveillance`, `minNotoriete`, `minTresor`, `lieux`, `enquete`, `procheMembre`, `minAnnees`), `cost` sur un choix (payé par la caisse puis le joueur), et dans chaque issue un objet `secte` : `adeptes`, `adeptesPct`, `ferveur`, `derive`, `surveillance`, `notoriete`, `tresor`, `tresorPct`, `enquete`, `defense`, `prisonMois` + `infraction`, `dissoudre`, `signal`.

Variables : `{secte}`, `{doctrine}`, `{adeptes}`, `{nb}`, `{gourou}`, `{proche}` (avec `procheMembre`), plus celles du moteur.

### Type d'affaire (`Data/Detective/affaires.json`)

`id`, `nom`, `icone`, `description`, `honoraires` [min, max], `difficulte` [min, max], `duree`, `reputationMin`, `danger`, `methodes` (bonus par méthode), `clients`, `cibles`, `indices`, `denouements` (texte + choix).

### Événement d'agence (`Data/DetectiveEvents/*.json`)

`kind` (`agence`, `terrain`, `equipe`, `police`, `presse`), `conditions` (`minReputation`, `maxReputation`, `minEnqueteurs`, `affaireEnCours`, `typesAffaire`, `sansAgrement`, `minEquipement`, `minBureau`, `minResolues`, `minAnnees`), `cost` sur un choix, et dans chaque issue un objet `agence` : `reputation`, `paiement` (part du solde payée, dénouements), `bonus`, `plainte`, `suspension`, `prisonMois` + `infraction`, `celebre`, `enqueteurPart`, `enqueteurCompetence`, `signal`.

Variables : `{agence}`, `{client}`, `{cible}`, `{affaire}` (avec `affaireEnCours`), `{enqueteur}` (avec `minEnqueteurs`), plus celles du moteur.

## Tags et signaux

Tags : `gourou`, `secte_communaute`, `secte_grande`, `secte_enquete`, `ancien_gourou`, `proche_dans_secte`, `detective`, `detective_celebre`, `detective_clandestin`, `ancien_detective`.

Signaux (pour les répercussions) : voir le tableau de docs/REPERCUSSIONS.md, ligne « Secte et détective ».

## Branchement (déjà fait)

- `Joueur` : `sectes: SectesEtat?`, `agences: AgencesEtat?` ; `occupation` affiche « Détective privé·e » ou « Gourou de … ».
- `Branchements.swift` : tags, `secteAnnee` / `agenceAnnee` dans `modulesAnnee`, `secteAvantTirage` / `agenceAvantTirage` à la fin de `modulesAvantTirage`, `secteApresChoix` / `agenceApresChoix` dans `modulesApresChoix`, fermeture à la mort dans `modulesMort`.
- `Coherence.swift` : `empechementActivite` (plein temps), priorité des cartes d'enquête et des dénouements.
- Navigation : `ModuleJeu.agenceDetective` et `ModuleJeu.secte`.
