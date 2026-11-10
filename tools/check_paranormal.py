#!/usr/bin/env python3
"""Vérifie la cohérence des quêtes paranormales (docs/PARANORMAL.md).

- chaque étape (Data/Repercussions/paranormal_*.json) est accrochée à un événement ou une étape qui existe,
  avec un choix et une issue valides ;
- chaque drapeau exigé par une étape est posé quelque part plus tôt dans la même quête ;
- chaque followUps pointe vers une étape existante ;
- chaque choix de chances fait 1 ;
- affiche l'arbre de chaque quête.

Usage : python3 tools/check_paranormal.py
"""
import glob
import json
import os
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(RACINE, "FTCHTLife", "Resources", "Data")


def charger(motif):
    out = []
    for f in sorted(glob.glob(os.path.join(DATA, motif))):
        out += json.load(open(f, encoding="utf-8"))
    return out


def drapeaux_poses(noeud):
    poses = set(noeud.get("remember") or []) | set(noeud.get("setFlags") or [])
    for eff in [noeud.get("effects") or {}] + [o.get("effects") or {}
                                               for c in noeud.get("choices") or [] for o in c["outcomes"]]:
        poses |= set(eff.get("setFlags") or [])
    return poses


def main():
    events = {e["id"]: e for e in charger("Events/paranormal_*.json")}
    etapes = {r["id"]: r for r in charger("Repercussions/paranormal_*.json")}
    noeuds = {**events, **etapes}
    erreurs = []

    enfants = {}
    for r in etapes.values():
        parent = r["on"][len("event:"):] if r["on"].startswith("event:") else None
        if parent not in noeuds:
            erreurs.append(f"{r['id']} : accroché à « {r['on']} », introuvable")
            continue
        enfants.setdefault(parent, []).append(r["id"])
        ch = noeuds[parent].get("choices") or []
        if r.get("choice") is not None and not 0 <= r["choice"] < len(ch):
            erreurs.append(f"{r['id']} : choix {r['choice']} absent de {parent}")
        if r.get("outcome") is not None and (r.get("choice") is None or
                                             not 0 <= r["outcome"] < len(ch[r["choice"]]["outcomes"])):
            erreurs.append(f"{r['id']} : issue {r.get('outcome')} absente de {parent}")
    for n in noeuds.values():
        for c in n.get("choices") or []:
            s = sum(o.get("chance", 1) for o in c["outcomes"])
            if abs(s - 1) > 0.011:
                erreurs.append(f"{n['id']} / « {c['label']} » : somme des chances = {s}")
            for o in c["outcomes"]:
                for i in (o.get("effects") or {}).get("followUps") or []:
                    if i not in etapes:
                        erreurs.append(f"{n['id']} : followUps vers « {i} » inconnu")
                    else:
                        enfants.setdefault(n["id"], []).append(i)

    # Drapeaux exigés : posés par un ancêtre (ou par le nœud qui programme via followUps).
    parents = {}
    for p, fs in enfants.items():
        for f in fs:
            parents.setdefault(f, set()).add(p)

    def ancetres(i, vus=None):
        vus = vus or set()
        for p in parents.get(i, ()):
            if p not in vus:
                vus.add(p)
                ancetres(p, vus)
        return vus

    for r in etapes.values():
        exiges = set((r.get("conditions") or {}).get("flags") or [])
        poses = set().union(*[drapeaux_poses(noeuds[a]) for a in ancetres(r["id"])] or [set()])
        for f in exiges - poses:
            erreurs.append(f"{r['id']} : exige le drapeau « {f} » jamais posé avant dans la quête")

    def arbre(i, prof=0):
        n = noeuds[i]
        print("  " * prof + f"- {i} : {n['text'][:70]}…")
        for e in sorted(set(enfants.get(i, []))):
            if e != i:
                arbre(e, prof + 1)

    for i, e in events.items():
        if i in enfants:
            arbre(i)
    isoles = [i for i in events if i not in enfants]
    print(f"\nRencontres isolées : {len(isoles)}")
    for e in erreurs:
        print("ERREUR :", e)
    print(f"{len(events)} événements, {len(etapes)} étapes, {len(erreurs)} erreurs")
    return 1 if erreurs else 0


if __name__ == "__main__":
    sys.exit(main())
