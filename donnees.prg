&& CC BY-NC-SA 4.0 - jean-marc "jihem" quere 2026
&& Gestion d'établissement : schéma de la base DuckDB, accès aux paramètres
&& et jeu d'exemple (un collège fictif complet).
&&
&& Tables saisies
&&   parametres(cle, valeur)              nom, dates de l'année, limites globales
&&   jours(num, nom, ouvre)               jours ouvrables (1 = lundi)
&&   creneaux(num, debut, fin, pause)     périodes de la journée ; pause après :
&&                                        "" / "recreation" / "repas" (une séance
&&                                        de deux heures ne franchit pas le repas)
&&   niveaux, classes(code, niveau, effectif_max, salle attitrée)
&&   matieres(code, libelle, couleur, genre enseignement | mission, max_jour)
&&   programme(niveau, matiere, heures, duree)     heures hebdomadaires par niveau,
&&                                        duree des séances (1 ou 2 créneaux)
&&   programme_classe(classe, matiere, heures)     dérogation pour une classe
&&   options(code, libelle, matiere, niveau, heures, duree, groupe_max, repartition)
&&                                        enseignement en groupe ; repartition :
&&                                        regrouper | repartir | libre
&&   eleves(id, nom, prenom, sexe F | G, niveau, profil fort | moyen | faible,
&&          classe, fixe), eleve_options(eleve, opt), affinites(eleve, autre, genre aime | evite)
&&   enseignants(code, nom, service, service_min, max_jour, max_classe)
&&   competences(enseignant, matiere, niveaux "*" ou "5e,4e"), missions(enseignant, libelle, heures)
&&   equipements(code, libelle), salles(code, libelle, batiment, etage, places, equipements "LABO,VIDEO")
&&   besoins(matiere, equipement, heures)  matrice : heures de la matière qui
&&                                        demandent l'équipement (0 : toutes)
&&   plages(id, genre, portee, cible, jour, debut, fin, du, au, libelle)
&&        portee : etablissement | niveau | classe | matiere | enseignant | salle ;
&&        sans dates (du, au) : plage hebdomadaire, contrainte de l'emploi du temps
&&        (indisponibilité, préparation, fermeture) ; avec dates : calendrier
&&        (vacances, férié, absence, travaux, sortie, examen), appliqué aux
&&        séances datées. jour nul : tous les jours ; debut / fin nuls : journée.
&& Tables calculées
&&   groupes(code, opt, num, effectif), eleve_groupes(eleve, groupe)
&&   cours(id, classe, groupe, matiere, niveau, heures, duree, enseignant)
&&   seances(id, cours, num, duree, jour, creneau, salle, epingle)

procedure CREER_SCHEMA
  sql "create table if not exists parametres(cle varchar primary key, valeur varchar)"
  sql "create table if not exists jours(num integer primary key, nom varchar, ouvre boolean)"
  sql "create table if not exists creneaux(num integer primary key, debut varchar, fin varchar, pause varchar)"
  sql "create table if not exists niveaux(code varchar primary key, libelle varchar, ordre integer)"
  sql "create table if not exists classes(code varchar primary key, niveau varchar, effectif_max integer, salle varchar)"
  sql "create table if not exists matieres(code varchar primary key, libelle varchar, couleur varchar, genre varchar, max_jour integer)"
  sql "create table if not exists programme(niveau varchar, matiere varchar, heures integer, duree integer)"
  sql "create table if not exists programme_classe(classe varchar, matiere varchar, heures integer)"
  sql [[create table if not exists options(code varchar primary key, libelle varchar, matiere varchar,
        niveau varchar, heures integer, duree integer, groupe_max integer, repartition varchar)]]
  sql [[create table if not exists eleves(id integer primary key, nom varchar, prenom varchar, sexe varchar,
        niveau varchar, profil varchar, classe varchar, fixe boolean)]]
  sql "create table if not exists eleve_options(eleve integer, opt varchar)"
  sql "create table if not exists affinites(eleve integer, autre integer, genre varchar)"
  sql [[create table if not exists enseignants(code varchar primary key, nom varchar, service integer,
        service_min integer, max_jour integer, max_classe integer)]]
  sql "create table if not exists competences(enseignant varchar, matiere varchar, niveaux varchar)"
  sql "create table if not exists missions(enseignant varchar, libelle varchar, heures integer)"
  sql "create table if not exists equipements(code varchar primary key, libelle varchar)"
  sql [[create table if not exists salles(code varchar primary key, libelle varchar, batiment varchar,
        etage integer, places integer, equipements varchar)]]
  sql "create table if not exists besoins(matiere varchar, equipement varchar, heures integer)"
  sql [[create table if not exists plages(id integer, genre varchar, portee varchar, cible varchar, jour integer,
        debut varchar, fin varchar, du date, au date, libelle varchar)]]
  sql "create table if not exists groupes(code varchar primary key, opt varchar, num integer, effectif integer)"
  sql "create table if not exists eleve_groupes(eleve integer, groupe varchar)"
  sql [[create table if not exists cours(id integer, classe varchar, groupe varchar, matiere varchar, niveau varchar,
        heures integer, duree integer, enseignant varchar)]]
  sql [[create table if not exists seances(id integer, cours integer, num integer, duree integer, jour integer,
        creneau integer, salle varchar, epingle boolean)]]
