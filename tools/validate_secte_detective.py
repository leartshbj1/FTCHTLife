#!/usr/bin/env python3
"""Vérifie les données des modules Secte et Agence de détective (docs/SECTE_DETECTIVE.md) :
- Data/Secte/doctrines.json, Data/SecteEvents/*.json ;
- Data/Detective/affaires.json, Data/DetectiveEvents/*.json.
Les suites (Data/Repercussions/secte_*.json, detective_*.json) sont vérifiées par tools/validate_repercussions.py.

Usage : python3 tools/validate_secte_detective.py
"""
import glob
import json
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(os.path.dirname(ICI), "FTCHTLife", "Resources", "Data")

COMPETENCES = set("""anglais espagnol allemand italien albanais japonais portugais arabe guitare piano chant danse dessin
photo cuisine bricolage mecanique jardinage sport survie code echecs seduction eloquence humour marchandage magie""".split())
EFFETS = {"happiness", "health", "smarts", "looks", "karma", "money", "relationships", "setFlags", "clearFlags",
          "followUps", "skills", "newFriend", "death"}
RELATIONS = {"mother", "father", "parent", "sibling", "friend", "partner", "child"}
STD_PH = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e"}
SECTE_PH = STD_PH | {"secte", "doctrine", "adeptes", "nb", "gourou", "proche"}
AGENCE_PH = STD_PH | {"agence", "client", "cible", "affaire", "enqueteur"}
SECTE_EFF = {"adeptes", "adeptesPct", "ferveur", "derive", "surveillance", "notoriete", "tresor", "tresorPct", "enquete",
             "defense", "prisonMois", "infraction", "dissoudre", "signal"}
SECTE_COND = {"minAdeptes", "maxAdeptes", "minFerveur", "maxFerveur", "minDerive", "maxDerive", "minSurveillance",
              "minNotoriete", "minTresor", "lieux", "enquete", "procheMembre", "minAnnees"}
SECTE_KINDS = {"vie", "derive", "exterieur", "enquete"}
LIEUX = {"salon", "local", "temple", "domaine"}
AGENCE_EFF = {"reputation", "paiement", "bonus", "plainte", "suspension", "prisonMois", "infraction", "celebre",
              "enqueteurPart", "enqueteurCompetence", "signal"}
AGENCE_COND = {"minReputation", "maxReputation", "minEnqueteurs", "affaireEnCours", "typesAffaire", "sansAgrement",
               "minEquipement", "minBureau", "minResolues", "minAnnees"}
AGENCE_KINDS = {"agence", "terrain", "equipe", "police", "presse"}
METHODES = {"filature", "planque", "terrain", "recherches", "infiltration", "limite"}
SIGNAUX = set("""secte_fondee secte_mouvement secte_proche_recrute secte_prelevement secte_regles_strictes secte_scandale
secte_enquete secte_perquisition secte_proces secte_condamnation secte_relaxe secte_dissoute
agence_ouverte agence_affaire_resolue agence_affaire_ratee agence_affaire_celebre agence_methode_limite agence_plainte
agence_suspendue agence_blessure agence_menace agence_fermee""".split())
RE_PH = re.compile(r"\{([a-z_]+)\}")
RE_ID = re.compile(r"^[a-z0-9_]+$")

erreurs = []
ids = set()


def lire(chemin):
    try:
        with open(chemin, encoding="utf-8") as f:
            d = json.load(f)
    except Exception as ex:  # noqa: BLE001
        erreurs.append(f"{os.path.basename(chemin)} : JSON invalide ({ex})")
        return []
    if not isinstance(d, list):
        erreurs.append(f"{os.path.basename(chemin)} : doit être un tableau")
        return []
    return d


def texte(t, ou, ph):
    if not isinstance(t, str) or not t.strip():
        erreurs.append(f"{ou} : texte vide")
        return
    for v in RE_PH.findall(t):
        if v not in ph:
            erreurs.append(f"{ou} : variable inconnue {{{v}}}")


def effets(e, ou):
    if not isinstance(e, dict):
        erreurs.append(f"{ou} : effects doit être un objet")
        return
    for k, v in e.items():
        if k not in EFFETS:
            erreurs.append(f"{ou} : effet inconnu {k}")
        elif k in ("happiness", "health", "smarts", "looks", "karma"):
            if not isinstance(v, int) or abs(v) > 100:
                erreurs.append(f"{ou} : {k} doit être un entier entre -100 et 100")
        elif k == "money" and not isinstance(v, int):
            erreurs.append(f"{ou} : money doit être un entier")
        elif k == "relationships":
            for r in v:
                if r not in RELATIONS:
                    erreurs.append(f"{ou} : relation inconnue {r}")
        elif k == "skills":
            for s in v:
                if s not in COMPETENCES:
                    erreurs.append(f"{ou} : compétence inconnue {s}")


