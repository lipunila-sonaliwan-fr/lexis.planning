&& CC BY-NC-SA 4.0 - jean-marc "jihem" quere 2026
&& Gestion d'établissement : répartition des élèves d'un niveau dans ses classes
&& (solveur wdreka), puis constitution des groupes d'options.
&&
&& Modèle NCP, par niveau (E élèves, K classes) :
&&   x[e, k]   l'élève e est dans la classe k (une seule classe par élève) ;
&&   effectifs équilibrés (écart d'au plus un élève), sous l'effectif maximal ;
&&   filles, élèves « forts » et « faibles » répartis à la tolérance près ;
&&   élèves à séparer (« évite ») jamais ensemble : contrainte stricte ;
&&   élèves à réunir (« aime ») : s[p] vrai si la paire est réunie, maximisé ;
&&   options « regrouper » : y[o, k] vrai si la classe k accueille l'option o,
&&   minimisé (moins de classes à aligner dans l'emploi du temps) ; options
&&   « repartir » : équilibrées comme les filles ;
&&   élèves « fixe » : gardent leur classe.

&& Construit le texte du modèle d'un niveau ; renvoie {texte, eleves, classes}
&& ou nul s'il n'y a rien à répartir.
fonction MODELE_REPARTITION(niv)
  locale els = requete("select id, sexe, profil, classe, fixe from eleves where niveau = ? order by id", niv)
  locale cls = requete("select code, effectif_max from classes where niveau = ? order by code", niv)
  locale ne = #els
  locale nk = #cls
  si ne = 0 ou nk = 0
    retourner nul
  finsi
  locale tol = PARAMN("tolerance", 1)
  locale rang = {}
  pour i = 1 a ne
    rang[els[i].id] = i - 1
  suivant
  locale rangk = {}
  pour k = 1 a nk
    rangk[cls[k].code] = k - 1
  suivant
  locale fil = {}, frt = {}, fai = {}
  locale nf = 0, nfort = 0, nfaible = 0
  pour chaque e dans els
    inserer(fil, sisinon(e.sexe = "F", "1", "0"))
    inserer(frt, sisinon(e.profil = "fort", "1", "0"))
    inserer(fai, sisinon(e.profil = "faible", "1", "0"))
    nf += sisinon(e.sexe = "F", 1, 0)
    nfort += sisinon(e.profil = "fort", 1, 0)
    nfaible += sisinon(e.profil = "faible", 1, 0)
  suivant
  locale l = {}
  inserer(l, "// répartition du niveau " + niv + " : " + ne + " élèves, " + nk + " classes")
  inserer(l, "const E = " + ne + ";")
  inserer(l, "const K = " + nk + ";")
  inserer(l, "const FILLE = [" + joindre(fil, ", ") + "];")
  inserer(l, "const FORT = [" + joindre(frt, ", ") + "];")
  inserer(l, "const FAIBLE = [" + joindre(fai, ", ") + "];")
  inserer(l, "var x[E, K] : bool;")
  inserer(l, "forall e in 0..E-1 { constraint sum([ite(x[e, k], 1, 0) | k in 0..K-1]) == 1; }")
  && effectifs
  locale lo = plancher(ne / nk)
  locale hi = plafond(ne / nk)
  pour k = 1 a nk
    locale mx = cls[k].effectif_max ou hi
    inserer(l, "constraint sum([ite(x[e, " + (k - 1) + "], 1, 0) | e in 0..E-1]) >= " + min(lo, mx) + ";")
    inserer(l, "constraint sum([ite(x[e, " + (k - 1) + "], 1, 0) | e in 0..E-1]) <= " + min(hi, mx) + ";")
  suivant
  && mixité et profils
  pour chaque cr dans {{"FILLE", nf}, {"FORT", nfort}, {"FAIBLE", nfaible}}
    locale a = max(0, plancher(cr[2] / nk) - tol)
    locale b = plafond(cr[2] / nk) + tol
    inserer(l, "forall k in 0..K-1 { constraint sum([ite(x[e, k], 1, 0) | e in 0..E-1 where " + cr[1] + "[e] == 1]) >= " + a + ";")
    inserer(l, "  constraint sum([ite(x[e, k], 1, 0) | e in 0..E-1 where " + cr[1] + "[e] == 1]) <= " + b + "; }")
  suivant
  && élèves fixés
  pour chaque e dans els
    si e.fixe et e.classe <> nul et rangk[e.classe] <> nul
      inserer(l, "constraint x[" + rang[e.id] + ", " + rangk[e.classe] + "];")
    finsi
  suivant
  && affinités
  locale aimes = {}
  pour chaque a dans requete("select eleve, autre, genre from affinites")
    locale ra = rang[a.eleve]
    locale rb = rang[a.autre]
    si ra <> nul et rb <> nul et ra <> rb
      si a.genre = "evite"
        inserer(l, "forall k in 0..K-1 { constraint not (x[" + ra + ", k] and x[" + rb + ", k]); }")
      sinon
        inserer(aimes, {ra, rb})
      finsi
    finsi
  suivant
  locale obj = {}
  si #aimes > 0
    inserer(l, "var s[" + #aimes + "] : bool;")
    pour p = 1 a #aimes
      inserer(l, "forall k in 0..K-1 { constraint s[" + (p - 1) + "] -> (x[" + aimes[p][1] + ", k] <-> x[" + aimes[p][2] + ", k]); }")
    suivant
    inserer(obj, "10 * (" + #aimes + " - sum([ite(s[p], 1, 0) | p in 0.." + (#aimes - 1) + "]))")
  finsi
  && options
  locale opts = requete("select code, repartition from options where niveau = ? order by code", niv)
  locale no = 0
  pour chaque o dans opts
    locale membres = {}
    pour chaque r dans requete("select eleve from eleve_options where opt = ? order by eleve", o.code)
      si rang[r.eleve] <> nul
        inserer(membres, chaine(rang[r.eleve]))
      finsi
    suivant
    si #membres = 0
      boucler
    finsi
    faire cas
    cas o.repartition = "regrouper"
      inserer(l, "// option " + o.code + " : à regrouper")
      inserer(l, "var y" + no + "[K] : bool;")
      inserer(l, "const M" + no + " = [" + joindre(membres, ", ") + "];")
      inserer(l, "forall i in 0..length(M" + no + ") - 1 { forall k in 0..K-1 { constraint x[M" + no + "[i], k] -> y" + no + "[k]; } }")
      inserer(obj, "3 * sum([ite(y" + no + "[k], 1, 0) | k in 0..K-1])")
      no += 1
    cas o.repartition = "repartir"
      inserer(l, "// option " + o.code + " : à répartir")
      locale n = #membres
      inserer(l, "const R" + no + " = [" + joindre(membres, ", ") + "];")
      inserer(l, "forall k in 0..K-1 { constraint sum([ite(x[R" + no + "[i], k], 1, 0) | i in 0..length(R" + no + ") - 1]) >= " + max(0, plancher(n / nk) - tol) + ";")
      inserer(l, "  constraint sum([ite(x[R" + no + "[i], k], 1, 0) | i in 0..length(R" + no + ") - 1]) <= " + (plafond(n / nk) + tol) + "; }")
      no += 1
    fincas
  suivant
  si #obj > 0
    inserer(l, "solve minimize " + joindre(obj, " + ") + ";")
  sinon
    inserer(l, "solve satisfy;")
  finsi
retourner {texte = joindre(l, car(10)), eleves = els, classes = cls, aimes = #aimes}

&& Répartit un niveau ; renvoie un compte rendu {statut, message}.
&& suivi : procédure de progression facultative (reçoit le modèle wdreka).
fonction REPARTIR_NIVEAU(niv, suivi)
  locale md = MODELE_REPARTITION(niv)
  si md = nul
    retourner {statut = "vide", message = niv + " : aucun élève ou aucune classe"}
  finsi
  locale m = wdreka.modele(md.texte)
  si suivi <> nul
    appeler(suivi, m)
  finsi
  locale r = m:resoudre({delai = PARAMN("delai", 30)})
  si r.solutions = 0
    retourner {statut = r.statut, message = niv + " : " + sisinon(r.statut = "infaisable", ;
               "répartition impossible (effectifs maximaux, tolérance ou élèves à séparer trop contraignants)", ;
               "aucune répartition trouvée dans le délai")}
  finsi
  locale els = md.eleves
  locale cls = md.classes
  pour chaque co dans m:vrais("x")
    sql "update eleves set classe = ? where id = ?" avec cls[co[2] + 1].code, els[co[1] + 1].id
  suivant
  locale reunis = 0
  si md.aimes > 0
    pour chaque v dans m:valeur("s")
      reunis += sisinon(v, 1, 0)
    suivant
  finsi
retourner {statut = r.statut, message = niv + " : " + #els + " élèves répartis (" + r.statut + ", " + ;
           arrondi(r.duree, 1) + " s) ; paires à réunir satisfaites : " + reunis + " / " + md.aimes}

&& Groupes d'options : effectif au plus groupe_max ; les élèves d'une même
&& classe restent ensemble autant que possible (moins de classes par groupe).
procedure CONSTITUER_GROUPES
  sql "delete from groupes"
  sql "delete from eleve_groupes"
  pour chaque o dans requete("select code, groupe_max from options order by code")
    locale membres = requete("select e.id, e.classe from eleve_options x join eleves e on e.id = x.eleve where x.opt = ? order by e.classe, e.id", o.code)
    locale n = #membres
    si n = 0
      boucler
    finsi
    locale gmax = max(1, o.groupe_max ou n)
    locale ng = plafond(n / gmax)
    locale debut = 1
    pour g = 1 a ng
      locale part = plancher(n / ng) + sisinon(g <= mod(n, ng), 1, 0)
      locale cg = o.code + sisinon(ng > 1, "-" + g, "")
      sql "insert into groupes values (?, ?, ?, ?)" avec cg, o.code, g, part
      pour i = debut a debut + part - 1
        sql "insert into eleve_groupes values (?, ?)" avec membres[i].id, cg
      suivant
      debut += part
    suivant
  suivant
retourner

&& Bilan de la répartition : une ligne par classe.
fonction BILAN_CLASSES()
retourner requete([[select c.code classe, c.niveau, count(e.id) effectif,
    count(*) filter (where e.sexe = 'F') filles, count(*) filter (where e.sexe = 'G') garcons,
    count(*) filter (where e.profil = 'fort') forts, count(*) filter (where e.profil = 'moyen') moyens,
    count(*) filter (where e.profil = 'faible') faibles
  from classes c left join eleves e on e.classe = c.code
  group by c.code, c.niveau order by c.niveau, c.code]])
