# Vieillesse et maison de retraite

Après 60 ans, un onglet **Retraite** : maisons de retraite (choisies ou imposées par les enfants), loto du jeudi,
résidents avec qui se lier, flirter, se marier ou comploter, évasions et cavale, petits-enfants (souvent absents),
voyages de retraités.

- Code : `FTCHTLife/Retraite/` (`RetraiteModeles.swift`, `RetraiteSysteme.swift`, `RetraiteView.swift`).
- Données : `FTCHTLife/Resources/Data/Retraite/<Sous-dossier>/*.json` (un tableau par fichier, un sous-dossier par type).
- Événements : `FTCHTLife/Resources/Data/Events/retraite_01..03.json` (ids `ret_0001` à `ret_0150`).
- Vérification : `python3 tools/validate_retraite.py` (événements retraite + catalogue).

## Ce que fait le module

| Système | Règle |
|---|---|
| Entrer en résidence | Dès 65 ans, choix parmi 12 résidences (de 18 000 €/an à 250 000 €/an), avec confort (santé), ambiance (bonheur) et surveillance (évasion). |
| Placement imposé | Dès 75 ans, chaque année, les enfants adultes peuvent te placer (plus probable si santé basse, grand âge, mauvais lien). Sans enfant : les services sociaux, à 85 ans et santé < 30. Ils choisissent surtout les moins chères. |
| Pension | Payée chaque année. Pas assez d'argent : les enfants paient (lien −6) ou l'aide sociale te transfère dans la moins chère. |
| Sortir | Résidence choisie : partir quand on veut. Imposée : négocier avec les enfants (1×/an) ou s'évader. |
| Évasion | 1 tentative/an, 6 plans (draps, déguisement, marché, gardien soudoyé, faux malaise, tunnel à la cuillère sur plusieurs années). Chances selon santé, intelligence, surveillance, complice. Échec : vigilance accrue. |
| Cavale | Chaque année ~30 % de chances d'être rattrapé·e (moins si intelligent·e). Après 3 ans : libre. On peut aussi se rendre. |
| Résidents | ~6 PNJ avec un trait. Discuter, cartes, flirter, déclarer sa flamme, mariage, complot d'évasion, farce. Ils vieillissent, meurent, d'autres arrivent. Statuts : voisin, ami, ennemi juré, flirt, couple, marié. Le couple devient aussi ton `partenaire` dans `Joueur.relations` (si tu n'en as pas déjà un), ce qui rend `{partenaire}` juste dans les événements. |
| Loto | 1 soirée/an (« loto du jeudi » en résidence, « salle des fêtes » sinon) : 1, 3 ou 6 cartons, ou tricher (exclusion 2 ans si pris). 12 lots pondérés. |
| Petits-enfants | Tes enfants de 22-45 ans ont des bébés (10 %/an, 3 max chacun). Visites rares, plus fréquentes si bon lien, si tu es riche, ou l'année après avoir « parlé de l'héritage ». Actions : appeler, carte avec billet, parler de l'héritage. |
| Activités | 14 activités (aquagym, macramé, thé dansant, belote…), certaines seulement en résidence, 1×/an chacune. |
| Voyages | 10 voyages de retraités (car avec vente de matelas, cure, croisière fluviale, tour du monde…), 1×/an chacun. |

Les actions « une fois par an » utilisent `Joueur.actionsAnnee` avec des clés préfixées `ret_`.

## Tags pour les événements

Fournis par `RetraiteSysteme.tags(j.retraite)` :

| Tag | Quand |
|---|---|
| `maison_retraite` | vit en résidence |
| `maison_retraite_imposee` | en résidence, placé·e par la famille ou l'aide sociale |
| `en_cavale` | évadé·e, en fuite |
| `romance_residence` | en couple ou marié·e avec un·e résident·e |
| `grand_parent` | au moins un petit-enfant |
| `petits_enfants_absents` | aucune visite depuis 3 ans (avec au moins un petit-enfant de 6 ans ou plus) |
| `senior_voyageur` | a fait au moins un voyage de retraités |
| `champion_loto` | 3 victoires ou plus au loto |

`tools/validate_events.py` les accepte. Les événements existants qui parlent de « la résidence » (`vie_0038`, `vie_0059`,
`vie_0080`, `vie_0094`, `vie_0112`, `vie_0135`, `vie_0147`, `abs_0012`) exigent maintenant `maison_retraite` ;
`vie_0012` (la famille visite une résidence) l'exclut. Ids et ordre des choix inchangés.

## Signaux (module Répercussions)

`maison_retraite_entree`, `maison_retraite_imposee`, `maison_retraite_sortie`, `evasion_retraite`, `evasion_ratee`,
`cavale_rattrape`, `cavale_liberte`, `cavale_fin`, `loto_gain`, `loto_triche_attrape`, `romance_residence`,
`mariage_residence`, `veuvage_residence`, `tromperie_decouverte`, `petit_enfant`, `visite_petits_enfants`, `voyage`,
`voyage_retraite`, et l'id de chaque activité (`aquagym`, `belote`…).

## Branchement dans le moteur (fil moteur)

1. `Joueur` : `var retraite: RetraiteEtat?` (optionnel : anciennes sauvegardes compatibles ; `RetraiteEtat` se décode même s'il manque des champs).
2. `tags(_:)` : `t.formUnion(RetraiteSysteme.tags(j.retraite))`.
3. `vieillir()`, après le bloc Emploi (salaire, retraite) et avant « Évolution naturelle des stats » :
   ```swift
   var retraite = j.retraite ?? RetraiteEtat()
   let bilan = RetraiteSysteme.annee(&j, &retraite)
   j.retraite = retraite
   lignes += bilan.lignes
   // bilan.signaux → Repercussions.signaler(…) quand le module sera branché
   ```
   (Petit coût : un `RetraiteEtat` vide est créé pour tout le monde. Pour l'éviter : `if j.age >= 38 || j.retraite != nil`.)
4. Interface : un bouton/onglet « Retraite » visible dès `RetraiteSysteme.ageOnglet` (60 ans) :
   ```swift
   RetraiteView(chemin: \.retraite)
   // ou, avec les répercussions :
   RetraiteView(chemin: \.retraite) { signal, j in
       var etat = j.repercussions ?? RepercussionsEtat()
       Repercussions.signaler(signal, age: j.age, etat: &etat)
       j.repercussions = etat
   }
   ```
   L'écran écrit lui-même le résultat de chaque action dans le journal de l'année.
5. Optionnel : `occupation` peut afficher « Pensionnaire à <résidence> » / « En cavale » via `j.retraite?.residence?.nom`.

## Style des textes

Même ton que les événements : on rit **avec** les vieux (rusés, rebelles, mauvais joueurs, romantiques), jamais d'eux.
Variables propres au catalogue : `{residence}`, `{resident}`, `{trait}`, `{il}` (il/elle du résident), `{er}`/`{ner}`
(accords du résident : « mort{er} », « espion{ner} »), `{petitenfant}`, `{pe}` (accord du petit-enfant), `{enfant}`,
`{grandparent}`, plus `{prenom}`, `{nom}`, `{ville}`, `{e}`.
