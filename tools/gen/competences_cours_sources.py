# Génère les cours (Data/CompetencesCours) et les gains automatiques (Data/CompetencesSources).
import json, os

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(RACINE, "FTCHTLife", "Resources", "Data")

def cours(id, comp, titre, desc, cout, gain, textes, minAge=None, niveauMin=None, niveauMax=None, effects=None):
    d = dict(id=id, competence=comp, titre=titre, description=desc, cout=cout, gain=gain, textes=textes)
    if minAge is not None: d["minAge"] = minAge
    if niveauMin is not None: d["niveauMin"] = niveauMin
    if niveauMax is not None: d["niveauMax"] = niveauMax
    if effects: d["effects"] = effects
    return d

K = []
# Langues : une appli, un cours du soir, un séjour.
for lid, nom, art, pays, ville in [
        ("anglais", "anglais", "l'", "en Angleterre", "Brighton"),
        ("espagnol", "espagnol", "l'", "en Espagne", "Valence"),
        ("allemand", "allemand", "l'", "en Allemagne", "Fribourg-en-Brisgau"),
        ("italien", "italien", "l'", "en Italie", "Bologne"),
        ("albanais", "albanais", "l'", "au Kosovo", "Prishtina"),
        ("japonais", "japonais", "le ", "au Japon", "Osaka"),
        ("portugais", "portugais", "le ", "au Portugal", "Porto"),
        ("arabe", "arabe", "l'", "au Maroc", "Fès")]:
    K.append(cours(f"cc_{lid}_appli", lid, f"Appli de {nom}", "Un hibou numérique qui te culpabilise chaque soir.", 60, [5, 8],
        [f"Tu as fait ta série de 30 jours sur l'appli. Le hibou est fier, ta famille inquiète.",
         f"L'appli t'a appris à dire « le canard boit du lait » en {nom}. Indispensable.",
         f"Tu as oublié ta leçon un soir. Le hibou t'a écrit à 23 h. Tu as eu peur."], minAge=8, niveauMax=3))
    K.append(cours(f"cc_{lid}_soir", lid, f"Cours du soir d'{nom}" if nom[0] in "aeiou" else f"Cours du soir de {nom}",
        "Deux heures par semaine dans une salle qui sent le café froid.", 450, [10, 15],
        [f"Tu as suivi les cours du soir. Ton prof s'appelle Gérard et il adore les verbes irréguliers.",
         f"Tu as passé l'année au cours du soir. Tu as appris {art}{nom} et la vie amoureuse de ta voisine de table.",
         f"Le cours du soir t'a fait progresser. Le jeu de rôle « à la boulangerie » t'a traumatisé{{e}}, mais tu progresses."], minAge=12, niveauMax=4))
    K.append(cours(f"cc_{lid}_sejour", lid, f"Séjour linguistique {pays}", f"Un mois à {ville}, en famille d'accueil. Immersion totale.", 2500, [16, 24],
        [f"Un mois à {ville} ! Ta famille d'accueil t'a gavé{{e}} et t'a appris des expressions que les profs ne connaissent pas.",
         f"À {ville}, tu as dû te débrouiller seul{{e}}. Tu as perdu tes clés, ta fierté et ton accent.",
         f"Tu rentres de {ville} en parlant avec les mains, même au téléphone."], minAge=13, effects={"happiness": 5}))

