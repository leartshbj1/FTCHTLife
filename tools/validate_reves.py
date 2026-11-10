#!/usr/bin/env python3
"""Vérifie le catalogue des rêves de vie et leurs événements occasion.

Usage : python3 tools/validate_reves.py [--marks] [--stats]
Format : docs/reves-format.md
"""
import json
import re
import sys
from collections import Counter
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
DATA = RACINE / "FTCHTLife" / "Resources" / "Data"
DOSSIER_REVES = DATA / "Dreams"
DOSSIER_EVENTS = DATA / "Events"

NIVEAUX = {"serieux", "ambitieux", "absurde"}
CLES_REVE = {"id", "level", "title", "description", "achievedText", "failedText", "happiness", "points",
             "weight", "gender", "requires", "deadlineAge", "conditions", "marks"}
OBLIGATOIRES = {"id", "level", "title", "description", "achievedText"}
REQUIRES = {"mother", "father", "siblings", "friend"}
DIPLOMES = {"aucun", "ecoleObligatoire", "bac", "licence", "master", "doctorat"}
FILIERES = {"medecine", "droit", "informatique", "commerce", "arts", "sciences"}
COND_INT = {"minMoney", "maxMoney", "minJobLevel", "minJobYears", "minSalary", "minAge", "minChildren", "minFriends",
            "minHappiness", "maxHappiness", "minHealth", "maxHealth", "minSmarts", "maxSmarts",
            "minLooks", "maxLooks", "minKarma", "maxKarma"}
COND_BOOL = {"unemployed", "partner"}
COND_LISTE = {"jobs", "jobTitleContains", "seenEvents"}
COND_STR = {"minDiploma", "diplomaField"}
COND_TOUTES = COND_INT | COND_BOOL | COND_LISTE | COND_STR

TAGS_MOTEUR = {"male", "female", "baby", "school", "university", "job", "adult", "unemployed", "retired", "rich",
               "poor", "friend", "mother", "father", "siblings", "partner", "children", "sick", "attractive", "smart"}
EFFETS = {"happiness", "health", "smarts", "looks", "karma", "money", "stress", "fame", "relationships",
          "newFriend", "death", "dreamMarks"}
CLES_EVENT = {"id", "category", "minAge", "maxAge", "weight", "unique", "conditions", "text", "effects", "choices"}
CLES_COND_EVENT = {"gender", "minMoney", "maxMoney", "requiresJob", "requiresPartner", "requiresSchool",
                   "tags", "excludeTags"}
VARIABLES = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e"}
VARIABLES_REVE = {"prenom", "nom", "ville", "mere", "pere", "fratrie", "e"}

erreurs = []
avertissements = []


def err(ou, msg):
    erreurs.append(f"{ou} : {msg}")


def warn(ou, msg):
    avertissements.append(f"{ou} : {msg}")


def metiers_moteur():
    src = (RACINE / "FTCHTLife" / "Models" / "Donnees.swift").read_text(encoding="utf-8")
    return set(re.findall(r'Metier\(id: "([a-z_]+)"', src))


def verifier_texte(ou, texte, permises):
    if not isinstance(texte, str) or not texte.strip():
        err(ou, "texte vide")
        return
    for v in re.findall(r"\{([^}]*)\}", texte):
        if v not in permises:
            err(ou, f"variable inconnue {{{v}}}")
    if re.search(r"\w\{e\}\w", texte):
        err(ou, "{e} au milieu d'un mot")


def verifier_effets(ou, eff, marques_posees):
    if not isinstance(eff, dict):
        err(ou, "effects doit être un objet")
        return
    for k, v in eff.items():
        if k not in EFFETS:
            err(ou, f"effet inconnu « {k} »")
        elif k == "dreamMarks":
            if not isinstance(v, list) or not all(isinstance(x, str) and x for x in v):
                err(ou, "dreamMarks doit être une liste de textes")
            else:
                marques_posees.update(v)


def charger(fichier):
    try:
        data = json.loads(fichier.read_text(encoding="utf-8"))
    except Exception as e:  # noqa: BLE001
        err(fichier.name, f"JSON invalide ({e})")
        return []
    if not isinstance(data, list):
        err(fichier.name, "le fichier doit contenir un tableau")
        return []
    return data


