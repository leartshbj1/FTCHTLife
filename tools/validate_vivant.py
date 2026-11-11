#!/usr/bin/env python3
"""Vérifie les données du module Jeu vivant (docs/VIVANT.md) :
- Data/Events/vivant_*.json (avec tools/validate_events.py) ;
- Data/Repercussions/vivant_*.json : suites rep_viv_ ;
- Data/VivantAnniversaires/*.json et Data/VivantProjets/*.json.

Usage : python3 tools/validate_vivant.py
"""
import glob
import json
import os
import re
import subprocess
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import validate_events as ve  # noqa: E402

DATA = os.path.join(os.path.dirname(ICI), "FTCHTLife", "Resources", "Data")
ve.PH |= {"jalon_nom", "annees", "projet"}

# Signaux connus : ceux du jeu (docs/REPERCUSSIONS.md) et ceux émis par le module Jeu vivant.
SIGNAUX = set("""
bac_obtenu bac_rate diplome abandon_etudes embauche promotion licenciement demission retraite
permis_code_obtenu permis_code_rate permis_obtenu permis_rate permis_retire accident_voiture arrestation proces_gagne
proces_perdu prison_entree prison_sortie evasion heritage loterie_gain casino_jackpot casino_ruine maladie guerison
hopital deces_parent deces_proche faillite celebrite achat_voiture achat_maison gros_achat
entreprise_creee entreprise_agrandie entreprise_empire entreprise_vendue entreprise_fermee entreprise_faillite proche_licencie
election_gagnee reelection mandat_perdu entree_gouvernement achat_voiture_luxe achat_moto achat_bateau achat_avion achat_bijoux
millionnaire milliardaire ruine placements_krach placements_envolee expatriation retour_pays condamnation casier_efface
star_reseaux projet_lance projet_abandon projet_reussite projet_moyen projet_echec
""".split())
JALONS = {"mariage", "rencontre_couple", "divorce", "veuvage", "deces_parent", "bac_obtenu", "diplome", "premier_emploi",
          "retraite", "prison_sortie", "entreprise_creee", "achat_maison", "naissance_enfant", "election_gagnee",
          "expatriation", "permis_obtenu"}
JALONS_NOMMES = {"mariage", "rencontre_couple", "divorce", "veuvage", "deces_parent", "naissance_enfant", "premier_emploi",
                 "entreprise_creee", "election_gagnee", "expatriation"}
PROCHE_TAG = {"mere": "mother", "pere": "father", "parent": "parents", "fratrie": "siblings", "partenaire": "partner",
              "enfant": "children", "ami": "friend", "grandparent": "grandparents", "ex": "ex"}
REGLE = {"id", "on", "choice", "outcome", "chance", "delay", "patience", "unique", "minAge", "maxAge", "conditions",
         "requires", "remember", "forget", "emit", "setFlags", "clearFlags", "text", "effects", "choices"}

erreurs = []


def tag_ok(t):
    return t in ve.TAGS or t.startswith(ve.TAG_PREFIXES) or t.startswith("reve_") or ve.LOISIRS_TAG.match(t)


def check_conditions(c, w, cles=None):
    for k, v in (c or {}).items():
        if k not in (cles or ve.COND):
            erreurs.append(f"{w}: condition inconnue {k}")
        elif k in ("tags", "excludeTags"):
            for t in v or []:
                if not tag_ok(t):
                    erreurs.append(f"{w}: tag inconnu {t}")


def textes(obj):
    """Tous les textes d'un objet (texte, labels, issues)."""
    out = [obj.get("text", ""), obj.get("ligne", "") or ""]
    for c in obj.get("choices") or []:
        out.append(c.get("label", ""))
        out += [o.get("text", "") for o in c.get("outcomes") or []]
    return out


