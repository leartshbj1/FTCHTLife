#!/usr/bin/env python3
"""Valide les événements de réputation familiale (Data/Events/famille_reputation_*.json).
Mêmes règles que les événements classiques, plus la clé d'effet familyRep, la variable {ancetre}
et les tags famille_*. Usage : python3 tools/validate_reputation_famille.py [fichiers...]"""
import json, sys, glob, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATS = {"happiness", "health", "smarts", "looks", "money", "karma", "stress", "fame"}
REL = {"mother", "father", "parent", "sibling", "friend", "partner", "child"}
AXES = {"respected", "mafia", "ridiculous", "cursed", "famous"}
FAM_TAGS = {"famille_sans_histoire", "heritier"}
for a in ["respectee", "mafieuse", "ridicule", "maudite", "celebre"]:
    FAM_TAGS |= {f"famille_{a}", f"famille_{a}_legendaire"}
TAGS = {"male", "female", "baby", "school", "university", "job", "adult", "unemployed", "retired", "rich", "poor",
        "friend", "mother", "father", "siblings", "partner", "children", "sick", "attractive", "smart"} | FAM_TAGS
SPECIAL = {"death", "newFriend", "relationships", "setFlags", "clearFlags", "familyRep"}
PH = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e", "ancetre"}
COND = {"gender", "minMoney", "maxMoney", "requiresJob", "requiresPartner", "requiresSchool", "tags", "excludeTags",
        "flags", "excludeFlags"}
# Variable de personne -> condition requise
NEEDS = {"mere": "mother", "pere": "father", "fratrie": "siblings", "ami": "friend"}


def check_effects(e, where, errs):
    if not isinstance(e, dict):
        errs.append(f"{where}: effects pas un objet"); return
    for k, v in e.items():
        if k in STATS:
            if not isinstance(v, (int, float)): errs.append(f"{where}: {k} non numérique")
            elif k != "money" and abs(v) > 100: errs.append(f"{where}: {k} hors bornes")
        elif k == "relationships":
            if not isinstance(v, dict) or any(r not in REL for r in v): errs.append(f"{where}: relationships invalide {v}")
        elif k == "familyRep":
            if not isinstance(v, dict) or not v: errs.append(f"{where}: familyRep invalide"); continue
            for a, d in v.items():
                if a not in AXES: errs.append(f"{where}: axe familyRep inconnu {a}")
                elif not isinstance(d, int) or abs(d) > 40: errs.append(f"{where}: familyRep.{a} doit être un entier entre -40 et 40")
        elif k not in SPECIAL:
            errs.append(f"{where}: clé d'effet inconnue {k}")


def placeholders(t):
    return re.findall(r"\{(\w+)\}", t) if isinstance(t, str) else []


def check_text(t, where, errs):
    if not isinstance(t, str) or not t.strip():
        errs.append(f"{where}: texte vide"); return
    for p in placeholders(t):
        if p not in PH: errs.append(f"{where}: placeholder inconnu {{{p}}}")


def main():
    files = sys.argv[1:] or sorted(glob.glob(os.path.join(ROOT, "FTCHTLife/Resources/Data/Events/famille_reputation_*.json")))
    all_events = sorted(glob.glob(os.path.join(ROOT, "FTCHTLife/Resources/Data/Events/*.json")))
    ids_ailleurs = {}
    for f in all_events:
        if f in files: continue
        try:
            for ev in json.load(open(f, encoding="utf-8")): ids_ailleurs[ev.get("id")] = os.path.basename(f)
        except Exception:
            pass
    ids, errs, n, par_tag = {}, [], 0, {}
    for f in files:
        try: data = json.load(open(f, encoding="utf-8"))
        except Exception as ex: errs.append(f"{f}: JSON invalide: {ex}"); continue
        if not isinstance(data, list): errs.append(f"{f}: pas un tableau"); continue
        for ev in data:
            n += 1
            i = ev.get("id", "?"); w = f"{os.path.basename(f)}:{i}"
            for k in ("id", "category", "minAge", "maxAge", "weight", "text", "choices"):
                if k not in ev: errs.append(f"{w}: champ manquant {k}")
            if not str(i).startswith("fam_"): errs.append(f"{w}: l'id doit commencer par fam_")
            if i in ids: errs.append(f"{w}: id dupliqué (aussi dans {ids[i]})")
            if i in ids_ailleurs: errs.append(f"{w}: id déjà pris dans {ids_ailleurs[i]}")
            ids[i] = os.path.basename(f)
            if not (0 <= ev.get("minAge", 0) <= ev.get("maxAge", 0) <= 120): errs.append(f"{w}: âges invalides")
            cond = ev.get("conditions") or {}
            for k in cond:
                if k not in COND: errs.append(f"{w}: condition inconnue {k}")
                elif k in ("tags", "excludeTags"):
                    for t in cond[k] or []:
                        if t not in TAGS: errs.append(f"{w}: tag inconnu {t}")
            tags = set(cond.get("tags") or [])
            fam = [t for t in tags if t in FAM_TAGS]
            for t in fam: par_tag[t] = par_tag.get(t, 0) + 1
            if not fam and not (set(cond.get("excludeTags") or []) & FAM_TAGS):
                errs.append(f"{w}: un événement de réputation doit exiger ou exclure un tag famille_*")
            textes = [ev.get("text")]
            check_text(ev.get("text"), w, errs)
            ch = ev.get("choices", [])
            if not ch:
                check_effects(ev.get("effects", {}), w, errs)
            if len(ch) > 4: errs.append(f"{w}: plus de 4 choix")
            for ci, c in enumerate(ch):
                cw = f"{w}/choix{ci}"; check_text(c.get("label"), cw, errs); textes.append(c.get("label"))
                outs = c.get("outcomes") or []
                if not outs: errs.append(f"{cw}: aucun outcome")
                s = sum(o.get("chance", 0) for o in outs)
                if abs(s - 1) > 0.011: errs.append(f"{cw}: somme des chances = {s}")
                for oi, o in enumerate(outs):
                    check_text(o.get("text"), f"{cw}/o{oi}", errs); textes.append(o.get("text"))
                    check_effects(o.get("effects", {}), f"{cw}/o{oi}", errs)
            used = {p for t in textes for p in placeholders(t)}
            for p, tag in NEEDS.items():
                if p in used and tag not in tags: errs.append(f"{w}: {{{p}}} exige le tag {tag}")
            if "partenaire" in used and cond.get("requiresPartner") is not True and "partner" not in tags:
                errs.append(f"{w}: {{partenaire}} exige requiresPartner")
            if "metier" in used and cond.get("requiresJob") is not True and "job" not in tags:
                errs.append(f"{w}: {{metier}} exige requiresJob")
    for e in errs[:200]: print("ERREUR", e)
    print(f"{n} événements de réputation, {len(files)} fichiers, {len(errs)} erreurs")
    for t in sorted(par_tag): print(f"  {t}: {par_tag[t]}")
    sys.exit(1 if errs else 0)


if __name__ == "__main__":
    main()
