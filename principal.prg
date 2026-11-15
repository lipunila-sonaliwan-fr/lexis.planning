&& CC BY-NC-SA 4.0 - jean-marc "jihem" quere 2026
&& Gestion d'établissement scolaire : répartition des élèves, services des
&& enseignants, emploi du temps, salles et calendrier de l'année, résolus par
&& le solveur de contraintes de wdreka (paquet wdreka, langage NCP).
&&
&&   wdlexisrt exemples/etablissement/principal.prg [base.duckdb]
&&
&& Base par défaut : ~/etablissement_lexis/etablissement.duckdb ; une base vide
&& reçoit le jeu d'exemple (collège Ada Lovelace, 16 classes, 436 élèves).
&&
&& Fichiers :
&&   donnees.prg     schéma, paramètres, jeu d'exemple
&&   editeurs.prg    saisie des tables (grilles) et matrice équipements × matières
&&   repartition.prg répartition des élèves (wdreka) et groupes d'options
&&   services.prg    cours et affectation des services (wdreka)
&&   edt.prg         emploi du temps et salles (wdreka), contrôle indépendant
&&   calendrier.prg  projection sur l'année (vacances, absences, travaux)
&&   planning.prg    plannings des classes, enseignants et salles (SVG)

os = paquet("systeme")
ui = paquet("interface")
NL = car(10)

CHEMIN_BASE = fichier.joindre(fichier.dossierperso(), "planning_lexis", "planning.duckdb")
si #systeme.args >= 1
  CHEMIN_BASE = fichier.absolu(systeme.args[1])
finsi
fichier.creerdossier(fichier.dossier(CHEMIN_BASE))
ouvrirbase(CHEMIN_BASE)
CREER_SCHEMA()
NOUVELLE_BASE = valeursql("select count(*) from classes") = 0
si NOUVELLE_BASE
  CHARGER_EXEMPLE()
finsi

&& état partagé
OCCUPE = faux
MODELE_EN_COURS = nul
ETAPE_EN_COURS = ""
SPECS = TABLES_EDITABLES()
SPEC_COURANTE = nul
SEANCE_CHOISIE = nul
LUNDI_VU = nul
PLANNING_COURANT = nul
GENRES_VUE = {"classe", "enseignant", "salle"}
COLONNES_VUE = {"c.classe", "c.enseignant", "s.salle"}
LISTE_CIBLES = {}

&&
&& accueil
&&

globale RACINE=fichier.dossier(os.args[0])
ACCUEIL()
ui.executer()

&&
&& fenêtre principale
&&