def check_proches(obj, tags, w, tags_choix=None):
    for texte in textes(obj):
        for p in re.findall(r"\{(\w+)\}", texte):
            besoin = PROCHE_TAG.get(p)
            if besoin and besoin not in tags and not (p == "parent" and ({"mother", "father"} & tags)):
                erreurs.append(f"{w}: {{{p}}} sans le tag {besoin}")


def check_choix(choices, w, projet=False):
    if not choices or not 2 <= len(choices) <= 4:
        erreurs.append(f"{w}: il faut 2 à 4 choix")
    for ci, c in enumerate(choices or []):
        cw = f"{w}/choix{ci}"
        ve.check_text(c.get("label"), cw, erreurs)
        outs = c.get("outcomes") or []
        if not outs:
            erreurs.append(f"{cw}: aucune issue")
        if abs(sum(o.get("chance", 0) for o in outs) - 1) > 0.011:
            erreurs.append(f"{cw}: somme des chances différente de 1")
        for oi, o in enumerate(outs):
            ve.check_text(o.get("text"), f"{cw}/o{oi}", erreurs)
            ve.check_effects(o.get("effects", {}), f"{cw}/o{oi}", erreurs)
            if projet:
                p = o.get("progres", 0)
                if not isinstance(p, int) or not -1 <= p <= 3:
                    erreurs.append(f"{cw}/o{oi}: progres entre -1 et 3")
                for k in o:
                    if k not in {"chance", "text", "effects", "progres", "abandon"}:
                        erreurs.append(f"{cw}/o{oi}: champ inconnu {k}")


def lire(chemin):
    try:
        return json.load(open(chemin, encoding="utf-8"))
    except Exception as ex:  # noqa: BLE001
        erreurs.append(f"{chemin}: JSON invalide : {ex}")
        return []


