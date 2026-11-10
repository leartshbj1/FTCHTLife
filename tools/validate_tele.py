#!/usr/bin/env python3
"""Vérifie les données du module Jeux télé (voir docs/TELE.md).

Usage : python3 tools/validate_tele.py
"""
import json
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent / "FTCHTLife" / "Resources" / "Data"
STATS = {"sante", "bonheur", "intelligence", "apparence", "karma", "charisme", "voix", "cuisine", "celebrite", "hasard"}
EFFETS = {"happiness", "health", "smarts", "looks", "karma", "money", "stress", "fame", "relationships", "newFriend", "death"}
RELATIONS = {"mother", "father", "parent", "sibling", "friend", "partner", "child"}
VARIABLES = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e",
             "emission", "rival", "crush", "manche", "gain", "culte", "celebrite"}
TAGS_TELE = {"tv_candidat", "tv_star", "tv_has_been", "tv_winner", "tv_culte"}
TAGS_MOTEUR = {"male", "female", "baby", "school", "university", "job", "adult", "unemployed", "retired", "rich", "poor",
               "friend", "mother", "father", "siblings", "partner", "children", "sick", "attractive", "smart"}

erreurs = []
ids = set()


def err(ou, msg):
    erreurs.append(f"{ou} : {msg}")


def texte(ou, t, variables=VARIABLES):
    if not isinstance(t, str) or not t.strip():
        err(ou, "texte vide ou absent")
        return
    for v in re.findall(r"\{([^}]*)\}", t):
        if v not in variables:
            err(ou, f"variable inconnue {{{v}}}")


def effets(ou, e):
    if e is None:
        return
    if not isinstance(e, dict):
        err(ou, "effets doit être un objet")
        return
    for k, v in e.items():
        if k not in EFFETS:
            err(ou, f"effet inconnu « {k} »")
        elif k == "relationships":
            for r in v:
                if r not in RELATIONS:
                    err(ou, f"relation inconnue « {r} »")
        elif k == "newFriend":
            if not isinstance(v, bool):
                err(ou, "newFriend doit être true/false")
        elif k == "death":
            texte(ou, v, set())  # le moteur ne remplace pas les variables dans la cause de la mort
        elif not isinstance(v, int):
            err(ou, f"{k} doit être un entier")


def unique(ou, i):
    if i in ids:
        err(ou, f"id en double « {i} »")
    ids.add(i)


def charger(dossier):
    d = RACINE / dossier
    for f in sorted(d.glob("*.json")):
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except Exception as ex:  # noqa: BLE001
            err(f.name, f"JSON invalide : {ex}")
            continue
        if not isinstance(data, list):
            err(f.name, "le fichier doit contenir un tableau")
            continue
        yield f.name, data


def resultats(ou, liste):
    if not isinstance(liste, list) or not liste:
        err(ou, "au moins un résultat requis")
        return
    for k, r in enumerate(liste):
        o = f"{ou}[{k}]"
        texte(o, r.get("texte"))
        p = r.get("points")
        if not isinstance(p, int) or not -3 <= p <= 3:
            err(o, "points doit être un entier de -3 à 3")
        effets(o, r.get("effets"))
        if "culte" in r:
            c = r["culte"]
            texte(o, c)
            if isinstance(c, str) and (c[:1].isupper() or c.rstrip().endswith((".", "!", "?"))):
                err(o, "culte : pas de majuscule au début ni de ponctuation finale")
        for b in ("couple", "rupture"):
            if b in r and not isinstance(r[b], bool):
                err(o, f"{b} doit être true/false")
        inconnues = set(r) - {"texte", "points", "effets", "culte", "couple", "rupture"}
        if inconnues:
            err(o, f"clés inconnues {sorted(inconnues)}")


nb = {"emissions": 0, "situations": 0, "questions": 0, "offres": 0, "evenements": 0}

