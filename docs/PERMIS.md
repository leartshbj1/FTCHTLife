# Système de permis

13 permis : scooter (14 ans), voiture, moto, poids lourd, bus, bateau, avion, hélicoptère,
chasse, armes, pêche, drone… et fusée (30 ans, 2,5 millions la pratique).

## Comment ça marche dans le jeu

- **Code** : un quiz de 5 questions (réponses mélangées), il faut au plus une erreur.
  Questions drôles avec une explication après chaque réponse.
- **Pratique** : 3 situations à choix. Chaque choix a une chance de réussite (ajustée par
  l'intelligence, la santé, l'âge et la difficulté du permis). Plus d'une faute, ou une faute
  éliminatoire, et c'est raté. On garde le code.
- Une tentative de code et une de pratique par permis et par an. Avant 18 ans, les parents paient.
- **Points** (permis de la route) : 6 points en probatoire, +2 par an sans infraction pendant 3 ans,
  puis 12. Deux ans sans infraction = 12 points rendus. Stage de récupération : +4 points, 250 €, une fois par an.
  0 point = permis annulé, tout est à repasser.
- **Sanctions** : amendes, retrait de points, suspension (on ne peut plus conduire légalement),
  annulation, retrait des permis hors route, prison.
- **Conduite sans permis** : en sortie ponctuelle, ou en habitude (interrupteur). Contrôle de police :
  1re fois amende + fourrière, 2e fois amende + interdiction de passer le permis 2 ans,
  ensuite prison. Rouler pendant une suspension prolonge la suspension.
- **Combines** : acheter un faux permis (20 % d'arnaque, découvert à 60 % lors d'un contrôle),
  soudoyer l'examinateur (45 % ça passe, 20 % c'est un inspecteur infiltré).
- **Sorties** (une par an) : en voiture, à moto, en bateau, en avion, à la chasse… situations à choix
  avec de vraies conséquences (radar, alcool, accident, mort possible).
- **Incidents annuels** automatiques dans le journal : radars, accidents, contrôles, bons moments.

## Fichiers

| Fichier | Contenu |
|---|---|
| `Permis/PermisModeles.swift` | `PermisType`, `PermisEtat` (sauvegarde), formats JSON |
| `Permis/PermisLogique.swift` | `PermisModule` : règles, examens, sanctions, année, tags |
| `Permis/PermisView.swift` | écran Permis, quiz du code, situations |
| `Resources/Data/Permis/Code/*.json` | questions du code (`PermisQuestion`) |
| `Resources/Data/Permis/Pratique/*.json` | situations d'examen (`PermisScene`) |
| `Resources/Data/Permis/Route/*.json` | sorties avec ou sans permis (`PermisScene`, `permisRequis`) |
| `Resources/Data/Permis/Incidents/*.json` | incidents annuels (`PermisIncident`) |
| `Resources/Data/Events/permis.json` | événements classiques liés aux permis (format moteur, tags ci-dessous) |

## Branchement (fil moteur)

1. **Sauvegarde** : dans `Joueur`, ajouter `var permis: PermisEtat?` (optionnel : les anciennes
   sauvegardes restent lisibles).

2. **Tags** : à la fin de `GameEngine.tags(_:)` :
   ```swift
   t.formUnion(PermisModule.tags(j.permis, age: j.age))
   ```

3. **Année** : dans `vieillir()`, après le bloc Emploi (donc après `j.age += 1`) :
   ```swift
   var permis = j.permis ?? PermisEtat()
   let bilanPermis = PermisModule.passerAnnee(&j, &permis)
   j.permis = permis
   lignes += bilanPermis.lignes
   ```
   Puis, après `j.journal.append(Annee(age: j.age, lignes: lignes))` :
   ```swift
   if let cause = bilanPermis.mort { mourir(&j, cause: cause) }
   ```

4. **Écran** : ouvrir `PermisView(chemin: \.permis)` (feuille ou lien), par exemple depuis Activités
   (« Permis », icône `car.fill`, dès 10 ans). La vue utilise `engine.modifier`, `engine.ajouterLigne`
   et `engine.appliquer` (pour la mort).

5. **Branchements optionnels**, au lancement de l'app :
   ```swift
   // Mode Shkurtaaa « Diplôme garanti » : examens réussis (quiz compris).
   PermisModule.ajusterChanceExamen = { Shkurtaaa.chanceExamen($0) }
   // Prison du module crime (sinon : prison avec sursis).
   PermisModule.envoyerEnPrison = { j, ans, motif in /* ... */ }
   // Répercussions (docs/REPERCUSSIONS.md).
   PermisModule.signaler = { j, signal in
       var etat = j.repercussions ?? RepercussionsEtat()
       Repercussions.signaler(signal, age: j.age, etat: &etat)
       j.repercussions = etat
   }
   ```

6. **Métiers** : `CareerProfile.licenses = PermisModule.licences(j.permis, age: j.age)`
   (seulement les permis valides : un permis suspendu, annulé ou faux n'y est pas).

## Identifiants partagés

Clés de permis (`PermisType.cle`), utilisées comme tags d'événements et comme licences pour les métiers :
`permis_scooter`, `permis_voiture`, `permis_moto`, `permis_poids_lourd`, `permis_bus`, `permis_bateau`,
`licence_pilote` (avion), `licence_helico`, `permis_chasse`, `permis_armes`, `carte_peche`,
`brevet_drone`, `permis_fusee`.

Autres tags : `conducteur` (peut conduire légalement), `sans_permis` (18+ sans permis voiture),
`permis_probatoire`, `permis_points_bas` (≤ 4 points), `permis_suspendu`, `permis_annule`,
`conduit_sans_permis` (habitude), `faux_permis`, `pilote`, `chasseur`, `chauffard` (5 infractions ou plus).

Signaux de répercussions émis : `permis_code_obtenu`, `permis_code_rate`, `permis_obtenu`, `permis_rate`,
`permis_retire`, `permis_suspendu`, `permis_annule`, `permis_points_recuperes`, `amende_vitesse`,
`accident_voiture`, `faux_permis_achete`, `faux_permis_demasque`, `conduite_sans_permis_arretee`,
`corruption_examinateur`, `corruption_ratee`.

## Ajouter du contenu

- Question : `{"id", "permis": ["route" | "<type>"], "question", "reponses": [...], "bonne": <index>, "explication"}`.
  Mettez la bonne réponse n'importe où, les réponses sont mélangées à l'affichage.
- Situation : `{"id", "permis": [...], "text", "permisRequis": "avec" | "sans", "minAge", "maxAge", "weight", "choices": [...]}`.
  Choix : `label`, `chance` (0 à 1), `success`, `failure`, `faute` (`"mineure"` ou `"eliminatoire"`, examen),
  `onSuccess` / `onFailure` (effets).
- Effets : `happiness`, `health`, `smarts`, `looks`, `karma`, `money`, `points` (retirés), `infraction` (libellé),
  `suspension` (années), `annulation`, `retrait`, `prison` (années), `controle` (contrôle de police),
  `death`, `signal`.
- Types : `scooter`, `voiture`, `moto`, `poidsLourd`, `bus`, `bateau`, `avion`, `helicoptere`, `chasse`,
  `armes`, `peche`, `drone`, `fusee` ; `route` = les cinq premiers ; `any` = tous.
- Variables : `{prenom}`, `{nom}`, `{ville}`, `{mere}`, `{pere}`, `{ami}`, `{partenaire}`, `{points}`, `{e}`.
