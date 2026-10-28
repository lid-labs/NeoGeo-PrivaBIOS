# La carte des menus de Sprixe BIOS

Où est chaque écran, et la touche qui y mène. Relevé dans le code le 2026-10-25 (main à `703cf222`),
AUTOFIRE ajouté le 2026-10-27 (#1454) :
les intitulés sont ceux de l'écran, la source de chaque écran est entre parenthèses. Les commandes
sont celles du joueur 1, sur front (un appui compte une fois).

```
Mise sous tension
├── Écran de boot (ecran.s) ── un bouton le passe
├── TEST tenu, ou START + SELECT tenus, ou commutateur 1 à ON ──► SOFT DIP SETTINGS (dip.s)
│     ├── REGION
│     ├── les réglages de la cartouche (selon le jeu)
│     ├── CABINET SETTINGS ──► FREE PLAY, NO CONTINUE, DEMO SOUND, CHEATS/DEBUG (reglages.s), DEBUG DIPS (debug.s)
│     ├── SCORE RESET
│     ├── MEMORY CARD ──► liste des sauvegardes, FORMAT CARD, EXIT (gestion-carte.s)
│     ├── MODE
│     ├── HARDWARE TESTS ──► WORK RAM … CROSSHATCH, CARTRIDGE CRC (crc.s), EXIT (tests.s)
│     ├── JUKEBOX (jukebox.s)
│     └── RESET TO DEFAULTS
└── Le jeu
      ├── TEST, ou START + SELECT, tenus ~1/3 s en partie ──► IN-GAME MENU (menu.s)
      │     ├── RESUME
      │     ├── RESTART GAME
      │     ├── les cheats du jeu, ON/OFF (cheats.s)
      │     ├── AUTOFIRE (autofire.s)
      │     ├── GAME SETTINGS (reglages-jeu.s)
      │     └── MEMORY EDITOR (memoire.s)
      ├── SELECT hors partie, multi-slot ──► jeu suivant (P1) ou précédent (P2)
      └── une exception du 68000 ──► SYSTEM CRASH (plantage.s)
```

## L'écran TEST : SOFT DIP SETTINGS

**Y entrer** : tenir le bouton TEST de la carte à la mise sous tension, jusqu'à l'écran. Il s'ouvre
après l'écran de boot, avant le jeu. Sans bouton TEST (une MVS consolisée), deux autres chemins :

- tenir START et SELECT de P1 ensemble dès la mise sous tension : ils passent l'écran de boot et
  ouvrent celui-ci. Refusé si A, B, C et D sont tenus tous les quatre en même temps, ce que fait
  l'adaptateur BlueRetro à sa mise en route ; avec un, deux ou trois d'entre eux, le geste marche ;
- mettre le commutateur 1 de la carte (« Setting Mode ») à ON : l'écran s'ouvre à chaque mise sous
  tension tant qu'il y reste. START en sort quand même : resté à ON, DIP SWITCH 1 IS ON s'affiche
  environ trois secondes (ou jusqu'à ce qu'on le rebascule), puis le jeu ; rebasculé à OFF pendant
  l'écran, le jeu tout de suite. Sous MAME, le BIOS SNK et UniBIOS refusent d'en sortir tant qu'il
  est à ON (« DIP-SW 1 OFF !! »).

**Commandes** : HAUT/BAS choisit la ligne, en boucle ; GAUCHE/DROITE change la valeur ; A passe à la
valeur suivante et repart au début après la dernière (pour une borne à un bouton) ; START
enregistre et lance le jeu.

**Le plus court chemin : « haut » depuis la première ligne**, parce que la liste boucle et que le
nombre de réglages de la cartouche varie d'un jeu à l'autre. Ces chemins ne dépendent pas du jeu :

| « haut » × | Ligne | Ce qu'elle fait |
|---|---|---|
| 0 | REGION | JAPAN, USA, EUROPE ; changée, START relance la machine dans cette région |
| 1 | RESET TO DEFAULTS | GAUCHE, DROITE ou A remet les réglages de la cartouche à leurs défauts |
| 2 | JUKEBOX | GAUCHE, DROITE ou A l'ouvre |
| 3 | HARDWARE TESTS | GAUCHE, DROITE ou A l'ouvre |
| 4 | MODE | MVS, AES ; changé, START relance la machine dans ce mode |
| 5 | MEMORY CARD | GAUCHE, DROITE ou A ouvre le gestionnaire de carte |
| 6 | SCORE RESET | ON, OFF ; à OFF, les jeux qui effacent leurs records quand la date change les gardent |
| 7 | CABINET SETTINGS | GAUCHE, DROITE ou A ouvre les réglages de la borne |

Les réglages de la cartouche commencent à « bas » une fois. REGION, MODE, SCORE RESET et CABINET
SETTINGS ne sont pas des réglages de la cartouche : RESET TO DEFAULTS ne les touche pas.

En région JAPAN, quand la cartouche donne ses intitulés en japonais, la liste s'écrit en grands
caractères, comme le BIOS SNK japonais : deux rangées par ligne, dix lignes à l'écran, et la liste
défile avec la ligne choisie. Les commandes et les chemins « haut » ne changent pas
(`DECISIONS.md` §19).

### CABINET SETTINGS

Cinq lignes ; HAUT/BAS choisit, GAUCHE, DROITE ou A change la valeur. START revient à la liste, et
c'est le START de la liste qui enregistre, sans relance.

| Ligne | Valeurs | Effet |
|---|---|---|
| FREE PLAY | OFF, ON, DIP | START lance une partie sans pièce, P2 compris. DIP : le commutateur 7 de la carte est à ON, ce qui suffit ; la ligne ne change plus |
| NO CONTINUE | OFF, ON | START est refusé pendant le décompte du continue |
| DEMO SOUND | ON, OFF | À OFF, les démos sont muettes ; titre et partie gardent le son |
| CHEATS/DEBUG | ON, OFF | À OFF, le menu en jeu n'offre plus ni cheats ni MEMORY EDITOR |
| DEBUG DIPS | le masque en hexadécimal, ou OFF | GAUCHE, DROITE ou A ouvre l'écran des debug dips ; OFF sous CHEATS/DEBUG OFF, et la ligne ne s'ouvre pas |

En mode AES, les trois premières affichent MVS ONLY et sont sans effet ; CHEATS/DEBUG vaut dans les
deux modes. Le commutateur 7 de la carte (« Free Play ») met la borne en free play comme FREE PLAY ON,
et il est relu machine allumée. Détail : `DECISIONS.md` §15 et §16.

**DEBUG DIPS** : deux rangées de huit bits, DIP 1 et DIP 2. GAUCHE/DROITE choisit le bit, HAUT/BAS la
rangée, A le bascule ; START revient. Les bits choisis sont mis à 1 dans les deux octets que le jeu
lit pour ses outils de mise au point, à chaque trame, en démo comme en partie ; ils ne sont jamais
enregistrés et s'effacent à la mise hors tension (`DECISIONS.md` §20).

### MEMORY CARD

HAUT/BAS choisit une sauvegarde (NGH, sous-numéro, blocs, nom du jeu), FORMAT CARD ou EXIT. A sur
une sauvegarde l'efface, A sur FORMAT CARD formate la carte ; les deux demandent confirmation (A oui,
B non). C sur une sauvegarde la copie : CHANGE CARD AND PRESS A, on change de carte, A l'écrit ; si la
nouvelle carte a déjà cette sauvegarde, OVERWRITE ? demande confirmation. B renonce. START revient. Sans carte : NO CARD ; carte vierge : CARD NOT FORMATTED ; carte protégée :
WRITE PROTECTED.

