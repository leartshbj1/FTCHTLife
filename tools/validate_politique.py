#!/usr/bin/env python3
"""Vérifie les données de la carrière politique (FTCHTLife/Resources/Data/Politique).

Usage : python3 tools/validate_politique.py
Format : docs/POLITIQUE.md
"""
import json
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent / "FTCHTLife" / "Resources" / "Data" / "Politique"

POSTES = {"militant", "conseiller", "adjoint", "maire", "depute", "ministre", "president", "any"}
KINDS = {"dossier", "scandale", "debat", "campagne", "militant"}
PREFIXES = {"dossier": "dos_", "scandale": "sca_", "debat": "deb_", "campagne": "cam_", "militant": "mil_"}
EFFETS = {"happiness", "health", "smarts", "looks", "karma", "money", "stress", "fame",
          "relationships", "newFriend", "death"}
RELATIONS = {"mother", "father", "parent", "sibling", "friend", "partner", "child"}
POL = {"popularite", "influence", "casseroles", "loyaute", "caisse", "parrainages", "campagne",
       "finMandat", "ineligibilite", "loi", "abroger", "exclusionParti"}
VARIABLES = {"prenom", "nom", "ville", "e", "parti", "poste", "adversaire", "ministere",
             "mere", "pere", "partenaire", "ami"}
CLES_PRIX = {"immobilier", "voitures", "bateaux", "avions", "bijoux", "voyages", "nourriture", "tech",
             "luxe", "animaux", "sante", "etudes", "loisirs", "vetements", "tout"}
CLES_SALAIRES = {"restauration", "commerce", "transport", "batiment", "beaute", "securite", "administration",
                 "medias", "immobilier", "tech", "finance", "arts", "science", "education", "droit", "sante",
                 "sport", "politique", "tout"}
CLES_REGLES = {"prison", "amendes", "impots", "retraite", "ageRetraite", "permis", "mortalite", "fertilite",
               "etudes", "chomage", "loyer", "elections", "mandatsIllimites", "popularite", "casino", "animaux",
               "bonheur", "sante"}

erreurs = []


def err(fichier, msg):
    erreurs.append(f"{fichier}: {msg}")


def verifier_texte(f, ou, t):
    if not isinstance(t, str) or not t.strip():
        err(f, f"{ou}: texte vide")
        return
    for v in re.findall(r"\{([^}]*)\}", t):
        if v not in VARIABLES:
            err(f, f"{ou}: variable inconnue {{{v}}}")
    if "{e}" in t and re.search(r"(eux|if|al|aux|eur)\{e\}", t):
        err(f, f"{ou}: accord {{e}} douteux (« …eux{{e}} », « …if{{e}} »…), réécris la phrase")


def verifier_effets(f, ou, e):
    if e is None:
        return
    if not isinstance(e, dict):
        err(f, f"{ou}: effects doit être un objet")
        return
    for k, v in e.items():
        if k not in EFFETS:
            err(f, f"{ou}: clé d'effet inconnue « {k} »")
        elif k == "relationships":
            for r in v:
                if r not in RELATIONS:
                    err(f, f"{ou}: relation inconnue « {r} »")
        elif k in ("newFriend",):
            if not isinstance(v, bool):
                err(f, f"{ou}: {k} doit être true/false")
        elif k == "death":
            if not isinstance(v, str):
                err(f, f"{ou}: death doit être un texte")
        elif not isinstance(v, int):
            err(f, f"{ou}: {k} doit être un entier")
    for k in ("happiness", "health", "smarts", "looks", "karma"):
        if isinstance(e.get(k), int) and abs(e[k]) > 40:
            err(f, f"{ou}: {k}={e[k]} trop fort (max ±40)")


def verifier_pol(f, ou, p, ids_lois):
    if p is None:
        return
    if not isinstance(p, dict):
        err(f, f"{ou}: pol doit être un objet")
        return
    for k, v in p.items():
        if k not in POL:
            err(f, f"{ou}: clé pol inconnue « {k} »")
        elif k in ("finMandat",):
            if not isinstance(v, str):
                err(f, f"{ou}: finMandat doit être un texte (la raison)")
        elif k in ("loi", "abroger"):
            if v not in ids_lois:
                err(f, f"{ou}: loi inconnue « {v} »")
        elif k == "exclusionParti":
            if not isinstance(v, bool):
                err(f, f"{ou}: exclusionParti doit être true/false")
        elif k == "campagne":
            if not isinstance(v, (int, float)):
                err(f, f"{ou}: campagne doit être un nombre")
        elif not isinstance(v, int):
            err(f, f"{ou}: {k} doit être un entier")
    for k in ("popularite", "influence", "casseroles", "loyaute"):
        if isinstance(p.get(k), int) and abs(p[k]) > 40:
            err(f, f"{ou}: {k}={p[k]} trop fort (max ±40)")


def charger(dossier):
    res = []
    d = RACINE / dossier
    for fichier in sorted(d.glob("*.json")):
        try:
            data = json.loads(fichier.read_text(encoding="utf-8"))
        except Exception as ex:  # noqa: BLE001
            err(fichier.name, f"JSON invalide : {ex}")
            continue
        if not isinstance(data, list):
            err(fichier.name, "le fichier doit contenir un tableau")
            continue
        for o in data:
            res.append((fichier.name, o))
    return res


