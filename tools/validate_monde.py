#!/usr/bin/env python3
"""Valide les flashs du journal du monde (FTCHTLife/Resources/Data/Monde/*.json).
Usage : python3 tools/validate_monde.py   (code de sortie 1 en cas d'erreur)"""
import json, glob, os, re, sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(RACINE, "FTCHTLife", "Resources", "Data")

RUBRIQUES = {"economie", "politique", "science", "insolite", "meteo", "sport", "people", "sante", "tech", "international"}
PRIX = {"immobilier", "voitures", "bateaux", "avions", "bijoux", "voyages", "nourriture", "tech", "luxe", "animaux",
        "sante", "etudes", "loisirs", "vetements", "tout"}
SECTEURS = {"restauration", "commerce", "transport", "batiment", "beaute", "securite", "administration", "medias",
            "immobilier", "tech", "finance", "arts", "science", "education", "droit", "sante", "sport", "politique",
            "industrie", "agriculture", "tourisme", "tout"}
MARCHES = {"bourse", "crypto", "or", "immobilier_locatif", "epargne"} | {"bourse_" + x for x in
           ("tech", "alimentation", "energie", "luxe", "sante", "transport", "loisirs", "finance", "industrie")}
CHAMPS = {"id", "rubrique", "titre", "texte", "poids", "duree", "unique", "minAge", "maxAge", "requiertTagsMonde",
          "excluTagsMonde", "suiteSeulement", "modificateurs", "effetsImmediats", "effetsAnnuels", "evenements",
          "tagsMonde", "texteFin", "suites", "chanceSuite"}
MODIFS = {"prix", "salaires", "evenements", "marches", "mortalite", "retraite"}
EFFETS = {"happiness", "health", "smarts", "looks", "karma", "money", "stress", "fame", "relationships", "newFriend", "death"}
RELATIONS = {"mother", "father", "parent", "sibling", "friend", "partner", "child"}
TAGS_JOUEUR = {"male", "female", "baby", "school", "university", "job", "adult", "unemployed", "retired", "rich", "poor",
               "friend", "mother", "father", "siblings", "partner", "children", "sick", "attractive", "smart"}
VARIABLES = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e"}

erreurs = []
def err(fichier, ident, msg):
    erreurs.append(f"{os.path.basename(fichier)} [{ident}] {msg}")

def verifier_texte(f, ident, t, champ):
    if not isinstance(t, str) or not t.strip():
        err(f, ident, f"{champ} vide ou absent"); return
    for v in re.findall(r"\{([^}]*)\}", t):
        if v not in VARIABLES:
            err(f, ident, f"{champ} : variable inconnue {{{v}}}")

def verifier_effets(f, ident, eff, ctx):
    if not isinstance(eff, dict):
        err(f, ident, f"{ctx} : effects doit être un objet"); return
    for k, v in eff.items():
        if k not in EFFETS: err(f, ident, f"{ctx} : clé d'effet inconnue {k}")
        elif k == "relationships":
            for r in v:
                if r not in RELATIONS: err(f, ident, f"{ctx} : relation inconnue {r}")
        elif k == "newFriend":
            if not isinstance(v, bool): err(f, ident, f"{ctx} : newFriend doit être true/false")
        elif k == "death":
            if not isinstance(v, str): err(f, ident, f"{ctx} : death doit être un texte")
        elif not isinstance(v, int) or isinstance(v, bool):
            err(f, ident, f"{ctx} : {k} doit être un entier")
        elif k != "money" and abs(v) > 100:
            err(f, ident, f"{ctx} : {k} hors bornes")

def verifier_table(f, ident, table, cles, nom):
    if not isinstance(table, dict): err(f, ident, f"{nom} doit être un objet"); return
    for k, v in table.items():
        if cles is not None and k not in cles: err(f, ident, f"{nom} : clé inconnue {k}")
        if not isinstance(v, (int, float)) or isinstance(v, bool) or not (0.1 <= v <= 10):
            err(f, ident, f"{nom}.{k} doit être un nombre entre 0.1 et 10")

def verifier_evenement(f, ident, e):
    for c in ("id", "minAge", "maxAge", "text"):
        if c not in e: err(f, ident, f"événement interne sans {c}")
    if not str(e.get("id", "")).startswith(ident + "_e"):
        err(f, ident, f"événement interne {e.get('id')} : l'id doit commencer par {ident}_e")
    verifier_texte(f, e.get("id"), e.get("text"), "text")
    cond = e.get("conditions") or {}
    for t in (cond.get("tags") or []) + (cond.get("excludeTags") or []):
        if t not in TAGS_JOUEUR and not t.startswith("monde_"):
            err(f, e.get("id"), f"tag inconnu {t}")
    if e.get("effects") is not None: verifier_effets(f, e.get("id"), e["effects"], "effects")
    choix = e.get("choices") or []
    if not choix and e.get("effects") is None: err(f, e.get("id"), "ni choix ni effects")
    for ch in choix:
        if not ch.get("label"): err(f, e.get("id"), "choix sans label")
        if not ch.get("outcomes"): err(f, e.get("id"), "choix sans outcomes")
        for o in ch.get("outcomes", []):
            verifier_texte(f, e.get("id"), o.get("text"), "outcome.text")
            if o.get("effects") is not None: verifier_effets(f, e.get("id"), o["effects"], "outcome")

