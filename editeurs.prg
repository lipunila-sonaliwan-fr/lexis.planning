&& CC BY-NC-SA 4.0 - jean-marc "jihem" quere 2026
&& Gestion d'établissement : éditeur générique des tables (grille de saisie)
&& et éditeur de la matrice des équipements par matière.
&&
&& Une table est décrite par {table, titre, ordre, aide, colonnes} ; chaque
&& colonne par {nom, titre, genre, largeur, choix} :
&&   genre texte | nombre | case | combo (choix : liste ou requête SQL) |
&&   ref (élève : affiché « 12 · Nom Prénom », enregistré 12).
&& L'enregistrement remplace tout le contenu de la table, dans une transaction.

fonction COL(nom, titre, genre, largeur, choix)
retourner {nom = nom, titre = titre, genre = genre, largeur = largeur, choix = choix}

fonction TABLES_EDITABLES()
  locale niveaux = "select code from niveaux order by ordre"
  locale matieres = "select code from matieres order by code"
  locale classes = "select code from classes order by code"
  locale salles = "select code from salles order by code"
  locale profs = "select code from enseignants order by code"
  locale lst = {}
  inserer(lst, {table = "parametres", titre = "Paramètres", ordre = "cle", ;
    aide = "nom ; annee_debut, annee_fin (AAAA-MM-JJ) ; max_classe : heures max d'un même enseignant dans une classe ; classe_max_jour : heures max par jour d'une classe ; tolerance : écart toléré à l'équilibre des classes ; delai : secondes par résolution", ;
    colonnes = {COL("cle", "Paramètre", "texte", 160, nul), COL("valeur", "Valeur", "texte", 260, nul)}})
  inserer(lst, {table = "jours", titre = "Jours ouvrables", ordre = "num", aide = "1 = lundi ; décochez les jours sans cours.", ;
    colonnes = {COL("num", "N°", "nombre", 50, nul), COL("nom", "Jour", "texte", 120, nul), COL("ouvre", "Ouvrable", "case", 90, nul)}})
  inserer(lst, {table = "creneaux", titre = "Créneaux horaires", ordre = "num", ;
    aide = "Pause après le créneau : une séance de deux créneaux ne franchit pas le repas.", ;
    colonnes = {COL("num", "N°", "nombre", 50, nul), COL("debut", "Début", "texte", 80, nul), COL("fin", "Fin", "texte", 80, nul), ;
                COL("pause", "Pause après", "combo", 120, {"", "recreation", "repas"})}})
  inserer(lst, {table = "niveaux", titre = "Niveaux", ordre = "ordre", aide = "", ;
    colonnes = {COL("code", "Code", "texte", 70, nul), COL("libelle", "Libellé", "texte", 180, nul), COL("ordre", "Ordre", "nombre", 70, nul)}})
  inserer(lst, {table = "classes", titre = "Classes", ordre = "niveau, code", aide = "Salle attitrée : préférée lors de l'attribution des salles.", ;
    colonnes = {COL("code", "Classe", "texte", 80, nul), COL("niveau", "Niveau", "combo", 80, niveaux), ;
                COL("effectif_max", "Effectif max", "nombre", 100, nul), COL("salle", "Salle attitrée", "combo", 110, salles)}})
  inserer(lst, {table = "matieres", titre = "Matières et missions", ordre = "code", ;
    aide = "max_jour : séances d'un même cours par jour (relevé automatiquement si le cours en compte trop).", ;
    colonnes = {COL("code", "Code", "texte", 70, nul), COL("libelle", "Libellé", "texte", 260, nul), COL("couleur", "Couleur", "texte", 90, nul), ;
                COL("genre", "Genre", "combo", 120, {"enseignement", "mission"}), COL("max_jour", "Max / jour", "nombre", 90, nul)}})
  inserer(lst, {table = "programme", titre = "Programme (heures par niveau)", ordre = "niveau, matiere", ;
    aide = "Heures hebdomadaires de chaque matière par niveau ; durée des séances en créneaux (1 ou 2).", ;
    colonnes = {COL("niveau", "Niveau", "combo", 80, niveaux), COL("matiere", "Matière", "combo", 100, matieres), ;
                COL("heures", "Heures", "nombre", 80, nul), COL("duree", "Durée séance", "combo", 110, {"1", "2"})}})
  inserer(lst, {table = "programme_classe", titre = "Dérogations par classe", ordre = "classe, matiere", ;
    aide = "Heures d'une matière pour une classe particulière (0 : supprimée).", ;
    colonnes = {COL("classe", "Classe", "combo", 80, classes), COL("matiere", "Matière", "combo", 100, matieres), COL("heures", "Heures", "nombre", 80, nul)}})
  inserer(lst, {table = "options", titre = "Options (enseignements de groupe)", ordre = "niveau, code", ;
    aide = "Répartition : regrouper (élèves concentrés dans peu de classes), repartir (équilibrés), libre.", ;
    colonnes = {COL("code", "Code", "texte", 90, nul), COL("libelle", "Libellé", "texte", 160, nul), COL("matiere", "Matière", "combo", 90, matieres), ;
                COL("niveau", "Niveau", "combo", 70, niveaux), COL("heures", "Heures", "nombre", 70, nul), COL("duree", "Durée", "combo", 70, {"1", "2"}), ;
                COL("groupe_max", "Groupe max", "nombre", 100, nul), COL("repartition", "Répartition", "combo", 110, {"regrouper", "repartir", "libre"})}})
  inserer(lst, {table = "eleves", titre = "Élèves", ordre = "niveau, nom, prenom", ;
    aide = "Classe : résultat de la répartition, ou imposée si « fixe » est coché.", ;
    colonnes = {COL("id", "N°", "nombre", 60, nul), COL("nom", "Nom", "texte", 130, nul), COL("prenom", "Prénom", "texte", 110, nul), ;
                COL("sexe", "Sexe", "combo", 60, {"F", "G"}), COL("niveau", "Niveau", "combo", 70, niveaux), ;
                COL("profil", "Profil", "combo", 90, {"fort", "moyen", "faible"}), COL("classe", "Classe", "combo", 80, classes), ;
                COL("fixe", "Fixe", "case", 60, nul)}})
  inserer(lst, {table = "eleve_options", titre = "Options des élèves", ordre = "opt, eleve", aide = "", ;
    colonnes = {COL("eleve", "Élève", "ref", 260, nul), COL("opt", "Option", "combo", 110, "select code from options order by code")}})
  inserer(lst, {table = "affinites", titre = "Affinités entre élèves", ordre = "genre, eleve", ;
    aide = "aime : à réunir si possible ; evite : jamais dans la même classe.", ;
    colonnes = {COL("eleve", "Élève", "ref", 240, nul), COL("autre", "Autre élève", "ref", 240, nul), COL("genre", "Genre", "combo", 80, {"aime", "evite"})}})
  inserer(lst, {table = "enseignants", titre = "Enseignants", ordre = "code", ;
    aide = "service : heures maximales (missions comprises) ; service_min : sous ce total, sous-service ; max_jour : heures par jour ; max_classe : limite propre (sinon paramètre).", ;
    colonnes = {COL("code", "Code", "texte", 70, nul), COL("nom", "Nom", "texte", 170, nul), COL("service", "Service", "nombre", 80, nul), ;
                COL("service_min", "Service min", "nombre", 100, nul), COL("max_jour", "Max / jour", "nombre", 90, nul), COL("max_classe", "Max / classe", "nombre", 100, nul)}})
  inserer(lst, {table = "competences", titre = "Compétences (matières / niveaux)", ordre = "enseignant, matiere", ;
    aide = "Niveaux : * pour tous, sinon liste (ex. 6e,5e).", ;
    colonnes = {COL("enseignant", "Enseignant", "combo", 100, profs), COL("matiere", "Matière", "combo", 100, matieres), COL("niveaux", "Niveaux", "texte", 120, nul)}})
  inserer(lst, {table = "missions", titre = "Missions et décharges", ordre = "enseignant", aide = "Heures retirées du service disponible.", ;
    colonnes = {COL("enseignant", "Enseignant", "combo", 100, profs), COL("libelle", "Mission", "texte", 240, nul), COL("heures", "Heures", "nombre", 80, nul)}})
  inserer(lst, {table = "equipements", titre = "Équipements", ordre = "code", aide = "", ;
    colonnes = {COL("code", "Code", "texte", 90, nul), COL("libelle", "Libellé", "texte", 240, nul)}})
  inserer(lst, {table = "salles", titre = "Salles et locaux", ordre = "batiment, code", aide = "Équipements : codes séparés par des virgules (ex. LABO,VIDEO).", ;
    colonnes = {COL("code", "Code", "texte", 70, nul), COL("libelle", "Libellé", "texte", 180, nul), COL("batiment", "Bâtiment", "texte", 90, nul), ;
                COL("etage", "Étage", "nombre", 60, nul), COL("places", "Places", "nombre", 70, nul), COL("equipements", "Équipements", "texte", 160, nul)}})
  inserer(lst, {table = "besoins", titre = "Équipements par matière (matrice)", ordre = "", matrice = vrai, ;
    aide = "Pour chaque matière et chaque équipement : vide (pas besoin), « toutes » (toutes les heures), ou nombre d'heures hebdomadaires qui en ont besoin.", ;
    colonnes = {}})
  inserer(lst, {table = "plages", titre = "Plages : réservations et calendrier", ordre = "du nulls first, id", ;
    aide = "Sans dates : plage hebdomadaire (contrainte de l'emploi du temps). Avec dates (AAAA-MM-JJ) : calendrier. Portée : etablissement, niveau, classe, matiere, enseignant, salle ; jour 1 = lundi (vide : tous) ; début / fin HH:MM (vides : journée).", ;
    colonnes = {COL("id", "N°", "nombre", 50, nul), COL("genre", "Genre", "combo", 110, {"fermeture", "indisponible", "preparation", "travaux", "vacances", "ferie", "absence", "sortie", "examen"}), ;
                COL("portee", "Portée", "combo", 110, {"etablissement", "niveau", "classe", "matiere", "enseignant", "salle"}), ;
                COL("cible", "Cible", "texte", 80, nul), COL("jour", "Jour", "combo", 55, {"", "1", "2", "3", "4", "5", "6"}), ;
                COL("debut", "Début", "texte", 65, nul), COL("fin", "Fin", "texte", 65, nul), COL("du", "Du", "texte", 100, nul), ;
                COL("au", "Au", "texte", 100, nul), COL("libelle", "Libellé", "texte", 220, nul)}})
