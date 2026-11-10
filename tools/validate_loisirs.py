#!/usr/bin/env python3
"""Vérifie les fichiers de loisirs (Resources/Data/Loisirs/*.json) et les événements loisirs_*.json.

Usage : python3 tools/validate_loisirs.py [fichiers...]
Sans argument, vérifie tout le dossier Loisirs et Events/loisirs_act_*.json.
"""
import glob
import json
import os
import re
import sys

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "FTCHTLife", "Resources", "Data")
CATEGORIES = {"nature", "sport", "bien_etre", "sorties", "hobbies", "aventure"}
EFFETS = {"happiness", "health", "smarts", "looks", "karma", "money", "stress", "fame",
          "relationships", "newFriend", "death"}
RELATIONS = {"mother", "father", "parent", "sibling", "friend", "partner", "child"}
VARIABLES = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e"}
ID_RE = re.compile(r"^[a-z0-9_]+$")

erreurs = []
avertissements = []


def err(ou, msg):
    erreurs.append(f"{ou} : {msg}")


def warn(ou, msg):
    avertissements.append(f"{ou} : {msg}")


def verifier_texte(ou, texte):
    if not isinstance(texte, str) or not texte.strip():
        err(ou, "texte vide")
        return
    for v in re.findall(r"\{([^}]*)\}", texte):
        if v not in VARIABLES:
            err(ou, f"variable inconnue {{{v}}}")
    for mot in ("BitLife", "Bitlife", "bitlife"):
        if mot in texte:
            err(ou, "ne pas citer d'autre jeu")


def verifier_effets(ou, eff, suite=False):
    if eff is None:
        return
    if not isinstance(eff, dict):
        err(ou, "effects doit être un objet")
        return
    for k, v in eff.items():
        if k not in EFFETS:
            err(ou, f"effet inconnu « {k} »")
        elif k == "relationships":
            if not isinstance(v, dict):
                err(ou, "relationships doit être un objet")
                continue
            for r, d in v.items():
                if r not in RELATIONS:
                    err(ou, f"relation inconnue « {r} »")
                if not isinstance(d, int):
                    err(ou, f"relationships.{r} doit être un entier")
        elif k == "newFriend":
            if v is not True and v is not None:
                err(ou, "newFriend doit valoir true")
            if suite:
                err(ou, "pas de newFriend dans une suite")
        elif k == "death":
            if not isinstance(v, str) or not v.strip():
                err(ou, "death doit être une phrase")
            if suite:
                err(ou, "pas de death dans une suite")
        elif not isinstance(v, int) or isinstance(v, bool):
            err(ou, f"{k} doit être un entier")
        elif k != "money" and abs(v) > 40:
            warn(ou, f"{k} = {v}, c'est beaucoup")


