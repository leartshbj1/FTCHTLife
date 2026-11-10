#!/usr/bin/env python3
"""Valide les données du module Placements (FTCHTLife/Resources/Data/Placements).

Usage : python3 tools/validate_placements.py
Code de sortie 1 s'il y a une erreur.
"""
import json
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent / "FTCHTLife" / "Resources" / "Data" / "Placements"
TYPES = {"action", "fonds", "or", "crypto"}
SECTEURS = {"tech", "alimentation", "energie", "luxe", "sante", "transport", "loisirs", "finance", "industrie"}
CIBLES = {"tout", "bourse", "crypto", "or", "immobilier"} | SECTEURS

erreurs = []


def err(fichier, element, msg):
    erreurs.append(f"{fichier.relative_to(RACINE)} [{element}] : {msg}")


def charger(dossier):
    elements = []
    base = RACINE / dossier
    if not base.is_dir():
        erreurs.append(f"dossier manquant : {dossier}")
        return elements
    for f in sorted(base.glob("*.json")):
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            erreurs.append(f"{f.name} : JSON invalide ({e})")
            continue
        if not isinstance(data, list):
            erreurs.append(f"{f.name} : le fichier doit contenir un tableau")
            continue
        elements += [(f, x) for x in data]
    return elements


def requis(f, x, champs):
    for c, t in champs.items():
        if c not in x:
            err(f, x.get("id", "?"), f"champ manquant « {c} »")
        elif not isinstance(x[c], t) or isinstance(x[c], bool) and t is not bool:
            err(f, x.get("id", "?"), f"« {c} » a un mauvais type")


def borne(f, x, champ, lo, hi, requis_=False):
    if champ not in x:
        if requis_:
            err(f, x.get("id", "?"), f"champ manquant « {champ} »")
        return
    v = x[champ]
    if not isinstance(v, (int, float)) or isinstance(v, bool) or not lo <= v <= hi:
        err(f, x.get("id", "?"), f"« {champ} » = {v!r} hors de [{lo}, {hi}]")


def uniques(elements, cle="id"):
    vus = {}
    for f, x in elements:
        v = x.get(cle)
        if v in vus:
            err(f, v, f"{cle} en double (déjà dans {vus[v].name})")
        vus[v] = f
    return set(vus)


NUM = (int, float)

# Actifs
actifs = charger("Actifs")
ids_actifs = uniques(actifs)
uniques(actifs, "ticker")
for f, a in actifs:
    requis(f, a, {"id": str, "nom": str, "ticker": str, "type": str, "description": str,
                  "prixInitial": NUM, "rendement": NUM, "volatilite": NUM})
    if a.get("type") not in TYPES:
        err(f, a.get("id"), f"type inconnu {a.get('type')!r}")
    if "secteur" in a and a["secteur"] not in SECTEURS:
        err(f, a.get("id"), f"secteur inconnu {a['secteur']!r}")
    if a.get("type") == "action" and "secteur" not in a:
        err(f, a.get("id"), "une action doit avoir un secteur")
    if not re.fullmatch(r"[A-Z0-9]{2,6}", str(a.get("ticker", ""))):
        err(f, a.get("id"), "ticker : 2 à 6 majuscules ou chiffres")
    borne(f, a, "prixInitial", 0.000001, 100000)
    borne(f, a, "rendement", -0.2, 0.2)
    borne(f, a, "volatilite", 0.02, 1.5)
    borne(f, a, "dividende", 0, 0.1)
    if a.get("type") == "crypto":
        borne(f, a, "chanceLune", 0, 0.05, True)
        borne(f, a, "chanceZero", 0, 0.5, True)

# Nouvelles
nouvelles = charger("Nouvelles")
uniques(nouvelles)
for f, n in nouvelles:
    requis(f, n, {"id": str, "texte": str, "cible": str, "variationMin": NUM, "variationMax": NUM})
    if n.get("cible") not in CIBLES and n.get("cible") not in ids_actifs:
        err(f, n.get("id"), f"cible inconnue {n.get('cible')!r}")
    borne(f, n, "variationMin", -0.9, 2)
    borne(f, n, "variationMax", -0.9, 2)
    if isinstance(n.get("variationMin"), NUM) and isinstance(n.get("variationMax"), NUM) and n["variationMin"] > n["variationMax"]:
        err(f, n.get("id"), "variationMin > variationMax")
    borne(f, n, "poids", 0, 100)

# Biens
biens = charger("Biens")
uniques(biens)
for f, b in biens:
    requis(f, b, {"id": str, "nom": str, "description": str, "prix": int, "loyerAnnuel": int, "charges": int, "risque": NUM})
    borne(f, b, "prix", 1000, 100_000_000)
    borne(f, b, "risque", 0, 1)
    if "designation" in b and "{" in b["designation"]:
        err(f, b.get("id"), "designation ne doit pas contenir de variable")

# Locataires
locataires = charger("Locataires")
uniques(locataires)
for f, l in locataires:
    requis(f, l, {"id": str, "description": str, "fiabilite": NUM})
    borne(f, l, "fiabilite", 0, 1)
    borne(f, l, "depart", 0, 1)
    borne(f, l, "poids", 0, 100)

# Incidents
incidents = charger("Incidents")
uniques(incidents)
for f, i in incidents:
    requis(f, i, {"id": str, "texte": str, "coutMin": int, "coutMax": int})
    if isinstance(i.get("coutMin"), int) and isinstance(i.get("coutMax"), int) and i["coutMin"] > i["coutMax"]:
        err(f, i.get("id"), "coutMin > coutMax")
    if i.get("condition") not in (None, "loue", "vide"):
        err(f, i.get("id"), f"condition inconnue {i.get('condition')!r}")
    if "{locataire}" in i.get("texte", "") and i.get("condition") != "loue":
        err(f, i.get("id"), "{locataire} seulement avec condition « loue »")
    borne(f, i, "valeur", 0.1, 3)
    borne(f, i, "poids", 0, 100)

# Toutes les variables entre accolades doivent être connues
VARS = {"{nom}", "{ticker}", "{bien}", "{locataire}"}
for groupe in (actifs, nouvelles, incidents):
    for f, x in groupe:
        for champ in ("texte", "texteLune", "texteZero", "description"):
            for v in re.findall(r"\{[^}]*\}", str(x.get(champ, ""))):
                if v not in VARS:
                    err(f, x.get("id"), f"variable inconnue {v} dans « {champ} »")

print(f"Placements : {len(actifs)} actifs, {len(nouvelles)} nouvelles, {len(biens)} biens, "
      f"{len(locataires)} locataires, {len(incidents)} incidents.")
if erreurs:
    print(f"{len(erreurs)} erreur(s) :")
    for e in erreurs:
        print("  - " + e)
    sys.exit(1)
print("OK")
