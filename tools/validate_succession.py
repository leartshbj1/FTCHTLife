#!/usr/bin/env python3
"""Vérifie les données du module Testament et guerre d'héritage (docs/SUCCESSION.md).

Usage : python3 tools/validate_succession.py
Code de sortie 1 s'il y a des erreurs.
"""
import json
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
DATA = RACINE / "FTCHTLife" / "Resources" / "Data"
SUC = DATA / "Succession"

PHASES = {"ouverture", "guerre", "suite"}
ROLES = {"seul", "favori", "egal", "desherite"}
BENEF = {"egal", "enfant", "partenaire", "chat", "oeuvre", "personne", "inconnu", "ami", "aucun"}
SUPPORTS = {"notaire", "papier", "serviette", "video", "tatouage", "aucun"}
LIENS = {"mere", "pere", "autre"}
COND_KEYS = {
    "roles", "beneficiaires", "supports", "liens", "minTension", "maxTension", "minPatrimoine",
    "maxPatrimoine", "dettes", "fratrie", "testament", "clauses", "flags", "excludeFlags",
    "minAge", "maxAge", "minHostilite", "maxHostilite", "enfants",
}
EFF_KEYS = {"happiness", "health", "smarts", "looks", "karma", "money", "moneyPct", "relationships", "rival", "death"}
REL_KEYS = {"mother", "father", "parent", "sibling", "friend", "partner", "child"}
ISSUE_KEYS = {"chance", "text", "effects", "next", "delay", "setFlags", "clearFlags", "close"}
EP_KEYS = {"id", "phase", "weight", "unique", "conditions", "text", "effects", "next", "delay", "setFlags", "close", "choices"}

VARS_MOTEUR = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e"}
VARS_EPISODE = VARS_MOTEUR | {
    "defunt", "le_defunt", "Le_defunt", "rival", "Rival", "rival_prenom", "frere", "bien", "patrimoine",
    "part", "beneficiaire", "chat", "oeuvre", "notaire",
}
VARS_CHRONIQUE = {
    "heritier", "enfant", "partenaire", "rival", "Rival", "bien", "patrimoine", "chat", "oeuvre", "notaire",
    "beneficiaire", "prenom", "e",
}

TAGS_MOTEUR = {
    "male", "female", "baby", "school", "university", "job", "adult", "unemployed", "retired", "rich", "poor",
    "friend", "mother", "father", "siblings", "partner", "children", "sick", "attractive", "smart",
}
TAGS_SUCCESSION = {"testament", "testament_secret", "testament_annonce", "heritier", "heritier_en_guerre",
                   "desherite", "a_herite_gros"} | {f"testament_{b}" for b in BENEF}

erreurs = []
avertissements = []


def err(f, msg):
    erreurs.append(f"{f}: {msg}")


def warn(f, msg):
    avertissements.append(f"{f}: {msg}")


def charger(dossier):
    out = []
    d = SUC / dossier
    if not d.exists():
        return out
    for p in sorted(d.glob("*.json")):
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
        except Exception as e:  # noqa: BLE001
            err(p.name, f"JSON invalide : {e}")
            continue
        if not isinstance(data, list):
            err(p.name, "le fichier doit contenir un tableau")
            continue
        out += [(p.name, x) for x in data]
    return out


def verifier_vars(f, ident, texte, permises):
    for v in re.findall(r"\{([^{}]+)\}", texte):
        if v.startswith("pct:"):
            if permises is VARS_CHRONIQUE or not re.fullmatch(r"pct:-?\d+", v):
                err(f, f"{ident}: variable invalide {{{v}}}")
            continue
        if v not in permises:
            err(f, f"{ident}: variable inconnue {{{v}}}")


