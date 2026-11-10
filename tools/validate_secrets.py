#!/usr/bin/env python3
"""Vérifie les données du module Secrets (docs/SECRETS.md).

Usage : python3 tools/validate_secrets.py
Code de sortie 1 s'il y a des erreurs.
"""
import json
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent / "FTCHTLife" / "Resources" / "Data" / "Secrets"

PORTEURS = {"mere", "pere", "frere", "soeur", "ami", "partenaire", "enfant", "ex", "joueur"}
BLESSE = {"partenaire", "parent", "mere", "pere", "fratrie", "frere", "soeur", "ami", "enfant", "ex"}
VARIABLES = {
    "cible", "Cible", "designation", "Designation", "il", "Il", "le", "eC", "heC",
    "complice", "eX", "montant", "resume", "titre",
    "prenom", "nom", "ville", "e", "mere", "pere", "partenaire",
}
CLES_TEXTES = {
    "fouille_rien", "fouille_pris", "garder", "dire_bien", "dire_mal", "reveler_soi",
    "chantage_refus_aveu", "chantage_refus_denonce", "chantage_versement", "chantage_revolte",
    "chantage_fin", "taire", "proche_se_tait", "proche_chantage", "proche_augmente", "payer",
    "paiement_annuel", "refuser", "avouer", "contre_ok", "contre_rate", "pas_les_moyens",
    "chanteur_mort", "victime_morte",
}
SIGNAUX_CONNUS = {
    "tromperie", "prison_sortie", "faillite", "addiction", "casino_ruine", "casino_triche",
    "chirurgie_esthetique", "faux_permis_achete", "crime_reussi", "abandon_etudes", "licenciement",
}
CHAMPS_MODELE = {
    "id", "titre", "gravite", "porteurs", "minAge", "maxAge", "genre", "poids", "complice", "blesse",
    "signalRevelation", "signaux", "seulementSignal", "resume", "indices", "decouvertes", "revelations",
    "chantages", "resumeJoueur", "naissances", "demasques", "revelationsJoueur",
}
TEXTES_PROCHE = {"resume": 1, "indices": 2, "decouvertes": 2, "revelations": 2, "chantages": 1}
TEXTES_JOUEUR = {"resumeJoueur": 1, "naissances": 1, "demasques": 1, "revelationsJoueur": 1}
CHAMPS_MOMENT = {"id", "porteurs", "minAge", "maxAge", "multiplicateur", "texte", "resultats"}

erreurs = []
avertissements = []


def err(ou, msg):
    erreurs.append(f"{ou} : {msg}")


def charger(dossier):
    elements = []
    d = RACINE / dossier
    if not d.is_dir():
        err(dossier, "dossier absent")
        return elements
    for f in sorted(d.glob("*.json")):
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            err(f.name, f"JSON invalide : {e}")
            continue
        if not isinstance(data, list):
            err(f.name, "le fichier doit contenir un tableau")
            continue
        for x in data:
            elements.append((f.name, x))
    return elements


def verifier_texte(ou, t, autorise_complice=True):
    if not isinstance(t, str) or not t.strip():
        err(ou, "texte vide ou pas une chaîne")
        return
    for v in re.findall(r"\{([^{}]*)\}", t):
        if v not in VARIABLES:
            err(ou, f"variable inconnue {{{v}}}")
        if v in ("complice", "eX") and not autorise_complice:
            err(ou, f"{{{v}}} utilisé sans \"complice\": true")
    if t.count("{") != t.count("}"):
        err(ou, "accolades déséquilibrées")
    if "—" in t:
        avertissements.append(f"{ou} : tiret cadratin")


def liste_textes(ou, m, cle, minimum, complice):
    v = m.get(cle)
    if cle in ("resume", "resumeJoueur"):
        if not isinstance(v, str):
            err(ou, f"{cle} manquant")
            return
        verifier_texte(f"{ou}.{cle}", v, complice)
        return
    if not isinstance(v, list) or len(v) < minimum:
        err(ou, f"{cle} : au moins {minimum} texte(s)")
        return
    for i, t in enumerate(v):
        verifier_texte(f"{ou}.{cle}[{i}]", t, complice)


