&& CC BY-NC-SA 4.0 - jean-marc "jihem" quere 2026
&& Gestion d'établissement : projection de la semaine type sur l'année.
&&
&& Chaque séance de la semaine type donne une occurrence par date ouvrable de
&& l'année (jours ouvrables de la table jours). Les plages datées s'appliquent
&& selon leur portée et, si elles en ont, leur jour et leurs heures :
&&   établissement, niveau, classe, matière (vacances, férié, examen, sortie…) :
&&       la séance est annulée ;
&&   enseignant (absence, formation…) : la séance n'est pas assurée (à remplacer) ;
&&   salle (travaux…) : la séance change de salle (salle compatible libre trouvée
&&       automatiquement, sinon signalée).
&& Résultat : table occurrences(date, seance, cours, …, statut, motif, salle_remplacement).

procedure PROJETER_CALENDRIER
  locale d1 = PARAM("annee_debut", "2026-09-01")
  locale d2 = PARAM("annee_fin", "2027-07-03")
  sql "drop table if exists occurrences"
  sql [[create table occurrences as
    with dates as (select d::date jour_date, isodow(d) dow
                   from generate_series(?::date, ?::date, interval 1 day) t(d)),
    base as (
      select s.id seance, dt.jour_date, s.jour, s.creneau, s.duree, s.salle, c.id cours, c.classe, c.groupe,
             c.matiere, c.niveau, c.enseignant, cr.debut,
             (select fin from creneaux where num = s.creneau + s.duree - 1) fin
      from seances s join cours c on c.id = s.cours
      join dates dt on dt.dow = s.jour
      join jours j on j.num = s.jour and j.ouvre
      join creneaux cr on cr.num = s.creneau),
    regle as (
      select b.*,
        (select p.libelle from plages p where p.du is not null and b.jour_date between p.du and coalesce(p.au, p.du)
           and (p.jour is null or p.jour = b.jour) and (coalesce(p.debut, '') = '' or p.debut < b.fin)
           and (coalesce(p.fin, '') = '' or p.fin > b.debut)
           and (p.portee = 'etablissement' or (p.portee = 'niveau' and p.cible = b.niveau)
                or (p.portee = 'classe' and p.cible = b.classe) or (p.portee = 'matiere' and p.cible = b.matiere))
           order by p.id limit 1) annulation,
        (select p.libelle from plages p where p.du is not null and b.jour_date between p.du and coalesce(p.au, p.du)
           and (p.jour is null or p.jour = b.jour) and (coalesce(p.debut, '') = '' or p.debut < b.fin)
           and (coalesce(p.fin, '') = '' or p.fin > b.debut)
           and p.portee = 'enseignant' and p.cible = b.enseignant order by p.id limit 1) absence,
        (select p.libelle from plages p where p.du is not null and b.jour_date between p.du and coalesce(p.au, p.du)
           and (p.jour is null or p.jour = b.jour) and (coalesce(p.debut, '') = '' or p.debut < b.fin)
           and (coalesce(p.fin, '') = '' or p.fin > b.debut)
           and p.portee = 'salle' and p.cible = b.salle order by p.id limit 1) travaux
      from base b)
    select *, case when annulation is not null then 'annulee'
                   when absence is not null then 'non assuree'
                   when travaux is not null then 'salle changee'
                   else 'prevue' end statut,
           coalesce(annulation, absence, travaux) motif,
           cast(NULL as varchar) salle_remplacement
    from regle]] avec d1, d2
  && salles de remplacement pendant les travaux
  pour chaque o dans requete("select rowid r, * from occurrences where statut = 'salle changee' order by jour_date, creneau")
    locale rempl = SALLE_LIBRE(o)
    si rempl <> nul
      sql "update occurrences set salle_remplacement = ? where rowid = ?" avec rempl, o.r
    sinon
      sql "update occurrences set statut = 'sans salle' where rowid = ?" avec o.r
    finsi
  suivant
retourner

&& Salle compatible libre pour une occurrence (même jour, mêmes créneaux).
fonction SALLE_LIBRE(o)
  locale eff = valeursql([[select coalesce((select count(*) from eleves e where e.classe = c.classe),
                           (select effectif from groupes g where g.code = c.groupe)) from cours c where c.id = ?]], o.cours)
  locale eq = {}
  pour chaque b dans requete("select equipement from besoins where matiere = ? and heures = 0", o.matiere)
    inserer(eq, majuscule(b.equipement))
  suivant
  locale libres = requete([[select sa.code, sa.equipements from salles sa where sa.places >= ? and sa.code <> ?
      and not exists (select 1 from seances s2 where s2.salle = sa.code and s2.jour = ?
                      and s2.creneau <= ? and s2.creneau + s2.duree - 1 >= ?)
      and not exists (select 1 from occurrences x where x.salle_remplacement = sa.code and x.jour_date = ?
                      and x.creneau <= ? and x.creneau + x.duree - 1 >= ?)
      and not exists (select 1 from plages p where p.portee = 'salle' and p.cible = sa.code and p.du is not null
                      and ?::date between p.du and coalesce(p.au, p.du))
      order by sa.batiment, sa.places]], eff ou 0, o.salle, o.jour, o.creneau + o.duree - 1, o.creneau, ;
      o.jour_date, o.creneau + o.duree - 1, o.creneau, o.jour_date)
  pour chaque s dans libres
    locale dispo = MOTS_LISTE(s.equipements)
    locale bon = vrai
    pour chaque e dans eq
      si non contient(dispo, e)
        bon = faux
      finsi
    suivant
    si bon
      retourner s.code
    finsi
  suivant
retourner nul

&& Heures de l'année par cours : prévues (hors vacances), non assurées, perdues.
fonction BILAN_ANNEE()
retourner requete([[select c.id, coalesce(c.classe, c.groupe) public, c.matiere, c.enseignant, c.heures hebdo,
    coalesce(sum(o.duree) filter (where o.statut <> 'annulee'), 0) prevues,
    coalesce(sum(o.duree) filter (where o.statut = 'non assuree'), 0) non_assurees,
    coalesce(sum(o.duree) filter (where o.statut = 'annulee'), 0) annulees,
    count(distinct o.jour_date - (isodow(o.jour_date) - 1)::int) filter (where o.statut <> 'annulee') semaines
  from cours c left join occurrences o on o.cours = c.id
  group by all order by public, c.matiere]])

&& Synthèse de l'année : semaines, heures, séances à remplacer.
fonction SYNTHESE_ANNEE()
retourner requete([[select count(distinct jour_date) filter (where statut <> 'annulee') jours_cours,
    sum(duree) filter (where statut <> 'annulee') heures_prevues,
    sum(duree) filter (where statut = 'non assuree') heures_a_remplacer,
    count(*) filter (where statut = 'salle changee') changements_salle,
    count(*) filter (where statut = 'sans salle') sans_salle
  from occurrences]])[1]

&& Lundi de la semaine d'une date « AAAA-MM-JJ ».
fonction LUNDI(d)
retourner chaine(valeursql("select (?::date - (isodow(?::date) - 1)::int)::varchar", d, d))

fonction DECALER_JOURS(d, n)
retourner chaine(valeursql("select (?::date + ?::int)::varchar", d, n))
