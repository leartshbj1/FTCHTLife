#!/usr/bin/env python3
"""Vérifie le catalogue du module Beauté (Data/Beaute/catalogue.json). Voir docs/BEAUTE.md."""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHEMIN = os.path.join(ROOT, "FTCHTLife/Resources/Data/Beaute/catalogue.json")

CHAMPS = {
    "salons": {"id": str, "nom": str, "description": str, "prix": int, "talent": float, "prestige": int, "ageMin": int, "couleur": bool, "mineurs": bool},
    "coupes": {"id": str, "nom": str, "description": str, "audace": int, "looks": int, "longueur": int, "prixFacteur": float, "duree": int, "ageMin": int},
    "couleurs": {"id": str, "nom": str, "audace": int, "looks": int, "prix": int, "ageMin": int, "duree": int},
    "cliniques": {"id": str, "nom": str, "description": str, "prixFacteur": float, "risqueFacteur": float, "gainBonus": int},
    "complications": {"id": str, "nom": str, "texte": str, "sante": int, "bonheur": int, "apparence": int, "duree": int, "grave": bool, "soin": int},
    "interventions": {"id": str, "nom": str, "zone": str, "description": str, "prix": int, "gainMin": int, "gainMax": int,
                      "risque": float, "risqueGrave": float, "sante": int, "bonheur": int, "ageMin": int,
                      "complications": list, "reussite": list, "rate": list},
}
OPTIONNELS = {
    "salons": {"prison": bool},
    "coupes": {"genre": str},
    "cliniques": {"illegal": bool, "interventions": list},
    "interventions": {"duree": int, "ageIdeal": int, "genre": str, "leger": bool, "repare": str, "marque": str},
}


def type_ok(v, t):
    if t is float:
        return isinstance(v, (int, float)) and not isinstance(v, bool)
    if t is int:
        return isinstance(v, int) and not isinstance(v, bool)
    return isinstance(v, t)


def main():
    err = []
    try:
        cat = json.load(open(CHEMIN, encoding="utf-8"))
    except Exception as ex:
        print(f"ERREUR JSON invalide : {ex}")
        sys.exit(1)
    for section, champs in CHAMPS.items():
        liste = cat.get(section)
        if not isinstance(liste, list) or not liste:
            err.append(f"{section} : liste manquante ou vide")
            continue
        vus = set()
        for x in liste:
            i = x.get("id", "?")
            w = f"{section}/{i}"
            if i in vus:
                err.append(f"{w} : id en double")
            vus.add(i)
            if not re.match(r"^[a-z0-9_]+$", i):
                err.append(f"{w} : id mal formé")
            for k, t in champs.items():
                if k not in x:
                    err.append(f"{w} : champ manquant {k}")
                elif not type_ok(x[k], t):
                    err.append(f"{w} : {k} mauvais type")
            for k, v in x.items():
                if k not in champs and k not in OPTIONNELS.get(section, {}):
                    err.append(f"{w} : champ inconnu {k}")
                elif k in OPTIONNELS.get(section, {}) and not type_ok(v, OPTIONNELS[section][k]):
                    err.append(f"{w} : {k} mauvais type")
            if x.get("genre") not in (None, "homme", "femme"):
                err.append(f"{w} : genre invalide")
    comps = {c["id"] for c in cat.get("complications", [])}
    inters = {i["id"] for i in cat.get("interventions", [])}
    for c in cat.get("coupes", []):
        if not 0 <= c.get("audace", 0) <= 3: err.append(f"coupes/{c['id']} : audace hors 0-3")
        if not 0 <= c.get("longueur", 0) <= 3: err.append(f"coupes/{c['id']} : longueur hors 0-3")
        if c.get("duree", 1) < 1: err.append(f"coupes/{c['id']} : durée < 1")
    for s in cat.get("salons", []):
        if not 0 < s.get("talent", 0) <= 1: err.append(f"salons/{s['id']} : talent hors 0-1")
    for i in cat.get("interventions", []):
        w = f"interventions/{i['id']}"
        if i.get("gainMin", 0) > i.get("gainMax", 0): err.append(f"{w} : gainMin > gainMax")
        if not 0 <= i.get("risque", 0) < 0.5: err.append(f"{w} : risque hors 0-0.5")
        if not 0 <= i.get("risqueGrave", 0) < 0.05: err.append(f"{w} : risqueGrave hors 0-0.05")
        if i.get("ageMin", 0) < 16: err.append(f"{w} : ageMin < 16")
        if i.get("repare") not in (None, "calvitie"): err.append(f"{w} : repare inconnu")
        if i.get("marque") and not re.match(r"^[a-z0-9_]+$", i["marque"]): err.append(f"{w} : marque mal formée")
        for c in i.get("complications", []):
            if c not in comps: err.append(f"{w} : complication inconnue {c}")
        if not i.get("complications"): err.append(f"{w} : aucune complication possible")
        if not i.get("reussite") or not i.get("rate"): err.append(f"{w} : textes reussite/rate manquants")
        for t in i.get("reussite", []) + i.get("rate", []):
            for p in re.findall(r"\{(\w+)\}", t):
                if p != "e": err.append(f"{w} : variable inconnue {{{p}}} (seul {{e}} est remplacé)")
    for c in cat.get("cliniques", []):
        for i in c.get("interventions") or []:
            if i not in inters: err.append(f"cliniques/{c['id']} : intervention inconnue {i}")
    if not any(c["id"] == "reconnu" for c in cat.get("cliniques", [])):
        err.append("cliniques : « reconnu » est obligatoire (clinique par défaut des événements)")
    if not any(s.get("prison") for s in cat.get("salons", [])):
        err.append("salons : il faut au moins un salon de prison")
    for e in err:
        print("ERREUR", e)
    print(f"Catalogue beauté : {sum(len(cat.get(s, [])) for s in CHAMPS)} entrées, {len(err)} erreurs")
    sys.exit(1 if err else 0)


if __name__ == "__main__":
    main()
