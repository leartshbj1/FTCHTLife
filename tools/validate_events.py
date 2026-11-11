#!/usr/bin/env python3
"""Valide tous les fichiers FTCHTLife/Resources/Data/Events/*.json. Usage: python3 tools/validate_events.py [fichiers...]"""
import json, sys, glob, os, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATS = {"happiness","health","smarts","looks","money","karma","stress","fame"}
REL = {"mother","father","parent","sibling","friend","partner","child"}
TAGS = {"male","female","baby","school","university","job","adult","unemployed","retired","rich","poor","friend","mother","father","siblings","partner","children","sick","attractive","smart"}
SPECIAL = {"death","newFriend","relationships","setFlags","skills","clearFlags","followUps","vie","casier","familyRep","dreamMarks"}
SKILLS = {"anglais","espagnol","allemand","italien","albanais","japonais","guitare","piano","chant","danse","dessin","photo","cuisine","bricolage","mecanique","jardinage","sport","survie","code","echecs","seduction","eloquence","humour","marchandage","magie"}
# Tags du module Permis (PermisModule.tags, docs/PERMIS.md)
TAGS |= {"permis_scooter","permis_voiture","permis_moto","permis_poids_lourd","permis_bus","permis_bateau","licence_pilote","licence_helico","permis_chasse","permis_armes","carte_peche","brevet_drone","permis_fusee","conducteur","sans_permis","permis_probatoire","permis_points_bas","permis_suspendu","permis_annule","conduit_sans_permis","faux_permis","pilote","chasseur","chauffard"}
# Tags posés par le module Placements (PlacementsMoteur.tags)
TAGS |= {"investisseur","crypto","proprietaire_bailleur","epargnant","ruine_crypto"}
# Étiquettes ajoutées par le module casino (CasinoSysteme.tags).
TAGS |= {"gambled","gambler","gambling_addict","gambler_recovering","casino_debt","casino_vip","casino_banned","casino_winner","casino_ruined"}
# Tags du module Retraite (RetraiteSysteme.tags, voir docs/RETRAITE.md).
TAGS |= {"maison_retraite","maison_retraite_imposee","en_cavale","romance_residence","grand_parent","petits_enfants_absents","senior_voyageur","champion_loto"}
# Tags du module Testament et héritage (docs/SUCCESSION.md)
TAGS |= {"testament","testament_secret","testament_annonce","heritier","heritier_en_guerre","desherite","a_herite_gros"} | {"testament_"+b for b in ("egal","enfant","partenaire","chat","oeuvre","personne","inconnu","ami","aucun")}
# Tags ajoutés par le module Loisirs (docs/LOISIRS.md).
LOISIRS_TAG = re.compile(r"^((pratique|habitue)_[a-z0-9_]+|sportif|blesse|abonne|aventurier|trophee)$")
# Tags du module « Vivre à l'étranger » (docs/ETRANGER_EVENTS.md), plus pays_xx, loi_xx, zone_xx.
TAGS |= {"etranger","expat_nouveau","expat_installe","langue_faible","bilingue","polyglotte","binational","de_retour"}
# Train de vie (Engine/Coherence.swift, tagsTrainDeVie).
TAGS |= {"millionaire","milliardaire","endette","gros_salaire","petit_salaire","chez_parents","locataire","proprietaire","voiture","voiture_luxe","moto","bateau","avion_prive","bijoux","collection_art","multi_proprietaire","vie_de_luxe","grand_voyageur"}
# Easter egg « Leart et Shkurta » (FTCHTLife/AmeSoeur, docs/AME_SOEUR.md).
TAGS |= {"ame_soeur","ame_soeur_leart","ame_soeur_shkurta"}
TAGS |= {"pol_ancien","pol_candidat","pol_chef_parti","pol_elu","pol_gouverne","pol_militant","pol_scandale"}
TAG_PREFIXES = ("pays_","loi_","zone_","origine_","famille_")
# Modules Casier et Réputation familiale.
TAGS |= {"casier","tig","casier_lourd","casier_efface"}
SPECIAL |= {"death","newFriend","relationships","setFlags"}
SPECIAL |= {"death","newFriend","relationships","setFlags","dreamMarks"}  # dreamMarks : voir docs/reves-format.md
PH = {"prenom","nom","ville","mere","pere","parent","ami","fratrie","partenaire","metier","e","ancetre"}
COND = {"gender","minMoney","maxMoney","requiresJob","requiresPartner","requiresSchool","tags","excludeTags","flags","excludeFlags","skills"}
TAGS |= {"male","female","baby","school","university","job","adult","unemployed","retired","rich","poor","friend","mother","father","siblings","partner","children","sick","attractive","smart",
        # module vie (FTCHTLife/Systems/VieSysteme.swift, tags)
        "prison","record","malade","bien_portant","addiction","pregnant","ex","parents","grandparents","grandchildren","dating","engaged","married","single"}
