&& CC BY-NC-SA 4.0 - jean-marc "jihem" quere 2026
&& Gestion d'établissement : cours à assurer et affectation des services
&& des enseignants (solveur wdreka).
&&
&& Cours : une matière du programme dans une classe (heures du niveau, ou de la
&& dérogation de la classe), ou un groupe d'option.
&& Modèle NCP (C cours, T enseignants + un poste « à pourvoir ») :
&&   y[c, t]   le cours c est confié à l'enseignant t (un seul par cours) ;
&&   seulement les enseignants compétents pour la matière et le niveau ;
&&   service : heures confiées + missions <= service de l'enseignant ;
&&   un même enseignant fait au plus max_classe heures dans une classe ;
&&   objectif : heures à pourvoir (100), sous-service sous le minimum (10),
&&   puis nombre de préparations (matière × niveau) de chaque enseignant (1).

&& Reconstruit la table des cours à partir du programme et des groupes.
procedure CONSTRUIRE_COURS
  sql "delete from cours"
  sql "delete from seances"
  sql [[insert into cours
    select row_number() over (order by c.niveau, c.code, p.matiere), c.code, NULL, p.matiere, c.niveau,
           coalesce(pc.heures, p.heures), p.duree, NULL
    from classes c join programme p on p.niveau = c.niveau
    left join programme_classe pc on pc.classe = c.code and pc.matiere = p.matiere
    where coalesce(pc.heures, p.heures) > 0]]
  && matières ajoutées à une seule classe (absentes du programme du niveau)
  sql [[insert into cours
    select (select coalesce(max(id), 0) from cours) + row_number() over (order by pc.classe, pc.matiere),
           pc.classe, NULL, pc.matiere, c.niveau, pc.heures, 1, NULL
    from programme_classe pc join classes c on c.code = pc.classe
    where pc.heures > 0 and not exists (select 1 from programme p where p.niveau = c.niveau and p.matiere = pc.matiere)]]
  sql [[insert into cours
    select (select coalesce(max(id), 0) from cours) + row_number() over (order by g.code), NULL, g.code,
           o.matiere, o.niveau, o.heures, o.duree, NULL
    from groupes g join options o on o.code = g.opt]]
retourner

fonction COMPETENT(niveaux, niv)
  si niveaux = nul ou rogner(niveaux) = "" ou rogner(niveaux) = "*"
    retourner vrai
  finsi
retourner contient(MOTS_LISTE(minuscule(niveaux)), majuscule(niv))

