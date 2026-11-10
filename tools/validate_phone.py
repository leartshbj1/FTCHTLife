#!/usr/bin/env python3
"""Valide les données du téléphone : FTCHTLife/Resources/Data/Phone/**. Usage : python3 tools/validate_phone.py"""
import json, sys, glob, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "FTCHTLife/Resources/Data/Phone")
STATS = {"happiness", "health", "smarts", "looks", "money", "karma", "stress", "fame"}
REL = {"mother", "father", "parent", "sibling", "friend", "partner", "child"}
SPECIAL = {"newFriend", "relationships", "death", "followers", "followersPct"}
TAGS = {"male", "female", "baby", "school", "university", "job", "adult", "unemployed", "retired", "rich", "poor",
        "friend", "mother", "father", "siblings", "partner", "children", "sick", "attractive", "smart",
        "phone", "influencer", "star_reseaux", "bad_buzz", "sponsorise"}
COND = {"gender", "minMoney", "maxMoney", "requiresJob", "requiresPartner", "requiresSchool", "tags", "excludeTags"}
PH = {"prenom", "nom", "ville", "mere", "pere", "parent", "ami", "fratrie", "partenaire", "metier", "e",
      "app", "abonnes", "gain", "marque", "montant", "match"}
APPS_POST = {"pozz", "tremousse", "ronchon"}
APPS = APPS_POST | {"pecho", "any"}
POST_STATS = {"looks", "smarts", "happiness", "karma", "none"}
PALIERS = ["flop", "moyen", "succes", "buzz", "badbuzz"]
COM_TYPES = {"fan", "hater", "bizarre", "famille", "bot"}
MSG_CATS = {"bizarre", "arnaque", "famille", "hater", "fan", "crush", "ami", "pro"}
RDV = {"lapin", "catastrophe", "bof", "bien", "coupdefoudre"}
GENRES = {"any", "male", "female"}

errs = []
ids = {}


def err(w, m):
    errs.append(f"{w}: {m}")


def texte(t, w):
    if not isinstance(t, str) or not t.strip():
        err(w, "texte vide")
        return
    for p in re.findall(r"\{(\w+)\}", t):
        if p not in PH:
            err(w, f"variable inconnue {{{p}}}")
    if t.count("{") != t.count("}"):
        err(w, "accolades déséquilibrées")


def effets(e, w):
    if e is None:
        return
    if not isinstance(e, dict):
        err(w, "effects n'est pas un objet")
        return
    for k, v in e.items():
        if k in STATS:
            if not isinstance(v, (int, float)) or isinstance(v, bool):
                err(w, f"{k} non numérique")
            elif k != "money" and abs(v) > 100:
                err(w, f"{k} hors bornes")
        elif k == "relationships":
            if not isinstance(v, dict) or any(r not in REL for r in v):
                err(w, f"relationships invalide {v}")
        elif k == "followers":
            if not isinstance(v, int) or isinstance(v, bool):
                err(w, "followers doit être un entier")
        elif k == "followersPct":
            if not isinstance(v, (int, float)) or not -1 <= v <= 5:
                err(w, "followersPct doit être entre -1 et 5")
        elif k == "newFriend":
            if not isinstance(v, bool):
                err(w, "newFriend doit être true/false")
        elif k == "death":
            if not isinstance(v, str):
                err(w, "death doit être un texte")
        else:
            err(w, f"clé d'effet inconnue {k}")


def conditions(c, w):
    if c is None:
        return
    if not isinstance(c, dict):
        err(w, "conditions n'est pas un objet")
        return
    for k, v in c.items():
        if k not in COND:
            err(w, f"condition inconnue {k}")
        elif k in ("tags", "excludeTags"):
            for t in v or []:
                if t not in TAGS:
                    err(w, f"tag inconnu {t}")
        elif k == "gender" and v not in (None, "any", "male", "female"):
            err(w, f"gender invalide {v}")


def ages(o, w):
    a, b = o.get("minAge", 0), o.get("maxAge", 120)
    if not (isinstance(a, int) and isinstance(b, int) and 0 <= a <= b <= 120):
        err(w, "âges invalides")


def nouvel_id(o, f):
    i = o.get("id")
    w = f"{os.path.relpath(f, BASE)}:{i}"
    if not isinstance(i, str) or not i:
        err(w, "id manquant")
    elif i in ids:
        err(w, f"id dupliqué (aussi dans {ids[i]})")
    else:
        ids[i] = os.path.relpath(f, BASE)
    return w


def requis(o, w, cles):
    for k in cles:
        if k not in o:
            err(w, f"champ manquant {k}")


