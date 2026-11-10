#!/usr/bin/env python3
"""Vérifie les données du module casier judiciaire.

- Data/Casier/{Avocats,Pistons,Metiers,TIG}/*.json : champs, gravités, ids uniques, chances entre 0 et 1.
- Tous les événements de Data/Events : le sous-objet effects.casier (et ceux des issues) a un format valide.

Usage : python3 tools/validate_casier.py   (code de sortie 1 en cas d'erreur)
"""
import json
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent / "FTCHTLife" / "Resources" / "Data"
GRAVITES = {"contravention", "delit", "crime"}
CONDITIONS_PISTON = {"parent", "ami", "partenaire", "fratrie", "metier", "riche", "aucune"}
VARIABLES_DONNEES = {"prenom", "e", "ville", "contact", "infraction"}
erreurs = []


def err(fichier, msg):
    erreurs.append(f"{fichier.relative_to(RACINE)} : {msg}")


def charger(dossier):
    for f in sorted((RACINE / "Casier" / dossier).glob("*.json")):
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            err(f, f"JSON invalide ({e})")
            continue
        if not isinstance(data, list):
            err(f, "doit contenir un tableau")
            continue
        for i, el in enumerate(data):
            yield f, i, el


def textes_ok(f, ou, textes):
    if not isinstance(textes, list) or not textes or not all(isinstance(t, str) and t.strip() for t in textes):
        err(f, f"{ou} : liste de phrases non vide attendue")
        return
    for t in textes:
        for v in re.findall(r"\{(\w+)\}", t):
            if v not in VARIABLES_DONNEES:
                err(f, f"{ou} : variable inconnue {{{v}}}")
        if "—" in t:
            err(f, f"{ou} : tiret long interdit")


def verifier_chance(f, ou, el, cle, obligatoire):
    v = el.get(cle)
    if v is None:
        if obligatoire:
            err(f, f"{ou} : '{cle}' manquant")
        return
    if not isinstance(v, (int, float)) or not 0 <= v <= 1:
        err(f, f"{ou} : '{cle}' doit être entre 0 et 1")


def verifier_offres(dossier, extra):
    ids = set()
    for f, i, el in charger(dossier):
        ou = f"[{i}] {el.get('id', '?')}"
        for cle in ("id", "nom", "description"):
            if not isinstance(el.get(cle), str) or not el[cle].strip():
                err(f, f"{ou} : '{cle}' manquant")
        if el.get("id") in ids:
            err(f, f"{ou} : id en double")
        ids.add(el.get("id"))
        if el.get("graviteMax") not in GRAVITES:
            err(f, f"{ou} : graviteMax invalide")
        verifier_chance(f, ou, el, "chance", True)
        verifier_chance(f, ou, el, "risque", False)
        textes_ok(f, ou + ".succes", el.get("succes"))
        textes_ok(f, ou + ".echecs", el.get("echecs"))
        if el.get("risque"):
            textes_ok(f, ou + ".scandales", el.get("scandales"))
        extra(f, ou, el)
    return len(ids)


def extra_avocat(f, ou, el):
    if not isinstance(el.get("prix"), int) or el["prix"] < 0:
        err(f, f"{ou} : 'prix' entier positif attendu")


def extra_piston(f, ou, el):
    cond = el.get("condition")
    if cond not in CONDITIONS_PISTON:
        err(f, f"{ou} : condition invalide ({cond})")
    if cond == "metier" and not el.get("metiers"):
        err(f, f"{ou} : condition 'metier' sans liste 'metiers'")
    if "prix" in el and (not isinstance(el["prix"], int) or el["prix"] < 0):
        err(f, f"{ou} : 'prix' entier positif attendu")


def verifier_metiers():
    n = 0
    for f, i, el in charger("Metiers"):
        n += 1
        ou = f"[{i}] {el.get('nom', '?')}"
        if not isinstance(el.get("nom"), str) or not el["nom"].strip():
            err(f, f"{ou} : 'nom' manquant")
        if el.get("graviteMin") not in GRAVITES:
            err(f, f"{ou} : graviteMin invalide")
        if not el.get("ids") and not el.get("motsCles"):
            err(f, f"{ou} : il faut 'ids' ou 'motsCles'")
        if not isinstance(el.get("raison"), str) or not el["raison"].strip():
            err(f, f"{ou} : 'raison' manquante")
    return n


def verifier_tig():
    n = 0
    for f, i, el in charger("TIG"):
        n += 1
        if not isinstance(el.get("mission"), str) or not el["mission"].strip():
            err(f, f"[{i}] : 'mission' manquante")
        textes_ok(f, f"[{i}].anecdotes", el.get("anecdotes"))
    return n


def verifier_effet_casier(f, ou, cas, compte):
    if not isinstance(cas, dict):
        err(f, f"{ou} : 'casier' doit être un objet")
        return
    inconnues = set(cas) - {"condamnation", "effacer", "delai"}
    if inconnues:
        err(f, f"{ou} : clés inconnues dans 'casier' : {sorted(inconnues)}")
    if "condamnation" in cas:
        c = cas["condamnation"]
        if not isinstance(c, dict) or not isinstance(c.get("infraction"), str) or not c["infraction"].strip():
            err(f, f"{ou} : condamnation.infraction manquante")
        elif c.get("gravite") not in GRAVITES:
            err(f, f"{ou} : condamnation.gravite invalide")
        else:
            compte["condamnation"] += 1
    if "effacer" in cas:
        if cas["effacer"] not in ("une", "tout"):
            err(f, f"{ou} : effacer doit valoir 'une' ou 'tout'")
        compte["effacer"] += 1
    if "delai" in cas:
        if not isinstance(cas["delai"], int) or not 1 <= cas["delai"] <= 10:
            err(f, f"{ou} : delai entier entre 1 et 10 attendu")
        compte["delai"] += 1


def verifier_evenements():
    compte = {"condamnation": 0, "effacer": 0, "delai": 0, "evenements": 0}
    for f in sorted((RACINE / "Events").glob("*.json")):
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            continue  # le validateur des événements s'en charge
        for ev in data if isinstance(data, list) else []:
            eid = ev.get("id", "?")
            touche = False
            effets = [(f"{eid}.effects", ev.get("effects"))]
            for ci, ch in enumerate(ev.get("choices") or []):
                for oi, oc in enumerate(ch.get("outcomes") or []):
                    effets.append((f"{eid}.choices[{ci}].outcomes[{oi}]", oc.get("effects")))
            for ou, eff in effets:
                if isinstance(eff, dict) and "casier" in eff:
                    touche = True
                    verifier_effet_casier(f, ou, eff["casier"], compte)
            tags = set((ev.get("conditions") or {}).get("tags") or []) | set((ev.get("conditions") or {}).get("excludeTags") or [])
            if touche or tags & {"casier", "casier_lourd", "tig", "casier_efface"}:
                compte["evenements"] += 1
    return compte


if __name__ == "__main__":
    na = verifier_offres("Avocats", extra_avocat)
    npi = verifier_offres("Pistons", extra_piston)
    nm = verifier_metiers()
    nt = verifier_tig()
    ev = verifier_evenements()
    if erreurs:
        print("\n".join(erreurs))
        print(f"\n{len(erreurs)} erreur(s).")
        sys.exit(1)
    print(f"OK : {na} avocats, {npi} pistons, {nm} règles de métiers fermés, {nt} missions de TIG.")
    print(f"Événements liés au casier : {ev['evenements']} ({ev['condamnation']} condamnations, "
          f"{ev['effacer']} effacements, {ev['delai']} délais).")
