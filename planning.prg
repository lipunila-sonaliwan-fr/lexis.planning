&& CC BY-NC-SA 4.0 - jean-marc "jihem" quere 2026
&& Gestion d'établissement : dessin des plannings (classe, enseignant, salle),
&& en SVG pour la toile : semaine type, ou semaine datée (après projection sur
&& le calendrier) avec annulations, absences et changements de salle.
&& Chaque séance est un groupe « s:<id> » : un clic la sélectionne.

fonction ECHAPPER(s)
  s = remplacertexte(chaine(s ou ""), "&", "&amp;")
  s = remplacertexte(s, "<", "&lt;")
retourner remplacertexte(s, ">", "&gt;")

fonction COUPER(s, n)
  s = chaine(s ou "")
  si longueur(s) <= n
    retourner s
  finsi
retourner gauche(s, max(1, n - 1)) + "…"

&& Séances à afficher : liste de {id, jour, creneau, duree, matiere, couleur,
&& public, enseignant, salle, epingle, statut, motif, salle_remplacement}
fonction SEANCES_PLANNING(genre, cible, lundi)
  locale filtre = ""
  faire cas
  cas genre = "classe"
    filtre = "(c.classe = ? or c.groupe in (select g.groupe from eleve_groupes g join eleves e on e.id = g.eleve where e.classe = ?))"
  cas genre = "enseignant"
    filtre = "(c.enseignant = ? or ? is null)"
  autrement
    filtre = "(s.salle = ? or ? is null)"
  fincas
  si lundi = nul
    retourner requete([[select s.id, s.jour, s.creneau, s.duree, c.matiere, m.couleur, coalesce(c.classe, c.groupe) public,
        coalesce(p.nom, 'à pourvoir') enseignant, s.salle, s.epingle, 'prevue' statut, '' motif, NULL salle_remplacement
      from seances s join cours c on c.id = s.cours left join matieres m on m.code = c.matiere
      left join enseignants p on p.code = c.enseignant where ]] + filtre + " order by s.jour, s.creneau", cible, cible)
  finsi
  si genre = "salle"
    filtre = "(s.salle = ? or o.salle_remplacement = ?)"
  finsi
retourner requete([[select s.id, s.jour, s.creneau, s.duree, c.matiere, m.couleur, coalesce(c.classe, c.groupe) public,
      coalesce(p.nom, 'à pourvoir') enseignant, s.salle, s.epingle, o.statut, o.motif, o.salle_remplacement, o.jour_date
    from occurrences o join seances s on s.id = o.seance join cours c on c.id = s.cours
    left join matieres m on m.code = c.matiere left join enseignants p on p.code = c.enseignant
    where o.jour_date between ?::date and ?::date + 6 and ]] + filtre + " order by s.jour, s.creneau", lundi, lundi, cible, cible)

&& Plages hebdomadaires qui ferment des créneaux pour cette vue.
fonction FERMES_PLANNING(genre, cible, g)
  locale f = FERMETURES(g)
  locale res = {}
  pour d = 0 a g.nj - 1
    pour p = 0 a g.np - 1
      locale u = d * g.np + p
      si FERME(f, "etablissement", "", u) ou FERME(f, genre, cible, u)
        res[u] = vrai
      finsi
    suivant
  suivant
retourner res

