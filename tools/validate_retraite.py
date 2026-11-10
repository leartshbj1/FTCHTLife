#!/usr/bin/env python3
"""Valide le module Vieillesse et maison de retraite.

- FTCHTLife/Resources/Data/Events/retraite_*.json : événements (format du moteur, tags du module autorisés)
- FTCHTLife/Resources/Data/Retraite/*.json : catalogue (résidences, activités, voyages, lots du loto, résidents)

Usage : python3 tools/validate_retraite.py
"""
import glob, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EVENTS = os.path.join(ROOT, "FTCHTLife/Resources/Data/Events")
DATA = os.path.join(ROOT, "FTCHTLife/Resources/Data/Retraite")

STATS = {"happiness", "health", "smarts", "looks", "money", "karma", "stress", "fame"}
REL = {"mother", "father", "parent", "sibling", "friend", "partner", "child"}
TAGS_MOTEUR = {"male", "female", "baby", "school", "university", "job", "adult", "unemployed", "retired",
               "rich", "poor", "friend", "mother", "father", "siblings", "partner", "children", "sick",
               "attractive", "smart"}
# Tags fournis par RetraiteSysteme.tags(_:) (voir docs/RETRAITE.md).
TAGS_RETRAITE = {"maison_retraite", "maison_retraite_imposee", "en_cavale", "romance_residence",
                 "grand_parent", "petits_enfants_absents", "senior_voyageur", "champion_loto"}
TAGS = TAGS_MOTEUR | TAGS_RETRAITE
SPECIAL = {"death", "newFriend", "relationships"}
PH = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e"}
COND = {"gender", "minMoney", "maxMoney", "requiresJob", "requiresPartner", "requiresSchool", "tags", "excludeTags"}
# Variables propres aux textes du catalogue (remplacées par RetraiteSysteme, pas par le moteur).
PH_CATALOGUE = {"residence", "resident", "er", "ner", "il", "trait", "petitenfant", "pe", "enfant", "grandparent"}
PH_COND = {"mere": "mother", "pere": "father", "ami": "friend", "fratrie": "siblings"}

errs = []


def err(m):
    errs.append(m)


def check_text(t, w, extra=frozenset()):
    if not isinstance(t, str) or not t.strip():
        err(f"{w}: texte vide"); return set()
    found = set(re.findall(r"\{(\w+)\}", t))
    for p in found:
        if p not in PH and p not in extra:
            err(f"{w}: placeholder inconnu {{{p}}}")
    return found


def check_effects(e, w):
    if not isinstance(e, dict):
        err(f"{w}: effects pas un objet"); return
    for k, v in e.items():
        if k in STATS:
            if not isinstance(v, int) or isinstance(v, bool):
                err(f"{w}: {k} doit être un entier")
            elif k != "money" and abs(v) > 100:
                err(f"{w}: {k} hors bornes")
        elif k == "relationships":
            if not isinstance(v, dict) or any(r not in REL for r in v):
                err(f"{w}: relationships invalide {v}")
        elif k == "newFriend":
            if v is not True: err(f"{w}: newFriend doit valoir true")
        elif k == "death":
            if not isinstance(v, str) or not v.strip(): err(f"{w}: death doit être une phrase")
        else:
            err(f"{w}: clé d'effet inconnue {k}")


def check_events():
    ids, n = {}, 0
    files = sorted(glob.glob(os.path.join(EVENTS, "retraite_*.json")))
    for f in files:
        base = os.path.basename(f)
        try:
            data = json.load(open(f, encoding="utf-8"))
        except Exception as ex:
            err(f"{base}: JSON invalide: {ex}"); continue
        if not isinstance(data, list):
            err(f"{base}: pas un tableau"); continue
        for ev in data:
            n += 1
            i = ev.get("id", "?"); w = f"{base}:{i}"
            for k in ("id", "category", "minAge", "maxAge", "weight", "text", "choices"):
                if k not in ev: err(f"{w}: champ manquant {k}")
            if not re.fullmatch(r"ret_\d{4}", str(i)): err(f"{w}: id attendu ret_NNNN")
            if i in ids: err(f"{w}: id dupliqué (aussi dans {ids[i]})")
            ids[i] = base
            if not (0 <= ev.get("minAge", 0) <= ev.get("maxAge", 0) <= 120): err(f"{w}: âges invalides")
            if ev.get("minAge", 0) < 55: err(f"{w}: événement de vieillesse avant 55 ans")
            cond = ev.get("conditions") or {}
            for k in cond:
                if k not in COND: err(f"{w}: condition inconnue {k}")
                elif k in ("tags", "excludeTags"):
                    for t in cond[k] or []:
                        if t not in TAGS: err(f"{w}: tag inconnu {t}")
            tags = set(cond.get("tags") or [])
            used = check_text(ev.get("text"), w)
            ch = ev.get("choices", [])
            if not isinstance(ch, list): err(f"{w}: choices pas un tableau"); ch = []
            if not ch: check_effects(ev.get("effects", {}), w)
            if len(ch) > 4: err(f"{w}: plus de 4 choix")
            for ci, c in enumerate(ch):
                cw = f"{w}/choix{ci}"
                used |= check_text(c.get("label"), cw)
                outs = c.get("outcomes") or []
                if not outs: err(f"{cw}: aucun outcome")
                s = sum(o.get("chance", 0) for o in outs)
                if abs(s - 1) > 0.011: err(f"{cw}: somme des chances = {s}")
                for oi, o in enumerate(outs):
                    used |= check_text(o.get("text"), f"{cw}/o{oi}")
                    check_effects(o.get("effects", {}), f"{cw}/o{oi}")
            for p, t in PH_COND.items():
                if p in used and t not in tags: err(f"{w}: {{{p}}} exige le tag {t}")
            if "partenaire" in used and cond.get("requiresPartner") is not True and "partner" not in tags:
                err(f"{w}: {{partenaire}} exige requiresPartner: true")
            if "metier" in used and cond.get("requiresJob") is not True:
                err(f"{w}: {{metier}} exige requiresJob: true")
    return n, len(files)