retourner lst

&& Choix d'une colonne combo (liste fixe ou requête SQL).
fonction CHOIX(c)
  si c.choix = nul
    retourner {}
  finsi
  si type(c.choix) = "table"
    retourner c.choix
  finsi
  locale l = {""}
  pour chaque v dans LISTE_SQL(c.choix)
    inserer(l, chaine(v))
  suivant
retourner l

&& Libellés des élèves pour les colonnes ref : {id -> "12 · Nom Prénom"}, liste triée.
fonction REFS_ELEVES()
  locale par = {}
  locale l = {}
  pour chaque e dans requete("select id, nom, prenom, niveau from eleves order by nom, prenom")
    locale s = e.id + " · " + e.nom + " " + e.prenom + " (" + e.niveau + ")"
    par[e.id] = s
    inserer(l, s)
  suivant
retourner {par = par, liste = l}

&& Remplit la grille g avec la table décrite par spec.
procedure CHARGER_TABLE(g, spec)
  si spec.matrice
    CHARGER_MATRICE(g)
    retourner
  finsi
  g:vider()
  && la grille n'a pas de suppression de colonnes : on la reconstruit par l'appelant
  locale refs = nul
  locale noms = {}
  pour chaque c dans spec.colonnes
    inserer(noms, c.nom)
    si c.genre = "ref" et refs = nul
      refs = REFS_ELEVES()
    finsi
  suivant
  locale q = "select " + joindre(noms, ", ") + " from " + spec.table + sisinon(spec.ordre <> "", " order by " + spec.ordre, "")
  pour chaque r dans requete(q)
    locale cel = {}
    pour chaque c dans spec.colonnes
      locale v = r[majuscule(c.nom)]
      faire cas
      cas v = nul
        inserer(cel, sisinon(c.genre = "case", "faux", ""))
      cas c.genre = "case"
        inserer(cel, sisinon(v, "vrai", "faux"))
      cas c.genre = "ref"
        inserer(cel, refs.par[v] ou chaine(v))
      autrement
        inserer(cel, chaine(v))
      fincas
    suivant
    g:ajouterligne(cel)
  suivant