SPECIAL |= {"death","newFriend","relationships","setFlags","clearFlags","followUps","vie"}
PH |= {"prenom","nom","ville","mere","pere","parent","ami","fratrie","partenaire","metier","e","enfant","ex","codetenu","grandparent"}
COND |= {"gender","minMoney","maxMoney","requiresJob","requiresPartner","requiresSchool","tags","excludeTags","flags","excludeFlags"}
SPECIAL |= {"death","newFriend","relationships","setFlags","skills"}  # skills : docs/COMPETENCES.md
# Module entourage (docs/ENTOURAGE.md) : tags EntourageTags.tags et sous-objet "entourage".
TAGS |= {"couple_2ans","couple_5ans","enfant_bebe","enfant_petit","enfant_ado","enfant_adulte","parent_age","parent_tres_age","poste_nouveau","poste_ancien","carriere"}
SPECIAL |= {"entourage"}
ENTOURAGE = {"fiancailles","mariage","offreEmploi","niveau","salaireBonus","demission","signaux"}
def _metiers():
    ids, secteurs = set(), set()
    for f in glob.glob(os.path.join(ROOT, "FTCHTLife/Resources/Data/Careers/*.json")):
        for c in json.load(open(f, encoding="utf-8")):
            ids.add(c["id"]); secteurs.add(c["sector"])
    return ids, secteurs
METIERS, SECTEURS = _metiers()
def check_entourage(v, where, errs):
    if not isinstance(v, dict): errs.append(f"{where}: entourage doit être un objet"); return
    for k in v:
        if k not in ENTOURAGE: errs.append(f"{where}: clé entourage inconnue {k}")
    o = v.get("offreEmploi")
    if o is not None:
        if o.startswith("secteur:"):
            if o[8:] not in SECTEURS: errs.append(f"{where}: secteur inconnu {o}")
        elif o not in ("auto", "meme_secteur") and o not in METIERS: errs.append(f"{where}: métier inconnu {o}")
# Module Jeu vivant (docs/VIVANT.md) : tags des autres modules utilisés par ses événements, et les siens.
TAG_PREFIXES += ("pol_", "tv_", "secteur_", "metier_")
TAGS |= {"entrepreneur","patron","magnat","ancien_entrepreneur","failli","phone","influencer","star_reseaux","bad_buzz","sponsorise",
         "mandat_debut","mandat_installe","bateau_oublie","avion_oublie","projet_en_cours","notable"}
# Le Milieu : crime organisé (docs/donnees-vie-sociale.md)
TAGS |= {"gang","gang_haut","dealer","sous_enquete","chaleur","ancien_gang","balance","argent_sale"}
PH |= {"organisation","chef","rival","rang"}
# Module Cœur (docs/COEUR.md) : liaisons, tromperies, enfants cachés, crises de couple ; tags réseaux (docs/PHONE.md).
TAGS |= {"liaison","liaison_longue","liaison_ultimatum","liaison_soupcon","liaison_hetero","ancien_amant","grossesse_liaison",
         "enfant_cache","enfant_cache_adulte","paternite_douteuse","partenaire_infidele","soupcon_partenaire","trahi",
         "crise_couple","therapie_couple","relation_libre","ecart_secret","infidele","infidele_recidiviste",
         "voustubeur","tiktaceur","onlyfesses","onlyfesses_star","onlyfesses_ancien","onlyfesses_connu"}