retourner

&& --- paramètres --------------------------------------------------------------
fonction PARAM(cle, defaut)
  locale v = valeursql("select valeur from parametres where cle = ?", cle)
  si v = nul ou v = ""
    retourner defaut
  finsi
retourner v

fonction PARAMN(cle, defaut)
  locale v = PARAM(cle, nul)
  si v = nul
    retourner defaut
  finsi
retourner nombre(v)

procedure FIXER_PARAM(cle, v)
  sql "delete from parametres where cle = ?" avec cle
  sql "insert into parametres values (?, ?)" avec cle, chaine(v)
retourner

&& Liste d'une colonne : LISTE_SQL("select code from classes order by code")
fonction LISTE_SQL(q)
  locale l = {}
  pour chaque r dans requete(q)
    pour chaque k, v dans r
      inserer(l, v)
      sortir
    suivant
  suivant
retourner l

&& « LABO, VIDEO » -> {"LABO", "VIDEO"}
fonction MOTS_LISTE(s)
  locale l = {}
  si s = nul
    retourner l
  finsi
  pour chaque x dans decouper(chaine(s), ",")
    x = majuscule(rogner(x))
    si x <> ""
      inserer(l, x)
    finsi
  suivant
retourner l

&& --- jeu d'exemple : collège Ada Lovelace -----------------------------------
procedure CHARGER_EXEMPLE
  pour chaque t dans {"parametres", "jours", "creneaux", "niveaux", "classes", "matieres", "programme", ;
                      "programme_classe", "options", "eleves", "eleve_options", "affinites", "enseignants", ;
                      "competences", "missions", "equipements", "salles", "besoins", "plages", "groupes", ;
                      "eleve_groupes", "cours", "seances"}
    sql "delete from " + t
  suivant
  FIXER_PARAM("nom", "Collège Ada Lovelace")
  FIXER_PARAM("annee_debut", "2026-09-01")
  FIXER_PARAM("annee_fin", "2027-07-03")
  FIXER_PARAM("max_classe", 8)            && heures max d'un même enseignant dans une classe
  FIXER_PARAM("classe_max_jour", 7)       && heures max par jour pour une classe
  FIXER_PARAM("tolerance", 1)             && écart toléré à l'équilibre (filles, profils)
  FIXER_PARAM("delai", 30)                && délai de chaque résolution (secondes)

  locale noms_jours = {"Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"}
  pour i = 1 a 6
    sql "insert into jours values (?, ?, ?)" avec i, noms_jours[i], i <= 5
  suivant
  locale cr = {{"08:00", "08:55", ""}, {"08:55", "09:50", "recreation"}, {"10:05", "11:00", ""}, ;
               {"11:00", "11:55", "repas"}, {"13:30", "14:25", ""}, {"14:25", "15:20", "recreation"}, ;
               {"15:35", "16:30", ""}, {"16:30", "17:25", ""}}
  pour i = 1 a #cr
    sql "insert into creneaux values (?, ?, ?, ?)" avec i, cr[i][1], cr[i][2], cr[i][3]
  suivant

  pour chaque n dans {{"6e", "Sixième", 1}, {"5e", "Cinquième", 2}, {"4e", "Quatrième", 3}, {"3e", "Troisième", 4}}
    sql "insert into niveaux values (?, ?, ?)" avec n[1], n[2], n[3]
  suivant

  && équipements et salles
  pour chaque e dans {{"VIDEO", "Vidéoprojecteur"}, {"LABO", "Paillasses de laboratoire"}, {"INFO", "Postes informatiques"}, ;
                      {"GYM", "Gymnase"}, {"ARTS", "Salle d'arts plastiques"}, {"MUSIQUE", "Instruments, sono"}}
    sql "insert into equipements values (?, ?)" avec e[1], e[2]
  suivant
  && bâtiment A : salles banales sur trois niveaux
  pour etg = 0 a 2
    pour k = 1 a 6
      locale cs = "A" + etg + "0" + k
      sql "insert into salles values (?, ?, ?, ?, ?, ?)" avec cs, "Salle " + cs, "A", etg, sisinon(k = 6, 20, 30), ;
          sisinon(k <= 3, "VIDEO", "")
    suivant
  suivant
  && bâtiment B : sciences, informatique, arts
  pour chaque s dans {{"B01", "Laboratoire 1", 0, 28, "LABO,VIDEO"}, {"B02", "Laboratoire 2", 0, 28, "LABO,VIDEO"}, ;
                      {"B03", "Laboratoire 3", 0, 28, "LABO"}, {"B11", "Informatique 1", 1, 28, "INFO,VIDEO"}, ;
                      {"B12", "Informatique 2", 1, 28, "INFO"}, {"B13", "Arts plastiques", 1, 30, "ARTS,VIDEO"}, ;
                      {"B14", "Musique", 1, 30, "MUSIQUE,VIDEO"}, {"B15", "Salle polyvalente", 1, 60, "VIDEO"}}
    sql "insert into salles values (?, ?, ?, ?, ?, ?)" avec s[1], s[2], "B", s[3], s[4], s[5]
  suivant
  pour chaque s dans {{"G1", "Gymnase - plateau 1"}, {"G2", "Gymnase - plateau 2"}, {"G3", "Plateau extérieur"}}
    sql "insert into salles values (?, ?, ?, ?, ?, ?)" avec s[1], s[2], "Gymnase", 0, 32, "GYM"
  suivant

  && matières (couleur, genre, au plus N séances par jour)
  pour chaque m dans {{"FR", "Français", "#4C6EF5", 1}, {"MA", "Mathématiques", "#E8590C", 1}, ;
                      {"HG", "Histoire-géographie, EMC", "#A0522D", 1}, {"ANG", "Anglais", "#2F9E44", 1}, ;
                      {"ESP", "Espagnol (LV2)", "#F59F00", 1}, {"ALL", "Allemand (LV2)", "#FAB005", 1}, ;
                      {"LAT", "Latin", "#862E9C", 1}, {"SVT", "Sciences de la vie et de la Terre", "#37B24D", 1}, ;
                      {"PC", "Physique-chimie", "#1098AD", 1}, {"TEC", "Technologie", "#5C7CFA", 1}, ;
                      {"EPS", "Éducation physique et sportive", "#F03E3E", 1}, {"ART", "Arts plastiques", "#D6336C", 1}, ;
                      {"MUS", "Éducation musicale", "#AE3EC9", 1}}
    sql "insert into matieres values (?, ?, ?, 'enseignement', ?)" avec m[1], m[2], m[3], m[4]
  suivant
  sql "insert into matieres values ('AP', 'Accompagnement personnalisé', '#868E96', 'mission', 1)"
  sql "insert into matieres values ('VDC', 'Heure de vie de classe', '#495057', 'mission', 1)"

  && programme : heures hebdomadaires par niveau et durée des séances
  locale prog = {{"FR", 5, 5, 4, 4}, {"MA", 4, 4, 4, 4}, {"HG", 3, 3, 3, 4}, {"ANG", 4, 3, 3, 3}, ;
                 {"SVT", 1, 2, 2, 2}, {"PC", 1, 2, 2, 2}, {"TEC", 1, 2, 2, 1}, {"EPS", 4, 3, 3, 3}, ;
                 {"ART", 1, 1, 1, 1}, {"MUS", 1, 1, 1, 1}, {"AP", 1, 0, 0, 0}, {"VDC", 0, 0, 0, 1}}
  locale niv = {"6e", "5e", "4e", "3e"}
  pour chaque p dans prog
    pour k = 1 a 4
      si p[k + 1] > 0
        sql "insert into programme values (?, ?, ?, ?)" avec niv[k], p[1], p[k + 1], sisinon(p[1] = "EPS", 2, 1)
      finsi
    suivant
  suivant
  && dérogation : la 3eD (section sportive) a une heure d'EPS de plus
  sql "insert into programme_classe values ('3D', 'EPS', 4)"

  && besoins en équipements (0 = toutes les heures de la matière)
  pour chaque b dans {{"PC", "LABO", 0}, {"SVT", "LABO", 1}, {"TEC", "INFO", 0}, {"EPS", "GYM", 0}, ;
                      {"ART", "ARTS", 0}, {"MUS", "MUSIQUE", 0}, {"ANG", "VIDEO", 1}, {"HG", "VIDEO", 1}}
    sql "insert into besoins values (?, ?, ?)" avec b[1], b[2], b[3]
  suivant

  && classes : quatre par niveau, salle attitrée dans le bâtiment A
  locale ns = 0
  pour k = 1 a 4
    pour chaque l dans {"A", "B", "C", "D"}
      ns += 1
      locale sa = "A" + entier((ns - 1) / 5) + "0" + (1 + mod(ns - 1, 5))
      sql "insert into classes values (?, ?, 30, ?)" avec gauche(niv[k], 1) + l, niv[k], sa
    suivant
  suivant

  && options : LV2 (5e, 4e, 3e), latin (5e, 4e, 3e)
  pour k = 2 a 4
    sql "insert into options values (?, ?, 'ESP', ?, ?, 1, 30, 'libre')" avec "ESP" + niv[k], "Espagnol " + niv[k], niv[k], sisinon(k = 4, 2, 3)
    sql "insert into options values (?, ?, 'ALL', ?, ?, 1, 30, 'regrouper')" avec "ALL" + niv[k], "Allemand " + niv[k], niv[k], sisinon(k = 4, 2, 3)
    sql "insert into options values (?, ?, 'LAT', ?, 2, 1, 30, 'regrouper')" avec "LAT" + niv[k], "Latin " + niv[k], niv[k]
  suivant

  && élèves
  locale prenomsf = {"Emma", "Jade", "Louise", "Alice", "Chloé", "Lina", "Léa", "Rose", "Anna", "Mila", "Inès", ;
                     "Julia", "Zoé", "Léna", "Ambre", "Agathe", "Iris", "Nina", "Sarah", "Lou", "Eva", "Manon", "Camille", "Salomé"}
  locale prenomsg = {"Gabriel", "Léo", "Raphaël", "Arthur", "Louis", "Jules", "Adam", "Maël", "Lucas", "Hugo", "Noah", ;
                     "Liam", "Sacha", "Gabin", "Nathan", "Tom", "Éthan", "Paul", "Aaron", "Timéo", "Victor", "Malo", "Nino", "Axel"}
  locale nomsfam = {"Martin", "Bernard", "Thomas", "Petit", "Robert", "Richard", "Durand", "Dubois", "Moreau", "Laurent", ;
                    "Simon", "Michel", "Lefebvre", "Leroy", "Roux", "David", "Bertrand", "Morel", "Fournier", "Girard", ;
                    "Bonnet", "Dupont", "Lambert", "Fontaine", "Rousseau", "Vincent", "Muller", "Lefèvre", "Faure", "André", ;
                    "Mercier", "Blanc", "Guerin", "Boyer", "Garnier", "Chevalier", "François", "Legrand", "Gauthier", "Garcia"}
  locale id = 0
  locale graine = 7
  pour k = 1 a 4
    locale effectif = 104 + 2 * k
    locale premiers = id + 1
    pour i = 1 a effectif
      id += 1
      graine = mod(graine * 1103515245 + 12345, 2147483648)
      locale tirage = mod(entier(graine / 65536), 1000)
      locale sx = sisinon(mod(tirage, 2) = 0, "F", "G")
      locale pr = sisinon(sx = "F", prenomsf[1 + mod(tirage, #prenomsf)], prenomsg[1 + mod(tirage, #prenomsg)])
      locale nf = nomsfam[1 + mod(entier(tirage / 7) + id, #nomsfam)]
      locale pf = sisinon(tirage < 300, "fort", sisinon(tirage < 750, "moyen", "faible"))
      sql "insert into eleves values (?, ?, ?, ?, ?, ?, NULL, false)" avec id, nf, pr, sx, niv[k], pf
      && options (à partir de la 5e) : LV2 espagnol (70 %) ou allemand, latin (20 %)
      si k >= 2
        sql "insert into eleve_options values (?, ?)" avec id, sisinon(mod(tirage, 10) < 7, "ESP", "ALL") + niv[k]
        si mod(entier(tirage / 10), 5) = 0
          sql "insert into eleve_options values (?, ?)" avec id, "LAT" + niv[k]
        finsi
      finsi
    suivant
    && affinités : élèves à réunir et à séparer
    pour i = 1 a 14
      locale a = premiers + mod(i * 37, effectif)
      locale b = premiers + mod(i * 37 + 5 + i, effectif)
      sql "insert into affinites values (?, ?, 'aime')" avec a, b
    suivant
    pour i = 1 a 8
      locale a = premiers + mod(i * 53 + 11, effectif)
      locale b = premiers + mod(i * 29 + 3, effectif)
      si a <> b
        sql "insert into affinites values (?, ?, 'evite')" avec a, b
      finsi
    suivant
  suivant

  && enseignants : {code, nom, service, matières, niveaux}
  locale profs = {{"FR1", "Mme Arnaud", 18, "FR", "*"}, {"FR2", "M. Benoît", 18, "FR", "*"}, ;
                  {"FR3", "Mme Carré", 15, "FR,LAT", "*"}, {"FR4", "M. Delmas", 18, "FR,AP", "*"}, ;
                  {"FR5", "Mme Esnault", 12, "FR", "*"}, ;
                  {"MA1", "M. Fabre", 18, "MA", "*"}, {"MA2", "Mme Gilles", 18, "MA", "*"}, ;
                  {"MA3", "M. Hamon", 18, "MA,AP", "*"}, {"MA4", "Mme Ibert", 16, "MA", "*"}, ;
                  {"HG1", "M. Jacob", 18, "HG,VDC", "*"}, {"HG2", "Mme Klein", 18, "HG", "*"}, ;
                  {"HG3", "M. Lenoir", 18, "HG,AP", "*"}, ;
                  {"AN1", "Mme Marchal", 18, "ANG", "*"}, {"AN2", "M. Noël", 18, "ANG", "*"}, ;
                  {"AN3", "Mme Olivier", 18, "ANG,VDC", "*"}, ;
                  {"ES1", "M. Pons", 18, "ESP", "*"}, {"ES2", "Mme Quentin", 18, "ESP,VDC", "*"}, ;
                  {"AL1", "M. Renaud", 18, "ALL", "*"}, ;
                  {"SV1", "Mme Simon", 18, "SVT", "*"}, {"SV2", "M. Tessier", 12, "SVT,VDC", "*"}, ;
                  {"PC1", "M. Ugo", 18, "PC", "*"}, {"PC2", "Mme Vidal", 12, "PC,TEC", "*"}, ;
                  {"TE1", "M. Weber", 18, "TEC", "*"}, {"TE2", "Mme Roche", 9, "TEC", "*"}, ;
                  {"EP1", "Mme Xavier", 20, "EPS", "*"}, {"EP2", "M. Yvon", 20, "EPS", "*"}, ;
                  {"EP3", "Mme Zola", 20, "EPS", "*"}, ;
                  {"AR1", "M. Aubert", 18, "ART", "*"}, {"MU1", "Mme Blin", 18, "MUS", "*"}}
  pour chaque p dans profs
    sql "insert into enseignants values (?, ?, ?, ?, 6, NULL)" avec p[1], p[2], p[3], p[3] - 3
    pour chaque m dans decouper(p[4], ",")
      sql "insert into competences values (?, ?, ?)" avec p[1], m, p[5]
    suivant
  suivant
  sql "insert into missions values ('MA1', 'Coordination de mathématiques', 1)"
  sql "insert into missions values ('TE1', 'Référent numérique', 2)"

  && plages hebdomadaires (contraintes de l'emploi du temps)
  locale pid = 0
  pour chaque p dans {{"fermeture", "etablissement", "", 3, "12:00", "18:00", "Mercredi après-midi libéré"}, ;
                      {"indisponible", "enseignant", "FR5", 5, nul, nul, "Temps partiel : vendredi"}, ;
                      {"indisponible", "enseignant", "FR5", 1, nul, nul, "Temps partiel : lundi"}, ;
                      {"indisponible", "enseignant", "MA4", 4, nul, nul, "Temps partiel : jeudi"}, ;
                      {"indisponible", "enseignant", "PC2", 2, "13:00", "18:00", "Mardi après-midi : autre établissement"}, ;
                      {"indisponible", "enseignant", "AR1", 1, "08:00", "10:00", "Lundi matin"}, ;
                      {"preparation", "salle", "B01", 5, "15:30", "18:00", "Préparation des TP"}, ;
                      {"indisponible", "matiere", "EPS", nul, "08:00", "08:55", "Pas d'EPS à la première heure"}}
    pid += 1
    sql "insert into plages values (?, ?, ?, ?, ?, ?, ?, NULL, NULL, ?)" avec pid, p[1], p[2], p[3], p[4], p[5], p[6], p[7]
  suivant
  && calendrier (plages datées)
  pour chaque p dans {{"vacances", "etablissement", "", "2026-10-17", "2026-11-01", "Vacances de la Toussaint"}, ;
                      {"ferie", "etablissement", "", "2026-11-11", "2026-11-11", "Armistice"}, ;
                      {"vacances", "etablissement", "", "2026-12-19", "2027-01-03", "Vacances de Noël"}, ;
                      {"vacances", "etablissement", "", "2027-02-13", "2027-02-28", "Vacances d'hiver"}, ;
                      {"ferie", "etablissement", "", "2027-03-29", "2027-03-29", "Lundi de Pâques"}, ;
                      {"vacances", "etablissement", "", "2027-04-10", "2027-04-25", "Vacances de printemps"}, ;
                      {"ferie", "etablissement", "", "2027-05-06", "2027-05-07", "Pont de l'Ascension"}, ;
                      {"ferie", "etablissement", "", "2027-05-17", "2027-05-17", "Lundi de Pentecôte"}, ;
                      {"examen", "niveau", "3e", "2027-01-21", "2027-01-22", "Brevet blanc"}, ;
                      {"sortie", "niveau", "3e", "2027-02-01", "2027-02-05", "Stage d'observation"}, ;
                      {"sortie", "classe", "4B", "2027-03-15", "2027-03-19", "Voyage scolaire à Berlin"}, ;
                      {"absence", "enseignant", "MA2", "2026-11-23", "2026-11-25", "Formation"}, ;
                      {"absence", "enseignant", "HG1", "2027-01-11", "2027-01-15", "Congé"}, ;
                      {"travaux", "salle", "B11", "2027-03-01", "2027-03-12", "Recâblage du réseau"}, ;
                      {"vacances", "etablissement", "", "2027-07-03", "2027-07-03", "Début des vacances d'été"}}
    pid += 1
    sql "insert into plages values (?, ?, ?, ?, NULL, NULL, NULL, ?::DATE, ?::DATE, ?)" avec pid, p[1], p[2], p[3], p[4], p[5], p[6]
  suivant
retourner
