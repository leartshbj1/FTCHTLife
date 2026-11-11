#!/usr/bin/env python3
"""Vérifie FTCHTLife/Resources/Data/Gloire/catalogue.json et proces.json (format : docs/GLOIRE.md).

Les champs obligatoires et leurs types suivent les structures Swift de FTCHTLife/Gloire/GloireModeles.swift :
un champ manquant ou d'un mauvais type ferait échouer tout le catalogue au chargement (module vide).
Usage : python3 tools/validate_gloire.py
"""
import json
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
DOSSIER = RACINE / "FTCHTLife/Resources/Data/Gloire"

erreurs: list[str] = []
avert: list[str] = []

STATS = {"apparence", "intelligence", "bonheur", "karma", "sante", "gloire"}
EFFETS = {"bonheur": int, "sante": int, "intelligence": int, "apparence": int, "karma": int, "argent": int,
          "gloire": int, "nouvelAmi": bool, "signal": str, "scandale": bool, "deces": str}
COMPETENCES = set("""anglais espagnol allemand italien albanais japonais guitare piano chant danse dessin photo cuisine
bricolage mecanique jardinage sport survie code echecs seduction eloquence humour marchandage magie""".split())
TYPES_CIBLES = {"proche", "employeur", "entreprise", "medecin", "presse", "etat", "voisin"}
CONDITIONS_CIBLE = {"emploi", "ancienEmploi", "prison", "gloire"}
RE_VAR = re.compile(r"\{([a-z_]+)\}")
VARS_BASE = {"prenom", "nom", "ville", "e"}


def typ(v, t) -> bool:
    if t is int:
        return isinstance(v, int) and not isinstance(v, bool)
    if t is float:
        return isinstance(v, (int, float)) and not isinstance(v, bool)
    return isinstance(v, t)


def champs(obj, ou: str, obligatoires: dict, facultatifs: dict):
    if not isinstance(obj, dict):
        erreurs.append(f"{ou} : objet attendu")
        return False
    for k, t in obligatoires.items():
        if k not in obj:
            erreurs.append(f"{ou} : champ « {k} » manquant")
        elif not typ(obj[k], t):
            erreurs.append(f"{ou} : « {k} » doit être {t.__name__}")
    for k, t in facultatifs.items():
        if k in obj and obj[k] is not None and not typ(obj[k], t):
            erreurs.append(f"{ou} : « {k} » doit être {t.__name__}")
    for k in obj:
        if k not in obligatoires and k not in facultatifs:
            avert.append(f"{ou} : champ inconnu « {k} » (ignoré par le jeu)")
    return True


def textes(liste, ou: str, vars_ok: set, vide_ok=False):
    if not isinstance(liste, list) or (not liste and not vide_ok):
        erreurs.append(f"{ou} : liste de textes non vide attendue")
        return
    for i, t in enumerate(liste):
        if not isinstance(t, str) or not t.strip():
            erreurs.append(f"{ou}[{i}] : texte vide")
            continue
        texte(t, f"{ou}[{i}]", vars_ok)


def texte(t: str, ou: str, vars_ok: set):
    for v in RE_VAR.findall(t):
        if v not in vars_ok:
            erreurs.append(f"{ou} : variable {{{v}}} inconnue ici")
    if "  " in t:
        avert.append(f"{ou} : double espace")


def effets(fx, ou: str):
    if fx is None:
        return
    if not isinstance(fx, dict):
        erreurs.append(f"{ou} : objet d'effets attendu")
        return
    for k, v in fx.items():
        if k not in EFFETS:
            erreurs.append(f"{ou} : effet inconnu « {k} »")
        elif not typ(v, EFFETS[k]):
            erreurs.append(f"{ou} : effet « {k} » doit être {EFFETS[k].__name__}")
    if "gloire" in fx and abs(fx["gloire"]) > 20:
        avert.append(f"{ou} : gloire {fx['gloire']} très forte")


def issues(liste, ou: str, vars_ok: set):
    if not isinstance(liste, list) or not liste:
        erreurs.append(f"{ou} : au moins une issue")
        return
    for i, x in enumerate(liste):
        w = f"{ou}[{i}]"
        if champs(x, w, {"texte": str}, {"chance": float, "effets": dict}):
            texte(x.get("texte", ""), w, vars_ok)
            effets(x.get("effets"), w)


