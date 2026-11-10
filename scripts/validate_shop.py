#!/usr/bin/env python3
"""Valide les données de la boutique (FTCHTLife/Resources/Data/shop)."""
import json, sys, glob, os
ROOT = os.path.join(os.path.dirname(__file__), "..", "FTCHTLife", "Resources", "Data", "Shop")
CATS = {"realEstate","car","moto","boat","aircraft","jewelry","watch","art","fashion","gadget","collection"}
FIN = {"none","carLoan","mortgage"}
EFF = {"money","happiness","health","looks","smarts","karma","condition","valuePct","destroy","stolen"}
SCOPES = {"item","owner","trip"}
errors, ids = [], {}
def err(f, i, m): errors.append(f"{os.path.basename(f)}[{i}] {m}")
def check_effects(f, i, e):
    for k in e:
        if k not in EFF: err(f, i, f"effet inconnu {k}")
def uniq(f, i, o):
    oid = o.get("id")
    if not oid or not isinstance(oid, str): err(f, i, "id manquant"); return
    if oid in ids: err(f, i, f"id en double {oid} (aussi dans {ids[oid]})")
    ids[oid] = os.path.basename(f)
def load(f):
    try:
        d = json.load(open(f, encoding="utf-8"))
    except Exception as ex:
        errors.append(f"{f}: JSON invalide: {ex}"); return []
    if not isinstance(d, list): errors.append(f"{f}: doit être un tableau"); return []
    return d
counts = {}
for f in sorted(glob.glob(os.path.join(ROOT, "catalog_*.json"))):
    for i, o in enumerate(load(f)):
        uniq(f, i, o)
        for k in ["id","category","subcategory","name","brand","description","icon","price","minAge","upkeep","appreciation","volatility","wear","happiness","looks","health","prestige","rentIncome","financing","usedMarket","tags"]:
            if k not in o: err(f, i, f"champ manquant {k}")
        if o.get("category") not in CATS: err(f, i, f"catégorie invalide {o.get('category')}")
        if o.get("financing") not in FIN: err(f, i, "financing invalide")
        for k in ["price","minAge","upkeep","wear","happiness","looks","health","prestige","rentIncome"]:
            if k in o and not isinstance(o[k], int): err(f, i, f"{k} doit être entier")
        if isinstance(o.get("price"), int) and o["price"] <= 0: err(f, i, "prix <= 0")
        counts[o.get("category")] = counts.get(o.get("category"), 0) + 1
f = os.path.join(ROOT, "rentals.json")
if os.path.exists(f):
    for i, o in enumerate(load(f)):
        uniq(f, i, o)
        for k in ["name","description","icon","rentPerYear","happiness","prestige","city"]:
            if k not in o: err(f, i, f"champ manquant {k}")
        counts["rentals"] = counts.get("rentals", 0) + 1
f = os.path.join(ROOT, "travel.json")
if os.path.exists(f):
    for i, o in enumerate(load(f)):
        uniq(f, i, o)
        for k in ["name","destination","description","icon","price","minAge","happiness","health","outcomes"]:
            if k not in o: err(f, i, f"champ manquant {k}")
        if not o.get("outcomes"): err(f, i, "pas d'outcomes")
        for oc in o.get("outcomes", []):
            if not isinstance(oc.get("weight"), int) or "text" not in oc: err(f, i, "outcome invalide")
            check_effects(f, i, oc.get("effects", {}))
        counts["travel"] = counts.get("travel", 0) + 1
for f in sorted(glob.glob(os.path.join(ROOT, "events_*.json"))):
    for i, o in enumerate(load(f)):
        uniq(f, i, o)
        if o.get("scope") not in SCOPES: err(f, i, "scope invalide")
        for c in o.get("categories", []):
            if c not in CATS: err(f, i, f"catégorie invalide {c}")
        if not isinstance(o.get("chance"), (int, float)) or not 0 < o["chance"] <= 1: err(f, i, "chance invalide")
        if "text" not in o: err(f, i, "text manquant")
        ch = o.get("choices", [])
        if not 1 <= len(ch) <= 4: err(f, i, "1 à 4 choix")
        for c in ch:
            if "label" not in c or not c.get("outcomes"): err(f, i, "choix invalide")
            for oc in c.get("outcomes", []):
                if not isinstance(oc.get("weight"), int) or "text" not in oc: err(f, i, "outcome invalide")
                check_effects(f, i, oc.get("effects", {}))
        counts["events"] = counts.get("events", 0) + 1
for k, v in sorted(counts.items()): print(f"{k:12} {v}")
print(f"TOTAL        {sum(counts.values())}")
if errors:
    print(f"\n{len(errors)} erreur(s):"); [print(" -", e) for e in errors[:200]]; sys.exit(1)
print("OK")
