#!/usr/bin/env python3
"""Convertit les `followUp` écrits dans les loisirs en suites du système de répercussions.

Pour chaque issue qui a un `followUp` :
- l'issue reçoit une `key` (signal précis `<activite>_<key>`) et perd son `followUp` ;
- une suite est ajoutée dans Resources/Data/Repercussions/loisirs_NN.json (ids rep_loi_NNNN, "on": ce signal).

Usage : python3 tools/convertir_suites_loisirs.py
Peut être relancé : seuls les nouveaux followUp sont convertis, la numérotation continue.
"""
import glob
import json
import os
import re

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "FTCHTLife", "Resources", "Data")
LOISIRS = os.path.join(RACINE, "Loisirs")
REPS = os.path.join(RACINE, "Repercussions")
PAR_FICHIER = 200


def ecrire(chemin, data):
    with open(chemin, "w", encoding="utf-8") as h:
        json.dump(data, h, ensure_ascii=False, indent=2)
        h.write("\n")


def main():
    os.makedirs(REPS, exist_ok=True)
    existants = []
    for f in sorted(glob.glob(os.path.join(REPS, "loisirs_*.json"))):
        with open(f, encoding="utf-8") as h:
            existants.append((f, json.load(h)))
    numeros = [int(m.group(1)) for _, d in existants for r in d
               if (m := re.match(r"^rep_loi_(\d{4})$", r.get("id", "")))]
    prochain = max(numeros, default=0) + 1
    nouvelles = []

    for f in sorted(glob.glob(os.path.join(LOISIRS, "*.json"))):
        with open(f, encoding="utf-8") as h:
            activites = json.load(h)
        modifie = False
        for a in activites:
            cles = {x.get("key") for o in a.get("options", []) for x in o.get("outcomes", []) if x.get("key")}
            for o in a.get("options", []):
                for k, x in enumerate(o.get("outcomes", [])):
                    fu = x.pop("followUp", None)
                    if not fu:
                        continue
                    modifie = True
                    cle = x.get("key")
                    if not cle:
                        cle = f"{o['id']}_{k + 1}"
                        n = 2
                        while cle in cles:
                            cle = f"{o['id']}_{k + 1}_{n}"
                            n += 1
                        cles.add(cle)
                        x["key"] = cle
                    annees = max(1, int(fu.get("inYears") or 1))
                    suite = {
                        "id": f"rep_loi_{prochain:04d}",
                        "on": f"{a['id']}_{cle}",
                        "chance": fu.get("chance", 1),
                        "delay": [annees, annees],
                        "text": fu["text"],
                    }
                    if fu.get("effects"):
                        suite["effects"] = fu["effects"]
                    nouvelles.append(suite)
                    prochain += 1
        if modifie:
            ecrire(f, activites)

    if not nouvelles:
        print("Aucun followUp à convertir.")
        return
    # Remplit le dernier fichier puis en crée de nouveaux.
    if existants and len(existants[-1][1]) < PAR_FICHIER:
        chemin, data = existants[-1]
    else:
        chemin, data = os.path.join(REPS, f"loisirs_{len(existants) + 1:02d}.json"), []
        existants.append((chemin, data))
    for s in nouvelles:
        if len(data) >= PAR_FICHIER:
            ecrire(chemin, data)
            chemin, data = os.path.join(REPS, f"loisirs_{len(existants) + 1:02d}.json"), []
            existants.append((chemin, data))
        data.append(s)
    ecrire(chemin, data)
    print(f"{len(nouvelles)} suites converties.")


if __name__ == "__main__":
    main()