procedure MENUPLAN()
  fen = ui.fenetre{titre = "Planning - Lexis+ et wdreka - Module \"Établissenent\"", largeur = 1500, hauteur = 940, disposition = "bordure"}

  haut = fen:ajouter(ui.rangee())
  haut.ancrage = "haut"
  haut.marge = 8
  haut.espacement = 8
  titre = haut:ajouter(ui.etiquette(PARAM("nom", "Établissement")))
  titre.poids = 1
  btout = haut:ajouter(ui.bouton("Tout générer"))
  btout.infobulle = "Répartition, services, emploi du temps et calendrier, à la suite"
  btout.surclic = @TOUT_GENERER
  barreter = haut:ajouter(ui.bouton("Arrêter"))
  barreter.infobulle = "Arrête la résolution en cours (la meilleure solution trouvée est gardée)"
  barreter.surclic = @ARRETER
  bexemple = haut:ajouter(ui.bouton("Recharger l'exemple"))
  bexemple.surclic = @RECHARGER_EXEMPLE

  bas = fen:ajouter(ui.rangee())
  bas.ancrage = "bas"
  bas.marge = 6
  bas.espacement = 8
  etat = bas:ajouter(ui.etiquette("Prêt."))
  etat.poids = 1
  jauge = bas:ajouter(ui.jauge())
  jauge.largeurfixe = 240
  jauge.max = 1
  jauge.num = 0

  onglets = fen:ajouter(ui.onglets())
  onglets.ancrage = "centre"

  && onglet Données
  pdon = onglets:ajouterpage("Données")
  sdon = pdon:ajouter(ui.separateur{vertical = vrai, position = 0.2})
  sdon.poids = 1
  listetables = sdon:ajouter(ui.liste())
  pour chaque s dans SPECS
    listetables:ajouter(s.titre)
  suivant
  listetables.surselection = @TABLE_CHOISIE
  zdon = sdon:ajouter(ui.colonne())
  outdon = zdon:ajouter(ui.rangee())
  outdon.espacement = 6
  outdon.marge = 4
  titretable = outdon:ajouter(ui.etiquette(""))
  titretable.poids = 1
  bajl = outdon:ajouter(ui.bouton("Ajouter une ligne"))
  bajl.surclic = @AJOUTER_LIGNE
  bsupl = outdon:ajouter(ui.bouton("Supprimer la ligne"))
  bsupl.surclic = @SUPPRIMER_LIGNE
  benr = outdon:ajouter(ui.bouton("Enregistrer"))
  benr.surclic = @ENREGISTRER_DONNEES
  brec = outdon:ajouter(ui.bouton("Annuler les modifications"))
  brec.surclic = @RECHARGER_DONNEES
  bcsv = outdon:ajouter(ui.bouton("Exporter CSV…"))
  bcsv.surclic = @EXPORTER_CSV
  aidetable = zdon:ajouter(ui.etiquette(""))
  aidetable.couleur = "#6C757D"
  gdonnees = nul

  && onglet Répartition
  prep = onglets:ajouterpage("Répartition")
  outrep = prep:ajouter(ui.rangee())
  outrep.espacement = 6
  outrep.marge = 4
  brep = outrep:ajouter(ui.bouton("Répartir tous les niveaux"))
  brep.surclic = @ACTION_REPARTIR
  outrep:ajouter(ui.etiquette("Niveau :"))
  cniveau = outrep:ajouter(ui.combo())
  REMPLIR_COMBO(cniveau, LISTE_SQL("select code from niveaux order by ordre"))
  brep1 = outrep:ajouter(ui.bouton("Répartir ce niveau"))
  brep1.surclic = @ACTION_REPARTIR_NIVEAU
  bgrp = outrep:ajouter(ui.bouton("Constituer les groupes d'options"))
  bgrp.surclic = @ACTION_GROUPES
  srep = prep:ajouter(ui.separateur{vertical = vrai, position = 0.62})
  srep.poids = 1
  gbilan = srep:ajouter(ui.grille{multi = faux})
  pour chaque c dans {{"classe", "Classe", 70}, {"niveau", "Niveau", 60}, {"effectif", "Effectif", 70}, {"filles", "Filles", 60}, ;
                      {"garcons", "Garçons", 70}, {"forts", "Forts", 60}, {"moyens", "Moyens", 70}, {"faibles", "Faibles", 70}, ;
                      {"options", "Options (élèves)", 330}}
    gbilan:ajoutercolonne{nom = c[1], titre = c[2], largeur = c[3]}
  suivant
  ggroupes = srep:ajouter(ui.grille{multi = faux})
  ggroupes:ajoutercolonne{nom = "groupe", titre = "Groupe d'option", largeur = 130}
  ggroupes:ajoutercolonne{nom = "effectif", titre = "Élèves", largeur = 70}
  ggroupes:ajoutercolonne{nom = "classes", titre = "Classes d'origine", largeur = 200}

  && onglet Services
  pser = onglets:ajouterpage("Services")
  outser = pser:ajouter(ui.rangee())
  outser.espacement = 6
  outser.marge = 4
  bser = outser:ajouter(ui.bouton("Construire les cours et affecter les services"))
  bser.surclic = @ACTION_SERVICES
  benrc = outser:ajouter(ui.bouton("Enregistrer les changements d'enseignant"))
  benrc.surclic = @ENREGISTRER_AFFECTATIONS
  infoser = outser:ajouter(ui.etiquette(""))
  infoser.poids = 1
  sser = pser:ajouter(ui.separateur{vertical = vrai, position = 0.55})
  sser.poids = 1
  ccours = sser:ajouter(ui.colonne())
  gcours = nul
  gprofs = sser:ajouter(ui.grille{multi = faux})
  pour chaque c dans {{"code", "Code", 60}, {"nom", "Enseignant", 140}, {"service", "Service", 70}, {"heures", "Cours", 60}, ;
                      {"missions", "Missions", 70}, {"total", "Total", 60}, {"classes", "Classes", 70}, {"preparations", "Prép.", 60}}
    gprofs:ajoutercolonne{nom = c[1], titre = c[2], largeur = c[3]}
  suivant

  && onglet Emploi du temps
  pedt = onglets:ajouterpage("Emploi du temps")
  outedt = pedt:ajouter(ui.rangee())
  outedt.espacement = 6
  outedt.marge = 4
  bedt = outedt:ajouter(ui.bouton("Générer l'emploi du temps"))
  bedt.surclic = @ACTION_EDT
  bverif = outedt:ajouter(ui.bouton("Vérifier"))
  bverif.surclic = @ACTION_VERIFIER
  outedt:ajouter(ui.etiquette("   Planning :"))
  cvue = outedt:ajouter(ui.combo("Classe", "Enseignant", "Salle"))
  cvue:selectionner(1)
  cvue.largeurfixe = 120
  cvue.surselection = @VUE_CHANGEE
  ccible = outedt:ajouter(ui.combo())
  ccible.largeurfixe = 220
  ccible.surselection = @AFFICHER_PLANNING
  cmode = outedt:ajouter(ui.combo("Semaine type", "Semaine datée"))
  cmode:selectionner(1)
  cmode.largeurfixe = 160
  cmode.surselection = @AFFICHER_PLANNING
  bprec = outedt:ajouter(ui.bouton("<"))
  bprec.largeurfixe = 34
  bprec.surclic = @SEMAINE_PRECEDENTE
  sdate = outedt:ajouter(ui.saisie{indication = "AAAA-MM-JJ"})
  sdate.largeurfixe = 110
  sdate.surtouchebas = @TOUCHE_DATE
  bsuiv = outedt:ajouter(ui.bouton(">"))
  bsuiv.largeurfixe = 34
  bsuiv.surclic = @SEMAINE_SUIVANTE
  sedt = pedt:ajouter(ui.separateur{vertical = vrai, position = 0.74})
  sedt.poids = 1
  vuetoile = sedt:ajouter(ui.toile{mode = "plateau"})
  vuetoile.surselection = @SEANCE_CLIQUEE
  zfiche = sedt:ajouter(ui.colonne())
  fiche = zfiche:ajouter(ui.markdown("Cliquez une séance du planning."))
  fiche.poids = 1
  bepingle = zfiche:ajouter(ui.bouton("Épingler / désépingler"))
  bepingle.infobulle = "Une séance épinglée garde son créneau quand l'emploi du temps est régénéré"
  bepingle.surclic = @BASCULER_EPINGLE
  rdep = zfiche:ajouter(ui.rangee())
  rdep.espacement = 4
  cdjour = rdep:ajouter(ui.combo())
  ccren = rdep:ajouter(ui.combo())
  bdep = zfiche:ajouter(ui.bouton("Déplacer vers ce créneau"))
  bdep.surclic = @DEPLACER

  && onglet Calendrier
  pcal = onglets:ajouterpage("Calendrier")
  outcal = pcal:ajouter(ui.rangee())
  outcal.espacement = 6
  outcal.marge = 4
  bcal = outcal:ajouter(ui.bouton("Projeter sur l'année"))
  bcal.surclic = @ACTION_CALENDRIER
  syncal = pcal:ajouter(ui.markdown(""))
  syncal.hauteurfixe = 150
  scal = pcal:ajouter(ui.separateur{vertical = vrai, position = 0.58})
  scal.poids = 1
  gannee = scal:ajouter(ui.grille{multi = faux})
  pour chaque c dans {{"public", "Classe / groupe", 110}, {"matiere", "Matière", 70}, {"enseignant", "Enseignant", 90}, ;
                      {"hebdo", "h / sem.", 70}, {"semaines", "Semaines", 80}, {"prevues", "Heures prévues", 110}, ;
                      {"non_assurees", "Non assurées", 100}, {"annulees", "Annulées", 80}}
    gannee:ajoutercolonne{nom = c[1], titre = c[2], largeur = c[3]}
  suivant
  gevts = scal:ajouter(ui.grille{multi = faux})
  pour chaque c dans {{"du", "Du", 95}, {"au", "Au", 95}, {"genre", "Genre", 85}, {"cible", "Pour", 110}, {"libelle", "Libellé", 220}}
    gevts:ajoutercolonne{nom = c[1], titre = c[2], largeur = c[3]}
  suivant

  && onglet Journal
  pjou = onglets:ajouterpage("Journal")
  journal = pjou:ajouter(ui.liste())
  journal.poids = 1

  && démarrage
  listetables:selectionner(1)
  TABLE_CHOISIE()
  REMPLIR_GRILLE_DATE_DEPLACEMENT()
  RAFRAICHIR_TOUT()
  NOTER("Base : " + CHEMIN_BASE)
  si NOUVELLE_BASE
    NOTER("Base vide : jeu d'exemple chargé (« Tout générer » pour tout calculer).")
  finsi
  ui.minuterie(400, @PROGRES)
  ui.executer()
