#!/usr/bin/env python3
"""Vérifie les données du module Compétences (voir docs/COMPETENCES.md).

Sans argument : vérifie
  - FTCHTLife/Resources/Data/Competences/*.json        (liste des compétences)
  - FTCHTLife/Resources/Data/CompetencesCours/*.json   (cours)
  - FTCHTLife/Resources/Data/CompetencesSources/*.json (gains automatiques : métiers, études, école, activités)
  - tous les événements de FTCHTLife/Resources/Data/Events/*.json qui utilisent les clés
    de compétences (requiresSkill, conditions.skills, effects.skills), et en entier les fichiers competences_*.json.

Avec des chemins : vérifie seulement ces fichiers d'événements (en entier).
Sortie 0 si tout va bien, 1 sinon.
"""
import json
import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(RACINE, "FTCHTLife", "Resources", "Data")

CLES_EFFETS = {"happiness", "health", "smarts", "looks", "karma", "money", "stress", "fame",
               "relationships", "newFriend", "death", "skills",
               # clés ajoutées par d'autres modules (répercussions)
               "setFlags", "clearFlags", "followUps"}
CLES_LIENS = {"mother", "father", "parent", "sibling", "friend", "partner", "child"}
CLES_CONDITIONS = {"gender", "minMoney", "maxMoney", "requiresJob", "requiresPartner", "requiresSchool",
                   "tags", "excludeTags", "skills", "flags", "excludeFlags"}
TAGS = {"male", "female", "baby", "school", "university", "job", "adult", "unemployed", "retired",
        "rich", "poor", "friend", "mother", "father", "siblings", "partner", "children", "sick",
        "attractive", "smart"}
VARIABLES = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e"}
CATEGORIES = {"langues", "arts", "pratique", "corps", "tete", "social"}
TYPES_SOURCES = {"metier", "filiere", "ecole", "activite", "etudes", "retraite"}

erreurs = []


def err(f, ident, msg):
    erreurs.append(f"{os.path.relpath(f, RACINE)} [{ident}] : {msg}")


def charger(f):
    try:
        with open(f, encoding="utf-8") as h:
            d = json.load(h)
    except Exception as e:  # noqa: BLE001
        err(f, "-", f"JSON invalide : {e}")
        return None
    if not isinstance(d, list):
        err(f, "-", "le fichier doit contenir un tableau")
        return None
    return d


def fichiers(dossier):
    p = os.path.join(DATA, dossier)
    if not os.path.isdir(p):
        return []
    return sorted(os.path.join(p, n) for n in os.listdir(p) if n.endswith(".json"))


def verifier_texte(f, ident, t, champ="text"):
    if not isinstance(t, str) or not t.strip():
        err(f, ident, f"{champ} vide")
        return
    for v in re.findall(r"\{([^}]*)\}", t):
        if v not in VARIABLES:
            err(f, ident, f"variable inconnue {{{v}}} dans {champ}")


def verifier_niveaux(f, ident, d, champ, ids):
    if not isinstance(d, dict) or not d:
        err(f, ident, f"{champ} doit être un objet non vide")
        return
    for k, v in d.items():
        if ids is not None and k not in ids:
            err(f, ident, f"{champ} : compétence inconnue « {k} »")
        if not isinstance(v, int) or not 1 <= v <= 5:
            err(f, ident, f"{champ} : niveau de « {k} » doit être un entier de 1 à 5")


def verifier_gains(f, ident, d, champ, ids, mini=-30, maxi=40):
    if not isinstance(d, dict) or not d:
        err(f, ident, f"{champ} doit être un objet non vide")
        return
    for k, v in d.items():
        if ids is not None and k not in ids:
            err(f, ident, f"{champ} : compétence inconnue « {k} »")
        if not isinstance(v, int) or not mini <= v <= maxi:
            err(f, ident, f"{champ} : gain de « {k} » doit être un entier entre {mini} et {maxi}")