def post(o, w):
    requis(o, w, ["app", "titre", "icone", "stat", "risque", "viralite", "textes"])
    if o.get("app") not in APPS_POST:
        err(w, f"app invalide {o.get('app')}")
    if o.get("stat") not in POST_STATS:
        err(w, f"stat invalide {o.get('stat')}")
    if not 0 <= o.get("risque", 0) <= 0.5:
        err(w, "risque hors de 0..0.5")
    if not 0.5 <= o.get("viralite", 1) <= 3:
        err(w, "viralite hors de 0.5..3")
    if not isinstance(o.get("cout", 0), int) or o.get("cout", 0) < 0:
        err(w, "cout invalide")
    texte(o.get("titre"), w)
    ages(o, w)
    conditions(o.get("conditions"), w)
    t = o.get("textes") or {}
    for p in PALIERS:
        l = t.get(p)
        if not isinstance(l, list) or len(l) < 2:
            err(w, f"textes.{p} : au moins 2 phrases")
            continue
        for k, s in enumerate(l):
            texte(s, f"{w}/{p}{k}")
    for p in t:
        if p not in PALIERS:
            err(w, f"palier inconnu {p}")


def commentaire(o, w):
    requis(o, w, ["type", "texte"])
    if o.get("type") not in COM_TYPES:
        err(w, f"type invalide {o.get('type')}")
    if o.get("app", "any") not in APPS:
        err(w, f"app invalide {o.get('app')}")
    texte(o.get("texte"), w)


def message(o, w):
    requis(o, w, ["categorie", "expediteur", "text", "choices"])
    if o.get("categorie") not in MSG_CATS:
        err(w, f"categorie invalide {o.get('categorie')}")
    if o.get("app", "any") not in APPS:
        err(w, f"app invalide {o.get('app')}")
    ages(o, w)
    conditions(o.get("conditions"), w)
    texte(o.get("expediteur"), w)
    texte(o.get("text"), w)
    ch = o.get("choices") or []
    if not 1 <= len(ch) <= 4:
        err(w, "il faut 1 à 4 choix")
    for ci, c in enumerate(ch):
        cw = f"{w}/choix{ci}"
        texte(c.get("label"), cw)
        outs = c.get("outcomes") or []
        if not outs:
            err(cw, "aucune issue")
        for oi, x in enumerate(outs):
            texte(x.get("text"), f"{cw}/o{oi}")
            effets(x.get("effects"), f"{cw}/o{oi}")


def sponsor(o, w):
    requis(o, w, ["marque", "produit", "minAbonnes", "tarif", "minPaiement", "louche", "offre", "accepte", "scandale"])
    if o.get("app", "any") not in APPS:
        err(w, f"app invalide {o.get('app')}")
    if not 0 <= o.get("louche", 0) <= 1:
        err(w, "louche hors de 0..1")
    if not 0 < o.get("tarif", 0) <= 1:
        err(w, "tarif hors de 0..1")
    for k in ("marque", "produit", "offre", "accepte", "scandale"):
        texte(o.get(k), f"{w}/{k}")


def profil(o, w):
    requis(o, w, ["genre", "bio"])
    if o.get("genre") not in GENRES:
        err(w, f"genre invalide {o.get('genre')}")
    ages(o, w)
    if o.get("minAge", 18) < 18:
        err(w, "Pécho est réservé aux 18 ans et plus")
    texte(o.get("bio"), w)


def rdv(o, w):
    requis(o, w, ["issue", "texte"])
    if o.get("issue") not in RDV:
        err(w, f"issue invalide {o.get('issue')}")
    texte(o.get("texte"), w)


TYPES = {"Posts": post, "Commentaires": commentaire, "Messages": message, "Sponsors": sponsor,
         "Profils": profil, "RendezVous": rdv}


def main():
    total = {}
    for dossier, fn in TYPES.items():
        n = 0
        for f in sorted(glob.glob(os.path.join(BASE, dossier, "*.json"))):
            try:
                data = json.load(open(f, encoding="utf-8"))
            except Exception as ex:
                err(f, f"JSON invalide : {ex}")
                continue
            if not isinstance(data, list):
                err(f, "le fichier doit contenir un tableau")
                continue
            for o in data:
                if not isinstance(o, dict):
                    err(f, "élément qui n'est pas un objet")
                    continue
                n += 1
                fn(o, nouvel_id(o, f))
        total[dossier] = n
    for f in glob.glob(os.path.join(BASE, "*.json")):
        err(f, "les JSON doivent être rangés dans un sous-dossier (Posts, Messages…)")
    for e in errs[:300]:
        print("ERREUR", e)
    print(", ".join(f"{k} : {v}" for k, v in total.items()), f"· {len(errs)} erreur(s)")
    sys.exit(1 if errs else 0)


if __name__ == "__main__":
    main()