def main():
    ids, refs, total, avec_effets = {}, [], 0, 0
    ids_evenements = set()
    for f in glob.glob(os.path.join(DATA, "Events", "*.json")):
        try:
            for e in json.load(open(f, encoding="utf-8")): ids_evenements.add(e.get("id"))
        except Exception: pass
    fichiers = sorted(glob.glob(os.path.join(DATA, "Monde", "*.json")))
    for f in fichiers:
        try:
            data = json.load(open(f, encoding="utf-8"))
        except Exception as ex:
            err(f, "-", f"JSON invalide : {ex}"); continue
        if not isinstance(data, list): err(f, "-", "le fichier doit contenir un tableau"); continue
        for fl in data:
            total += 1
            ident = fl.get("id", "?")
            if not re.fullmatch(r"mon_\d{4}", str(ident)): err(f, ident, "id attendu : mon_NNNN")
            if ident in ids: err(f, ident, f"id en double (déjà dans {ids[ident]})")
            ids[ident] = os.path.basename(f)
            for c in fl:
                if c not in CHAMPS: err(f, ident, f"champ inconnu {c}")
            if fl.get("rubrique") not in RUBRIQUES: err(f, ident, f"rubrique inconnue {fl.get('rubrique')}")
            titre = fl.get("titre", "")
            if not titre or titre != titre.upper(): err(f, ident, "titre absent ou pas en majuscules")
            if len(titre) > 60: err(f, ident, "titre trop long (> 60)")
            verifier_texte(f, ident, fl.get("texte"), "texte")
            duree = fl.get("duree", 0)
            if not isinstance(duree, int) or not (0 <= duree <= 10): err(f, ident, "duree entre 0 et 10")
            if not isinstance(fl.get("poids", 1), (int, float)) or fl.get("poids", 1) <= 0: err(f, ident, "poids > 0")
            m = fl.get("modificateurs")
            durable = bool(m) or bool(fl.get("effetsAnnuels")) or bool(fl.get("evenements")) or bool(fl.get("tagsMonde"))
            if durable and duree == 0: err(f, ident, "a des effets durables mais duree = 0")
            if duree > 0 and not durable: err(f, ident, "duree > 0 mais aucun effet durable")
            if duree > 0: avec_effets += 1
            if m:
                for k in m:
                    if k not in MODIFS: err(f, ident, f"modificateur inconnu {k}")
                if "prix" in m: verifier_table(f, ident, m["prix"], PRIX, "prix")
                if "salaires" in m: verifier_table(f, ident, m["salaires"], SECTEURS, "salaires")
                if "marches" in m: verifier_table(f, ident, m["marches"], MARCHES, "marches")
                ev = m.get("evenements")
                if ev is not None:
                    for k in ev:
                        if k not in ("categories", "prefixes"): err(f, ident, f"evenements.{k} inconnu")
                    verifier_table(f, ident, ev.get("categories", {}), None, "evenements.categories")
                    verifier_table(f, ident, ev.get("prefixes", {}), None, "evenements.prefixes")
                for k in ("mortalite", "retraite"):
                    if k in m: verifier_table(f, ident, {k: m[k]}, None, k)
            for champ in ("effetsImmediats", "effetsAnnuels"):
                for i, ea in enumerate(fl.get(champ) or []):
                    if "effects" not in ea: err(f, ident, f"{champ}[{i}] sans effects")
                    else: verifier_effets(f, ident, ea["effects"], champ)
                    if "text" in ea: verifier_texte(f, ident, ea["text"], champ + ".text")
                    for t in (ea.get("tags") or []) + (ea.get("excludeTags") or []):
                        if t not in TAGS_JOUEUR and not t.startswith("monde_"): err(f, ident, f"{champ} : tag inconnu {t}")
            for e in fl.get("evenements") or []:
                verifier_evenement(f, ident, e)
                if e.get("id") in ids_evenements: err(f, ident, f"id d'événement en double {e.get('id')}")
                ids_evenements.add(e.get("id"))
            for t in (fl.get("tagsMonde") or []) + (fl.get("requiertTagsMonde") or []) + (fl.get("excluTagsMonde") or []):
                if not re.fullmatch(r"[a-z0-9_]+", t): err(f, ident, f"tag monde invalide {t} (minuscules, chiffres, _)")
            if fl.get("texteFin") is not None: verifier_texte(f, ident, fl["texteFin"], "texteFin")
            for s in fl.get("suites") or []: refs.append((f, ident, s))
            if fl.get("suiteSeulement") and not fl.get("requiertTagsMonde"):
                pass
    for f, ident, s in refs:
        if s not in ids: err(f, ident, f"suite inconnue {s}")
    if erreurs:
        print("\n".join(erreurs)); print(f"\n{len(erreurs)} erreur(s)."); sys.exit(1)
    print(f"OK : {total} flashs dans {len(fichiers)} fichiers ({avec_effets} avec effets durables, {total - avec_effets} pour rire).")

main()