def fourchette(v, ou: str):
    if not (isinstance(v, list) and len(v) == 2 and all(typ(x, int) for x in v) and 0 <= v[0] <= v[1]):
        erreurs.append(f"{ou} : [min, max] d'entiers attendu")


def ids_uniques(liste, ou: str):
    vus = set()
    for x in liste:
        i = x.get("id") if isinstance(x, dict) else None
        if i in vus:
            erreurs.append(f"{ou} : id « {i} » en double")
        vus.add(i)


def verifier_catalogue():
    p = DOSSIER / "catalogue.json"
    data = json.loads(p.read_text(encoding="utf-8"))
    champs(data, "catalogue", {"livres": list, "pubs": list, "fetes": list, "shootings": list, "plateaux": list}, {})

    for g in data.get("livres", []):
        ou = f"livres/{g.get('id')}"
        champs(g, ou, {"id": str, "nom": str, "emoji": str, "description": str, "ageMin": int, "gloireMin": int,
                       "ventes": int, "poidsGloire": float, "titres": list, "critiquesBonnes": list,
                       "critiquesMoyennes": list, "critiquesMauvaises": list}, {"competence": str})
        if g.get("competence") and g["competence"] not in COMPETENCES:
            erreurs.append(f"{ou} : compétence « {g['competence']} » inconnue")
        textes(g.get("titres"), ou + "/titres", VARS_BASE)
        for k in ("critiquesBonnes", "critiquesMoyennes", "critiquesMauvaises"):
            textes(g.get(k), f"{ou}/{k}", VARS_BASE | {"titre"})
    ids_uniques(data.get("livres", []), "livres")

    for pub in data.get("pubs", []):
        ou = f"pubs/{pub.get('id')}"
        champs(pub, ou, {"id": str, "marque": str, "produit": str, "emoji": str, "gloireMin": int, "ageMin": int,
                         "cachet": list, "gloire": int, "textes": list},
               {"ageMax": int, "louche": bool, "risque": float, "textesRates": list, "effetsRates": dict})
        fourchette(pub.get("cachet"), ou + "/cachet")
        vars_pub = VARS_BASE | {"marque", "produit", "cachet"}
        textes(pub.get("textes"), ou + "/textes", vars_pub)
        if pub.get("risque"):
            if not pub.get("textesRates"):
                erreurs.append(f"{ou} : risque sans textesRates")
            textes(pub.get("textesRates") or [], ou + "/textesRates", vars_pub, vide_ok=True)
        effets(pub.get("effetsRates"), ou + "/effetsRates")
    ids_uniques(data.get("pubs", []), "pubs")
    paliers = sorted({p.get("gloireMin", 0) for p in data.get("pubs", [])})
    if not paliers or paliers[0] != 0:
        erreurs.append("pubs : il faut des offres à gloire 0 pour débuter")

    toutes = []
    for cle in ("fetes", "shootings", "plateaux"):
        for a in data.get(cle, []):
            ou = f"{cle}/{a.get('id')}"
            toutes.append(a)
            champs(a, ou, {"id": str, "nom": str, "emoji": str, "description": str, "ageMin": int, "gloireMin": int,
                           "prix": int, "stat": str, "succes": list, "rates": list},
                   {"cachet": list, "dilemmes": list})
            if a.get("stat") not in STATS:
                erreurs.append(f"{ou} : stat « {a.get('stat')} » inconnue")
            if "cachet" in a:
                fourchette(a["cachet"], ou + "/cachet")
            vars_act = VARS_BASE | ({"cachet"} if "cachet" in a else set())
            issues(a.get("succes"), ou + "/succes", vars_act)
            issues(a.get("rates"), ou + "/rates", VARS_BASE)
            for k, d in enumerate(a.get("dilemmes") or []):
                w = f"{ou}/dilemmes[{k}]"
                champs(d, w, {"chance": float, "texte": str, "accepter": str, "refuser": str,
                              "siAccepte": list, "siRefuse": list}, {})
                texte(d.get("texte", ""), w, VARS_BASE)
                issues(d.get("siAccepte"), w + "/siAccepte", VARS_BASE)
                issues(d.get("siRefuse"), w + "/siRefuse", VARS_BASE)
    ids_uniques(toutes, "fêtes/shootings/plateaux")
    return data


