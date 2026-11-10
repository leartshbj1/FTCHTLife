# Réputation du nom de famille

Chaque famille traîne une réputation. Quand on continue la partie avec son enfant, il hérite du nom… et de
tout ce qui va avec. Les ancêtres ont braqué la poste ? On te regarde de travers à la boulangerie. Ta
grand-mère a eu le prix Nobel ? Les profs attendent beaucoup trop de toi. Au fil des générations, on peut
redorer le blason ou le traîner dans la boue.

Code : `FTCHTLife/ReputationFamille/`. Événements : `FTCHTLife/Resources/Data/Events/famille_reputation_*.json`.
Vérification : `python3 tools/validate_reputation_famille.py`.

## Les cinq réputations

Une famille a cinq jauges de 0 à 100, indépendantes (une famille peut être **célèbre et ridicule**, c'est même fréquent).

| Axe | Adjectif | Clé d'effet (`familyRep`) | Tag (≥ 30) | Tag légendaire (≥ 70) | Oubli par génération |
|---|---|---|---|---|---|
| Respect | respectée | `respected` | `famille_respectee` | `famille_respectee_legendaire` | × 0,75 |
| Mafia | mafieuse | `mafia` | `famille_mafieuse` | `famille_mafieuse_legendaire` | × 0,80 (on n'oublie pas) |
| Ridicule | ridicule | `ridiculous` | `famille_ridicule` | `famille_ridicule_legendaire` | × 0,70 |
| Malédiction | maudite | `cursed` | `famille_maudite` | `famille_maudite_legendaire` | × 0,90 (ça colle) |
| Célébrité | célèbre | `famous` | `famille_celebre` | `famille_celebre_legendaire` | × 0,75 |

Autres tags :
- `famille_sans_histoire` : aucune jauge à 30 ou plus.
- `heritier` : le joueur joue un descendant (génération 2 ou plus).

Une jauge à 90 ou plus s'oublie moins vite (les légendes durent).

## Dans les événements

Les événements de `Data/Events` peuvent :

- exiger une réputation : `"conditions": { "tags": ["famille_mafieuse"] }` (ou l'exclure avec `excludeTags`) ;
- la modifier : `"effects": { "familyRep": { "respected": 5, "ridiculous": -3 } }` (deltas en points, bornés 0-100) ;
- citer un ancêtre : `{ancetre}` devient « ton arrière-grand-père Marcel » (ou « un lointain aïeul » s'il n'y a
  pas encore d'ancêtre connu). À utiliser en milieu de phrase.

Style : la réputation **colore** la vie, elle ne la remplace pas. On veut des situations où l'enfant subit ou
profite du nom (« Le prof de maths a eu ton père. Il te met 4 par principe. »), et des choix qui permettent de
**redorer** (deltas positifs sur `respected`, négatifs sur les autres) ou **salir** le nom.

## Ce que fait le module (sans événement)

- **Naissance** : une ou deux phrases dans le journal sur la réputation de la famille.
- **Chaque année** (au hasard, pas tous les ans) : petits effets passifs selon la réputation forte
  (enveloppe discrète pour les mafieux, paparazzi pour les célèbres, guigne pour les maudits, moqueries pour les
  ridicules, crédit de confiance pour les respectés).
- **Signaux** : les signaux des modules (voir `docs/REPERCUSSIONS.md`) font bouger la réputation
  (`prison_entree` → mafia +6, respect −6 ; `celebrite` → célébrité +10 ; `faillite` → ridicule +6…).
- **Actions** (onglet Famille) : faire un don à la ville, engager une agence de com', faire exorciser la lignée,
  écrire ses mémoires, porter plainte pour diffamation, acheter un titre de noblesse sur internet,
  changer de nom de famille, profiter du nom (racket ou placements de produit).
- **Mort** : bilan de vie (« Tu as redoré le blason des Dupont » / « Tu as sali le nom »), surnom posthume
  (« Marcel le Parrain », « Ginette la Maudite ») et entrée dans l'arbre des ancêtres.
- **Succession** : l'héritier reçoit les jauges, un peu oubliées, plus la génération.

## Branchement dans le moteur (fil moteur / fil générations)

1. `Joueur` : `var reputationFamille: RepFamilleEtat?` (optionnel, anciennes sauvegardes compatibles).
2. `Effets` : `var familyRep: [String: Int]?`.
3. Nouvelle vie (`nouvelleVie`) : `j.reputationFamille = ReputationFamille.aleatoire()`, puis
   `lignes += ReputationFamille.lignesNaissance(j.reputationFamille!, joueur: j)`.
4. Succession (continuer avec un enfant) : `heritier.reputationFamille = ReputationFamille.transmettre(parent: ancienJoueur, etat: ancienJoueur.reputationFamille ?? ReputationFamille.aleatoire(), heritier: heritier)`,
   puis les `lignesNaissance` (elles parlent de l'héritage quand `generation > 1`).
5. `tags(j)` : `t.formUnion(ReputationFamille.tags(j.reputationFamille))`.
6. `appliquer(eff, &j)` :
   ```swift
   if let d = eff.familyRep, var rf = j.reputationFamille {
       ReputationFamille.modifier(d, etat: &rf, joueur: j)
       j.reputationFamille = rf
   }
   ```
7. `remplir` : au début, `t = ReputationFamille.remplir(t, etat: j.reputationFamille)`.
8. `vieillir`, après l'évolution des stats :
   ```swift
   if var rf = j.reputationFamille {
       let a = ReputationFamille.annee(joueur: j, etat: &rf)
       j.reputationFamille = rf
       lignes += a.lignes
       appliquer(a.effets, &j)
   }
   ```
9. Signaux : partout où `Repercussions.signaler(signal, …)` est appelé, appeler aussi
   `ReputationFamille.signaler(signal, joueur: j, etat: &rf)`.
10. `mourir` : `if var rf = j.reputationFamille { let b = ReputationFamille.bilanDeVie(joueur: j, etat: &rf); j.reputationFamille = rf }`
    (le bilan est gardé dans `rf.dernierBilan` pour l'écran de mort ; `transmettre` le fait aussi s'il manque).
11. Écrans :
    - un onglet ou une entrée « Famille » qui ouvre `RepFamilleView(joueur:etat:faire:)` ; `faire` exécute
      ```swift
      engine.modifier { j in
          var rf = j.reputationFamille ?? ReputationFamille.aleatoire()
          let texte = ReputationFamille.faire(action, joueur: &j, etat: &rf)
          j.reputationFamille = rf
          engine.ajouterLigne(&j, texte)
      }
      ```
      et renvoie `texte` pour l'afficher ;
    - `RepFamilleBadge(etat:)` dans le profil ou l'en-tête ;
    - `RepFamilleBilanView(etat:)` dans l'écran de mort.
12. Validateur d'événements : accepter la clé d'effet `familyRep`, la variable `{ancetre}` et les tags ci-dessus.
