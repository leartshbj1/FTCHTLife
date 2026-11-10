#!/usr/bin/env python3
"""Convertit les données brutes du module vie (format docs/donnees-vie-sociale.md)
vers les formats du jeu :
- événements -> FTCHTLife/Resources/Data/Events/vie_*.json (format docs/ARCHITECTURE.md, effets en plus dans "vie")
- suites (followUpOnly) -> FTCHTLife/Resources/Data/Repercussions/vie_suites.json (format docs/REPERCUSSIONS.md)
- crimes, activités de prison, maladies, alternatives, addictions, étapes, noms, dialogues -> dossiers du module.

Usage : python3 tools/convertir_vie.py <dossier_brut>
Le dossier brut contient relations/, crime/, health/ (fichiers écrits par les auteurs).
"""
import json
import os
import sys

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "FTCHTLife", "Resources", "Data")

FLAGS = {
    "hasPartner": "partner", "isDating": "dating", "isEngaged": "engaged", "isMarried": "married",
    "single": "single", "hasChildren": "children", "hasFriends": "friend", "hasParents": "parents",
    "hasSiblings": "siblings", "hasEx": "ex", "inPrison": "prison", "hasRecord": "record",
    "isSick": "malade", "isHealthy": "bien_portant", "lowHealth": "sick", "rich": "rich", "poor": "poor",
    "hasAddiction": "addiction",
}
# Ordre de la personne ciblée par "bond" (même ordre que l'auteur a utilisé pour les variables).
CIBLES = [("hasPartner", "partner"), ("hasChildren", "child"), ("hasFriends", "friend"),
          ("hasParents", "parent"), ("hasSiblings", "sibling"), ("hasEx", "ex")]
STATS = ["health", "happiness", "smarts", "looks", "karma", "money"]
VIE = ["jailMonths", "fine", "record", "disease", "breakup", "newPartner", "pregnancy", "addiction"]


def lire(chemin):
    if not os.path.exists(chemin):
        return None
    with open(chemin, encoding="utf-8") as f:
        return json.load(f)


def ecrire(dossier, nom, donnees):
    d = os.path.join(RACINE, dossier)
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, nom), "w", encoding="utf-8") as f:
        json.dump(donnees, f, ensure_ascii=False, indent=1)
        f.write("\n")
    n = len(donnees) if isinstance(donnees, list) else len(donnees.keys())
    print(f"  {dossier}/{nom} : {n}")


def cible(requires):
    for flag, cle in CIBLES:
        if flag in requires:
            return cle
    return None


def conditions(e):
    req = e.get("requires") or []
    exc = e.get("excludes") or []
    c = {}
    if "male" in req:
        c["gender"] = "male"
    if "female" in req:
        c["gender"] = "female"
    tags = [FLAGS[f] for f in req if f in FLAGS]
    xtags = [FLAGS[f] for f in exc if f in FLAGS]
    if "male" in exc:
        c["gender"] = "female"
    if "female" in exc:
        c["gender"] = "male"
    if tags:
        c["tags"] = sorted(set(tags))
    if xtags:
        c["excludeTags"] = sorted(set(xtags))
    return c or None


def effets(fx, qui):
    if not fx:
        return None
    out = {k: fx[k] for k in STATS if fx.get(k)}
    if fx.get("bond") and qui and qui != "ex":
        out["relationships"] = {qui: fx["bond"]}
    if fx.get("newFriend"):
        out["newFriend"] = True
    if fx.get("death"):
        out["death"] = fx["death"]
    if fx.get("followUp") in REP_IDS:
        out["followUps"] = [REP_IDS[fx["followUp"]]]
    vie = {k: fx[k] for k in VIE if fx.get(k)}
    if fx.get("cure"):
        vie["cure"] = True
    if fx.get("targetDies") and qui:
        vie["targetDies"] = qui
    if vie:
        out["vie"] = vie
    return out or None


def choix(e):
    qui = cible(e.get("requires") or [])
    res = []
    for c in e.get("choices") or []:
        issues = []
        for o in c.get("outcomes") or []:
            i = {"chance": o.get("chance", 1), "text": o["text"]}
            fx = effets(o.get("effects"), qui)
            if fx:
                i["effects"] = fx
            issues.append(i)
        res.append({"label": c["label"], "outcomes": issues})
    return res


