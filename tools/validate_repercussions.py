#!/usr/bin/env python3
"""Vérifie les fichiers de FTCHTLife/Resources/Data/Repercussions/*.json (format : docs/REPERCUSSIONS.md).

Usage : python3 tools/validate_repercussions.py [fichiers...]
Code de sortie 1 s'il y a des erreurs. Les avertissements n'échouent pas.
"""
import glob
import json
import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOSSIER = os.path.join(RACINE, "FTCHTLife", "Resources", "Data", "Repercussions")
EVENTS = os.path.join(RACINE, "FTCHTLife", "Resources", "Data", "Events")

CHAMPS = {"id", "category", "on", "choice", "outcome", "chance", "delay", "patience", "unique", "minAge", "maxAge",
          "conditions", "requires", "remember", "forget", "emit", "setFlags", "clearFlags", "text", "effects", "choices"}
CONDITIONS = {"gender", "minMoney", "maxMoney", "requiresJob", "requiresPartner", "requiresSchool", "tags",
              "excludeTags", "flags", "excludeFlags", "minCounters", "maxCounters", "flagMinYears", "flagMaxYears"}
REQUIRES = {"flags", "excludeFlags", "minCounters", "maxCounters", "flagMinYears", "flagMaxYears"}
EFFETS = {"happiness", "health", "smarts", "looks", "karma", "money", "stress", "fame", "relationships",
          "newFriend", "death", "setFlags", "clearFlags", "followUps",
          "vie"}  # "vie" : sous-objet du module amour/crime/santé, vérifié par son propre validateur
RELATIONS = {"mother", "father", "parent", "sibling", "friend", "partner", "child"}
TAGS = {"male", "female", "baby", "school", "university", "job", "adult", "unemployed", "retired", "rich",
        "poor", "friend", "mother", "father", "siblings", "partner", "children", "sick", "attractive", "smart",
        # module permis
        "permis_voiture", "permis_moto", "permis_poids_lourd", "licence_pilote", "conducteur", "sans_permis",
        "permis_suspendu", "permis_annule", "permis_probatoire", "permis_points_bas", "conduit_sans_permis",
        "faux_permis", "pilote", "chasseur", "chauffard"}
VARIABLES = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e",
             "enfant", "ex", "grandparent"}  # module vie
# Le Milieu : crime organisé (docs/donnees-vie-sociale.md)
TAGS |= {"prison", "gang", "gang_haut", "dealer", "sous_enquete", "chaleur", "ancien_gang", "balance", "argent_sale"}
VARIABLES |= {"organisation", "chef", "rival", "rang"}
SIGNAUX = set("""
rencontre rendez_vous rendez_vous_rate couple rupture largue tromperie tromperie_decouverte demande_mariage
demande_refusee mariage divorce veuvage grossesse naissance_enfant adoption enfant_majeur enfant_quitte_maison
casino_gain casino_perte casino_jackpot casino_ruine casino_triche casino_triche_attrape loterie_ticket loterie_gain
pari_sportif_gain pari_sportif_perte randonnee randonnee_sommet randonnee_perdu randonnee_blessure randonnee_animal
camping permis_code_obtenu permis_code_rate permis_obtenu permis_rate permis_retire amende_vitesse accident_voiture
achat_voiture crime_reussi crime_rate arrestation proces_gagne proces_perdu prison_entree prison_sortie evasion
bac_obtenu bac_rate diplome abandon_etudes embauche promotion licenciement demission retraite deces_parent
deces_proche heritage maladie guerison chirurgie_esthetique hopital achat_maison demenagement gros_achat faillite
voyage celebrite fiancailles_rompues addiction cure_desintox meilleur_ami
permis_suspendu permis_annule permis_points_recuperes faux_permis_achete faux_permis_demasque
conduite_sans_permis_arretee corruption_examinateur corruption_ratee casino_usurier casino_usurier_violence
vie_suite chaque_annee
""".split())
SIGNAUX |= set("""gang_entree gang_promotion gang_trahison gang_sortie gang_chef trafic_debut trafic_saisie
enquete_ouverte enquete_classee guerre_territoire blanchiment balance mission_reussie mission_ratee""".split())
ACTIVITES = """randonnee camping peche escalade ski kayak champignons salle_sport course natation velo yoga danse
meditation spa cinema restaurant concert soiree jardinage cuisine jeux_video voyage""".split()
ISSUES = ["", "_sommet", "_perdu", "_blessure", "_animal", "_rencontre", "_honte", "_victoire", "_casse", "_arnaque"]
SIGNAUX |= {a + i for a in ACTIVITES for i in ISSUES}
RE_FLAG = re.compile(r"^[a-z0-9_]+$")
RE_ID = re.compile(r"^rep_[a-z_]+_\d{4}$")