def verifier_effets(f, ident, e, ids):
    if e is None:
        return
    if not isinstance(e, dict):
        err(f, ident, "effects doit être un objet")
        return
    for k, v in e.items():
        if k not in CLES_EFFETS:
            err(f, ident, f"clé d'effet inconnue « {k} »")
        elif k == "relationships":
            if not isinstance(v, dict) or not set(v) <= CLES_LIENS:
                err(f, ident, "relationships invalide")
        elif k == "skills":
            verifier_gains(f, ident, v, "effects.skills", ids)
        elif k in {"newFriend"}:
            if not isinstance(v, bool):
                err(f, ident, f"{k} doit être true/false")
        elif k in {"death"}:
            if not isinstance(v, str):
                err(f, ident, "death doit être un texte")
        elif k in {"setFlags", "clearFlags", "followUps"}:
            if not isinstance(v, list):
                err(f, ident, f"{k} doit être une liste")
        elif not isinstance(v, int):
            err(f, ident, f"{k} doit être un entier")


def utilise_competences(ev):
    s = json.dumps(ev, ensure_ascii=False)
    return '"requiresSkill"' in s or '"skills"' in s


def verifier_evenements(chemins, ids, tout=False, ids_vus=None):
    ids_vus = ids_vus if ids_vus is not None else {}
    total = 0
    caches = 0
    for f in chemins:
        d = charger(f)
        if d is None:
            continue
        complet = tout or os.path.basename(f).startswith("competences_")
        for ev in d:
            ident = ev.get("id", "?") if isinstance(ev, dict) else "?"
            if not isinstance(ev, dict):
                err(f, ident, "événement non objet")
                continue
            if ident in ids_vus:
                err(f, ident, f"id déjà utilisé dans {ids_vus[ident]}")
            ids_vus[ident] = os.path.basename(f)
            if not (complet or utilise_competences(ev)):
                continue
            total += 1
            if complet and not re.fullmatch(r"cmp_\d{4}", ident):
                err(f, ident, "id attendu : cmp_NNNN")
            for c in ("minAge", "maxAge"):
                if not isinstance(ev.get(c), int):
                    err(f, ident, f"{c} manquant")
            if isinstance(ev.get("minAge"), int) and isinstance(ev.get("maxAge"), int) and ev["minAge"] > ev["maxAge"]:
                err(f, ident, "minAge > maxAge")
            verifier_texte(f, ident, ev.get("text"))
            cond = ev.get("conditions") or {}
            for k, v in cond.items():
                if k not in CLES_CONDITIONS:
                    err(f, ident, f"condition inconnue « {k} »")
                elif k in ("tags", "excludeTags"):
                    for t in v or []:
                        if t not in TAGS:
                            err(f, ident, f"tag inconnu « {t} »")
                elif k == "skills":
                    verifier_niveaux(f, ident, v, "conditions.skills", ids)
                elif k == "gender" and v not in (None, "any", "male", "female"):
                    err(f, ident, "gender invalide")
            texte_complet = ev.get("text", "")
            choix = ev.get("choices") or []
            if not choix:
                verifier_effets(f, ident, ev.get("effects"), ids)
            if complet and not 2 <= len(choix) <= 4:
                err(f, ident, "2 à 4 choix attendus")
            libres = 0
            for i, c in enumerate(choix):
                cid = f"{ident} choix {i}"
                if not isinstance(c.get("label"), str) or not c["label"].strip():
                    err(f, cid, "label vide")
                for k in c:
                    if k not in ("label", "outcomes", "requiresSkill"):
                        err(f, cid, f"clé de choix inconnue « {k} »")
                if "requiresSkill" in c:
                    caches += 1
                    verifier_niveaux(f, cid, c["requiresSkill"], "requiresSkill", ids)
                else:
                    libres += 1
                issues = c.get("outcomes") or []
                if not 1 <= len(issues) <= 3:
                    err(f, cid, "1 à 3 issues attendues")
                somme = 0.0
                for o in issues:
                    somme += float(o.get("chance", 1))
                    verifier_texte(f, cid, o.get("text"))
                    texte_complet += " " + str(o.get("text", ""))
                    verifier_effets(f, cid, o.get("effects"), ids)
                if complet and issues and abs(somme - 1) > 0.011:
                    err(f, cid, f"somme des chances = {somme:.2f} (attendu 1)")
            if choix and libres == 0:
                err(f, ident, "il faut au moins un choix sans requiresSkill")
            if "{partenaire}" in texte_complet and cond.get("requiresPartner") is not True \
                    and "partner" not in (cond.get("tags") or []):
                err(f, ident, "{partenaire} utilisé sans requiresPartner: true")
            if "{metier}" in texte_complet and cond.get("requiresJob") is not True \
                    and "job" not in (cond.get("tags") or []):
                err(f, ident, "{metier} utilisé sans requiresJob: true")
    return total, caches


