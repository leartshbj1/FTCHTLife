#!/usr/bin/env python3
"""Vérifie les données du module Voisinage (FTCHTLife/Resources/Data/Voisinage).

Usage : python3 tools/validate_voisinage.py
Code de sortie 1 si une erreur est trouvée.
"""
import json
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent / "FTCHTLife" / "Resources" / "Data" / "Voisinage"

LOGEMENTS = {"appartement", "maison", "villa", "campagne", "caravane"}
STATUTS = {"neutre", "ami", "ennemi", "amour"}
GENRES = {"any", "male", "female"}
TRAITS = {"bruit", "curiosite", "gentillesse"}

EFFETS = {"happiness", "health", "smarts", "looks", "karma", "money", "stress", "fame",
          "relationships", "newFriend", "death", "setFlags", "clearFlags", "followUps"}
REL = {"mother", "father", "parent", "sibling", "friend", "partner", "child"}
COND = {"gender", "minMoney", "maxMoney", "requiresJob", "requiresPartner", "requiresSchool",
        "tags", "excludeTags", "flags", "excludeFlags"}
QUARTIER = {"logements", "chezParents", "proprietaire", "president", "minAmbiance", "maxAmbiance",
            "drapeaux", "sansDrapeaux", "minCompteurs", "minAnnees"}
CIBLE = {"archetypes", "statuts", "minLien", "maxLien", "celibataire", "gender", "opposite",
         "minAge", "maxAge", "souvenirs", "sansSouvenirs"}
VEFFET = {"lien", "statut", "souvenir", "oublie", "demenage", "meurt", "devientAmi", "devientPartenaire",
          "lienTous", "ambiance", "drapeaux", "retireDrapeaux", "compteurs", "president", "charges",
          "travaux", "signaux"}
EVT = {"id", "minAge", "maxAge", "weight", "unique", "conditions", "quartier", "cible", "text",
       "effects", "voisin", "choices"}
ISSUE = {"chance", "text", "effects", "voisin"}
IISSUE = {"chance", "trait", "sens", "bonusLien", "text", "effects", "voisin"}
INTER = {"id", "titre", "icone", "description", "portee", "minAge", "maxAge", "cout", "cible",
         "quartier", "conditions", "outcomes"}
ARCH = {"id", "titreM", "titreF", "description", "logements", "ageMin", "ageMax", "gender", "weight",
        "bruit", "curiosite", "gentillesse", "celibat", "phrases"}

VARS = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e",
        "voisin", "voisin_nom", "voisin_complet", "voisin_qui", "voisin_age", "il", "Il", "lui", "ve",
        "emplacement", "quartier", "adresse", "syndic"}
VOISIN_VARS = {"voisin", "voisin_nom", "voisin_complet", "voisin_qui", "voisin_age", "il", "Il", "lui", "ve", "emplacement"}

erreurs = []


def err(f, i, msg):
    erreurs.append(f"{f}:{i}: {msg}")


def is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


REQUIS = {
    "archétype": {"id", "titreM", "titreF", "description", "logements", "ageMin", "ageMax", "bruit", "curiosite",
                  "gentillesse", "phrases"},
    "interaction": {"id", "titre", "icone", "description", "portee", "minAge", "outcomes"},
    "événement": {"id", "minAge", "maxAge", "text"},
    "issue": {"text"},
    "choix": {"label", "outcomes"},
}


def check_keys(f, i, obj, allowed, nom):
    if not isinstance(obj, dict):
        err(f, i, f"{nom} doit être un objet")
        return False
    for k in obj:
        if k not in allowed:
            err(f, i, f"{nom} : clé inconnue « {k} »")
    for k in REQUIS.get(nom, set()) - set(obj):
        err(f, i, f"{nom} : clé obligatoire manquante « {k} »")
    for k, v in obj.items():
        if v is None and k in REQUIS.get(nom, set()):
            err(f, i, f"{nom} : « {k} » ne peut pas être null")
    return True


def check_text(f, i, t, a_cible):
    if not isinstance(t, str) or not t.strip():
        err(f, i, "texte vide")
        return
    for v in re.findall(r"\{([^}]*)\}", t):
        if v not in VARS:
            err(f, i, f"variable inconnue {{{v}}}")
        elif v in VOISIN_VARS and not a_cible:
            err(f, i, f"{{{v}}} utilisé sans « cible » (aucun voisin choisi)")