### HARDWARE TESTS

HAUT/BAS choisit, en boucle depuis WORK RAM, A lance, START revient.

| « haut » × | Test | Ce qu'il montre |
|---|---|---|
| — | WORK RAM, PALETTE RAM, VRAM, BACKUP RAM | OK, ou FAIL avec l'adresse, la valeur écrite et la valeur lue |
| — | INPUT TEST (« bas » × 4) | l'état des entrées ; START tenu 1 s pour sortir. Commutateur 3 de la carte à ON à l'ouverture : la page du panneau de mahjong, 0 ou 1 par touche (A à N, PON à REACH, START, SELECT) |
| — | COLOR BARS (« bas » × 5) | des barres de couleur ; A change de page |
| 3 | CROSSHATCH | une mire de réglage |
| 2 | CARTRIDGE CRC | le CRC32 de la P-ROM de la cartouche, FIXED puis BANKS, à comparer à celui du romset ; START arrête le calcul (`DECISIONS.md` §20) |
| 1 | EXIT | retour à la liste |

### JUKEBOX

HAUT/BAS change le code de 1, GAUCHE/DROITE de 16, A joue, B arrête, START sort. Les codes 01 à 03
sont sautés. Si rien ne joue, l'écran conseille le code 07 (PLAY 07 FIRST IF SILENT). Après environ
deux minutes sans toucher à rien, l'écran devient noir et la musique continue ; une touche le rallume
sans rien faire d'autre (`DECISIONS.md` §25).

## Le menu en jeu : IN-GAME MENU