def module(m, ou, autorises):
    if not isinstance(m, dict):
        erreurs.append(f"{ou} : doit être un objet")
        return
    for k, v in m.items():
        if k not in autorises:
            erreurs.append(f"{ou} : champ inconnu {k}")
        elif k == "signal" and v not in SIGNAUX:
            erreurs.append(f"{ou} : signal inconnu {v}")
        elif k == "infraction" and not isinstance(v, str):
            erreurs.append(f"{ou} : infraction doit être un texte")
    if "infraction" in m and "prisonMois" not in m:
        erreurs.append(f"{ou} : infraction sans prisonMois")


def choix(liste, ou, ph, cle_module, autorises):
    if not isinstance(liste, list) or not liste:
        erreurs.append(f"{ou} : il faut au moins un choix")
        return
    if len(liste) > 4:
        erreurs.append(f"{ou} : 4 choix maximum")
    if all(c.get("requiresSkill") for c in liste):
        erreurs.append(f"{ou} : il faut au moins un choix sans requiresSkill")
    for i, c in enumerate(liste):
        w = f"{ou} choix {i}"
        texte(c.get("label"), w, ph)
        for s, n in (c.get("requiresSkill") or {}).items():
            if s not in COMPETENCES or not 1 <= n <= 5:
                erreurs.append(f"{w} : requiresSkill invalide {s}={n}")
        if "cost" in c and (not isinstance(c["cost"], int) or c["cost"] < 0):
            erreurs.append(f"{w} : cost doit être un entier positif")
        outs = c.get("outcomes")
        if not isinstance(outs, list) or not outs:
            erreurs.append(f"{w} : il faut au moins une issue")
            continue
        for k, o in enumerate(outs):
            wo = f"{w} issue {k}"
            for cle in o:
                if cle not in ("chance", "text", "effects", cle_module):
                    erreurs.append(f"{wo} : champ inconnu {cle}")
            texte(o.get("text"), wo, ph)
            if "effects" in o:
                effets(o["effects"], wo)
            if cle_module in o:
                module(o[cle_module], f"{wo} {cle_module}", autorises)


def unique_id(i, ou, prefixe):
    if not isinstance(i, str) or not RE_ID.match(i) or not i.startswith(prefixe):
        erreurs.append(f"{ou} : id invalide {i!r} (préfixe {prefixe})")
    if i in ids:
        erreurs.append(f"{ou} : id en double {i}")
    ids.add(i)


def secte():
    doctrines = lire(os.path.join(DATA, "Secte", "doctrines.json"))
    noms_doctrines = set()
    for d in doctrines:
        ou = f"doctrine {d.get('id')}"
        for k in ("id", "nom", "icone", "description", "adeptesNom", "titreGourou", "donMoyen", "attrait", "risque",
                  "nomsSuggeres", "preches"):
            if k not in d:
                erreurs.append(f"{ou} : champ manquant {k}")
        noms_doctrines.add(d.get("id"))
        if len(d.get("titreGourou", [])) != 2:
            erreurs.append(f"{ou} : titreGourou = [masculin, féminin]")
        for p in d.get("preches", []):
            texte(p, ou, SECTE_PH)
    n = 0
    stades = {1: 0, 2: 0, 3: 0, 4: 0}
    for chemin in sorted(glob.glob(os.path.join(DATA, "SecteEvents", "*.json"))):
        for e in lire(chemin):
            n += 1
            ou = f"{os.path.basename(chemin)}/{e.get('id')}"
            unique_id(e.get("id"), ou, "sec_")
            for k in e:
                if k not in ("id", "kind", "doctrines", "weight", "unique", "conditions", "text", "choices"):
                    erreurs.append(f"{ou} : champ inconnu {k}")
            if e.get("kind") not in SECTE_KINDS:
                erreurs.append(f"{ou} : kind inconnu {e.get('kind')}")
            for d in e.get("doctrines") or []:
                if d not in noms_doctrines:
                    erreurs.append(f"{ou} : doctrine inconnue {d}")
            c = e.get("conditions") or {}
            for k, v in c.items():
                if k not in SECTE_COND:
                    erreurs.append(f"{ou} : condition inconnue {k}")
                elif k == "lieux" and not set(v) <= LIEUX:
                    erreurs.append(f"{ou} : lieu inconnu {v}")
            if e.get("kind") == "enquete":
                s = c.get("enquete")
                if s not in stades:
                    erreurs.append(f"{ou} : une carte d'enquête doit avoir conditions.enquete entre 1 et 4")
                else:
                    stades[s] += 1
            if "proche" in RE_PH.findall(json.dumps(e, ensure_ascii=False)) and not c.get("procheMembre"):
                erreurs.append(f"{ou} : {{proche}} demande conditions.procheMembre")
            texte(e.get("text"), ou, SECTE_PH)
            choix(e.get("choices"), ou, SECTE_PH, "secte", SECTE_EFF)
    for s, k in stades.items():
        if k == 0:
            erreurs.append(f"SecteEvents : aucune carte pour le stade d'enquête {s}")
    return len(doctrines), n