def check_effets(f, i, e):
    if e is None:
        return
    if not check_keys(f, i, e, EFFETS, "effects"):
        return
    for k, v in e.items():
        if k in {"happiness", "health", "smarts", "looks", "karma", "money", "stress", "fame"} and not is_int(v):
            err(f, i, f"effects.{k} doit être un entier")
        if k == "relationships":
            for rk, rv in v.items():
                if rk not in REL or not is_int(rv):
                    err(f, i, f"relationships.{rk} invalide")


def check_cond(f, i, c):
    if c is None:
        return
    if check_keys(f, i, c, COND, "conditions"):
        if "gender" in c and c["gender"] not in GENRES:
            err(f, i, "conditions.gender invalide")


def check_quartier(f, i, q):
    if q is None:
        return
    if check_keys(f, i, q, QUARTIER, "quartier"):
        for l in q.get("logements", []) or []:
            if l not in LOGEMENTS:
                err(f, i, f"logement inconnu {l}")


def check_cible(f, i, c, archetypes):
    if c is None:
        return
    if check_keys(f, i, c, CIBLE, "cible"):
        for a in c.get("archetypes", []) or []:
            if a not in archetypes:
                err(f, i, f"archétype inconnu {a}")
        for s in c.get("statuts", []) or []:
            if s not in STATUTS:
                err(f, i, f"statut inconnu {s}")
        if "gender" in c and c["gender"] not in GENRES:
            err(f, i, "cible.gender invalide")


def check_veffet(f, i, v, a_cible):
    if v is None:
        return
    if not check_keys(f, i, v, VEFFET, "voisin"):
        return
    if "statut" in v and v["statut"] not in STATUTS:
        err(f, i, f"statut inconnu {v['statut']}")
    for k in ("lien", "lienTous", "ambiance", "charges"):
        if k in v and not is_int(v[k]):
            err(f, i, f"voisin.{k} doit être un entier")
    voisin_seul = {"lien", "statut", "souvenir", "oublie", "demenage", "meurt", "devientAmi", "devientPartenaire"}
    if not a_cible and voisin_seul & set(v):
        err(f, i, f"effet sur un voisin ({', '.join(sorted(voisin_seul & set(v)))}) sans « cible »")


def charger(dossier):
    fichiers = sorted((RACINE / dossier).glob("*.json"))
    for p in fichiers:
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
        except Exception as e:  # noqa: BLE001
            erreurs.append(f"{p.name}: JSON invalide : {e}")
            continue
        if not isinstance(data, list):
            erreurs.append(f"{p.name}: le fichier doit contenir un tableau")
            continue
        yield p.name, data