for nom, data in charger("Tele/Emissions"):
    for em in data:
        ou = f"{nom}:{em.get('id')}"
        unique(ou, em.get("id"))
        nb["emissions"] += 1
        for k in ("nom", "slogan", "icone"):
            texte(ou + "." + k, em.get(k))
        for k in ("ageMin", "ageMax", "prix", "cachet", "celebriteVictoire"):
            if not isinstance(em.get(k), int):
                err(ou, f"{k} doit être un entier")
        c = em.get("casting", {})
        if c.get("stat") not in STATS:
            err(ou, f"casting.stat inconnue « {c.get('stat')} »")
        for k in ("acceptes", "refus"):
            for t in c.get(k) or [None]:
                texte(ou + ".casting." + k, t)
        for k in ("intro", "eliminations", "victoires", "defaitesFinale"):
            for t in em.get(k) or [None]:
                texte(ou + "." + k, t)
        manches = em.get("manches") or []
        if len(manches) < 2:
            err(ou, "au moins 2 manches")
        for m, manche in enumerate(manches):
            texte(f"{ou}.manches[{m}].titre", manche.get("titre"))
            sits = manche.get("situations") or []
            if not sits:
                err(f"{ou}.manches[{m}]", "aucune situation")
            for s in sits:
                so = f"{ou}/{s.get('id')}"
                unique(so, s.get("id"))
                nb["situations"] += 1
                texte(so, s.get("texte"))
                choix = s.get("choix") or []
                if not 2 <= len(choix) <= 4:
                    err(so, "2 à 4 choix")
                for ci, ch in enumerate(choix):
                    co = f"{so}.choix[{ci}]"
                    texte(co + ".label", ch.get("label"))
                    if ch.get("stat") not in STATS:
                        err(co, f"stat inconnue « {ch.get('stat')} »")
                    d = ch.get("difficulte")
                    if not isinstance(d, int) or not 0 <= d <= 100:
                        err(co, "difficulte de 0 à 100")
                    resultats(co + ".reussite", ch.get("reussite"))
                    resultats(co + ".echec", ch.get("echec"))

for nom, data in charger("Tele/Quiz"):
    for q in data:
        ou = f"{nom}:{q.get('id')}"
        unique(ou, q.get("id"))
        nb["questions"] += 1
        if q.get("niveau") not in (1, 2, 3):
            err(ou, "niveau 1, 2 ou 3")
        for k in ("theme", "question", "bonne"):
            texte(ou + "." + k, q.get(k), set())
        m = q.get("mauvaises")
        if not isinstance(m, list) or len(m) != 3:
            err(ou, "exactement 3 mauvaises réponses")
        else:
            reps = [q.get("bonne")] + m
            if len({str(r).strip().lower() for r in reps}) != 4:
                err(ou, "réponses en double")
            for r in m:
                texte(ou + ".mauvaises", r, set())

for nom, data in charger("Tele/Offres"):
    for o in data:
        ou = f"{nom}:{o.get('id')}"
        unique(ou, o.get("id"))
        nb["offres"] += 1
        for k in ("titre", "description", "icone"):
            texte(ou + "." + k, o.get(k))
        g = o.get("gain")
        if not (isinstance(g, list) and len(g) == 2 and all(isinstance(x, int) for x in g) and g[0] <= g[1]):
            err(ou, "gain = [min, max]")
        for t in o.get("textes") or [None]:
            texte(ou + ".textes", t)
        for t in o.get("textesRates") or []:
            texte(ou + ".textesRates", t)
        effets(ou, o.get("effets"))
        effets(ou, o.get("effetsRates"))

for f in sorted((RACINE / "Tele" / "Evenements").glob("*.json")):
    data = json.loads(f.read_text(encoding="utf-8"))
    for ev in data:
        ou = f"{f.name}:{ev.get('id')}"
        unique(ou, ev.get("id"))
        nb["evenements"] += 1
        tags = set((ev.get("conditions") or {}).get("tags") or [])
        if not tags & TAGS_TELE:
            err(ou, "il faut un tag tv_* dans conditions.tags")
        inconnus = (tags | set((ev.get("conditions") or {}).get("excludeTags") or [])) - TAGS_TELE - TAGS_MOTEUR
        if inconnus:
            err(ou, f"tags inconnus {sorted(inconnus)}")
        variables = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e"}
        if "tv_culte" in tags:
            variables.add("culte")
        texte(ou, ev.get("text"), variables)
        effets(ou, ev.get("effects"))
        for c in ev.get("choices") or []:
            texte(ou + ".label", c.get("label"), variables)
            for i in c.get("outcomes") or []:
                texte(ou + ".outcome", i.get("text"), variables)
                effets(ou, i.get("effects"))

if erreurs:
    print("\n".join(erreurs))
    print(f"\n{len(erreurs)} erreur(s).")
    sys.exit(1)
print("OK : " + ", ".join(f"{v} {k}" for k, v in nb.items()))