def charger(nom):
    p = os.path.join(DATA, nom)
    try:
        d = json.load(open(p, encoding="utf-8"))
    except Exception as ex:
        err(f"Retraite/{nom}: {ex}"); return []
    if not isinstance(d, list): err(f"Retraite/{nom}: pas un tableau"); return []
    return d


def champs(liste, nom, requis):
    vus = set()
    for x in liste:
        w = f"Retraite/{nom}:{x.get('id', '?')}"
        for k, typ in requis.items():
            if k not in x: err(f"{w}: champ manquant {k}")
            elif not isinstance(x[k], typ) or isinstance(x[k], bool) and typ is not bool:
                err(f"{w}: {k} mauvais type")
        if x.get("id") in vus: err(f"{w}: id dupliqué")
        vus.add(x.get("id"))
        for k, v in x.items():
            if isinstance(v, str): check_text(v, w, PH_CATALOGUE)
            if isinstance(v, list):
                for s in v:
                    if isinstance(s, str): check_text(s, w, PH_CATALOGUE)


def check_catalogue():
    champs(charger("Residences/residences.json"), "residences.json",
           {"id": str, "nom": str, "description": str, "prixAnnuel": int, "confort": int,
            "ambiance": int, "surveillance": int, "specialite": str})
    champs(charger("Activites/activites.json"), "activites.json",
           {"id": str, "titre": str, "icone": str, "description": str, "resultats": list})
    for a in charger("Activites/activites.json"):
        for r in a.get("resultats", []):
            if not isinstance(r, dict) or "texte" not in r: err(f"activites {a.get('id')}: résultat invalide"); continue
            check_effects(r.get("effets", {}), f"activites {a.get('id')}")
    champs(charger("Voyages/voyages.json"), "voyages.json",
           {"id": str, "titre": str, "icone": str, "description": str, "cout": int, "resultats": list})
    for a in charger("Voyages/voyages.json"):
        for r in a.get("resultats", []):
            if not isinstance(r, dict) or "texte" not in r: err(f"voyages {a.get('id')}: résultat invalide"); continue
            check_effects(r.get("effets", {}), f"voyages {a.get('id')}")
    champs(charger("Lots/lots_loto.json"), "lots_loto.json", {"id": str, "nom": str, "valeur": int, "poids": int})
    res = charger("Residents/residents.json")
    if res:
        r = res[0]
        for k in ("prenomsHommes", "prenomsFemmes", "noms", "traits", "phrasesDeces", "phrasesArrivee"):
            if not isinstance(r.get(k), list) or len(r[k]) < 2: err(f"Retraite/residents.json: {k} manquant ou trop court")
            for s in r.get(k) or []: check_text(s, f"residents.{k}", PH_CATALOGUE)
    phr = charger("Phrases/phrases.json")
    if phr:
        for k in ("placementImpose", "placementServicesSociaux", "anneeResidence", "aucuneVisite", "visite",
                  "naissancePetitEnfant", "rattrape", "cavale", "liberte", "evasionRatee"):
            if not isinstance(phr[0].get(k), list) or not phr[0][k]: err(f"Retraite/phrases.json: {k} manquant")
            for s in phr[0].get(k, []): check_text(s, f"phrases.{k}", PH_CATALOGUE)


n, nf = check_events()
check_catalogue()
for e in errs[:300]:
    print("ERREUR", e)
print(f"{n} événements retraite dans {nf} fichiers, catalogue vérifié, {len(errs)} erreurs")
sys.exit(1 if errs else 0)