retourner

&& Valeur SQL d'une cellule.
fonction LITTERAL(c, s)
  s = rogner(chaine(s ou ""))
  faire cas
  cas c.genre = "case"
    retourner sisinon(s = "vrai" ou s = "1", "true", "false")
  cas s = ""
    retourner "NULL"
  cas c.genre = "nombre"
    locale n = nombre(remplacertexte(s, ",", "."))
    si n = nul
      erreur "« " + s + " » n'est pas un nombre (colonne " + c.titre + ")"
    finsi
    retourner chaine(n)
  cas c.genre = "ref"
    locale n = nombre(decouper(s, " ")[1])
    si n = nul
      erreur "élève inconnu : « " + s + " »"
    finsi
    retourner chaine(n)
  fincas
retourner "'" + remplacertexte(s, "'", "''") + "'"

&& Enregistre la grille dans sa table ; renvoie le nombre de lignes.
fonction ENREGISTRER_TABLE(g, spec)
  si spec.matrice
    retourner ENREGISTRER_MATRICE(g)
  finsi
  locale noms = {}
  pour chaque c dans spec.colonnes
    inserer(noms, c.nom)
  suivant
  locale lignes = {}
  pour i = 1 a g:nombre()
    locale cel = g:ligne(i)
    locale vide = vrai
    locale vals = {}
    pour j = 1 a #spec.colonnes
      locale c = spec.colonnes[j]
      locale s = rogner(chaine(cel[j] ou ""))
      si s <> "" et c.genre <> "case"
        vide = faux
      finsi
      inserer(vals, LITTERAL(c, s))
    suivant
    si non vide
      inserer(lignes, "(" + joindre(vals, ", ") + ")")
    finsi
  suivant
  sql "begin transaction"
  essayer
    sql "delete from " + spec.table
    si #lignes > 0
      sql "insert into " + spec.table + " (" + joindre(noms, ", ") + ") values " + joindre(lignes, ", ")
    finsi
    sql "commit"
  capturer e
    sql "rollback"
    erreur e
  finessayer
