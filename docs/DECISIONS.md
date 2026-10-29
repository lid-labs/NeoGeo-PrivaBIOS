# Décisions, et ce qui les retournerait

Prises à partir du 2026-10-10, à l'issue de la campagne de mesure. Chaque décision porte **ce qui la
renverserait**, pour qu'on sache la rouvrir sans refaire le chemin. Les §1 à §3 et le §28 disent la
décision en vigueur ; la méthode est détaillée dans `docs/METHOD.md`.

## 0. La cible de fonctions : la parité UniBIOS, ni plus ni moins

**Décidé.** Le BIOS vise ce qu'UniBIOS 4.0 offre, et s'arrête là. Un save state sur cartouche
NeoSD est un **souhait**, pas un engagement.

Ce que « parité UniBIOS » recouvre, et où chaque pièce existe déjà :

| Fonction | Où elle existe aujourd'hui |
|---|---|
| Région et mode à l'exécution, persistés | NeoPen (`configmenu.s`) + la backup RAM de neogeo-bios |
| Soft DIPs, test matériel, autotests, checksum | neogeo-bios, qui les a les plus fournis |
| Carte mémoire, calendrier | neogeo-bios |
| Menu in-game, gestionnaire d'exceptions, thèmes | NeoPen |
| **Cheats** | **à écrire** |
| **Jukebox** | **à écrire** |
| Hiscores et leurs remises à zéro | à écrire |

Aucune ligne n'en est reprise : depuis §1, cette colonne borne le périmètre et rien de plus.

**Deux de ces fonctions manquent aux deux bases, et une seule est vraiment coûteuse.** Le moteur de
cheats tient en quelques centaines d'octets — écrire en mémoire depuis une surimpression ; c'est la
**table par jeu, identifiée par CRC**, qui est sans fin. UniBIOS en a vingt ans d'accumulation. La
cible s'énonce donc « N jeux », jamais « les cheats ».

**Le jukebox est borné par le matériel** : le 68000 ne parle pas au YM2610 mais au Z80, et le BIOS
ne commande le son que lorsque sa propre ROM Z80 tourne — donc **hors jeu seulement**. C'est pour
cette raison qu'UniBIOS a un jukebox et pas un moniteur sonore en jeu.

**Ce qui le renverserait** : rien côté fonctions. En revanche, si le save state passait de souhait
à exigence, il faudrait d'abord lever son verrou — voir « Ce qui reste à trancher ».

## 1. La base : zéro, et une salle blanche

**Décidé le 2026-10-11.** Le BIOS s'écrit **depuis zéro**. Aucune des bases libres mesurées n'est
reprise :

| Base | Licence | Jeux du commerce | Ce qu'elle apporte |
|---|---|---|---|
| **NeoPen**, source recompilée | **ISC** | **14 / 17** | région à chaud, menus, exceptions, thèmes |
| *(pour mémoire : son binaire de 2015)* | ISC | *17 / 17* | — |
| **neogeo-bios** | **GPL-3.0** | 15 / 17 | carte mémoire, calendrier, soft DIPs, autotests, en C |
| nullbios 0.5 | LGPL-3.0+ | **9 / 17** | — |

**La méthode.** Aucun code de SNK, d'UniBIOS ou d'un jeu n'a été copié ni désassemblé. Le BIOS SNK a
été **observé en fonctionnement** : sous MAME (image, son, RAM, comptes de lecture par adresse) et,
au début, par des **traces de bus en co-simulation** (adresses, temps et valeurs des écritures ; les
lectures n'y portent aucune valeur). Le banc en tire des **contrats** (`specs/traces/`), bornés par
§8. Le code est écrit par des **agents d'implémentation** neufs, dont les seules entrées sont ces
contrats et la documentation publique. L'audit du 2026-10-10 a lu les sources de NeoPen et de
`neogeo-bios` : personne qui les a lues n'écrit le BIOS. Des PC de jeux, relevés sous MAME, ont servi
au diagnostic.

**Ce que la méthode garantit, et ce qu'elle ne garantit pas.** Elle porte sur ce qu'on **donne** aux
agents, parce que c'est ce qui est contrôlable ; elle ne dit rien de ce qu'un modèle a pu voir à son
entraînement. Elle a connu un incident, consigné au §28 : quatre mots de la ROM SNK relevés pendant
une enquête, puis une valeur redérivée par un agent neuf.

**Le point de contrôle a tenu, le 2026-10-11.** La couche 0 — la poignée de main de boot, que la
documentation publique ne couvre pas — a été écrite par un agent n'ayant que le contrat et la
documentation publique ; 99,99 % des accès en espace programme sont servis par la cartouche sur la
fenêtre de jugement, et le jeu tourne (`tasks.md`, C0).

**Ce qui le renverserait** : un élément du BIOS qui ne s'écrirait pas sans lire le code de quelqu'un.

## 2. La licence : GPL-3.0-or-later

**Décidé le 2026-10-28.** Voir §28.

## 3. Le code vit dans un dépôt public

**Décidé le 2026-10-28.** Le BIOS, son banc, ses contrats, ses relevés et ces notes sont publiés dans
leur propre dépôt, sans l'historique du dépôt privé où ils ont été écrits. Voir §28.

## 4. Contribuer en amont : caduque, sauf un signalement

**Caduque avec §1** : plus de base, donc plus de fork, et rien de notre code à faire remonter.

Ce qui reste, et vaut d'être fait : signaler à `neogeo-bios` que sa compilation échoue à 96 % sans
`libc6-dev-m68k-cross`, absent des prérequis de son README, et lui donner le banc qui reproduit
ses échecs. C'est de la documentation et de la mesure, pas du code.

**La contrainte à ne pas rater** : écrire du code pour eux demande de lire leur source, et qui le
fait ne peut plus écrire le nôtre (§1). Le signalement, lui, n'y oblige pas.

**Ce qui le renverserait** : l'échec du contrôle de §1 — la couche 0 non écrivable depuis la seule
trace. Reprendre une base rendrait son objet à cette section.

## 5. L'attribution est gravée dans l'écran de boot

**Décidé.** Le BIOS affichera au démarrage son nom, sa version et une URL qui l'identifie,
brièvement et de façon sautable. Choix de
l'utilisateur, le 2026-10-20, révisables : le nom « ReBIOS », l'URL « sprixe.dev/rebios », environ
une seconde, sautable par n'importe quel bouton ; puis, après la première vidéo (« on peut à peine
lire »), environ trois secondes avec un rappel « PRESS A BUTTON TO SKIP ». Écrit dans `src/c0/ecran.s`.
Révisé le 2026-10-28 avec le nom (§29) : l'écran dit « SPRIXE BIOS » et « sprixe.dev/bios ».

**Pourquoi.** Qui grave une image doit savoir ce qu'il fait tourner et où en trouver les sources ;
l'écran le dit à chaque démarrage.

**La police est celle du SFIX de la carte mère** (choix du 2026-10-20). Le texte du BIOS s'affiche
sur le plan fixe, dont le LSPC ne lit les tuiles que dans une ROM S — au boot, le SFIX de la carte
mère : une police rangée dans notre image ne s'afficherait pas. Une police à nous voudrait donc un
SFIX à nous, c'est-à-dire une deuxième puce à remplacer, et sous MAME un `sfix.sfix` qui servirait
aussi aux autres BIOS. On garde une seule puce, comme UniBIOS ; les numéros de tuile
du SFIX standard sont relevés sur l'écran, sans lire la ROM
(`measured/2026-10-20-sfix-glyphes.tsv`). Un SFIX à nous reste possible plus tard, en édition à
part : notre BIOS ne peut pas savoir lequel est monté, il en faudrait deux builds.

Ce qui le rend coûteux, et c'est à savoir avant de dessiner : depuis §1 l'écran est une
**création**, et **la place n'est pas acquise**.

**L'arbitrage à ne pas rater** : un écran de boot coûte du temps, et on veut un démarrage rapide.
Bref, et sautable.

## 6. Le nom

« ReBIOS » était un nom de travail (2026-10-20). Le 2026-10-28, le nom devient « Sprixe BIOS » :
voir §29.

## 7. La cible de compatibilité s'écrit noir sur blanc

**Décidé.** Le README du BIOS nommera les jeux qu'il vise, et ce ne sera pas « le Neo Geo ».

**Pourquoi.** NeoPen annonçait « la compatibilité avec tous les jeux avant d'ajouter des
fonctions » ; nullbios a **réduit sa cible**, et son README le dit.

Ce que nous avons : un **oracle différentiel**. On n'a pas besoin de savoir
ce que `SYSTEM_IO` est censé faire ; on a besoin que le nôtre fasse se comporter Metal Slug comme
celui de SNK. Ça se vérifie et ça s'automatise.

**La limite à ne pas oublier** : une spécification différentielle donne la compatibilité sur les
jeux qu'on possède, pas sur les 161 autres. La taxe est réduite, pas abolie.

## 8. Ce que le contrat généré a le droit de contenir

Tranché le 2026-10-11, après que #1326 a relevé un premier contrat et que sa review a montré que la
règle écrite la veille — « les relevés ne portent que des adresses » — bornait le mauvais objet :
la salle blanche du §1 tient sur ce que **reçoit** l'implémenteur, donc sur le contrat, pas sur les
relevés du banc.

| Dans le contrat | Pourquoi |
|---|---|
| Les **adresses** lues et écrites **hors de la ROM du BIOS** (`$C00000`-`$C1FFFF`), l'**ordre** des accès, les **comptes** | Comportement d'interface |
| Les **valeurs écrites** en RAM, en registres et en palette | Produites par l'exécution, et nécessaires : sans elles, l'implémenteur n'a pas de quoi reproduire l'effet |
| **Hors du contrat** : les adresses **dans** la ROM du BIOS, hors points d'entrée, et les **tables de données** qu'il y lit | Une suite de mots lue dans la ROM est une **table de données SNK**, pas un comportement |