def verifier_activite(ou, a, ids):
    if not isinstance(a, dict):
        err(ou, "une activité doit être un objet")
        return
    for champ in ("id", "title", "icon", "category", "description", "minAge", "options"):
        if champ not in a:
            err(ou, f"champ manquant « {champ} »")
    aid = a.get("id", "?")
    ou = f"{ou} [{aid}]"
    if not isinstance(aid, str) or not ID_RE.match(aid):
        err(ou, "id invalide (a-z0-9_)")
    elif aid in ids:
        err(ou, f"id en double (déjà dans {ids[aid]})")
    else:
        ids[aid] = ou
    if a.get("category") not in CATEGORIES:
        err(ou, f"catégorie inconnue « {a.get('category')} »")
    if not isinstance(a.get("minAge"), int):
        err(ou, "minAge doit être un entier")
    if a.get("maxAge") is not None and (not isinstance(a["maxAge"], int) or a["maxAge"] < a.get("minAge", 0)):
        err(ou, "maxAge invalide")
    py = a.get("perYear")
    if py is not None and (not isinstance(py, int) or py < 1 or py > 5):
        err(ou, "perYear entre 1 et 5")
    if a.get("signal") is not None and (not isinstance(a["signal"], str) or not ID_RE.match(a["signal"])):
        err(ou, "signal invalide (a-z0-9_)")
    sub = a.get("subscription")
    if sub is not None:
        if not isinstance(sub, dict) or not isinstance(sub.get("name"), str) or not isinstance(sub.get("yearlyCost"), int):
            err(ou, "subscription = {name, yearlyCost}")
    for champ in ("tags", "excludeTags"):
        if a.get(champ) is not None and not isinstance(a[champ], list):
            err(ou, f"{champ} doit être une liste")
    opts = a.get("options")
    if not isinstance(opts, list) or not opts:
        err(ou, "au moins une option")
        return
    oids = set()
    if not any((o.get("minLevel") or 0) == 0 for o in opts if isinstance(o, dict)):
        err(ou, "il faut au moins une option de niveau 0")
    for i, o in enumerate(opts):
        oo = f"{ou} option {i}"
        if not isinstance(o, dict):
            err(oo, "doit être un objet")
            continue
        oid = o.get("id")
        if not isinstance(oid, str) or not ID_RE.match(oid):
            err(oo, "id d'option invalide")
        elif oid in oids:
            err(oo, f"id d'option en double « {oid} »")
        else:
            oids.add(oid)
        if not isinstance(o.get("label"), str) or not o["label"].strip():
            err(oo, "label manquant")
        for champ in ("cost", "minAge", "minLevel", "minHealth", "xp"):
            if o.get(champ) is not None and (not isinstance(o[champ], int) or isinstance(o[champ], bool)):
                err(oo, f"{champ} doit être un entier")
        if o.get("minLevel") is not None and not 0 <= o["minLevel"] <= 4:
            err(oo, "minLevel entre 0 et 4")
        outs = o.get("outcomes")
        if not isinstance(outs, list) or not outs:
            err(oo, "au moins une issue")
            continue
        niveau_min = o.get("minLevel") or 0
        for niveau in range(niveau_min, 5):
            if not any((x.get("minLevel") or 0) <= niveau <= (x.get("maxLevel") if x.get("maxLevel") is not None else 4)
                       for x in outs if isinstance(x, dict)):
                err(oo, f"aucune issue possible au niveau {niveau}")
        for k, x in enumerate(outs):
            ox = f"{oo} issue {k}"
            if not isinstance(x, dict):
                err(ox, "doit être un objet")
                continue
            verifier_texte(ox, x.get("text"))
            if x.get("chance") is not None and (not isinstance(x["chance"], (int, float)) or x["chance"] <= 0):
                err(ox, "chance doit être > 0")
            verifier_effets(ox, x.get("effects"))
            inj = x.get("injury")
            if inj is not None:
                if not isinstance(inj, dict) or not isinstance(inj.get("name"), str):
                    err(ox, "injury = {name, years, healthPerYear}")
                elif inj["name"][:3].lower() in ("un ", "une", "le ", "la ", "l'", "les"):
                    warn(ox, "injury.name sans article")
            fu = x.get("followUp")
            if fu is not None:
                if not isinstance(fu, dict):
                    err(ox, "followUp doit être un objet")
                else:
                    verifier_texte(ox + " suite", fu.get("text"))
                    verifier_effets(ox + " suite", fu.get("effects"), suite=True)
                    if fu.get("inYears") is not None and (not isinstance(fu["inYears"], int) or fu["inYears"] < 1):
                        err(ox, "followUp.inYears >= 1")
            if x.get("key") is not None and (not isinstance(x["key"], str) or not ID_RE.match(x["key"])):
                err(ox, "key invalide (a-z0-9_)")
            if x.get("signal") is not None and (not isinstance(x["signal"], str) or not ID_RE.match(x["signal"])):
                err(ox, "signal invalide (a-z0-9_)")
            for champ in ("minLevel", "maxLevel"):
                if x.get(champ) is not None and (not isinstance(x[champ], int) or not 0 <= x[champ] <= 4):
                    err(ox, f"{champ} entre 0 et 4")


def verifier_evenement(ou, e, ids):
    for champ in ("id", "minAge", "maxAge", "text"):
        if champ not in e:
            err(ou, f"champ manquant « {champ} »")
    eid = e.get("id", "?")
    ou = f"{ou} [{eid}]"
    if eid in ids:
        err(ou, "id en double")
    ids[eid] = ou
    verifier_texte(ou, e.get("text"))
    verifier_effets(ou, e.get("effects"))
    choix = e.get("choices") or []
    if not choix and not e.get("effects"):
        warn(ou, "ni choix ni effets")
    for i, c in enumerate(choix):
        if not c.get("label"):
            err(ou, f"choix {i} sans label")
        if not c.get("outcomes"):
            err(ou, f"choix {i} sans issue")
        for k, x in enumerate(c.get("outcomes") or []):
            verifier_texte(f"{ou} choix {i} issue {k}", x.get("text"))
            verifier_effets(f"{ou} choix {i} issue {k}", x.get("effects"))


def main():
    fichiers = sys.argv[1:]
    if not fichiers:
        fichiers = sorted(glob.glob(os.path.join(RACINE, "Loisirs", "*.json")))
        fichiers += sorted(glob.glob(os.path.join(RACINE, "Events", "loisirs_act_*.json")))
    ids_act, ids_evt = {}, {}
    nb_act = nb_opt = nb_iss = nb_evt = 0
    for f in fichiers:
        nom = os.path.basename(f)
        try:
            with open(f, encoding="utf-8") as h:
                data = json.load(h)
        except Exception as ex:  # noqa: BLE001
            err(nom, f"JSON invalide : {ex}")
            continue
        if not isinstance(data, list):
            err(nom, "le fichier doit contenir un tableau")
            continue
        est_evt = os.path.basename(os.path.dirname(os.path.abspath(f))) == "Events"
        for i, x in enumerate(data):
            if est_evt:
                nb_evt += 1
                verifier_evenement(f"{nom} #{i}", x, ids_evt)
            else:
                nb_act += 1
                verifier_activite(f"{nom} #{i}", x, ids_act)
                for o in x.get("options") or []:
                    nb_opt += 1
                    nb_iss += len(o.get("outcomes") or [])
    for a in avertissements:
        print("⚠️ ", a)
    for e in erreurs:
        print("❌", e)
    print(f"{nb_act} activités, {nb_opt} options, {nb_iss} issues, {nb_evt} événements. "
          f"{len(erreurs)} erreur(s), {len(avertissements)} avertissement(s).")
    sys.exit(1 if erreurs else 0)


if __name__ == "__main__":
    main()
