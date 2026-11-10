#!/usr/bin/env python3
"""Vérifie les données du module « Vivre à l'étranger ».

Usage : python3 tools/validate_etranger.py
- Data/Etranger/pays.json et langues.json : champs obligatoires, langues connues.
- Data/Events/etranger_*.json : format d'événement du moteur, ids uniques,
  tags connus (moteur + module), pays existants, effets entiers.
"""
import glob
import json
import os
import re
import sys

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "FTCHTLife", "Resources", "Data")
TAGS_MOTEUR = {"male", "female", "baby", "school", "university", "job", "adult", "unemployed", "retired",
               "rich", "poor", "friend", "mother", "father", "siblings", "partner", "children", "sick",
               "attractive", "smart"}
TAGS_MODULE = {"etranger", "expat_nouveau", "expat_installe", "langue_faible", "bilingue", "polyglotte",
               "binational", "de_retour"}
EFFETS_INT = {"happiness", "health", "smarts", "looks", "karma", "money", "stress", "fame"}
EFFETS_AUTRES = {"relationships", "newFriend", "death"}
RELATIONS = {"mother", "father", "parent", "sibling", "friend", "partner", "child"}
VARIABLES = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e"}

erreurs = []


def err(msg):
    erreurs.append(msg)


def charger(chemin):
    with open(chemin, encoding="utf-8") as f:
        return json.load(f)


langues = charger(os.path.join(RACINE, "Etranger", "langues.json"))
ids_langues = {l["id"] for l in langues}
for l in langues:
    for k in ("id", "nom", "difficulte", "bonjour", "merci"):
        if k not in l:
            err(f"langues.json : {l.get('id')} sans {k}")

pays = charger(os.path.join(RACINE, "Etranger", "pays.json"))
ids_pays = set()
lois = set()
zones = set()
for p in pays:
    for k in ("id", "nom", "drapeau", "zone", "langue", "villes", "salaire", "prix", "impots", "visa",
              "naturalisation", "coutDemenagement", "presentation", "lois", "coutumes"):
        if k not in p:
            err(f"pays.json : {p.get('id')} sans {k}")
    if p["id"] in ids_pays:
        err(f"pays.json : id en double {p['id']}")
    ids_pays.add(p["id"])
    zones.add(p["zone"])
    for l in [p["langue"]] + p.get("autresLangues", []):
        if l not in ids_langues:
            err(f"pays.json : {p['id']} parle une langue inconnue {l}")
    if not 0 <= p["visa"] <= 4:
        err(f"pays.json : {p['id']} visa hors de 0…4")
    for loi in p["lois"]:
        lois.add(loi["id"])

tags_valides = TAGS_MOTEUR | TAGS_MODULE | {f"pays_{i}" for i in ids_pays} | {f"loi_{i}" for i in lois} | {f"zone_{z}" for z in zones}


def verifier_effets(ctx, eff):
    if not isinstance(eff, dict):
        err(f"{ctx} : effects n'est pas un objet")
        return
    for k, v in eff.items():
        if k in EFFETS_INT:
            if not isinstance(v, int) or isinstance(v, bool):
                err(f"{ctx} : effet {k} doit être un entier")
        elif k == "relationships":
            for r, d in v.items():
                if r not in RELATIONS or not isinstance(d, int):
                    err(f"{ctx} : relation invalide {r}={d}")
        elif k == "newFriend":
            if not isinstance(v, bool):
                err(f"{ctx} : newFriend doit être booléen")
        elif k == "death":
            if not isinstance(v, str):
                err(f"{ctx} : death doit être un texte")
        else:
            err(f"{ctx} : effet inconnu {k}")


def verifier_texte(ctx, t):
    for v in re.findall(r"\{([^}]*)\}", t):
        if v not in VARIABLES:
            err(f"{ctx} : variable inconnue {{{v}}}")


ids = set()
total = 0
for chemin in sorted(glob.glob(os.path.join(RACINE, "Events", "*.json"))):
    data = charger(chemin)
    nom = os.path.basename(chemin)
    module = nom.startswith("etranger_")
    for e in data:
        if e["id"] in ids:
            err(f"{nom} : id en double {e['id']}")
        ids.add(e["id"])
        if not module:
            continue
        total += 1
        ctx = f"{nom}:{e['id']}"
        for k in ("id", "minAge", "maxAge", "text"):
            if k not in e:
                err(f"{ctx} : champ {k} manquant")
        if not e["id"].startswith("etr_"):
            err(f"{ctx} : l'id doit commencer par etr_")
        if e["minAge"] > e["maxAge"]:
            err(f"{ctx} : minAge > maxAge")
        c = e.get("conditions") or {}
        for t in (c.get("tags") or []) + (c.get("excludeTags") or []):
            if t not in tags_valides:
                err(f"{ctx} : tag inconnu {t}")
        if not any(t in TAGS_MODULE or t.startswith(("pays_", "loi_", "zone_")) for t in (c.get("tags") or [])):
            err(f"{ctx} : doit exiger au moins un tag du module (etranger, pays_xx, de_retour…)")
        verifier_texte(ctx, e["text"])
        choix = e.get("choices") or []
        if not choix and "effects" not in e:
            err(f"{ctx} : ni choix ni effets")
        if e.get("effects"):
            verifier_effets(ctx, e["effects"])
        for ch in choix:
            if not ch.get("label") or not ch.get("outcomes"):
                err(f"{ctx} : choix sans label ou sans issue")
            for o in ch.get("outcomes", []):
                if "text" not in o:
                    err(f"{ctx} : issue sans texte")
                    continue
                verifier_texte(ctx, o["text"])
                if "effects" in o:
                    verifier_effets(ctx, o["effects"])

if erreurs:
    print("\n".join(erreurs))
    print(f"\n{len(erreurs)} erreur(s).")
    sys.exit(1)
print(f"OK : {len(pays)} pays, {len(langues)} langues, {total} événements « étranger ».")
