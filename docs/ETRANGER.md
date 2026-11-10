# Module « Vivre à l'étranger »

Le joueur peut s'installer dans 26 pays (les mêmes ids que la création de perso). Chaque pays change
les salaires, les prix, les impôts, le prix des soins, la difficulté du visa, la durée avant la naturalisation,
et apporte ses lois, ses coutumes et ses propres événements (culture, malentendus de langue).
On apprend la langue par immersion chaque année ou en prenant des cours.

## Fichiers

| Fichier | Contenu |
|---|---|
| `FTCHTLife/Etranger/ExpatModeles.swift` | `ExpatPays`, `ExpatLangue`, `ExpatLoi`, `ExpatCatalogue` (chargement), `ExpatEtat` (sauvegarde) |
| `FTCHTLife/Etranger/ExpatMoteur.swift` | règles : visa, déménagement, langues, coût de la vie, naturalisation, tags ; `ExpatPontLangues` |
| `FTCHTLife/Etranger/ExpatView.swift` | écran « Vivre à l'étranger » et fiche pays |
| `Resources/Data/Etranger/pays.json` | les 26 pays (coefficients, visa, lois, coutumes, villes) |
| `Resources/Data/Etranger/langues.json` | 15 langues (difficulté pour un francophone, bonjour, merci) |
| `Resources/Data/Events/etranger_*.json` | événements au format standard, filtrés par les tags du module |
| `docs/ETRANGER_EVENTS.md` | consignes d'écriture et liste des tags |
| `tools/validate_etranger.py` | vérification des données |

Le module ne touche à aucun fichier du moteur. Tout passe par des fonctions pures sur `Joueur` + `ExpatEtat`.

## Règles du jeu

- **Départ** : 18 ans minimum. Coût = déménagement du pays + frais de visa éventuels.
- **Visa** : aucun pour un pays dont on a la nationalité ou en libre circulation (UE + Suisse entre eux).
  Sinon frais de dossier (80 € + 120 € × difficulté) et chances selon la difficulté (85 % à 30 %), le diplôme,
  l'argent (visa investisseur), la langue, le karma. Un refus bloque ce pays jusqu'à l'année suivante.
- **En partant** : 25 % de chances d'être muté (salaire ajusté au pays), sinon on perd son emploi.
  Le partenaire suit selon le lien (sinon il devient un ex), les amis s'éloignent, les études continuent.
- **Chaque année** (`finAnnee`) : immersion dans la langue du pays (plus lente pour le japonais que pour
  l'espagnol, plus rapide pour les enfants), coût de la vie (12 000 € × (1 − coefficient prix) par an), correction
  d'impôts (le moteur prend 25 %, le pays prend son taux), mal du pays les deux premières années,
  naturalisation possible après N années si on parle assez bien la langue.
- **Salaire local** : `salaireLocal(base, …)` = salaire de base × coefficient du pays, −20 % si on parle mal la langue.

## Branchement dans le moteur (fil moteur)

1. **Sauvegarde** : ajouter à `Joueur` le champ `var etranger: ExpatEtat?`.
   À la naissance : `j.etranger = ExpatEtat.naissance(pays: draft.countryID, ville: draft.city)`
   (ou `pays: "fr"` sans création de perso). Une vieille sauvegarde sans le champ : créer l'état à la volée,
   comme ci-dessous.

   ```swift
   extension Joueur {
       var etatExpat: ExpatEtat { etranger ?? ExpatEtat.naissance(pays: "fr", ville: ville, age: age) }
   }
   ```

2. **Tags** : dans `GameEngine.tags(_:)`, ajouter
   `t.formUnion(ExpatMoteur.tags(j.etatExpat, j))`.

3. **Année** : dans `vieillir()`, après les relations et avant `j.journal.append(...)` :

   ```swift
   var e = j.etatExpat
   lignes += ExpatMoteur.finAnnee(&j, &e)
   j.etranger = e
   ```

4. **Écran** : un bouton « Vivre à l'étranger » (par ex. dans Activités ou Profil) qui ouvre

   ```swift
   ExpatView(etat: { $0.etatExpat },
             ecrire: { j, e in j.etranger = e },
             visaToujoursAccepte: Shkurtaaa.actif)   // mode triche : visa toujours accepté
       .environmentObject(engine)
   ```

5. **Variable `{pays}`** (facultatif) : `ExpatMoteur.paysActuel(j.etatExpat).nom`.

6. **Prix** (facultatif mais conseillé) :
   - offres d'emploi : `ExpatMoteur.salaireLocal(metier.salaire, j.etatExpat, j)` ;
   - boutique, activités : `ExpatMoteur.prixLocal(prix, j.etatExpat)` ;
   - médecin, hôpital : `ExpatMoteur.prixSoin(prix, j.etatExpat)`.

7. **Langues du module Compétences** (anglais, espagnol, allemand, italien, albanais, japonais, portugais, arabe) :
   la compétence fait foi. Brancher le pont une fois au démarrage :

   ```swift
   let competencesLangues = ["en": "anglais", "es": "espagnol", "de": "allemand",
                             "it": "italien", "sq": "albanais", "ja": "japonais",
                             "pt": "portugais", "ar": "arabe"]
   ExpatPontLangues.lire = { id, j in competencesLangues[id].map { Competences.xp($0, j) } }
   ExpatPontLangues.gagner = { id, n, j in
       guard let c = competencesLangues[id] else { return [] }
       return Competences.gagner(c, n, &j).messages
   }
   ```

   Sans pont, le module garde lui-même tous les niveaux dans `ExpatEtat.langues`.

## Pour les autres modules

- Pays actuel : `ExpatMoteur.paysActuel(j.etatExpat)` (`.id`, `.nom`, `.lois`…). Nécrologie : `ExpatEtat.sejours`.
- Lois : tags `loi_<id>` (ex. `loi_conduite_gauche` pour le permis, `loi_cannabis_legal`, `loi_alcool_21`, `loi_sante_chere`).
- Niveau dans une langue : `ExpatMoteur.niveau("ja", e, j)`.

## Ajouter un pays

Ajouter un objet dans `pays.json` (même id que dans `Creation/creation_data.json` si possible), puis
des événements `etranger_<id>.json` avec les tags `["etranger", "pays_<id>"]`. Lancer `python3 tools/validate_etranger.py`.
