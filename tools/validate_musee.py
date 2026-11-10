#!/usr/bin/env python3
"""Vérifie les données de la nécrologie et du musée (FTCHTLife/Resources/Data/Museum).

Usage : python3 tools/validate_musee.py
"""
import json
import re
import sys
from pathlib import Path

DOSSIER = Path(__file__).resolve().parent.parent / "FTCHTLife" / "Resources" / "Data" / "Museum"

SECTIONS = ["titre", "intro", "enfance", "etudes", "carriere", "argent", "amour",
            "famille", "caractere", "fin", "epitaphe"]
SECTIONS_OBLIGATOIRES = ["titre", "intro", "fin", "epitaphe"]

TAGS = set("""
male female bebe enfant ado jeune adulte vieux tres_vieux centenaire
endette fauche aise riche milliardaire
sans_diplome bachelier diplome_sup doctorat
filiere_medecine filiere_droit filiere_informatique filiere_commerce filiere_arts filiere_sciences
travailleur chomeur retraite etudiant
intelligent bete beau moche gentil mechant heureux deprime malade
populaire solitaire en_couple celibataire ex_nombreux
parent famille_nombreuse fratrie enfant_unique orphelin
mort_naturelle mort_maladie mort_absurde
vie_reussie vie_ratee
""".split())

VARIABLES = {"prenom", "nom", "surnom", "ville", "age", "cause", "metier", "fortune", "diplome",
             "filiere", "nbAmis", "nbEnfants", "nbEx", "partenaire", "mere", "pere", "e", "il", "Il", "le"}

# Variable -> tag requis pour l'utiliser.
VARIABLE_TAG = {"metier": "travailleur", "partenaire": "en_couple", "filiere": "diplome_sup"}

CLES = {"id", "section", "text", "textFemale", "weight", "conditions"}
CLES_COND = {"tags", "excludeTags", "minAge", "maxAge"}

erreurs = []


def err(f, msg):
    erreurs.append(f"{f}: {msg}")


def verifier_texte(f, ident, texte, tags, est_surnom):
    if not isinstance(texte, str) or not texte.strip():
        err(f, f"{ident}: texte vide")
        return
    for v in re.findall(r"\{([^}]*)\}", texte):
        if v not in VARIABLES:
            err(f, f"{ident}: variable inconnue {{{v}}}")
        elif v in VARIABLE_TAG and VARIABLE_TAG[v] not in tags:
            err(f, f"{ident}: {{{v}}} demande le tag {VARIABLE_TAG[v]}")
        if est_surnom and v not in ("e",):
            err(f, f"{ident}: un surnom n'utilise pas de variable (sauf {{e}})")
    if "  " in texte:
        err(f, f"{ident}: double espace")
    if re.search(r"\btu\b|\bton\b|\bta\b|\btes\b", texte, re.IGNORECASE) and not est_surnom:
        err(f, f"{ident}: tutoiement interdit (3e personne)")


def verifier_conditions(f, ident, c):
    if c is None:
        return set()
    if not isinstance(c, dict):
        err(f, f"{ident}: conditions doit être un objet")
        return set()
    for k in c:
        if k not in CLES_COND:
            err(f, f"{ident}: condition inconnue {k}")
    tags = c.get("tags") or []
    excl = c.get("excludeTags") or []
    for t in list(tags) + list(excl):
        if t not in TAGS:
            err(f, f"{ident}: tag inconnu {t}")
    if set(tags) & set(excl):
        err(f, f"{ident}: tag à la fois requis et exclu")
    for k in ("minAge", "maxAge"):
        if c.get(k) is not None and not isinstance(c[k], int):
            err(f, f"{ident}: {k} doit être un entier")
    return set(tags)


def main():
    if not DOSSIER.is_dir():
        print(f"Dossier introuvable : {DOSSIER}")
        return 1
    ids = {}
    par_section = {s: [] for s in SECTIONS}
    surnoms = []
    textes = {}
    for chemin in sorted(DOSSIER.glob("*.json")):
        f = chemin.name
        try:
            data = json.loads(chemin.read_text(encoding="utf-8"))
        except Exception as e:  # noqa: BLE001
            err(f, f"JSON invalide : {e}")
            continue
        if not isinstance(data, list):
            err(f, "le fichier doit contenir un tableau")
            continue
        est_surnom = f.startswith("surnoms")
        if not est_surnom and not f.startswith("necro_"):
            err(f, "nom de fichier : surnoms*.json ou necro_*.json")
            continue
        for o in data:
            ident = o.get("id", "?")
            if ident in ids:
                err(f, f"id en double {ident} (déjà dans {ids[ident]})")
            ids[ident] = f
            for k in o:
                if k not in CLES:
                    err(f, f"{ident}: clé inconnue {k}")
            tags = verifier_conditions(f, ident, o.get("conditions"))
            for cle in ("text", "textFemale"):
                if o.get(cle) is not None:
                    verifier_texte(f, ident, o[cle], tags, est_surnom)
                    norm = o[cle].strip().lower()
                    if norm in textes:
                        err(f, f"{ident}: texte identique à {textes[norm]}")
                    textes[norm] = ident
            w = o.get("weight")
            if w is not None and (not isinstance(w, (int, float)) or w <= 0):
                err(f, f"{ident}: weight doit être > 0")
            if est_surnom:
                if "section" in o:
                    err(f, f"{ident}: un surnom n'a pas de section")
                surnoms.append(o)
            else:
                s = o.get("section")
                if s not in SECTIONS:
                    err(f, f"{ident}: section inconnue {s}")
                else:
                    par_section[s].append(o)

    def generique(o):
        c = o.get("conditions") or {}
        return not (c.get("tags") or c.get("excludeTags") or c.get("minAge") is not None or c.get("maxAge") is not None)

    if not any(generique(o) for o in surnoms):
        err("surnoms", "il faut au moins un surnom sans condition")
    for s in SECTIONS_OBLIGATOIRES:
        if not any(generique(o) for o in par_section[s]):
            err(s, "il faut au moins une phrase sans condition dans cette section")

    print(f"Surnoms : {len(surnoms)}")
    for s in SECTIONS:
        print(f"  {s:10s} {len(par_section[s])}")
    if erreurs:
        print(f"\n{len(erreurs)} erreur(s) :")
        for e in erreurs:
            print("  - " + e)
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