def evenement(e):
    ev = {
        "id": e["id"],
        "category": e.get("category", "relation"),
        "minAge": e.get("minAge", 0) if e.get("minAge") is not None else 0,
        "maxAge": e.get("maxAge", 120) if e.get("maxAge") is not None else 120,
        "weight": e.get("weight", 1),
    }
    c = conditions(e)
    if c:
        ev["conditions"] = c
    ev["text"] = e["text"]
    ev["choices"] = choix(e)
    return ev


REP_IDS = {}


def preparer_suites(suites_brutes):
    """Donne un id de Répercussions (rep_vie_NNNN) à chaque suite."""
    for n, s in enumerate(suites_brutes, 1):
        REP_IDS[s["id"]] = f"rep_vie_{n:04d}"


def suites(evenements_sources, suites_brutes):
    """Chaque suite devient une règle de Répercussions programmée par "followUps" (signal "vie_suite" jamais émis)."""
    delais = {}
    for src in list(evenements_sources) + list(suites_brutes):
        for c in src.get("choices") or []:
            for o in c.get("outcomes") or []:
                fx = o.get("effects") or {}
                if fx.get("followUp"):
                    delais.setdefault(fx["followUp"], []).append(int(fx.get("followUpYears", 1) or 0))
    regles = []
    for s in suites_brutes:
        d = delais.get(s["id"])
        if not d:
            print(f"  ! suite jamais déclenchée : {s['id']}")
            continue
        r = {"id": REP_IDS[s["id"]], "on": "vie_suite", "delay": [min(d), max(d)], "patience": 1}
        c = conditions(s)
        if c:
            r["conditions"] = c
        if s.get("minAge") is not None and s.get("minAge") > 0:
            r["minAge"] = s["minAge"]
        r["text"] = s["text"]
        r["choices"] = choix(s)
        regles.append(r)
    return regles


def main():
    brut = sys.argv[1]
    for f in ["relations/followups.json", "relations/events_suites.json"]:
        d = lire(os.path.join(brut, f)) or []
        preparer_suites_liste = [e for e in d if e.get("followUpOnly")]
        if preparer_suites_liste:
            preparer_suites(preparer_suites_liste)
    print("Événements :")
    tous_sources = []
    suites_brutes = []
    for dossier, fichiers in {"relations": ["events.json", "events_suites.json", "followups.json"],
                              "crime": ["events.json", "prison_events.json"],
                              "health": ["events.json"]}.items():
        for f in fichiers:
            d = lire(os.path.join(brut, dossier, f))
            if not d:
                continue
            normaux = [e for e in d if not e.get("followUpOnly")]
            suites_brutes += [e for e in d if e.get("followUpOnly")]
            tous_sources += normaux
            if normaux:
                nom = {"relations/events.json": "vie_amour.json", "relations/events_suites.json": "vie_amour_suites.json",
                       "relations/followups.json": "vie_amour_debuts.json",
                       "crime/events.json": "vie_crime.json", "crime/prison_events.json": "vie_prison.json",
                       "health/events.json": "vie_sante.json"}[f"{dossier}/{f}"]
                ecrire("Events", nom, [evenement(e) for e in normaux])
    if suites_brutes:
        print("Répercussions :")
        ecrire("Repercussions", "vie_suites.json", suites(tous_sources, suites_brutes))

    print("Données du module :")
    for src, dst, nom in [("crime/crimes.json", "Crime", "crimes.json"),
                          ("crime/prison_activities.json", "CrimePrison", "activites.json"),
                          ("health/diseases.json", "Health", "maladies.json"),
                          ("health/alternatives.json", "HealthAlternatives", "alternatives.json"),
                          ("health/addictions.json", "HealthAddictions", "addictions.json"),
                          ("relations/milestones.json", "Relationships", "etapes.json"),
                          ("relations/names.json", "RelationshipsTexts", "noms.json"),
                          ("relations/dialogues.json", "RelationshipsTexts", "dialogues.json")]:
        d = lire(os.path.join(brut, src))
        if d is not None:
            ecrire(dst, nom, d)


if __name__ == "__main__":
    main()