SPECIAL |= {"coeur"}
PH |= {"amant","amant_role","amant_il","enfant_cache"}
TAGS |= {"couple_recent","couple_fertile"}
# Actions de couple : contraception, couple installé (docs/COEUR.md).
TAGS |= {"couple_installe","couple_10ans","contraception_possible","contraception","contraception_pilule","contraception_sterilet",
         "contraception_implant","contraception_preservatif","couple_fertile_protege"}
COEUR = {"ecart":bool,"liaison":str,"via":str,"intensite":int,"soupcon":int,"decouverte":bool,"grossesse":bool,"enfantCache":str,
         "partenaireInfidele":bool,"soupconJoueur":int,"trahisonDecouverte":bool,"pardon":bool,"crise":int,"therapie":int,
         "relationLibre":bool,"scandale":int,"lienCible":int,"contraception":str,"rupture":bool}
COEUR_VALEURS = {"liaison":{"debut","fin","officialiser","avouer"},
                 "via":{"travail","ex","soiree","ami","voyage","sport","voisin","pecho","reseaux","fan","autre"},
                 "enfantCache":{"reconnaitre","pension","cacher","reveler"},
                 "contraception":{"pilule","sterilet","implant","preservatif","aucune"}}
def check_coeur(v, where, errs):
    if not isinstance(v, dict): errs.append(f"{where}: coeur doit être un objet"); return
    for k, x in v.items():
        if k not in COEUR: errs.append(f"{where}: clé coeur inconnue {k}"); continue
        if not isinstance(x, COEUR[k]) or (COEUR[k] is int and isinstance(x, bool)): errs.append(f"{where}: coeur.{k} mauvais type")
        elif k in COEUR_VALEURS and x not in COEUR_VALEURS[k]: errs.append(f"{where}: coeur.{k} valeur inconnue {x}")
# Module Beauté (docs/BEAUTE.md) : tags beaute_* (BeauteMoteur.tags) et sous-objet "beaute" des effets.
TAG_PREFIXES += ("beaute_",)
SPECIAL |= {"beaute"}
# Secte et agence de détective (docs/SECTE_DETECTIVE.md)
TAGS |= {"gourou","secte_communaute","secte_grande","secte_enquete","ancien_gourou","proche_dans_secte","detective","detective_celebre","detective_clandestin","ancien_detective"}
# Le Milieu, trafic et coups (vie4_trafic.json)
TAGS |= {"dealer_gros","guerre_prix","rupture_stock","independant","coup_prepare","braqueur","a_revendeurs","produit_drogue"}
PH |= {"produit","zone","concurrent"}
# Protection contre la police, enquête par étapes, façades, fuite à l'étranger, trafic international (vie5_protection_international.json)
TAGS |= {"protege","avocat_attitre","profil_bas","international","cargaison_en_route","douanier",
         "enquete_signalement","enquete_filature","enquete_ecoutes","enquete_perquisition","facade","recherche",
         "comptable", "juge","prete_nom"}
PH |= {"etranger"}
WARN = []
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
        elif k == "entourage": check_entourage(v, where, errs)
        elif k == "coeur": check_coeur(v, where, errs)
        elif k not in SPECIAL: errs.append(f"{where}: clé d'effet inconnue {k}")