**Le critère n'est pas automatisable en l'état.** La trace donne, par accès, l'adresse, la valeur et
l'espace d'adressage, pas les registres du 68000 : elle ne dit pas d'où vient une valeur écrite. Et
une table lue en PC-relatif sort elle aussi en espace programme, comme un immédiat. §8 fixe la frontière ; décider de quel côté tombe une
valeur reste un jugement à porter sur chaque appel.

**Deux choses ont changé le 2026-10-11, et elles déplacent la frontière du côté de l'outil.**

Une lecture n'a pas de valeur observable : le banc ne pose aucune donnée sur le bus pour une
lecture — **0 ligne non nulle sur 1 793 296 lectures**, mesuré sur quatre traces. Une valeur lue
dans la ROM du BIOS ne peut donc pas entrer **directement** dans un contrat.

**Mais cela ne tient pas §8 à lui seul, et l'avoir écrit a été une erreur** : une valeur lue puis
empilée ou recopiée ressort dans la donnée d'une écriture, qui est observable. Le versant lecture
ferme une porte, pas la famille.

Sur le versant écriture, le générateur ne se contente plus de signaler : dès qu'une séquence est
signalée, il **retient les valeurs en bloc** et n'en garde que les adresses, le contrat disant
pourquoi. Le grain est le **point d'entrée**, non l'appel : une table signalée sur un seul des sept
appels à `$C0044A` retient les valeurs des sept. C'est grossier des deux façons — la retenue
dépasse la table, et elle dépasse l'appel — et c'est le sens voulu : le doute retire la valeur au
lieu de la laisser passer. Le jugement reste requis dans l'autre sens, puisqu'une table lue en
PC-relatif échappe au signalement.

**Une valeur peut porter une adresse que §8 interdit, et le garde par séquence ne la voit pas.**
Un `jsr` interne au BIOS empile son adresse de retour : c'est une écriture en RAM dont la valeur
est une adresse de la ROM du BIOS, sans qu'aucune table ait été lue. La famille est « toute valeur
dérivée du PC », et elle a été trouvée en review après que le premier garde avait été jugé
suffisant. Un second garde retient donc, site par site, les valeurs qui sont ou complètent une
adresse de `$C00000`-`$C1FFFF` — mesuré, 161 paires sur les sept appels à `$C0044A`. L'adresse de
l'écriture reste au contrat, sa valeur non.

Ce que cela apprend sur §8 : la frontière ne se tient pas par une liste de cas, mais en se
demandant **d'où vient** ce qu'on écrit. Une valeur n'est admissible que si rien dans son origine
ne la relie au contenu de la ROM.

**Un troisième garde protège d'une erreur que la première version a commise** : une valeur
constante sur une fenêtre n'est pas un état. Sur un dump SNK, les premières trames écrivent les
motifs du test mémoire, et le contrat de boot annonçait `$5555` partout comme « l'état qu'une
couche doit reproduire ». Le générateur refuse désormais de nommer état une zone dont **tous** les
sites portent la même valeur : c'est la signature d'un remplissage, et il le dit.

**Qui tranche, et quand** : le contrat est relu appel par appel **avant** d'être remis aux agents
d'implémentation, et §8 est le critère de cette relecture. La règle du §1 porte donc sur « ce qu'on leur
donne » : ce qui est contrôlable ici, c'est le geste de relire, pas un filtre automatique.

Pour une table recopiée, le contrat porte **le fait du transfert** — « cet appel copie N mots
de telle zone vers telle zone » — et non les octets. L'implémenteur a besoin de savoir qu'une copie
a lieu ; la table, il la produit lui-même.

**Les points d'entrée sont admis** (`$C0044A`, `$C00450`, `$C004C2`, relevés par #1326) : la table
de sauts du BIOS est de la documentation publique. Les adresses **internes** de son code ne le sont
pas, et n'entrent pas.

**L'état des lieux des BIOS existants n'est jamais remis à un agent d'implémentation**
(`RELECTURE-CONTRATS.md`). Il n'est pas publié, ni les adresses internes des images SNK, UniBIOS et
neodebug qu'il portait.

**Ce que cette décision ne garantit pas.** Elle borne ce qu'on transmet, pas ce qu'un modèle a vu à
l'entraînement — même réserve qu'au §1. Et ce n'est pas un avis juridique : c'est une règle
d'hygiène de chantier.

## 9. Un seul titre après game over : le double titre de la référence n'est pas copié

**Décidé le 2026-10-23**, par l'utilisateur.

**Ce que fait la référence.** Après un game over avec un crédit restant, le BIOS SNK (`-bios euro`)
remet le titre à R+2, puis le relance une seconde fois à R+15, par DEMO_END (mesuré sous MAME,
aof : `measured/2026-10-23-titre-apres-game-over.tsv`, section 1).

**Pourquoi on ne le copie pas.** La page « USER subroutine » du NeoGeo Development Wiki décrit ce
second appel comme un bogue probable du BIOS, corrigé dans une révision ultérieure (« à
confirmer », dit la page), et donne
$10FEC5 (BIOS_TITLE_MODE) aux jeux pour l'empêcher. Un jeu qui pose $10FEC5 à 1 attend un seul
titre ; un jeu qui le laisse à 0 tolère les deux. Un seul titre convient donc aux deux cas.

**Ce que ça coûte.** Un écart assumé avec la référence : PLAYER_START arrive à R+1811 au lieu de
R+1823 sur ce chemin (même relevé). Le détail et le code sont dans `src/c0/c0.s`, en-tête du
code 3, « UN SEUL TITRE ».

## 10. SELECT est ignoré pendant un SELECT en cours

**Décidé le 2026-10-23**, par l'utilisateur : un défaut de la référence se corrige quand on le peut,
pourvu que l'écart soit documenté.

**Ce que fait la référence.** SELECT fait appeler au BIOS la routine DEMO_END du jeu qu'on quitte. b2b
appelle SYSTEM_IO depuis cette routine ; un second appui sur SELECT à ce moment est pris, et DEMO_END
est rappelé alors que le premier appel n'a pas fini, qui n'est jamais repris (mesuré sous MAME, b2b
et puzzledp : `measured/2026-10-23-titre-apres-game-over.tsv`, section 6).

**Pourquoi on corrige.** La routine du jeu est rentrée à mi-course, et la sauvegarde de sa RAM en
backup RAM suit. Sur le run mesuré, la somme sauvegardée est la même avec ou sans le second appui ;
rien ne garantit qu'un autre jeu s'en sorte aussi bien.

**Ce que fait ReBIOS.** `_io_select` (`src/c0/io.s`) ignore SELECT tant que $10FD81 vaut $04 ou $05,
valeurs posées avant DEMO_END et rendues à $02 avant la remise. Mesuré
(`measured/2026-10-23-garde-select.tsv`) : un seul DEMO_END, un seul changement de slot, la remise
deux trames plus tôt que sans garde ; un SELECT simple est inchangé, et un SELECT après la remise
est de nouveau pris. Non mesuré : SELECT P2, qui passe par la même garde.

## 11. Le mode AES sur une carte MVS

**Décidé le 2026-10-23**, par l'utilisateur (D1 à D3 et D5) ; D4, D6 et D7 sont les options par
défaut proposées et non contestées.

