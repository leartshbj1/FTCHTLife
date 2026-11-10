#!/usr/bin/env python3
"""Vérifie les fichiers de FTCHTLife/Resources/Data/Trophees/*.json.

Usage : python3 tools/validate_trophees.py [--signaux]
  --signaux : liste tous les signaux utilisés par les trophées (pour les brancher dans les modules).
"""
import json, os, sys, glob

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOSSIER = os.path.join(RACINE, 'FTCHTLife', 'Resources', 'Data', 'Trophees')

CATEGORIES = {'vie', 'mort', 'argent', 'amour', 'famille', 'ecole', 'travail', 'crime', 'sante', 'loisirs',
              'casino', 'permis', 'boutique', 'celebrite', 'monde', 'animaux', 'etrange', 'collection'}
RARETES = {'bronze', 'argent', 'or', 'legendaire'}
DIPLOMES = {'aucun', 'ecoleObligatoire', 'bac', 'licence', 'master', 'doctorat'}
FILIERES = {'medecine', 'droit', 'informatique', 'commerce', 'arts', 'sciences'}
PROCHES = {'mere', 'pere', 'frere', 'soeur', 'ami', 'partenaire', 'enfant', 'ex', 'fratrie', 'parents'}
CHAMPS_TROPHEE = {'id', 'nom', 'description', 'categorie', 'rarete', 'secret', 'condition', 'bonus'}
CHAMPS_BONUS = {'titre': str, 'description': str, 'argent': int, 'sante': int, 'bonheur': int, 'intelligence': int,
                'apparence': int, 'karma': int, 'argentParents': int, 'lienParents': int, 'ami': bool}
ENTIERS = ['minAge', 'maxAge', 'minArgent', 'maxArgent', 'minSante', 'maxSante', 'minBonheur', 'maxBonheur',
           'minIntelligence', 'maxIntelligence', 'minApparence', 'maxApparence', 'minKarma', 'maxKarma',
           'minNiveau', 'minAnneesEmploi', 'minCausesDifferentes', 'minTrophees']
DICTS_SIGNAUX = ['compteurs', 'maxCompteurs', 'compteursTotal', 'apresAge', 'avantAge']
DICTS_PROCHES = ['minRelations', 'maxRelations', 'minRelationsTotal']
LISTES = ['drapeaux', 'sansDrapeaux', 'tags', 'excludeTags', 'metiers', 'causeContient', 'prenomCommencePar']
CHAMPS_CONDITION = set(ENTIERS + DICTS_SIGNAUX + DICTS_PROCHES + LISTES +
                       ['moment', 'gender', 'diplome', 'maxDiplome', 'filiere', 'emploi', 'shkurtaaa'])


def main():
    erreurs, ids, signaux, total = [], {}, {}, 0
    fichiers = sorted(glob.glob(os.path.join(DOSSIER, '*.json')))
    if not fichiers:
        print('Aucun fichier de trophées.'); return 1
    for chemin in fichiers:
        nom = os.path.basename(chemin)
        try:
            data = json.load(open(chemin, encoding='utf-8'))
        except Exception as e:
            erreurs.append(f'{nom} : JSON invalide ({e})'); continue
        if not isinstance(data, list):
            erreurs.append(f'{nom} : le fichier doit contenir un tableau'); continue
        for t in data:
            total += 1
            tid = t.get('id', '?')
            ou = f'{nom} / {tid}'
            def err(m): erreurs.append(f'{ou} : {m}')
            for champ in ('id', 'nom', 'description', 'categorie', 'rarete', 'condition'):
                if champ not in t: err(f'champ obligatoire manquant « {champ} »')
            for champ in t:
                if champ not in CHAMPS_TROPHEE: err(f'champ inconnu « {champ} »')
            if tid in ids: err(f'id déjà utilisé dans {ids[tid]}')
            ids[tid] = nom
            if not str(tid).startswith('tro_'): err('l\'id doit commencer par « tro_ »')
            if t.get('categorie') not in CATEGORIES: err(f'catégorie inconnue « {t.get("categorie")} »')
            if t.get('rarete') not in RARETES: err(f'rareté inconnue « {t.get("rarete")} »')
            if 'secret' in t and not isinstance(t['secret'], bool): err('secret doit être true/false')
            c = t.get('condition', {})
            if not isinstance(c, dict): err('condition doit être un objet'); continue
            if not c: err('condition vide : le trophée tomberait tout de suite')
            for champ, v in c.items():
                if champ not in CHAMPS_CONDITION: err(f'condition : champ inconnu « {champ} »')
                elif champ in ENTIERS and (not isinstance(v, int) or isinstance(v, bool)): err(f'{champ} doit être un entier')
                elif champ in DICTS_SIGNAUX or champ in DICTS_PROCHES:
                    if not isinstance(v, dict) or not all(isinstance(x, int) and not isinstance(x, bool) for x in v.values()):
                        err(f'{champ} doit être un objet {{"nom": entier}}')
                    elif champ in DICTS_PROCHES:
                        for k in v:
                            if k not in PROCHES: err(f'{champ} : type de proche inconnu « {k} »')
                    else:
                        for k in v: signaux.setdefault(k, []).append(tid)
                elif champ in LISTES and (not isinstance(v, list) or not all(isinstance(x, str) for x in v)):
                    err(f'{champ} doit être une liste de textes')
            if c.get('moment') not in (None, 'vie', 'mort'): err('moment doit être « vie » ou « mort »')
            if c.get('gender') not in (None, 'any', 'male', 'female'): err('gender invalide')
            for champ in ('diplome', 'maxDiplome'):
                if champ in c and c[champ] not in DIPLOMES: err(f'{champ} inconnu « {c[champ]} »')
            if 'filiere' in c and c['filiere'] not in FILIERES: err(f'filière inconnue « {c["filiere"]} »')
            for champ in ('emploi', 'shkurtaaa'):
                if champ in c and not isinstance(c[champ], bool): err(f'{champ} doit être true/false')
            b = t.get('bonus')
            if b is not None:
                if not isinstance(b, dict): err('bonus doit être un objet')
                else:
                    for champ in ('titre', 'description'):
                        if champ not in b: err(f'bonus : « {champ} » manquant')
                    for champ, v in b.items():
                        attendu = CHAMPS_BONUS.get(champ)
                        if attendu is None: err(f'bonus : champ inconnu « {champ} »')
                        elif attendu is int and (not isinstance(v, int) or isinstance(v, bool)): err(f'bonus : {champ} doit être un entier')
                        elif attendu is not int and not isinstance(v, attendu): err(f'bonus : {champ} a un mauvais type')
    if '--signaux' in sys.argv:
        for s in sorted(signaux):
            print(f'{s:32} {len(signaux[s])} trophée(s)')
    if erreurs:
        print('\n'.join(erreurs))
        print(f'{len(erreurs)} erreur(s) sur {total} trophées.')
        return 1
    print(f'OK : {total} trophées dans {len(fichiers)} fichiers, {len(signaux)} signaux utilisés.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