def charger_evenements():
    evts = {}
    for f in glob.glob(os.path.join(EVENTS, "*.json")):
        try:
            for e in json.load(open(f, encoding="utf-8")):
                evts[e.get("id")] = e
        except Exception:
            pass
    return evts


def verifier_texte(t, ou, erreurs):
    for v in re.findall(r"\{([^}]*)\}", t):
        if v not in VARIABLES:
            erreurs.append(f"{ou} : variable inconnue {{{v}}}")


def verifier_effets(eff, ou, erreurs, ids):
    if not isinstance(eff, dict):
        erreurs.append(f"{ou} : effects doit être un objet")
        return
    for k, v in eff.items():
        if k not in EFFETS:
            erreurs.append(f"{ou} : effet inconnu « {k} »")
        elif k == "vie":
            if not isinstance(v, dict):
                erreurs.append(f"{ou} : vie doit être un objet")
        elif k == "relationships":
            for r in v:
                if r not in RELATIONS:
                    erreurs.append(f"{ou} : relation inconnue « {r} »")
        elif k in ("setFlags", "clearFlags"):
            for f in v:
                if not RE_FLAG.match(f):
                    erreurs.append(f"{ou} : drapeau mal formé « {f} »")
        elif k == "followUps":
            for i in v:
                if i not in ids:
                    erreurs.append(f"{ou} : followUps vers une suite inconnue « {i} »")
        elif k in ("newFriend",):
            if not isinstance(v, bool):
                erreurs.append(f"{ou} : newFriend doit être true/false")
        elif k == "death":
            if not isinstance(v, str):
                erreurs.append(f"{ou} : death doit être un texte")
        elif not isinstance(v, int):
            erreurs.append(f"{ou} : {k} doit être un entier")


AVERT = []


def verifier_conditions(c, ou, erreurs, autorises):
    if not isinstance(c, dict):
        erreurs.append(f"{ou} : doit être un objet")
        return
    for k, v in c.items():
        if k not in autorises:
            erreurs.append(f"{ou} : champ inconnu « {k} »")
        elif k in ("tags", "excludeTags"):
            for t in v or []:
                if t not in TAGS:
                    # Les modules ajoutent leurs propres tags (prison, origine_<pays>…) : simple avertissement.
                    AVERT.append(f"{ou} : tag « {t} » hors de la liste de base (tag de module ?)")
        elif k in ("flags", "excludeFlags"):
            for f in v or []:
                if not RE_FLAG.match(f):
                    erreurs.append(f"{ou} : drapeau mal formé « {f} »")
        elif k in ("minCounters", "maxCounters", "flagMinYears", "flagMaxYears"):
            if not isinstance(v, dict) or not all(isinstance(n, int) for n in v.values()):
                erreurs.append(f"{ou} : {k} doit être un objet signal → entier")
        elif k == "gender" and v not in (None, "any", "male", "female"):
            erreurs.append(f"{ou} : gender invalide « {v} »")