retourner

&&
&& utilitaires
&&

procedure NOTER(msg)
  pour chaque ligne dans decouper(chaine(msg), NL)
    journal:ajouter(heure() + "  " + ligne)
  suivant
  journal:selectionner(journal:nombre())
retourner

procedure REMPLIR_COMBO(c, l)
  c:vider()
  pour chaque x dans l
    c:ajouter(chaine(x))
  suivant
  si #l > 0
    c:selectionner(1)
  finsi
retourner

procedure REMPLIR_GRILLE(g, lignes, colonnes)
  g:vider()
  pour chaque r dans lignes
    locale cel = {}
    pour chaque c dans colonnes
      locale v = r[majuscule(c)]
      inserer(cel, sisinon(v = nul, "", chaine(v)))
    suivant
    g:ajouterligne(cel)
  suivant
retourner

&& --- exécution des étapes -----------------------------------------------------
&& Lance une étape longue : une seule à la fois, journal, durée, erreurs.
procedure LANCER(nom, etape)
  globale OCCUPE, MODELE_EN_COURS, ETAPE_EN_COURS
  si OCCUPE
    ui.alerte("Une résolution est déjà en cours.", "info")
    retourner
  finsi
  OCCUPE = vrai
  MODELE_EN_COURS = nul
  ETAPE_EN_COURS = nom
  etat.libelle = nom + "…"
  locale t0 = systeme.horloge()
  essayer
    appeler(etape)
    NOTER(nom + " : terminé en " + arrondi(systeme.horloge() - t0, 1) + " s")
  capturer e
    NOTER(nom + " : " + e)
    ui.alerte(nom + " : " + e, "attention")
  finessayer
  OCCUPE = faux
  MODELE_EN_COURS = nul
  etat.libelle = "Prêt."
  jauge.num = 0
retourner

&& Reçoit chaque modèle wdreka avant sa résolution (progression, arrêt).
procedure SUIVI(m, etape)
  globale MODELE_EN_COURS, ETAPE_EN_COURS
  MODELE_EN_COURS = m
  si etape <> nul
    ETAPE_EN_COURS = etape
  finsi
  locale st = m:statistiques()
  NOTER("  modèle " + ETAPE_EN_COURS + " : " + st.booleens + " booléens, " + st.propagateurs + " propagateurs")