def main():
    # 1. Événements classiques : le validateur commun.
    fichiers = sorted(glob.glob(os.path.join(DATA, "Events", "vivant_*.json")))
    if fichiers:
        r = subprocess.run([sys.executable, os.path.join(ICI, "validate_events.py")] + fichiers, capture_output=True, text=True)
        print(r.stdout.strip().splitlines()[-1] if r.stdout.strip() else r.stderr)
        if r.returncode:
            erreurs.extend(l for l in r.stdout.splitlines() if l.startswith("ERREUR"))
        for f in fichiers:
            for e in lire(f):
                tags = set((e.get("conditions") or {}).get("tags") or [])
                check_proches(e, tags, f"{os.path.basename(f)}:{e.get('id')}")
                if not e.get("id", "").startswith("viv_"):
                    erreurs.append(f"{f}:{e.get('id')}: les ids du module commencent par viv_")

    # 2. Suites rep_viv_.
    ids = set()
    n_regles = 0
    for f in sorted(glob.glob(os.path.join(DATA, "Repercussions", "vivant_*.json"))):
        for r in lire(f):
            n_regles += 1
            w = f"{os.path.basename(f)}:{r.get('id')}"
            if not re.match(r"^rep_viv_\d{4}$", r.get("id", "")):
                erreurs.append(f"{w}: id invalide (rep_viv_NNNN)")
            if r.get("id") in ids:
                erreurs.append(f"{w}: id en double")
            ids.add(r.get("id"))
            for k in r:
                if k not in REGLE:
                    erreurs.append(f"{w}: champ inconnu {k}")
            on = r.get("on", "")
            if not on.startswith("event:") and on not in SIGNAUX:
                erreurs.append(f"{w}: signal inconnu {on}")
            check_conditions(r.get("conditions"), w, ve.COND | {"minCounters", "maxCounters"})
            ve.check_text(r.get("text"), w, erreurs)
            if r.get("choices"):
                check_choix(r["choices"], w)
            elif r.get("effects"):
                ve.check_effects(r["effects"], w, erreurs)
            tags = set((r.get("conditions") or {}).get("tags") or [])
            check_proches(r, tags, w)
            d = r.get("delay", [1, 1])
            if not (isinstance(d, list) and 1 <= len(d) <= 2 and all(isinstance(x, int) and x >= 0 for x in d)):
                erreurs.append(f"{w}: delay invalide")

    # 3. Anniversaires.
    n_anniv = 0
    vus = set()
    for f in sorted(glob.glob(os.path.join(DATA, "VivantAnniversaires", "*.json"))):
        for a in lire(f):
            n_anniv += 1
            w = f"{os.path.basename(f)}:{a.get('id')}"
            if not re.match(r"^viv_anv_\d{4}$", a.get("id", "")) or a.get("id") in vus:
                erreurs.append(f"{w}: id invalide ou en double")
            vus.add(a.get("id"))
            if a.get("jalon") not in JALONS:
                erreurs.append(f"{w}: jalon inconnu {a.get('jalon')}")
            if not a.get("annees") or not all(isinstance(x, int) and x > 0 for x in a["annees"]):
                erreurs.append(f"{w}: annees invalides")
            if a.get("jalon") not in JALONS_NOMMES and any("{jalon_nom}" in t for t in textes(a)):
                erreurs.append(f"{w}: {{jalon_nom}} sur un jalon sans nom")
            check_conditions(a.get("conditions"), w)
            ve.check_text(a.get("text"), w, erreurs)
            if a.get("ligne"):
                ve.check_text(a["ligne"], w + "/ligne", erreurs)
            if a.get("choices"):
                check_choix(a["choices"], w)
            tags = set((a.get("conditions") or {}).get("tags") or [])
            check_proches(a, tags, w)

    # 4. Projets.
    n_proj = 0
    for f in sorted(glob.glob(os.path.join(DATA, "VivantProjets", "*.json"))):
        for p in lire(f):
            n_proj += 1
            w = f"{os.path.basename(f)}:{p.get('id')}"
            if not re.match(r"^[a-z0-9_]+$", p.get("id", "")) or "." in p.get("id", ""):
                erreurs.append(f"{w}: id invalide")
            for k in ("nom", "description", "etapes", "fins"):
                if k not in p:
                    erreurs.append(f"{w}: champ manquant {k}")
            check_conditions(p.get("conditions"), w)
            tags_p = set((p.get("conditions") or {}).get("tags") or [])
            if p.get("competence") and p["competence"] not in ve.SKILLS:
                erreurs.append(f"{w}: compétence inconnue {p['competence']}")
            etapes = p.get("etapes") or []
            if not 3 <= len(etapes) <= 5:
                erreurs.append(f"{w}: 3 à 5 étapes")
            for ei, e in enumerate(etapes):
                ew = f"{w}/etape{ei}"
                ve.check_text(e.get("text"), ew, erreurs)
                check_proches({"text": e.get("text", "")}, tags_p, ew)
                check_choix(e.get("choices"), ew, projet=True)
                libres = [c for c in e.get("choices") or [] if not c.get("requiresTags") and not c.get("requiresSkill")]
                if len(libres) < 2:
                    erreurs.append(f"{ew}: au moins 2 choix sans requiresTags ni requiresSkill")
                for ci, c in enumerate(e.get("choices") or []):
                    check_proches({"choices": [c]}, tags_p | set(c.get("requiresTags") or []), f"{ew}/choix{ci}")
            for fin in ("reussite", "moyen", "echec"):
                x = (p.get("fins") or {}).get(fin)
                if not x:
                    erreurs.append(f"{w}: fin {fin} manquante")
                    continue
                ve.check_text(x.get("text"), f"{w}/{fin}", erreurs)
                ve.check_effects(x.get("effects", {}), f"{w}/{fin}", erreurs)

    for e in erreurs:
        print("ERREUR", e)
    print(f"{n_regles} suites rep_viv_, {n_anniv} anniversaires, {n_proj} projets, {len(erreurs)} erreurs")
    sys.exit(1 if erreurs else 0)


if __name__ == "__main__":
    main()
