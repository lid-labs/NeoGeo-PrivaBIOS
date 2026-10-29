| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| LE MENU EN JEU — ouvert pendant la partie par le bouton TEST de la carte tenu, il met le
| jeu en pause puis le rend tel qu'il était. TEST ouvre les menus du BIOS (`dip.s` au boot).
|
| AUCUN ORACLE : ni le BIOS de référence ni un BIOS tiers ne sont lus. La remise est
| « Couche 3 → le menu en jeu, le 2026-10-21 » (`docs/RELECTURE-CONTRATS.md`).
| « mesuré » : un relevé nommé (jig `bench/menu.lua` et sondes lua du 2026-10-21, MAME
| 0.286, -bios euro, notre image, 22 jeux du corpus, ~3 600 trames chacun, pièce et START
| planifiés comme `bios-probe.lua` ; relevés non versionnés, remis à la session
| principale) ; « lu dans » : une page du NeoGeo Development Wiki ; « SUPPOSÉ » : ni l'un
| ni l'autre.
|
| LE CROCHET. `_menu_en_jeu`, appelé par `jsr` depuis SYSTEM_IO (`io.s`) juste après
| `_io_commun`, à chaque appel. Sans le geste : quelques instructions, aucun registre
| touché. Il commence par le moteur des cheats et des gels (`cheats.s`), qui sans cheat ni
| gel actif n'est que deux tests.
| MESURÉ : les 22 jeux appellent SYSTEM_IO depuis leur gestionnaire de vblank (SR au
| moment de l'appel : IPL 1, ou 7 pour kof94, kof98, samsho2 ; trally seul a des appels
| IPL 0, hors partie). Le menu s'ouvre donc DANS l'interruption du jeu, et son programme
| principal est suspendu quelque part — y compris au milieu d'une file d'écritures VRAM
| (voir L'ADRESSE VRAM).
|
| LE GESTE. TEST tenu SEUIL appels de suite, en partie (BIOS_USER_MODE $10FDAF = 2, « BIOS
| RAM locations »). Après la fermeture, il faut tout relâcher avant de recompter. SEUIL :
| choix (~1/3 s). TEST : REG_SYSTYPE ($300081) bit 7, actif bas (mesuré dans `dip.s`).
| Mesuré (taps de lecture, 22 jeux, 3 600 trames) : seul ridhero lit $300081 en partie
| (3 199 lectures) ; TEST tenu, sa RAM diffère d'un témoin d'un octet ($100152), et aucun
| autre jeu ne diverge (garou, mesuré sous le BIOS SNK, ne lit pas $300081). START + SELECT,
| le premier geste, avait été écarté : sous MAME 0.286 les sets d'une cartouche n'ont aucun champ
| SELECT. REPRIS le 2026-10-25 EN PLUS DE TEST, pour une MVS consolisée, qui n'a pas de bouton
| TEST et dont les manettes ont START et SELECT : START et SELECT de P1 tenus ensemble SEUIL
| appels de suite (REG_STATUS_B $380000 bits 0 et 1, actifs bas). SELECT parce qu'aucun jeu ne le
| voit sur MVS (« BIOS RAM locations » : « On MVS the select bits are always read as 0 ») ; mesuré
| (`measured/2026-10-25-dip-free-play.tsv`, section 5, BIOS SNK, MV-6F) : SELECT tenu une seconde
| en partie ne change aucune image sur 154 des 157 jeux du catalogue joués ; kof94 et lastbld2 n'y
| sont décalés que d'une trame, pbobblen ne se répète pas d'un run à l'autre. Le BIOS ne le lit
| qu'au titre avec un crédit (`io.s`, `_io_select`), le geste qu'en partie. START, lui, part au
| jeu comme d'habitude (un jeu qui met en pause sur START la verra sous le menu). Au repos, $380000 vaut $FF sous
| MAME sur toutes les machines MVS ; SUPPOSÉ sur le matériel. LES CYCLES : sans TEST, deux
| `btst` et un branchement de plus par appel de SYSTEM_IO quand START n'est pas tenu (+30) ;
| mesuré sans effet sur le parcours et sur la matrice du catalogue, le 2026-10-25.
| L'ADAPTATEUR, depuis le 2026-10-27 : START + SELECT ne comptent pas si A, B, C et D de P1
| sont tenus TOUS LES QUATRE (REG_P1CNT $300000 bits 4-7, actifs bas) ; le compte repart alors de
| zéro. Un, deux ou trois d'entre eux tenus, le geste compte comme seul. CONSTATÉ sur le matériel
| par le testeur le 2026-10-26 (image n°14, `docs/ESSAI-MATERIEL.md`) : l'adaptateur BlueRetro
| tient environ une seconde L/R, A, B, C, D, START et SELECT à sa mise en route, et branché en
| partie ouvrait le menu. « A-D relâchés » est écarté : un joueur qui frôle A verrait le geste
| refusé. TEST n'en dépend pas. $300000 n'est lu qu'une fois START et SELECT vus tenus : le geste
| qui compte coûte 30 cycles de plus par appel, les autres chemins rien. DECISIONS §17 pt 5.
|
| LA SAUVEGARDE, $10F4C0-$10F7EB (le cadre et la ligne en dessin) et $10F800-$10FAFF (le
| reste, et la pile). MESURÉ libre : des taps d'écriture sur $10F300-$10FFFF,
| 22 jeux, ne montrent aucune écriture de jeu entre $10F4B4 et $10FBFF (nam1975 écrit
| $10F300-$10F4B3, quatre jeux $10FC00-$10FC69) ; notre BIOS n'y écrit que le vidage du
| boot (`c0.s`). Le compteur du geste y est écrit à chaque appel.
|
| CE QUE LE MENU TOUCHE, ET COMMENT IL LE REND :
|   - SR (IRQ masquées, $2700) et les 15 registres : sauvés, rendus. La pile du jeu ne
|     reçoit que l'adresse de retour du `jsr` ; le menu court sur sa pile, MN_PILE ;
|   - REG_VRAMMOD : relisible (« Memory mapped registers » : « Reads VRAM address
|     modulo ») ; sauvé, rendu ;
|   - L'ADRESSE VRAM : non relisible (même page : REG_VRAMADDR se lit comme REG_VRAMRW,
|     « address doesn't change »). Or le programme du jeu peut être au milieu d'une file
|     d'écritures : MESURÉ, 9 jeux sur 22 écrivent REG_VRAMRW, au retour de SYSTEM_IO,
|     sans reposer d'adresse (neomrdo 82 fois en 3 600 trames, trally 93, lbowling 8…).
|     On la RETROUVE donc : y écrire deux paires sondes à la place de quatre mots lus,
|     balayer $0000-$87FF pour les y voir, remettre les mots lus, et reposer cette adresse
|     en sortie (`.Lsonder`). Un balayage, ~0,15 s. SUPPOSÉ, les bords : A ≥ $8800 (un
|     miroir de $8000-$87FF, « VRAM ») se retrouve à son adresse canonique, reposée telle
|     quelle ; A dans $87FD-$87FF, les sondes passent le bord du balayage et l'échec suit. Mesuré (jig,
|     11 fermetures sur aof, mslug, kof98, neomrdo) : retrouvée à chaque fois, égale à celle
|     que MAME tient (item `m_vram_offset`), VRAM identique à l'octet. SUPPOSÉ : que
|     la lecture de REG_VRAMRW rende le mot de l'adresse courante même juste après une
|     écriture de données (la page ne le dit qu'après une écriture d'adresse) ;
|   - le plan fixe : seules les cases du cadre (20 × 10 sans cheat, 28 × (10 + V) avec V
|     lignes de cheat, 28 × 14 pour les sous-écrans, 392 au plus), lues par
|     REG_VRAMRW avant d'être écrites, rendues après ;
|   - trois palettes de la banque en place, celles que le plan fixe n'emploie pas
|     (`.Lchoisir_palettes` ; à défaut, des employées, le cas de kof98 au relevé) : lues, rendues (« Palettes » : « can be
|     read and written at full speed at any time »). La banque n'est pas changée : la page
|     en dit « one usable at a time », donc celle que le CPU voit est celle du jeu ; rien à
|     déduire. Écrites juste après le passage de la ligne $1F0 (la même page : écrire en
|     affichage fait de la neige). Pendant la pause, les sprites du jeu qui usent de ces
|     palettes prennent nos couleurs ;
|   - le Z80 : RIEN. Ni $01, ni REG_BRDFIX, ni REG_CRTFIX, ni $03 : le pilote du jeu joue
|     pendant la pause, comme sous UniBIOS (`measured/2026-10-23-unibios-menu-en-jeu.tsv`).
|     Le $03 d'avant le relançait sans le rendre : en pleine partie, plus aucun key-on FM ni
|     ADPCM-B, aof muet jusqu'au prochain $03 du jeu, mslug 160 s au moins ; le $03 seul, sans
|     menu, fait de même, et rejouer les commandes du jeu ne répare pas mslug
|     (`measured/2026-10-23-menu-en-jeu-son.tsv`) ;
|   - le plan fixe reste sur la S ROM de la cartouche : le HUD du jeu hors du cadre garde ses
|     tuiles. Le texte y est dans SA police : 0-9, A-Z, espace, « : - / . » identiques au SFIX
|     sur 20 jeux sur 22, trally lisible (`measured/2026-10-21-police-cartouche.tsv`) ; « > »
|     lisible à l'œil sur mslug, aof, kof98, pas mesuré. kof2003 : sa S ROM n'a pas de police,
|     le texte du menu y est invisible (déduit, pas mesuré) ;
|   - les IRQ en attente : à la sortie on attend la ligne où le menu s'est ouvert
|     (REG_LSPCMODE, `.Lsync`), puis on acquitte (REG_IRQACK, « 68k interrupts » : bit 2
|     vblank, bit 1 timer) les interruptions nées pendant la pause : toujours le vblank —
|     celui de l'appel est en cours de service, un autre en attente est périmé —, le timer
|     si l'appel le laissait passer (IPL < 2). SUPPOSÉ : qu'un timer en attente sous un IPL
|     ≥ 2 au moment de l'appel ne soit pas acquitté à tort en le laissant.
| NON RENDUS : le compteur d'auto-animation et le timer du LSPC, qui courent pendant la pause,
| et la musique, qui continue. Après la reprise, le son est celui du témoin (mesuré, key-on
| FM sous menu / témoin : mslug 212/218, aof 363/361, kof98 78/87 ;
| `measured/2026-10-23-menu-en-jeu-son.tsv`).
|
| CHEATS/DEBUG OFF (CABINET SETTINGS de `dip.s`, bit 3 de BORNE_RAM, le 2026-10-25) : ni ligne de
| cheat (`_cheats_trouver` ne donne plus d'entrée) ni MEMORY EDITOR — sa ligne reste en blanc, et le
| dernier choix est GAME SETTINGS : « haut » depuis RESUME y mène. Le cadre ne change pas de taille.
| LES CHOIX : RESUME, RESTART GAME, puis une ligne par cheat du jeu (`cheats.s`), son nom
| et ON / OFF ; A ou START sur une ligne de cheat bascule son bit dans CH_ETATS et le menu
| reste ouvert. LA FENÊTRE, le 2026-10-29 : MN_VIS lignes de cheat au plus (V), et les N cheats
| du jeu, jusqu'à CH_MAX, y défilent derrière le choix (`.Lfenetre`) ; au-delà de MN_VIS, la
| ligne sous le titre dit lesquels sont montrés (« CHEATS 5-8/12 »). Les choix ne changent pas :
| le cheat k est toujours à « bas » k + 2 fois depuis RESUME, et les lignes d'après à N près.
| Puis GAME SETTINGS (`reglages-jeu.s`) et MEMORY EDITOR (`memoire.s`), le
| 2026-10-23, toujours là, APRÈS les cheats : les chemins de touches des relevés d'avant
| (RESTART à « bas », le premier cheat à « bas, bas ») restent ; depuis RESUME, « haut » mène
| à MEMORY EDITOR, « haut, haut » à GAME SETTINGS, quel que soit le jeu. Le cadre sans cheat
| n'est donc plus celui d'avant les cheats : deux lignes de plus.
| AUTOFIRE (`autofire.s`, le 2026-10-27, DECISIONS §22) : une ligne de plus, ENTRE LES CHEATS
| ET GAME SETTINGS, à « haut » trois fois depuis RESUME (deux sous CHEATS/DEBUG OFF) : « bas »,
| « bas, bas » et « haut », « haut, haut » mènent où ils menaient. Le cadre ne grandit pas : la ligne
| vide sous MEMORY EDITOR lui laisse sa place, et la ligne d'aide reste où elle était. La boucle
| garde ses cycles, et GAME SETTINGS s'ouvre aux mêmes cycles qu'avant (`reglages-jeu.s`, LES
| CYCLES ; voir le choix, `.Lboucle`). AUTOFIRE reste sous CHEATS/DEBUG OFF.
| LES SOUS-ÉCRANS (GAME SETTINGS, MEMORY EDITOR, AUTOFIRE) prennent un cadre fixe de SOUS_NCOL ×
| SOUS_NLIG cases, sauvé et rendu comme celui du menu (`_mn_sous_ouvrir`, `_mn_sous_fermer`) :
| le cadre du menu est rendu d'abord, le leur sauvé ensuite, puis l'inverse au retour. Mêmes
| palettes, même boucle d'une trame par tour, mêmes boutons (`_mn_entrees`).
| RESTART GAME : la relance par le watchdog de `dip.s` (mesurée), IRQ masquées.
| L'affichage comme `dip.s` : glyphes 8×8 = tuile ASCII, trait à l'index 1 ; la tuile $020
| est pleine de l'index 2, sous la S ROM aussi, 22 jeux sur 22, et les glyphes n'y ont que
| les index 1 et 2 (`measured/2026-10-23-menu-en-jeu-plan-fixe.tsv`), d'où un cadre
| opaque : les entrées 2 à 15 portent la couleur du cadre.
| ==================================================================================

        .section .haut, "ax"
        .global _menu_en_jeu
        .global _mn_sync, _mn_entrees, _mn_ligne, _mn_vider, _mn_texte
        .global _mn_sous_ouvrir, _mn_relancer
        .global MN_BUF, MN_COUL, MN_REP

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    IRQACK,   0x3C000C
        .equ    WATCHDOG, 0x300001
        .equ    P1CNT,    0x300000
        .equ    SYSTYPE,  0x300081
        .equ    STATUS_B, 0x380000
        .equ    PALETTES, 0x400000
        .equ    BORNE_RAM, 0x10FB20     | bit 3 : CHEATS/DEBUG OFF (`reglages.s`)

        .equ    SEUIL,    20            | appels de SYSTEM_IO, geste tenu
        .equ    S1,       0x5AC3        | la paire sonde de `.Lsonder`, choix arbitraire
        .equ    S2,       0xA53C
        .equ    T1,       0x3C96        | la seconde paire, choix arbitraire
        .equ    T2,       0xC369

        | La zone, mesurée libre (voir l'en-tête).
        .equ    MN_COMPTE, 0x10F800     | .w geste tenu ; $FFFF : attendre le relâchement
        .equ    MN_SR,    0x10F802      | .w SR de l'appel
        .equ    MN_SP,    0x10F804      | .l pile du jeu
        .equ    MN_REGS,  0x10F808      | 15 .l, D0-D7 puis A0-A6
        .equ    MN_MOD,   0x10F844      | .w REG_VRAMMOD
        .equ    MN_LIGNE, 0x10F846      | .w ligne d'affichage à l'ouverture
        .equ    MN_ADR,   0x10F848      | .w adresse VRAM retrouvée
        .equ    MN_ADROK, 0x10F84A      | .w 1 si retrouvée
        .equ    MN_R0,    0x10F84C      | .w le mot sous l'adresse courante
        .equ    MN_R1,    0x10F84E      | .w les trois mots suivants
        .equ    MN_R2,    0x10F850
        .equ    MN_R3,    0x10F852
        .equ    MN_ADR2,  0x10F854      | .w A selon la seconde paire sonde
        .equ    MN_NCH,   0x10F856      | .w cheats du jeu (`cheats.s`), 0 à CH_MAX
        .equ    MN_NCOL,  0x10F858      | .w la mise en page du cadre (`.Lmise_en_page`)
        .equ    MN_NLIG,  0x10F85A
        .equ    MN_CASE0, 0x10F85C      | .w la case en haut à gauche
        .equ    MN_CURS,  0x10F85E      | .w la colonne du curseur
        .equ    MN_PAD,   0x10F860      | .w la marge des lignes fixes
        | .w le dernier choix : 3 + N, ou 2 sous CHEATS/DEBUG OFF (GAME SETTINGS), posé par
        | `.Lmise_en_page`. Lu par la boucle en autant de cycles que l'ancien calcul (MN_NCH + 3) :
        | mesuré, deux tests de plus par tour et par ligne avançaient d'une trame la relance de
        | RESTART GAME depuis GAME SETTINGS sur ncombat (scène gs-mmss, RESET à 2417 au lieu de 2418).
        .equ    MN_DERNIER, 0x10F862
        .equ    MN_NVIS,  0x10F864      | .w lignes de cheat du cadre : N, au plus MN_VIS
        .equ    MN_HAUT,  0x10F866      | .w le premier cheat montré (`.Lfenetre`)
        .equ    MN_CHOIX, 0x10F870      | .w ligne choisie : 0 RESUME, 1 RESTART, 2… les cheats, puis
                                        | AUTOFIRE (2 + N), GAME SETTINGS (3 + N), MEMORY EDITOR (4 + N)
        .equ    MN_PALS,  0x10F872      | 3 .w : les palettes prises (titre, choisi, texte)
        .equ    MN_USAGE, 0x10F878      | .w un bit par palette vue sur le plan fixe
        .equ    MN_PAL,   0x10F880      | 3 palettes, 96 octets
        .equ    MN_COUL,  0x10F8E0      | 28 octets : le rôle de chaque case de MN_BUF
                                        | (0 texte, 1 titre, 2 choisi), pour `_mn_ligne`
        .equ    MN_REP,   0x10F8FC      | .w la répétition d'une direction tenue (`memoire.s`)
        | $10F900-$10F9DF : les états de `reglages-jeu.s` et de `memoire.s`, sous la pile.
        | Le cadre sauvé, 392 .w au plus (28 × 14), colonne par colonne, et la ligne en cours de
        | dessin : sous $10F800, dans la même zone mesurée libre ($10F4B4-$10FBFF, voir l'en-tête).
        .equ    MN_FIX,   0x10F4C0      | → $10F7CF
        .equ    MN_BUF,   0x10F7D0      | 28 octets → $10F7EB
        .equ    MN_PILE,  0x10FB00      | sommet de la pile du menu (descend vers $10FA20)
        | $10FB00 et au-delà : les états des cheats et des gels (`cheats.s`), et de l'éditeur
        | mémoire (`memoire.s`).

        | Le cadre (« Fix layer » : $7000 + 32 × colonne + ligne ; lignes 2-29 et colonnes 1-38
        | visibles, comme `dip.s`). Sans cheat : colonnes 10-29, lignes 11-20. Avec V lignes de cheat
        | (MN_NVIS) : 28 colonnes (6-33), 10 + V lignes à partir de 11 − V/2 — le nom de 16 caractères et son
        | état ne tiennent pas dans 20.
        .equ    COL0,     10
        .equ    NCOL,     20
        .equ    LIG0,     11
        .equ    NLIG,     10
        .equ    COL0_C,   6
        .equ    NCOL_C,   28
        .equ    PAD_C,    4             | lignes fixes centrées dans les 28 colonnes
        | Le cadre des sous-écrans : 28 × 14 = 392 cases, ce que MN_FIX tient ; colonnes 6-33,
        | lignes 9-22. 28 × (10 + MN_VIS) y tient aussi, d'où MN_VIS = 4 ; les autres cheats défilent.
        .equ    MN_VIS,   4
        .equ    SOUS_NCOL, 28
        .equ    SOUS_NLIG, 14
        .equ    SOUS_CASE0, 0x7000 + 32 * 6 + 9
        .equ    NPAL,     3             | titre, ligne choisie, texte

        | Les couleurs, $0RGB (« Colors »). Choix d'aspect.
        .equ    C_CADRE,  0x0124

| ----------------------------------------------------------------------------------
| LE CROCHET. Ne détruit aucun registre, seulement les codes de condition.
_menu_en_jeu:
        bsr     _cheats_appliquer       | les cheats actifs (`cheats.s`) ; aucun : un test
        btst    #7, SYSTYPE             | TEST tenu : bit 7 à 0
        bne.s   4f                      | relâché : le geste sans bouton TEST, plus bas
3:      cmpi.b  #2, 0x10FDAF            | en partie seulement
        bne.s   1f
        tst.w   MN_COMPTE
        bmi.s   2f                      | fermé il y a peu : on attend le relâchement
        addq.w  #1, MN_COMPTE
        cmpi.w  #SEUIL, MN_COMPTE
        bcc.s   _menu_ouvrir
2:      rts
| START ET SELECT DE P1 TENUS (voir l'en-tête), à part : le chemin de TEST tenu garde ses cycles
| d'avant au cycle près. Mesuré : deux cycles de plus sur ce chemin (un `beq` pris au lieu d'un
| `bne` non pris) avançaient d'une trame le RESET de RESTART GAME de la scène gs-fois.
4:      btst    #0, STATUS_B
        bne.s   1f
        btst    #1, STATUS_B
        beq.s   5f
1:      clr.w   MN_COMPTE
        rts
| A, B, C ET D DE P1 TENUS TOUS LES QUATRE (REG_P1CNT bits 4-7 à 0) : l'adaptateur BlueRetro, pas
| le geste (voir l'en-tête) ; le compte repart de zéro, comme START ou SELECT relâché. Une seule
| lecture, à part : START non tenu, ou SELECT non tenu, garde ses cycles d'avant.
5:      cmpi.b  #0x10, P1CNT
        bcc.s   3b                      | au moins un des quatre relâché : le geste
        bra.s   1b                      | les quatre tenus : refusé

| ----------------------------------------------------------------------------------
| L'OUVERTURE. SR d'abord : c'est la première écriture du menu (le jig y prend son relevé
| « avant »).
_menu_ouvrir:
        move.w  %sr, MN_SR
        move.w  #0x2700, %sr
        movem.l %d0-%d7/%a0-%a6, MN_REGS
        move.l  %sp, MN_SP
        lea     MN_PILE, %sp
        move.b  %d0, WATCHDOG
        | LE COMMUTATEUR 3 lu ici, à l'ouverture, et pas après : P1 dans le menu et ses sous-écrans
        | (`panneau.s`, DECISIONS §30).
        jsr     _panneau_verrou
        move.w  LSPCMODE, %d0           | la ligne : bits 15-7 (`.Lsync`)
        lsr.w   #7, %d0
        move.w  %d0, MN_LIGNE
        move.w  VRAMMOD, MN_MOD
        clr.w   MN_CHOIX
        clr.w   MN_HAUT
        bsr     .Lsonder
        bsr     _cheats_trouver         | CH_ENTREE, CH_NB (`cheats.s`)
        bsr     .Lmise_en_page

        | PALETTES. Trois que le plan fixe n'emploie pas, pour que le texte du jeu hors du
        | cadre garde ses couleurs (les sprites qui en useraient, eux, les perdent) : les plus
        | hautes de 1 à 15 absentes des 1 280 cases ; à défaut, 15, 14, 13. Sauvées puis posées
        | juste après la ligne $1F0.
        bsr     .Lchoisir_palettes
        bsr     .Lsync
        lea     MN_PALS, %a4
        lea     MN_PAL, %a3
        lea     .Lcouleurs, %a5
        moveq   #NPAL - 1, %d2
1:      move.w  (%a4)+, %d0
        lsl.w   #5, %d0
        lea     PALETTES, %a2
        adda.w  %d0, %a2
        moveq   #16 - 1, %d1
2:      move.w  (%a2)+, (%a3)+
        dbra    %d1, 2b
        lea     -30(%a2), %a2           | entrée 1 ; l'entrée 0 reste au jeu
        move.w  (%a5)+, (%a2)+          | le trait
        moveq   #14 - 1, %d1
3:      move.w  #C_CADRE, (%a2)+        | entrées 2-15, le cadre
        dbra    %d1, 3b
        dbra    %d2, 1b
        bsr     .Lsauver_fix
        bsr     .Ldessiner

| ----------------------------------------------------------------------------------
| LA BOUCLE, une trame par tour. P1 seul, sur front. Lu dans « Memory mapped registers » :
| REG_P1CNT bits 0 haut, 1 bas, 4 A ; REG_STATUS_B bit 0 START ; actifs à l'état bas.
| %d5 : l'état de la trame d'avant, pris à l'ouverture (START tenu n'y compte pas).
        bsr     .Lentrees
.Lboucle:
        bsr     .Lsync
        bsr     .Lentrees
        move.w  MN_DERNIER, %d1         | %d1 : le dernier choix (`.Lmise_en_page`)
        nop                             | les cycles de l'`addq` d'avant : voir MN_DERNIER
        btst    #0, %d0                 | haut : le précédent, du premier au dernier
        beq.s   1f
        subq.w  #1, MN_CHOIX
        bpl.s   3f
        move.w  %d1, MN_CHOIX
        bra.s   3f
1:      btst    #1, %d0                 | bas : le suivant, du dernier au premier
        beq.s   2f
        addq.w  #1, MN_CHOIX
        cmp.w   MN_CHOIX, %d1
        bcc.s   3f
        clr.w   MN_CHOIX
3:      bsr     .Ldessiner
        bra.s   .Lboucle
2:      andi.w  #0x0110, %d0            | A ou START
        beq.s   .Lboucle
        move.w  MN_CHOIX, %d1
        beq.s   .Lreprendre
        subq.w  #1, %d1
        beq.w   .Lrelance
        | %d1 : le choix moins 3 moins N — négatif un cheat ou AUTOFIRE, 0 GAME SETTINGS, 1 l'éditeur.
        | `subq #2` et `blt` au lieu de `subq #1` et `bcs` : mêmes cycles, et GAME SETTINGS s'ouvre aux
        | cycles d'avant AUTOFIRE (voir `reglages-jeu.s`, LES CYCLES ; mesuré, la scène gs-mmss).
        subq.w  #2, %d1
        sub.w   MN_NCH, %d1
        blt.s   4f
        beq.s   5f
        bsr     _memoire_ecran          | `memoire.s`
        bra.s   6f
5:      bsr     _reglages_jeu_ecran     | `reglages-jeu.s`
6:      bsr     .Lsous_fermer
        bsr     .Lentrees               | un bouton encore tenu (START) ne compte pas
        bra     .Lboucle
4:      add.w   MN_NCH, %d1
        addq.w  #1, %d1                 | le choix moins 2 : 0 à N − 1 un cheat, N AUTOFIRE (`autofire.s`)
        cmp.w   MN_NCH, %d1
        bne.s   7f
        bsr     _af_ecran
        bra.s   6b
7:      move.w  CH_ETATS, %d2           | un cheat : son bit basculé, et on reste dans le menu
        bchg    %d1, %d2
        move.w  %d2, CH_ETATS
        bsr     .Ldessiner
        bra     .Lboucle

| RESUME. Tout relâché d'abord : un bouton encore tenu au retour serait un appui pour le
| jeu. Puis l'écran rendu, et le jeu à la ligne où il était.
.Lreprendre:
1:      bsr     .Lsync
        jsr     _panneau_p1             | %d0 : P1, manette ou panneau traduit (`panneau.s`)
        not.b   %d0
        andi.b  #0xF0, %d0              | A, B, C, D
        bne.s   1b
        move.b  STATUS_B, %d0
        not.b   %d0
        andi.b  #0x0F, %d0              | START et SELECT, P1 et P2
        | Sur MVS, START seuls : lu dans « BIOS RAM locations », « On MVS the select bits
        | are always read as 0 », comme `ecran.s`. Un SELECT lu actif au repos ferait attendre
        | RESUME à jamais (SUPPOSÉ pour le registre brut, comme dans `ecran.s`). La MACHINE,
        | REG_STATUS_B bit 7 (« 0:AES 1:MVS »), pas le mode : un MVS en mode AES reste un MVS.
        tst.b   STATUS_B                | bit 7, le signe : à 0, AES
        bpl.s   8f
        andi.b  #0x05, %d0
8:      tst.b   %d0
        bne.s   1b
        btst    #7, SYSTYPE             | et TEST
        beq.s   1b
        bsr     .Lsync
        lea     MN_PALS, %a4
        lea     MN_PAL, %a2
        moveq   #NPAL - 1, %d2
2:      move.w  (%a4)+, %d0
        lsl.w   #5, %d0
        lea     PALETTES, %a3
        adda.w  %d0, %a3
        moveq   #16 - 1, %d1
3:      move.w  (%a2)+, (%a3)+
        dbra    %d1, 3b
        dbra    %d2, 2b
        bsr     .Lrendre_fix
        move.w  MN_MOD, VRAMMOD
        tst.w   MN_ADROK
        beq.s   4f
        move.w  MN_ADR, VRAMADDR        | la file du jeu reprend là où elle était
4:
        | La ligne de l'ouverture, puis les IRQ nées pendant la pause (voir l'en-tête).
        | BORNÉE comme `.Lsync` (SYNC_TOURS tours, coup de pied à chaque tour) : un tour fait
        | 78 cycles ici (`cmp.w` abs.l 16 au lieu de `cmpi.w` 8), ≈ 2,2 trames, puis la reprise
        | se fait quand même. %d1 est libre : il est rechargé juste après, puis rendu au jeu.
        move.w  #SYNC_TOURS - 1, %d1
5:      move.b  %d0, WATCHDOG
        move.w  LSPCMODE, %d0
        lsr.w   #7, %d0
        cmp.w   MN_LIGNE, %d0
        dbeq    %d1, 5b
        moveq   #4, %d0                 | le vblank
        move.w  MN_SR, %d1
        andi.w  #0x0700, %d1
        cmpi.w  #0x0100, %d1
        bhi.s   6f
        moveq   #6, %d0                 | et le timer
6:      move.w  %d0, IRQACK
        move.b  %d0, WATCHDOG
        move.w  #-1, MN_COMPTE          | rien avant le relâchement ; le jig y reconnaît la sortie
        movea.l MN_SP, %sp
        movem.l MN_REGS, %d0-%d7/%a0-%a6
        move.w  MN_SR, %sr              | le jig prend ici son relevé « après »
        rts

| RESTART GAME : sans coup de pied, le watchdog relance tout (`dip.s`). `_mn_relancer` : la
| même, pour GAME SETTINGS.
_mn_relancer:
.Lrelance:
        bra.s   .Lrelance

| ----------------------------------------------------------------------------------
| LES SOUS-ÉCRANS (voir l'en-tête). Ouvrir : le cadre du menu rendu au jeu, celui du
| sous-écran sauvé. Fermer : l'inverse, puis le menu redessiné. Clobbers %d0-%d4, %d6, %a0-%a3.
_mn_sous_ouvrir:
        bsr     .Lrendre_fix
        move.w  #SOUS_NCOL, MN_NCOL
        move.w  #SOUS_NLIG, MN_NLIG
        move.w  #SOUS_CASE0, MN_CASE0
        bra     .Lsauver_fix

.Lsous_fermer:
        bsr     .Lrendre_fix
        bsr     .Lmise_en_page
        bsr     .Lsauver_fix
        bra     .Ldessiner

| MN_BUF à espaces, MN_COUL au texte. Clobbers %d0, %a0.
_mn_vider:
        lea     MN_BUF, %a0
        moveq   #SOUS_NCOL - 1, %d0
1:      move.b  #0x20, (%a0)+
        dbra    %d0, 1b
        lea     MN_COUL, %a0
        moveq   #SOUS_NCOL - 1, %d0
1:      clr.b   (%a0)+
        dbra    %d0, 1b
        rts

| %d4 caractères de %a3 dans MN_BUF à partir de la colonne %d0, au rôle %d1. Clobbers %d0, %d4,
| %a0, %a1, %a3.
_mn_texte:
        lea     MN_BUF, %a0
        adda.w  %d0, %a0
        lea     MN_COUL, %a1
        adda.w  %d0, %a1
        subq.w  #1, %d4
        bmi.s   9f
1:      move.b  (%a3)+, (%a0)+
        move.b  %d1, (%a1)+
        dbra    %d4, 1b
9:      rts

| LA LIGNE %d4 DU CADRE, MN_NCOL cases de MN_BUF, chacune sous la palette de son rôle (MN_COUL :
| 0 le texte, 1 le titre, 2 la ligne choisie, MN_PALS). REG_VRAMMOD à 32. Hors de $20-$7E, une
| espace. Clobbers %d0-%d3, %a0-%a3.
_mn_ligne:
        move.w  #32, VRAMMOD
        lea     VRAMRW, %a0
        move.w  MN_CASE0, %d1
        add.w   %d4, %d1
        move.w  %d1, VRAMADDR
        lea     MN_BUF, %a2
        lea     MN_COUL, %a3
        move.w  MN_NCOL, %d2
        subq.w  #1, %d2
1:      moveq   #0, %d0
        move.b  (%a2)+, %d0
        cmpi.b  #0x20, %d0
        bcs.s   2f
        cmpi.b  #0x7E, %d0
        bls.s   3f
2:      moveq   #0x20, %d0
3:      moveq   #0, %d1
        move.b  (%a3)+, %d1
        cmpi.b  #2, %d1
        bls.s   4f
        moveq   #0, %d1
4:      add.w   %d1, %d1                | le rôle → MN_PALS : 0 texte (+4), 1 titre (+0), 2 choisi (+2)
        lea     .Lroles, %a1
        move.w  (%a1,%d1.w), %d1
        lea     MN_PALS, %a1
        move.w  (%a1,%d1.w), %d3
        ror.w   #4, %d3
        add.w   %d3, %d0
        move.w  %d0, (%a0)
        dbra    %d2, 1b
        rts
.Lroles: .word  4, 0, 2

| ----------------------------------------------------------------------------------
| LES BOUTONS. %d5.w : l'état d'avant, mis à jour ; %d0.w : les fronts. Bits : ceux de
| REG_P1CNT (« Memory mapped registers ») — 0 haut, 1 bas, 2 gauche, 3 droite, 4 A, 5 B, 6 C,
| 7 D —, et 8 START. Clobbers %d1, %d2.
_mn_entrees:
.Lentrees:
        moveq   #0, %d2
        jsr     _panneau_p1             | %d0 : P1, manette ou panneau traduit (`panneau.s`)
        move.b  %d0, %d2
        not.b   %d2
        move.b  STATUS_B, %d1
        not.b   %d1
        andi.w  #0x01, %d1
        lsl.w   #8, %d1                 | START → bit 8
        or.w    %d1, %d2
        move.w  %d5, %d0
        not.w   %d0
        and.w   %d2, %d0
        move.w  %d2, %d5
        rts

| ----------------------------------------------------------------------------------
| L'ADRESSE VRAM DU JEU, retrouvée (voir l'en-tête). Rien ne doit écrire REG_VRAMADDR
| avant la sonde : ce serait perdre ce qu'on cherche. Donc, l'adresse courante étant A et le
| pas mis à 1 (REG_VRAMMOD est déjà sauvé), quatre mots lus puis remplacés : R0..R3 =
| VRAM[A..A+3], et à leur place DEUX paires sondes, S1 S2 puis T1 T2. Un seul balayage
| compte chacune : une paire S trouvée une seule fois donne A ; sinon une paire T unique
| donne A + 2 (une paire S naturelle ailleurs en VRAM ne fait donc pas échouer). On remet
| R0..R3 à A..A+3. ÉCHEC des deux (chacune absente ou en double) : MN_ADROK reste à 0, la
| sortie ne repose pas d'adresse, et les quatre mots sondes RESTENT en VRAM à A..A+3, où
| le jeu reprendra sur une adresse fausse — SUPPOSÉ rare, deux paires arbitraires.
| Clobbers %d0-%d5, %a0, %a1.
.Lsonder:
        lea     VRAMRW, %a0
        lea     VRAMADDR, %a1
        clr.w   MN_ADROK
        move.w  #1, VRAMMOD
        move.w  (%a0), MN_R0
        move.w  #S1, (%a0)
        nop                             | 16 cycles au moins avant de relire (« VRAM »)
        nop
        nop
        move.w  (%a0), MN_R1
        move.w  #S2, (%a0)
        nop
        nop
        nop
        move.w  (%a0), MN_R2
        move.w  #T1, (%a0)
        nop
        nop
        nop
        move.w  (%a0), MN_R3
        move.w  #T2, (%a0)
        nop
        nop
        nop

        | LE BALAYAGE de $0000-$87FF (« VRAM » : $0000-$7FFF puis $8000-$87FF). %d2 : le mot
        | lu à l'adresse d'avant. Rythme : 16 cycles au moins entre l'adresse et la lecture —
        | `addq` (4), trois `nop` (12), puis le `move` qui lit. %d4 / %d5 : paires S / T vues.
        moveq   #0, %d4
        moveq   #0, %d5
        moveq   #0, %d1
        moveq   #0, %d2
        move.w  #0x8800 - 1, %d3
1:      move.w  %d1, (%a1)
        addq.w  #1, %d1
        nop
        nop
        nop
        move.w  (%a0), %d0
        cmpi.w  #S2, %d0
        bne.s   2f
        cmpi.w  #S1, %d2
        bne.s   3f
        addq.w  #1, %d4
        move.w  %d1, MN_ADR
        subq.w  #2, MN_ADR              | %d1 est déjà passé au mot suivant S2
        bra.s   3f
2:      cmpi.w  #T2, %d0
        bne.s   3f
        cmpi.w  #T1, %d2
        bne.s   3f
        addq.w  #1, %d5
        move.w  %d1, MN_ADR2
        subq.w  #4, MN_ADR2             | T1 est à A + 2
3:      move.w  %d0, %d2
        move.b  %d0, WATCHDOG
        dbra    %d3, 1b
        cmpi.w  #1, %d4
        beq.s   4f
        cmpi.w  #1, %d5
        bne.s   9f
        move.w  MN_ADR2, MN_ADR
4:      move.w  #1, MN_ADROK
        move.w  MN_ADR, (%a1)
        nop
        nop
        nop
        nop
        move.w  MN_R0, (%a0)            | pas de 1 : A, A+1, A+2, A+3
        move.w  MN_R1, (%a0)
        move.w  MN_R2, (%a0)
        move.w  MN_R3, (%a0)
9:      rts

| ----------------------------------------------------------------------------------
| LE CADRE. Sauver : MN_NCOL × MN_NLIG cases lues une à une. Rendre : réécrites colonne par colonne.
.Lsauver_fix:
        lea     VRAMRW, %a0
        lea     VRAMADDR, %a1
        lea     MN_FIX, %a2
        move.w  MN_CASE0, %d1
        move.w  MN_NCOL, %d3
        subq.w  #1, %d3
1:      move.w  MN_NLIG, %d2
        subq.w  #1, %d2
        move.w  %d1, %d4                | la colonne, case par case
2:      move.w  %d4, (%a1)
        addq.w  #1, %d4
        nop
        nop
        nop
        move.w  (%a0), (%a2)+
        dbra    %d2, 2b
        addi.w  #32, %d1
        dbra    %d3, 1b
        rts

.Lrendre_fix:
        lea     VRAMRW, %a0
        lea     MN_FIX, %a2
        move.w  #1, VRAMMOD             | une colonne : MN_NLIG mots consécutifs
        move.w  MN_CASE0, %d1
        move.w  MN_NCOL, %d3
        subq.w  #1, %d3
1:      move.w  %d1, VRAMADDR
        move.w  MN_NLIG, %d2
        subq.w  #1, %d2
2:      move.w  (%a2)+, (%a0)
        dbra    %d2, 2b
        addi.w  #32, %d1
        dbra    %d3, 1b
        rts

| LA MISE EN PAGE, d'après CH_NB (`_cheats_trouver`). Clobbers %d0, %d1.
.Lmise_en_page:
        move.w  CH_NB, %d0
        move.w  %d0, MN_NCH
        move.w  %d0, %d1
        addq.w  #4, %d1                 | N + 4, MEMORY EDITOR
        btst    #3, BORNE_RAM
        beq.s   2f
        subq.w  #1, %d1                 | CHEATS/DEBUG OFF : GAME SETTINGS est le dernier
2:      move.w  %d1, MN_DERNIER
        cmpi.w  #MN_VIS, %d0
        bls.s   3f
        moveq   #MN_VIS, %d0            | au-delà : la fenêtre défile
3:      move.w  %d0, MN_NVIS
        tst.w   %d0
        bne.s   1f
        move.w  #NCOL, MN_NCOL          | sans cheat : le cadre d'avant, à l'identique
        move.w  #NLIG, MN_NLIG
        move.w  #1, MN_CURS
        clr.w   MN_PAD
        move.w  #0x7000 + 32 * COL0 + LIG0, MN_CASE0
        rts
1:      move.w  #NCOL_C, MN_NCOL
        move.w  #PAD_C, MN_PAD
        move.w  #PAD_C + 1, MN_CURS
        move.w  %d0, %d1
        addi.w  #NLIG, %d1
        move.w  %d1, MN_NLIG
        lsr.w   #1, %d0
        move.w  #0x7000 + 32 * COL0_C + LIG0, %d1
        sub.w   %d0, %d1                | 11 − V/2
        move.w  %d1, MN_CASE0
        rts

| LA FENÊTRE : MN_HAUT suit le choix quand c'est un cheat, juste assez pour le montrer. Ailleurs
| (RESUME, RESTART, AUTOFIRE et après), elle ne bouge pas. Clobbers %d0, %d1.
.Lfenetre:
        move.w  MN_CHOIX, %d0
        subq.w  #2, %d0                 | l'index du cheat choisi
        bmi.s   9f                      | RESUME, RESTART
        cmp.w   MN_NCH, %d0
        bcc.s   9f                      | AUTOFIRE et la suite
        cmp.w   MN_HAUT, %d0
        bcc.s   1f
        move.w  %d0, MN_HAUT            | au-dessus de la fenêtre : il en devient le haut
        rts
1:      move.w  %d0, %d1
        sub.w   MN_NVIS, %d1
        addq.w  #1, %d1                 | le haut qui le montre en dernière ligne
        cmp.w   MN_HAUT, %d1
        ble.s   9f                      | signé : négatif tant que l'index est sous MN_NVIS
        move.w  %d1, MN_HAUT
9:      rts

| LE CHOIX DE LA LIGNE %d4 DU CADRE, dans %d0 (négatif pour les lignes 0-2) : les lignes 3 et 4,
| puis MN_NVIS cheats à partir de MN_HAUT, puis les lignes fixes, à N cheats du début. Clobbers %d1.
.Lchoix_de_ligne:
        move.w  %d4, %d0
        subq.w  #3, %d0
        cmpi.w  #2, %d0
        blt.s   9f                      | lignes 0-4 : la ligne moins 3
        move.w  MN_NVIS, %d1
        addq.w  #2, %d1
        cmp.w   %d1, %d0
        bge.s   1f
        add.w   MN_HAUT, %d0            | un cheat de la fenêtre
        rts
1:      add.w   MN_NCH, %d0
        sub.w   MN_NVIS, %d0            | après la fenêtre : les cheats cachés en plus
9:      rts

| LES LIGNES DU CADRE, REG_VRAMMOD à 32 : une ligne s'écrit d'une adresse, depuis MN_BUF
| (`.Lconstruire`). MN_PALS : le titre, la ligne choisie (et son curseur), le reste.
| Clobbers %d0-%d4, %d6, %a0, %a2, %a3 ; %d5, l'état des boutons, est intact.
.Ldessiner:
        bsr     .Lfenetre
        move.w  #32, VRAMMOD
        moveq   #0, %d4                 | la ligne du cadre
1:      bsr     .Lconstruire
        moveq   #0, %d6                 | 1 : la ligne porte le curseur
        move.w  MN_PALS + 4, %d3        | le texte
        cmpi.w  #1, %d4
        bne.s   2f
        move.w  MN_PALS, %d3            | le titre
2:      bsr     .Lchoix_de_ligne        | les choix à partir de la ligne 3
        cmp.w   MN_CHOIX, %d0
        bne.s   3f
        move.w  MN_PALS + 2, %d3        | la ligne choisie
        moveq   #1, %d6
3:      ror.w   #4, %d3                 | le numéro de palette dans les 4 bits hauts
        lea     VRAMRW, %a0
        move.w  MN_CASE0, %d1
        add.w   %d4, %d1
        move.w  %d1, VRAMADDR
        lea     MN_BUF, %a2
        move.w  MN_NCOL, %d2
        subq.w  #1, %d2
        move.w  %d2, %d1
        sub.w   MN_CURS, %d1            | %d2 quand la colonne est celle du curseur
4:      moveq   #0, %d0
        move.b  (%a2)+, %d0
        tst.w   %d6
        beq.s   5f
        cmp.w   %d1, %d2
        bne.s   5f
        moveq   #0x3E, %d0              | « > »
5:      add.w   %d3, %d0
        move.w  %d0, (%a0)
        dbra    %d2, 4b
        addq.w  #1, %d4
        cmp.w   MN_NLIG, %d4
        bcs.s   1b
        rts

| LA LIGNE %d4 DU CADRE, en caractères dans MN_BUF (NCOL_C octets, espaces au-delà de
| MN_NCOL). Lignes 0-4 et les cinq dernières : `.Llignes` 0-9, décalées de MN_PAD ; entre
| les deux, les MN_NVIS cheats de la fenêtre : le nom à MN_PAD + 3, l'état « ON » / « OFF » à
| MN_PAD + 20. La ligne 2, quand des cheats sont cachés : `.Lrang`. Clobbers %d0-%d2, %a2, %a3.
.Lconstruire:
        lea     MN_BUF, %a2
        moveq   #NCOL_C - 1, %d0
1:      move.b  #0x20, (%a2)+
        dbra    %d0, 1b
        lea     MN_BUF, %a2
        adda.w  MN_PAD, %a2
        move.w  %d4, %d0
        cmpi.w  #5, %d0
        bcs.s   8f                      | lignes fixes 0-4
        subq.w  #5, %d0                 | k = ligne − 5
        cmp.w   MN_NVIS, %d0
        bcs.s   6f                      | k < V : le cheat MN_HAUT + k
        move.w  %d4, %d0
        sub.w   MN_NVIS, %d0            | lignes fixes 5-9 (ligne − V ≥ 5 ici)
        bra.s   3f
8:      cmpi.w  #2, %d0
        bne.s   3f
        move.w  MN_NCH, %d1
        cmp.w   MN_NVIS, %d1
        bhi.s   .Lrang                  | des cheats cachés
        bra.s   3f
6:      add.w   MN_HAUT, %d0
        movea.l CH_ENTREE, %a3
        move.w  %d0, %d2
        lsl.w   #5, %d2                 | × FICHE (`cheats.s`)
        adda.w  %d2, %a3
        addq.l  #3, %a2
        moveq   #16 - 1, %d2
2:      move.b  (%a3)+, (%a2)+
        dbra    %d2, 2b
        addq.l  #1, %a2
        lea     .Lon, %a3
        move.w  CH_ETATS, %d2
        btst    %d0, %d2
        bne.s   4f
        lea     .Loff, %a3
4:      move.b  (%a3)+, (%a2)+
        move.b  (%a3)+, (%a2)+
        move.b  (%a3)+, (%a2)+
        rts
3:      cmpi.w  #7, %d0                 | MEMORY EDITOR, CHEATS/DEBUG OFF : la ligne en blanc
        bne.s   7f
        btst    #3, BORNE_RAM
        bne.s   9f
7:      lea     .Llignes, %a3           | 20 × %d0
        lsl.w   #2, %d0
        adda.w  %d0, %a3
        lsl.w   #2, %d0
        adda.w  %d0, %a3
        moveq   #NCOL - 1, %d2
5:      move.b  (%a3)+, (%a2)+
        dbra    %d2, 5b
9:      rts

| « CHEATS a-b/N » à MN_PAD + 3 : les cheats montrés, de 1 à N. %a2 : MN_BUF + MN_PAD. La fin de
| `.Lconstruire`, rendue par le `rts` de `.Ldecimal`. Clobbers %d0, %d2, %a2, %a3.
.Lrang:
        addq.l  #3, %a2
        lea     .Lcheats, %a3
        moveq   #7 - 1, %d2
1:      move.b  (%a3)+, (%a2)+
        dbra    %d2, 1b
        move.w  MN_HAUT, %d0
        addq.w  #1, %d0
        bsr.s   .Ldecimal
        move.b  #0x2D, (%a2)+           | « - »
        move.w  MN_HAUT, %d0
        add.w   MN_NVIS, %d0
        bsr.s   .Ldecimal
        move.b  #0x2F, (%a2)+           | « / »
        move.w  MN_NCH, %d0             | puis `.Ldecimal`, juste en dessous

| %d0.w (0 à 99) en décimal sans zéro de tête, à (%a2)+. Clobbers %d0.
.Ldecimal:
        andi.l  #0xFFFF, %d0
        divu    #10, %d0                | les dizaines dans le mot bas, les unités dans le haut
        tst.w   %d0
        beq.s   1f
        addi.b  #0x30, %d0
        move.b  %d0, (%a2)+
1:      swap    %d0
        addi.b  #0x30, %d0
        move.b  %d0, (%a2)+
        rts

| LES PALETTES DU MENU (voir l'ouverture). Un bit par palette des 1 280 cases du plan fixe,
| lues par REG_VRAMRW au rythme de `.Lsauver_fix` ; puis de 15 vers 1, les trois premières
| absentes. MN_PALS reçoit titre, choisi, texte. Clobbers %d0-%d3, %a0-%a2.
.Lchoisir_palettes:
        lea     VRAMRW, %a0
        lea     VRAMADDR, %a1
        moveq   #0, %d2                 | les palettes vues
        move.w  #0x7000, %d1
        move.w  #1280 - 1, %d3
1:      move.w  %d1, (%a1)
        addq.w  #1, %d1
        nop
        nop
        nop
        move.w  (%a0), %d0
        rol.w   #4, %d0
        andi.w  #0x0F, %d0
        bset    %d0, %d2
        move.b  %d0, WATCHDOG
        dbra    %d3, 1b
        move.w  %d2, MN_USAGE
        lea     MN_PALS, %a2
        moveq   #15, %d0
        moveq   #NPAL - 1, %d3
2:      btst    %d0, %d2
        bne.s   3f
        move.w  %d0, (%a2)+             | libre : prise
        subq.w  #1, %d3
        bmi.s   9f
3:      subq.w  #1, %d0
        bne.s   2b
        | Moins de trois libres : toutes les libres sont déjà prises, les places restantes
        | prennent les EMPLOYÉES, de 15 vers 1 — jamais deux fois la même, sans quoi la
        | sauvegarde d'une palette déjà écrasée la rendrait fausse au jeu. Le texte du jeu
        | sous elles change de couleur pendant la pause.
        moveq   #15, %d0
4:      btst    %d0, %d2
        beq.s   5f                      | libre : déjà prise au premier tour
        move.w  %d0, (%a2)+
        subq.w  #1, %d3
        bmi.s   9f
5:      subq.w  #1, %d0
        bne.s   4b
9:      rts

| LE PASSAGE DE LA LIGNE $1F0, comme `dip.s` ; watchdog à chaque tour. Clobbers %d0.
| BORNÉE à SYNC_TOURS tours par attente, ≈ 2 trames, ligne vue ou non : le compte est dans
| `ecran.s`, dont c'est la copie identique.
        .equ    SYNC_TOURS, 5800
_mn_sync:
.Lsync:
        move.l  %d1, -(%sp)
        move.w  #SYNC_TOURS - 1, %d1
1:      move.b  %d0, WATCHDOG
        move.w  LSPCMODE, %d0
        lsr.w   #7, %d0
        cmpi.w  #0x1F0, %d0
        dbne    %d1, 1b
        move.w  #SYNC_TOURS - 1, %d1
2:      move.b  %d0, WATCHDOG
        move.w  LSPCMODE, %d0
        lsr.w   #7, %d0
        cmpi.w  #0x1F0, %d0
        dbeq    %d1, 2b
        move.l  (%sp)+, %d1
        rts

| ----------------------------------------------------------------------------------
| LES DONNÉES.
        .balign 2
.Lcouleurs:                             | l'entrée 1 : titre, ligne choisie, texte
        .word   0x04CF                  | le titre
        .word   0x0FE3                  | la ligne choisie
        .word   0x0DDD                  | le texte
.Lon:    .ascii  "ON "
.Loff:   .ascii  "OFF"
.Lcheats: .ascii "CHEATS "
.Llignes:                               | NLIG lignes de NCOL caractères
        .ascii  "                    "
        .ascii  "    IN-GAME MENU    "
        .ascii  "                    "
        .ascii  "   RESUME           "
        .ascii  "   RESTART GAME     "
        .ascii  "   AUTOFIRE         "
        .ascii  "   GAME SETTINGS    "
        .ascii  "   MEMORY EDITOR    "
        .ascii  " UP/DOWN A/START:OK "
        .ascii  "                    "
        .balign 2