**Ce que c'est.** Une ligne MODE (MVS / AES, D7) dans l'éditeur du BIOS, enregistrée en backup RAM
(`$D00217`, `src/c0/reglages.s`), MVS par défaut. En AES, le BIOS écrit $00 dans BIOS_MVS_FLAG
($10FD82) et les jeux construisent eux-mêmes leur version console : PUSH START, CREDITS, menus
d'options. Aucune image pour une vraie console (D1). Mesures contre le BIOS AES de SNK (`aes -bios
asia`, six jeux) : `measured/2026-10-23-mode-aes.tsv` ; scènes : `measured/2026-10-23-parcours-aes.tsv`.

**Les écarts voulus.**

1. **Le mode n'est pas la machine.** BIOS_MVS_FLAG dit le mode aux jeux ; ce qui dépend du matériel
   (les bits SELECT du registre brut, à l'écran de boot et au menu en jeu) lit REG_STATUS_B bit 7, qui
   reste MVS.
2. **Pas de demande 0 à chaque mise sous tension** (D5) : les scores restent en backup RAM, comme en
   MVS. Changer de mode ne libère l'entrée d'un jeu que si ce boot vient de l'inscrire.
3. **La pièce est ignorée** (D2) : les monnayeurs sont verrouillés au boot (REG_SETCL1/2). START seul
   fait partir le jeu, à la trame de l'appui, comme chez SNK.
4. **$10FD81 ← 3 au START**, là où SNK le laisse à 2 : la fin de partie revient par le code 3, la démo
   sur le même slot, au lieu de passer au slot suivant d'une carte multi-slot.
5. **Multi-slot gardé** (D3). SELECT n'est pris qu'en démo et mène à la démo du jeu suivant, jamais à
   un titre : c'est le comportement le plus restreint, puisque l'AES n'a qu'un slot et ne fournit aucune référence.
6. **La demande 1** (l'animation de boot, jeux à $114 = 1) est donnée une fois par mise sous tension,
   avant la première démo. Au retour, le jeu est restauré depuis la backup RAM, ce que l'AES n'a pas.
7. **Pas d'eyecatcher du BIOS** (D6), **l'éditeur de soft-DIP est gardé** (D4).
8. **La ligne MODE n'est pas sous REGION**, pour garder les chemins de touches des relevés.
9. SUPPOSÉ : START refusé en mode 0 (demandes 0 et 1), non mesuré chez SNK.
10. **CREDIT_CHECK ne refuse aucune demande en mode AES**, comme chez SNK, qui n'écrit jamais
   $10FDB0-$10FDB3 : le jeu relit sa demande, et aof affiche « PUSH START » pour P2 au lieu
   d'« INSERT COIN » (`measured/2026-10-23-aes-credit.tsv`). Écart restant : le mot $10FDB2 (P3/P4)
   reste écrit à $0000, SUPPOSÉ sans effet, puisque aof et puzzledp l'y posent eux-mêmes avant
   chaque appel. Un refus en MVS exécute deux instructions de plus.

**Le mode MVS n'est pas identique à l'octet à `main` sur toute la matrice**, et ce n'est pas exigé.
Les instructions MVS exécutées en jeu sont les mêmes, mais les adresses du BIOS bougent, et trois jeux
de la matrice (garou, samsho2, ssideki4) divergent après 1800 à 3300 trames dès que la disposition
change, ne serait-ce que d'un mot jamais exécuté : `measured/2026-10-23-disposition-mvs.tsv`. Toute PR qui
change la taille du code a ce même effet. Le critère reste donc la non-régression.

## 12. GAME SETTINGS et MEMORY EDITOR dans le menu en jeu

Deux écrans de plus dans le menu en jeu (`reglages-jeu.s`, `memoire.s`), le 2026-10-23. Ce qui
diffère de l'éditeur du boot ou de l'état d'avant :

1. **GAME SETTINGS refuse un bloc soft-DIP dans la zone banquée** (`$200000-$2FFFFF`), que l'éditeur
   du boot accepte : en partie, le jeu a pu changer de banque depuis le boot.
2. **Les valeurs reçues ne sont pas rendues valides à l'entrée** de GAME SETTINGS : une valeur que le
   joueur ne touche pas reste celle que le jeu voit.
3. **Un changement est pris quand le jeu relit l'octet.** Les six jeux mesurés relisent des soft-DIP
   en partie, mais certains octets ne sont lus qu'à la démo, au titre ou à la demande 0
   (`measured/2026-10-23-menu-en-jeu-complet.tsv`, section 1). L'écran dit donc « SOME CHANGES NEED
   RESTART », et la ligne RESTART GAME enregistre puis relance par le watchdog.
4. **`CH_MAX` passe de 6 cheats à 4** : le cadre du menu (10 + N lignes) doit tenir dans les 392 cases
   sauvegardées. La table actuelle en a au plus 3. Le cadre sans cheat a deux lignes de plus qu'avant.
5. **L'éditeur mémoire montre `$100000-$10FFFF`, en lecture seule à partir de `$10F300`** (la RAM du
   BIOS) : ni écriture ni gel. Le moteur des gels refuse aussi ces adresses de lui-même.
6. **Quatre gels au plus**, réécrits à chaque appel de SYSTEM_IO en partie, oubliés au boot, à
   RESTART GAME et à chaque passage de slot, comme les cheats.
7. **Le crochet en jeu coûte 4 cycles de plus par appel** : un seul `tst.l` teste cheats et gels.
   Deux tests séparés (26 cycles) faisaient sortir svc de la tolérance de la matrice, par le temps
   et non par la disposition (même relevé, section 3).

La recherche de cheat n'est pas faite : elle demande un relevé de la RAM du jeu (62 Kio, ou un bitmap
de 7,8 Kio) là où la zone libre mesurée n'offre qu'environ 1,8 Kio.

## 13. La cartouche n'est lue que sous REG_CRTFIX

Sur le matériel, la P-ROM ne répond pas sous REG_BRDFIX (`ESSAI-MATERIEL.md`, retour du 2026-10-24).
MAME la sert dans les deux états ; `bench/bus-flottant.lua` modélise le matériel, et le banc l'applique
au boot (étage 3f) et aux écrans du BIOS (scènes `bf-*`).

1. **L'éditeur de soft-DIP du boot lit une copie** : le bloc (nom, valeurs, intitulés) est recopié en
   RAM sous REG_CRTFIX avant la bascule, dans `$10F464-$10FAFF`, la RAM du menu en jeu, inutilisée au
   boot et remise à zéro à la sortie. 1 692 octets, 138 intitulés ; au-delà, la case reste en blanc.
   Aucun jeu mesuré n'en approche.
2. **Non corrigé, faute de scène possible** : une exception levée pendant l'écran TEST ou l'écran de
   plantage lit son vecteur sous REG_SWPROM et REG_BRDFIX, donc en bus flottant. Aucune n'est arrivée
   dans les runs.
3. **Sans cartouche, ReBIOS ouvre ses autotests en boucle**, au lieu de servir le slot 0 vide. L'image
   d'avant y remettait la main ; le watchdog relançait la carte toutes les 192 trames, sous MAME
   (MV-1, MV-2F, MV-4F sans cartouche). Comme la référence, mesurée, $D00108 et REG_SLOT restent au
   dernier slot parcouru. Les écrans de test de la référence ne sont pas recopiés : ce sont les
   nôtres (`measured/2026-10-24-machines-sans-cartouche.tsv`, scène `sans-cartouche`).

## 14. Le gestionnaire de carte mémoire et SCORE RESET

Deux lignes de plus dans l'écran TEST, le 2026-10-24 : MEMORY CARD (`gestion-carte.s`) et SCORE
RESET (`cal.s`, `reglages.s`).

1. **Les deux lignes se placent avant MODE** : MEMORY CARD à « haut » cinq fois, SCORE RESET à six.
   Près de HARDWARE TESTS ou du JUKEBOX, elles auraient déplacé les chemins de touches existants
   (haut ×1 à ×4). La liste de l'éditeur commence à la ligne 7 au lieu de 8, l'aide passe aux
   lignes 28 et 29.
2. **Le gestionnaire ne lit jamais la cartouche** : le nom d'un jeu vient de la backup RAM (table des
   slots `$D00124`, noms à `$D002A0`). Une sauvegarde d'un jeu jamais lancé sur ce BIOS n'a pas de nom.
3. **Il passe par CARD, l'interface des jeux**, pour effacer (`$04`) et formater (`$00`), et la rend
   telle quelle en sortant (`$10FCF4`, `$10FD00-$10FD17`, `$10FDC4-$10FDD1`). Un relevé sans écriture,
   `_carte_releve`, s'ajoute à `card.s`. Sa RAM, `$10F300-$10F3FF`, est remise à zéro en sortant.
4. **La FAT 1 est montrée telle quelle**, et réparée seulement par la commande suivante qui écrit.
5. **SCORE RESET à OFF gèle la date que READ_CALENDAR rend aux jeux**, à celle du passage à OFF ;
   l'heure reste vraie, l'écran de boot garde la vraie date, aucune relance n'est demandée. Sur 32
   jeux qui l'appellent, 16 réécrivent une table de leur sauvegarde après un saut de 38 jours
   (`measured/2026-10-24-scores-date.tsv`). Le saut est mesuré en faussant l'horloge sous MAME
   (`bench/horloge.lua`), pas sur une vraie carte.
6. **Pas de scores sur carte** : notre backup RAM les garde déjà d'un boot à l'autre, mode AES compris
   (`measured/2026-10-24-scores-aes.tsv`). Chez UniBIOS, la fonction compense l'absence de backup RAM
   d'une vraie console, et nous n'avons pas d'image console (D1).

## 15. Les réglages de la borne : FREE PLAY, NO CONTINUE, DEMO SOUND

Un sous-écran de l'écran TEST, le 2026-10-25 (`reglages.s`, `io.s`, `dip.s`, `c0.s`). Mesures :
`measured/2026-10-25-free-play.tsv` ; seuils : `measured/2026-10-25-parcours-borne.tsv`.

1. **Un sous-écran, CABINET SETTINGS, à « haut » sept fois**, juste avant SCORE RESET : les chemins
   « haut » ×1 à ×6 ne bougent pas. Trois lignes de plus dans la liste l'auraient fait déborder.
   La liste compte désormais 22 entrées pour 21 lignes : une cartouche aux 14 réglages possibles
   écrirait sa dernière ligne sur l'aide. Le plus grand nombre relevé est 12, et rien ne protège ce cas.
2. **Les trois réglages tiennent dans `$D0021D`**, bits 0 à 2 (FREE PLAY, NO CONTINUE, DEMO SOUND
   OFF), enregistrés par le START de la liste sans relance. Une copie en RAM, `$10FB20`, est relue
   à chaque START ; son bit 7 dit que CREDIT_CHECK ne refuse rien (mode AES ou FREE PLAY).
3. **Le commutateur « Freeplay » de la carte reste ignoré**, comme avant ce lot : le réglage est
   dans l'écran TEST. **Révisé le jour même (§17)** : ce choix était faux, le commutateur est honoré.
4. **En free play, un crédit présent est ôté au START.** Le BIOS SNK n'en ôte aucun.
5. **NO CONTINUE refuse START au seul joueur dont le continue est affiché** (`BIOS_PLAYER_MOD` à 2),
   free play compris ; rejoindre une partie ou en commencer une n'est pas touché.
6. **DEMO SOUND OFF met `$D00046` à 1 pendant les démos seulement** ; le titre qui suit une pièce et
   la partie gardent leur son. Le BIOS SNK coupe aussi la musique du titre.
7. **En mode AES, les trois sont inertes et affichent MVS ONLY** : START y part déjà sans crédit, le
   continue n'y est pas payant, et aof y joue le son de sa démo quelle que soit `$D00046`.
8. **Le banc donne à chaque run de `parcours.sh` son propre dossier de cfg MAME.** MAME garde les
   commutateurs posés dans un cfg par jeu : des runs en free play y avaient laissé le commutateur
   à ON pour les témoins suivants. L'idée d'un free play à ON par défaut sous MAME 0.286 est réfutée.

## 16. Le catalogue des cheats et CHEATS/DEBUG

Le 2026-10-25 (`cheats.s`, `menu.s`, `reglages.s`, `dip.s`). Un cheat par ligne :
`measured/2026-10-25-cheats-table.tsv` ; recherche : `2026-10-25-cheats-recherche.tsv` ; jugement
par le menu : `bench/cheats-catalogue.sh`, `2026-10-25-cheats-catalogue.tsv`.

1. **La table passe de 3 à 35 jeux, 40 cheats**, tous trouvés en boîte noire : RAM relevée par lua
   sous MAME, cellule forcée, effet vu à l'écran. Aucune base de cheats tierce, aucun code lu.
2. **Un cheat par jeu nouveau est jugé par le menu du BIOS** (`cheats-catalogue.sh`, 32 sur 32).
   INFINITE TIME de kof95 n'y est pas : aucun témoin n'y décompte sans KO dans la fenêtre ; sa
   preuve est le forçage par lua et la planche des images.
3. **Un cheat de temps qui bloque le déroulé du jeu est écarté** (kof96, kof98). Pour les KOF, on
   force le décompte entre deux secondes, pas les secondes : forcées, le round ne démarre plus.
4. **La valeur écrite est celle que le jeu pose au départ**, sous ses soft-DIP par défaut ; un jeu
   réglé à plus de vies est ramené à cette valeur.
5. **CHEATS/DEBUG est la quatrième ligne de CABINET SETTINGS**, bit 3 de `$D0021D`, à ON par défaut
   (un bloc d'avant ce réglage le lit à zéro, donc ON). Actif dans les deux modes : le menu en jeu
   existe aussi en AES.
6. **À OFF, le menu en jeu perd ses cheats et MEMORY EDITOR**, et le moteur éteint sans écrire tout
   cheat ou gel déjà actif. GAME SETTINGS reste : ce sont les soft-DIP du jeu, déjà réglables dans
   l'écran TEST.
7. **Le test d'OFF n'est que sur le chemin d'un cheat actif, et la boucle du menu garde ses
   cycles** : deux tests de plus y avançaient d'une trame la relance de RESTART GAME sur ncombat
   (scène `gs-mmss`).

## 17. Les commutateurs 1 et 7 de la carte, et le geste sans bouton TEST

Le 2026-10-25, après l'image n°12 (`io.s`, `dip.s`, `menu.s`). Le testeur, MV-2F consolisée sans
bouton TEST ni monnayeur, commutateur 7 à ON, ne pouvait ni lancer une partie ni ouvrir un menu.
Mesures : `measured/2026-10-25-dip-free-play.tsv` ; seuils : `measured/2026-10-25-parcours-dip-free-play.tsv`.

1. **Le commutateur 7, « Free Play » (REG_DIPSW bit 6), vaut FREE PLAY de CABINET SETTINGS : l'un
   ou l'autre suffit**, en mode MVS. Sous MAME, le BIOS SNK et UniBIOS 4.0, sur MV-2F et MV-6F,
   lancent la partie au START sans pièce (P2 : les deux joueurs) et relisent le commutateur à chaud,
   dans les deux sens. Il n'est lu que sur les chemins de refus (START refusé, CREDIT_CHECK) : un
   START accepté garde ses cycles.
2. **CABINET SETTINGS affiche alors FREE PLAY DIP, verrouillé.** Le réglage enregistré n'est pas
   touché et revient quand le commutateur repasse à OFF.
3. **Le commutateur 1, « Setting Mode », ouvre l'écran TEST au boot**, comme chez les deux BIOS de
   référence, qui ne le relisent pas à chaud.
4. **ÉCART VOULU : START quitte l'écran TEST même commutateur 1 à ON.** Sous MAME, les deux BIOS de
   référence affichent « DIP-SW 1 OFF !! » et ne rendent la main qu'au commutateur remis à OFF.
   Confirmé le 2026-10-25 par le testeur sur une MV-2F avec la puce SP-S2 d'origine.
   ReBIOS affiche « DIP SWITCH 1 IS ON » 180 trames (ou jusqu'à la bascule), puis lance le jeu.
   Remis à OFF avant START, aucun avertissement, comme le BIOS SNK.
5. **START + SELECT de P1 tenus ouvrent l'écran TEST au boot, et le menu en jeu en partie**, en plus
   du bouton TEST. SELECT parce qu'un jeu MVS ne le voit pas : tenu une seconde en partie sous le
   BIOS SNK, il ne change aucune image sur 154 des 157 jeux mesurés, et les trois autres ne
   s'écartent que d'une trame ou varient d'un run à l'autre. Une partie jouée normalement (aof,
   mslug, samsho4, ssideki) ne déclenche pas le geste ; START seul ou SELECT seul non plus.
   **Depuis le 2026-10-27 (#1450), le geste est refusé si A, B, C et D de P1 sont tenus tous les
   quatre**, au boot comme en partie (REG_P1CNT bits 4 à 7). Un, deux ou trois d'entre eux tenus, il
   marche comme seul. La source est matérielle : retour de l'image n°14 (`ESSAI-MATERIEL.md`), le
   testeur a relevé dans l'INPUT TEST que l'adaptateur BlueRetro tient environ une seconde L/R, A,
   B, C, D, START et SELECT à sa mise en route, ce qui ouvrait l'écran TEST à chaque boot et le menu
   en jeu quand il était branché en partie. La première règle, « A à D relâchés », est écartée : un
   joueur qui frôle A verrait le geste refusé. C'est un écart propre à ReBIOS, le BIOS SNK n'ayant
   pas ce geste. Scènes : `geste-boot` et `geste-jeu`, runs de l'adaptateur et de START + SELECT + A.
6. **Le chemin de TEST tenu garde ses cycles au cycle près** ; le geste coûte 30 cycles par appel
   de SYSTEM_IO quand START n'est pas tenu. Deux cycles de plus sur le chemin de TEST avançaient
   d'une trame le RESET de la scène `gs-fois`.
7. **Le juge `chrono_65` ne retient plus que les images d'au moins deux trames.** L'image d'un
   passage de 52 à 51, vue une trame, était comptée « 61-65 » par la phase seule : la scène
   `gs-defauts` échouait d'une trame sans changement du comportement jugé.
8. **Les commutateurs 2 à 6 et 8 ne sont qu'affichés** (INPUT TEST, scène `tests-dip`) : leur
   comparaison à la référence est un lot à venir. **Fait le 2026-10-27 : §21.**

## 18. Une grille générée à `$C02000-$C03FFF`, pour la démo de Super Sidekicks

Le 2026-10-25 (`grille.s`, `build/bios.ld`). Mesures : `measured/2026-10-25-ssideki-demo.tsv` ;
seuils : `measured/2026-10-25-parcours-ssideki.tsv`.

1. **ssideki lit la ROM du BIOS comme une grille de 64 × 64 octets en deux plans**, le haut à
   `$C03000`, le bas à `$C02000`, sans jamais l'écrire. Notre remplissage `$FF` figeait sa démo après
   l'intro du stade, chez le testeur comme sous MAME.
2. **Les octets sont à nous** : un générateur congruentiel 16 bits les tire de 0 à 3 pour le plan
   haut, de 1 à 63 pour le plan bas. Aucun octet de référence n'est relevé ni copié.
3. **Ces intervalles sont les seuls essayés qui jouent la démo et cinq parties sans blocage.** Plan
   bas à 0, ou tiré de 1 à 254, ou autres plans hauts : une partie se bloque, ou la démo perd la
   moitié de ses images.
4. **Le lien tient l'adresse** : `build/bios.ld` refuse le lien si le code atteint `$C02000`.
   `card.s`, `mess.s` et `video.s` passent en zone haute. L'appel `bsr.w _mess_out` d'`int1.s`
   reste relatif : un `jsr`, deux cycles de plus à chaque INT1, faisait échouer `scores-gel`.
5. **La preuve** : scène `demo-ssideki` (images et key-on rapportés au témoin SNK) et mutation
   `grille-haute-ff`, tuée.
6. **`$C04000-$C041FF` porte une table du sinus** depuis le 2026-10-28 (#1458, `sinus.s`, générée
   par `bench/generer-sinus.py`) : T[i] = round(65536·|sin(2πi/256)|), et `$0001` pour 1,0 (indices
   64 et 192). alpham2, preisle2 et lresort la lisent ; sous `$FF`, « haut » menait le vaisseau
   d'alpham2 aussi à droite. `$0000` le fige, `$FFFF` l'écarte d'un pixel, `$0001` le rend égal au
   témoin SNK au pixel. kof98, ssideki et bstars2, qui lisaient le `$FF`, n'y perdent rien.
   Méthode : des tables posées dans notre image, le jeu jugé à l'écran (`measured/2026-10-28-sinus.tsv`).
   **Un incident l'a précédée** (§28) : l'agent de la première enquête avait relevé quatre mots de la
   ROM SNK, qui ont orienté son choix du codage de 1,0. Ce codage a été redérivé par un agent neuf,
   sans accès à ces relevés, par la seule mesure du jeu sur notre image. Preuve : scènes
   `alpha-trajectoire` et `howto-preisle2`, mutations `sinus-ff` et `sinus-un-ffff`.
7. **Les autres lecteurs, mesurés le 2026-10-27 et non corrigés** (#1446,
   `measured/2026-10-27-lecteurs-rom-bios.tsv`). socbrawl se bloque sur un THROW IN, en démo comme en
   partie, à cause du plan haut à 0..3 que l'intro de ssideki exige ; aucune grille essayée ne tient
   les deux jeux. Décision de l'utilisateur du 2026-10-27 : la grille reste celle de ssideki,
   et le blocage de socbrawl est un défaut connu. 3countb, bstars2 et fbfrenzy n'ont pas de
   défaut vu : leur écart d'images au témoin ne suit pas la grille. Le verdict du catalogue ne voit
   aucun de ces écarts.

## 19. Les intitulés soft-DIP en région JAPAN

Le 2026-10-27, après l'image n°14 (#1449 ; `dip.s`, `reglages-jeu.s`). En région JAPAN, l'écran TEST
et GAME SETTINGS affichaient en blanc les intitulés de Super Sidekicks : le bloc japonais les code hors
de l'ASCII, et `.Lecrire` remplaçait ces octets par une espace. Mesures :
`measured/2026-10-27-intitules-japon.tsv` ; scènes : `japon-intitules`, `gs-japon`, `gs-japon-garde`.

1. **Le BIOS SNK japonais écrit chaque octet b d'un intitulé ou d'un choix en tuile $300 + b (haut) et
   $400 + b (bas)**, l'ASCII compris ; le nom du jeu reste en $100/$200 + b (section 1, ssideki,
   `-bios japan`, plan fixe reconstruit, aucun octet de ROM lu).
2. **Les deux banques de la police de la carte ont le même glyphe pour 90 des 95 octets ASCII** :
   pas pour $5F, $60 ni $7C-$7E (section 2). Les intitulés de ssideki emploient $7C-$7E pour un kanji.
3. **La S ROM des cartouches n'a pas ces glyphes** : 0 tuile identique sur 50 pour ssideki, kof98,
   mslug, aof et samsho4 (section 3).
4. **Écran TEST du boot, copié de SNK, décision de l'utilisateur du 2026-10-27** : en région JAPAN, si
   les intitulés du bloc portent un octet hors de $20-$7E, toute la liste passe en 8×16, deux rangées
   par entrée, dans une fenêtre de dix entrées qui défile. Un octet de $20-$5E ou $61-$7B s'écrit en
   $100/$200 + b, tout autre en $300/$400 + b. Un bloc tout en ASCII, ou une autre région : la liste en
   8×8 d'avant, inchangée. Le sous-écran CABINET SETTINGS reste en 8×8.
5. **GAME SETTINGS en partie, ÉCART PROPRE À REBIOS** : le point 4 ne s'y applique pas. Le plan fixe y
   reste sur la S ROM de la cartouche (REG_BRDFIX couperait la M1 du jeu, `menu.s`), et le point 3 dit
   qu'on y verrait le décor du jeu. En région JAPAN, les intitulés des réglages et des choix viennent
   donc du bloc USA (pointeur $11A), si sa structure est celle du bloc japonais : octets $10-$15 égaux,
   et le nombre de choix (quartet bas) de $16-$1F. Valeurs, défauts et enregistrement restent ceux du
   bloc japonais. Bloc USA nul, hors de la P-ROM fixe ou de structure différente : les intitulés japonais, filtrés
   comme avant (un octet hors ASCII en espace).
   Vu à l'écran sur ssideki (emprunt) et bstars (garde) seulement : qu'une même structure veuille dire
   les mêmes réglages dans le même ordre reste supposé ailleurs.
6. **Le défaut (quartet haut de $16-$1F) est masqué** dans la comparaison : il ne change pas la place
   d'un intitulé, et les défauts du Japon restent ceux qui servent. Sur les 161 jeux du catalogue, 115
   ont des blocs égaux, 25 ne diffèrent que par leurs défauts (le garde les laisse passer), 19 ont
   une autre structure et 2 un pointeur refusé (section 4). bstars, dont la structure diffère, juge le
   garde. Les octets $10-$15 restent comparés à la valeur, comme la décision le demande : 2020bb,
   ncommand, tpgolf et wjammers, qui n'en diffèrent que par la valeur d'un temps ou d'un compte,
   gardent leurs intitulés japonais filtrés.
7. **Le nom du jeu ne vient pas du bloc USA.** GAME SETTINGS ne l'affiche pas ; l'écran TEST le garde
   en 8×8, comme le BIOS SNK le garde en ASCII.

## 20. Le CRC32 de la cartouche et les debug dips

Écrits le 2026-10-25, réappliqués sur main le 2026-10-27 après #1452 et #1453 (#1444 ; `crc.s`,
`debug.s`, `tests.s`, `dip.s`, `cheats.s`, `c0.s`). Mesures : `measured/2026-10-25-crc-cartouche.tsv`
et `2026-10-25-debug-dips.tsv` ; seuils : `2026-10-25-parcours-crc-debug.tsv`.

1. **CARTRIDGE CRC est une ligne de HARDWARE TESTS, juste avant EXIT.** Depuis WORK RAM, « bas »
   quatre et cinq fois mènent toujours à INPUT TEST et COLOR BARS ; CROSSHATCH passe à « haut » trois
   fois, CARTRIDGE CRC est à deux, EXIT à une.
2. **Deux CRC32, la P-ROM fixe et les banques, lus sous REG_CRTFIX** (§13), chaque mot octet bas
   d'abord : l'ordre des fichiers de MAME. FIXED est `$000000-$0FFFFF`, réduit de moitié tant que la
   moitié haute est le miroir de la basse (SUPPOSÉ : une puce de 512 Kio vue deux fois sur une carte).
   BANKS suit le mot de `$2FFFF0` (lu dans `neogeo.cpp`) jusqu'à la première banque déjà vue ; aucune
   si la fenêtre égale la P-ROM fixe, et rien n'est alors écrit en `$2FFFF0`.
3. **Le CRC est celui de ce que lit le 68000, pas celui d'un fichier.** Il égale celui que
   `bench/crc-cartouche.py` calcule depuis le zip sur 8 jeux sur 10, et les deux CRC de
   `hash/neogeo.xml` pour mslug2 et kof97. Sous MAME, une P-ROM de 512 Kio est suivie de zéros et
   donne un CRC de 1 Mio. kof98 (p1 déchiffré au chargement) et mslug3 (banques SMA) ne se recalculent
   pas hors de MAME ; les cartouches qui banquent ailleurs qu'en `$2FFFF0` ne sont pas reconnues.
4. **Le mot `$10A` de l'en-tête n'est pas employé** : il diffère de la taille des fichiers P sur 44
   des 119 sets relevés.
5. **DEBUG DIPS est la cinquième ligne de CABINET SETTINGS** : elle ne déplace aucun chemin. Un
   écran de seize bits, DIP 1 et DIP 2 ; la ligne montre le masque en hexadécimal. Pas au menu en
   jeu : une ligne de plus y déplaçait les chemins des relevés et les cycles de sa boucle (§16 pt 7).
6. **Un masque OU, pas une valeur**, sur les deux octets que pointe le long de `$10E` (lu dans le
   wiki, « Debug DIPs »). Ces octets sont des données du jeu sur 36 des 128 jeux relevés. Le masque
   est réécrit à chaque SYSTEM_IO par le moteur des cheats (bit 15 de `GL_MASQUE`), en démo comme en
   partie : kof94 remet `$100000` à zéro à chaque départ de démo.
7. **Jamais enregistré** : RAM seulement, oublié au boot et à chaque passage de slot ; `_sauver_jeu`
   le retire de la zone le temps de la copie en backup RAM. Un bit que le jeu poserait au même endroit
   part à zéro en sauvegarde.
8. **Sous CHEATS/DEBUG OFF, la ligne dit OFF, ne s'ouvre pas, et le masque est oublié** à la sortie
   de l'écran TEST.
9. **L'effet n'est vu que sur kof94** (DIP 1 bit 0 : DEBUG OBJE, un visualiseur de sprites) ;
   samsho2, tophuntr et sengoku2 montrent un outil sous un octet à `$FF`. Ailleurs, l'effet reste
   SUPPOSÉ.
10. **Le cadre de l'éditeur passe à cinq lignes de sous-écran**, la liste en 8×16 de §19 gardée :
    602 octets de pile sous les autotests (`tests.s`). Le code bas finit à `$C01C98`, sous la garde
    de §18.
11. **Preuves** : 7 scènes (`crc-*`, `bf-crc*`, `dd-*`) et 12 mutations. Sur l'image réappliquée
    `8c8caefa…`, les sept scènes et `geste-boot`, `japon-intitules`, `gs-fois`, `tests-grille`,
    `bf-tests`, `bo-ecran`, `gs-japon`, lancées seules, PASS. Preuves complètes (NR, mutations,
    catalogue) à la passe finale.

## 21. Les commutateurs 2 à 6 et 8 de la carte

Le 2026-10-27 (#1445 ; `io.s`, `c0.s`, `ecran.s`). Décisions de l'utilisateur du même jour, sur le
relevé fait d'abord en boîte noire : `measured/2026-10-27-dip-2-8.tsv`. Seuils :
`measured/2026-10-27-parcours-dip-2-8.tsv`.

1. **Commutateur 8, « Freeze » : copié du BIOS SNK et d'UniBIOS 4.0.** À ON, le jeu est suspendu dès
   l'appel suivant de SYSTEM_IO ou SYSTEM_INT1, en démo comme en partie : l'image ne bouge plus, les
   entrées ne lui parviennent plus, le watchdog est servi, et le Z80 continue (son pilote écrit
   toujours au YM2610). Remis à OFF, le jeu reprend où il était, sans RESET. Sous MAME, les deux
   références figent 297 à 299 trames sur 299 et reprennent décalées de la durée du gel (sections 2
   et 3) ; ReBIOS de même (scène `dip-gel`). SUPPOSÉ : que la référence masque les IRQ pendant le gel,
   comme nous ; seul est mesuré que l'image ne bouge plus.
2. **ÉCART VOULU : au boot, un message.** Les deux références s'arrêtent écran noir après leur test
   mémoire. ReBIOS s'arrête au même endroit de son boot, avant son écran, mais affiche DIP SWITCH 8 IS
   ON et SET IT OFF TO CONTINUE : un écran noir se prend pour une panne. Remis à OFF, le boot reprend
   (scène `dip-gel-boot`). Hors du boot, le gel passe par SYSTEM_IO et SYSTEM_INT1 : dans les écrans
   du BIOS (écran TEST, menu en jeu), ni le nôtre ni celui des références n'a été essayé.
3. **Commutateur 3, « Mahjong Panel » : copié du BIOS SNK.** À ON, BIOS_P1STATUS ($10FD94) vaut 3 et le
   panneau est balayé à chaque appel par REG_POUTPUT ($09, $12, $24) : les rangées A-G, H-N et PON à
   REACH tenues dans $10FD95, $10FD96 et $10FD97, leurs fronts dans $10FDA1, $10FDA2 et $10FDA3, sans
   répétition. La correspondance a été mesurée touche par touche, sous les trois BIOS de référence,
   avant d'écrire le code (section 8) : complète, les trois identiques. P2 reste une manette
   ordinaire. Un joystick sur ce commutateur s'y lit dans les trois rangées à la fois, comme chez SNK
   (section 4) : le front devient le niveau, une direction tenue est vue à chaque trame.
4. **Le panneau à OFF, défaut corrigé.** Notre image ne lisait aucune touche d'un panneau, à aucune
   position (section 5). Commutateur 3 à OFF, la référence le lit en joystick, les rangées A-G et H-N
   confondues : ReBIOS écrit $1B dans REG_POUTPUT avant de lire les manettes, comme elle (scène
   `dip-mj-off`). Sur un joystick, cette sortie ne change rien. Elle coûte une écriture par appel.
5. **Commutateur 2, « VS Mode » : copié d'UniBIOS et du BIOS SNK japonais.** Recopié dans $10FEF8,
   BIOS_4P_REQUESTED (« BIOS RAM locations » : $2, « dip 2 was on »). Le BIOS SNK européen ne le fait
   pas. kizuna y affiche alors un second compteur CREDIT (scène `dip-4p`). **Pas d'adaptateur 4
   joueurs** : BIOS_4P_MODE et BIOS_4P_PLUGGED restent à 0.
6. **Les commutateurs 2 et 3 sont relus à chaque remise de la main**, boot compris : la référence les
   reprend à la pièce, trois trames après (section 4 et 6 ; scènes `dip-mahjong`, `dip-4p`). SUPPOSÉ :
   aux autres remises (fin de démo, game over, SELECT), que rien n'a mesurées.
7. **Commutateurs 4, 5 et 6 : rien côté BIOS.** Ni le BIOS SNK ni UniBIOS ne change une trame d'un jeu
   pour eux (section 1) ; ils ne font que s'afficher dans leurs écrans de test (COMMUNICATION, NETWORK
   ID ; section 7). ridhero lit le 6 lui-même, sous les trois BIOS, ReBIOS compris (992 trames de
   partie sur 1001 égales à la précédente contre 836 sous SNK ; MAME : « runs in slow-mo ») : c'est le
   jeu, et notre image le sert sans rien faire.
8. **Pas de noms de commutateurs dans INPUT TEST** : il garde ses huit voyants (§17 pt 8).
9. **Les trois commutateurs agissent en mode AES aussi** : ce sont des commutateurs de la carte, et le
   mode AES de ReBIOS n'existe que sur une carte MVS (§11). SUPPOSÉ sans conséquence : un jeu en mode
   AES ne lit pas BIOS_4P_REQUESTED autrement.
10. **Le coût en cycles** : par appel de SYSTEM_IO ou SYSTEM_INT1, un test du commutateur 8, l'écriture
    de $1B et un test de BIOS_P1STATUS, environ 70 cycles. Lancées seules sur l'image du lot
    (66c240b7…), dix-neuf scènes existantes sensibles au chronométrage (boot, remises, `gs-fois`,
    `gs-mmss`, `scores-gel`, `aes-texte`, `dip-*`, `geste-*`, `ms-select`…) restent PASS. Preuves
    complètes (NR, mutations, catalogue) à la passe finale.
11. **Preuves** : 7 scènes (`dip-gel`, `dip-gel-off`, `dip-gel-boot`, `dip-mahjong`, `dip-mj-off`,
    `dip-4p`, `dip-4p-off`), chacune contre un témoin de référence, et 11 mutations écrites. Le
    panneau de mahjong s'ajoute à `bench/son.lua` (`mjA` à `mjReach`, `mjStart`).

## 22. L'autofire par jeu, dans le menu en jeu

Le 2026-10-27 (#1454 ; `autofire.s`, `io.s`, `menu.s`, `c0.s`). Décisions de l'utilisateur du même
jour : dans le menu en jeu, par jeu, gardé en backup RAM ; A, B, C et D séparément ; 15 tirs/s par
défaut, 30 et 10 en option ; la liste des jeux documentée. Aucun BIOS Neo Geo connu ne le propose.
Mesure qui le fonde : `measured/2026-10-27-autofire.tsv` (164 jeux) ; liste du joueur :
`docs/AUTOFIRE.md` ; seuils : `measured/2026-10-27-parcours-autofire.tsv`.

1. **Le turbo est dans SYSTEM_IO, entre la lecture de la manette et sa mise en RAM.** Le jeu le voit
   s'il lit BIOS_P1CURRENT et les cases qui suivent, pas s'il lit REG_P1CNT lui-même. Mesuré avec un
   prototype hors dépôt, A de P1, à 15 tirs/s : 89 jeux le voient comme un joueur qui tape, 25
   l'ont irrégulier (ils lisent aussi le registre, ou n'appellent pas SYSTEM_IO une fois par trame :
   le motif avance d'un pas par appel), 35 ne le voient pas, 15 ne sont pas mesurés. B, C, D et P2
   ne sont pas mesurés.
2. **Coût constant**, turbo actif ou non, bouton tenu ou non : ni branchement ni Scc, deux tables
   par phase (boutons relâchés, phase suivante) préparées quand le réglage change, ~112 cycles par
   manette et par appel. Quelques jeux divergent pour quelques cycles (mesuré pendant le prototype) :
   un coût qui varierait avec le réglage ferait d'un jeu réglé un autre jeu.
3. **La phase repart de 0 dès qu'aucun bouton du réglage n'est tenu** : le premier appui part à
   l'instant. Une phase par joueur ; **P1 et P2 suivent le même réglage** (choix fait seul : le jeu
   est réglé, pas le joueur ; un réglage par joueur doublerait l'écran).
4. **Panneau de mahjong (commutateur 3 à ON) : pas de turbo**, P2 compris. Le balayage du panneau
   (`_io_mahjong`) ne passe pas par le calcul ; ses touches n'ont pas A à D au même sens (scène
   `af-mahjong`).
5. **Une ligne AUTOFIRE entre les cheats et GAME SETTINGS**, à « haut » trois fois depuis RESUME :
   les chemins « bas », « bas, bas », « haut » et « haut, haut » des relevés ne bougent pas. Le cadre
   garde ses dix lignes (la ligne vide sous MEMORY EDITOR lui laisse sa place). Elle reste sous
   CHEATS/DEBUG OFF : ce n'est ni un cheat ni un outil de mise au point. §20 pt 5 écartait une ligne
   de plus pour les debug dips : celle-ci est demandée au menu en jeu, et la place choisie évite
   les deux obstacles nommés, les chemins et les cycles de la boucle.
6. **GAME SETTINGS s'ouvre aux cycles d'avant.** Une première version du choix prenait 20 cycles de
   plus à l'ouverture du menu : avec ceux du turbo, la relance de RESTART GAME avançait d'une trame
   (scènes `restart` et `gs-mmss`, RESET à 2393 et 2417 au lieu de 2394 et 2418), alors que chacun
   seul passait. Le choix passe par `subq #2` et `blt` aux mêmes cycles, et les deux scènes repassent.