AUTRES = [
    ("guitare", [
        ("cc_guitare_tuto", "Tutos de guitare en ligne", "Un barbu sympathique t'apprend trois accords en 10 minutes.", 0, [3, 6],
         ["Tu as regardé dix tutos. Le barbu joue très vite. Toi, très lentement.", "Tu as appris un riff célèbre. Tu le joues à chaque fois que tu passes devant la guitare."], dict(minAge=8, niveauMax=2)),
        ("cc_guitare_prof", "Cours particuliers de guitare", "Un vrai prof, qui a joué en première partie d'un groupe que personne ne connaît.", 900, [11, 16],
         ["Ton prof t'a montré le barré. Ton index ne s'en remettra jamais.", "Ton prof dit que tu as « un truc ». Il dit ça à tout le monde, mais tu le crois."], dict(minAge=8)),
        ("cc_guitare_stage", "Stage rock d'été", "Une semaine dans une ferme avec des amplis et des gens chevelus.", 1200, [15, 22],
         ["Une semaine de stage rock : tu as monté un groupe éphémère appelé « Les Pâtes Froides ».", "Tu as joué devant un public de vaches. Elles ont adoré le solo."], dict(minAge=14, niveauMin=2, effects={"happiness": 4}))]),
    ("piano", [
        ("cc_piano_conserv", "Conservatoire", "Le solfège, les gammes, et une professeure qui ne sourit jamais.", 800, [10, 15],
         ["Une année de conservatoire. Ta professeure a souri une fois. C'était en voyant ta fausse note.", "Tu as passé l'examen de fin d'année. Le jury a pris des notes. Toi aussi, des fausses."], dict(minAge=6)),
        ("cc_piano_masterclass", "Masterclass de piano", "Trois jours avec une pianiste célèbre et très exigeante.", 2000, [16, 22],
         ["La pianiste a corrigé ta posture, tes doigts et ta vie. Tu joues comme jamais.", "Elle t'a fait rejouer la même mesure 80 fois. La 81e était parfaite."], dict(minAge=14, niveauMin=3))]),
    ("chant", [
        ("cc_chant_chorale", "Chorale du quartier", "Une chorale sympa, moyenne d'âge 72 ans, ambiance de feu.", 120, [7, 11],
         ["La chorale t'a accueilli{e} comme un petit-enfant. Tu as chanté et mangé beaucoup de cake.", "Tu as chanté au concert de Noël de la chorale. Une dame a pleuré. C'était sa petite-fille, mais quand même."], dict(minAge=6, effects={"happiness": 3})),
        ("cc_chant_prof", "Cours de chant lyrique", "Respirer avec le ventre et faire trembler les vitres.", 1100, [12, 18],
         ["Ton prof de chant t'a fait chanter allongé{e} par terre. Tu ne sais toujours pas pourquoi, mais ça marche.", "Tu as tenu un contre-ut. Le verre de ton prof s'en souvient encore."], dict(minAge=12))]),
    ("danse", [
        ("cc_danse_club", "Cours de danse", "Salsa, hip-hop ou valse : le prof décide selon son humeur.", 500, [9, 14],
         ["Cette année, cours de salsa. Tu as marché sur les pieds de 14 personnes différentes. Elles t'ont pardonné.", "Le prof de hip-hop t'a appelé{e} « la machine ». Tu ne sais pas si c'était un compliment."], dict(minAge=5, effects={"health": 2})),
        ("cc_danse_compagnie", "Stage avec une compagnie", "Une semaine avec des danseurs pros qui sentent le baume du tigre.", 1600, [15, 22],
         ["Tu as dansé huit heures par jour. Tes muscles ont des muscles.", "Le chorégraphe t'a dit « encore » 200 fois. Tu as fini par l'entendre dans tes rêves."], dict(minAge=14, niveauMin=2))]),
    ("dessin", [
        ("cc_dessin_atelier", "Atelier de dessin", "Natures mortes, pommes, bouteilles, et parfois un modèle très habillé.", 350, [8, 13],
         ["Tu as dessiné la même pomme toute l'année. Elle est morte avant la fin du cours.", "La prof d'atelier a accroché ton dessin au mur. À côté de la porte, mais au mur."], dict(minAge=6)),
        ("cc_dessin_beauxarts", "Prépa beaux-arts", "Une année intense à dessiner des plâtres antiques jusqu'à minuit.", 3000, [16, 24],
         ["Une année de prépa. Tu connais chaque muscle du corps humain, et chaque recoin de la cafétéria.", "Tu as dessiné un plâtre de Vénus 60 fois. Vous êtes intimes maintenant."], dict(minAge=17, effects={"stress": 5}))]),
    ("photo", [
        ("cc_photo_club", "Club photo", "Des passionnés qui parlent d'objectifs pendant des heures.", 150, [7, 11],
         ["Le club photo t'a appris la règle des tiers. Tu cadres tout en trois, même ta soupe.", "Sortie du club au lac. Tu as photographié un cygne, le cygne t'a attaqué{e}."], dict(minAge=10)),
        ("cc_photo_pro", "Formation photo pro", "Studio, lumières, retouche. Tu sauras enfin pourquoi tes photos sont jaunes.", 1800, [14, 20],
         ["Tu sais régler un flash de studio. Tu as ébloui tout le monde, mais professionnellement.", "Tu as appris la retouche. Tu ne regardes plus jamais une pub de la même façon."], dict(minAge=16))]),
    ("cuisine", [
        ("cc_cuisine_atelier", "Atelier cuisine", "Un chef jovial t'apprend à ne pas pleurer en coupant les oignons.", 250, [8, 12],
         ["À l'atelier cuisine, tu as fait un risotto. Le chef a dit « pas mal » et c'est le plus beau jour de ta vie.", "Tu as appris à tenir un couteau. Tu as toujours tes dix doigts, bravo."], dict(minAge=8, effects={"health": 1})),
        ("cc_cuisine_ecole", "École de cuisine (stage intensif)", "Trois mois de brigade, de « oui chef » et de brûlures aux avant-bras.", 3500, [18, 26],
         ["Trois mois de brigade. Tu dis « oui chef » même à ta mère maintenant.", "Le chef a jeté ta sauce à la poubelle six fois. La septième, il l'a goûtée deux fois."], dict(minAge=16, effects={"stress": 4})),
        ("cc_cuisine_mamie", "Recettes de mamie", "Un après-midi avec une grand-mère qui ne mesure jamais rien.", 0, [4, 7],
         ["Mamie t'a appris sa tarte. « Un peu de farine, un peu de beurre. » Combien ? « Un peu. »", "Tu as passé l'après-midi en cuisine avec une mamie. Tu as appris trois recettes et quatre secrets de famille."], dict(minAge=6, niveauMax=2, effects={"happiness": 3}))]),
    ("bricolage", [
        ("cc_bricolage_atelier", "Atelier du magasin de bricolage", "Le samedi matin, un vendeur en gilet t'apprend à percer droit.", 40, [6, 10],
         ["Le vendeur t'a appris à percer droit. Tu as aussi acheté une perceuse, un niveau et une scie. C'était le but.", "Tu as fabriqué un nichoir. Un oiseau l'a regardé, puis est parti vivre ailleurs."], dict(minAge=10)),
        ("cc_bricolage_menuiserie", "Formation menuiserie", "Six mois à sentir la sciure et le vernis.", 2200, [15, 21],
         ["Tu sais faire un tenon et une mortaise. Tu ne sais pas encore à quoi ça sert dans la vie, mais tu sais.", "Tu as fabriqué une table entière. Elle est un peu bancale, ce qui la rend authentique."], dict(minAge=16))]),
    ("mecanique", [
        ("cc_meca_garage", "Stage au garage du coin", "Un mécano bourru t'apprend en jurant.", 0, [7, 11],
         ["Le mécano t'a appris trois choses et cinquante gros mots. Les deux servent.", "Tu as changé ta première roue de voiture. Elle est bien serrée. Peut-être trop."], dict(minAge=14, niveauMax=3)),
        ("cc_meca_cap", "Formation mécanique auto", "Un an de cours pour comprendre enfin ce qui fait « clonc ».", 2600, [15, 22],
         ["Tu connais le nom de toutes les pièces d'un moteur. Tu les récites pour t'endormir.", "Tu as démonté et remonté un moteur entier. Il marche. Tu as gardé une vis en souvenir."], dict(minAge=16))]),
    ("jardinage", [
        ("cc_jardin_partage", "Jardin partagé", "Une parcelle au milieu de retraités très compétitifs sur les tomates.", 80, [7, 11],
         ["Au jardin partagé, René t'a appris à tailler les tomates. Il a aussi volé tes fraises.", "Tu as cultivé tes premières courgettes. Il y en a trop. Il y en a toujours trop."], dict(minAge=6, effects={"happiness": 3})),
        ("cc_jardin_paysagiste", "Formation paysagiste", "Tailles, greffes et noms latins de plantes.", 1900, [14, 20],
         ["Tu connais le nom latin du pissenlit. Tu le dis à voix haute en promenade. Les gens s'éloignent.", "Tu as réussi ta première greffe. L'arbre donne maintenant deux sortes de pommes. Il est perplexe."], dict(minAge=16))]),
    ("sport", [
        ("cc_sport_club", "Club de sport", "Foot, basket, natation : on t'inscrit, tu transpires.", 300, [8, 13],
         ["Une saison au club. Ton équipe a perdu tous ses matchs sauf un, par forfait de l'adversaire.", "Ton entraîneur crie beaucoup. Tu cours vite pour ne plus l'entendre. Ça marche."], dict(minAge=5, effects={"health": 3})),
        ("cc_sport_coach", "Coach sportif personnel", "Quelqu'un de très musclé qui compte jusqu'à dix très lentement.", 1500, [13, 19],
         ["Ton coach t'a fait faire des burpees. Tu le hais. Tu es en pleine forme.", "Ton coach compte « 8, 9, 9 et demi, 9 trois quarts... ». C'est de la torture mathématique."], dict(minAge=16, effects={"health": 4, "looks": 2}))]),
    ("survie", [
        ("cc_survie_scouts", "Scouts", "Des tentes, des chants et un foulard noué très serré.", 150, [8, 12],
         ["Chez les scouts, tu as appris à faire un feu et une dizaine de nœuds dont un très inutile.", "Tu as passé un camp sous la pluie. Tu es devenu{e} une personne plus forte et plus humide."], dict(minAge=7, maxAgeIgnored=True)),
        ("cc_survie_stage", "Stage de survie en montagne", "Trois jours dans le Valais avec un ancien militaire et un couteau.", 900, [14, 20],
         ["Trois jours avec l'ancien militaire. Tu as mangé un insecte et tu as dit merci.", "Tu as construit un abri en neige. Il était plus confortable que ton premier appartement."], dict(minAge=16, effects={"health": 2}))]),
    ("code", [
        ("cc_code_ligne", "Cours de code en ligne", "Des vidéos, des exercices, et un forum plein de gens énervés.", 100, [7, 11],
         ["Tu as suivi le cours en ligne. Le forum t'a appris plus que le cours, et beaucoup de mépris.", "Tu as fini le module « boucles ». Tu as fait une boucle infinie. Ton ordinateur a chauffé la pièce."], dict(minAge=9)),
        ("cc_code_bootcamp", "Bootcamp de développement", "Douze semaines, dix heures par jour, des pizzas et des larmes.", 6000, [20, 28],
         ["Douze semaines de bootcamp. Tu as appris trois langages et oublié le goût des légumes.", "Ton projet de fin de bootcamp est une appli qui dit si ton yaourt est périmé. Le jury a applaudi."], dict(minAge=17, effects={"smarts": 3, "stress": 6}))]),
    ("echecs", [
        ("cc_echecs_club", "Club d'échecs", "Le mercredi soir, dans une salle silencieuse qui sent la tisane.", 100, [8, 12],
         ["Au club, un monsieur de 84 ans t'a battu{e} en douze coups. Il t'a offert une tisane pour te consoler.", "Tu as appris trois ouvertures. Tu les mélanges, ça déstabilise tout le monde, toi compris{e}."], dict(minAge=6)),
        ("cc_echecs_maitre", "Leçons avec un maître FIDE", "Un vrai maître international qui soupire très fort.", 1400, [14, 20],
         ["Le maître a soupiré 400 fois cette année. Le dernier soupir était presque admiratif.", "Il t'a fait analyser une partie de 1924 pendant trois mois. Tu la connais mieux que tes cousins."], dict(minAge=10, niveauMin=2))]),
    ("seduction", [
        ("cc_seduction_livre", "Livre « Plaire en 10 leçons »", "Un livre trouvé en solde, écrit par un auteur divorcé trois fois.", 25, [3, 6],
         ["Tu as lu le livre. La leçon 4 conseille de parler des pingouins. Tu vas essayer.", "Le livre t'a appris à « dominer l'espace ». Tu as surtout fait tomber une lampe."], dict(minAge=16, niveauMax=2)),
        ("cc_seduction_theatre", "Cours de théâtre", "Gagner en assurance, apprendre à regarder les gens dans les yeux.", 600, [9, 14],
         ["Une année de théâtre : tu as joué un arbre, puis un roi, puis un roi arbre. Ton assurance a doublé.", "Le théâtre t'a appris à sourire avec les yeux. C'est plus dur qu'il n'y paraît."], dict(minAge=12, effects={"happiness": 3}))]),
    ("eloquence", [
        ("cc_eloquence_debat", "Club de débat", "On défend des idées absurdes avec beaucoup de sérieux.", 150, [8, 13],
         ["Tu as défendu la thèse « les chaussettes devraient être interdites » et tu as gagné.", "Au club de débat, tu as appris à dire « c'est une excellente question » pour gagner du temps."], dict(minAge=11, effects={"smarts": 1})),
        ("cc_eloquence_coach", "Coaching prise de parole", "Une coach qui filme tes tics de langage et te les montre au ralenti.", 1300, [13, 19],
         ["Tu as vu ta vidéo. Tu touches ton nez 30 fois par minute. Plus maintenant.", "La coach t'a appris à ralentir. Tes phrases sont plus courtes. Et plus fortes."], dict(minAge=16))]),
    ("humour", [
        ("cc_humour_impro", "Cours d'impro", "On t'envoie sur scène sans texte et on voit ce qui se passe.", 400, [9, 14],
         ["En impro, on t'a donné le thème « un dentiste sur la Lune ». Tu as fait rire la salle et pleurer un dentiste.", "Tu as appris la règle d'or de l'impro : toujours dire « oui, et ». Tu l'appliques à ta banque, ça marche moins."], dict(minAge=10, effects={"happiness": 3})),
        ("cc_humour_scene", "Scène ouverte de stand-up", "Cinq minutes au micro devant 30 personnes et un barman fatigué.", 0, [6, 12],
         ["Ta première scène ouverte : deux rires, une toux, et le barman qui a souri. C'est un succès.", "Tu as fait ton passage. Un type au fond a crié « pas mal ». Tu le gardes dans ton cœur."], dict(minAge=18, niveauMin=2, effects={"stress": 3}))]),
    ("marchandage", [
        ("cc_marchandage_puces", "Matinée aux puces avec un chineur", "Un vieux brocanteur t'apprend à dire « bof » en regardant un trésor.", 0, [6, 10],
         ["Le brocanteur t'a appris à faire une moue déçue. Tu l'as essayée sur un serveur, tu as eu une remise.", "Tu as passé la matinée aux puces. Tu sais maintenant que tout se négocie, sauf le café du brocanteur."], dict(minAge=12)),
        ("cc_marchandage_nego", "Formation négociation commerciale", "Une formation d'entreprise avec des jeux de rôle gênants.", 1500, [13, 19],
         ["Tu as appris l'ancrage : toujours proposer un prix ridicule en premier. Ta boulangère n'a pas apprécié.", "Le formateur t'a fait négocier un trombone contre une voiture. Tu as eu une trottinette, c'est déjà bien."], dict(minAge=18))]),
    ("magie", [
        ("cc_magie_coffret", "Coffret de magie", "Une boîte avec des cartes truquées et un chapeau en carton.", 35, [4, 7],
         ["Tu as fait tous les tours du coffret. Ta famille connaît désormais tous les trucs, par force.", "Le coffret promettait 100 tours. Il y en a 12, plus un lapin en plastique. Tu maîtrises le lapin."], dict(minAge=6, niveauMax=2)),
        ("cc_magie_club", "Club des magiciens", "Des gens en gilet qui gardent leurs secrets très jalousement.", 700, [11, 17],
         ["Tu as été admis{e} au club. On t'a appris un tour, puis on t'a fait jurer de ne jamais le révéler. Tu as juré sur un jeu de cartes.", "Un vieux magicien t'a montré une passe secrète. Tu l'as répétée 5 000 fois. Tes cartes sont usées, toi aussi."], dict(minAge=10, niveauMin=1))]),
]
for comp, liste in AUTRES:
    for (id, titre, desc, cout, gain, textes, opts) in liste:
        opts = dict(opts)
        opts.pop("maxAgeIgnored", None)
        K.append(cours(id, comp, titre, desc, cout, gain, textes, **opts))

