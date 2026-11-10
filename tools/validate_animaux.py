#!/usr/bin/env python3
"""Valide les données des animaux de compagnie (FTCHTLife/Resources/Data/Animaux).
Usage : python3 tools/validate_animaux.py [fichiers d'événements...]"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "FTCHTLife/Resources/Data/Animaux")

STATS = {"happiness", "health", "smarts", "looks", "money", "karma", "stress", "fame"}
REL = {"mother", "father", "parent", "sibling", "friend", "partner", "child"}
SPECIAL = {"death", "newFriend", "relationships"}
TAGS = {"male", "female", "baby", "school", "university", "job", "adult", "unemployed", "retired", "rich",
        "poor", "friend", "mother", "father", "siblings", "partner", "children", "sick", "attractive", "smart"}
COND = {"gender", "minMoney", "maxMoney", "requiresJob", "requiresPartner", "requiresSchool", "tags", "excludeTags"}
PET = {"bond", "health", "sick", "cure", "death", "runaway", "newPet", "trait"}
PH = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e",
      "animal", "espece", "le_espece", "ton_espece", "cri", "a", "il", "Il", "caractere"}
EV_KEYS = {"id", "especes", "caracteres", "minAgeAnimal", "maxAgeAnimal", "minAge", "maxAge", "minLien", "maxLien",
           "malade", "vieux", "weight", "unique", "conditions", "text", "effects", "pet", "choices"}


def load(path, errs):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except Exception as ex:  # noqa: BLE001
        errs.append(f"{path}: JSON invalide : {ex}")
        return []
    if not isinstance(data, list):
        errs.append(f"{path}: le fichier doit contenir un tableau")
        return []
    return data


def check_text(t, where, errs):
    if not isinstance(t, str) or not t.strip():
        errs.append(f"{where}: texte vide")
        return
    for p in re.findall(r"\{(\w+)\}", t):
        if p not in PH:
            errs.append(f"{where}: variable inconnue {{{p}}}")


def check_effects(e, where, errs):
    if e is None:
        return
    if not isinstance(e, dict):
        errs.append(f"{where}: effects doit être un objet")
        return
    for k, v in e.items():
        if k in STATS:
            if not isinstance(v, (int, float)):
                errs.append(f"{where}: {k} non numérique")
            elif k != "money" and abs(v) > 100:
                errs.append(f"{where}: {k} hors bornes")
        elif k == "relationships":
            if not isinstance(v, dict) or any(r not in REL for r in v):
                errs.append(f"{where}: relationships invalide {v}")
        elif k == "death":
            if not isinstance(v, str) or not v.strip():
                errs.append(f"{where}: death doit être une phrase")
        elif k not in SPECIAL:
            errs.append(f"{where}: clé d'effet joueur inconnue {k}")


def check_pet(p, where, errs, especes, caracteres):
    if p is None:
        return
    if not isinstance(p, dict):
        errs.append(f"{where}: pet doit être un objet")
        return
    for k, v in p.items():
        if k not in PET:
            errs.append(f"{where}: clé d'effet animal inconnue {k}")
        elif k in ("bond", "health") and (not isinstance(v, int) or abs(v) > 100):
            errs.append(f"{where}: {k} doit être un entier entre -100 et 100")
        elif k in ("cure", "runaway") and v is not True:
            errs.append(f"{where}: {k} doit valoir true")
        elif k in ("sick", "death") and (not isinstance(v, str) or not v.strip()):
            errs.append(f"{where}: {k} doit être une phrase")
        elif k == "newPet" and v not in especes:
            errs.append(f"{where}: newPet : espèce inconnue {v}")
        elif k == "trait" and v not in caracteres:
            errs.append(f"{where}: trait : caractère inconnu {v}")


def main():
    errs = []
    especes = {}
    for f in sorted(glob.glob(os.path.join(DATA, "Especes/*.json"))):
        for s in load(f, errs):
            for k in ("id", "nom", "article", "emoji", "categorie", "prix", "entretien", "esperanceVie", "cri", "noms", "description"):
                if k not in s:
                    errs.append(f"espèce {s.get('id', '?')}: champ manquant {k}")
            if s.get("article") not in ("le", "la", "l'"):
                errs.append(f"espèce {s.get('id')}: article doit être le, la ou l'")
            if s.get("categorie") not in ("commun", "exotique"):
                errs.append(f"espèce {s.get('id')}: categorie doit être commun ou exotique")
            ev = s.get("esperanceVie") or []
            if len(ev) != 2 or ev[0] > ev[1]:
                errs.append(f"espèce {s.get('id')}: esperanceVie doit être [min, max]")
            if s.get("categorie") == "commun" and "prixRefuge" not in s:
                errs.append(f"espèce {s.get('id')}: une espèce commune a besoin de prixRefuge")
            if not s.get("noms"):
                errs.append(f"espèce {s.get('id')}: au moins un nom")
            if s.get("id") in especes:
                errs.append(f"espèce {s.get('id')}: id dupliqué")
            especes[s.get("id")] = s
    caracteres = {}
    for f in sorted(glob.glob(os.path.join(DATA, "Caracteres/*.json"))):
        for c in load(f, errs):
            for k in ("id", "nom", "emoji", "description"):
                if k not in c:
                    errs.append(f"caractère {c.get('id', '?')}: champ manquant {k}")
            caracteres[c.get("id")] = c
    for s in especes.values():
        for c in s.get("caracteres") or []:
            if c not in caracteres:
                errs.append(f"espèce {s['id']}: caractère inconnu {c}")

    files = sys.argv[1:] or sorted(glob.glob(os.path.join(DATA, "Evenements/*.json")))
    ids = {}
    n = 0
    par_caractere = {c: 0 for c in caracteres}
    par_espece = {s: 0 for s in especes}
    for f in files:
        base = os.path.basename(f)
        for ev in load(f, errs):
            n += 1
            i = ev.get("id", "?")
            w = f"{base}:{i}"
            for k in ev:
                if k not in EV_KEYS:
                    errs.append(f"{w}: champ inconnu {k}")
            for k in ("id", "text"):
                if k not in ev:
                    errs.append(f"{w}: champ manquant {k}")
            if not str(i).startswith("ani_"):
                errs.append(f"{w}: l'id doit commencer par ani_")
            if i in ids:
                errs.append(f"{w}: id dupliqué (aussi dans {ids[i]})")
            ids[i] = base
            for e in ev.get("especes") or []:
                if e not in especes:
                    errs.append(f"{w}: espèce inconnue {e}")
                else:
                    par_espece[e] += 1
            for c in ev.get("caracteres") or []:
                if c not in caracteres:
                    errs.append(f"{w}: caractère inconnu {c}")
                else:
                    par_caractere[c] += 1
            for a, b in (("minAgeAnimal", "maxAgeAnimal"), ("minAge", "maxAge"), ("minLien", "maxLien")):
                if a in ev and b in ev and ev[a] > ev[b]:
                    errs.append(f"{w}: {a} > {b}")
            for k in (ev.get("conditions") or {}):
                if k not in COND:
                    errs.append(f"{w}: condition inconnue {k}")
                elif k in ("tags", "excludeTags"):
                    for t in ev["conditions"][k] or []:
                        if t not in TAGS and not t.startswith("pet"):
                            errs.append(f"{w}: tag inconnu {t}")
            check_text(ev.get("text"), w, errs)
            ch = ev.get("choices") or []
            if ch and ("effects" in ev or "pet" in ev):
                errs.append(f"{w}: effects/pet à la racine seulement pour un événement sans choix")
            check_effects(ev.get("effects"), w, errs)
            check_pet(ev.get("pet"), w, errs, especes, caracteres)
            if len(ch) > 4:
                errs.append(f"{w}: plus de 4 choix")
            for ci, c in enumerate(ch):
                cw = f"{w}/choix{ci}"
                check_text(c.get("label"), cw, errs)
                outs = c.get("outcomes") or []
                if not outs:
                    errs.append(f"{cw}: aucune issue")
                for oi, o in enumerate(outs):
                    ow = f"{cw}/issue{oi}"
                    for k in o:
                        if k not in ("chance", "text", "effects", "pet"):
                            errs.append(f"{ow}: champ inconnu {k}")
                    check_text(o.get("text"), ow, errs)
                    check_effects(o.get("effects"), ow, errs)
                    check_pet(o.get("pet"), ow, errs, especes, caracteres)

    for e in errs[:300]:
        print("ERREUR", e)
    print(f"{len(especes)} espèces, {len(caracteres)} caractères, {n} événements dans {len(files)} fichiers, {len(errs)} erreurs")
    if "-v" in os.environ.get("ANIMAUX_STATS", "-v"):
        print("Par caractère :", ", ".join(f"{k} {v}" for k, v in par_caractere.items()))
        print("Par espèce :", ", ".join(f"{k} {v}" for k, v in par_espece.items()))
    sys.exit(1 if errs else 0)


if __name__ == "__main__":
    main()
