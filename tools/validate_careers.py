#!/usr/bin/env python3
"""Vérifie les fichiers de métiers et d'événements de travail.

Usage : python3 tools/validate_careers.py
"""
import json, sys, glob, os

ROOT = os.path.join(os.path.dirname(__file__), "..", "FTCHTLife", "Resources", "Data")
EDU = ["none", "brevet", "cap", "bac", "licence", "master", "doctorat"]
KINDS = {"standard", "partTime", "freelance", "special", "illegal", "military"}
SECTORS = {"sante", "education", "droit", "finance", "tech", "ingenierie", "batiment", "industrie",
           "transport", "commerce", "restauration", "hotellerie_tourisme", "art_culture", "medias",
           "spectacle", "sport", "securite", "armee", "administration", "politique", "agriculture",
           "environnement", "science", "beaute_mode", "services", "religion", "crime", "insolite"}
SKILLS = {"smarts", "looks", "health", "talent", "charisma", "athleticism"}
EFFECT_NUM = {"happiness", "health", "smarts", "looks", "karma", "fame", "money", "performance",
              "bossRelation", "coworkerRelation", "salaryMultiplier"}
EFFECT_BOOL = {"promoted", "fired", "quit", "arrested", "injured"}
VARS = {"prenom", "e", "boss", "coworker", "company", "title"}
PERMITS = {"permis_scooter", "permis_voiture", "permis_moto", "permis_poids_lourd", "permis_bus", "permis_bateau",
           "licence_pilote", "licence_helico", "permis_chasse", "permis_armes", "carte_peche", "brevet_drone", "permis_fusee"}
def is_exam(x): return x.startswith("concours_") or x.startswith("examen_") or x == "barreau"

errors = []
def err(where, msg): errors.append(f"{where}: {msg}")

def load(path):
    try:
        with open(path, encoding="utf-8") as f: return json.load(f)
    except Exception as e:
        err(path, f"JSON invalide : {e}"); return []

def check_text(where, t):
    import re
    if not isinstance(t, str) or not t.strip(): err(where, "texte vide"); return
    for v in re.findall(r"\{(\w+)\}", t):
        if v not in VARS: err(where, f"variable inconnue {{{v}}}")

majors = {m["id"] for m in load(os.path.join(ROOT, "CareerMajors", "majors.json"))}
for c in load(os.path.join(ROOT, "CareerCompanies", "companies.json")):
    if c.get("sector") not in SECTORS or not c.get("names"): errors.append(f"companies.json: entrée invalide {c.get('sector')}")
careers = {}
for path in sorted(glob.glob(os.path.join(ROOT, "Careers", "*.json"))):
    data = load(path)
    if not isinstance(data, list): err(path, "doit être un tableau"); continue
    for c in data:
        w = f"{os.path.basename(path)}:{c.get('id')}"
        cid = c.get("id")
        if not cid or not cid.replace("_", "").isalnum() or cid != cid.lower(): err(w, "id invalide")
        if cid in careers: err(w, "id en double")
        careers[cid] = c
        if not c.get("name"): err(w, "name manquant")
        if c.get("sector") not in SECTORS: err(w, f"secteur inconnu {c.get('sector')}")
        if c.get("kind") not in KINDS: err(w, f"kind inconnu {c.get('kind')}")
        if "requirements" not in c: err(w, "requirements manquant")
        r = c.get("requirements", {})
        if r.get("education", "none") not in EDU: err(w, f"education inconnue {r.get('education')}")
        for m in r.get("majors", []) or []:
            if m not in majors: err(w, f"filière inconnue {m}")
        lic = r.get("requiresLicense")
        if lic and lic not in PERMITS and not is_exam(lic): err(w, f"permis inconnu {lic}")
        for k in ("minSmarts", "minLooks", "minHealth"):
            v = r.get(k, 0)
            if not isinstance(v, int) or not 0 <= v <= 100: err(w, f"{k} hors bornes")
        lad = c.get("ladder", [])
        if not lad: err(w, "ladder vide")
        for i, s in enumerate(lad):
            if not s.get("title"): err(w, f"échelon {i} sans titre")
            if not isinstance(s.get("salary"), int) or s["salary"] < 0: err(w, f"échelon {i} salaire invalide")
            if not isinstance(s.get("yearsToPromote"), int) or s["yearsToPromote"] < 0: err(w, f"échelon {i} yearsToPromote invalide")
        for k in ("stress", "prestige", "hiringDifficulty"):
            v = c.get(k)
            if not isinstance(v, int) or not 0 <= v <= 100: err(w, f"{k} hors bornes")
        sp = c.get("special")
        if sp and sp.get("skill") and sp["skill"] not in SKILLS: err(w, f"skill inconnu {sp['skill']}")

events = {}
for path in sorted(glob.glob(os.path.join(ROOT, "WorkEvents", "*.json"))):
    data = load(path)
    if not isinstance(data, list): err(path, "doit être un tableau"); continue
    for e in data:
        w = f"{os.path.basename(path)}:{e.get('id')}"
        if not e.get("id"): err(w, "id manquant")
        if e.get("id") in events: err(w, "id en double")
        events[e.get("id")] = e
        cond = e.get("conditions", {})
        for cid in cond.get("careers", []) or []:
            if cid not in careers: err(w, f"métier inconnu {cid}")
        for s in cond.get("sectors", []) or []:
            if s not in SECTORS: err(w, f"secteur inconnu {s}")
        for k in cond.get("kinds", []) or []:
            if k not in KINDS: err(w, f"kind inconnu {k}")
        check_text(w, e.get("text"))
        ch = e.get("choices", [])
        if not 1 <= len(ch) <= 4: err(w, "1 à 4 choix attendus")
        for c in ch:
            check_text(w, c.get("label"))
            outs = c.get("outcomes", [])
            if not outs: err(w, "choix sans outcome")
            if sum(o.get("chance", 0) for o in outs) != 100: err(w, f"chances ≠ 100 pour « {c.get('label')} »")
            for o in outs:
                check_text(w, o.get("text"))
                for k, v in (o.get("effects") or {}).items():
                    if k in EFFECT_BOOL:
                        if v is not True: err(w, f"effet {k} doit valoir true")
                    elif k in EFFECT_NUM:
                        if not isinstance(v, (int, float)): err(w, f"effet {k} non numérique")
                    else: err(w, f"effet inconnu {k}")

by_kind = {}
for c in careers.values(): by_kind[c.get("kind")] = by_kind.get(c.get("kind"), 0) + 1
print(f"{len(careers)} métiers, {sum(len(c.get('ladder', [])) for c in careers.values())} échelons, {len(events)} événements de travail")
print("par type :", by_kind)
if errors:
    print(f"\n{len(errors)} erreur(s) :"); [print(" -", e) for e in errors[:200]]; sys.exit(1)
print("OK")