7. **Le sous-écran** : BUTTON A à D (OFF, ON), RATE (10/S, 15/S, 30/S) ; droite, gauche, A comme
   GAME SETTINGS ; START revient. Le changement vaut à l'instant ; START l'enregistre. Aucun voyant
   « TURBO » en jeu (choix fait seul : l'écran du jeu n'est pas à nous, le menu en jeu ne le touche
   qu'en pause).
8. **En backup RAM, `$D001B0-$D0020F`** : la signature « AUTF », puis 23 fiches de 4 octets (NGH,
   réglage, contrôle), la plus récente d'abord ; un jeu au réglage par défaut n'a pas de fiche ; au-delà
   de 23 jeux, le moins récemment réglé perd la sienne. Zone non documentée par « Backup RAM », sans
   écriture mesurée de jeu ni de BIOS sur 21 jeux, sans lecture sur 22 ; `$D00144-$D001A3`, où la
   référence range des dates de slot, est laissé.
9. **Le jeu est le NGH de l'entrée du slot servi** (`$D00124`), écrit au boot depuis l'en-tête : le
   NGH des cheats, sans lire la cartouche (§13). Chargé à chaque remise de la main au jeu, avant
   l'attente de la ligne $1F0. **En RAM, `$10FB40-$10FB51`**, dans la zone mesurée libre du menu ; le
   prototype a relu `$10FB40-$10FB41` inchangés pendant les 158 parties mesurées.
10. **Preuves** : 4 scènes (`af-tir` contre A tapé au même motif, `af-sauve` après redémarrage,
    `af-off`, `af-mahjong`) et 7 mutations écrites. Sur l'image du lot (8a328fb6…), lancées seules
    avec vingt-et-une scènes existantes que le code touche (menu en jeu, cheats, GAME SETTINGS,
    RESTART, SYSTEM_IO, remises, commutateurs), PASS. Preuves complètes (NR, mutations, catalogue)
    à la passe finale.

## 23. Les garanties sur les défauts d'UniBIOS

Le 2026-10-27 (#1448 ; `dip.s`). Trois scènes fixent ce que ReBIOS fait là où UniBIOS a un défaut connu
(`ATTENTES.md` §2). Seuils et mesures : `measured/2026-10-27-parcours-garanties.tsv`.

1. **L'écran de boot ne lit aucun graphisme de la cartouche** (scène `boot-graphismes`). Il n'emploie
   que le plan fixe sous REG_BRDFIX, la police de la carte, et masque les sprites par LSP_1st avant de
   dessiner. Mesuré sous MAME : avec les C ROM et la S ROM d'aof remplacées par du bruit, et la VRAM et
   les palettes bruitées à la mise sous tension comme sur le matériel, aucune des trames 4 à 188 ne
   change. Le logo d'UniBIOS 4.0 se brouille dans les mêmes conditions (155 trames sur 190) : le défaut
   de la scène se reproduit sous MAME. Les trames 2 et 3, avant la première palette du BIOS, montrent le
   bruit de la mise sous tension et ne sont pas jugées : quelques trames de neige au démarrage, que tout
   BIOS a, et pas un logo.
2. **Le son du slot 2 sans cartouche au slot 1** (scène `ms-son-slot2`) : sur la MV-6F, le slot 1 est
   servi et la démo sonne à 1,21 du RMS du BIOS SNK. Sous MAME, UniBIOS 4.0 y sonne aussi (RMS 2 378) : le
   défaut d'UniBIOS sur carte multi-slot n'est pas reproduit, et la scène fixe notre comportement, rien de
   plus. Sur le matériel : non mesuré. La remise à zéro du Z80 hors du premier slot n'a pas de mutation :
   sous MAME, le Z80 privé de son reset repart et la démo sonne (RMS 2 969 contre 2 958), mesuré.
3. **L'éditeur du boot sur une entrée jamais initialisée** (scène `dip-vierge`) : un slot dont la table
   porte un autre jeu, ou qui connaît le jeu mais dont le bloc soft-DIP est quelconque. L'éditeur montre
   les défauts de la cartouche et enregistre le bloc qu'aurait une NVRAM neuve, et les blocs voisins ne
   sont pas touchés. Depuis le pt 5, ces deux entrées arrivent à l'éditeur déjà validées, et la passe
   finale y a vu survivre les mutations de `.Linutilises` et `.Lnormaliser` : la scène les juge sur mslug,
   dont le bloc, en zone banquée, échappe à `_dip_valider` (run `vierge-m`), et les deux y tombent.
4. **Corrigé : les réglages inutilisés.** La scène a trouvé que l'éditeur enregistrait tels quels les
   octets des réglages que la cartouche déclare inutilisés (un temps $FFFF, un compte $FF, un réglage
   sans choix). Ils prennent désormais à l'entrée de l'éditeur la valeur que l'inscription y écrit
   (`.Linutilises`). Aucune ligne ne les montre : le joueur ne voit rien de changé. GAME SETTINGS en
   partie n'est pas touché (§12 pt 2).
5. **Corrigé sur décision de l'utilisateur du 2026-10-27 : une entrée connue au bloc quelconque.**
   Mesuré d'abord : sans passer par l'éditeur, le bloc était servi tel quel au jeu, et la partie d'aof
   changeait entièrement à la trame 3000 (texte japonais, chronomètre à 98), quand une NVRAM de même
   histoire sans ces octets lui était égale au pixel. `_relire_dip` (`c0.s`) appelle désormais
   `_dip_valider` (`dip.s`) : les règles de l'éditeur, valeur par valeur — un réglage inutilisé prend
   ce que la cartouche déclare, une valeur hors de ses bornes le défaut de la cartouche, une valeur
   valide n'est pas touchée. Scène `dip-corrompue` : GAME_DIP et les 2 000 trames de la partie égales
   au témoin. Trois choix faits par l'agent : la correction est par valeur et non par entrée entière
   (comme l'éditeur) ; seul GAME_DIP est corrigé, le bloc de la backup RAM gardant ses octets jusqu'au
   prochain START de l'éditeur ; un bloc soft-DIP dans la zone banquée (mslug) n'est pas validé, la
   banque en place n'étant sûre qu'au premier boot. Le coût : quelques centaines de cycles à chaque
   relecture (boot d'un slot connu, rotation et sélection multi-slot), dans une attente IRQ masquées ;
   les scènes de ces chemins, lancées seules, restent PASS. Une telle entrée naît d'une backup RAM
   laissée par un autre BIOS, d'une demande 0 qui ne revient pas sous le BIOS SNK (kof98 finit la sienne
   par un reset), ou d'une pile usée.

## 24. La page du panneau de mahjong dans INPUT TEST

Le 2026-10-27 (#1448 ; `tests.s`). Décision de l'utilisateur du même jour, sur le relevé fait en boîte
noire (`measured/2026-10-27-attentes-reference.tsv`) : copier le BIOS SNK japonais et UniBIOS 4.0, sans
page 4 joueurs. La scène juge des états, sans seuil.

1. **Commutateur 3 à ON à l'ouverture d'INPUT TEST, la page MAHJONG PANEL** remplace celle des manettes :
   A à G, H à N, PON, CHI, KAN, RON, REACH, START, SELECT, chacune suivie de 0 ou de 1 (tenue), puis les
   voyants COIN, SERVICE, TEST et DIP de la page ordinaire. P2 n'y est pas, comme chez les deux
   références. Le commutateur n'est lu qu'à l'ouverture, comme elles : basculé pendant le test, la page
   reste, et les scènes `tests-dip` gardent leur page.
2. **Le panneau est balayé comme `_io_mahjong`** (§21 pt 3) : REG_POUTPUT ← $09, $12, $24, une rangée à la
   fois. La sortie reste à $24 en quittant ; le jeu pose la sienne à son premier SYSTEM_IO.
3. **La preuve sur une manette** (scène `tests-mahjong`) : une manette se lit dans les trois rangées à la
   fois (§21 pt 3), A allume E, L et REACH, B F et M, haut A, H et PON. La correspondance touche par touche
   du panneau n'est prouvée que par `dip-mahjong` (§21), dont la page reprend le balayage.
4. **CONSTATÉ, NON CORRIGÉ : les menus du BIOS ne se parcourent pas au panneau.** Sur la machine janshin
   de MAME, commutateur 3 à ON comme à OFF, A et B du panneau ne déplacent pas la ligne de l'éditeur : le
   boot n'écrit pas REG_POUTPUT avant ses écrans, et le panneau ne répond qu'à une rangée choisie. Le BIOS
   SNK japonais et UniBIOS 4.0 entrent dans HARDWARE TEST par A du panneau, commutateur 3 à ON. Sur une
   borne de mahjong, la page n'est donc atteignable qu'avec une manette branchée en P1. Corriger demande
   de choisir quelles touches du panneau mènent les menus : une décision. **Levé par §30.**

## 25. L'économiseur d'écran du JUKEBOX

Le 2026-10-27 (#1448 ; `jukebox.s`). Décision de l'utilisateur du même jour : copier UniBIOS 4.0, dans le
JUKEBOX seulement, pas sur CROSSHATCH. Seuil : `measured/2026-10-27-parcours-garanties.tsv`.

1. **Mesuré chez UniBIOS 4.0** (`measured/2026-10-27-attentes-reference.tsv`) : dans son JUKEBOX PLAYER,
   l'écran devient entièrement noir ~7 220 trames après la dernière entrée, la musique continue, une
   touche le rend ; rien de tel sur 31 min dans son menu principal, son menu TEST ni son menu en jeu.
2. **Ici, 7 100 trames sans entrée** (~2 min) : les entrées 1 des palettes 1-4, seules couleurs de cet
   écran, passent à zéro juste après le passage de la ligne $1F0. Le Z80 n'est pas touché.
3. **Toute entrée de P1 compte**, C et D compris, que le jukebox n'emploie pas ; une entrée tenue empêche
   l'écran noir.
4. **La trame du réveil ne fait rien d'autre** : ni code, ni pas, ni sortie. Une touche tenue ensuite n'a
   plus de front.
5. **REG_SHADOW n'est pas employé** : il assombrit sans éteindre, et cet écran pose déjà ses palettes.
6. **Preuve** : scène `jukebox-veille`, contre un témoin que C tapé garde allumé : 71 680 pixels noirs
   sur 71 680 à la trame 7800, le même RMS que le témoin, le code inchangé au réveil puis 21 → 22.

## 26. La copie d'une sauvegarde dans MEMORY CARD

Le 2026-10-27 (#1448 ; `gestion-carte.s`). Décision de l'utilisateur du même jour : une sauvegarde à
la fois, par un tampon en RAM, « CHANGE CARD AND PRESS A », une confirmation avant d'écraser ; pas de
COPY ALL.

1. **Mesuré chez UniBIOS 4.0** (`measured/2026-10-27-attentes-reference.tsv`) : COPY GAME DATA, A sur une
   sauvegarde, « DATA IS COPIED / CHANGE CARD AND PRESS A BUTTON », puis sur une carte qui l'a déjà « GAME
   IS ALREADY ON THIS CARD / DO YOU WANT TO DELETE OLD DATA ? ».
2. **C sur une sauvegarde** la lit par CARD $02 (blocs de sa chaîne × 64 octets), puis « CHANGE CARD AND
   PRESS A B:NO ». C n'était pris nulle part dans cet écran ; A garde DELETE, et B reste « non ».
3. **A relit la carte en place avant tout**, puis demande « OVERWRITE nnnn-ss? » si elle porte déjà le
   même NGH et la même sous-sauvegarde, sinon écrit par CARD $03. Mesuré sous MAME : retirée et remise
   entre deux trames, une carte ne change pas REG_STATUS_B, et la recherche se faisait sur la liste de
   l'ancienne. Carte absente ou protégée au A : le message, l'attente continue. B ou START renoncent.
4. **La place en RAM.** La plus grande sauvegarde d'une carte de 2 Kio (seule géométrie servie, `card.s`)
   fait 27 blocs, 1 728 octets. La RAM du gestionnaire n'en a que 256 ($10F300-$10F3FF), et celle de
   l'écran TEST ($10F464-$10FAFF) tient la copie du bloc soft-DIP de `dip.s`. Le tampon est donc la RAM de
   travail du jeu, $100000-$1006BF, dont les 1 728 octets sont mis de côté en VRAM ($0000-$035F, la carte
   des tuiles des sprites 0 à 13, masqués depuis le boot) avant la lecture et rendus après l'écriture ou le
   renoncement. Mesuré : un motif posé en $100000 et $1006BE ressort intact. Les autotests WORK RAM, eux,
   réécrivent la RAM du jeu sous $10F000 sans la rendre (lu dans `tests.s`) : non changé ici.
5. **Les cartes de plus de 2 Kio ne sont pas concernées** : REG_CRDBANK reste à 0 et CARD refuse toute
   autre géométrie ($85).
6. **Preuve** : scène `cm-copier`, la carte changée par `bench/carte-echange.lua` (retirée, puis une autre
   insérée vingt trames plus tard) : copie sur une carte vide, écrasement confirmé, renoncement ; la
   source jamais écrite.

## 27. Pas de réglage des couleurs des menus

Le 2026-10-27, décision de l'utilisateur (#1448). UniBIOS 4.0 l'annonce dans ses notes, mais aucun
réglage de couleur n'a été trouvé dans ses écrans sous MAME (menu principal, GENERAL BIOS SETTINGS,
REGION SETUP, menu en jeu, menu TEST : `measured/2026-10-27-attentes-reference.tsv`), et aucune demande
de la scène ne le cite (`ATTENTES.md` §3). Sans référence ni demande, ReBIOS ne l'a pas.

## 28. La licence : GPL-3.0-or-later, et la source publiée

**Décidé le 2026-10-28.** Sprixe BIOS est publié avec ses sources, sous **GPL-3.0-or-later**.

**Pourquoi publier.** La salle blanche devient vérifiable par n'importe qui, sources, contrats et
relevés à l'appui ; des contributions deviennent possibles.

**Pourquoi la GPL-3.0.** Une licence permissive (MIT, ISC) laisserait un tiers reprendre le code et le
refermer ; une licence non commerciale ne serait plus de l'open source. La GPL-3.0 laisse tout le monde
modifier, redistribuer et graver sur puce, à condition de fournir les sources de ce qui est distribué.

**L'incident de la table du sinus, le 2026-10-28.** Pendant la première enquête sur la dérive du
vaisseau d'alpham2 (#1458), l'agent chargé de l'enquête a relevé quatre mots de la ROM du BIOS SNK
(`$C04000`, `$C04080`, `$C04100`, `$C04180`). Il les a effacés, mais ils ont orienté son choix du codage
de 1,0. Un agent neuf, sans accès à ces relevés, a redérivé ce codage par la seule mesure du jeu sur
notre image : `$0001`, identique au témoin au pixel sur huit directions (`measured/2026-10-28-sinus.tsv`,
§18 pt 6). C'est cette valeur, et elle seule, qui est dans le code. Les fichiers de la première enquête
ne sont pas publiés.

**Ce qui le renverserait** : la découverte d'un élément dérivé d'un code tiers qu'on ne pourrait pas
retirer ni réécrire. Il serait retiré, puis réécrit en salle blanche.

## 29. Le nom : Sprixe BIOS

**Décidé le 2026-10-28 par l'utilisateur. Remplace le nom de travail de §6.** Le BIOS s'appelle
**Sprixe BIOS**, en deux mots. L'écran de boot dit « SPRIXE BIOS » et « sprixe.dev/bios » (§5).

**Pourquoi.**

- Un logiciel libre, `ReBIOS-Project/ReBIOS`, porte déjà ce nom depuis le 2026-10-16. C'est lui
  aussi un firmware BIOS : le boot legacy sur un PC UEFI. Il est antérieur à notre choix du
  2026-10-20.
- « ReBIOS » est descriptif, donc une marque faible.
- « SprixeBIOS », en un mot, se prononce mal.

**La marque.** Celle qu'on vise est **SPRIXE** seule ; elle n'est pas déposée à ce jour.

**Ce qui ne change pas.** L'historique garde « ReBIOS » : les entrées datées de ce fichier, du
`CHANGELOG.md` et du registre de `ESSAI-MATERIEL.md`, et les images déjà envoyées sous ce nom. La
signature de la backup RAM (`REBIOS`, `src/c0/reglages.s`) est un format interne qui ne s'affiche
pas : elle reste, pour que les réglages déjà enregistrés sur une carte restent valides.

**Ce qui le renverserait** : une antériorité sur SPRIXE dans ces classes, trouvée avant le dépôt.

## 30. Les menus du BIOS au panneau de mahjong

**Décidé le 2026-10-28 par l'utilisateur (#1455), sur le relevé en boîte noire du même jour**
(`measured/2026-10-28-panneau-menus-reference.tsv`). Il lève le « constaté, non corrigé » de §24 pt 4.
Le BIOS SNK japonais et UniBIOS 4.0 s'y pilotent à l'identique ; on reprend ce comportement.

1. **Commutateur 3 à ON : le panneau traduit en manette.** A, B, C, D font les boutons A, B, C, D ;
   E monte, F descend, G va à gauche, H à droite ; START reste START. Les autres touches (I à N, PON
   à REACH) ne font rien dans les menus.
2. **Commutateur 3 à OFF : le panneau lu comme un joystick**, REG_POUTPUT à $1B, comme §21 pt 4 :
   A/H haut, B/I bas, C/J gauche, D/K droite, E/L bouton A, F/M bouton B, G/N bouton C. Le bouton D
   n'a pas de touche, chez les références comme ici.
3. **Le commutateur est lu à l'ouverture du menu**, comme le BIOS SNK japonais ; UniBIOS le lit au
   boot. Basculé menu ouvert, la traduction reste celle de l'ouverture, chez les deux.
4. **Hors de ce lot** : le menu en jeu s'ouvre par START + SELECT, et le panneau n'a pas de SELECT ;
   il reste inaccessible sur une borne de mahjong. Ce que font les références en partie n'a pas été
   mesuré.

## 31. Une cartouche qui tarde : le parcours des slots refait jusqu'à la trame 270

**Décidé le 2026-10-28 en mode autonome, à confirmer par l'utilisateur**, sur le retour du matériel
du même jour (`ESSAI-MATERIEL.md`, image n°15) : le NeoSD Pro et le BackBit s'arrêtaient sur l'écran
de boot, GAME NGH 0000, un slot vide.

1. **L'écart à la référence.** Elle parcourt les slots une fois, vers la trame 276
   (`measured/2026-10-24-slot-crtfix.tsv`). Nous les parcourons dès le boot, pour que l'écran de
   boot montre l'en-tête du slot servi, et, tant qu'aucun n'est occupé, à chaque trame jusqu'à 270
   parcours (`c0.s`, ATTENTE_CARTE). Une cartouche trouvée au premier parcours n'attend rien.
2. **Pourquoi pas un parcours unique à la trame 276** : chaque boot attendrait 4,5 s de plus, et
   tout le chronométrage sur lequel reposent la matrice et les scènes bougerait.
3. **Le prix** : sans cartouche, l'écran de boot vient environ 4,5 s plus tard (scène
   sans-cartouche, HARDWARE TESTS jugé à la trame 700 au lieu de 400).
4. **SUPPOSÉ** : qu'un flash cart soit muet sur ses premières trames ; mesuré seulement sous MAME,
   où une cartouche muette sur 30 trames (`bus-flottant.lua`, BF_ABSENTE) est trouvée
   (`measured/2026-10-28-carte-lente.tsv`). **Non couvert** : un flash cart lent à côté d'une
   cartouche prompte, que le premier parcours trouve sans lui.

## 32. Jusqu'à 16 cheats par jeu, dans une fenêtre qui défile

**Décidé le 2026-10-29 avec l'utilisateur** : agrandir la base des cheats sans plafond de 4 par jeu,
toujours trouvés sous MAME, sans base tierce.

1. **16, pas plus** : un bit par cheat dans CH_ETATS, qui reste un mot contigu à GL_MASQUE. Le
   crochet garde ainsi son seul `tst.l` sans cheat ni gel, dont les cycles comptent (`cheats.s`).
2. **Une fenêtre dans le menu, pas un sous-écran** : 4 lignes de cheat au plus, qui défilent
   derrière le choix. Les chemins de touches restent ceux d'avant : le cheat k à « bas » k + 2
   fois, AUTOFIRE, GAME SETTINGS et MEMORY EDITOR à « haut » 3, 2 et 1 fois.
3. **La table au bout de la zone haute** (`build/bios.ld`, section `.cheats`) : au milieu du code,
   elle repoussait `_mess_out` hors de portée du `bsr.w` de `int1.s`.
4. **Le format des fiches ne change pas** (32 octets). Mesuré le 2026-10-29 : la zone haute finit
   à $C0B416, soit environ 83 Kio libres, de quoi loger plus de 2 000 fiches.

## Ce qui reste à trancher

- **Le verrou du save state** : existe-t-il une voie d'écriture vers une cartouche flash ? Aucun
  document public ne la décrit, et elle décide à elle seule si la fonction est possible. Les deux
  autres obstacles se mesurent ici — le temps de capture (~140 Kio lisibles, soit environ quatre
  trames de gel à estimer au cycle près) et le coût du crochet en jeu.
- **La cause des segfauts de MAME** sur `garou` et `svc`, le seul résultat de la campagne qu'on ne
  sache pas interpréter.
- ~~**Armer le watchdog du banc.**~~ **Tranché, et fait le 2026-10-11** (tâche I3) : le banc
  cosim (non publié) tient un compte à rebours de 8 trames, rechargé à chaque écriture sur `$300001` et décrémenté
  sur le front VSYNC ; à zéro, la broche de reset est tirée. Un BIOS qui oublie d'en donner se
  fait donc réinitialiser au lieu de passer le banc. Démontré des deux côtés : le harnais, qui
  n'en donne aucun, est réinitialisé aux trames 8 et 16 ; la couche 0, qui en donne, n'enregistre
  aucun reset sur 20 trames. La carte mémoire et le calendrier **sont** modélisés,
  seule la date étant figée.