def agence():
    types = lire(os.path.join(DATA, "Detective", "affaires.json"))
    for t in types:
        ou = f"affaire {t.get('id')}"
        unique_id(t.get("id"), ou, "")
        for k in ("id", "nom", "icone", "description", "honoraires", "difficulte", "duree", "reputationMin", "danger",
                  "clients", "cibles", "indices", "denouements"):
            if k not in t:
                erreurs.append(f"{ou} : champ manquant {k}")
        for k in ("honoraires", "difficulte"):
            v = t.get(k)
            if not (isinstance(v, list) and len(v) == 2 and v[0] <= v[1]):
                erreurs.append(f"{ou} : {k} = [min, max]")
        for m in (t.get("methodes") or {}):
            if m not in METHODES:
                erreurs.append(f"{ou} : méthode inconnue {m}")
        for cle in ("clients", "cibles", "indices"):
            if not t.get(cle):
                erreurs.append(f"{ou} : {cle} vide")
            for x in t.get(cle, []):
                texte(x, f"{ou} {cle}", AGENCE_PH)
        for i, d in enumerate(t.get("denouements", [])):
            texte(d.get("text"), f"{ou} dénouement {i}", AGENCE_PH)
            choix(d.get("choices"), f"{ou} dénouement {i}", AGENCE_PH, "agence", AGENCE_EFF)
    noms_types = {t.get("id") for t in types}
    n = 0
    for chemin in sorted(glob.glob(os.path.join(DATA, "DetectiveEvents", "*.json"))):
        for e in lire(chemin):
            n += 1
            ou = f"{os.path.basename(chemin)}/{e.get('id')}"
            unique_id(e.get("id"), ou, "det_")
            for k in e:
                if k not in ("id", "kind", "weight", "unique", "conditions", "text", "choices"):
                    erreurs.append(f"{ou} : champ inconnu {k}")
            if e.get("kind") not in AGENCE_KINDS:
                erreurs.append(f"{ou} : kind inconnu {e.get('kind')}")
            c = e.get("conditions") or {}
            for k, v in c.items():
                if k not in AGENCE_COND:
                    erreurs.append(f"{ou} : condition inconnue {k}")
                elif k == "typesAffaire":
                    for x in v:
                        if x not in noms_types:
                            erreurs.append(f"{ou} : type d'affaire inconnu {x}")
            usage = set(RE_PH.findall(json.dumps(e, ensure_ascii=False)))
            if usage & {"client", "cible", "affaire"} and not c.get("affaireEnCours"):
                erreurs.append(f"{ou} : {{client}}/{{cible}}/{{affaire}} demandent conditions.affaireEnCours")
            if "enqueteur" in usage and not c.get("minEnqueteurs"):
                erreurs.append(f"{ou} : {{enqueteur}} demande conditions.minEnqueteurs")
            texte(e.get("text"), ou, AGENCE_PH)
            choix(e.get("choices"), ou, AGENCE_PH, "agence", AGENCE_EFF)
    return len(types), n


if __name__ == "__main__":
    nd, ns = secte()
    nt, na = agence()
    for e in erreurs:
        print("ERREUR", e)
    print(f"Secte : {nd} doctrines, {ns} événements. Agence : {nt} types d'affaires, {na} événements. {len(erreurs)} erreurs")
    sys.exit(1 if erreurs else 0)
