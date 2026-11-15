&& CC BY-NC-SA 4.0 - jean-marc "jihem" quere 2026
&& Gestion d'établissement : emploi du temps de la semaine type et attribution
&& des salles (solveur wdreka).
&&
&& Grille : jours ouvrables × créneaux ; u = rang du jour × P + rang du créneau.
&& Séances : chaque cours est découpé selon la durée de ses séances (1 ou 2
&& créneaux ; une séance de deux créneaux ne franchit pas le repas).
&&
&& Modèle 1 (créneaux), z[k] : la séance i(k) commence au créneau t(k) ; on ne
&& crée que les débuts admissibles (établissement ouvert ; classe, niveau,
&& matière, enseignant disponibles ; au moins une salle compatible libre) :
&&   chaque séance commence une fois ;
&&   une classe, un enseignant : une séance par créneau ;
&&   options en barrettes : pendant une option, les classes concernées n'ont pas
&&   d'autre cours (oc[j]), plusieurs options peuvent être simultanées si elles
&&   n'ont aucun élève commun ;
&&   salles : pour chaque famille A de salles compatibles et chaque créneau, les
&&   séances qui ne peuvent aller que dans A sont au plus |A| (condition de Hall) ;
&&   au plus max_jour séances d'un même cours par jour ; heures par jour d'une
&&   classe et d'un enseignant plafonnées ; séances épinglées gardées ;
&&   objectif : éviter les fins de journée et la première heure.
&& Modèle 2 (salles), r[k] : la séance i(k) a lieu dans la salle s(k) :
&&   une salle par séance, une séance par salle et par créneau ; objectif : salle
&&   attitrée de la classe, sinon même bâtiment.

&& Somme NCP d'une liste de termes : sum([…]) est évalué en temps linéaire,
&& une longue chaîne « a + b + … » en temps quadratique.
fonction SOMME(t)
retourner "sum([" + joindre(t, ", ") + "])"

&& --- grille ----------------------------------------------------------------
fonction GRILLE()
  locale js = requete("select num, nom from jours where ouvre order by num")
  locale cs = requete("select num, debut, fin, pause from creneaux order by num")
  locale rj = {}
  pour d = 1 a #js
    rj[js[d].num] = d - 1
  suivant
