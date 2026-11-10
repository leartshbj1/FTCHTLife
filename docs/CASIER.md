# Casier judiciaire effaçable

Module autonome : `FTCHTLife/Casier/` (code) et `FTCHTLife/Resources/Data/Casier/` (données).
Événements : `FTCHTLife/Resources/Data/Events/casier_01.json` et `casier_02.json` (ids `cas_0001` à `cas_0100`).
Validateur : `python3 tools/validate_casier.py`.

## Règles du jeu

- Chaque condamnation a une gravité : **contravention**, **délit** ou **crime**.
- Une nouvelle condamnation remet à zéro le compteur d'**années sans récidive**. Les années en prison ne comptent pas.
- Tant que le casier contient une condamnation :
  - des **métiers sont fermés** selon la gravité (police, justice, enseignement, banque, sécurité, armée, aviation, santé, politique…) ;
  - des **événements louches** arrivent (tags `casier`, `casier_lourd`).
- Quatre façons d'effacer :
  1. **Années sans récidive** (automatique) : 3 ans pour une contravention, 5 pour un délit, 10 pour un crime.
  2. **Avocat** (une tentative par an) : 5 avocats, du commis d'office à 300 € à l'avocat des stars. Prix × 0,4 pour une contravention, × 3 pour un crime. Les chances montent avec les années sans récidive et le karma, baissent pour les récidivistes et les crimes. L'avocat « arrangeant » réussit souvent mais peut se faire prendre : nouvelle condamnation.
  3. **Travaux d'intérêt général** : 60 h (contravention), 180 h (délit), 300 h (crime). Les heures avancent chaque année (50 à 110 h) et on peut en faire plus une fois par an. Fini : la condamnation est effacée ; pour un crime, l'attente est raccourcie de 3 ans.
  4. **Piston** (une tentative par an, chaque piston une fois par vie) : parent, ami au greffe, belle-famille, frère ou sœur flic, collègue de la justice, dîner avec un député, don à la « fondation » du procureur, pote hacker, voyante du maire. Il faut la bonne relation (lien minimum), le bon métier ou assez d'argent. Échec : le lien baisse. Certains peuvent tourner au scandale : nouvelle condamnation (trafic d'influence…).
- Les condamnations effacées restent dans les **archives** de l'écran (tag `casier_efface` quand le casier est redevenu vierge).

## Branchement dans le moteur (fil principal)

Le module compile seul : il ne touche ni `Joueur` ni `Effets`. Pour l'activer :

1. `Models/Models.swift`, dans `Joueur` :
   ```swift
   var casier: CasierJudiciaire?
   ```
2. `Models/Evenement.swift`, dans `Effets` :
   ```swift
   var casier: CasierEffet?
   ```
3. `GameEngine.tags(_:)`, avant `return t` :
   ```swift
   t.formUnion(CasierSysteme.tags(j.casier))
   ```
4. `GameEngine.vieillir()`, après le bloc « Emploi » :
   ```swift
   if var c = j.casier {
       lignes += CasierSysteme.passerAnnee(&c, joueur: j, enPrison: false /* état prison du module crime */)
       j.casier = c
   }
   ```
5. `GameEngine.appliquer(_:_:)`, avant le test de mort :
   ```swift
   if let ce = eff.casier {
       var c = j.casier ?? CasierJudiciaire()
       for ligne in CasierSysteme.appliquer(ce, &c, age: j.age) { ajouterLigne(&j, ligne) }
       j.casier = c
   }
   ```
6. Métiers : dans `conditionsRemplies(_ m: Metier)` et `postuler(_:)` :
   ```swift
   if let raison = CasierSysteme.raisonMetierFerme(id: m.id, titre: m.titre, casier: j.casier) { return raison } // postuler
   CasierSysteme.raisonMetierFerme(id: m.id, titre: m.titre, casier: j.casier) == nil                        // conditionsRemplies
   ```
7. Écran : un bouton « Casier judiciaire » (Profil ou Activités) qui ouvre
   ```swift
   .sheet(isPresented: $casierOuvert) { CasierView(chemin: \.casier) }
   ```
   et, dans le profil, `CasierSysteme.resume(j.casier)` donne « Vierge », « 1 délit », « 2 contraventions, 1 crime »…

## Pour le module crime et prison

Quand le joueur est condamné :
```swift
var c = j.casier ?? CasierJudiciaire()
let ligne = CasierSysteme.condamner(&c, infraction: "vol de nains de jardin", gravite: .delit, age: j.age)
j.casier = c
engine.ajouterLigne(&j, ligne)
```
Passez `enPrison: true` à `passerAnnee` pour les années derrière les barreaux.

## Pour le module métiers

Pour chaque métier du catalogue, `CasierSysteme.raisonMetierFerme(id:titre:casier:)` renvoie la raison du refus ou `nil`.
La comparaison se fait sur l'id puis sur le début des mots du titre (« polic » trouve « Policier·ère », « maire » ne trouve pas « primaire »).
Les règles sont dans `Data/Casier/Metiers/metiers_fermes.json` : on peut y ajouter des ids de vos métiers.

## Format des données

- `Casier/Avocats/*.json` : `id`, `nom`, `description`, `prix` (pour un délit), `chance` (0 à 1, pour un délit), `graviteMax`, `risque` et `infractionRisque` (optionnels), `succes`, `echecs`, `scandales`.
- `Casier/Pistons/*.json` : comme les avocats, plus `condition` (`parent`, `ami`, `partenaire`, `fratrie`, `metier`, `riche`, `aucune`), `lienMin`, `metiers`, `prix` (optionnel), `lienEchec`.
- `Casier/Metiers/*.json` : `nom` (domaine affiché), `ids`, `motsCles`, `graviteMin`, `raison`.
- `Casier/TIG/*.json` : `mission`, `anecdotes`.
- Variables dans ces textes : `{prenom}`, `{e}`, `{ville}`, `{contact}` (avocat ou personne du piston), `{infraction}`.

## Effet `casier` dans les événements

Sous-objet optionnel des `effects` (d'un événement ou d'une issue) :

```json
"effects": {
  "karma": -5,
  "casier": {
    "condamnation": { "infraction": "recel de trottinettes", "gravite": "delit" },
    "effacer": "une",
    "delai": 2
  }
}
```

- `condamnation` : le joueur s'est fait prendre, la condamnation est inscrite (compteur remis à zéro).
- `effacer` : `"une"` (la plus légère) ou `"tout"`.
- `delai` : années ajoutées au compteur sans récidive (bonne conduite).

Tags fournis : `casier` (au moins une condamnation), `casier_lourd` (un crime), `tig` (TIG en cours), `casier_efface` (casier redevenu vierge).
Tant que le moteur n'a pas fait le branchement, les événements avec ces tags ne sortent pas, et le sous-objet `casier` est ignoré sans erreur.