retourner

procedure PROGRES(ev)
  si non OCCUPE ou MODELE_EN_COURS = nul
    retourner
  finsi
  locale p = MODELE_EN_COURS:progression()
  si non p.encours
    retourner
  finsi
  locale delai = PARAMN("delai", 30)
  etat.libelle = "wdreka - " + ETAPE_EN_COURS + " : " + arrondi(p.duree, 1) + " s, " + p.solutions + " solution(s)" + ;
                 sisinon(p.objectif <> nul, ", coût " + p.objectif, "") + ", " + p.conflits + " conflits"
  jauge.max = delai
  jauge.num = min(delai, p.duree)
retourner

procedure ARRETER(ev)
  si MODELE_EN_COURS <> nul
    MODELE_EN_COURS:arreter()
    NOTER("Arrêt demandé : la meilleure solution trouvée est gardée.")
  finsi
retourner

procedure ETAPE_REPARTITION
  globale ETAPE_EN_COURS
  pour chaque niv dans LISTE_SQL("select code from niveaux order by ordre")
    ETAPE_EN_COURS = "répartition " + niv
    NOTER(REPARTIR_NIVEAU(niv, @SUIVI).message)
  suivant
  CONSTITUER_GROUPES()
  NOTER("Groupes d'options : " + valeursql("select count(*) from groupes") + " groupe(s)")
  RAFRAICHIR_REPARTITION()
retourner

procedure ETAPE_REPARTITION_NIVEAU
  globale ETAPE_EN_COURS
  ETAPE_EN_COURS = "répartition " + cniveau:element(cniveau:selection())
  NOTER(REPARTIR_NIVEAU(cniveau:element(cniveau:selection()), @SUIVI).message)
  CONSTITUER_GROUPES()
  RAFRAICHIR_REPARTITION()
retourner

procedure ETAPE_GROUPES
  CONSTITUER_GROUPES()
  RAFRAICHIR_REPARTITION()
retourner

procedure ETAPE_SERVICES
  globale ETAPE_EN_COURS
  ETAPE_EN_COURS = "services"
  CONSTRUIRE_COURS()
  NOTER("Cours : " + valeursql("select count(*) from cours") + " (" + valeursql("select sum(heures) from cours") + " h)")
  NOTER(AFFECTER_SERVICES(@SUIVI).message)
  RAFRAICHIR_SERVICES()
retourner

procedure ETAPE_EDT
  locale r = GENERER_EDT(@SUIVI)
  NOTER(r.message)
  si r.statut = "erreur" ou valeursql("select count(*) from seances") = 0
    erreur r.message
  finsi
  ETAPE_VERIFIER()
  sql "drop table if exists occurrences"
  VUE_CHANGEE()
retourner

