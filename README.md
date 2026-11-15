```
   _._
 o|- -|o This file is licensed under CC BY-NC-SA 4.0 international license.
  ( l )  To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/
    =    Author: jean-marc "jihem" quere 2026
```

[![planning](ressources/planning.png)](https://lipunila.sonaliwan.fr)
# Gestion d'un établissement scolaire en Lexis+ (avec wdreka)

Répartition des élèves dans les classes, services des enseignants, emploi du
temps, attribution des salles, calendrier de l'année et plannings, avec le
solveur de contraintes **wdreka** (paquet `wdreka`, CP-SAT en Nim pur) et une
base **DuckDB**.

```
wdlexisrt exemples/planning/principal.prg [base.duckdb]
```

La base par défaut est `~/planning_lexis/planning.duckdb`. Si elle est
vide, l'exemple **Collège Ada Lovelace** y est chargé. Ce collège est fictif :
16 classes de la 6e à la 3e, 436 élèves, 29 enseignants, 29 salles, les options
espagnol, allemand et latin, et l'année 2026-2027 avec des vacances plausibles.
*Recharger l'exemple* remet ces données.

## Les données (onglet Données)

Chaque table se modifie dans une grille : *Ajouter une ligne*, *Supprimer la
ligne*, *Enregistrer*, *Annuler*, *Exporter CSV*. Les colonnes à choix (niveau,
matière, enseignant, salle…) proposent les valeurs existantes.

| Table | Contenu |
| --- | --- |
| Paramètres | année (début, fin), `max_classe` : heures maximales d'un même enseignant dans une classe, `classe_max_jour`, `tolerance` (équilibre), `delai` de chaque résolution |
| Jours ouvrables, Créneaux horaires | semaine type : jours travaillés, créneaux (début, fin, pause méridienne) |
| Niveaux, Classes | niveaux (6e…3e), classes avec effectif maximal et salle attitrée |
| Matières et missions | matières (couleur, heures maximales par jour) et missions (coordination, labo…) |
| Programme (heures par niveau) | heures hebdomadaires de chaque matière par niveau, durée des séances (1 h, 2 h) |
| Dérogations par classe | heures d'une matière propres à une classe (remplacent le programme du niveau) |
| Options (enseignements de groupe) | matière, niveau, heures, taille maximale des groupes, élèves **regroupés** dans peu de classes ou **répartis** |
| Élèves, Options des élèves | sexe, niveau, profil fort / moyen / faible, classe imposée (`fixe`) ; options suivies |
| Affinités entre élèves | `aime` (à garder ensemble si possible) ou `evite` (à séparer obligatoirement) |
| Enseignants, Compétences, Missions et décharges | service (maximal et minimal), heures par jour, heures par classe ; matières enseignées et niveaux (`*` : tous) ; missions qui comptent dans le service |
| Équipements, Salles et locaux | bâtiment, étage, places, équipements (vidéoprojecteur, paillasses, ordinateurs, gymnase…) |
| Équipements par matière (matrice) | pour chaque matière et chaque équipement : heures qui en ont besoin (vide : aucune, 0 : toutes les heures) |
| Plages : réservations et calendrier | voir plus bas |

### Plages

Une plage est **hebdomadaire** (jour et heures, sans dates) ou **datée**
(`du`…`au`, éventuellement avec des heures). Elle s'applique à une **portée** :
`etablissement`, `niveau`, `classe`, `matiere`, `enseignant` ou `salle`.

L'effet dépend de la portée. Le genre (`fermeture`, `indisponible`,
`absence`, `preparation`, `travaux`, `vacances`, `ferie`, `examen`, `sortie`…)
et le libellé sont descriptifs.

