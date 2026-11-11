#!/usr/bin/env python3
"""Valide les cartes des carrières spéciales (FTCHTLife/Resources/Data/SpecialesEvents). Voir docs/CARRIERES_SPECIALES.md."""
import json
import re
import sys
from collections import Counter
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
DOSSIER = RACINE / "FTCHTLife" / "Resources" / "Data" / "SpecialesEvents"

CARRIERES = {"mma": "mma_", "sport": "spo_", "mannequin": "man_", "cinema": "cin_", "musique": "mus_",
             "musee": "mee_", "invest": "inv_", "salle": "sal_"}
SPORTS = {"football", "basket", "tennis", "rugby", "athletisme", "cyclisme"}
GENRES = {"rap", "pop", "rock", "electro", "variete", "jazz",
          "comedie", "drame", "action", "horreur", "sf", "documentaire", "auteur"}
CLES_CARTE = {"id", "carriere", "minNiveau", "maxNiveau", "minAge", "maxAge", "sports", "genres", "types", "groupe",
              "unique", "poids", "text", "choices"}
CLES_CHOIX = {"label", "outcomes", "cost", "costPct", "requiresSkill", "risk"}
CLES_ISSUE = {"chance", "text", "effects", "spe"}
CLES_SPE = {"reputation", "forme", "niveau", "blessure", "gainPct", "fansPct", "force", "technique", "cardio",
            "prestige", "visiteursPct", "collectionPct", "investPct", "finCarriere", "signal"}
CLES_EFFETS = {"happiness", "health", "smarts", "looks", "karma", "money", "stress", "fame", "relationships",
               "newFriend", "death", "setFlags", "clearFlags", "followUps", "skills", "familyRep", "dreamMarks"}
VARIABLES = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e",
             "rang", "coach", "adversaire", "ligue", "salle", "club", "sport", "agence", "marque", "film",
             "groupe", "label", "musee", "oeuvre", "projet"}


def verifier_texte(t, ou, erreurs):
    if not isinstance(t, str) or not t.strip():
        erreurs.append(f"{ou}: texte vide")
        return
    for v in re.findall(r"\{([^}]*)\}", t):
        if v not in VARIABLES:
            erreurs.append(f"{ou}: variable inconnue {{{v}}}")


def main():
    erreurs, ids, compte = [], Counter(), Counter()
    fichiers = sorted(DOSSIER.glob("*.json"))
    for f in fichiers:
        try:
            cartes = json.loads(f.read_text(encoding="utf-8"))
        except Exception as e:  # noqa: BLE001
            erreurs.append(f"{f.name}: JSON invalide ({e})")
            continue
        if not isinstance(cartes, list):
            erreurs.append(f"{f.name}: le fichier doit contenir un tableau")
            continue
        for c in cartes:
            cid = c.get("id", "?")
            ou = f"{f.name}:{cid}"
            ids[cid] += 1
            for k in c:
                if k not in CLES_CARTE:
                    erreurs.append(f"{ou}: clé inconnue {k}")
            car = c.get("carriere")
            if car not in CARRIERES:
                erreurs.append(f"{ou}: carriere inconnue {car}")
            elif not re.fullmatch(CARRIERES[car] + r"\d{4}", cid):
                erreurs.append(f"{ou}: id attendu {CARRIERES[car]}NNNN")
            compte[car] += 1
            for s in c.get("sports") or []:
                if s not in SPORTS:
                    erreurs.append(f"{ou}: sport inconnu {s}")
            for ty in c.get("types") or []:
                if ty not in {"combattant", "film", "album", "club", "agence"}:
                    erreurs.append(f"{ou}: type d'investissement inconnu {ty}")
            for g in c.get("genres") or []:
                if g not in GENRES:
                    erreurs.append(f"{ou}: genre inconnu {g}")
            for k in ("minNiveau", "maxNiveau"):
                if k in c and not (isinstance(c[k], int) and 0 <= c[k] <= 5):
                    erreurs.append(f"{ou}: {k} doit être un entier de 0 à 5")
            verifier_texte(c.get("text"), ou, erreurs)
            choix = c.get("choices")
            if not isinstance(choix, list) or not 2 <= len(choix) <= 4:
                erreurs.append(f"{ou}: 2 à 4 choix")
                continue
            if all(ch.get("requiresSkill") for ch in choix):
                erreurs.append(f"{ou}: au moins un choix sans requiresSkill")
            for i, ch in enumerate(choix):
                oc = f"{ou} choix {i}"
                for k in ch:
                    if k not in CLES_CHOIX:
                        erreurs.append(f"{oc}: clé inconnue {k}")
                verifier_texte(ch.get("label"), oc, erreurs)
                issues = ch.get("outcomes")
                if not isinstance(issues, list) or not issues:
                    erreurs.append(f"{oc}: au moins une issue")
                    continue
                for n, o in enumerate(issues):
                    oo = f"{oc} issue {n}"
                    for k in o:
                        if k not in CLES_ISSUE:
                            erreurs.append(f"{oo}: clé inconnue {k}")
                    verifier_texte(o.get("text"), oo, erreurs)
                    for k in (o.get("effects") or {}):
                        if k not in CLES_EFFETS:
                            erreurs.append(f"{oo}: effet inconnu {k}")
                    for k, v in (o.get("spe") or {}).items():
                        if k not in CLES_SPE:
                            erreurs.append(f"{oo}: clé spe inconnue {k}")
                        elif k == "finCarriere" and not isinstance(v, bool):
                            erreurs.append(f"{oo}: finCarriere doit être true/false")
                        elif k == "signal" and not isinstance(v, str):
                            erreurs.append(f"{oo}: signal doit être un texte")
                        elif k not in ("finCarriere", "signal") and not isinstance(v, int):
                            erreurs.append(f"{oo}: {k} doit être un entier")
    for i, n in ids.items():
        if n > 1:
            erreurs.append(f"id en double : {i} ({n} fois)")
    for e in erreurs[:200]:
        print("❌", e)
    print(f"{len(fichiers)} fichiers, {sum(compte.values())} cartes : " + ", ".join(f"{k} {v}" for k, v in sorted(compte.items())))
    print(f"{len(erreurs)} erreur(s)")
    sys.exit(1 if erreurs else 0)


if __name__ == "__main__":
    main()