def main():
    metiers = metiers_moteur()
    reves = {}
    marques_attendues = {}
    for f in sorted(DOSSIER_REVES.glob("*.json")):
        for i, r in enumerate(charger(f)):
            ou = f"{f.name}[{i}] {r.get('id', '?') if isinstance(r, dict) else '?'}"
            if not isinstance(r, dict):
                err(ou, "un rêve doit être un objet")
                continue
            for k in r:
                if k not in CLES_REVE:
                    err(ou, f"clé inconnue « {k} »")
            for k in OBLIGATOIRES:
                if k not in r:
                    err(ou, f"clé obligatoire manquante « {k} »")
            rid = r.get("id")
            if not isinstance(rid, str) or not re.fullmatch(r"reve_[a-z0-9_]+", rid or ""):
                err(ou, "id doit ressembler à reve_xxx (minuscules, chiffres, _)")
            elif rid in reves:
                err(ou, f"id en double (déjà dans {reves[rid][0]})")
            if r.get("level") not in NIVEAUX:
                err(ou, f"level doit être {sorted(NIVEAUX)}")
            for k in ("title", "description", "achievedText"):
                if k in r:
                    verifier_texte(f"{ou}.{k}", r[k], VARIABLES_REVE)
            if r.get("failedText") is not None:
                verifier_texte(f"{ou}.failedText", r["failedText"], VARIABLES_REVE)
                if r.get("deadlineAge") is None:
                    warn(ou, "failedText sans deadlineAge (jamais affiché)")
            if isinstance(r.get("title"), str) and len(r["title"]) > 48:
                warn(ou, f"titre long ({len(r['title'])} caractères)")
            for k in ("happiness", "points"):
                v = r.get(k)
                if v is not None and (not isinstance(v, int) or not 0 <= v <= 100):
                    err(ou, f"{k} doit être un entier 0-100")
            if r.get("weight") is not None and (not isinstance(r["weight"], (int, float)) or r["weight"] <= 0):
                err(ou, "weight doit être > 0")
            if r.get("gender", "any") not in (None, "any", "male", "female"):
                err(ou, "gender doit être any, male ou female")
            for q in r.get("requires") or []:
                if q not in REQUIRES:
                    err(ou, f"requires inconnu « {q} » (permis : {sorted(REQUIRES)})")
            d = r.get("deadlineAge")
            if d is not None and (not isinstance(d, int) or not 17 <= d <= 120):
                err(ou, "deadlineAge doit être un entier entre 17 et 120")
            cond = r.get("conditions")
            if cond is not None:
                if not isinstance(cond, dict):
                    err(ou, "conditions doit être un objet")
                    cond = None
                else:
                    for k, v in cond.items():
                        if k not in COND_TOUTES:
                            err(ou, f"condition inconnue « {k} »")
                        elif v is None:
                            continue
                        elif k in COND_INT and not isinstance(v, int):
                            err(ou, f"{k} doit être un entier")
                        elif k in COND_BOOL and not isinstance(v, bool):
                            err(ou, f"{k} doit être true/false")
                        elif k in COND_LISTE and (not isinstance(v, list) or not v
                                                  or not all(isinstance(x, str) and x for x in v)):
                            err(ou, f"{k} doit être une liste de textes non vide")
                        elif k == "minDiploma" and v not in DIPLOMES:
                            err(ou, f"minDiploma inconnu « {v} »")
                        elif k == "diplomaField" and v not in FILIERES:
                            err(ou, f"diplomaField inconnu « {v} »")
                    for m in cond.get("jobs") or []:
                        if m not in metiers:
                            warn(ou, f"métier « {m} » absent du moteur (ok s'il vient du module métiers)")
                    if d is not None and cond.get("minAge") is not None and cond["minAge"] > d:
                        err(ou, "minAge > deadlineAge : impossible")
                    if not any(v is not None for v in cond.values()):
                        cond = None
            marks = r.get("marks") or []
            if not isinstance(marks, list) or not all(isinstance(x, str) and x for x in marks):
                err(ou, "marks doit être une liste de textes")
                marks = []
            if isinstance(rid, str):
                reves[rid] = (f.name, r, cond is not None)
                marques_attendues[rid] = set(marks) | {rid}

    # Événements occasion
    marques_posees = set()
    tags_utilises = Counter()
    occasions_par_reve = Counter()
    ids_events = {}
    nb_occ = 0
    for f in sorted(DOSSIER_EVENTS.glob("*.json")):
        evts = charger(f)
        for i, e in enumerate(evts):
            if not isinstance(e, dict):
                continue
            eid = e.get("id")
            if eid in ids_events:
                err(f"{f.name}[{i}] {eid}", f"id d'événement en double (déjà dans {ids_events[eid]})")
            ids_events[eid] = f.name
            if not f.name.startswith("reves_"):
                # On relève seulement les marques posées ailleurs.
                for c in e.get("choices") or []:
                    for o in c.get("outcomes") or []:
                        if isinstance(o.get("effects"), dict):
                            marques_posees.update(o["effects"].get("dreamMarks") or [])
                if isinstance(e.get("effects"), dict):
                    marques_posees.update(e["effects"].get("dreamMarks") or [])
                continue
            nb_occ += 1
            ou = f"{f.name}[{i}] {eid}"
            for k in e:
                if k not in CLES_EVENT:
                    err(ou, f"clé inconnue « {k} »")
            for k in ("id", "minAge", "maxAge", "text"):
                if k not in e:
                    err(ou, f"clé obligatoire manquante « {k} »")
            if not isinstance(eid, str) or not eid.startswith("reve_occ_"):
                err(ou, "id doit commencer par reve_occ_")
            mi, ma = e.get("minAge"), e.get("maxAge")
            if not isinstance(mi, int) or not isinstance(ma, int) or mi > ma:
                err(ou, "minAge/maxAge invalides")
            elif ma < 16:
                err(ou, "maxAge < 16 : les rêves sont tirés à 16 ans")
            verifier_texte(f"{ou}.text", e.get("text"), VARIABLES)
            c = e.get("conditions") or {}
            for k in c:
                if k not in CLES_COND_EVENT:
                    err(ou, f"condition inconnue « {k} »")
            tags = c.get("tags") or []
            reves_tags = [t for t in tags if t.startswith("reve_")]
            for t in tags + (c.get("excludeTags") or []):
                if t.startswith("reve_"):
                    if t not in reves:
                        err(ou, f"tag « {t} » : aucun rêve avec cet id")
                elif t not in TAGS_MOTEUR:
                    err(ou, f"tag inconnu « {t} »")
            if not reves_tags:
                warn(ou, "aucun tag reve_* : l'événement arrive à tout le monde")
            for t in reves_tags:
                tags_utilises[t] += 1
            marques_evt = set()
            choix = e.get("choices")
            if not choix:
                if "effects" not in e:
                    warn(ou, "ni choix ni effets")
                else:
                    verifier_effets(ou, e["effects"], marques_evt)
            else:
                for ci, ch in enumerate(choix):
                    if not isinstance(ch.get("label"), str) or not ch["label"].strip():
                        err(f"{ou}.choices[{ci}]", "label manquant")
                    outs = ch.get("outcomes") or []
                    if not outs:
                        err(f"{ou}.choices[{ci}]", "aucune issue")
                    for oi, o in enumerate(outs):
                        ou2 = f"{ou}.choices[{ci}].outcomes[{oi}]"
                        verifier_texte(ou2, o.get("text"), VARIABLES)
                        if o.get("chance") is not None and (not isinstance(o["chance"], (int, float)) or o["chance"] <= 0):
                            err(ou2, "chance doit être > 0")
                        if "effects" in o:
                            verifier_effets(ou2, o["effects"], marques_evt)
            marques_posees.update(marques_evt)
            for t in reves_tags:
                if marques_evt & marques_attendues.get(t, set()):
                    occasions_par_reve[t] += 1

    # Chaque rêve doit pouvoir être réalisé.
    for rid, (fichier, r, a_cond) in reves.items():
        if not a_cond and not (marques_attendues[rid] & marques_posees) and not (r.get("marks")):
            err(f"{fichier} {rid}", "impossible à réaliser : ni conditions, ni marks, ni événement qui pose sa marque")
        elif not a_cond and not (marques_attendues[rid] & marques_posees):
            warn(f"{fichier} {rid}", f"réalisable seulement par une marque d'un autre module : {sorted(r.get('marks') or [])}")

    for a in avertissements:
        print("⚠️ ", a)
    for e in erreurs:
        print("❌", e)
    niveaux = Counter(r.get("level") for _, r, _ in reves.values())
    print(f"\n{len(reves)} rêves ({', '.join(f'{n} {k}' for k, n in sorted(niveaux.items()))}), "
          f"{nb_occ} événements occasion, {len(erreurs)} erreur(s), {len(avertissements)} avertissement(s).")
    if "--marks" in sys.argv:
        toutes = sorted({m for rid, (_, r, _) in reves.items() for m in (r.get("marks") or [])})
        print("Marques attendues par le catalogue :", ", ".join(toutes) or "aucune")
    if "--stats" in sys.argv:
        for rid in sorted(reves):
            print(f"  {rid}: {occasions_par_reve[rid]} occasion(s) gagnante(s), conditions={'oui' if reves[rid][2] else 'non'}")
    sys.exit(1 if erreurs else 0)


if __name__ == "__main__":
    main()