retourner {jours = js, creneaux = cs, nj = #js, np = #cs, rangjour = rj}

&& La plage couvre-t-elle le créneau cr du jour jnum ?
fonction COUVRE(pl, jnum, cr)
  si pl.jour <> nul et pl.jour <> jnum
    retourner faux
  finsi
  si pl.debut <> nul et pl.debut <> "" et pl.debut >= cr.fin
    retourner faux
  finsi
  si pl.fin <> nul et pl.fin <> "" et pl.fin <= cr.debut
    retourner faux
  finsi
retourner vrai

&& Créneaux fermés par les plages hebdomadaires : {portee|cible -> {u -> vrai}}
fonction FERMETURES(g)
  locale f = {}
  pour chaque pl dans requete("select * from plages where du is null and au is null")
    locale cle = pl.portee + "|" + sisinon(pl.portee = "etablissement", "", (pl.cible ou ""))
    si f[cle] = nul
      f[cle] = {}
    finsi
    pour d = 1 a g.nj
      pour p = 1 a g.np
        si COUVRE(pl, g.jours[d].num, g.creneaux[p])
          f[cle][(d - 1) * g.np + (p - 1)] = vrai
        finsi
      suivant
    suivant
  suivant
retourner f

fonction FERME(f, portee, cible, u)
  locale t = f[portee + "|" + (cible ou "")]
retourner t <> nul et t[u] = vrai

&& --- séances à placer ---------------------------------------------------------
&& Renvoie la liste des séances avec tout ce qu'il faut pour les placer.
fonction SEANCES_A_PLACER()
  locale salles = requete("select code, batiment, places, equipements from salles order by code")
  locale effcl = {}
  pour chaque r dans requete("select classe, count(*) n from eleves where classe is not null group by classe")
    effcl[r.classe] = r.n
  suivant
  locale clgr = {}
  pour chaque r dans requete("select groupe, string_agg(distinct e.classe, ',') cls from eleve_groupes x join eleves e on e.id = x.eleve group by groupe")
    clgr[r.groupe] = MOTS_LISTE(r.cls)
  suivant
  locale effgr = {}
  pour chaque r dans requete("select code, effectif from groupes")
    effgr[r.code] = r.effectif
  suivant
  locale besoins = {}
  pour chaque b dans requete("select matiere, equipement, heures from besoins")
    si besoins[b.matiere] = nul
      besoins[b.matiere] = {}
    finsi
    inserer(besoins[b.matiere], b)
  suivant
  locale maxj = {}
  pour chaque r dans requete("select code, max_jour from matieres")
    maxj[r.code] = r.max_jour ou 1
  suivant
  locale epingles = {}
  pour chaque r dans requete("select cours, num, jour, creneau from seances where epingle")
    epingles[r.cours + "|" + r.num] = r
  suivant
  locale profils = {}
  locale lp = {}
  locale res = {}
  pour chaque c dans requete("select * from cours order by id")
    locale eff = sisinon(c.classe <> nul, effcl[c.classe] ou 0, effgr[c.groupe] ou 0)
    locale cls = sisinon(c.classe <> nul, {c.classe}, clgr[c.groupe] ou {})
    locale reste = c.heures
    locale num = 0
    locale fait = 0
    tantque reste > 0
      num += 1
      locale du = min(max(1, c.duree ou 1), reste)
      && équipements demandés par cette séance
      locale eq = {}
      pour chaque b dans besoins[c.matiere] ou {}
        si (b.heures ou 0) = 0 ou fait < b.heures
          inserer(eq, majuscule(b.equipement))
        finsi
      suivant
      && salles compatibles (famille)
      locale ok = {}
      pour chaque s dans salles
        si (s.places ou 0) >= eff
          locale dispo = MOTS_LISTE(s.equipements)
          locale bon = vrai
          pour chaque e dans eq
            si non contient(dispo, e)
              bon = faux
              sortir
            finsi
          suivant
          si bon
            inserer(ok, s.code)
          finsi
        finsi
      suivant
      locale cle = joindre(ok, ",")
      si profils[cle] = nul
        profils[cle] = #lp
        inserer(lp, ok)
      finsi
      locale ep = epingles[c.id + "|" + num]
      inserer(res, {cours = c.id, num = num, duree = du, classe = c.classe, groupe = c.groupe, classes = cls, ;
                    prof = c.enseignant, matiere = c.matiere, niveau = c.niveau, eff = eff, salles = ok, ;
                    profil = profils[cle], equip = joindre(eq, ","), maxjour = maxj[c.matiere] ou 1, ;
                    pin = ep, nbseances = 0})
      fait += du
      reste -= du
    fintantque
  suivant
  && nombre de séances de chaque cours (pour la limite par jour)
  locale nbc = {}
  pour chaque s dans res
    nbc[s.cours] = (nbc[s.cours] ou 0) + 1
  suivant
  pour chaque s dans res
    s.nbseances = nbc[s.cours]
  suivant
retourner {seances = res, profils = lp, salles = salles}

&& --- modèle 1 : créneaux -------------------------------------------------------
fonction MODELE_EDT()
  locale g = GRILLE()
  locale f = FERMETURES(g)
  locale sp = SEANCES_A_PLACER()
  locale se = sp.seances
  locale nt = g.nj * g.np
  locale np = g.np
  locale cmax = PARAMN("classe_max_jour", 8)
  locale pmax = {}
  pour chaque r dans requete("select code, max_jour from enseignants")
    pmax[r.code] = r.max_jour ou np
  suivant
  && salles disponibles par créneau (plages hebdomadaires des salles)
  locale dispo = {}
  pour u = 0 a nt - 1
    locale l = {}
    pour chaque s dans sp.salles
      si non FERME(f, "salle", s.code, u)
        l[s.code] = vrai
      finsi
    suivant
    dispo[u] = l
  suivant
  && capacité de chaque famille de salles à chaque créneau
  locale capa = {}
  pour pi = 1 a #sp.profils
    locale c = {}
    pour u = 0 a nt - 1
      locale n = 0
      pour chaque s dans sp.profils[pi]
        si dispo[u][s]
          n += 1
        finsi
      suivant
      c[u] = n
    suivant
    capa[pi - 1] = c
  suivant
  && débuts admissibles
  locale cand = {}
  locale cout = {}
  locale erreurs = {}
  pour i = 1 a #se
    locale s = se[i]
    s.cov = {}
    s.debuts = {}
    pour d = 0 a g.nj - 1
      pour p = 0 a np - s.duree
        locale ok = vrai
        locale t = d * np + p
        pour q = 0 a s.duree - 1
          locale u = t + q
          si q < s.duree - 1 et g.creneaux[p + q + 1].pause = "repas"
            ok = faux
          sinonsi FERME(f, "etablissement", "", u) ou FERME(f, "niveau", s.niveau, u) ;
              ou FERME(f, "matiere", s.matiere, u) ou FERME(f, "enseignant", s.prof, u) ;
              ou capa[s.profil][u] = 0
            ok = faux
          sinon
            pour chaque cl dans s.classes
              si FERME(f, "classe", cl, u)
                ok = faux
              finsi
            suivant
          finsi
          si non ok
            sortir
          finsi
        suivant
        si ok et s.pin <> nul
          ok = s.pin.jour = g.jours[d + 1].num et s.pin.creneau = p + 1
        finsi
        si ok
          locale k = #cand
          inserer(cand, {i = i, t = t})
          inserer(s.debuts, k)
          pour q = 0 a s.duree - 1
            si s.cov[t + q] = nul
              s.cov[t + q] = {}
            finsi
            inserer(s.cov[t + q], "z[" + k + "]")
          suivant
          && coût : fin de journée, première heure
          locale fin = p + s.duree
          inserer(cout, sisinon(fin = np, 3, sisinon(fin = np - 1, 1, 0)) + sisinon(p = 0, 1, 0))
        finsi
      suivant
    suivant
    si #s.debuts = 0
      inserer(erreurs, "séance impossible à placer : " + s.matiere + " " + (s.classe ou s.groupe) + ;
              " (" + (s.prof ou "à pourvoir") + ", salles : " + sisinon(#s.salles = 0, "aucune compatible", joindre(s.salles, " ")) + ")")
    finsi
  suivant
  si #erreurs > 0
    retourner {erreurs = erreurs}
  finsi
  locale l = {}
  inserer(l, "// emploi du temps : " + #se + " séances, " + #cand + " débuts possibles, " + nt + " créneaux")
  inserer(l, "var z[" + #cand + "] : bool;")
  inserer(l, "// --- une seule fois")
  && une seule fois
  pour chaque s dans se
    locale t = {}
    pour chaque k dans s.debuts
      inserer(t, "z[" + k + "]")
    suivant
    inserer(l, "constraint " + SOMME(t) + " == 1;")
  suivant
  && regroupements par classe, groupe, enseignant
  locale parcl = {}, paropt = {}, parprof = {}, pargr = {}
  pour i = 1 a #se
    locale s = se[i]
    si s.classe <> nul
      si parcl[s.classe] = nul
        parcl[s.classe] = {}
      finsi
      inserer(parcl[s.classe], i)
    sinon
      pour chaque cl dans s.classes
        si paropt[cl] = nul
          paropt[cl] = {}
        finsi
        inserer(paropt[cl], i)
      suivant
      si pargr[s.groupe] = nul
        pargr[s.groupe] = {}
      finsi
      inserer(pargr[s.groupe], i)
    finsi
    si s.prof <> nul
      si parprof[s.prof] = nul
        parprof[s.prof] = {}
      finsi
      inserer(parprof[s.prof], i)
    finsi
  suivant
  && occupation d'un ensemble de séances au créneau u
  locale noc = 0
  locale ocdecl = {}
  locale lcl = {}
  pour chaque cl, liste dans parcl
    pour u = 0 a nt - 1
      locale t = {}
      pour chaque i dans liste
        pour chaque x dans se[i].cov[u] ou {}
          inserer(t, x)
        suivant
      suivant
      locale opt = {}
      pour chaque i dans paropt[cl] ou {}
        pour chaque x dans se[i].cov[u] ou {}
          inserer(opt, x)
        suivant
      suivant
      si #opt > 0
        locale v = "oc[" + noc + "]"
        noc += 1
        pour chaque x dans opt
          inserer(ocdecl, "constraint " + x + " -> " + v + ";")
        suivant
        inserer(t, v)
      finsi
      si #t > 1
        inserer(lcl, "constraint " + SOMME(t) + " <= 1;")
      finsi
    suivant
  suivant
  inserer(l, "// --- classes et barrettes")
  si noc > 0
    inserer(l, "var oc[" + noc + "] : bool;")
    pour chaque x dans ocdecl
      inserer(l, x)
    suivant
  finsi
  pour chaque x dans lcl
    inserer(l, x)
  suivant
  inserer(l, "// --- groupes")
  && groupes d'options : un groupe à la fois ; deux groupes ayant un élève commun jamais ensemble
  locale paires = {}
  pour chaque gr, liste dans pargr
    inserer(paires, {gr, gr})
  suivant
  pour chaque r dans requete([[select a.groupe g1, b.groupe g2 from eleve_groupes a join eleve_groupes b
                               on a.eleve = b.eleve and a.groupe < b.groupe group by all]])
    inserer(paires, {r.g1, r.g2})
  suivant
  pour chaque pr dans paires
    locale ens = {}
    pour chaque i dans pargr[pr[1]] ou {}
      inserer(ens, i)
    suivant
    si pr[1] <> pr[2]
      pour chaque i dans pargr[pr[2]] ou {}
        inserer(ens, i)
      suivant
    finsi
    pour u = 0 a nt - 1
      locale t = {}
      pour chaque i dans ens
        pour chaque x dans se[i].cov[u] ou {}
          inserer(t, x)
        suivant
      suivant
      si #t > 1
        inserer(l, "constraint " + SOMME(t) + " <= 1;")
      finsi
    suivant
  suivant
  inserer(l, "// --- enseignants")
  && enseignants : un créneau à la fois, maximum par jour
  pour chaque pf, liste dans parprof
    pour u = 0 a nt - 1
      locale t = {}
      pour chaque i dans liste
        pour chaque x dans se[i].cov[u] ou {}
          inserer(t, x)
        suivant
      suivant
      si #t > 1
        inserer(l, "constraint " + SOMME(t) + " <= 1;")
      finsi
    suivant
    locale mj = pmax[pf] ou np
    pour d = 0 a g.nj - 1
      locale t = {}
      pour chaque i dans liste
        pour u = d * np a d * np + np - 1
          pour chaque x dans se[i].cov[u] ou {}
            inserer(t, x)
          suivant
        suivant
      suivant
      si #t > mj
        inserer(l, "constraint " + SOMME(t) + " <= " + mj + ";")
      finsi
    suivant
  suivant
  inserer(l, "// --- classes par jour")
  && classes : heures par jour
  pour chaque cl, liste dans parcl
    pour d = 0 a g.nj - 1
      locale t = {}
      pour chaque i dans liste
        pour u = d * np a d * np + np - 1
          pour chaque x dans se[i].cov[u] ou {}
            inserer(t, x)
          suivant
        suivant
      suivant
      si #t > cmax
        inserer(l, "constraint " + SOMME(t) + " <= " + cmax + ";")
      finsi
    suivant
  suivant
  inserer(l, "// --- cours par jour")
  && un même cours : au plus max_jour séances par jour (plus si le cours en compte trop)
  locale parcours = {}
  pour i = 1 a #se
    locale cle = chaine(se[i].cours)
    si parcours[cle] = nul
      parcours[cle] = {}
    finsi
    inserer(parcours[cle], i)
  suivant
  pour chaque cc, liste dans parcours
    && jours où le cours peut avoir lieu (indisponibilités de l'enseignant…)
    locale jo = {}
    locale nj = 0
    pour chaque i dans liste
      pour chaque k dans se[i].debuts
        locale d = plancher(cand[k + 1].t / np)
        si non jo[d]
          jo[d] = vrai
          nj += 1
        finsi
      suivant
    suivant
    locale lim = max(se[liste[1]].maxjour, plafond(#liste / max(1, nj)))
    si #liste > lim
      pour d = 0 a g.nj - 1
        locale t = {}
        pour chaque i dans liste
          pour chaque k dans se[i].debuts
            si plancher(cand[k + 1].t / np) = d
              inserer(t, "z[" + k + "]")
            finsi
          suivant
        suivant
        si #t > lim
          inserer(l, "constraint " + SOMME(t) + " <= " + lim + ";")
        finsi
      suivant
    finsi
  suivant
  && salles : condition de Hall par famille
  locale inclus = {}
  pour a = 1 a #sp.profils
    locale membres = {}
    pour b = 1 a #sp.profils
      locale sous = vrai
      pour chaque s dans sp.profils[b]
        si non contient(sp.profils[a], s)
          sous = faux
          sortir
        finsi
      suivant
      si sous
        inserer(membres, b - 1)
      finsi
    suivant
    inclus[a - 1] = membres
  suivant
  inserer(l, "// --- salles (Hall)")
  pour a = 0 a #sp.profils - 1
    pour u = 0 a nt - 1
      locale t = {}
      pour i = 1 a #se
        si contient(inclus[a], se[i].profil)
          pour chaque x dans se[i].cov[u] ou {}
            inserer(t, x)
          suivant
        finsi
      suivant
      si #t > capa[a][u]
        inserer(l, "constraint " + SOMME(t) + " <= " + capa[a][u] + ";")
      finsi
    suivant
  suivant
  inserer(l, "// --- objectif")
  && objectif
  locale ob = {}
  pour k = 1 a #cand
    si cout[k] > 0
      inserer(ob, sisinon(cout[k] = 1, "", cout[k] + " * ") + "z[" + (k - 1) + "]")
    finsi
  suivant
  si #ob > 0
    inserer(l, "solve minimize " + SOMME(ob) + ";")
  sinon
    inserer(l, "solve satisfy;")
  finsi
retourner {texte = joindre(l, car(10)), seances = se, cand = cand, grille = g, salles = sp.salles, fermetures = f}

&& --- modèle 2 : salles -----------------------------------------------------
fonction MODELE_SALLES(md, placement)
  locale g = md.grille
  locale np = g.np
  locale se = md.seances
  locale attitree = {}
  pour chaque r dans requete("select code, salle from classes")
    attitree[r.code] = r.salle
  suivant
  locale bat = {}
  pour chaque s dans md.salles
    bat[s.code] = s.batiment
  suivant
  locale cand = {}
  locale parsalle = {}
  locale l = {}
  locale ob = {}
  locale erreurs = {}
  pour i = 1 a #se
    locale s = se[i]
    locale t0 = placement[i]
    locale ks = {}
    pour chaque sa dans s.salles
      locale libre = vrai
      pour q = 0 a s.duree - 1
        si FERME(md.fermetures, "salle", sa, t0 + q)
          libre = faux
        finsi
      suivant
      si libre
        locale k = #cand
        inserer(cand, {i = i, salle = sa})
        inserer(ks, "r[" + k + "]")
        pour q = 0 a s.duree - 1
          locale cle = sa + "|" + (t0 + q)
          si parsalle[cle] = nul
            parsalle[cle] = {}
          finsi
          inserer(parsalle[cle], "r[" + k + "]")
        suivant
        && coût : salle attitrée 0, même bâtiment 1, ailleurs 2 (groupes : 1)
        locale att = sisinon(s.classe <> nul, attitree[s.classe], nul)
        locale c = sisinon(att = nul, 1, sisinon(att = sa, 0, sisinon(bat[att] = bat[sa], 1, 2)))
        si c > 0
          inserer(ob, sisinon(c = 1, "", c + " * ") + "r[" + k + "]")
        finsi
      finsi
    suivant
    si #ks = 0
      inserer(erreurs, "aucune salle libre pour " + s.matiere + " " + (s.classe ou s.groupe))
    finsi
    inserer(l, "constraint " + SOMME(ks) + " == 1;")
  suivant
  pour chaque cle, t dans parsalle
    si #t > 1
      inserer(l, "constraint " + SOMME(t) + " <= 1;")
    finsi
  suivant
  locale tete = {"// salles : " + #se + " séances, " + #cand + " possibilités", "var r[" + #cand + "] : bool;"}
  pour chaque x dans l
    inserer(tete, x)
  suivant
  inserer(tete, sisinon(#ob > 0, "solve minimize " + SOMME(ob) + ";", "solve satisfy;"))
retourner {texte = joindre(tete, car(10)), cand = cand, erreurs = erreurs}

&& --- génération complète ---------------------------------------------------
&& Renvoie {statut, message} ; suivi(m, etape) reçoit chaque modèle wdreka.
fonction GENERER_EDT(suivi)
  locale delai = PARAMN("delai", 30)
  locale t0 = systeme.horloge()
  locale md = MODELE_EDT()
  si md.erreurs <> nul
    retourner {statut = "erreur", message = joindre(md.erreurs, car(10))}
  finsi
  locale m = wdreka.modele(md.texte)
  si suivi <> nul
    appeler(suivi, m, "créneaux")
  finsi
  locale r = m:resoudre({delai = delai})
  si r.solutions = 0
    retourner {statut = r.statut, message = "emploi du temps : " + sisinon(r.statut = "infaisable", ;
               "impossible avec ces contraintes (indisponibilités, salles, limites par jour)", ;
               "aucune solution dans le délai (" + delai + " s) : augmentez-le")}
  finsi
  locale placement = {}
  pour chaque k dans m:vrais("z")
    placement[md.cand[k + 1].i] = md.cand[k + 1].t
  suivant
  locale rapport1 = "créneaux : " + r.statut + " en " + arrondi(r.duree, 1) + " s (coût " + (r.objectif ou 0) + ")"
  && salles
  locale ms = MODELE_SALLES(md, placement)
  si #ms.erreurs > 0
    retourner {statut = "erreur", message = joindre(ms.erreurs, car(10))}
  finsi
  locale m2 = wdreka.modele(ms.texte)
  si suivi <> nul
    appeler(suivi, m2, "salles")
  finsi
  locale r2 = m2:resoudre({delai = max(5, delai / 2)})
  si r2.solutions = 0
    retourner {statut = r2.statut, message = rapport1 + car(10) + "salles : aucune attribution (" + r2.statut + ")"}
  finsi
  locale salle = {}
  pour chaque k dans m2:vrais("r")
    salle[ms.cand[k + 1].i] = ms.cand[k + 1].salle
  suivant
  && enregistrement
  locale g = md.grille
  sql "delete from seances"
  pour i = 1 a #md.seances
    locale s = md.seances[i]
    locale t = placement[i]
    sql "insert into seances values (?, ?, ?, ?, ?, ?, ?, ?)" avec i, s.cours, s.num, s.duree, ;
        g.jours[plancher(t / g.np) + 1].num, mod(t, g.np) + 1, salle[i], s.pin <> nul
  suivant
retourner {statut = r.statut, message = rapport1 + car(10) + "salles : " + r2.statut + " en " + arrondi(r2.duree, 1) + ;
           " s (coût " + (r2.objectif ou 0) + ")" + car(10) + #md.seances + " séances placées en " + ;
           arrondi(systeme.horloge() - t0, 1) + " s"}

&& Salle compatible (places, équipements) libre dans la semaine type pour la
&& séance id déplacée au jour jnum, créneaux cr .. cr + duree - 1.
fonction SALLE_LIBRE_SEMAINE(id, jnum, cr, duree)
  locale s = requete([[select c.matiere, c.classe, coalesce((select count(*) from eleves e where e.classe = c.classe),
      (select effectif from groupes g where g.code = c.groupe)) eff from seances s join cours c on c.id = s.cours where s.id = ?]], id)[1]
  locale eq = {}
  pour chaque b dans requete("select equipement from besoins where matiere = ? and heures = 0", s.matiere)
    inserer(eq, majuscule(b.equipement))
  suivant
  locale g = GRILLE()
  locale f = FERMETURES(g)
  locale d = g.rangjour[jnum]
  locale att = valeursql("select salle from classes where code = ?", s.classe)
  pour chaque sa dans requete([[select code, equipements from salles where places >= ?
      and not exists (select 1 from seances s2 where s2.id <> ? and s2.salle = salles.code and s2.jour = ?
                      and s2.creneau <= ? and s2.creneau + s2.duree - 1 >= ?)
      order by (code = ?) desc, batiment, places]], s.eff ou 0, id, jnum, cr + duree - 1, cr, att ou "")
    locale bon = vrai
    locale dispo = MOTS_LISTE(sa.equipements)
    pour chaque e dans eq
      si non contient(dispo, e)
        bon = faux
      finsi
    suivant
    pour q = cr a cr + duree - 1
      si FERME(f, "salle", sa.code, d * g.np + q - 1)
        bon = faux
      finsi
    suivant
    si bon
      retourner sa.code
    finsi
  suivant
retourner nul

&& --- contrôle ------------------------------------------------------------------
&& Vérification indépendante de l'emploi du temps (requêtes SQL) : renvoie la
&& liste des anomalies (vide si tout va bien).
fonction VERIFIER_EDT()
  locale pb = {}
  sql [[create or replace temp view occ as
    select s.id, s.cours, s.jour, s.creneau + k.i creneau, s.salle, c.classe, c.groupe, c.enseignant, c.matiere
    from seances s join cours c on c.id = s.cours, range(0, 4) k(i) where k.i < s.duree]]
  pour chaque r dans requete("select classe, jour, creneau, count(*) n from occ where classe is not null group by all having count(*) > 1")
    inserer(pb, "classe " + r.classe + " : " + r.n + " séances au créneau " + r.jour + "/" + r.creneau)
  suivant
  pour chaque r dans requete("select enseignant, jour, creneau, count(*) n from occ where enseignant is not null group by all having count(*) > 1")
    inserer(pb, "enseignant " + r.enseignant + " : " + r.n + " séances au créneau " + r.jour + "/" + r.creneau)
  suivant
  pour chaque r dans requete("select salle, jour, creneau, count(*) n from occ group by all having count(*) > 1")
    inserer(pb, "salle " + r.salle + " : " + r.n + " séances au créneau " + r.jour + "/" + r.creneau)
  suivant
  && option et cours de la classe d'un de ses élèves en même temps
  pour chaque r dans requete([[select distinct g.groupe, e.classe, o.jour, o.creneau from occ o
      join eleve_groupes g on g.groupe = o.groupe join eleves e on e.id = g.eleve
      join occ o2 on o2.classe = e.classe and o2.jour = o.jour and o2.creneau = o.creneau]])
    inserer(pb, "groupe " + r.groupe + " en même temps qu'un cours de " + r.classe + " (" + r.jour + "/" + r.creneau + ")")
  suivant
  && salle trop petite ou sans l'équipement
  pour chaque r dans requete([[select s.id, s.salle, sa.places, c.matiere,
      coalesce((select count(*) from eleves e where e.classe = c.classe), (select effectif from groupes g where g.code = c.groupe)) eff
      from seances s join cours c on c.id = s.cours join salles sa on sa.code = s.salle]])
    si r.places < r.eff
      inserer(pb, "salle " + r.salle + " trop petite (" + r.places + " places pour " + r.eff + ")")
    finsi
  suivant
  pour chaque r dans requete([[select s.salle, b.equipement, c.matiere from seances s join cours c on c.id = s.cours
      join besoins b on b.matiere = c.matiere and b.heures = 0 join salles sa on sa.code = s.salle
      where not contains(',' || upper(replace(sa.equipements, ' ', '')) || ',', ',' || upper(b.equipement) || ',')]])
    inserer(pb, r.matiere + " en salle " + r.salle + " sans " + r.equipement)
  suivant
  && plages hebdomadaires des salles (préparation, indisponibilité)
  pour chaque r dans requete([[select o.id, o.salle, o.jour, o.creneau from occ o join creneaux cr on cr.num = o.creneau
      join plages p on p.du is null and p.portee = 'salle' and p.cible = o.salle and (p.jour is null or p.jour = o.jour)
      and (coalesce(p.debut, '') = '' or p.debut < cr.fin) and (coalesce(p.fin, '') = '' or p.fin > cr.debut)]])
    inserer(pb, "salle " + r.salle + " indisponible (" + r.jour + "/" + r.creneau + ")")
  suivant
  && plages hebdomadaires de l'établissement
  pour chaque r dans requete([[select o.id, o.jour, o.creneau from occ o join creneaux cr on cr.num = o.creneau
      join plages p on p.du is null and p.portee = 'etablissement' and (p.jour is null or p.jour = o.jour)
      and (p.debut is null or p.debut < cr.fin) and (p.fin is null or p.fin > cr.debut)]])
    inserer(pb, "séance " + r.id + " sur un créneau fermé (" + r.jour + "/" + r.creneau + ")")
  suivant
  && indisponibilités des enseignants
  pour chaque r dans requete([[select o.id, o.enseignant, o.jour, o.creneau from occ o join creneaux cr on cr.num = o.creneau
      join plages p on p.du is null and p.portee = 'enseignant' and p.cible = o.enseignant and (p.jour is null or p.jour = o.jour)
      and (p.debut is null or p.debut < cr.fin) and (p.fin is null or p.fin > cr.debut)]])
    inserer(pb, "enseignant " + r.enseignant + " indisponible (" + r.jour + "/" + r.creneau + ")")
  suivant
retourner pb