def main():
    args = sys.argv[1:]
    ids = None
    liste = []
    for f in fichiers("Competences"):
        d = charger(f)
        if d:
            liste += [(f, x) for x in d]
    if liste:
        ids = set()
        for f, c in liste:
            ident = c.get("id", "?")
            if not re.fullmatch(r"[a-z]+", ident or ""):
                err(f, ident, "id en minuscules sans accent ni espace")
            if ident in ids:
                err(f, ident, "id en double")
            ids.add(ident)
            for k in ("nom", "icone", "description", "debloque"):
                if not isinstance(c.get(k), str) or not c[k].strip():
                    err(f, ident, f"{k} manquant")
            if c.get("categorie") not in CATEGORIES:
                err(f, ident, f"categorie doit être parmi {sorted(CATEGORIES)}")
            if not isinstance(c.get("minAge"), int):
                err(f, ident, "minAge manquant")
            titres = c.get("titres")
            if not isinstance(titres, list) or len(titres) != 5:
                err(f, ident, "titres : 5 textes (niveaux 1 à 5)")
            paliers = c.get("paliers")
            if not isinstance(paliers, list) or len(paliers) != 5:
                err(f, ident, "paliers : 5 textes (niveaux 1 à 5)")
            else:
                for t in paliers:
                    verifier_texte(f, ident, t, "paliers")
            p = c.get("pratique") or {}
            for k in ("debut", "milieu", "maitre"):
                if not isinstance(p.get(k), list) or len(p[k]) < 2:
                    err(f, ident, f"pratique.{k} : au moins 2 textes")
                else:
                    for t in p[k]:
                        verifier_texte(f, ident, t, f"pratique.{k}")
            verifier_effets(f, ident, p.get("effects"), ids)
            for a in p.get("accidents") or []:
                verifier_texte(f, ident, a.get("text"), "accident")
                verifier_effets(f, ident, a.get("effects"), ids)
                if not 0 < float(a.get("chance", 0)) <= 1:
                    err(f, ident, "accident.chance entre 0 et 1")
    elif not args:
        err(DATA, "-", "aucune compétence trouvée dans Data/Competences")

    if not args:
        for f in fichiers("CompetencesCours"):
            for c in charger(f) or []:
                ident = c.get("id", "?")
                if ids is not None and c.get("competence") not in ids:
                    err(f, ident, f"competence inconnue « {c.get('competence')} »")
                for k in ("titre", "description"):
                    if not isinstance(c.get(k), str) or not c[k].strip():
                        err(f, ident, f"{k} manquant")
                if not isinstance(c.get("cout"), int) or c["cout"] < 0:
                    err(f, ident, "cout : entier positif")
                g = c.get("gain")
                if not (isinstance(g, list) and len(g) == 2 and all(isinstance(x, int) for x in g) and 0 < g[0] <= g[1] <= 40):
                    err(f, ident, "gain : [min, max] entre 1 et 40")
                if not isinstance(c.get("textes"), list) or len(c["textes"]) < 2:
                    err(f, ident, "textes : au moins 2")
                for t in c.get("textes") or []:
                    verifier_texte(f, ident, t, "textes")
                verifier_effets(f, ident, c.get("effects"), ids)
                for k in ("niveauMin", "niveauMax"):
                    if k in c and not (isinstance(c[k], int) and 0 <= c[k] <= 5):
                        err(f, ident, f"{k} entre 0 et 5")
        for f in fichiers("CompetencesSources"):
            for s in charger(f) or []:
                ident = s.get("id", "?")
                if s.get("type") not in TYPES_SOURCES:
                    err(f, ident, f"type parmi {sorted(TYPES_SOURCES)}")
                verifier_gains(f, ident, s.get("gains"), "gains", ids, 1, 15)
                if s.get("type") in ("metier", "filiere", "activite") and not (s.get("ids") or s.get("motsCles")):
                    err(f, ident, "ids ou motsCles requis")

    if args:
        total, caches = verifier_evenements([os.path.abspath(a) for a in args], ids, tout=True)
    else:
        total, caches = verifier_evenements(fichiers("Events"), ids)

    if erreurs:
        print("\n".join(erreurs))
        print(f"\n{len(erreurs)} erreur(s).")
        return 1
    print(f"OK : {len(ids or [])} compétences, {total} événements vérifiés, {caches} choix cachés.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
