#!/usr/bin/env python3
"""Vérifie les données du module Entreprises (voir docs/ENTREPRISES.md).

Usage : python3 tools/validate_entreprises.py
"""
import json
import os
import re
import sys

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "FTCHTLife", "Resources", "Data")
DOSSIER_TYPES = os.path.join(RACINE, "Entreprises")
DOSSIER_EVENTS = os.path.join(RACINE, "EntrepriseEvents")
DOSSIER_LEVIERS = os.path.join(RACINE, "EntrepriseLeviers")
CLES_EFFETS_LEVIER = {"demande", "prix", "coutVariable", "capacite", "productivite", "reputation", "moral", "risque", "karma"}

SECTEURS = {"restauration", "beaute", "commerce", "mode", "tech", "services", "artisanat", "loisirs", "immobilier", "transport"}
DIPLOMES = {"aucun", "ecoleObligatoire", "bac", "licence", "master", "doctorat"}
FILIERES = {None, "medecine", "droit", "informatique", "commerce", "arts", "sciences"}
KINDS = {"crise", "opportunite", "equipe", "absurde"}
EMPLOYE = {"proche", "inconnu", "any"}
CLES_BUSINESS = {"cash", "argentJoueur", "dette", "reputation", "elan", "moral", "employeMoral",
                 "employeCompetence", "employePart", "lienEmploye", "niveau", "faillite"}
CLES_EFFETS = {"happiness", "health", "smarts", "looks", "karma", "money", "stress", "fame",
               "relationships", "newFriend", "death"}
CLES_RELATIONS = {"mother", "father", "parent", "sibling", "friend", "partner", "child"}
CLES_CONDITIONS = {"employe", "minEmployes", "maxEmployes", "minAnnees", "enDifficulte", "patronAbsent",
                   "minReputation", "maxReputation"}
VARIABLES = {"entreprise", "produit", "employe", "poste", "concurrent", "niveau", "prenom", "nom", "ville",
             "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e"}

erreurs = []


def err(fichier, ident, msg):
    erreurs.append(f"{os.path.basename(fichier)} [{ident}] : {msg}")


