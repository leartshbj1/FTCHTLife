#!/usr/bin/env python3
"""Valide les données du module Voyages sur mesure (docs/VOYAGES.md).

Usage : python3 tools/validate_voyages.py [fichiers moments_*.json...]
Sans argument : destinations.json et tous les moments_*.json de FTCHTLife/Resources/Data/Voyages.
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "FTCHTLife/Resources/Data/Voyages")

CONTINENTS = {"europe", "afrique", "asie", "amerique", "oceanie", "antarctique"}
CLIMATS = {"tempere", "chaud", "tropical", "froid", "desert"}
ACCES = {"route", "ferry", "mer", "avion"}
PHASES = {"trajet", "sejour", "retour"}
AVEC = {"partenaire", "parent", "enfant", "fratrie", "ami"}
TRANSPORTS = {"train", "autocar", "covoiturage", "autostop", "voitureLocation", "avionLowCost", "avionEco",
              "avionBusiness", "avionPremiere", "jetLocation", "ferry", "croisiere", "maVoiture", "maMoto",
              "monBateau", "monAvion"}
GROUPES = {"rail", "route", "avion", "mer", "perso", "luxe"}
HEBERGEMENTS = {"camping", "auberge", "habitant", "hotel", "luxe", "palace"}
DUREES = {3, 7, 14, 30}
SKILLS = {"anglais", "espagnol", "allemand", "italien", "albanais", "japonais", "arabe", "portugais", "guitare",
          "piano", "chant", "danse", "dessin", "photo", "cuisine", "bricolage", "mecanique", "jardinage", "sport",
          "survie", "code", "echecs", "seduction", "eloquence", "humour", "marchandage", "magie"}
LANGUES = {"fr", "en", "es", "it", "pt", "de", "nl", "sq", "ar", "wo", "tr", "ru", "hi", "ja", "zh"}

MOMENT_KEYS = {"id", "phase", "weight", "minAge", "maxAge", "unique", "avec", "seul", "groupe", "transports", "groupes",
               "destinations", "continents", "climats", "hebergements", "minJours", "vehiculeUse", "conditions",
               "text", "choices"}
CHOICE_KEYS = {"label", "outcomes", "requiresSkill"}
OUTCOME_KEYS = {"chance", "text", "effects", "compagnon", "compagnons", "vehicule", "souvenir", "signal"}
EFFECT_KEYS = {"happiness", "health", "smarts", "looks", "karma", "money", "stress", "fame", "newFriend", "death",
               "setFlags", "clearFlags", "followUps", "skills", "vie", "casier", "familyRep", "dreamMarks"}
COND_KEYS = {"gender", "minMoney", "maxMoney", "requiresJob", "requiresPartner", "requiresSchool", "tags",
             "excludeTags", "flags", "excludeFlags", "skills"}
PLACEHOLDERS = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e",
                "enfant", "compagnon", "compagnon_qui", "Compagnon_qui", "compagnon_e", "il", "Il", "pays",
                "en_pays", "destination", "incontournable", "specialite", "vehicule", "hebergement", "nb"}
ID_RE = re.compile(r"^voy_(tra|sej|ret)_\d{4}$")
PHASE_PREFIX = {"trajet": "voy_tra_", "sejour": "voy_sej_", "retour": "voy_ret_"}


def placeholders(text, where, errs):
    for p in re.findall(r"\{([^}]*)\}", text):
        if p not in PLACEHOLDERS:
            errs.append(f"{where}: variable inconnue {{{p}}}")


def check_destinations(errs):
    path = os.path.join(DATA, "destinations.json")
    data = json.load(open(path, encoding="utf-8"))
    ids = set()
    for i, d in enumerate(data):
        w = f"destinations[{i}] {d.get('id')}"
        for k in ("id", "nom", "enPays", "drapeau", "continent", "distance", "acces", "cotier", "ile", "climat", "prixJour",
                  "danger", "villes", "incontournables", "specialites", "presentation"):
            if k not in d:
                errs.append(f"{w}: champ manquant {k}")
        if d.get("id") in ids:
            errs.append(f"{w}: id en double")
        ids.add(d.get("id"))
        if d.get("continent") not in CONTINENTS: errs.append(f"{w}: continent inconnu")
        if d.get("climat") not in CLIMATS: errs.append(f"{w}: climat inconnu")
        if d.get("acces") not in ACCES: errs.append(f"{w}: accès inconnu")
        if "langue" in d and d["langue"] not in LANGUES: errs.append(f"{w}: langue inconnue {d['langue']}")
        if "competence" in d and d["competence"] not in SKILLS: errs.append(f"{w}: compétence inconnue")
        for k in ("villes", "incontournables", "specialites"):
            if not d.get(k): errs.append(f"{w}: {k} vide")
    return ids


def check_effects(e, where, errs):
    if not isinstance(e, dict):
        errs.append(f"{where}: effects doit être un objet"); return
    for k, v in e.items():
        if k not in EFFECT_KEYS:
            errs.append(f"{where}: effet inconnu {k}")
        elif k in ("happiness", "health", "smarts", "looks", "karma", "money", "stress", "fame") and not isinstance(v, int):
            errs.append(f"{where}: {k} doit être un entier")
        elif k == "skills":
            for s in v:
                if s not in SKILLS: errs.append(f"{where}: compétence inconnue {s}")


def check_moment(m, where, errs, dest_ids):
    for k in m:
        if k not in MOMENT_KEYS: errs.append(f"{where}: clé inconnue {k}")
    for k in ("id", "phase", "text", "choices"):
        if k not in m: errs.append(f"{where}: champ manquant {k}")
    mid = m.get("id", "")
    if not ID_RE.match(mid): errs.append(f"{where}: id mal formé {mid}")
    ph = m.get("phase")
    if ph not in PHASES: errs.append(f"{where}: phase inconnue {ph}")
    elif not mid.startswith(PHASE_PREFIX[ph]): errs.append(f"{where}: l'id ne correspond pas à la phase {ph}")
    for k, allowed in (("avec", AVEC), ("transports", TRANSPORTS), ("groupes", GROUPES), ("continents", CONTINENTS),
                       ("climats", CLIMATS), ("hebergements", HEBERGEMENTS), ("destinations", dest_ids)):
        for v in m.get(k, []) or []:
            if v not in allowed: errs.append(f"{where}: {k} inconnu {v}")
    if "minJours" in m and m["minJours"] not in DUREES: errs.append(f"{where}: minJours doit valoir 3, 7, 14 ou 30")
    if m.get("seul") and (m.get("avec") or m.get("groupe")): errs.append(f"{where}: seul incompatible avec avec/groupe")
    for k in (m.get("conditions") or {}):
        if k not in COND_KEYS: errs.append(f"{where}: condition inconnue {k}")
    placeholders(m.get("text", ""), where, errs)
    if m.get("seul") and "{compagnon" in m.get("text", ""):
        errs.append(f"{where}: {{compagnon}} dans un moment « seul »")
    choices = m.get("choices") or []
    if not 2 <= len(choices) <= 3: errs.append(f"{where}: il faut 2 ou 3 choix")
    if choices and all(c.get("requiresSkill") for c in choices):
        errs.append(f"{where}: au moins un choix sans requiresSkill")
    for ci, c in enumerate(choices):
        cw = f"{where} choix {ci}"
        for k in c:
            if k not in CHOICE_KEYS: errs.append(f"{cw}: clé inconnue {k}")
        if not c.get("label"): errs.append(f"{cw}: label manquant")
        placeholders(c.get("label", ""), cw, errs)
        for s, n in (c.get("requiresSkill") or {}).items():
            if s not in SKILLS: errs.append(f"{cw}: compétence inconnue {s}")
            if not (isinstance(n, int) and 1 <= n <= 5): errs.append(f"{cw}: niveau 1 à 5")
        outs = c.get("outcomes") or []
        if not outs: errs.append(f"{cw}: aucune issue")
        for oi, o in enumerate(outs):
            ow = f"{cw} issue {oi}"
            for k in o:
                if k not in OUTCOME_KEYS: errs.append(f"{ow}: clé inconnue {k}")
            if not o.get("text"): errs.append(f"{ow}: texte manquant")
            placeholders(o.get("text", ""), ow, errs)
            placeholders(o.get("souvenir", ""), ow, errs)
            if "effects" in o: check_effects(o["effects"], ow, errs)
            for k in ("compagnon", "compagnons", "vehicule"):
                if k in o and not isinstance(o[k], int): errs.append(f"{ow}: {k} doit être un entier")
            if m.get("seul") and ("compagnon" in o or "compagnons" in o or "{compagnon" in o.get("text", "")):
                errs.append(f"{ow}: compagnon dans un moment « seul »")


def main():
    errs = []
    dest_ids = check_destinations(errs)
    files = sys.argv[1:] or sorted(glob.glob(os.path.join(DATA, "moments_*.json")))
    seen = {}
    total = 0
    phases = {}
    for f in files:
        try:
            data = json.load(open(f, encoding="utf-8"))
        except Exception as ex:  # noqa: BLE001
            errs.append(f"{f}: JSON invalide ({ex})"); continue
        for i, m in enumerate(data):
            where = f"{os.path.basename(f)}[{i}] {m.get('id')}"
            check_moment(m, where, errs, dest_ids)
            mid = m.get("id")
            if mid in seen: errs.append(f"{where}: id déjà utilisé dans {seen[mid]}")
            seen[mid] = os.path.basename(f)
            phases[m.get("phase")] = phases.get(m.get("phase"), 0) + 1
            total += 1
    for e in errs:
        print("ERREUR", e)
    print(f"{len(dest_ids)} destinations, {total} moments {phases}, {len(errs)} erreur(s)")
    sys.exit(1 if errs else 0)


if __name__ == "__main__":
    main()