def main():
    ids = set()
    modeles = charger("Modeles")
    for f, m in modeles:
        ou = f"{f}:{m.get('id', '?')}"
        if not isinstance(m, dict):
            err(f, "élément qui n'est pas un objet")
            continue
        for k in m:
            if k not in CHAMPS_MODELE:
                err(ou, f"champ inconnu « {k} »")
        i = m.get("id")
        if not isinstance(i, str) or not re.fullmatch(r"sec_\d{4}", i):
            err(ou, "id doit être sec_NNNN")
        elif i in ids:
            err(ou, "id en double")
        ids.add(i)
        if not isinstance(m.get("titre"), str) or not m["titre"].strip():
            err(ou, "titre manquant")
        g = m.get("gravite")
        if not isinstance(g, int) or not 1 <= g <= 5:
            err(ou, "gravite doit être un entier de 1 à 5")
        porteurs = m.get("porteurs")
        if not isinstance(porteurs, list) or not porteurs:
            err(ou, "porteurs manquant")
            porteurs = []
        for p in porteurs:
            if p not in PORTEURS:
                err(ou, f"porteur inconnu « {p} »")
        for k in ("minAge", "maxAge"):
            if m.get(k) is not None and not isinstance(m[k], int):
                err(ou, f"{k} doit être un entier")
        if m.get("genre") not in (None, "any", "male", "female"):
            err(ou, "genre : any, male ou female")
        if m.get("poids") is not None and not isinstance(m["poids"], (int, float)):
            err(ou, "poids doit être un nombre")
        for b in m.get("blesse") or []:
            if b not in BLESSE:
                err(ou, f"blesse : type inconnu « {b} »")
        for s in m.get("signaux") or []:
            if s not in SIGNAUX_CONNUS:
                avertissements.append(f"{ou} : signal « {s} » absent de la liste connue")
        complice = m.get("complice") is True
        proche = any(p != "joueur" for p in porteurs)
        joueur = "joueur" in porteurs
        if proche:
            for cle, n in TEXTES_PROCHE.items():
                liste_textes(ou, m, cle, n, complice)
        if joueur:
            for cle, n in TEXTES_JOUEUR.items():
                liste_textes(ou, m, cle, n, complice)
            if m.get("seulementSignal") and not m.get("signaux"):
                err(ou, "seulementSignal sans signaux")
        tout = json.dumps(m, ensure_ascii=False)
        if complice and "{complice}" not in tout:
            avertissements.append(f"{ou} : complice true mais {{complice}} jamais utilisé")
        if not proche and any(m.get(k) for k in TEXTES_PROCHE):
            avertissements.append(f"{ou} : textes de proche inutiles (pas de porteur proche)")
        if not joueur and any(m.get(k) for k in TEXTES_JOUEUR):
            avertissements.append(f"{ou} : textes du joueur inutiles (joueur pas porteur)")
        if proche and (m.get("minAge") or 0) < 18 and any(
                w in tout.lower() for w in ("liaison", "amant", "maîtresse", "prison", "dette")):
            avertissements.append(f"{ou} : thème adulte avec minAge < 18 ?")

    ids_moments = set()
    for f, m in charger("Moments"):
        ou = f"{f}:{m.get('id', '?')}"
        for k in m:
            if k not in CHAMPS_MOMENT:
                err(ou, f"champ inconnu « {k} »")
        i = m.get("id")
        if not isinstance(i, str) or not re.fullmatch(r"mom_\d{4}", i):
            err(ou, "id doit être mom_NNNN")
        elif i in ids_moments:
            err(ou, "id en double")
        ids_moments.add(i)
        for p in m.get("porteurs") or []:
            if p not in PORTEURS - {"joueur"}:
                err(ou, f"porteur invalide « {p} »")
        if not m.get("porteurs"):
            err(ou, "porteurs manquant")
        mult = m.get("multiplicateur")
        if mult is not None and (not isinstance(mult, (int, float)) or not 1 <= mult <= 3):
            err(ou, "multiplicateur entre 1 et 3")
        verifier_texte(f"{ou}.texte", m.get("texte"), False)
        if not isinstance(m.get("resultats"), list) or not m["resultats"]:
            err(ou, "resultats : au moins 1 texte")
        for k, t in enumerate(m.get("resultats") or []):
            verifier_texte(f"{ou}.resultats[{k}]", t, False)

    cles = {}
    for f, t in charger("Textes"):
        ou = f"{f}:{t.get('cle', '?')}"
        if set(t) != {"cle", "textes"}:
            err(ou, "champs attendus : cle, textes")
        c = t.get("cle")
        if c not in CLES_TEXTES:
            err(ou, f"clé inconnue « {c} »")
        for k, x in enumerate(t.get("textes") or []):
            verifier_texte(f"{ou}[{k}]", x, False)
        cles[c] = cles.get(c, 0) + len(t.get("textes") or [])
    for c in sorted(CLES_TEXTES):
        if cles.get(c, 0) < 3:
            err("Textes", f"clé « {c} » : au moins 3 textes ({cles.get(c, 0)})")

    # Couverture : chaque type de proche doit pouvoir avoir des secrets.
    for p in sorted(PORTEURS):
        n = sum(1 for _, m in modeles if p in (m.get("porteurs") or []))
        if n < 3:
            avertissements.append(f"couverture : seulement {n} secret(s) pour « {p} »")

    for a in avertissements:
        print("⚠️ ", a)
    for e in erreurs:
        print("❌", e)
    print(f"{len(modeles)} secrets, {len(ids_moments)} moments, {len(cles)} clés de textes : "
          f"{len(erreurs)} erreur(s), {len(avertissements)} avertissement(s).")
    return 1 if erreurs else 0


if __name__ == "__main__":
    sys.exit(main())
