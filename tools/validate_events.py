#!/usr/bin/env python3
"""Valide tous les fichiers FTCHTLife/Resources/Data/Events/*.json. Usage: python3 tools/validate_events.py [fichiers...]"""
import json, sys, glob, os, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATS = {"happiness","health","smarts","looks","money","karma","stress","fame"}
REL = {"mother","father","parent","sibling","friend","partner","child"}
TAGS = {"male","female","baby","school","university","job","adult","unemployed","retired","rich","poor","friend","mother","father","siblings","partner","children","sick","attractive","smart"}
SPECIAL = {"death","newFriend","relationships","setFlags","skills"}
SKILLS = {"anglais","espagnol","allemand","italien","albanais","japonais","guitare","piano","chant","danse","dessin","photo","cuisine","bricolage","mecanique","jardinage","sport","survie","code","echecs","seduction","eloquence","humour","marchandage","magie"}
# Tags du module Permis (PermisModule.tags, docs/PERMIS.md)
TAGS |= {"permis_scooter","permis_voiture","permis_moto","permis_poids_lourd","permis_bus","permis_bateau","licence_pilote","licence_helico","permis_chasse","permis_armes","carte_peche","brevet_drone","permis_fusee","conducteur","sans_permis","permis_probatoire","permis_points_bas","permis_suspendu","permis_annule","conduit_sans_permis","faux_permis","pilote","chasseur","chauffard"}
# Tags posés par le module Placements (PlacementsMoteur.tags)
TAGS |= {"investisseur","crypto","proprietaire_bailleur","epargnant","ruine_crypto"}
# Étiquettes ajoutées par le module casino (CasinoSysteme.tags).
TAGS |= {"gambled","gambler","gambling_addict","gambler_recovering","casino_debt","casino_vip","casino_banned","casino_winner","casino_ruined"}
SPECIAL = {"death","newFriend","relationships","setFlags"}
SPECIAL = {"death","newFriend","relationships","setFlags","dreamMarks"}  # dreamMarks : voir docs/reves-format.md
PH = {"prenom","nom","ville","mere","pere","parent","ami","fratrie","partenaire","metier","e"}
COND = {"gender","minMoney","maxMoney","requiresJob","requiresPartner","requiresSchool","tags","excludeTags","flags","excludeFlags","skills"}
TAGS = {"male","female","baby","school","university","job","adult","unemployed","retired","rich","poor","friend","mother","father","siblings","partner","children","sick","attractive","smart",
        # module vie (FTCHTLife/Systems/VieSysteme.swift, tags)
        "prison","record","malade","bien_portant","addiction","pregnant","ex","parents","grandparents","grandchildren","dating","engaged","married","single"}
SPECIAL = {"death","newFriend","relationships","setFlags","clearFlags","followUps","vie"}
PH = {"prenom","nom","ville","mere","pere","parent","ami","fratrie","partenaire","metier","e","enfant","ex","codetenu","grandparent"}
COND = {"gender","minMoney","maxMoney","requiresJob","requiresPartner","requiresSchool","tags","excludeTags","flags","excludeFlags"}
SPECIAL = {"death","newFriend","relationships","setFlags","skills"}  # skills : docs/COMPETENCES.md
def check_effects(e, where, errs):
    if not isinstance(e, dict): errs.append(f"{where}: effects pas un objet"); return
    for k,v in e.items():
        if k in STATS:
            if not isinstance(v,int) or isinstance(v,bool): errs.append(f"{where}: {k} doit être un entier")
            elif k!="money" and abs(v)>100: errs.append(f"{where}: {k} hors bornes")
        elif k == "relationships":
            if not isinstance(v, dict) or any(r not in REL for r in v): errs.append(f"{where}: relationships invalide {v}")
        elif k == "skills":
            if not isinstance(v, dict) or any(x not in SKILLS for x in v): errs.append(f"{where}: skills invalide {v}")
        elif k not in SPECIAL: errs.append(f"{where}: clé d'effet inconnue {k}")
def check_text(t, where, errs):
    if not isinstance(t,str) or not t.strip(): errs.append(f"{where}: texte vide"); return
    m = re.search(r"\b\w*(x|f|er|et|en|on|el)\{e\}", t)
    if m: errs.append(f"{where}: accord {{e}} incorrect sur « {m.group(0)} » (reformule)")
    m2 = re.search(r"\{(ami|fratrie|mere|pere|parent|partenaire)\}([^.!?]{0,25})\{e\}", t)
    if m2 and not re.search(r"\bt'|\bte\b|\btoi\b|\bt’", m2.group(2)): errs.append(f"{where}: {{e}} semble porter sur un autre personnage que le joueur")
    for p in re.findall(r"\{(\w+)\}", t):
        if p not in PH: errs.append(f"{where}: placeholder inconnu {{{p}}}")
def main():
    files = sys.argv[1:] or sorted(glob.glob(os.path.join(ROOT,"FTCHTLife/Resources/Data/Events/*.json")))
    ids, errs, n = {}, [], 0
    for f in files:
        try: data = json.load(open(f, encoding="utf-8"))
        except Exception as ex: errs.append(f"{f}: JSON invalide: {ex}"); continue
        if not isinstance(data, list): errs.append(f"{f}: pas un tableau"); continue
        for ev in data:
            n += 1; i = ev.get("id","?"); w=f"{os.path.basename(f)}:{i}"
            for k in ("id","category","minAge","maxAge","weight","text","choices"):
                if k not in ev: errs.append(f"{w}: champ manquant {k}")
            if i in ids: errs.append(f"{w}: id dupliqué (aussi dans {ids[i]})")
            ids[i]=os.path.basename(f)
            if not (0 <= ev.get("minAge",0) <= ev.get("maxAge",0) <= 120): errs.append(f"{w}: âges invalides")
            for k in (ev.get("conditions") or {}):
                if k not in COND: errs.append(f"{w}: condition inconnue {k}")
                elif k in ("tags","excludeTags"):
                    for t in ev["conditions"][k] or []:
                        if t not in TAGS and not t.startswith("reve_"): errs.append(f"{w}: tag inconnu {t}")
            check_text(ev.get("text"), w, errs)
            ch = ev.get("choices", [])
            if not ch:
                check_effects(ev.get("effects", {}), w, errs)
                if "resultText" in ev: errs.append(f"{w}: resultText non supporté, mets le texte dans text")
            if len(ch) > 4: errs.append(f"{w}: plus de 4 choix")
            if ch and all(c.get("requiresSkill") for c in ch): errs.append(f"{w}: au moins un choix doit être sans requiresSkill")
            for ci,c in enumerate(ch):
                cw=f"{w}/choix{ci}"; check_text(c.get("label"), cw, errs)
                rs=c.get("requiresSkill")
                if rs is not None and (not isinstance(rs,dict) or any(x not in SKILLS or not 1<=n<=5 for x,n in rs.items())): errs.append(f"{cw}: requiresSkill invalide {rs}")
                outs=c.get("outcomes") or []
                if not outs: errs.append(f"{cw}: aucun outcome")
                s=sum(o.get("chance",0) for o in outs)
                if abs(s-1)>0.011: errs.append(f"{cw}: somme des chances = {s}")
                for oi,o in enumerate(outs):
                    check_text(o.get("text"), f"{cw}/o{oi}", errs); check_effects(o.get("effects",{}), f"{cw}/o{oi}", errs)
    for e in errs[:200]: print("ERREUR", e)
    print(f"{n} événements, {len(files)} fichiers, {len(errs)} erreurs")
    sys.exit(1 if errs else 0)
if __name__=="__main__": main()