def main(fichiers):
    fichiers = fichiers or sorted(glob.glob(os.path.join(DOSSIER, "*.json")))
    erreurs, avertissements = [], []
    regles = []
    for f in fichiers:
        try:
            data = json.load(open(f, encoding="utf-8"))
        except Exception as ex:
            erreurs.append(f"{os.path.basename(f)} : JSON invalide ({ex})")
            continue
        if not isinstance(data, list):
            erreurs.append(f"{os.path.basename(f)} : doit contenir un tableau")
            continue
        regles += [(os.path.basename(f), r) for r in data]

    evts = charger_evenements()
    ids = {}
    for nom, r in regles:
        i = r.get("id", "?")
        if i in ids:
            erreurs.append(f"{nom}/{i} : id en double (aussi dans {ids[i]})")
        ids[i] = nom
        if i in evts:
            erreurs.append(f"{nom}/{i} : id déjà utilisé par un événement")

    for nom, r in regles:
        i = r.get("id", "?")
        ou = f"{nom}/{i}"
        for k in r:
            if k not in CHAMPS:
                erreurs.append(f"{ou} : champ inconnu « {k} »")
        if not RE_ID.match(i):
            erreurs.append(f"{ou} : id doit ressembler à rep_<theme>_0001")
        on = r.get("on")
        if not isinstance(on, str) or not on:
            erreurs.append(f"{ou} : « on » manquant")
            continue
        cible = None
        if on.startswith("event:"):
            eid = on[6:]
            if eid in evts:
                cible = evts[eid]
            elif eid in ids:
                cible = next(x for _, x in regles if x.get("id") == eid)
            else:
                avertissements.append(f"{ou} : événement « {eid} » introuvable (pas encore écrit ?)")
        else:
            if r.get("choice") is not None or r.get("outcome") is not None:
                erreurs.append(f"{ou} : choice/outcome seulement pour un signal event:")
            if on not in SIGNAUX:
                avertissements.append(f"{ou} : signal « {on} » absent de la liste de docs/REPERCUSSIONS.md")
        if cible is not None:
            ch = cible.get("choices") or []
            c = r.get("choice")
            if c is not None:
                if not ch or not (0 <= c < len(ch)):
                    erreurs.append(f"{ou} : choice {c} n'existe pas dans {on}")
                else:
                    o = r.get("outcome")
                    if o is not None and not (0 <= o < len(ch[c].get("outcomes", []))):
                        erreurs.append(f"{ou} : outcome {o} n'existe pas dans {on} choix {c}")
            elif r.get("outcome") is not None:
                erreurs.append(f"{ou} : outcome sans choice")
        ch = r.get("chance")
        if ch is not None and not (isinstance(ch, (int, float)) and 0 < ch <= 1):
            erreurs.append(f"{ou} : chance doit être entre 0 et 1")
        d = r.get("delay")
        if d is not None and not (isinstance(d, list) and 1 <= len(d) <= 2 and all(isinstance(x, int) and x >= 0 for x in d)
                                  and (len(d) == 1 or d[0] <= d[1])):
            erreurs.append(f"{ou} : delay doit être [min, max] avec 0 ≤ min ≤ max")
        if "conditions" in r:
            verifier_conditions(r["conditions"], ou + " conditions", erreurs, CONDITIONS)
        if "requires" in r:
            verifier_conditions(r["requires"], ou + " requires", erreurs, REQUIRES)
        for k in ("remember", "forget", "setFlags", "clearFlags"):
            for f in r.get(k) or []:
                if not RE_FLAG.match(f):
                    erreurs.append(f"{ou} : drapeau mal formé « {f} »")
        for sig in r.get("emit") or []:
            if sig not in SIGNAUX:
                avertissements.append(f"{ou} : emit vers un signal absent de la liste « {sig} »")
            if sig == on:
                erreurs.append(f"{ou} : emit ne peut pas réémettre son propre signal")
        texte = r.get("text")
        if texte is None:
            if r.get("effects") or r.get("choices"):
                erreurs.append(f"{ou} : effects/choices sans text")
            if not (r.get("remember") or r.get("forget") or r.get("setFlags") or r.get("clearFlags") or r.get("emit")):
                erreurs.append(f"{ou} : règle vide (ni texte ni drapeau)")
        else:
            verifier_texte(texte, ou, erreurs)
        if "effects" in r:
            verifier_effets(r["effects"], ou, erreurs, ids)
        for ci, c in enumerate(r.get("choices") or []):
            if not c.get("label"):
                erreurs.append(f"{ou} choix {ci} : label manquant")
            verifier_texte(c.get("label", ""), ou, erreurs)
            if not c.get("outcomes"):
                erreurs.append(f"{ou} choix {ci} : outcomes manquant")
            for oi, o in enumerate(c.get("outcomes") or []):
                if "text" not in o:
                    erreurs.append(f"{ou} choix {ci} issue {oi} : text manquant")
                verifier_texte(o.get("text", ""), ou, erreurs)
                if "effects" in o:
                    verifier_effets(o["effects"], f"{ou} choix {ci} issue {oi}", erreurs, ids)
        if r.get("choices") and r.get("effects"):
            erreurs.append(f"{ou} : effects à la racine ET choices (mettre les effets dans les issues)")

    avertissements += AVERT
    for a in avertissements:
        print("avertissement :", a)
    for e in erreurs:
        print("ERREUR :", e)
    print(f"{len(regles)} suites, {len(erreurs)} erreurs, {len(avertissements)} avertissements")
    return 1 if erreurs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