| Portée | Plage hebdomadaire | Plage datée |
| --- | --- | --- |
| `etablissement`, `niveau`, `classe`, `matiere` | aucun cours de cette portée sur ces créneaux (mercredi après-midi libéré, pas d'EPS à 8 h) | séances annulées : vacances, fériés, examens, sorties, éventuellement par niveau ou par classe |
| `enseignant` | indisponibilité : l'emploi du temps l'évite (temps partiel, autre établissement) | absence : séances non assurées, comptées en heures à remplacer |
| `salle` | réservation (préparation) : aucune séance dans la salle | travaux : séances déplacées dans une autre salle compatible et libre, ou signalées sans salle |

## La chaîne de résolution

*Tout générer* enchaîne les étapes. Chaque onglet permet aussi de lancer son
étape seule. La progression du solveur (solutions, objectif, conflits) s'affiche
en bas, et *Arrêter* garde la meilleure solution trouvée.

| Étape | Fichier | Modèle wdreka |
| --- | --- | --- |
| **Répartition** des élèves d'un niveau | `repartition.prg` | `x[e, k]` (élève e en classe k). Effectifs équilibrés (±1), filles et profils fort / faible équilibrés à `tolerance` près, élèves `evite` séparés, classes imposées. Options *regroupées* dans le moins de classes possible ou *réparties*. Objectif : le plus d'affinités `aime` respectées. Les groupes d'options sont ensuite constitués. |
| **Services** des enseignants | `services.prg` | `y[c, t]` (cours c confié à l'enseignant t, ou « à pourvoir »). Compétence pour la matière et le niveau, service maximal, heures par classe (`max_classe`), missions. Objectif : tout pourvoir, puis respecter les services minimaux et limiter le nombre de préparations. Une seconde passe (ordre glouton) prend le relais si la première ne conclut pas dans son délai. |
| **Emploi du temps** de la semaine type | `edt.prg` | `z[s, t]` (séance s commence au créneau t). Une classe et un enseignant à la fois, groupes d'options en barrette, séances de 2 h sans traverser la pause du repas, heures par jour (classe, enseignant, matière), fermetures et indisponibilités. Il faut aussi assez de salles de chaque profil d'équipement à chaque créneau. Les séances épinglées sont conservées. Objectif : éviter les fins de journée et la première heure. |
| **Salles** | `edt.prg` | `r[s, l]` (séance s dans la salle l). Places suffisantes, équipements de la matrice, salles réservées exclues, une séance par salle et par créneau. Objectif : la salle attitrée de la classe. |
| **Vérification** | `edt.prg` | contrôle SQL indépendant du solveur : doublons de classe, d'enseignant, de salle, d'élève (options), plages et capacités |
| **Calendrier** de l'année | `calendrier.prg` | projection de la semaine type sur les jours ouvrables (DuckDB `generate_series`). Les séances sont annulées (vacances, fériés, sorties, examens), non assurées (absence) ou changées de salle (travaux, avec recherche d'une salle libre). |

Les modèles sont du texte NCP construit à partir des tables. *Journal* montre
la taille de chaque modèle (booléens, clauses), son statut (optimal, solution,
infaisable, temps) et sa durée.

## Plannings (onglet Emploi du temps)

- **Planning** d'une classe, d'un enseignant ou d'une salle, en **semaine type**
  ou à une **date** (`<` / `>` : semaine précédente / suivante). À une date, les
  séances annulées, non assurées ou changées de salle sont marquées.
- **Clic sur une séance** : sa fiche (classe ou groupe, enseignant, salle,
  épinglage) et son devenir sur l'année.
- **Épingler / désépingler** : une séance épinglée garde son créneau quand on
  régénère l'emploi du temps.
- **Déplacer vers ce créneau** : le déplacement est refusé, avec ses raisons, si
  le créneau est fermé ou si l'enseignant, la classe, un groupe ou un élève est
  déjà pris. Sinon une salle compatible libre est cherchée si besoin, la séance
  est épinglée et le calendrier de l'année est recalculé.

L'onglet **Calendrier** résume l'année (jours de cours, heures prévues, heures
à remplacer, changements de salle). Il donne aussi le bilan par cours (heures
prévues, annulées, non assurées) et la liste des plages datées.

## Fichiers

| Fichier | Rôle |
| --- | --- |
| `principal.prg` | interface : onglets, lancement des étapes, suivi du solveur, fiches, déplacements |
| `donnees.prg` | schéma DuckDB, paramètres, données d'exemple |
| `editeurs.prg` | éditeurs génériques des tables et de la matrice des équipements |
| `repartition.prg` | répartition des élèves, groupes d'options |
| `services.prg` | cours et services des enseignants |
| `edt.prg` | emploi du temps, salles, vérification |
| `calendrier.prg` | projection sur l'année, salles de remplacement, bilans |
| `planning.prg` | dessin SVG des plannings (toile) |

Avec les données d'exemple, *Tout générer* prend environ 75 secondes : les
répartitions sont optimales, tous les services sont pourvus et les 435 séances
sont placées sans anomalie. Augmenter le paramètre `delai` laisse plus de temps
au solveur pour de plus grands établissements.

## IMPORTANT
Le langage de programmation utilisé pour réaliser cette application est **Lexis+** (disponible pour Linux, macOS et Windows). Vous devez installer l'environnement de développement intégré (EDI / IDE) **[wdlexis+](https://github.com/lipunila-sonaliwan-fr/nim.wdlexis)** disponible sur GitHub pour pouvoir (re)compiler. Le dépôt de **wdlexis** comporte des versions prête à installer dans la section **[Releases](https://github.com/lipunila-sonaliwan-fr/nim.wdlexis/releases)**. La version minimale requise est **v1.9.6 wdlexis+ (complet)**.

## Licence

CC BY-NC-SA 4.0 - jean-marc "jihem" quere 2026

### Encore une chose !
Un p'tit geste qui peut - grandement - nous aider... \[La caféïne c'est important pour une équipe de neuro-atypiques : TSA, TDAH, TAG, HPI et/ou THPI (membres de **mensa.fr** et de **triplenine.org**).\]

[![Buy Me a Coffee](buymeacoffe-fre.png)](https://buymeacoffee.com/sonaliwan.fr)
