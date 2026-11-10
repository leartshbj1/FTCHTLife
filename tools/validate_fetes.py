#!/usr/bin/env python3
"""Vérifie les fêtes de l'année (format : docs/FETES.md).

  FTCHTLife/Resources/Data/FetesCalendrier/*.json  : le calendrier des fêtes
  FTCHTLife/Resources/Data/Fetes/*.json            : les variantes (format des événements)

Usage : python3 tools/validate_fetes.py [--couverture]
Code de sortie 1 s'il y a des erreurs. Les avertissements n'échouent pas.
"""
import collections
import glob
import json
import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(RACINE, "FTCHTLife", "Resources", "Data")

STATS = {"happiness", "health", "smarts", "looks", "money", "karma", "stress", "fame"}
REL = {"mother", "father", "parent", "sibling", "friend", "partner", "child"}
TAGS = {"male", "female", "baby", "school", "university", "job", "adult", "unemployed", "retired", "rich", "poor",
        "friend", "mother", "father", "siblings", "partner", "children", "sick", "attractive", "smart"}
EFFETS_SPECIAUX = {"relationships", "newFriend", "death", "setFlags", "clearFlags"}
VARIABLES = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e"}
CONDITIONS = {"gender", "minMoney", "maxMoney", "requiresJob", "requiresPartner", "requiresSchool", "tags",
              "excludeTags", "flags", "excludeFlags"}
RE_ID = re.compile(r"^fet_[a-z]{3}_\d{4}$")
RE_FLAG = re.compile(r"^fete_[a-z0-9_]+$")

# Variable de personne -> condition qui garantit que la personne existe.
EXIGE = {
    "mere": ("tag", "mother"), "pere": ("tag", "father"), "fratrie": ("tag", "siblings"),
    "ami": ("tag", "friend"), "partenaire": ("partner", None), "metier": ("job", None),
}
# Clé de relationships -> condition qui garantit que l'effet touche quelqu'un.
REL_EXIGE = {
    "mother": ("tag", "mother"), "father": ("tag", "father"), "sibling": ("tag", "siblings"),
    "friend": ("tag", "friend"), "partner": ("partner", None), "child": ("tag", "children"),
}


def garanti(cond, exigence):
    tags = set(cond.get("tags") or [])
    sorte, tag = exigence
    if sorte == "tag":
        return tag in tags
    if sorte == "partner":
        return cond.get("requiresPartner") is True or "partner" in tags
    if sorte == "job":
        return cond.get("requiresJob") is True or "job" in tags
    return True