def verifier_proces():
    p = DOSSIER / "proces.json"
    data = json.loads(p.read_text(encoding="utf-8"))
    champs(data, "proces", {"cibles": list, "motifs": list, "avocats": list, "strategies": list,
                            "audiences": list, "accords": list}, {})
    vars_proces = VARS_BASE | {"cible", "motif", "montant", "avocat"}

    types = {"proche"}
    for c in data.get("cibles", []):
        ou = f"cibles/{c.get('id')}"
        champs(c, ou, {"id": str, "nom": str, "emoji": str, "description": str, "type": str, "defense": int,
                       "poche": float}, {"condition": str})
        if c.get("type") not in TYPES_CIBLES:
            erreurs.append(f"{ou} : type « {c.get('type')} » inconnu")
        types.add(c.get("type"))
        if c.get("condition") and c["condition"] not in CONDITIONS_CIBLE:
            erreurs.append(f"{ou} : condition « {c['condition']} » inconnue")
        if RE_VAR.search(c.get("nom", "")):
            erreurs.append(f"{ou} : pas de variable dans le nom d'une cible")
    ids_uniques(data.get("cibles", []), "cibles")

    couverts = set()
    for m in data.get("motifs", []):
        ou = f"motifs/{m.get('id')}"
        champs(m, ou, {"id": str, "nom": str, "description": str, "cibles": list, "solidite": int, "dommages": list,
                       "victoire": list, "defaite": list}, {"frivole": bool})
        for t in m.get("cibles", []):
            if t not in TYPES_CIBLES:
                erreurs.append(f"{ou} : type de cible « {t} » inconnu")
            couverts.add(t)
        fourchette(m.get("dommages"), ou + "/dommages")
        texte(m.get("nom", ""), ou + "/nom", VARS_BASE)
        texte(m.get("description", ""), ou + "/description", VARS_BASE)
        textes(m.get("victoire"), ou + "/victoire", vars_proces)
        textes(m.get("defaite"), ou + "/defaite", vars_proces)
        if not 0 <= m.get("solidite", 0) <= 100:
            erreurs.append(f"{ou} : solidite entre 0 et 100")
    for t in types - couverts:
        erreurs.append(f"motifs : aucun motif pour les cibles de type « {t} »")
    ids_uniques(data.get("motifs", []), "motifs")

    for a in data.get("avocats", []):
        ou = f"avocats/{a.get('id')}"
        champs(a, ou, {"id": str, "nom": str, "emoji": str, "description": str, "honoraires": int, "bonus": int},
               {"pourcentage": float, "condition": str})
        if a.get("condition") not in (None, "droit"):
            erreurs.append(f"{ou} : condition « {a.get('condition')} » inconnue")
    if not any(a.get("condition") is None and a.get("honoraires") == 0 for a in data.get("avocats", [])):
        erreurs.append("avocats : il faut un avocat gratuit sans condition (commis d'office)")
    ids_uniques(data.get("avocats", []), "avocats")

    for s in data.get("strategies", []):
        ou = f"strategies/{s.get('id')}"
        champs(s, ou, {"id": str, "nom": str, "emoji": str, "description": str, "stat": str, "amplitude": int,
                       "textes": list}, {})
        if s.get("stat") not in STATS:
            erreurs.append(f"{ou} : stat « {s.get('stat')} » inconnue")
        textes(s.get("textes"), ou + "/textes", vars_proces)
    ids_uniques(data.get("strategies", []), "strategies")
    textes(data.get("audiences"), "audiences", vars_proces)
    textes(data.get("accords"), "accords", vars_proces)
    return data


def main():
    cat = verifier_catalogue()
    pr = verifier_proces()
    for a in avert:
        print("avertissement :", a)
    for e in erreurs:
        print("ERREUR :", e)
    n_act = sum(len(cat.get(k, [])) for k in ("fetes", "shootings", "plateaux"))
    print(f"{len(cat.get('livres', []))} genres de livres, {len(cat.get('pubs', []))} pubs, {n_act} activités, "
          f"{len(pr.get('cibles', []))} cibles, {len(pr.get('motifs', []))} motifs, {len(pr.get('avocats', []))} avocats — "
          f"{len(erreurs)} erreurs, {len(avert)} avertissements")
    sys.exit(1 if erreurs else 0)


if __name__ == "__main__":
    main()