retourner #lignes

&& --- matrice des équipements par matière ----------------------------------------
procedure CHARGER_MATRICE(g)
  g:vider()
  locale eqs = LISTE_SQL("select code from equipements order by code")
  pour chaque m dans requete("select code, libelle from matieres order by code")
    locale cel = {m.code + " · " + m.libelle}
    pour chaque e dans eqs
      locale h = valeursql("select heures from besoins where matiere = ? and equipement = ?", m.code, e)
      inserer(cel, sisinon(h = nul, "", sisinon(h = 0, "toutes", chaine(h))))
    suivant
    g:ajouterligne(cel)
  suivant
retourner

fonction ENREGISTRER_MATRICE(g)
  locale eqs = LISTE_SQL("select code from equipements order by code")
  locale lignes = {}
  pour i = 1 a g:nombre()
    locale cel = g:ligne(i)
    locale mat = rogner(decouper(cel[1], "·")[1])
    pour j = 1 a #eqs
      locale s = rogner(chaine(cel[j + 1] ou ""))
      si s <> ""
        locale h = sisinon(s = "toutes", 0, nombre(s))
        si h = nul
          erreur "« " + s + " » : indiquez « toutes » ou un nombre d'heures (" + mat + " / " + eqs[j] + ")"
        finsi
        inserer(lignes, "('" + mat + "', '" + eqs[j] + "', " + h + ")")
      finsi
    suivant
  suivant
  sql "delete from besoins"
  si #lignes > 0
    sql "insert into besoins values " + joindre(lignes, ", ")
  finsi
retourner #lignes

&& Colonnes de la grille pour une table (la grille est recréée à chaque table).
procedure COLONNES_GRILLE(g, spec)
  si spec.matrice
    g:ajoutercolonne{nom = "matiere", titre = "Matière", genre = "texte", largeur = 260}
    pour chaque e dans LISTE_SQL("select code from equipements order by code")
      g:ajoutercolonne{nom = e, titre = e, genre = "combo", largeur = 90, choix = {"", "toutes", "1", "2", "3", "4", "5"}}
    suivant
    retourner
  finsi
  locale refs = nul
  pour chaque c dans spec.colonnes
    faire cas
    cas c.genre = "combo"
      g:ajoutercolonne{nom = c.nom, titre = c.titre, genre = "combo", largeur = c.largeur, choix = CHOIX(c)}
    cas c.genre = "ref"
      si refs = nul
        refs = REFS_ELEVES()
      finsi
      g:ajoutercolonne{nom = c.nom, titre = c.titre, genre = "combo", largeur = c.largeur, choix = refs.liste}
    cas c.genre = "nombre"
      g:ajoutercolonne{nom = c.nom, titre = c.titre, genre = "nombre", largeur = c.largeur}
    cas c.genre = "case"
      g:ajoutercolonne{nom = c.nom, titre = c.titre, genre = "case", largeur = c.largeur}
    autrement
      g:ajoutercolonne{nom = c.nom, titre = c.titre, genre = "texte", largeur = c.largeur}
    fincas
  suivant
retourner
