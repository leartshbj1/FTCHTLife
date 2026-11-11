#!/usr/bin/env python3
"""Valide FTCHTLife/Resources/Data/CoeurCartes/*.json (cartes qui suivent une action avec un proche, docs/COEUR.md).
Chaque carte est un événement normal (mêmes règles que validate_events.py) plus action, cibleMinAge, cibleMaxAge, cibleGenre.
Usage : python3 tools/validate_coeur_cartes.py"""
import json, sys, glob, os, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import validate_events as V

ROOT = V.ROOT
# Âges des proches pour lesquels chaque action est proposée (CoeurActionProche.pour).
ACTIONS = {"nuit": (18, 120), "avenir": (0, 120), "surprise": (0, 120),
           "jouer": (0, 12), "devoirs": (6, 17), "parlerVie": (11, 20), "punir": (4, 17), "argentPoche": (8, 25),
           "conduite": (16, 22), "conseilAdulte": (18, 120), "visite": (0, 120), "sortie": (0, 120)}
PARTENAIRE = {"nuit", "avenir", "surprise"}
# Pas de rupture ni de tromperie dans une carte avec le/la partenaire (couple protégé, voir docs/COEUR.md).
INTERDIT_PARTENAIRE = {"ecart", "liaison", "decouverte", "partenaireInfidele", "relationLibre", "trahisonDecouverte"}
V.PH |= {"cible", "cible_il", "cible_lui", "cible_le", "cible_e"}

def main():
    files = sorted(glob.glob(os.path.join(ROOT, "FTCHTLife/Resources/Data/CoeurCartes/*.json")))
    errs, ids = [], set()
    evts = glob.glob(os.path.join(ROOT, "FTCHTLife/Resources/Data/Events/*.json"))
    for f in evts:
        for e in json.load(open(f, encoding="utf-8")): ids.add(e.get("id"))
    par_action = {}
    for f in files:
        for c in json.load(open(f, encoding="utf-8")):
            w = f"{os.path.basename(f)}:{c.get('id')}"
            if c.get("id") in ids: errs.append(f"{w}: id déjà pris par un événement")
            a = c.get("action")
            if a not in ACTIONS: errs.append(f"{w}: action inconnue {a}"); continue
            par_action[a] = par_action.get(a, 0) + 1
            lo, hi = ACTIONS[a]
            mi, ma = c.get("cibleMinAge", lo), c.get("cibleMaxAge", hi)
            if not (isinstance(mi, int) and isinstance(ma, int) and mi <= ma): errs.append(f"{w}: âges de la cible invalides")
            elif ma < lo or mi > hi: errs.append(f"{w}: âges de la cible hors de ceux de l'action ({lo}-{hi})")
            if c.get("cibleGenre") not in (None, "male", "female"): errs.append(f"{w}: cibleGenre invalide")
            if a in PARTENAIRE and not (c.get("conditions") or {}).get("requiresPartner"):
                errs.append(f"{w}: une carte {a} exige requiresPartner")
            for ch in c.get("choices", []):
                for o in ch.get("outcomes", []):
                    co = (o.get("effects") or {}).get("coeur") or {}
                    if a in PARTENAIRE and INTERDIT_PARTENAIRE & set(co):
                        errs.append(f"{w}: effet coeur interdit dans une carte avec le/la partenaire : {sorted(INTERDIT_PARTENAIRE & set(co))}")
                    vie = (o.get("effects") or {}).get("vie") or {}
                    if vie.get("breakup"): errs.append(f"{w}: pas de rupture dans une carte d'action")
                    if vie.get("pregnancy") and "couple_fertile" not in ((c.get("conditions") or {}).get("tags") or []):
                        errs.append(f"{w}: une grossesse exige le tag couple_fertile")
    for e in errs: print("ERREUR", e)
    print("Cartes par action :", ", ".join(f"{k} {par_action.get(k, 0)}" for k in ACTIONS))
    sys.argv = [sys.argv[0]] + files
    if errs:
        print(f"{len(errs)} erreurs propres aux cartes"); V.main(); sys.exit(1)
    V.main()

if __name__ == "__main__": main()