def main():
    ids = set()
    partis = charger("Partis")
    for f, p in partis:
        for k in ("id", "nom", "sigle", "slogan", "description", "couleur", "bord", "bonusElection", "cotisation"):
            if k not in p:
                err(f, f"parti sans {k}")
    ministeres = charger("Ministeres")
    ids_min = {m.get("id") for _, m in ministeres}

    lois = charger("Lois")
    ids_lois = {l.get("id") for _, l in lois}
    for f, l in lois:
        i = l.get("id", "?")
        if i in ids:
            err(f, f"id en double {i}")
        ids.add(i)
        for k in ("id", "niveau", "titre", "description", "difficulte", "headline", "texteAdoption", "texteRejet"):
            if k not in l:
                err(f, f"{i}: champ manquant {k}")
        if l.get("niveau") not in ("municipal", "national"):
            err(f, f"{i}: niveau doit être municipal ou national")
        pref = "mun_" if l.get("niveau") == "municipal" else "nat_"
        if not i.startswith(pref):
            err(f, f"{i}: l'id doit commencer par {pref}")
        if l.get("monde") is not None and not re.fullmatch(r"mon_\d{4}", str(l["monde"])):
            err(f, f"{i}: monde doit être un id de flash mon_NNNN")
        if l.get("ministere") is not None and l["ministere"] not in ids_min:
            err(f, f"{i}: ministère inconnu {l['ministere']}")
        d = l.get("difficulte")
        if not isinstance(d, int) or not 0 <= d <= 100:
            err(f, f"{i}: difficulte entre 0 et 100")
        for k in ("titre", "description", "headline", "texteAdoption", "texteRejet"):
            if k in l:
                verifier_texte(f, f"{i}.{k}", l[k])
        verifier_pol(f, f"{i}.adoption", l.get("adoption"), ids_lois)
        verifier_effets(f, f"{i}.annuel", l.get("annuel"))
        for k, v in (l.get("prix") or {}).items():
            if k not in CLES_PRIX:
                err(f, f"{i}: clé de prix inconnue {k}")
            if not isinstance(v, (int, float)) or not 0.2 <= v <= 3:
                err(f, f"{i}: multiplicateur de prix {k} hors de 0.2-3")
        for k, v in (l.get("salaires") or {}).items():
            if k not in CLES_SALAIRES:
                err(f, f"{i}: secteur de salaire inconnu {k}")
            if not isinstance(v, (int, float)) or not 0.2 <= v <= 3:
                err(f, f"{i}: multiplicateur de salaire {k} hors de 0.2-3")
        for k in (l.get("regles") or {}):
            if k not in CLES_REGLES:
                err(f, f"{i}: règle inconnue {k} (voir docs/POLITIQUE.md)")
        a = l.get("annuel") or {}
        if isinstance(a.get("money"), int) and abs(a["money"]) > 5000:
            err(f, f"{i}: argent annuel trop fort (max ±5000)")

    dossiers = charger("Dossiers")
    for f, d in dossiers:
        i = d.get("id", "?")
        if i in ids:
            err(f, f"id en double {i}")
        ids.add(i)
        for k in ("id", "kind", "postes", "title", "text", "choices"):
            if k not in d:
                err(f, f"{i}: champ manquant {k}")
        kind = d.get("kind")
        if kind not in KINDS:
            err(f, f"{i}: kind inconnu {kind}")
        elif not i.startswith(PREFIXES[kind]):
            err(f, f"{i}: l'id d'un {kind} doit commencer par {PREFIXES[kind]}")
        postes = d.get("postes") or []
        if not postes:
            err(f, f"{i}: postes vide")
        for p in postes:
            if p not in POSTES:
                err(f, f"{i}: poste inconnu {p}")
        if d.get("ministere") is not None and d["ministere"] not in ids_min:
            err(f, f"{i}: ministère inconnu {d['ministere']}")
        verifier_texte(f, f"{i}.title", d.get("title"))
        verifier_texte(f, f"{i}.text", d.get("text"))
        choix = d.get("choices") or []
        if not 2 <= len(choix) <= 4:
            err(f, f"{i}: il faut 2 à 4 choix")
        for n, c in enumerate(choix):
            verifier_texte(f, f"{i}.choix{n}.label", c.get("label"))
            outs = c.get("outcomes") or []
            if not outs:
                err(f, f"{i}.choix{n}: aucune issue")
            for m, o in enumerate(outs):
                ou = f"{i}.choix{n}.issue{m}"
                verifier_texte(f, ou, o.get("text"))
                ch = o.get("chance", 1)
                if not isinstance(ch, (int, float)) or ch <= 0:
                    err(f, f"{ou}: chance doit être > 0")
                verifier_effets(f, ou, o.get("effects"))
                verifier_pol(f, ou, o.get("pol"), ids_lois)
                if not o.get("effects") and not o.get("pol"):
                    err(f, f"{ou}: une issue sans aucun effet")

    from collections import Counter
    comptes = Counter(d.get("kind") for _, d in dossiers)
    niveaux = Counter(l.get("niveau") for _, l in lois)
    print(f"Partis : {len(partis)}, ministères : {len(ministeres)}, lois : {len(lois)} {dict(niveaux)}, "
          f"dossiers : {len(dossiers)} {dict(comptes)}")
    if erreurs:
        print(f"\n{len(erreurs)} erreur(s) :")
        for e in erreurs[:200]:
            print(" -", e)
        sys.exit(1)
    print("OK")


if __name__ == "__main__":
    main()
