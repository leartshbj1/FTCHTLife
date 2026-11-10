# Mode Shkurtaaa

Mode triche / bonus activable dans **Paramètres**. C'est un drapeau global
(`Shkurtaaa.shared`, sauvegardé dans UserDefaults) que chaque système consulte.
Quand le mode est coupé, toutes les fonctions renvoient la valeur d'origine.

## Avantages (cochables un par un)

| Avantage | Effet | Par défaut |
|---|---|---|
| Compte en banque infini | Argent jamais sous 100 milliards | oui |
| Évasion express | Bouton « S'évader » qui marche à coup sûr | oui |
| Casier vierge | Jamais arrêté après un crime | non |
| Corps de fer | Santé ≥ 50 %, maladies guéries au premier traitement | oui |
| Moral d'acier | Bonheur ≥ 50 % | oui |
| Né parfait | Stats à 100 % à la naissance | oui |
| Piston partout | Embauche et promotions garanties | oui |
| Irrésistible | Drague, couple, mariage toujours acceptés | oui |
| Diplôme garanti | Admissions et examens réussis | oui |
| Vie éternelle | Pas de mort de vieillesse | non |

## Branchements à faire par chaque système

- **Paramètres** (moteur) : ajouter `ShkurtaaaSettingsSection()` dans le `Form`.
  Optionnel : `ShkurtaaaBadge()` dans l'en-tête de l'écran principal.
- **Argent** (boutique, salaire, amendes…) : après chaque modification,
  `argent = Shkurtaaa.argent(argent)`. Pour griser un bouton d'achat :
  `Shkurtaaa.peutPayer(prix, solde: argent)`.
- **Prison** : afficher `ShkurtaaaBoutonEvasion { libérer() }` sur l'écran prison,
  et passer la chance d'évasion normale dans `Shkurtaaa.chanceEvasion(_:)`.
  Après un crime : `Shkurtaaa.chanceArrestation(_:)`.
- **Santé / bonheur** : `Shkurtaaa.sante(_:)`, `Shkurtaaa.bonheur(_:)` après chaque
  modification, `Shkurtaaa.chanceGuerison(_:)` chez le médecin.
- **Naissance** : `Shkurtaaa.statNaissance(_:)` pour chaque stat.
- **Carrière / études / amour** : `chanceEmbauche`, `chancePromotion`,
  `chanceAdmission`, `chanceExamen`, `chanceSeduction`.
- **Mort** : `Shkurtaaa.peutMourir(deVieillesse:)` avant de tuer le personnage.
- **Journal** : `ShkurtaaaJournal.evasions.randomElement()` /
  `ShkurtaaaJournal.argent.randomElement()` pour un texte drôle.

Comme le moteur relit l'argent à chaque `+1 an`, il est aussi prudent d'appliquer
`Shkurtaaa.argent(_:)` au début de chaque année : ainsi, activer le mode en
cours de vie remonte le compte tout de suite.