def main():
    erreurs, avert = [], []
    couverture = "--couverture" in sys.argv

    # Calendrier
    cal = []
    for f in sorted(glob.glob(os.path.join(DATA, "FetesCalendrier", "*.json"))):
        try:
            cal += json.load(open(f, encoding="utf-8"))
        except Exception as ex:
            erreurs.append(f"{f} : JSON invalide : {ex}")
    fetes = {}
    for c in cal:
        for k in ("id", "nom", "emoji", "mois"):
            if k not in c:
                erreurs.append(f"calendrier {c.get('id')} : champ manquant {k}")
        if c.get("id") in fetes:
            erreurs.append(f"calendrier : id dupliqué {c.get('id')}")
        fetes[c.get("id")] = c

    # Variantes
    variantes, ids, textes = [], {}, {}
    for f in sorted(glob.glob(os.path.join(DATA, "Fetes", "*.json"))):
        nom = os.path.basename(f)
        try:
            data = json.load(open(f, encoding="utf-8"))
        except Exception as ex:
            erreurs.append(f"{nom} : JSON invalide : {ex}")
            continue
        if not isinstance(data, list):
            erreurs.append(f"{nom} : doit être un tableau")
            continue
        for ev in data:
            ev["_fichier"] = nom
            variantes.append(ev)

    flags_poses, flags_exiges, flags_retires = collections.defaultdict(list), collections.defaultdict(list), set()

    for ev in variantes:
        i = ev.get("id", "?")
        w = f"{ev['_fichier']}:{i}"
        for k in ("id", "category", "minAge", "maxAge", "weight", "text", "choices"):
            if k not in ev:
                erreurs.append(f"{w} : champ manquant {k}")
        if not RE_ID.match(str(i)):
            erreurs.append(f"{w} : id attendu fet_xxx_NNNN")
        if i in ids:
            erreurs.append(f"{w} : id dupliqué (aussi dans {ids[i]})")
        ids[i] = ev["_fichier"]
        if ev.get("category") not in fetes:
            erreurs.append(f"{w} : category « {ev.get('category')} » absente du calendrier")
        mi, ma = ev.get("minAge", 0), ev.get("maxAge", 0)
        if not (isinstance(mi, int) and isinstance(ma, int) and 0 <= mi <= ma <= 120):
            erreurs.append(f"{w} : âges invalides")
        cond = ev.get("conditions") or {}
        for k, v in cond.items():
            if k not in CONDITIONS:
                erreurs.append(f"{w} : condition inconnue {k}")
            elif k in ("tags", "excludeTags"):
                for t in v or []:
                    if t not in TAGS:
                        erreurs.append(f"{w} : tag inconnu {t}")
            elif k in ("flags", "excludeFlags"):
                for fl in v or []:
                    if not RE_FLAG.match(fl):
                        erreurs.append(f"{w} : drapeau « {fl} » : attendu fete_…")
                    if k == "flags":
                        flags_exiges[fl].append(i)
            elif k == "gender" and v not in (None, "any", "male", "female"):
                erreurs.append(f"{w} : gender invalide")

        def texte(t, ou):
            if not isinstance(t, str) or not t.strip():
                erreurs.append(f"{ou} : texte vide")
                return
            for p in re.findall(r"\{([^}]*)\}", t):
                if p not in VARIABLES:
                    erreurs.append(f"{ou} : variable inconnue {{{p}}}")
                elif p in EXIGE and not garanti(cond, EXIGE[p]):
                    erreurs.append(f"{ou} : {{{p}}} exige la condition {EXIGE[p]}")

        def effets(e, ou):
            if not isinstance(e, dict):
                erreurs.append(f"{ou} : effects doit être un objet")
                return
            for k, v in e.items():
                if k in STATS:
                    if not isinstance(v, int) or isinstance(v, bool):
                        erreurs.append(f"{ou} : {k} doit être un entier")
                    elif k != "money" and abs(v) > 40:
                        avert.append(f"{ou} : {k} = {v}, gros effet")
                    if k == "money" and isinstance(v, int) and v < 0 and mi < 16:
                        erreurs.append(f"{ou} : argent négatif pour une variante accessible avant 16 ans")
                elif k == "relationships":
                    if not isinstance(v, dict):
                        erreurs.append(f"{ou} : relationships doit être un objet")
                        continue
                    for r, d in v.items():
                        if r not in REL:
                            erreurs.append(f"{ou} : relation inconnue {r}")
                        elif not isinstance(d, int):
                            erreurs.append(f"{ou} : relationships.{r} doit être un entier")
                        elif r in REL_EXIGE and not garanti(cond, REL_EXIGE[r]):
                            erreurs.append(f"{ou} : relationships.{r} exige la condition {REL_EXIGE[r]}")
                elif k in ("setFlags", "clearFlags"):
                    for fl in v:
                        if not RE_FLAG.match(fl):
                            erreurs.append(f"{ou} : drapeau « {fl} » : attendu fete_…")
                        if k == "setFlags":
                            flags_poses[fl].append(i)
                        else:
                            flags_retires.add(fl)
                elif k == "newFriend" and not isinstance(v, bool):
                    erreurs.append(f"{ou} : newFriend doit être true/false")
                elif k == "death" and not isinstance(v, str):
                    erreurs.append(f"{ou} : death doit être un texte")
                elif k not in STATS | EFFETS_SPECIAUX:
                    erreurs.append(f"{ou} : effet inconnu {k}")

        texte(ev.get("text"), w)
        cle = (ev.get("text") or "").strip().lower()
        if cle in textes:
            erreurs.append(f"{w} : même texte que {textes[cle]}")
        textes[cle] = i
        ch = ev.get("choices") or []
        if not ch:
            avert.append(f"{w} : pas de choix (une fête doit proposer un petit choix)")
            effets(ev.get("effects") or {}, w)
        if len(ch) > 4:
            erreurs.append(f"{w} : plus de 4 choix")
        for ci, c in enumerate(ch):
            cw = f"{w}/choix{ci}"
            texte(c.get("label"), cw)
            if len(c.get("label") or "") > 40:
                avert.append(f"{cw} : label long ({len(c['label'])} caractères)")
            outs = c.get("outcomes") or []
            if not outs:
                erreurs.append(f"{cw} : aucune issue")
            s = sum(o.get("chance", 1) for o in outs)
            if abs(s - 1) > 0.011:
                erreurs.append(f"{cw} : somme des chances = {s}")
            for oi, o in enumerate(outs):
                texte(o.get("text"), f"{cw}/issue{oi}")
                effets(o.get("effects") or {}, f"{cw}/issue{oi}")
        if cond.get("flags") and not ev.get("unique"):
            for fl in cond["flags"]:
                tous = all(fl in ((o.get("effects") or {}).get("clearFlags") or [])
                           for c in ch for o in c.get("outcomes") or [])
                if not tous:
                    avert.append(f"{w} : souvenir « {fl} » jamais effacé dans certaines issues (risque de répétition)")

    for fl, qui in flags_exiges.items():
        if fl not in flags_poses:
            erreurs.append(f"drapeau « {fl} » exigé par {qui} mais jamais posé")
    for fl, qui in flags_poses.items():
        if fl not in flags_exiges:
            avert.append(f"drapeau « {fl} » posé par {qui} mais aucune variante ne s'en souvient")

    # Statistiques
    par_fete = collections.Counter(ev.get("category") for ev in variantes)
    for fid in fetes:
        if par_fete[fid] == 0:
            avert.append(f"fête « {fid} » sans variante")
    jalons = sorted(ev["minAge"] for ev in variantes if ev.get("minAge") == ev.get("maxAge"))

    # Couverture : fêtes possibles à chaque âge pour un joueur sans partenaire, sans emploi, sans frère ni sœur.
    def possible_sans_rien(ev, age):
        if not (ev["minAge"] <= age <= ev["maxAge"]) or ev.get("conditions", {}).get("flags"):
            return False
        c = ev.get("conditions") or {}
        t = set(c.get("tags") or []) - {"male", "female", "mother", "father", "baby", "school", "adult", "retired"}
        return not t and c.get("requiresPartner") is not True and c.get("requiresJob") is not True and not c.get("minMoney")
    trous = []
    for age in range(0, 101):
        n = {ev["category"] for ev in variantes if possible_sans_rien(ev, age)}
        if couverture:
            print(f"{age:3d} ans : {len(n):2d} fêtes  {' '.join(sorted(n))}")
        if len(n) < 3:
            trous.append(age)
    if trous:
        avert.append(f"âges avec moins de 3 fêtes possibles (joueur seul) : {trous}")

    for a in avert[:80]:
        print("ATTENTION", a)
    for e in erreurs[:200]:
        print("ERREUR", e)
    print(f"{len(fetes)} fêtes, {len(variantes)} variantes, {len(jalons)} anniversaires marquants "
          f"({', '.join(map(str, sorted(set(jalons))))}), {len(flags_exiges)} souvenirs")
    print("Par fête : " + ", ".join(f"{k} {par_fete[k]}" for k in fetes))
    print(f"{len(erreurs)} erreurs, {len(avert)} avertissements")
    sys.exit(1 if erreurs else 0)


if __name__ == "__main__":
    main()