def verifier_conditions(f, ident, c):
    if c is None:
        return
    if not isinstance(c, dict):
        err(f, f"{ident}: conditions doit être un objet")
        return
    for k in c:
        if k not in COND_KEYS:
            err(f, f"{ident}: condition inconnue « {k} »")
    for k, ok in (("roles", ROLES), ("beneficiaires", BENEF), ("supports", SUPPORTS), ("liens", LIENS)):
        for v in c.get(k) or []:
            if v not in ok:
                err(f, f"{ident}: valeur « {v} » invalide pour {k}")
    for k in ("minTension", "maxTension", "minPatrimoine", "maxPatrimoine", "minAge", "maxAge", "minHostilite", "maxHostilite"):
        if k in c and c[k] is not None and not isinstance(c[k], int):
            err(f, f"{ident}: {k} doit être un entier")
    for k in ("dettes", "fratrie", "testament", "enfants"):
        if k in c and c[k] is not None and not isinstance(c[k], bool):
            err(f, f"{ident}: {k} doit être true/false")


def verifier_effets(f, ident, e):
    if e is None:
        return
    if not isinstance(e, dict):
        err(f, f"{ident}: effects doit être un objet")
        return
    for k, v in e.items():
        if k not in EFF_KEYS:
            err(f, f"{ident}: effet inconnu « {k} »")
        elif k == "relationships":
            for r, d in v.items():
                if r not in REL_KEYS:
                    err(f, f"{ident}: relation inconnue « {r} »")
                if not isinstance(d, int):
                    err(f, f"{ident}: relationships.{r} doit être un entier")
        elif k == "death":
            if not isinstance(v, str):
                err(f, f"{ident}: death doit être un texte")
        elif k == "moneyPct":
            if not isinstance(v, (int, float)) or not -100 <= v <= 100:
                err(f, f"{ident}: moneyPct entre -100 et 100")
        elif not isinstance(v, int):
            err(f, f"{ident}: {k} doit être un entier")
        elif k in ("happiness", "health", "smarts", "looks", "karma") and abs(v) > 40:
            warn(f, f"{ident}: {k}={v} est énorme")


def verifier_suite(f, ident, obj, refs):
    for n in obj.get("next") or []:
        refs.append((f, ident, n))
    d = obj.get("delay")
    if d is not None:
        if not (isinstance(d, list) and len(d) == 2 and all(isinstance(x, int) for x in d) and 0 <= d[0] <= d[1] <= 10):
            err(f, f"{ident}: delay doit être [min, max] (0 à 10)")
        if not obj.get("next"):
            warn(f, f"{ident}: delay sans next")


episodes = charger("Episodes")
ids = {}
refs = []
par_phase = {p: 0 for p in PHASES}
for f, ep in episodes:
    ident = ep.get("id", "?")
    if not isinstance(ep, dict):
        err(f, "épisode qui n'est pas un objet")
        continue
    for k in ep:
        if k not in EP_KEYS:
            err(f, f"{ident}: champ inconnu « {k} »")
    if not isinstance(ident, str) or not ident.startswith("suc_"):
        err(f, f"{ident}: l'id doit commencer par suc_")
    if ident in ids:
        err(f, f"{ident}: id en double (déjà dans {ids[ident][0]})")
    ids[ident] = (f, ep)
    ph = ep.get("phase")
    if ph not in PHASES:
        err(f, f"{ident}: phase invalide « {ph} »")
    else:
        par_phase[ph] += 1
    texte = ep.get("text")
    if not isinstance(texte, str) or not texte.strip():
        err(f, f"{ident}: text manquant")
        texte = ""
    if len(texte) > 320:
        warn(f, f"{ident}: texte long ({len(texte)} caractères)")
    verifier_vars(f, ident, texte, VARS_EPISODE)
    cond = ep.get("conditions") or {}
    verifier_conditions(f, ident, ep.get("conditions"))
    verifier_effets(f, ident, ep.get("effects"))
    verifier_suite(f, ident, ep, refs)
    tout_texte = texte
    choix = ep.get("choices") or []
    if choix and (ep.get("effects") or ep.get("next")):
        err(f, f"{ident}: effects/next à la racine seulement sans choix")
    for i, c in enumerate(choix):
        if not isinstance(c.get("label"), str) or not c["label"].strip():
            err(f, f"{ident}: choix {i} sans label")
        elif len(c["label"]) > 60:
            warn(f, f"{ident}: label long « {c['label']} »")
        outs = c.get("outcomes") or []
        if not outs:
            err(f, f"{ident}: choix {i} sans issue")
        for k, o in enumerate(outs):
            oid = f"{ident}[{i}][{k}]"
            for key in o:
                if key not in ISSUE_KEYS:
                    err(f, f"{oid}: champ inconnu « {key} »")
            if not isinstance(o.get("text"), str) or not o["text"].strip():
                err(f, f"{oid}: text manquant")
            else:
                verifier_vars(f, oid, o["text"], VARS_EPISODE)
                tout_texte += o["text"]
            ch = o.get("chance")
            if ch is not None and (not isinstance(ch, (int, float)) or ch <= 0):
                err(f, f"{oid}: chance doit être > 0")
            verifier_effets(f, oid, o.get("effects"))
            verifier_suite(f, oid, o, refs)
    if "{frere}" in tout_texte and cond.get("fratrie") is not True:
        err(f, f"{ident}: utilise {{frere}} sans \"fratrie\": true")
    if "{oeuvre}" in tout_texte and cond.get("beneficiaires") and "oeuvre" not in cond["beneficiaires"]:
        warn(f, f"{ident}: {{oeuvre}} sans bénéficiaire oeuvre")
    if ph == "ouverture" and ep.get("unique"):
        warn(f, f"{ident}: une ouverture unique peut manquer pour un 2e dossier")