def lire(dossier):
    out = []
    if not os.path.isdir(dossier):
        return out
    for nom in sorted(os.listdir(dossier)):
        if not nom.endswith(".json"):
            continue
        chemin = os.path.join(dossier, nom)
        try:
            with open(chemin, encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:  # noqa: BLE001
            erreurs.append(f"{nom} : JSON invalide ({e})")
            continue
        if not isinstance(data, list):
            erreurs.append(f"{nom} : le fichier doit contenir un tableau")
            continue
        out += [(chemin, x) for x in data]
    return out


def verifier_texte(fichier, ident, texte, champ):
    if not isinstance(texte, str) or not texte.strip():
        err(fichier, ident, f"{champ} vide")
        return
    for v in re.findall(r"\{([^}]*)\}", texte):
        if v not in VARIABLES:
            err(fichier, ident, f"variable inconnue {{{v}}} dans {champ}")


def verifier_issue(fichier, ident, issue, ou):
    if not isinstance(issue, dict):
        err(fichier, ident, f"{ou} : issue invalide")
        return
    inconnues = set(issue) - {"chance", "text", "business", "effects"}
    if inconnues:
        err(fichier, ident, f"{ou} : clés inconnues {sorted(inconnues)}")
    verifier_texte(fichier, ident, issue.get("text"), f"{ou}.text")
    if "chance" in issue and not isinstance(issue["chance"], (int, float)):
        err(fichier, ident, f"{ou} : chance doit être un nombre")
    b = issue.get("business") or {}
    for k, v in b.items():
        if k not in CLES_BUSINESS:
            err(fichier, ident, f"{ou} : clé business inconnue {k}")
        elif k in ("employePart", "faillite"):
            if not isinstance(v, bool):
                err(fichier, ident, f"{ou} : {k} doit être true/false")
        elif not isinstance(v, int) or isinstance(v, bool):
            err(fichier, ident, f"{ou} : {k} doit être un entier")
    e = issue.get("effects") or {}
    for k, v in e.items():
        if k not in CLES_EFFETS:
            err(fichier, ident, f"{ou} : clé effects inconnue {k}")
        elif k == "relationships":
            if not isinstance(v, dict) or set(v) - CLES_RELATIONS:
                err(fichier, ident, f"{ou} : relationships invalide")
        elif k == "death":
            if not isinstance(v, str):
                err(fichier, ident, f"{ou} : death doit être un texte")
        elif k == "newFriend":
            if not isinstance(v, bool):
                err(fichier, ident, f"{ou} : newFriend doit être true/false")
        elif not isinstance(v, int) or isinstance(v, bool):
            err(fichier, ident, f"{ou} : {k} doit être un entier")
    utilise_employe = any(k in b for k in ("employePart", "lienEmploye", "employeMoral", "employeCompetence"))
    return utilise_employe


def main():
    ids = set()
    types = lire(DOSSIER_TYPES)
    ids_types = set()
    for fichier, t in types:
        ident = t.get("id", "?")
        if ident in ids_types:
            err(fichier, ident, "id de type en double")
        ids_types.add(ident)
        for champ in ("nom", "secteur", "icone", "description", "produit", "coutCreation", "chiffreAffairesBase",
                      "marge", "volatilite", "risque", "multipleValeur", "salaireEmploye", "postes", "niveaux", "nomsSuggeres"):
            if champ not in t:
                err(fichier, ident, f"champ manquant {champ}")
        if t.get("secteur") not in SECTEURS:
            err(fichier, ident, f"secteur inconnu {t.get('secteur')}")
        if t.get("diplomeMin", "aucun") not in DIPLOMES:
            err(fichier, ident, "diplomeMin inconnu")
        if t.get("filiere") not in FILIERES:
            err(fichier, ident, "filiere inconnue")
        if len(t.get("niveaux", [])) != 6:
            err(fichier, ident, "niveaux doit contenir exactement 6 noms")
        if not 4 <= len(t.get("postes", [])) <= 8:
            err(fichier, ident, "postes : 4 à 8 intitulés")
        if len(t.get("nomsSuggeres", [])) < 6:
            err(fichier, ident, "nomsSuggeres : au moins 6 noms")
        m = t.get("marge", 0.3)
        if not 0.05 <= m <= 0.8:
            err(fichier, ident, "marge hors de [0.05, 0.8]")
        for n in t.get("niveaux", []):
            verifier_texte(fichier, ident, n, "niveaux")

    events = lire(DOSSIER_EVENTS)
    for fichier, e in events:
        ident = e.get("id", "?")
        if not re.fullmatch(r"ent_[a-z0-9]+_\d{4}", str(ident)):
            err(fichier, ident, "id attendu ent_<theme>_NNNN")
        if ident in ids:
            err(fichier, ident, "id en double")
        ids.add(ident)
        inconnues = set(e) - {"id", "kind", "secteurs", "types", "minNiveau", "maxNiveau", "weight", "unique",
                              "conditions", "text", "choices", "ignore"}
        if inconnues:
            err(fichier, ident, f"clés inconnues {sorted(inconnues)}")
        if e.get("kind", "crise") not in KINDS:
            err(fichier, ident, "kind inconnu")
        for s in e.get("secteurs") or []:
            if s not in SECTEURS:
                err(fichier, ident, f"secteur inconnu {s}")
        for ty in e.get("types") or []:
            if ids_types and ty not in ids_types:
                err(fichier, ident, f"type inconnu {ty}")
        c = e.get("conditions") or {}
        if set(c) - CLES_CONDITIONS:
            err(fichier, ident, f"conditions inconnues {sorted(set(c) - CLES_CONDITIONS)}")
        if c.get("employe") is not None and c.get("employe") not in EMPLOYE:
            err(fichier, ident, "conditions.employe : proche, inconnu ou any")
        verifier_texte(fichier, ident, e.get("text"), "text")
        choix = e.get("choices")
        if not isinstance(choix, list) or not 2 <= len(choix) <= 4:
            err(fichier, ident, "2 à 4 choix")
            choix = choix if isinstance(choix, list) else []
        utilise_employe = "{employe}" in e.get("text", "") or "{poste}" in e.get("text", "")
        for i, ch in enumerate(choix):
            if set(ch) - {"label", "cost", "outcomes"}:
                err(fichier, ident, f"choix {i} : clés inconnues")
            verifier_texte(fichier, ident, ch.get("label"), f"choix {i}.label")
            if "cost" in ch and (not isinstance(ch["cost"], int) or ch["cost"] < 0):
                err(fichier, ident, f"choix {i} : cost entier positif")
            issues = ch.get("outcomes")
            if not isinstance(issues, list) or not 1 <= len(issues) <= 4:
                err(fichier, ident, f"choix {i} : 1 à 4 issues")
                continue
            for k, iss in enumerate(issues):
                if verifier_issue(fichier, ident, iss, f"choix {i} issue {k}"):
                    utilise_employe = True
                if isinstance(iss, dict) and ("{employe}" in iss.get("text", "") or "{poste}" in iss.get("text", "")):
                    utilise_employe = True
        if "ignore" in e and verifier_issue(fichier, ident, e["ignore"], "ignore"):
            utilise_employe = True
        if utilise_employe and c.get("employe") is None:
            err(fichier, ident, "utilise {employe}/{poste} ou un effet employé sans conditions.employe")

    vus_types = set()
    ids_leviers = set()
    for fichier, l in lire(DOSSIER_LEVIERS):
        ident = l.get("typeId", "?")
        if ids_types and ident not in ids_types:
            err(fichier, ident, "typeId inconnu")
        if ident in vus_types:
            err(fichier, ident, "type décrit deux fois")
        vus_types.add(ident)
        inconnues = set(l) - {"typeId", "vente", "site", "usine", "prixUnitaire", "elasticite", "leviers"}
        if inconnues:
            err(fichier, ident, f"clés inconnues {sorted(inconnues)}")
        for bloc, cles in (("vente", {"nom", "pluriel"}), ("site", {"nom", "pluriel", "cout"}), ("usine", {"nom", "pluriel", "cout"})):
            b = l.get(bloc)
            if b is None:
                if bloc != "usine":
                    err(fichier, ident, f"{bloc} manquant")
                continue
            if set(b) != cles:
                err(fichier, ident, f"{bloc} : clés attendues {sorted(cles)}")
            if "cout" in b and (not isinstance(b["cout"], int) or b["cout"] <= 0):
                err(fichier, ident, f"{bloc}.cout entier positif")
        if not isinstance(l.get("prixUnitaire"), (int, float)) or l.get("prixUnitaire", 0) <= 0:
            err(fichier, ident, "prixUnitaire positif")
        el = l.get("elasticite", 1.2)
        if not isinstance(el, (int, float)) or not 0.4 <= el <= 2.2:
            err(fichier, ident, "elasticite entre 0.4 et 2.2")
        lev = l.get("leviers", [])
        if not 4 <= len(lev) <= 8:
            err(fichier, ident, "4 à 8 leviers")
        for v in lev:
            lid = v.get("id", "?")
            if lid in ids_leviers:
                err(fichier, lid, "id de levier en double")
            ids_leviers.add(lid)
            inc = set(v) - {"id", "nom", "description", "icone", "groupe", "niveauMin", "coutInstallation", "coutAnnuel", "parSite", "effets", "activation"}
            if inc:
                err(fichier, lid, f"clés inconnues {sorted(inc)}")
            for champ in ("nom", "description", "icone", "activation"):
                if not isinstance(v.get(champ), str) or not v.get(champ):
                    err(fichier, lid, f"{champ} manquant")
            for champ in ("coutInstallation", "coutAnnuel"):
                if not isinstance(v.get(champ, 0), int) or v.get(champ, 0) < 0:
                    err(fichier, lid, f"{champ} entier positif ou nul")
            if not 0 <= v.get("niveauMin", 0) <= 5:
                err(fichier, lid, "niveauMin de 0 à 5")
            eff = v.get("effets", {})
            if set(eff) - CLES_EFFETS_LEVIER:
                err(fichier, lid, f"effets inconnus {sorted(set(eff) - CLES_EFFETS_LEVIER)}")
            for k, x in eff.items():
                if not isinstance(x, int) or isinstance(x, bool) or abs(x) > 100:
                    err(fichier, lid, f"effet {k} : entier entre -100 et 100")
            for champ in ("description", "activation"):
                if isinstance(v.get(champ), str):
                    verifier_texte(fichier, lid, v[champ], champ)

    for m in erreurs:
        print("❌ " + m)
    print(f"{len(ids_types)} types, {len(ids)} événements d'entreprise, {len(vus_types)} types avec leviers ({len(ids_leviers)} leviers), {len(erreurs)} erreur(s).")
    return 1 if erreurs else 0


if __name__ == "__main__":
    sys.exit(main())