**Y entrer** : en partie (pas en démo), tenir TEST environ 1/3 s, ou START et SELECT de P1 ensemble
(sans bouton TEST), sauf avec A, B, C et D tenus tous les quatre (l'adaptateur BlueRetro, comme au
boot). Le jeu se met en pause, la musique continue.

**Commandes** : HAUT/BAS choisit, A ou START valide. Sur une ligne de cheat, A ou START bascule ON/OFF
et le menu reste ouvert.

| Depuis RESUME | Ligne | Ce qu'elle fait |
|---|---|---|
| — | RESUME | rend le jeu là où il était |
| « bas » × 1 | RESTART GAME | relance la machine |
| « bas » × 2 et suivants | un cheat par ligne | seulement pour les 35 jeux de la table (`measured/2026-10-25-cheats-table.tsv`) |
| « haut » × 3 | AUTOFIRE | le tir automatique de A, B, C et D, gardé pour ce jeu |
| « haut » × 2 | GAME SETTINGS | les soft-DIP du jeu, en partie |
| « haut » × 1 | MEMORY EDITOR | la RAM du jeu |

**Sous CHEATS/DEBUG à OFF**, les cheats et MEMORY EDITOR disparaissent : « haut » × 1 mène alors à
GAME SETTINGS, « haut » × 2 à AUTOFIRE.

### AUTOFIRE

Quatre lignes BUTTON A à BUTTON D, chacune OFF ou ON, puis RATE : 15/S par défaut, 30/S ou 10/S
(tirs par seconde). HAUT/BAS choisit ; DROITE met ON (ou la cadence au-dessus), GAUCHE met OFF (ou
la cadence au-dessous), A bascule (ou passe à la cadence suivante) ; START revient.

Un bouton à ON, tenu, tire tout seul : le jeu le voit appuyé puis relâché, au rythme choisi, et le
premier appui part tout de suite. Le réglage vaut pour les joueurs 1 et 2, et il est gardé pour ce
jeu, même machine éteinte : chaque jeu a le sien, et un jeu qu'on n'a jamais réglé n'en a pas. Il
n'a d'effet que sur les jeux qui lisent la manette par le BIOS : la liste, jeu par jeu, est dans
`AUTOFIRE.md`. Coupé avec le panneau de mahjong (commutateur 3 à ON). Détail : `DECISIONS.md` §22.

### GAME SETTINGS

Les réglages de la cartouche, puis RESET TO DEFAULTS et RESTART GAME ; ni REGION ni MODE. En région
JAPAN, les intitulés sont ceux que la cartouche donne pour les USA, quand ses deux listes de réglages
ont la même forme ; sinon ils restent en blanc (`DECISIONS.md` §19).
HAUT/BAS choisit, GAUCHE, DROITE ou A change, START revient. Certains jeux ne relisent un réglage
qu'au début d'un round ou d'une partie (SOME CHANGES NEED RESTART) : RESTART GAME enregistre et
relance.

### MEMORY EDITOR

| Écran | Commandes |
|---|---|
| La page | HAUT/BAS change de ligne (8 octets), GAUCHE/DROITE d'octet ; B tenu + HAUT/BAS change de page ; A édite, C va à une adresse, D gèle l'octet ou le dégèle ; START revient |
| SET VALUE | HAUT/BAS change de 1, GAUCHE/DROITE de $10 ; A écrit, B annule |
| GOTO ADDRESS | GAUCHE/DROITE choisit le chiffre, HAUT/BAS le change ; A valide, B annule |

La fenêtre couvre la RAM de travail, $100000-$10FFFF, en boucle. La zone du BIOS
($10F300-$10FFFF) s'affiche en READ ONLY : A et D n'y font rien. Les octets gelés sont listés en bas
(FROZEN) ; le moteur les réécrit à chaque trame.

## Les autres écrans

- **L'écran de boot** : SYSTEM, REGION, CLOCK, CARD, GAME NGH, puis PRESS A BUTTON TO SKIP ; un
  bouton passe l'attente.
- **Le commutateur 8 de la carte (« Freeze ») à ON au boot** : avant l'écran de boot, DIP SWITCH 8 IS
  ON et SET IT OFF TO CONTINUE, jusqu'à ce qu'on le rebascule ; le BIOS SNK reste écran noir. En jeu,
  il fige la partie sans rien afficher, comme le BIOS SNK (`DECISIONS.md` §21).
- **SELECT sur une carte multi-slot** : SELECT P1 passe au jeu suivant, SELECT P2 au précédent ;
  les conditions sont dans `io.s`.
- **SYSTEM CRASH** : l'exception ou ses causes possibles, les registres et le NGH du jeu ; START relance.
- **Sans cartouche** : la machine ouvre HARDWARE TESTS au lieu de redémarrer en boucle
  (`DECISIONS.md` §13).
