# Entreprises : créer sa propre boîte

Le joueur (18 ans et plus) peut fonder jusqu'à 3 entreprises : food truck, kebab, salon de coiffure, startup,
marque de vêtements… Il lui donne un nom, embauche ses amis et sa famille (et les vire), affronte une crise par an,
fait grandir sa boîte (6 niveaux, du petit commerce à l'empire), la revend ou finit en faillite.

Code : `FTCHTLife/Entreprises/*.swift`. Données : `FTCHTLife/Resources/Data/Entreprises/*.json` (types de boîtes)
et `FTCHTLife/Resources/Data/EntrepriseEvents/*.json` (crises et opportunités).
Vérification : `python3 tools/validate_entreprises.py`.

## Règles du jeu

- **Création** : coût du type (`coutCreation`). Le joueur paie au moins 30 % de sa poche, la banque prête le reste
  (dette remboursée sur 8 ans, 6 % d'intérêts). Conditions : âge, diplôme, intelligence selon le type.
- **Niveaux** 0 à 5. Chaque niveau multiplie la taille de la boîte (`echelle` : 1, 2.5, 6, 16, 50, 160).
  Le nom de chaque niveau est dans `niveaux` (ex. « Un camion », …, « L'empire de la raclette »). Agrandir coûte
  `coutCreation × (2, 5, 14, 40, 120)`.
- **Bilan annuel** (à chaque +1 an) : chiffre d'affaires = base × échelle × réputation × marché (hasard) × équipe × élan.
  Les charges fixes sont `base × échelle × (1 − marge)`, plus les salaires des employés nommés et la dette.
  Le résultat va dans la **trésorerie** de la boîte (pas dans les poches du joueur).
- **Argent du patron** : action « Se verser un dividende » une fois par an ; « Injecter de l'argent » pour renflouer.
- **Équipe** : postes clés = niveau + 1. Un poste vide coûte 8 % de chiffre d'affaires et fatigue le patron.
  On embauche un inconnu (3 candidats par an) ou un proche (ami, frère, sœur, parent, partenaire, enfant majeur, ex).
  Un proche est souvent moins compétent mais plus motivé. Le virer fait chuter le lien (−35) et le karma.
- **Patron absent** : si le joueur a aussi un emploi, −15 % de chiffre d'affaires.
- **Crise de l'année** : environ une chance sur deux par boîte, tirée dans `EntrepriseEvents`. Elle attend la décision
  du joueur dans l'écran Entreprises. Ignorée jusqu'au bilan suivant → l'issue `ignore` s'applique.
- **Faillite** : trésorerie sous `−30 %` des charges annuelles deux bilans de suite → la boîte ferme, le joueur perd
  la moitié du trou (caution personnelle) et beaucoup de bonheur. Le joueur peut aussi fermer sa boîte : à l'amiable s'il reste de l'argent une fois la dette payée, sinon c'est la faillite.
- **Revente** : une offre par an (valeur × 0,7 à 1,3). La valeur dépend du résultat, du secteur, de la réputation.
- **Empire** : atteindre le niveau 5 rend le joueur célèbre (« magnat »).

## Secteurs et types

Secteurs : `restauration`, `beaute`, `commerce`, `mode`, `tech`, `services`, `artisanat`, `loisirs`, `immobilier`, `transport`.

Ids de types (fichier `Data/Entreprises/types.json`) :

| Secteur | Types |
|---|---|
| restauration | `food_truck`, `kebab`, `pizzeria`, `boulangerie`, `restaurant_gastro`, `bar`, `brasserie` |
| beaute | `salon_coiffure`, `barbier`, `onglerie`, `institut_beaute` |
| commerce | `epicerie`, `boutique_telephones`, `fleuriste`, `magasin_bio` |
| mode | `marque_vetements`, `friperie`, `marque_sneakers` |
| tech | `startup_appli`, `appli_rencontre`, `studio_jeux_video`, `agence_web`, `startup_crypto` |
| services | `pressing`, `cabinet_conseil`, `pompes_funebres`, `toilettage_chiens`, `auto_ecole` |
| artisanat | `garage`, `entreprise_btp` |
| loisirs | `salle_sport`, `escape_game`, `boite_de_nuit`, `agence_voyages` |
| immobilier | `agence_immobiliere`, `promoteur_immobilier` |
| transport | `vtc`, `demenagement`, `compagnie_aerienne` |

### Format d'un type

```json
{
  "id": "kebab",
  "nom": "Kebab",
  "secteur": "restauration",
  "icone": "flame.fill",
  "description": "Une broche, une plancha et un rêve.",
  "produit": "kebabs",
  "coutCreation": 45000,
  "ageMin": 18,
  "diplomeMin": "aucun",
  "filiere": null,
  "intelligenceMin": 0,
  "chiffreAffairesBase": 150000,
  "marge": 0.32,
  "volatilite": 0.2,
  "risque": 1.0,
  "multipleValeur": 1.2,
  "salaireEmploye": 38000,
  "postes": ["Cuisinier", "Caissier", "Livreur", "Plongeur"],
  "niveaux": ["Un kebab de quartier", "Le kebab star de {ville}", "Trois kebabs", "Une chaîne régionale", "Une chaîne nationale", "L'empire du kebab"],
  "nomsSuggeres": ["Le Roi de la Broche", "Kebab'n'Roll"]
}
```

| Champ | Rôle |
|---|---|
| `icone` | nom d'un symbole SF Symbols (iOS 16) |
| `produit` | nom pluriel de ce qu'on vend, pour `{produit}` dans les textes (« kebabs », « coupes », « applis ») |
| `diplomeMin` | `aucun`, `ecoleObligatoire`, `bac`, `licence`, `master`, `doctorat` |
| `filiere` | `null` ou `medecine`, `droit`, `informatique`, `commerce`, `arts`, `sciences` (diplôme exigé dans cette filière) |
| `chiffreAffairesBase` | chiffre d'affaires annuel au niveau 0, réputation moyenne, en euros |
| `marge` | part du chiffre d'affaires qui reste après les charges fixes (0,1 à 0,6) |
| `volatilite` | amplitude du hasard annuel (0,1 boulangerie stable, 0,6 startup crypto) |
| `risque` | multiplicateur de la fréquence des crises (0,7 à 1,5) |
| `multipleValeur` | valeur de revente = résultat annuel × ce multiple × 4 + trésorerie (tech plus haut) |
| `postes` | intitulés des postes clés (4 à 6) |
| `niveaux` | exactement 6 noms, du plus petit au plus grand ; variables possibles `{ville}`, `{entreprise}` |
| `nomsSuggeres` | 8 à 12 noms de boîte drôles proposés à la création |

## Format d'un événement d'entreprise (`Data/EntrepriseEvents/<theme>.json`)

```json
{
  "id": "ent_gen_0001",
  "kind": "crise",
  "secteurs": ["restauration"],
  "types": ["kebab"],
  "minNiveau": 0,
  "maxNiveau": 5,
  "weight": 2,
  "unique": false,
  "conditions": { "employe": "proche", "minEmployes": 1, "minAnnees": 2, "enDifficulte": false, "patronAbsent": null, "minReputation": null, "maxReputation": null },
  "text": "{employe}, ton {poste}, a mangé la moitié du stock de {produit} de {entreprise}.",
  "choices": [
    {
      "label": "Le virer",
      "outcomes": [
        { "chance": 0.7, "text": "Il part en emportant la broche.", "business": { "employePart": true, "lienEmploye": -30, "cash": -2000 } },
        { "chance": 0.3, "text": "Il pleure. Tu pleures. Vous pleurez.", "business": { "employePart": true }, "effects": { "happiness": -5 } }
      ]
    }
  ],
  "ignore": { "text": "Tu n'as rien dit. Il mange maintenant aussi la caisse.", "business": { "cash": -3000, "moral": -5 } }
}
```

| Champ | Rôle | Défaut |
|---|---|---|
| `id` | unique, `ent_<theme>_NNNN` | obligatoire |
| `kind` | `crise`, `opportunite`, `equipe`, `absurde` (icône et couleur de la carte) | `crise` |
| `secteurs` / `types` | restreint à ces secteurs / types (si les deux sont donnés, l'un ou l'autre suffit) | tous |
| `minNiveau`, `maxNiveau` | taille de la boîte | 0 et 5 |
| `weight` | fréquence relative | 1 |
| `unique` | une seule fois par entreprise | false |
| `conditions.employe` | `"proche"` (ami, famille, partenaire, ex), `"inconnu"`, `"any"` : il faut un employé de ce genre, et `{employe}` le désigne | aucun |
| `conditions.minEmployes`, `maxEmployes` | nombre d'employés nommés | aucun |
| `conditions.minAnnees` | âge de la boîte en années | aucun |
| `conditions.enDifficulte` | `true` = trésorerie négative, `false` = positive | aucun |
| `conditions.patronAbsent` | `true` = le joueur a aussi un emploi | aucun |
| `conditions.minReputation`, `maxReputation` | réputation 0-100 | aucun |
| `text` | situation (1-2 phrases) | obligatoire |
| `choices` | 2 à 4 choix, chacun 1 à 3 issues (`chance` = poids relatif) | obligatoire |
| `ignore` | issue appliquée si le joueur n'a pas décidé avant le bilan suivant | réputation −5 |

Un choix peut avoir `"cost": 5000` : montant (mis à l'échelle) payé par la trésorerie avant le tirage ; le choix est
grisé si la trésorerie plus l'argent du joueur ne suffisent pas.

**Effets sur la boîte** (`business`, tous optionnels) :

| Clé | Effet |
|---|---|
| `cash` | euros ajoutés à la trésorerie. **Montant pour un niveau 0** : multiplié automatiquement par l'échelle |
| `argentJoueur` | euros ajoutés au joueur, multipliés par l'échelle (pots-de-vin, primes, amendes perso) |
| `dette` | euros ajoutés à la dette bancaire, multipliés par l'échelle |
| `reputation` | points de réputation (0-100) |
| `elan` | points d'élan en % du chiffre d'affaires (−50 à +100), s'estompe de 30 % par an |
| `moral` | motivation de tous les employés |
| `employeMoral`, `employeCompetence` | motivation / compétence de l'employé `{employe}` |
| `employePart` | `true` : `{employe}` quitte la boîte |
| `lienEmploye` | lien avec `{employe}` s'il est un proche |
| `niveau` | +1 / −1 niveau |
| `faillite` | `true` : la boîte ferme en faillite |

**Effets sur le joueur** (`effects`) : exactement le format des événements (`happiness`, `health`, `smarts`, `looks`,
`karma`, `money` (pas mis à l'échelle), `relationships`, `death`…).

**Variables** : `{entreprise}` (nom de la boîte), `{produit}`, `{employe}` (prénom), `{poste}` (son poste),
`{concurrent}` (nom de boîte rivale), `{niveau}` (nom du niveau), plus toutes celles des événements
(`{prenom}`, `{ville}`, `{mere}`, `{ami}`, `{partenaire}`, `{e}`…).

## Style

Mêmes consignes que les événements : tutoiement, humour décalé et un peu méchant, 100 % original, 1 à 2 phrases,
labels de 1 à 5 mots, une vraie chute par issue. Les montants `cash` pensés pour un petit commerce (500 à 30 000 €).
Mélanger crises (contrôle fiscal, avis assassin, fournisseur louche), opportunités (contrat, buzz, rachat) et
drames d'équipe (le cousin qui pique dans la caisse, la mère qui réorganise tout).

## Branchement dans le moteur (fil moteur)

1. `Joueur` : `var entreprises: EntreprisesEtat? = nil` (déjà ajouté par cette PR, compatible avec les anciennes sauvegardes).
2. Dans `vieillir`, juste avant `j.journal.append(Annee(age: j.age, lignes: lignes))` :
   `lignes += bilanEntreprises(&j)`
3. `tags(j)` : `t.formUnion(EntrepriseMoteur.tags(j.entreprises))` → `entrepreneur`, `patron`, `magnat`,
   `ancien_entrepreneur`, `failli`.
4. Un bouton qui ouvre `EntreprisesView()` (en sheet, avec `.environmentObject(engine)`), par ex. dans Occupation
   (section « Mes entreprises ») ou Activités, à partir de 18 ans.
5. Optionnel : afficher la crise en attente dès la fin de l'année avec
   `.sheet(item: …) { EntrepriseCriseView(entrepriseId: …) }` (voir `EntrepriseMoteur.criseEnAttente(j)`).
6. Répercussions : signaux `entreprise_creee`, `entreprise_agrandie`, `entreprise_empire`, `entreprise_vendue`,
   `entreprise_faillite`, `entreprise_fermee`, `proche_licencie` (renvoyés dans `EntreprisesEtat.signaux`, à vider par le module répercussions).
7. Mort du joueur : rien à faire, `EntrepriseMoteur.resumeVie(j.entreprises)` donne des lignes pour la nécrologie.

## Gestion poussée (v2)

Chaque boîte se pilote comme une vraie entreprise. Les décisions prennent effet au bilan suivant ; l'écran de pilotage
affiche une **estimation de l'année prochaine** (sans le hasard) à chaque réglage.

### Modèle économique annuel

- **Points de vente** (`sites` : camions, salons, boutiques, agences…) : chacun apporte des clients potentiels (le marché
  touché) et, sauf pour les types à usine, de la capacité de production. Ouvrir coûte `site.cout`, chaque site a un loyer.
- **Usines** (optionnel, types qui fabriquent : marque de vêtements, sneakers, brasserie, studio…) : la capacité vient des
  usines, les points de vente ne font que vendre. Trop de boutiques pour trop peu d'usines = ruptures de stock.
- **Demande** = marché touché × attractivité : qualité, réputation, marketing, élan, prix (élasticité du type),
  leviers activés, pression de la concurrence (qui bouge chaque année). **Part de marché** = demande / marché touché.
- **Capacité** = unités × taux d'encadrement (effectif × productivité ÷ effectif nécessaire). La productivité dépend du
  moral, des salaires, des cadres (employés nommés) et des leviers.
- **Ventes** = min(demande, capacité) × hasard du marché. Les clients refusés sont comptés dans le rapport.
- **Coûts** : achats (par vente, selon la qualité), salaires (effectif × salaire × niveau de salaire + cadres),
  loyers, marketing (% du chiffre d'affaires), leviers (coût annuel), banque.
- **Réputation** : tend vers une cible fixée par la qualité, le rapport qualité/prix, le marketing et les leviers.
- **Moral** de l'équipe : tend vers une cible fixée par les salaires, la surcharge de travail et les licenciements ;
  sous 30, des employés démissionnent.
- **Niveau** (nom affiché, événements) : dépend du nombre de points de vente (1, 2, 4, 10, 30, 100).

### Réglages génériques

Prix (−40 % à +100 %), qualité (1 à 5), budget marketing (0, 2, 5, 10, 20 % du CA), niveau des salaires (−20 % à +40 %),
effectif (embaucher coûte 10 % d'un salaire annuel, licencier 25 % et fait baisser le moral), points de vente et usines
(ouvrir, fermer en récupérant 30 %).

### Leviers propres à chaque type (`Data/EntrepriseLeviers/*.json`)

Chaque fichier est un tableau ; une entrée par type :

```json
{
  "typeId": "marque_sneakers",
  "vente": { "nom": "paire", "pluriel": "paires" },
  "site": { "nom": "boutique", "pluriel": "boutiques", "cout": 60000 },
  "usine": { "nom": "usine", "pluriel": "usines", "cout": 90000 },
  "prixUnitaire": 130,
  "elasticite": 1.1,
  "leviers": [
    {
      "id": "snk_collab_rappeur",
      "nom": "Collab avec un rappeur",
      "description": "Il porte tes baskets dans un clip. Elles sont à l'envers, mais ça compte.",
      "icone": "music.mic",
      "groupe": null,
      "niveauMin": 0,
      "coutInstallation": 25000,
      "coutAnnuel": 8000,
      "parSite": false,
      "effets": { "demande": 15, "prix": 10, "coutVariable": 0, "capacite": 0, "productivite": 0, "reputation": 3, "moral": 0, "risque": 10, "karma": 0 },
      "activation": "Le rappeur a signé le contrat avec ton stylo. Il l'a gardé."
    }
  ]
}
```

| Champ | Rôle |
|---|---|
| `vente` | ce qu'on compte comme une vente (« kebab », « coupe », « abonnement », « billet ») |
| `site` | nom du point de vente et coût d'ouverture d'un site de plus |
| `usine` | optionnel : nom de l'unité de production et coût. Présent = la capacité vient des usines |
| `prixUnitaire` | prix moyen d'une vente en euros, au réglage normal |
| `elasticite` | sensibilité des clients au prix : 0,6 (luxe, on s'en fiche) à 1,8 (tout le monde compare) |
| `leviers` | 5 à 7 décisions propres au métier |
| `groupe` | leviers d'un même groupe : un seul actif à la fois (ex. horaires) |
| `niveauMin` | taille minimale de la boîte (0 à 5) |
| `coutInstallation` | payé à l'activation (× nombre de sites si `parSite`) |
| `coutAnnuel` | payé à chaque bilan (× nombre de sites si `parSite`) |
| `effets` | en % : `demande`, `prix` (prix de vente), `coutVariable`, `capacite`, `productivite` ; en points par an : `reputation`, `moral`, `karma` (karma appliqué au joueur à chaque bilan) ; `risque` = % de chances de crise en plus |
| `activation` | phrase drôle affichée quand on active le levier |

Sans entrée pour un type, le jeu utilise des valeurs par défaut (site nommé « local », pas d'usine, pas de levier).

### Branchement de la v2 (fil moteur)

1. Après chaque anniversaire, quand `!engine.entreprisesAvecRapportNonLu.isEmpty`, présenter en feuille
   `EntreprisesBilanAnnuelView().environmentObject(engine)` (après les cartes d'événements de l'année, ou à leur place
   si la file est vide). Le bouton « Continuer » appelle `engine.marquerRapportsEntreprisesLus()`.
   La feuille montre pour chaque boîte : chiffre d'affaires et évolution, résultat, ventes, part de marché, trésorerie,
   faits marquants, conseils, la crise de l'année, un lien vers le rapport complet (graphique) et vers le pilotage.
2. Rien d'autre : `bilanEntreprises(&j)` fait déjà tout le calcul, et les anciennes sauvegardes sont converties
   automatiquement (points de vente déduits du niveau, effectif conseillé).
3. Le framework `Charts` (iOS 16) est utilisé pour le graphique : rien à ajouter dans `project.yml`, il est lié automatiquement.