&& Construit le SVG ; renvoie {svg, largeur, hauteur, seances (id -> séance)}.
fonction PLANNING_SVG(genre, cible, lundi)
  locale g = GRILLE()
  locale sl = SEANCES_PLANNING(genre, cible, lundi)
  locale fermes = FERMES_PLANNING(genre, cible, g)
  locale larg = 1040
  locale gx = 70
  locale gy = 46
  locale cw = (larg - gx - 10) / max(1, g.nj)
  locale rh = 58
  && ordonnée de chaque créneau (les pauses laissent un espace)
  locale ys = {}
  locale y = gy
  pour p = 1 a g.np
    ys[p] = y
    y += rh + sisinon(g.creneaux[p].pause = "repas", 24, sisinon(g.creneaux[p].pause = "recreation", 8, 0))
  suivant
  locale haut = y + 12
  locale l = {}
  inserer(l, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"" + larg + "\" height=\"" + haut + "\" viewBox=\"0 0 " + larg + " " + haut + "\">")
  inserer(l, "<rect x=\"0\" y=\"0\" width=\"" + larg + "\" height=\"" + haut + "\" fill=\"#FFFFFF\"/>")
  && en-têtes des jours
  locale dates = {}
  pour d = 1 a g.nj
    locale x = gx + (d - 1) * cw
    locale titre = g.jours[d].nom
    si lundi <> nul
      locale dd = DECALER_JOURS(lundi, g.jours[d].num - 1)
      dates[d] = dd
      titre = titre + " " + souschaine(dd, 9, 2) + "/" + souschaine(dd, 6, 2)
    finsi
    inserer(l, "<rect x=\"" + (x + 1) + "\" y=\"8\" width=\"" + (cw - 2) + "\" height=\"30\" rx=\"6\" fill=\"#1F3A5F\"/>")
    inserer(l, "<text x=\"" + (x + cw / 2) + "\" y=\"28\" text-anchor=\"middle\" font-size=\"14\" font-weight=\"bold\" fill=\"#FFFFFF\">" + ECHAPPER(titre) + "</text>")
  suivant
  && heures et fond de grille
  pour p = 1 a g.np
    locale cr = g.creneaux[p]
    inserer(l, "<text x=\"" + (gx - 8) + "\" y=\"" + (ys[p] + 16) + "\" text-anchor=\"end\" font-size=\"12\" fill=\"#495057\">" + cr.debut + "</text>")
    inserer(l, "<text x=\"" + (gx - 8) + "\" y=\"" + (ys[p] + 31) + "\" text-anchor=\"end\" font-size=\"11\" fill=\"#ADB5BD\">" + cr.fin + "</text>")
    pour d = 1 a g.nj
      locale x = gx + (d - 1) * cw
      locale u = (d - 1) * g.np + (p - 1)
      si fermes[u]
        inserer(l, "<rect x=\"" + (x + 1) + "\" y=\"" + ys[p] + "\" width=\"" + (cw - 2) + "\" height=\"" + rh + "\" rx=\"4\" fill=\"#E9ECEF\"/>")
        inserer(l, "<text x=\"" + (x + cw / 2) + "\" y=\"" + (ys[p] + rh / 2 + 4) + "\" text-anchor=\"middle\" font-size=\"11\" fill=\"#ADB5BD\">indisponible</text>")
      sinon
        inserer(l, "<rect x=\"" + (x + 1) + "\" y=\"" + ys[p] + "\" width=\"" + (cw - 2) + "\" height=\"" + rh + "\" rx=\"4\" fill=\"#F8F9FA\" stroke=\"#E9ECEF\"/>")
      finsi
    suivant
  suivant
  && séances qui se chevauchent (options en barrette) : la case est partagée
  locale col = {}, ncol = {}
  pour chaque a dans sl
    locale n = 0
    locale rang = 0
    pour chaque b dans sl
      si b.jour = a.jour et b.creneau < a.creneau + a.duree et a.creneau < b.creneau + b.duree
        si b.id < a.id
          rang += 1
        finsi
        n += 1
      finsi
    suivant
    col[a.id] = rang
    ncol[a.id] = n
  suivant
  && séances
  locale parid = {}
  locale nb = 0
  locale perdues = 0
  pour chaque s dans sl
    locale d = g.rangjour[s.jour]
    si d = nul
      boucler
    finsi
    nb += 1
    parid[s.id] = s
    locale w = (cw - 6) / ncol[s.id]
    locale x = gx + d * cw + 3 + col[s.id] * w
    locale y0 = ys[s.creneau]
    locale pf = min(g.np, s.creneau + s.duree - 1)
    locale h = ys[pf] + rh - y0
    locale coul = s.couleur ou "#868E96"
    locale fond = coul
    locale op = "0.22"
    locale trait = coul
    locale texte1 = "#1A1A1A"
    locale l2 = ""
    locale l3 = ""
    faire cas
    cas genre = "classe"
      l2 = s.enseignant
      l3 = sisinon(s.public <> cible, s.public + " · ", "") + (s.salle_remplacement ou s.salle ou "")
    cas genre = "enseignant"
      l2 = s.public
      l3 = s.salle_remplacement ou s.salle ou ""
    autrement
      l2 = s.public
      l3 = s.enseignant
    fincas
    faire cas
    cas s.statut = "annulee"
      fond = "#DEE2E6"
      op = "0.9"
      trait = "#ADB5BD"
      texte1 = "#868E96"
      l2 = s.motif
      l3 = "annulée"
      perdues += s.duree
    cas s.statut = "non assuree"
      trait = "#E03131"
      l3 = "non assurée : " + s.motif
    cas s.statut = "salle changee"
      l3 = "salle " + s.salle + " → " + (s.salle_remplacement ou "?")
    cas s.statut = "sans salle"
      trait = "#F08C00"
      l3 = "sans salle (" + s.motif + ")"
    fincas
    locale nc = entier((w - 14) / 6.6)
    inserer(l, "<g data-groupe=\"s:" + s.id + "\">")
    inserer(l, "<rect x=\"" + x + "\" y=\"" + (y0 + 1) + "\" width=\"" + w + "\" height=\"" + (h - 2) + "\" rx=\"6\" fill=\"" + fond + "\" fill-opacity=\"" + op + "\" stroke=\"" + trait + "\" stroke-width=\"" + sisinon(s.statut = "non assuree", "2.5", "1.2") + "\"/>")
    inserer(l, "<rect x=\"" + x + "\" y=\"" + (y0 + 1) + "\" width=\"6\" height=\"" + (h - 2) + "\" rx=\"3\" fill=\"" + sisinon(s.statut = "annulee", "#ADB5BD", coul) + "\"/>")
    inserer(l, "<text x=\"" + (x + 12) + "\" y=\"" + (y0 + 17) + "\" font-size=\"13\" font-weight=\"bold\" fill=\"" + texte1 + "\">" + ECHAPPER(COUPER(s.matiere, nc)) + "</text>")
    inserer(l, "<text x=\"" + (x + 12) + "\" y=\"" + (y0 + 33) + "\" font-size=\"11\" fill=\"#343A40\">" + ECHAPPER(COUPER(l2, nc)) + "</text>")
    inserer(l, "<text x=\"" + (x + 12) + "\" y=\"" + (y0 + 48) + "\" font-size=\"11\" fill=\"" + sisinon(s.statut = "non assuree", "#E03131", "#495057") + "\">" + ECHAPPER(COUPER(l3, nc)) + "</text>")
    si s.epingle
      inserer(l, "<circle cx=\"" + (x + w - 9) + "\" cy=\"" + (y0 + 10) + "\" r=\"4.5\" fill=\"#E8590C\" stroke=\"#FFFFFF\" stroke-width=\"1.5\"/>")
    finsi
    inserer(l, "</g>")
  suivant
  inserer(l, "</svg>")
retourner {svg = joindre(l, car(10)), largeur = larg, hauteur = haut, seances = parid, nombre = nb, perdues = perdues}