references = set()
for f, ident, n in refs:
    references.add(n)
    if n not in ids:
        err(f, f"{ident}: next vers un épisode inexistant « {n} »")
    elif ids[n][1].get("phase") != "suite":
        err(f, f"{ident}: next vers « {n} » qui n'est pas en phase suite")
for ident, (f, ep) in ids.items():
    if ep.get("phase") == "suite" and ident not in references:
        warn(f, f"{ident}: suite jamais programmée par un next")

# Couverture : chaque situation doit avoir au moins une ouverture.
ouvertures = [ep for _, ep in episodes if ep.get("phase") == "ouverture"]
COMBOS = {
    "seul": ("egal", "aucun", "enfant"),
    "favori": ("enfant",),
    "egal": ("egal", "aucun"),
    "desherite": ("enfant", "partenaire", "chat", "oeuvre", "personne", "inconnu", "ami"),
}
for role, benefs in COMBOS.items():
    for benef in benefs:
        for dettes in (False, True):
            ok = False
            for ep in ouvertures:
                c = ep.get("conditions") or {}
                if c.get("roles") and role not in c["roles"]:
                    continue
                if c.get("beneficiaires") and benef not in c["beneficiaires"]:
                    continue
                if c.get("dettes") is not None and c["dettes"] != dettes:
                    continue
                if c.get("fratrie") is not None or c.get("flags") or c.get("minTension") or c.get("minPatrimoine") \
                        or c.get("supports") or c.get("liens") or c.get("clauses") or c.get("testament") is not None \
                        or c.get("minAge") or c.get("maxAge") or c.get("maxTension") is not None or c.get("maxPatrimoine") is not None:
                    continue
                ok = True
                break
            if episodes and not ok:
                warn("Episodes", f"pas d'ouverture sans condition fine pour rôle={role} bénéficiaire={benef} dettes={dettes}")

# Clauses et œuvres
clauses = charger("Clauses")
cids = set()
for f, c in clauses:
    i = c.get("id")
    if not isinstance(i, str) or not i.startswith("cla_"):
        err(f, f"clause {i}: id doit commencer par cla_")
    if i in cids:
        err(f, f"clause {i}: id en double")
    cids.add(i)
    if not isinstance(c.get("texte"), str) or not c["texte"].strip():
        err(f, f"clause {i}: texte manquant")
    elif len(c["texte"]) > 90:
        warn(f, f"clause {i}: texte long")
    d = c.get("drame")
    if d is not None and (not isinstance(d, int) or not 0 <= d <= 3):
        err(f, f"clause {i}: drame entre 0 et 3")
    for k in c:
        if k not in {"id", "texte", "drame", "reaction"}:
            err(f, f"clause {i}: champ inconnu « {k} »")

for f, ep in episodes:
    for cl in (ep.get("conditions") or {}).get("clauses") or []:
        if cl not in cids:
            err(f, f"{ep.get('id')}: clause inconnue « {cl} »")

