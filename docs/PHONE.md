# Téléphone et réseaux sociaux (module `FTCHTLife/Phone/`)

Dès 13 ans, le joueur reçoit un téléphone (écran déjà fissuré, évidemment). Il contient quatre applis
inventées et une messagerie :

| Appli (id) | Nom | Âge | Ce qu'on y fait | Stat qui aide |
|---|---|---|---|---|
| `pozz` | **Pozz** | 13+ | photos (selfies, plats, vacances…) | apparence |
| `tremousse` | **Trémousse** | 13+ | vidéos courtes, danses, défis, lives | bonheur (énergie) |
| `ronchon` | **Ronchon** | 15+ | messages courts, avis tranchés, clashs | intelligence |
| `pecho` | **Pécho** | 18+ | appli de rencontre (swipe, match, rendez-vous) | apparence |
| messagerie | **Messages** | 13+ | messages bizarres, arnaques, famille, haters, fans, offres de sponsors | — |

Mécaniques : poster (3 posts par appli et par an), abonnés par appli, buzz et bad buzz,
compte certifié à 100 000 abonnés, sponsors payés chaque année selon les abonnés (avec scandale possible
si la marque est louche), haters à gérer, faux abonnés à acheter (risqué), lives avec dons,
détox numérique, et les rendez-vous de Pécho qui peuvent finir en couple.

## Branchement par le fil moteur

Le module ne touche pas `App/`, `Engine/`, `Models/`, `Views/`. Pour le brancher :

1. **Sauvegarde** : ajouter à `Joueur` (`Models/Models.swift`) le champ
   ```swift
   var telephone: PhoneEtat?
   ```
   (optionnel : les anciennes sauvegardes restent lisibles).
2. **+1 an** : dans `GameEngine.vieillir()`, juste avant `j.journal.append(Annee(...))` :
   ```swift
   var tel = j.telephone ?? PhoneEtat()
   lignes += PhoneEngine.passerAnnee(&j, &tel, engine: self)
   j.telephone = tel
   ```
   C'est là que le téléphone est offert à 13 ans, que les abonnés évoluent, que les sponsors paient
   et que les nouveaux messages arrivent.