def check_text(t, where, errs):
    if not isinstance(t,str) or not t.strip(): errs.append(f"{where}: texte vide"); return
    m = re.search(r"\b\w*(x|f|er|et|en|on|el)\{e\}", t)
    if m: errs.append(f"{where}: accord {{e}} incorrect sur « {m.group(0)} » (reformule)")
    m2 = re.search(r"\{(ami|fratrie|mere|pere|parent|partenaire)\}([^.!?]{0,25})\{e\}", t)
    if m2 and not re.search(r"\bt'|\bte\b|\btoi\b|\bt’", m2.group(2)): WARN.append(f"{where}: {{e}} semble porter sur un autre personnage que le joueur")
    for p in re.findall(r"\{(\w+)\}", t):
        if p not in PH: errs.append(f"{where}: placeholder inconnu {{{p}}}")
RISK = {"none","low","medium","high","extreme"}
def check_choices(ch, w, errs, ids, ev_id, etape):
    """Choix d'un événement ou d'une étape de scène (docs/SCENES.md) : 3 étapes au plus par scène."""
    for ci,c in enumerate(ch):
        cw=f"{w}/choix{ci}"; check_text(c.get("label"), cw, errs)
        rs=c.get("requiresSkill")
        if rs is not None and (not isinstance(rs,dict) or any(x not in SKILLS or not 1<=n<=5 for x,n in rs.items())): errs.append(f"{cw}: requiresSkill invalide {rs}")
        if c.get("risk") is not None and c["risk"] not in RISK: errs.append(f"{cw}: risk doit être {sorted(RISK)}")
        outs=c.get("outcomes") or []
        if not outs: errs.append(f"{cw}: aucun outcome")
        s=sum(o.get("chance",0) for o in outs)
        if abs(s-1)>0.011: errs.append(f"{cw}: somme des chances = {s}")
        for oi,o in enumerate(outs):
            check_text(o.get("text"), f"{cw}/o{oi}", errs); check_effects(o.get("effects",{}), f"{cw}/o{oi}", errs)
            t=o.get("then")
            if t is None: continue
            tw=f"{cw}/o{oi}/then"
            if etape >= 3: errs.append(f"{tw}: une scène a 3 étapes au plus"); continue
            if not isinstance(t, dict): errs.append(f"{tw}: then doit être un objet"); continue
            for k in t:
                if k not in ("id","text","choices"): errs.append(f"{tw}: clé inconnue {k}")
            sid=t.get("id")
            if sid is not None:
                if not isinstance(sid,str) or not sid.startswith(ev_id): errs.append(f"{tw}: l'id d'étape doit commencer par l'id de l'événement ({ev_id})")
                elif sid in ids: errs.append(f"{tw}: id d'étape dupliqué {sid}")
                else: ids[sid]=w
            check_text(t.get("text"), tw, errs)
            tch=t.get("choices") or []
            if not 1 <= len(tch) <= 4: errs.append(f"{tw}: 1 à 4 choix")
            if tch and all(c2.get("requiresSkill") for c2 in tch): errs.append(f"{tw}: au moins un choix doit être sans requiresSkill")
            check_choices(tch, tw, errs, ids, ev_id, etape+1)
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
                        if t not in TAGS and not t.startswith("reve_") and not LOISIRS_TAG.match(t) and not t.startswith(TAG_PREFIXES): errs.append(f"{w}: tag inconnu {t}")
            check_text(ev.get("text"), w, errs)
            ch = ev.get("choices", [])
            if not ch:
                check_effects(ev.get("effects", {}), w, errs)
                if "resultText" in ev: errs.append(f"{w}: resultText non supporté, mets le texte dans text")
            if len(ch) > 4: errs.append(f"{w}: plus de 4 choix")
            if ch and all(c.get("requiresSkill") for c in ch): errs.append(f"{w}: au moins un choix doit être sans requiresSkill")
            check_choices(ch, w, errs, ids, i, 1)
    for e in errs: print("ERREUR", e)
    for x in WARN: print("AVERTISSEMENT", x)
    print(f"{n} événements, {len(files)} fichiers, {len(errs)} erreurs")
    sys.exit(1 if errs else 0)
if __name__=="__main__": main()