oeuvres = charger("Oeuvres")
oids = set()
for f, o in oeuvres:
    i = o.get("id")
    if not isinstance(i, str) or not i.startswith("oeu_"):
        err(f, f"œuvre {i}: id doit commencer par oeu_")
    if i in oids:
        err(f, f"œuvre {i}: id en double")
    oids.add(i)
    if not isinstance(o.get("nom"), str) or not o["nom"].strip():
        err(f, f"œuvre {i}: nom manquant")
    for k in o:
        if k not in {"id", "nom"}:
            err(f, f"œuvre {i}: champ inconnu « {k} »")

chroniques = charger("Chroniques")
chids = set()
for f, c in chroniques:
    i = c.get("id")
    if not isinstance(i, str) or not i.startswith("chr_"):
        err(f, f"chronique {i}: id doit commencer par chr_")
    if i in chids:
        err(f, f"chronique {i}: id en double")
    chids.add(i)
    for k in c:
        if k not in {"id", "weight", "conditions", "text"}:
            err(f, f"chronique {i}: champ inconnu « {k} »")
    if not isinstance(c.get("text"), str) or not c["text"].strip():
        err(f, f"chronique {i}: text manquant")
    else:
        verifier_vars(f, i, c["text"], VARS_CHRONIQUE)
        cond = c.get("conditions") or {}
        if "{enfant}" in c["text"] or "{heritier}" in c["text"]:
            if cond.get("enfants") is not True and not (cond.get("beneficiaires") and set(cond["beneficiaires"]) <= {"enfant", "egal"}):
                err(f, f"chronique {i}: {{enfant}}/{{heritier}} demande \"enfants\": true")
        if "{partenaire}" in c["text"] and cond.get("beneficiaires") != ["partenaire"]:
            warn(f, f"chronique {i}: {{partenaire}} sans bénéficiaire partenaire (remplacé par « ton ex » si absent)")
    verifier_conditions(f, i, c.get("conditions"))
    for cl in (c.get("conditions") or {}).get("clauses") or []:
        if cl not in cids:
            err(f, f"chronique {i}: clause inconnue « {cl} »")

# Événements classiques liés au testament
for p in sorted((DATA / "Events").glob("testament_*.json")):
    try:
        evs = json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:  # noqa: BLE001
        err(p.name, f"JSON invalide : {e}")
        continue
    for ev in evs:
        i = ev.get("id", "?")
        if not str(i).startswith("tes_"):
            err(p.name, f"{i}: l'id doit commencer par tes_")
        c = ev.get("conditions") or {}
        for t in (c.get("tags") or []) + (c.get("excludeTags") or []):
            if t not in TAGS_MOTEUR | TAGS_SUCCESSION:
                err(p.name, f"{i}: tag inconnu « {t} »")
        textes = [ev.get("text", "")]
        for ch in ev.get("choices") or []:
            textes += [o.get("text", "") for o in ch.get("outcomes") or []]
            for o in ch.get("outcomes") or []:
                for k, v in (o.get("effects") or {}).items():
                    if k not in {"happiness", "health", "smarts", "looks", "karma", "money", "stress", "fame",
                                 "relationships", "newFriend", "death"}:
                        err(p.name, f"{i}: effet inconnu « {k} »")
                    elif k in {"happiness", "health", "smarts", "looks", "karma", "money", "stress", "fame"} and not isinstance(v, int):
                        err(p.name, f"{i}: {k} doit être un entier")
        for t in textes:
            verifier_vars(p.name, i, t, VARS_MOTEUR)
        for k in ("minAge", "maxAge", "text"):
            if k not in ev:
                err(p.name, f"{i}: champ {k} manquant")

for a in avertissements:
    print("⚠️ ", a)
for e in erreurs:
    print("❌", e)
print(f"Épisodes : {len(episodes)} ({', '.join(f'{k} {v}' for k, v in sorted(par_phase.items()))}) · "
      f"clauses : {len(clauses)} · œuvres : {len(oeuvres)} · chroniques : {len(chroniques)}")
print("OK" if not erreurs else f"{len(erreurs)} erreur(s)")
sys.exit(1 if erreurs else 0)