S = [
    # École : un peu chaque année avant le bac.
    dict(id="src_ecole_anglais", type="ecole", minAge=8, maxAge=18, gains={"anglais": 4}),
    dict(id="src_ecole_allemand", type="ecole", minAge=11, maxAge=18, chance=0.6, gains={"allemand": 3}),
    dict(id="src_ecole_espagnol", type="ecole", minAge=13, maxAge=18, chance=0.4, gains={"espagnol": 3}),
    dict(id="src_ecole_sport", type="ecole", minAge=6, maxAge=18, gains={"sport": 2}),
    dict(id="src_ecole_dessin", type="ecole", minAge=3, maxAge=11, chance=0.7, gains={"dessin": 3}),
    dict(id="src_ecole_chant", type="ecole", minAge=3, maxAge=11, chance=0.5, gains={"chant": 2}),
    dict(id="src_ecole_eloquence", type="ecole", minAge=15, maxAge=18, chance=0.5, gains={"eloquence": 2}),
    # Études supérieures.
    dict(id="src_fil_info", type="filiere", ids=["informatique"], gains={"code": 9, "anglais": 2}),
    dict(id="src_fil_droit", type="filiere", ids=["droit"], gains={"eloquence": 7}),
    dict(id="src_fil_commerce", type="filiere", ids=["commerce"], gains={"marchandage": 6, "anglais": 3}),
    dict(id="src_fil_arts", type="filiere", ids=["arts"], gains={"dessin": 7, "photo": 4}),
    dict(id="src_fil_sciences", type="filiere", ids=["sciences"], gains={"code": 3, "anglais": 3}),
    dict(id="src_fil_medecine", type="filiere", ids=["medecine"], gains={"anglais": 2}),
    dict(id="src_etudes_fete", type="etudes", chance=0.5, gains={"danse": 2, "seduction": 2}),
    # Métiers (ids du moteur + mots-clés pour les métiers des autres modules).
    dict(id="src_met_code", type="metier", ids=["dev"], motsCles=["develop", "informati", "program", "hacker", "data", "web", "logiciel", "devops", "cyber"], gains={"code": 6}),
    dict(id="src_met_cuisine", type="metier", ids=["plongeur"], motsCles=["cuisin", "boulang", "patiss", "traiteur", "pizzaiolo", "kebab", "restaura", "boucher", "charcut"], gains={"cuisine": 5}),
    dict(id="src_met_bricolage", type="metier", ids=["macon", "agent_entretien"], motsCles=["macon", "menuis", "charpent", "plomb", "electricien", "peintre en bat", "carrel", "artisan", "ouvrier", "concierge", "renovat"], gains={"bricolage": 5}),
    dict(id="src_met_meca", type="metier", ids=["chauffeur"], motsCles=["mecan", "garag", "carross", "chauffeur", "pilote", "routier", "taxi"], gains={"mecanique": 4}),
    dict(id="src_met_jardin", type="metier", motsCles=["jardin", "paysag", "agricult", "fleur", "horticul", "viticult", "vigneron", "maraich", "fermier"], gains={"jardinage": 6}),
    dict(id="src_met_sport", type="metier", ids=["livreur", "policier"], motsCles=["sport", "coach", "athlet", "footbal", "pompier", "livreur", "militaire", "soldat", "polic", "moniteur", "guide de montagne", "maitre-nageur", "facteur"], gains={"sport": 4}),
    dict(id="src_met_survie", type="metier", motsCles=["guide", "garde forest", "militaire", "soldat", "pompier", "berger", "bucheron", "explorat"], gains={"survie": 4}),
    dict(id="src_met_eloquence", type="metier", ids=["avocat", "juge", "prof", "marketing"], motsCles=["avocat", "juge", "enseign", "professeu", "politi", "journal", "present", "commercial", "vendeur", "porte-parole", "maire", "depute", "pretre", "pasteur"], gains={"eloquence": 5}),
    dict(id="src_met_marchandage", type="metier", ids=["vendeur", "agent_immo", "caissier", "comptable"], motsCles=["vendeur", "commerc", "immobil", "acheteur", "trader", "banqu", "brocant", "antiquair", "negoci", "courtier"], gains={"marchandage": 5}),
    dict(id="src_met_seduction", type="metier", ids=["mannequin", "influenceur", "coiffeur"], motsCles=["mannequin", "influenc", "acteur", "actrice", "barman", "serveu", "hote", "coiff", "esthetic", "maquill"], gains={"seduction": 4}),
    dict(id="src_met_humour", type="metier", motsCles=["humor", "comedi", "clown", "animat", "youtub", "presentat"], gains={"humour": 6}),
    dict(id="src_met_dessin", type="metier", ids=["graphiste"], motsCles=["graphi", "dessin", "illustr", "architect", "tatou", "peintre", "design"], gains={"dessin": 5}),
    dict(id="src_met_photo", type="metier", motsCles=["photo", "camera", "cadreu", "videast", "realisat", "journal"], gains={"photo": 5}),
    dict(id="src_met_musique", type="metier", motsCles=["music", "guitar", "rock"], gains={"guitare": 5}),
    dict(id="src_met_piano", type="metier", motsCles=["pian", "compositeur", "chef d'orchestre", "organiste"], gains={"piano": 5}),
    dict(id="src_met_chant", type="metier", motsCles=["chanteu", "choriste", "opera", "karaok"], gains={"chant": 5}),
    dict(id="src_met_danse", type="metier", motsCles=["danseu", "choregraph", "ballet"], gains={"danse": 6}),
    dict(id="src_met_magie", type="metier", motsCles=["magic", "illusion", "cirque", "prestidig"], gains={"magie": 6}),
    dict(id="src_met_echecs", type="metier", ids=["chercheur", "juge"], motsCles=["chercheu", "mathemat", "strateg", "analyst", "ingenieu"], gains={"echecs": 2}),
    dict(id="src_met_anglais", type="metier", ids=["dev", "chercheur", "marketing", "medecin", "chirurgien"], motsCles=["pilote", "steward", "hotesse", "traduct", "interpret", "diplomat", "hotel", "touris", "internation", "export", "consult"], gains={"anglais": 3}),
    dict(id="src_met_traduction", type="metier", motsCles=["traduct", "interpret"], gains={"espagnol": 3, "allemand": 3, "italien": 3}),
    # Retraite : le temps libre profite à certains talents.
    dict(id="src_retraite_jardin", type="retraite", chance=0.6, gains={"jardinage": 4}),
    dict(id="src_retraite_echecs", type="retraite", chance=0.4, gains={"echecs": 3}),
    dict(id="src_retraite_cuisine", type="retraite", chance=0.4, gains={"cuisine": 3}),
    # Activités de l'onglet Activités (ids du moteur ; les autres modules ajoutent les leurs).
    dict(id="src_act_sport", type="activite", ids=["sport"], gains={"sport": 6}),
    dict(id="src_act_biblio", type="activite", ids=["biblio"], chance=0.5, gains={"echecs": 2, "anglais": 2}),
    dict(id="src_act_amis", type="activite", ids=["amis"], gains={"humour": 2, "seduction": 1}),
    dict(id="src_act_soiree", type="activite", ids=["soiree"], gains={"danse": 4, "seduction": 2}),
    dict(id="src_act_meditation", type="activite", ids=["meditation"], chance=0.3, gains={"survie": 1}),
    dict(id="src_act_vacances", type="activite", ids=["vacances"], chance=0.7, gains={"anglais": 3, "espagnol": 2, "italien": 2, "photo": 3}),
    dict(id="src_act_casino", type="activite", ids=["casino", "loterie"], chance=0.3, gains={"marchandage": 1}),
    dict(id="src_act_randonnee", type="activite", ids=["randonnee", "rando", "camping", "hiking"], gains={"survie": 5, "sport": 3}),
]
# Mots-clés : sans accents, minuscules (le moteur simplifie aussi le texte du métier).
for s in S:
    if "motsCles" in s:
        s["motsCles"] = [m.lower() for m in s["motsCles"]]

def ecrire(dossier, nom, donnees):
    p = os.path.join(DATA, dossier, nom)
    with open(p, "w", encoding="utf-8") as f:
        json.dump(donnees, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(len(donnees), "->", os.path.relpath(p, RACINE))

ecrire("CompetencesCours", "cours.json", K)
ecrire("CompetencesSources", "sources.json", S)