def main():
    ids = set()
    archetypes = {}
    for f, data in charger("Archetypes"):
        for i, a in enumerate(data):
            if not check_keys(f, i, a, ARCH, "archétype"):
                continue
            aid = a.get("id")
            if aid in archetypes:
                err(f, i, f"archétype en double {aid}")
            archetypes[aid] = a
            for k in ("titreM", "titreF", "description"):
                if not a.get(k):
                    err(f, i, f"{k} manquant")
            for l in a.get("logements", []):
                if l not in LOGEMENTS:
                    err(f, i, f"logement inconnu {l}")
            for k in ("bruit", "curiosite", "gentillesse", "ageMin", "ageMax"):
                if not is_int(a.get(k)):
                    err(f, i, f"{k} doit être un entier")
            if len(a.get("phrases", [])) < 3:
                err(f, i, "au moins 3 phrases d'ambiance")
            for t in a.get("phrases", []):
                check_text(f, i, t, True)

    n_inter = 0
    for f, data in charger("Interactions"):
        for i, it in enumerate(data):
            n_inter += 1
            if not check_keys(f, i, it, INTER, "interaction"):
                continue
            if it.get("id") in ids:
                err(f, i, f"id en double {it.get('id')}")
            ids.add(it.get("id"))
            if it.get("portee") not in ("voisin", "quartier"):
                err(f, i, "portee doit être « voisin » ou « quartier »")
            a_cible = it.get("portee") == "voisin"
            check_cible(f, i, it.get("cible"), archetypes)
            check_quartier(f, i, it.get("quartier"))
            check_cond(f, i, it.get("conditions"))
            if not it.get("outcomes"):
                err(f, i, "outcomes vide")
            for o in it.get("outcomes", []):
                if check_keys(f, i, o, IISSUE, "issue"):
                    check_text(f, i, o.get("text"), a_cible)
                    check_effets(f, i, o.get("effects"))
                    check_veffet(f, i, o.get("voisin"), a_cible)
                    if "trait" in o and o["trait"] not in TRAITS:
                        err(f, i, f"trait inconnu {o['trait']}")
                    if "sens" in o and o["sens"] not in ("haut", "bas"):
                        err(f, i, "sens doit être « haut » ou « bas »")

    n_evt = 0
    for f, data in charger("Evenements"):
        for i, e in enumerate(data):
            n_evt += 1
            if not check_keys(f, i, e, EVT, "événement"):
                continue
            eid = e.get("id", "")
            if not re.fullmatch(r"vsn_[a-z]{3}_\d{4}", eid or ""):
                err(f, i, f"id « {eid} » : format vsn_xxx_0000 attendu")
            if eid in ids:
                err(f, i, f"id en double {eid}")
            ids.add(eid)
            if not is_int(e.get("minAge")) or not is_int(e.get("maxAge")) or e["minAge"] > e["maxAge"]:
                err(f, i, "minAge/maxAge invalides")
            a_cible = "cible" in e
            check_cond(f, i, e.get("conditions"))
            check_quartier(f, i, e.get("quartier"))
            check_cible(f, i, e.get("cible"), archetypes)
            check_text(f, i, e.get("text"), a_cible)
            check_effets(f, i, e.get("effects"))
            check_veffet(f, i, e.get("voisin"), a_cible)
            choix = e.get("choices") or []
            if not choix and not e.get("effects") and not e.get("voisin"):
                err(f, i, "ni choix ni effets")
            for c in choix:
                if not check_keys(f, i, c, {"label", "outcomes"}, "choix"):
                    continue
                if not c.get("label"):
                    err(f, i, "choix sans label")
                if not c.get("outcomes"):
                    err(f, i, "choix sans issue")
                for o in c.get("outcomes", []):
                    if check_keys(f, i, o, ISSUE, "issue"):
                        check_text(f, i, o.get("text"), a_cible)
                        check_effets(f, i, o.get("effects"))
                        check_veffet(f, i, o.get("voisin"), a_cible)

    # Cohérence : archétypes ciblés qui peuvent vivre dans les logements de l'événement,
    # drapeaux et souvenirs exigés qui sont posés quelque part.
    poses_drapeaux, poses_souvenirs = set(), set()
    exiges = []
    for dossier in ("Evenements", "Interactions"):
        for f, data in charger(dossier):
            for i, e in enumerate(data):
                if not isinstance(e, dict):
                    continue
                issues = [e] + [o for c in (e.get("choices") or []) if isinstance(c, dict) for o in c.get("outcomes", [])] + list(e.get("outcomes") or [])
                for o in issues:
                    v = o.get("voisin") or {}
                    poses_drapeaux.update(v.get("drapeaux") or [])
                    poses_souvenirs.update(v.get("souvenir") or [])
                q = e.get("quartier") or {}
                c = e.get("cible") or {}
                for d in q.get("drapeaux") or []:
                    exiges.append((f, i, "drapeau", d))
                for d in c.get("souvenirs") or []:
                    exiges.append((f, i, "souvenir", d))
                logs = set(q.get("logements") or LOGEMENTS)
                arch = c.get("archetypes")
                if arch and all(not (set(archetypes.get(a, {}).get("logements", [])) & logs) for a in arch):
                    err(f, i, f"aucun des archétypes {arch} ne vit dans {sorted(logs)}")
    for f, i, genre, nom in exiges:
        if (genre == "drapeau" and nom not in poses_drapeaux) or (genre == "souvenir" and nom not in poses_souvenirs):
            err(f, i, f"{genre} « {nom} » exigé mais jamais posé")

    for e in erreurs:
        print("❌", e)
    print(f"{len(archetypes)} archétypes, {n_inter} interactions, {n_evt} événements, {len(erreurs)} erreur(s).")
    sys.exit(1 if erreurs else 0)


if __name__ == "__main__":
    main()