procedure ETAPE_VERIFIER
  locale pb = VERIFIER_EDT()
  si #pb = 0
    NOTER("Contrôle indépendant : aucune anomalie (classes, enseignants, salles, options, plages).")
  sinon
    NOTER("Contrôle : " + #pb + " anomalie(s)")
    pour chaque x dans pb
      NOTER("  " + x)
    suivant
  finsi
retourner

procedure ETAPE_CALENDRIER
  PROJETER_CALENDRIER()
  RAFRAICHIR_CALENDRIER()
retourner

procedure ETAPE_TOUT
  ETAPE_REPARTITION()
  ETAPE_SERVICES()
  ETAPE_EDT()
  ETAPE_CALENDRIER()
retourner

procedure TOUT_GENERER(ev)
  LANCER("Tout générer", @ETAPE_TOUT)
retourner
procedure ACTION_REPARTIR(ev)
  LANCER("Répartition des élèves", @ETAPE_REPARTITION)
retourner
procedure ACTION_REPARTIR_NIVEAU(ev)
  LANCER("Répartition d'un niveau", @ETAPE_REPARTITION_NIVEAU)
retourner
procedure ACTION_GROUPES(ev)
  LANCER("Groupes d'options", @ETAPE_GROUPES)
retourner
procedure ACTION_SERVICES(ev)
  LANCER("Services des enseignants", @ETAPE_SERVICES)
retourner
procedure ACTION_EDT(ev)
  LANCER("Emploi du temps", @ETAPE_EDT)
retourner
procedure ACTION_VERIFIER(ev)
  LANCER("Contrôle de l'emploi du temps", @ETAPE_VERIFIER)
retourner
procedure ACTION_CALENDRIER(ev)
  LANCER("Calendrier de l'année", @ETAPE_CALENDRIER)
retourner

procedure RECHARGER_EXEMPLE(ev)
  si non ui.confirmer("Remplacer toutes les données par le jeu d'exemple ?")
    retourner
  finsi
  CHARGER_EXEMPLE()
  titre.libelle = PARAM("nom", "")
  TABLE_CHOISIE()
  RAFRAICHIR_TOUT()
  NOTER("Jeu d'exemple rechargé.")
retourner

procedure RAFRAICHIR_TOUT
  RAFRAICHIR_REPARTITION()
  RAFRAICHIR_SERVICES()
  VUE_CHANGEE()
  RAFRAICHIR_CALENDRIER()
retourner

&& --- onglet Données ------------------------------------------------------------
procedure TABLE_CHOISIE(ev)
  globale SPEC_COURANTE, gdonnees
  locale i = listetables:selection()
  si i < 1
    retourner
  finsi
  SPEC_COURANTE = SPECS[i]
  titretable.libelle = SPEC_COURANTE.titre
  aidetable.libelle = SPEC_COURANTE.aide
  si gdonnees <> nul
    gdonnees:detruire()
  finsi
  gdonnees = zdon:ajouter(ui.grille{multi = faux})
  gdonnees.poids = 1
  COLONNES_GRILLE(gdonnees, SPEC_COURANTE)
  gdonnees:fixermodifiable(vrai)
  CHARGER_TABLE(gdonnees, SPEC_COURANTE)
  etat.libelle = SPEC_COURANTE.titre + " : " + gdonnees:nombre() + " ligne(s)"
retourner

procedure AJOUTER_LIGNE(ev)
  si gdonnees = nul ou SPEC_COURANTE.matrice
    retourner
  finsi
  locale cel = {}
  pour chaque c dans SPEC_COURANTE.colonnes
    inserer(cel, sisinon(c.genre = "case", "faux", ""))
  suivant
  && numéro suivant pour les tables numérotées
  si SPEC_COURANTE.colonnes[1].nom = "id" ou SPEC_COURANTE.colonnes[1].nom = "num"
    cel[1] = chaine((valeursql("select max(" + SPEC_COURANTE.colonnes[1].nom + ") from " + SPEC_COURANTE.table) ou 0) + gdonnees:nombre() + 1 ;
             - valeursql("select count(*) from " + SPEC_COURANTE.table))
  finsi
  gdonnees:ajouterligne(cel)
  gdonnees:selectionner(gdonnees:nombre())
retourner

procedure SUPPRIMER_LIGNE(ev)
  si gdonnees = nul ou SPEC_COURANTE.matrice
    retourner
  finsi
  locale i = gdonnees:selection()
  si i >= 1
    gdonnees:supprimerligne(i)
  finsi
retourner

procedure ENREGISTRER_DONNEES(ev)
  si gdonnees = nul
    retourner
  finsi
  essayer
    locale n = ENREGISTRER_TABLE(gdonnees, SPEC_COURANTE)
    NOTER(SPEC_COURANTE.titre + " : " + n + " ligne(s) enregistrée(s)")
    etat.libelle = SPEC_COURANTE.titre + " enregistré."
    titre.libelle = PARAM("nom", "")
    && les listes de choix des autres tables suivent
    REMPLIR_COMBO(cniveau, LISTE_SQL("select code from niveaux order by ordre"))
    REMPLIR_GRILLE_DATE_DEPLACEMENT()
  capturer e
    ui.alerte("Enregistrement impossible : " + e, "attention")
  finessayer
retourner

procedure RECHARGER_DONNEES(ev)
  TABLE_CHOISIE()
retourner

procedure EXPORTER_CSV(ev)
  si gdonnees = nul
    retourner
  finsi
  locale p = ui.enregistrerfichier{titre = "Exporter en CSV", nom = SPEC_COURANTE.table + ".csv", filtre = "CSV|*.csv"}
  si p <> nul
    gdonnees:enregistrercsv(p)
    NOTER("Exporté : " + p)
  finsi
retourner

&& --- onglet Répartition ------------------------------------------------------
procedure RAFRAICHIR_REPARTITION
  locale opts = {}
  pour chaque r dans requete([[select classe, string_agg(opt || ' ' || n, ', ' order by opt) t from
      (select e.classe, x.opt, count(*) n from eleve_options x join eleves e on e.id = x.eleve
       where e.classe is not null group by all) group by classe]])
    opts[r.classe] = r.t
  suivant
  gbilan:vider()
  pour chaque b dans BILAN_CLASSES()
    gbilan:ajouterligne({b.classe, b.niveau, chaine(b.effectif), chaine(b.filles), chaine(b.garcons), chaine(b.forts), ;
                         chaine(b.moyens), chaine(b.faibles), opts[b.classe] ou ""})
  suivant
  REMPLIR_GRILLE(ggroupes, requete([[select g.code groupe, g.effectif, string_agg(distinct e.classe, ', ' order by e.classe) classes
      from groupes g left join eleve_groupes x on x.groupe = g.code left join eleves e on e.id = x.eleve
      group by g.code, g.effectif order by g.code]]), {"groupe", "effectif", "classes"})
retourner

&& --- onglet Services -----------------------------------------------------------
procedure RAFRAICHIR_SERVICES
  globale gcours
  si gcours <> nul
    gcours:detruire()
  finsi
  gcours = ccours:ajouter(ui.grille{multi = faux})
  gcours.poids = 1
  gcours:ajoutercolonne{nom = "id", titre = "N°", largeur = 50}
  gcours:ajoutercolonne{nom = "public", titre = "Classe / groupe", largeur = 110}
  gcours:ajoutercolonne{nom = "matiere", titre = "Matière", largeur = 70}
  gcours:ajoutercolonne{nom = "heures", titre = "Heures", largeur = 60}
  locale lp = {""}
  pour chaque x dans LISTE_SQL("select code from enseignants order by code")
    inserer(lp, x)
  suivant
  gcours:ajoutercolonne{nom = "enseignant", titre = "Enseignant", genre = "combo", largeur = 100, choix = lp}
  gcours:fixermodifiable(vrai)
  REMPLIR_GRILLE(gcours, requete("select id, coalesce(classe, groupe) public, matiere, heures, enseignant from cours order by coalesce(classe, groupe), matiere"), ;
                 {"id", "public", "matiere", "heures", "enseignant"})
  locale lignes = BILAN_SERVICES()
  gprofs:vider()
  pour chaque b dans lignes
    gprofs:ajouterligne({b.code, b.nom, chaine(b.service), chaine(b.heures), chaine(b.missions), chaine(b.heures + b.missions), ;
                         chaine(b.classes), chaine(b.preparations)})
  suivant
  locale ap = valeursql("select coalesce(sum(heures), 0) from cours where enseignant is null")
  infoser.libelle = valeursql("select count(*) from cours") + " cours ; " + sisinon(ap = 0, "toutes les heures sont couvertes", ap + " heure(s) à pourvoir")
retourner

procedure ENREGISTRER_AFFECTATIONS(ev)
  pour i = 1 a gcours:nombre()
    locale cel = gcours:ligne(i)
    locale p = rogner(cel[5])
    sql "update cours set enseignant = ? where id = ?" avec sisinon(p = "", nul, p), nombre(cel[1])
  suivant
  NOTER("Affectations enregistrées (régénérez l'emploi du temps).")
  RAFRAICHIR_SERVICES()
retourner

&& --- onglet Emploi du temps ----------------------------------------------------
procedure VUE_CHANGEE(ev)
  globale LISTE_CIBLES
  locale v = cvue:selection()
  faire cas
  cas v = 1
    LISTE_CIBLES = LISTE_SQL("select code from classes order by niveau, code")
    REMPLIR_COMBO(ccible, LISTE_CIBLES)
  cas v = 2
    LISTE_CIBLES = LISTE_SQL("select code from enseignants order by code")
    REMPLIR_COMBO(ccible, LISTE_SQL("select code || ' - ' || nom from enseignants order by code"))
  autrement
    LISTE_CIBLES = LISTE_SQL("select code from salles order by code")
    REMPLIR_COMBO(ccible, LISTE_SQL("select code || ' - ' || libelle from salles order by code"))
  fincas
  AFFICHER_PLANNING()
retourner

procedure AFFICHER_PLANNING(ev)
  globale LUNDI_VU, PLANNING_COURANT
  locale i = ccible:selection()
  si i < 1 ou i > #LISTE_CIBLES
    retourner
  finsi
  locale genre = GENRES_VUE[cvue:selection()]
  locale cible = LISTE_CIBLES[i]
  locale lundi = nul
  si cmode:selection() = 2
    si valeursql("select count(*) from information_schema.tables where table_name = 'occurrences'") = 0
      fiche.valeur = "La semaine datée demande la projection sur l'année : onglet **Calendrier**, *Projeter sur l'année*."
      cmode:selectionner(1)
    sinon
      si LUNDI_VU = nul
        LUNDI_VU = LUNDI(PARAM("annee_debut", "2026-09-01"))
      finsi
      lundi = LUNDI_VU
      sdate.valeur = lundi
    finsi
  finsi
  locale p = PLANNING_SVG(genre, cible, lundi)
  PLANNING_COURANT = p
  vuetoile:chargersvg(p.svg)
  vuetoile:ajuster()
  locale h = valeursql("select coalesce(sum(s.duree), 0) from seances s join cours c on c.id = s.cours where " + ;
                       COLONNES_VUE[cvue:selection()] + " = ?", cible)
  etat.libelle = "Planning " + genre + " " + cible + sisinon(lundi <> nul, ", semaine du " + lundi, ", semaine type") + ;
                 " : " + p.nombre + " séance(s)" + sisinon(genre = "classe", " (dont options), " + h + " h de cours", "") + ;
                 sisinon(p.perdues > 0, " ; " + p.perdues + " h annulées", "")
retourner

procedure SEMAINE_PRECEDENTE(ev)
  DECALER_SEMAINE(-7)
retourner

procedure SEMAINE_SUIVANTE(ev)
  DECALER_SEMAINE(7)
retourner

procedure DECALER_SEMAINE(n)
  globale LUNDI_VU
  si LUNDI_VU = nul
    LUNDI_VU = LUNDI(PARAM("annee_debut", "2026-09-01"))
  sinon
    LUNDI_VU = DECALER_JOURS(LUNDI_VU, n)
  finsi
  cmode:selectionner(2)
  AFFICHER_PLANNING()
retourner

procedure TOUCHE_DATE(ev)
  globale LUNDI_VU
  si ev.touche = 13 ou ev.touche = 1073741912
    essayer
      LUNDI_VU = LUNDI(rogner(sdate.valeur))
      cmode:selectionner(2)
      AFFICHER_PLANNING()
    capturer e
      ui.alerte("Date attendue au format AAAA-MM-JJ.", "attention")
    finessayer
  finsi
retourner

procedure SEANCE_CLIQUEE(ev)
  locale s = ev.texte ou ""
  si commencepar(s, "s:")
    FICHE_SEANCE(nombre(souschaine(s, 3)))
  finsi
retourner

procedure FICHE_SEANCE(id)
  globale SEANCE_CHOISIE
  SEANCE_CHOISIE = id
  locale r = requete([[select s.*, c.classe, c.groupe, c.matiere, c.niveau, c.enseignant, c.heures, m.libelle mlib,
      p.nom pnom, j.nom jnom, cr.debut, (select fin from creneaux where num = s.creneau + s.duree - 1) fin, sa.libelle slib, sa.places
    from seances s join cours c on c.id = s.cours left join matieres m on m.code = c.matiere
    left join enseignants p on p.code = c.enseignant left join jours j on j.num = s.jour
    left join creneaux cr on cr.num = s.creneau left join salles sa on sa.code = s.salle where s.id = ?]], id)
  si #r = 0
    retourner
  finsi
  r = r[1]
  locale md = "### " + r.mlib + NL + NL
  md = md + "- **" + (r.classe ou ("groupe " + r.groupe)) + "** (" + r.niveau + "), séance " + r.num + " du cours de " + r.heures + " h" + NL
  md = md + "- " + r.jnom + " " + r.debut + " - " + r.fin + NL
  md = md + "- enseignant : " + (r.pnom ou "**à pourvoir**") + NL
  md = md + "- salle : " + (r.salle ou "?") + " · " + (r.slib ou "") + " (" + (r.places ou "?") + " places)" + NL
  md = md + "- " + sisinon(r.epingle, "**épinglée** : garde ce créneau à la régénération", "non épinglée") + NL
  si r.groupe <> nul
    md = md + NL + "Classes du groupe : " + joindre(LISTE_SQL("select distinct e.classe from eleve_groupes x join eleves e on e.id = x.eleve where x.groupe = '" + ;
                                                             r.groupe + "' order by 1"), ", ") + NL
  finsi
  && occurrences particulières de l'année
  si valeursql("select count(*) from information_schema.tables where table_name = 'occurrences'") > 0
    locale ev = requete("select jour_date::varchar d, statut, motif, salle_remplacement from occurrences where seance = ? and statut <> 'prevue' order by jour_date", id)
    si #ev > 0
      md = md + NL + "**Dans l'année** (" + #ev + ") :" + NL + NL
      locale n = 0
      pour chaque x dans ev
        n += 1
        si n > 12
          md = md + "- …" + NL
          sortir
        finsi
        md = md + "- " + x.d + " : " + STATUT_LISIBLE(x.statut) + " (" + x.motif + ")" + sisinon(x.salle_remplacement <> nul, " → " + x.salle_remplacement, "") + NL
      suivant
    finsi
  finsi
  fiche.valeur = md
  && créneau proposé pour un déplacement : le créneau actuel
  cdjour:selectionner(max(1, cdjour:chercher(r.jnom)))
  ccren:selectionner(r.creneau)
retourner

fonction STATUT_LISIBLE(st)
  faire cas
  cas st = "annulee"
    retourner "annulée"
  cas st = "non assuree"
    retourner "non assurée"
  cas st = "salle changee"
    retourner "salle changée"
  cas st = "prevue"
    retourner "prévue"
  fincas
retourner st

procedure REMPLIR_GRILLE_DATE_DEPLACEMENT
  REMPLIR_COMBO(cdjour, LISTE_SQL("select nom from jours where ouvre order by num"))
  REMPLIR_COMBO(ccren, LISTE_SQL("select debut || ' - ' || fin from creneaux order by num"))
retourner

procedure BASCULER_EPINGLE(ev)
  si SEANCE_CHOISIE = nul
    retourner
  finsi
  sql "update seances set epingle = not coalesce(epingle, false) where id = ?" avec SEANCE_CHOISIE
  NOTER("Séance " + SEANCE_CHOISIE + " " + sisinon(valeursql("select epingle from seances where id = ?", SEANCE_CHOISIE), "épinglée", "désépinglée"))
  FICHE_SEANCE(SEANCE_CHOISIE)
  AFFICHER_PLANNING()
retourner

&& Déplace la séance choisie si le créneau visé est libre pour sa classe (et
&& ses options), son enseignant et sa salle (sinon une salle compatible libre
&& est cherchée) ; la séance devient épinglée.
procedure DEPLACER(ev)
  si SEANCE_CHOISIE = nul
    retourner
  finsi
  locale s = requete("select s.*, c.classe, c.groupe, c.enseignant, c.matiere, c.niveau from seances s join cours c on c.id = s.cours where s.id = ?", SEANCE_CHOISIE)[1]
  locale jnum = valeursql("select num from jours where nom = ?", cdjour:element(cdjour:selection()))
  locale cr = ccren:selection()
  locale fin = cr + s.duree - 1
  locale pb = {}
  si fin > valeursql("select count(*) from creneaux")
    inserer(pb, "la séance dépasse la fin de journée")
  finsi
  si s.duree > 1 et valeursql("select count(*) from creneaux where num >= ? and num < ? and pause = 'repas'", cr, fin) > 0
    inserer(pb, "la séance franchirait la pause du repas")
  finsi
  && plages hebdomadaires
  locale g = GRILLE()
  locale f = FERMETURES(g)
  locale d = g.rangjour[jnum]
  pour q = cr a fin
    locale u = d * g.np + q - 1
    si FERME(f, "etablissement", "", u) ou FERME(f, "enseignant", s.enseignant, u) ou FERME(f, "matiere", s.matiere, u) ;
       ou FERME(f, "niveau", s.niveau, u) ou FERME(f, "classe", s.classe, u)
      inserer(pb, "créneau fermé ou indisponible (" + g.creneaux[q].debut + ")")
      sortir
    finsi
  suivant
  && séances qui se chevaucheraient
  locale autres = requete([[select s2.id, c2.classe, c2.groupe, c2.enseignant, s2.salle, c2.matiere from seances s2 join cours c2 on c2.id = s2.cours
      where s2.id <> ? and s2.jour = ? and s2.creneau <= ? and s2.creneau + s2.duree - 1 >= ?]], s.id, jnum, fin, cr)
  locale classes_s = {}
  si s.classe <> nul
    classes_s = {s.classe}
  sinon
    classes_s = LISTE_SQL("select distinct e.classe from eleve_groupes x join eleves e on e.id = x.eleve where x.groupe = '" + s.groupe + "'")
  finsi
  locale salle_prise = faux
  pour chaque a dans autres
    si s.enseignant <> nul et a.enseignant = s.enseignant
      inserer(pb, "l'enseignant a déjà " + a.matiere + " (" + (a.classe ou a.groupe) + ")")
    finsi
    si a.classe <> nul et contient(classes_s, a.classe)
      inserer(pb, "la classe " + a.classe + " a déjà " + a.matiere)
    finsi
    si a.groupe <> nul et s.classe <> nul et valeursql("select count(*) from eleve_groupes x join eleves e on e.id = x.eleve where x.groupe = ? and e.classe = ?", a.groupe, s.classe) > 0
      inserer(pb, "des élèves de " + s.classe + " ont l'option " + a.groupe)
    finsi
    si a.groupe <> nul et s.groupe <> nul et valeursql("select count(*) from eleve_groupes a join eleve_groupes b on a.eleve = b.eleve where a.groupe = ? and b.groupe = ?", a.groupe, s.groupe) > 0
      inserer(pb, "des élèves sont dans " + a.groupe + " et " + s.groupe)
    finsi
    si a.salle = s.salle
      salle_prise = vrai
    finsi
  suivant
  si #pb > 0
    ui.alerte("Déplacement impossible :" + NL + "- " + joindre(pb, NL + "- "), "attention")
    retourner
  finsi
  locale salle = s.salle
  si salle_prise ou FERME(f, "salle", s.salle, d * g.np + cr - 1)
    salle = SALLE_LIBRE_SEMAINE(s.id, jnum, cr, s.duree)
    si salle = nul
      ui.alerte("Déplacement impossible : aucune salle compatible libre à ce créneau.", "attention")
      retourner
    finsi
  finsi
  sql "update seances set jour = ?, creneau = ?, salle = ?, epingle = true where id = ?" avec jnum, cr, salle, s.id
  NOTER("Séance " + s.id + " (" + s.matiere + " " + (s.classe ou s.groupe) + ") déplacée : " + cdjour:element(cdjour:selection()) + ;
        " " + ccren:element(cr) + ", salle " + salle + " ; épinglée.")
  si valeursql("select count(*) from information_schema.tables where table_name = 'occurrences'") > 0
    PROJETER_CALENDRIER()
    RAFRAICHIR_CALENDRIER()
  finsi
  FICHE_SEANCE(s.id)
  AFFICHER_PLANNING()
retourner

&& --- onglet Calendrier ---------------------------------------------------------
procedure RAFRAICHIR_CALENDRIER
  REMPLIR_GRILLE(gevts, requete([[select du::varchar du, au::varchar au, genre, portee || coalesce(' ' || nullif(cible, ''), '') cible, libelle
      from plages where du is not null order by du]]), {"du", "au", "genre", "cible", "libelle"})
  si valeursql("select count(*) from information_schema.tables where table_name = 'occurrences'") = 0
    syncal.valeur = "Projetez la semaine type sur l'année (" + PARAM("annee_debut", "?") + " → " + PARAM("annee_fin", "?") + ;
                    ") pour obtenir les heures réellement prévues, les séances non assurées et les changements de salle."
    gannee:vider()
    retourner
  finsi
  locale sy = SYNTHESE_ANNEE()
  locale md = "### Année " + PARAM("annee_debut", "") + " → " + PARAM("annee_fin", "") + NL + NL
  md = md + "- **" + sy.jours_cours + "** jours de cours" + NL
  md = md + "- **" + sy.heures_prevues + "** heures de cours prévues (toutes classes et groupes)" + NL
  md = md + "- **" + (sy.heures_a_remplacer ou 0) + "** heures à remplacer (absences d'enseignants)" + NL
  md = md + "- **" + (sy.changements_salle ou 0) + "** séances déplacées dans une autre salle (travaux)" + ;
       sisinon((sy.sans_salle ou 0) > 0, ", **" + sy.sans_salle + "** sans salle libre", "") + NL
  syncal.valeur = md
  REMPLIR_GRILLE(gannee, BILAN_ANNEE(), {"public", "matiere", "enseignant", "hebdo", "semaines", "prevues", "non_assurees", "annulees"})
retourner
