#!/usr/bin/env python3
"""Vérifie les cartes « métiers qui changent la vie » (docs/METIERS_VIE.md).

Fichiers : FTCHTLife/Resources/Data/Repercussions/metiers_vie_*.json
Usage : python3 tools/validate_metiers_vie.py [--stats]
Lance aussi tools/validate_repercussions.py sur ces fichiers. Code de sortie 1 s'il y a des erreurs.
"""
import collections
import glob
import json
import os
import re
import subprocess
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(RACINE, "FTCHTLife", "Resources", "Data")
FICHIERS = sorted(glob.glob(os.path.join(DATA, "Repercussions", "metiers_vie_*.json")))
RE_ID = re.compile(r"^rep_met_(\d{4})$")
STATS = {"happiness", "health", "smarts", "looks", "money"}
# Variable → tag qui garantit que la personne existe.
VAR_TAG = {"partenaire": "partner", "enfant": "children", "ami": "friend", "mere": "mother", "pere": "father",
           "fratrie": "siblings"}
# Tags qui garantissent aussi la variable (parents = au moins un parent).
TAG_EQUIV = {"parents": {"mother", "father"}}
# Ces variables ont un repli raisonnable dans le moteur, mais on préfère le tag.
ACCEPTE_SANS_TAG = {"parent"}


def metiers():
    ids = set()
    for f in glob.glob(os.path.join(DATA, "Careers", "*.json")):
        for j in json.load(open(f, encoding="utf-8")):
            ids.add(j["id"])
    return ids


def textes(r):
    yield r.get("text") or ""
    for c in r.get("choices") or []:
        yield c.get("label") or ""
        for o in c.get("outcomes") or []:
            yield o.get("text") or ""