&& Construit le modèle ; renvoie {texte, cours, profs}.
&& kmax >= 0 : au plus kmax heures à pourvoir (l'objectif ne garde que les
&& sous-services et les préparations) ; glouton : ordre de recherche imposé.
fonction MODELE_SERVICES(kmax, glouton)
  locale crs = requete("select id, classe, groupe, matiere, niveau, heures from cours order by id")
  locale prf = requete("select code, service, service_min, max_classe from enseignants order by code")
  locale comp = requete("select enseignant, matiere, niveaux from competences")
  locale miss = {}
  pour chaque r dans requete("select enseignant, sum(heures) h from missions group by enseignant")
    miss[r.enseignant] = r.h
  suivant
  locale nc = #crs
  locale nt = #prf
  locale maxc = PARAMN("max_classe", 99)
  locale l = {}
  inserer(l, "// affectation des services : " + nc + " cours, " + nt + " enseignants")
  inserer(l, "const C = " + nc + ";")
  inserer(l, "const T = " + (nt + 1) + ";       // dernier : poste à pourvoir")
  locale hs = {}
  pour chaque c dans crs
    inserer(hs, chaine(c.heures))
  suivant
  inserer(l, "const H = [" + joindre(hs, ", ") + "];")
  inserer(l, "var y[C, T] : bool;")
  inserer(l, "forall c in 0..C-1 { constraint sum([ite(y[c, t], 1, 0) | t in 0..T-1]) == 1; }")
  && compétences
  locale rangt = {}
  pour t = 1 a nt
    rangt[prf[t].code] = t - 1
  suivant
  locale cand = {}
  pour ci = 1 a nc
    locale c = crs[ci]
    locale ok = {}
    pour chaque k dans comp
      si k.matiere = c.matiere et COMPETENT(k.niveaux, c.niveau) et rangt[k.enseignant] <> nul
        ok[rangt[k.enseignant]] = vrai
      finsi
    suivant
    pour t = 0 a nt - 1
      si non ok[t]
        inserer(l, "constraint not y[" + (ci - 1) + ", " + t + "];")
      finsi
    suivant
    cand[ci] = ok
  suivant
  && services
  locale sous = {}
  pour t = 1 a nt
    locale p = prf[t]
    locale charge = "sum([H[c] * ite(y[c, " + (t - 1) + "], 1, 0) | c in 0..C-1])"
    locale mi = miss[p.code] ou 0
    inserer(l, "constraint " + charge + " + " + mi + " <= " + (p.service ou 18) + ";")
    si (p.service_min ou 0) > 0
      inserer(l, "var d" + (t - 1) + " : 0.." + p.service_min + ";")
      inserer(l, "constraint d" + (t - 1) + " >= " + (p.service_min - mi) + " - " + charge + ";")
      inserer(sous, "d" + (t - 1))
    finsi
  suivant
  && limite d'heures d'un même enseignant dans une classe
  locale parclasse = {}
  pour ci = 1 a nc
    si crs[ci].classe <> nul
      si parclasse[crs[ci].classe] = nul
        parclasse[crs[ci].classe] = {}
      finsi
      inserer(parclasse[crs[ci].classe], ci - 1)
    finsi
  suivant
  pour chaque cl, liste dans parclasse
    pour t = 1 a nt
      locale lim = prf[t].max_classe ou maxc
      locale termes = {}
      locale tot = 0
      pour chaque ci dans liste
        si cand[ci + 1][t - 1]
          inserer(termes, crs[ci + 1].heures + " * ite(y[" + ci + ", " + (t - 1) + "], 1, 0)")
          tot += crs[ci + 1].heures
        finsi
      suivant
      si tot > lim
        inserer(l, "constraint " + joindre(termes, " + ") + " <= " + lim + ";   // " + cl + " / " + prf[t].code)
      finsi
    suivant
  suivant
  && préparations : z[t, m×n] vrai si l'enseignant t a la matière m au niveau n
  locale prep = {}
  locale np = 0
  pour ci = 1 a nc
    locale cle = crs[ci].matiere + "|" + crs[ci].niveau
    si prep[cle] = nul
      prep[cle] = np
      np += 1
    finsi
  suivant
  inserer(l, "var z[" + (nt + 1) + ", " + np + "] : bool;")
  pour ci = 1 a nc
    pour chaque t, v dans cand[ci]
      inserer(l, "constraint y[" + (ci - 1) + ", " + t + "] -> z[" + t + ", " + prep[crs[ci].matiere + "|" + crs[ci].niveau] + "];")
    suivant
  suivant
  locale apourvoir = "sum([H[c] * ite(y[c, " + nt + "], 1, 0) | c in 0..C-1])"
  locale obj = ""
  si kmax >= 0
    inserer(l, "constraint " + apourvoir + " <= " + kmax + ";")
  sinon
    obj = "100 * " + apourvoir + " + "
  finsi
  si #sous > 0
    obj = obj + "10 * (" + joindre(sous, " + ") + ") + "
  finsi
  obj = obj + "sum([ite(z[t, p], 1, 0) | t in 0.." + (nt - 1) + ", p in 0.." + (np - 1) + "])"
  si non glouton
    inserer(l, "solve minimize " + obj + ";")
    retourner {texte = joindre(l, car(10)), cours = crs, profs = prf}
  finsi
  && recherche « premier qui convient, par ordre décroissant » : les cours les
  && plus contraints (peu d'enseignants possibles) puis les plus longs d'abord ;
  && pour chacun, les spécialistes (peu de matières) d'abord, le poste à
  && pourvoir en dernier. La première affectation est ainsi déjà bonne.
  locale nbmat = {}
  pour chaque k dans comp
    nbmat[k.enseignant] = (nbmat[k.enseignant] ou 0) + 1
  suivant
  locale ordre = {}
  pour ci = 1 a nc
    locale n = 0
    pour chaque t, v dans cand[ci]
      n += 1
    suivant
    inserer(ordre, {ci = ci - 1, n = n, h = crs[ci].heures})
  suivant
  trier(ordre, @COURS_D_ABORD)
  locale rangp = {}
  pour t = 1 a nt
    inserer(rangp, {t = t - 1, m = nbmat[prf[t].code] ou 9, s = prf[t].service ou 0})
  suivant
  trier(rangp, @PROF_D_ABORD)
  locale sv = {}
  pour chaque o dans ordre
    pour chaque p dans rangp
      si cand[o.ci + 1][p.t]
        inserer(sv, "y[" + o.ci + ", " + p.t + "]")
      finsi
    suivant
    inserer(sv, "y[" + o.ci + ", " + nt + "]")
  suivant
  inserer(l, "search [" + joindre(sv, ", ") + "] : input_order, max;")
  inserer(l, "solve minimize " + obj + ";")
retourner {texte = joindre(l, car(10)), cours = crs, profs = prf}

fonction COURS_D_ABORD(a, b)
  si a.n <> b.n
    retourner a.n < b.n
  finsi
retourner a.h > b.h

fonction PROF_D_ABORD(a, b)
  si a.m <> b.m
    retourner a.m < b.m
  finsi
retourner a.s > b.s

&& Affecte les services ; renvoie {statut, message}.
fonction AFFECTER_SERVICES(suivi)
  && 1) toutes les heures couvertes : le solveur trouve vite si c'est possible,
  &&    puis améliore sous-services et préparations ;
  && 2) sinon, meilleure couverture possible, recherche gloutonne.
  locale delai = PARAMN("delai", 30)
  locale md = MODELE_SERVICES(0, faux)
  si #md.cours = 0
    retourner {statut = "vide", message = "aucun cours : répartissez d'abord les élèves (programme, classes, groupes)"}
  finsi
  locale m = wdreka.modele(md.texte)
  si suivi <> nul
    appeler(suivi, m)
  finsi
  locale r = m:resoudre({delai = delai * 0.6})
  si r.solutions = 0
    md = MODELE_SERVICES(-1, vrai)
    m = wdreka.modele(md.texte)
    si suivi <> nul
      appeler(suivi, m)
    finsi
    r = m:resoudre({delai = delai * 0.4})
  finsi
  si r.solutions = 0
    retourner {statut = r.statut, message = "services : aucune affectation (" + r.statut + ")"}
  finsi
  locale nt = #md.profs
  locale apourvoir = 0
  pour chaque co dans m:vrais("y")
    locale c = md.cours[co[1] + 1]
    si co[2] < nt
      sql "update cours set enseignant = ? where id = ?" avec md.profs[co[2] + 1].code, c.id
    sinon
      sql "update cours set enseignant = NULL where id = ?" avec c.id
      apourvoir += c.heures
    finsi
  suivant
retourner {statut = r.statut, message = "services affectés (" + r.statut + ", " + arrondi(r.duree, 1) + " s) ; " + ;
           sisinon(apourvoir = 0, "toutes les heures sont couvertes", apourvoir + " heure(s) à pourvoir")}

&& Charge de chaque enseignant.
fonction BILAN_SERVICES()
retourner requete([[select e.code, e.nom, e.service, e.service_min,
    coalesce(sum(c.heures), 0) heures, coalesce((select sum(m.heures) from missions m where m.enseignant = e.code), 0) missions,
    count(distinct c.classe) classes, count(distinct c.matiere || c.niveau) preparations
  from enseignants e left join cours c on c.enseignant = e.code
  group by e.code, e.nom, e.service, e.service_min order by e.code]])