3. **Tags d'événements** (optionnel) : à la fin de `GameEngine.tags(_:)` :
   ```swift
   t.formUnion(PhoneEngine.tags(j.telephone))
   ```
   Tags ajoutés : `phone` (a un téléphone), `influencer` (≥ 10 000 abonnés au total),
   `star_reseaux` (≥ 1 000 000), `bad_buzz` (bad buzz cette année ou l'an dernier),
   `sponsorise` (au moins un contrat de sponsor).
4. **Écran** : ouvrir `TelephoneView(chemin: \.telephone)` (en feuille, comme les autres onglets),
   par exemple depuis un bouton « Téléphone » de la barre d'onglets ou de l'onglet Activités.
   `PhoneEngine.nonLus(j.telephone)` donne le nombre de messages non lus pour une pastille.

## Données (`FTCHTLife/Resources/Data/Phone/<Sous-dossier>/*.json`)

Chaque fichier est un **tableau**. Les ids sont uniques dans tout le module.
Valider avec `python3 tools/validate_phone.py`.

Variables de texte : celles du moteur (`{prenom}`, `{nom}`, `{ville}`, `{mere}`, `{pere}`, `{parent}`,
`{ami}`, `{fratrie}`, `{partenaire}`, `{metier}`, `{e}`) plus celles du téléphone :
`{app}` (nom de l'appli), `{abonnes}` (abonnés de l'appli, ex. « 12 400 »), `{gain}` (abonnés gagnés ou
perdus par ce post, toujours positif), `{marque}` (sponsor), `{montant}` (paiement du sponsor, ex. « 3 000 € »),
`{match}` (prénom de la personne rencontrée sur Pécho).

### `Posts/` : types de publication

```json
{
  "id": "pozz_selfie_miroir",
  "app": "pozz",
  "titre": "Selfie dans le miroir",
  "icone": "camera.fill",
  "minAge": 13,
  "maxAge": 120,
  "stat": "looks",
  "risque": 0.05,
  "viralite": 1.0,
  "cout": 0,
  "conditions": { "tags": ["adult"] },
  "textes": {
    "flop":    ["…", "…"],
    "moyen":   ["…", "…"],
    "succes":  ["…", "…"],
    "buzz":    ["…", "…"],
    "badbuzz": ["…", "…"]
  }
}
```
- `app` : `pozz`, `tremousse` ou `ronchon`.
- `stat` : `looks`, `smarts`, `happiness`, `karma` ou `none` (la stat qui fait réussir le post).
- `risque` (0 à 0,5) : chance de base de bad buzz. `viralite` (0,5 à 3) : potentiel de buzz. `cout` en euros.
- `conditions` (optionnel) : mêmes clés que les événements (`gender`, `minMoney`, `tags`, `excludeTags`…).
- `textes` : au moins 2 phrases par palier. Le résultat est tiré par le code (stat + hasard), le texte décrit la réaction.

### `Commentaires/` : commentaires affichés sous un post

```json
{ "id": "com_0001", "type": "hater", "app": "any", "minAbonnes": 0, "texte": "…" }
```
- `type` : `fan`, `hater`, `bizarre`, `famille`, `bot`. `app` : `any` ou un id d'appli.
- `texte` : un commentaire court, sans pseudo (le pseudo de l'auteur est généré par le code).

### `Messages/` : messagerie (messages avec choix)

```json
{
  "id": "msg_0001",
  "categorie": "arnaque",
  "expediteur": "Prince Aurélien du Liechtenstein",
  "minAge": 13,
  "maxAge": 120,
  "weight": 2,
  "unique": true,
  "minAbonnes": 0,
  "conditions": null,
  "text": "…",
  "choices": [
    { "label": "Envoyer 500 €", "outcomes": [
        { "chance": 1.0, "text": "…", "effects": { "money": -500, "happiness": -5 } }
    ] },
    { "label": "Bloquer", "outcomes": [ { "chance": 1.0, "text": "…", "effects": {} } ] }
  ]
}
```
- `categorie` : `bizarre`, `arnaque`, `famille`, `hater`, `fan`, `crush`, `ami`, `pro`.
- `minAbonnes` : abonnés totaux minimum (ex. 1 000 pour les haters et les fans).
- `effects` : clés d'effets des événements (`happiness`, `health`, `smarts`, `looks`, `karma`, `money`,
  `relationships`, `newFriend`…) plus deux clés propres au téléphone :
  `followers` (variation d'abonnés du compte principal, entier) et `followersPct` (variation en fraction,
  ex. `-0.2` = perd 20 %).

### `Sponsors/` : marques qui proposent un contrat

```json
{
  "id": "sp_the_detox",
  "marque": "Thé Pschitt Détox",
  "produit": "un thé qui fait surtout maigrir ton compte en banque",
  "app": "any",
  "minAbonnes": 5000,
  "minAge": 16,
  "tarif": 0.03,
  "minPaiement": 300,
  "louche": 0.3,
  "offre": "…",
  "accepte": "…",
  "scandale": "…"
}
```
- Paiement annuel = max(`minPaiement`, abonnés × `tarif`) euros. `louche` (0 à 1) : chance de scandale par an
  (bad buzz, karma −, fin du contrat).

### `Profils/` : profils de l'appli de rencontre Pécho

```json
{ "id": "pro_0001", "genre": "any", "minAge": 18, "maxAge": 99, "bio": "…" }
```
- Le prénom et l'âge sont générés par le code ; `bio` est la description (drôle) que la personne a écrite.
- `genre` : `any`, `male`, `female` (genre de la personne du profil).

### `RendezVous/` : déroulé d'un rendez-vous Pécho

```json
{ "id": "rdv_0001", "issue": "catastrophe", "texte": "…{match}…" }
```
- `issue` : `lapin` (on te pose un lapin), `catastrophe`, `bof`, `bien`, `coupdefoudre`.
  Un `coupdefoudre` sans partenaire actuel fait de `{match}` ton copain ou ta copine.