def main():
    stats = "--stats" in sys.argv
    connus = metiers()
    erreurs, avert = [], []
    vus = {}
    cartes = collections.Counter()
    apres = collections.Counter()
    poses = set()
    exiges = []
    for f in FICHIERS:
        nom = os.path.basename(f)
        try:
            data = json.load(open(f, encoding="utf-8"))
        except Exception as ex:
            erreurs.append(f"{nom} : JSON invalide ({ex})")
            continue
        for r in data:
            i = r.get("id", "?")
            ou = f"{nom}/{i}"
            if not RE_ID.match(i):
                erreurs.append(f"{ou} : id attendu rep_met_NNNN")
            if i in vus:
                erreurs.append(f"{ou} : id en double (aussi dans {vus[i]})")
            vus[i] = nom
            if r.get("on") != "chaque_annee":
                erreurs.append(f"{ou} : « on » doit être chaque_annee")
            c = r.get("conditions") or {}
            tags = set(c.get("tags") or [])
            flags = set(c.get("flags") or [])
            job_tags = [t for t in tags if t.startswith("metier_")]
            for t in job_tags + [t for t in c.get("excludeTags") or [] if t.startswith("metier_")]:
                if t[7:] not in connus:
                    erreurs.append(f"{ou} : métier inconnu « {t[7:]} »")
            for fl in flags:
                if fl.startswith("a_ete_") and fl[6:] not in connus:
                    erreurs.append(f"{ou} : drapeau d'ancien métier vers un métier inconnu « {fl} »")
            for fl in r.get("remember") or []:
                poses.add(fl)
            for ch in r.get("choices") or []:
                for o in ch.get("outcomes") or []:
                    for fl in (o.get("effects") or {}).get("setFlags") or []:
                        poses.add(fl)
            for fl in (r.get("effects") or {}).get("setFlags") or []:
                poses.add(fl)
            for fl in r.get("setFlags") or []:
                poses.add(fl)
            for fl in flags:
                exiges.append((ou, fl))
            texte = r.get("text")
            if texte is None:
                # Règle de marquage : pose a_ete_<métier> pendant qu'on l'exerce.
                if len(job_tags) != 1:
                    erreurs.append(f"{ou} : règle sans texte qui n'exige pas un métier")
                attendu = "a_ete_" + job_tags[0][7:] if job_tags else None
                for fl in r.get("remember") or []:
                    if fl != attendu:
                        avert.append(f"{ou} : drapeau de marquage « {fl} » (attendu a_ete_<métier>)")
                continue
            if r.get("unique") is not True:
                erreurs.append(f"{ou} : carte sans unique: true")
            ch = r.get("chance")
            if not isinstance(ch, (int, float)) or not (0.01 <= ch <= 0.15):
                erreurs.append(f"{ou} : chance attendue entre 0,01 et 0,15 (ici {ch})")
            if job_tags:
                cartes[job_tags[0][7:]] += 1
            else:
                anciens = [fl for fl in flags if fl.startswith("a_ete_")]
                if anciens:
                    apres[anciens[0][6:]] += 1
                    if "metier_" + anciens[0][6:] not in (c.get("excludeTags") or []):
                        erreurs.append(f"{ou} : carte « après » sans excludeTags metier_{anciens[0][6:]}")
                elif not flags:
                    erreurs.append(f"{ou} : carte sans tag metier_ ni drapeau")
            choix = r.get("choices") or []
            if not 2 <= len(choix) <= 3:
                erreurs.append(f"{ou} : 2 ou 3 choix attendus ({len(choix)})")
            for ci, cc in enumerate(choix):
                issues = cc.get("outcomes") or []
                if not 1 <= len(issues) <= 3:
                    erreurs.append(f"{ou} choix {ci} : 1 à 3 issues attendues")
                total = sum(o.get("chance", 1) for o in issues)
                if issues and abs(total - 1) > 0.011:
                    erreurs.append(f"{ou} choix {ci} : somme des chances = {total}")
                if len((cc.get("label") or "").split()) > 7:
                    avert.append(f"{ou} choix {ci} : label long « {cc.get('label')} »")
                for oi, o in enumerate(issues):
                    eff = o.get("effects") or {}
                    if not STATS & set(eff):
                        avert.append(f"{ou} choix {ci} issue {oi} : aucune stat centrale")
            for t in textes(r):
                if "·" in t:
                    erreurs.append(f"{ou} : écriture « · » dans un texte (« {t[:40]}… »)")
                for v in re.findall(r"\{([^}]*)\}", t):
                    tag = VAR_TAG.get(v)
                    if tag and tag not in tags and not any(tag in TAG_EQUIV.get(x, ()) for x in tags):
                        erreurs.append(f"{ou} : {{{v}}} sans le tag « {tag} »")

    for ou, fl in exiges:
        if fl.startswith("a_ete_") or fl in poses:
            continue
        avert.append(f"{ou} : drapeau exigé « {fl} » jamais posé par ces cartes (drapeau commun ?)")
    for m in apres:
        if f"a_ete_{m}" not in poses:
            erreurs.append(f"cartes « après » pour {m} sans règle qui pose a_ete_{m}")

    sans = sorted(connus - set(cartes))
    for a in avert:
        print("avertissement :", a)
    for e in erreurs:
        print("ERREUR :", e)
    total = sum(cartes.values()) + sum(apres.values())
    print(f"{total} cartes ({sum(apres.values())} après le métier), {len(cartes)} métiers couverts sur {len(connus)}, "
          f"{len(erreurs)} erreurs, {len(avert)} avertissements")
    if stats:
        print("Métiers sans carte :", " ".join(sans) or "aucun")
        peu = sorted(m for m, n in cartes.items() if n < 4)
        print("Métiers avec moins de 4 cartes :", " ".join(peu) or "aucun")
    code = 1 if erreurs else 0
    if FICHIERS:
        rep = subprocess.run([sys.executable, os.path.join(RACINE, "tools", "validate_repercussions.py"), *FICHIERS],
                             capture_output=True, text=True)
        lignes = rep.stdout.strip().splitlines()
        for l in lignes:
            if l.startswith("ERREUR") or l == lignes[-1]:
                print("validate_repercussions :", l)
        code |= rep.returncode
    return code


if __name__ == "__main__":
    sys.exit(main())
