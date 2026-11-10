#!/usr/bin/env python3
"""Valide les données du module Vie scolaire (FTCHTLife/Resources/Data/Scolarite).
Usage : python3 tools/validate_scolarite.py"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "FTCHTLife/Resources/Data/Scolarite")

STATS = {"happiness", "health", "smarts", "looks", "money", "karma", "stress", "fame"}
REL = {"mother", "father", "parent", "sibling", "friend", "partner", "child"}
SCHOOL = {"popularity", "teachers", "detention", "summonParents", "grades", "joinGroup", "leaveGroup", "loseDelegate"}
GROUPES = {"sportifs", "intellos", "rebelles", "gamers", "artistes", "stars"}
TAGS = {"male", "female", "baby", "school", "university", "job", "adult", "unemployed", "retired", "rich", "poor",
        "friend", "mother", "father", "siblings", "partner", "children", "sick", "attractive", "smart",
        "scol_college", "scol_lycee", "scol_6e", "scol_5e", "scol_4e", "scol_3e", "scol_2nde", "scol_1re",
        "scol_terminale", "scol_populaire", "scol_impopulaire", "scol_chouchou", "scol_bete_noire",
        "scol_delegue", "scol_colle", "scol_sans_groupe"} | {"scol_groupe_" + g for g in GROUPES}
PH = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "e",
      "prof", "matiere", "classe", "groupe", "camarade"}
COND = {"gender", "tags", "excludeTags"}
MATIERES = {"francais", "maths", "histoire", "anglais", "svt", "physique", "eps", "arts", "musique", "techno",
            "philo", "ses", "espagnol", "allemand", "*"}
TRANCHES = {"excellent", "bien", "moyen", "faible", "nul"}
MENTIONS = {"felicitations", "compliments", "encouragements", "rien", "avertissement_travail", "avertissement_conduite"}
TRAITS = {"bavard", "insolent", "absent", "chouchou", "populaire", "invisible", "delegue", "colles"} | GROUPES
TYPES = {"appreciation", "comportement", "generale", "delegue", "colle", "prof", "adversaire", "promesse"}

errs = []
ids = {}


def err(msg):
    errs.append(msg)


def check_id(i, where):
    if not isinstance(i, str) or not i:
        err(f"{where}: id manquant")
        return
    if i in ids:
        err(f"{where}: id {i} déjà utilisé dans {ids[i]}")
    ids[i] = where


def check_text(t, where, ph=PH):
    if not isinstance(t, str) or not t.strip():
        err(f"{where}: texte vide")
        return
    for p in re.findall(r"\{(\w+)\}", t):
        if p not in ph:
            err(f"{where}: variable inconnue {{{p}}}")


def check_effects(e, where):
    if e is None:
        return
    if not isinstance(e, dict):
        err(f"{where}: effects n'est pas un objet")
        return
    for k, v in e.items():
        if k in STATS:
            if not isinstance(v, (int, float)) or isinstance(v, bool):
                err(f"{where}: {k} non numérique")
            elif k != "money" and abs(v) > 40:
                err(f"{where}: {k} trop fort ({v})")
            elif not isinstance(v, int):
                err(f"{where}: {k} doit être un entier")
        elif k == "relationships":
            if not isinstance(v, dict) or any(r not in REL or not isinstance(x, int) for r, x in v.items()):
                err(f"{where}: relationships invalide {v}")
        elif k == "newFriend":
            if not isinstance(v, bool):
                err(f"{where}: newFriend doit être true/false")
        elif k == "school":
            if not isinstance(v, dict):
                err(f"{where}: school n'est pas un objet")
                continue
            for sk, sv in v.items():
                if sk not in SCHOOL:
                    err(f"{where}: clé school inconnue {sk}")
                elif sk in ("popularity", "teachers", "detention"):
                    if not isinstance(sv, int) or isinstance(sv, bool) or abs(sv) > 40:
                        err(f"{where}: school.{sk} invalide ({sv})")
                elif sk == "grades":
                    if not isinstance(sv, (int, float)) or isinstance(sv, bool) or abs(sv) > 5:
                        err(f"{where}: school.grades invalide ({sv})")
                elif sk == "joinGroup":
                    if sv not in GROUPES:
                        err(f"{where}: groupe inconnu {sv}")
                elif not isinstance(sv, bool):
                    err(f"{where}: school.{sk} doit être true/false")
        else:
            err(f"{where}: clé d'effet inconnue {k}")


def check_conditions(c, where):
    if c is None:
        return
    if not isinstance(c, dict):
        err(f"{where}: conditions n'est pas un objet")
        return
    for k, v in c.items():
        if k not in COND:
            err(f"{where}: condition inconnue {k}")
        elif k == "gender":
            if v not in (None, "any", "male", "female"):
                err(f"{where}: gender invalide {v}")
        else:
            for t in v or []:
                if t not in TAGS:
                    err(f"{where}: tag inconnu {t}")


def check_outcomes(outs, where):
    if not isinstance(outs, list) or not outs:
        err(f"{where}: aucune issue")
        return
    if len(outs) > 3:
        err(f"{where}: plus de 3 issues")
    s = 0
    for oi, o in enumerate(outs):
        ow = f"{where}/issue{oi}"
        s += o.get("chance", 1)
        check_text(o.get("text"), ow)
        check_effects(o.get("effects"), ow)
        for k in o:
            if k not in ("chance", "text", "effects"):
                err(f"{ow}: champ inconnu {k}")
    if abs(s - 1) > 0.011:
        err(f"{where}: somme des chances = {s}")


def check_age(o, where, lo=11, hi=17):
    a, b = o.get("minAge"), o.get("maxAge")
    if not isinstance(a, int) or not isinstance(b, int) or not (lo <= a <= b <= hi):
        err(f"{where}: âges invalides ({a}-{b}), il faut {lo} ≤ minAge ≤ maxAge ≤ {hi}")


def check_scene(s, where, ages=True):
    check_id(s.get("id"), where)
    for k in s:
        if k not in ("id", "minAge", "maxAge", "weight", "unique", "conditions", "text", "choices"):
            err(f"{where}: champ inconnu {k}")
    if ages:
        check_age(s, where)
    check_conditions(s.get("conditions"), where)
    check_text(s.get("text"), where)
    ch = s.get("choices")
    if not isinstance(ch, list) or not (2 <= len(ch) <= 4):
        err(f"{where}: il faut 2 à 4 choix")
        return
    for ci, c in enumerate(ch):
        cw = f"{where}/choix{ci}"
        check_text(c.get("label"), cw)
        check_outcomes(c.get("outcomes"), cw)


def charger(dossier):
    out = []
    for f in sorted(glob.glob(os.path.join(BASE, dossier, "*.json"))):
        nom = f"{dossier}/{os.path.basename(f)}"
        try:
            data = json.load(open(f, encoding="utf-8"))
        except Exception as ex:
            err(f"{nom}: JSON invalide : {ex}")
            continue
        if not isinstance(data, list):
            err(f"{nom}: le fichier doit contenir un tableau")
            continue
        out += [(nom, x) for x in data]
    return out


def prefixe(i, p, where):
    if isinstance(i, str) and not i.startswith(p):
        err(f"{where}: l'id doit commencer par {p}")


def main():
    stats = {}
    for dossier, p in (("Situations", "scl_"), ("Convocations", "scv_")):
        n = 0
        for nom, s in charger(dossier):
            n += 1
            w = f"{nom}:{s.get('id')}"
            check_scene(s, w)
            prefixe(s.get("id"), p, w)
        stats[dossier] = n

    groupes = set()
    for nom, g in charger("Groupes"):
        w = f"{nom}:{g.get('id')}"
        check_id(g.get("id"), w)
        groupes.add(g.get("id"))
        if g.get("id") not in GROUPES:
            err(f"{w}: groupe inconnu (ajoutez-le aussi dans GROUPES ici et dans ScolRegles)")
        for k in ("nom", "icone", "description", "accepte", "refuse", "quitte"):
            check_text(g.get(k), f"{w}.{k}")
        r = g.get("requis")
        if r is not None and (r.get("stat") not in ("health", "happiness", "smarts", "looks", "karma", "popularity")
                              or not isinstance(r.get("min"), int)):
            err(f"{w}: requis invalide {r}")
        check_effects(g.get("parAn"), f"{w}.parAn")
    if groupes != GROUPES:
        err(f"Groupes: il faut exactement {sorted(GROUPES)}, trouvé {sorted(x for x in groupes if x)}")
    stats["groupes"] = len(groupes)

    n = 0
    for nom, a in charger("Actions"):
        n += 1
        w = f"{nom}:{a.get('id')}"
        check_id(a.get("id"), w)
        prefixe(a.get("id"), "sca_", w)
        for k in ("titre", "icone", "description"):
            check_text(a.get(k), f"{w}.{k}")
        if a.get("groupe") not in (None, *GROUPES):
            err(f"{w}: groupe inconnu {a.get('groupe')}")
        check_age(a, w)
        check_conditions(a.get("conditions"), w)
        check_outcomes(a.get("outcomes"), w)
    stats["actions"] = n

    n = 0
    for nom, v in charger("Voyages"):
        n += 1
        w = f"{nom}:{v.get('id')}"
        check_id(v.get("id"), w)
        prefixe(v.get("id"), "voy_", w)
        for k in ("destination", "intro", "retour"):
            check_text(v.get(k), f"{w}.{k}")
        if v.get("niveau") not in ("college", "lycee", "tous"):
            err(f"{w}: niveau invalide")
        if not isinstance(v.get("cout"), int) or v["cout"] < 0:
            err(f"{w}: cout invalide")
        sc = v.get("scenes") or []
        if len(sc) < 2:
            err(f"{w}: il faut au moins 2 scènes")
        for s in sc:
            sw = f"{w}/{s.get('id')}"
            check_scene(s, sw, ages=False)
            prefixe(s.get("id"), v.get("id", "") + "_", sw)
    stats["voyages"] = n

    n = {"francais": 0, "grand_oral": 0}
    for nom, o in charger("Oraux"):
        w = f"{nom}:{o.get('id')}"
        check_id(o.get("id"), w)
        ex = o.get("examen")
        if ex not in n:
            err(f"{w}: examen invalide {ex}")
            continue
        n[ex] += 1
        prefixe(o.get("id"), "orf_" if ex == "francais" else "ogo_", w)
        check_text(o.get("sujet"), f"{w}.sujet")
        check_text(o.get("intro"), f"{w}.intro")
        qs = o.get("questions") or []
        if len(qs) != 3:
            err(f"{w}: il faut exactement 3 questions")
        for qi, q in enumerate(qs):
            qw = f"{w}/q{qi}"
            check_text(q.get("question"), qw)
            rs = q.get("reponses") or []
            if not (3 <= len(rs) <= 4):
                err(f"{qw}: il faut 3 ou 4 réponses")
            if rs and max(r.get("points", 0) for r in rs) < 4:
                err(f"{qw}: aucune bonne réponse (4 ou 5 points)")
            for ri, r in enumerate(rs):
                check_text(r.get("text"), f"{qw}/r{ri}")
                check_text(r.get("reaction"), f"{qw}/r{ri}.reaction")
                if not isinstance(r.get("points"), int) or not 0 <= r["points"] <= 5:
                    err(f"{qw}/r{ri}: points de 0 à 5")
    stats["oraux"] = n

    compte = {}
    promesses = set()
    for nom, t in charger("Textes"):
        ty = t.get("type")
        w = f"{nom}:{ty}:{(t.get('text') or '')[:30]}"
        if ty not in TYPES:
            err(f"{w}: type inconnu")
            continue
        check_text(t.get("text"), w, ph={"prenom"})
        cle = ty
        if ty == "appreciation":
            if t.get("matiere") not in MATIERES or t.get("tranche") not in TRANCHES:
                err(f"{w}: matiere/tranche invalide")
            cle = f"appreciation:{t.get('matiere')}:{t.get('tranche')}"
        elif ty == "comportement":
            if t.get("trait") not in TRAITS:
                err(f"{w}: trait invalide {t.get('trait')}")
            cle = f"comportement:{t.get('trait')}"
        elif ty == "generale":
            if t.get("mention") not in MENTIONS:
                err(f"{w}: mention invalide")
            cle = f"generale:{t.get('mention')}"
        elif ty == "prof":
            if t.get("matiere") not in MATIERES - {"*"}:
                err(f"{w}: matiere invalide")
            cle = f"prof:{t.get('matiere')}"
        elif ty == "promesse":
            i = t.get("id")
            if not isinstance(i, str) or i in promesses:
                err(f"{w}: id de promesse manquant ou en double")
            promesses.add(i)
            check_text(t.get("discours"), w + ".discours", ph={"prenom"})
            if not isinstance(t.get("bonus"), int) or not -10 <= t["bonus"] <= 20:
                err(f"{w}: bonus de -10 à 20")
            if not isinstance(t.get("realiste"), bool):
                err(f"{w}: realiste true/false")
            if t.get("realiste") is False:
                check_text(t.get("bilan"), w + ".bilan", ph={"prenom"})
        compte[cle] = compte.get(cle, 0) + 1

    # Couverture minimale pour que le bulletin trouve toujours un texte.
    for tr in TRANCHES:
        if compte.get(f"appreciation:*:{tr}", 0) < 3:
            err(f"Textes: il faut au moins 3 appréciations matiere '*' tranche {tr}")
    for m in MENTIONS:
        if compte.get(f"generale:{m}", 0) < 3:
            err(f"Textes: il faut au moins 3 appréciations générales mention {m}")
    for m in MATIERES - {"*"}:
        if compte.get(f"prof:{m}", 0) < 1:
            err(f"Textes: aucun prof de {m}")
    for ty in ("colle", "adversaire", "delegue"):
        if compte.get(ty, 0) < 5:
            err(f"Textes: il faut au moins 5 textes de type {ty}")
    if len(promesses) < 4:
        err("Textes: il faut au moins 4 promesses")
    stats["textes"] = sum(compte.values())

    for e in errs[:300]:
        print("ERREUR", e)
    print(stats)
    print(f"{len(errs)} erreur(s)")
    sys.exit(1 if errs else 0)


if __name__ == "__main__":
    main()
