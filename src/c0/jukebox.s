| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| LE JUKEBOX — ouvert depuis l'écran TEST (`dip.s`, ligne JUKEBOX), hors partie : il
| envoie au pilote son de la cartouche le code qu'on choisit. Le BIOS n'a pas de programme
| Z80 à lui.
|
| AUCUN ORACLE : ni le BIOS de référence ni un BIOS tiers ne sont lus, ni le code Z80 des
| cartouches. La remise est « Couche 3 → le jukebox, le 2026-10-21 »
| (`docs/RELECTURE-CONTRATS.md`). « mesuré » : un relevé nommé ; « lu dans » : une page du
| NeoGeo Development Wiki ; « SUPPOSÉ » : ni l'un ni l'autre.
|
| APPEL : `jsr _jukebox` depuis `dip.s`, %a1 = le bloc soft-DIP de la cartouche (0 s'il est
| refusé), d'où le nom du jeu. Tous les registres rendus. À l'appel, l'état est celui de
| l'écran TEST : REG_BRDFIX (police de la carte), le pilote du jeu en boucle en RAM après
| la poignée de main $01 de `dip.s`, palettes 1-4 de `dip.s` posées dans la banque 0, IRQ
| masquées. Au retour, le même état, sauf la palette 5 laissée à zéro : `dip.s` n'emploie
| que 1-4, `tests.s` et `plantage.s` posent les leurs avant usage (lu dans le code).
|
| L'ENTRÉE. REG_CRTFIX rend la M1 de la cartouche au Z80 et la S ROM au plan fixe (lu dans
| « Memory mapped registers ») ; $03, « soft reset » du Z80, « within 100ms », sans
| réponse (lu dans « 68k/Z80 communication ») ; puis 8 trames (~135 ms) avant le premier
| code, comme `menu.s`. Le texte est donc dans la POLICE DE LA CARTOUCHE, aux places du
| SFIX, en 8×8 (tuile = ASCII) : mesuré, `measured/2026-10-21-police-cartouche.tsv`, 20 jeux
| identiques au SFIX sur 0-9, A-Z, espace, « : - / . », trally lisible, kof2003 sans rien
| (ses cases sont des aplats d'index 2) : sur kof2003 l'écran est noir, le son marche.
| Seuls ces caractères sont employés (pas de « $ » : non mesuré).
| L'EFFACEMENT : chaque case reçoit la tuile $020 sous la palette 5, dont les 16 entrées
| sont mises à zéro. Quel que soit le dessin de $020 dans la S ROM, tout index non nul y
| est noir, comme le fond ; la tuile $FF de FIX_CLEAR n'est pas mesurée sous la S ROM.
| Le trait à l'index 1 (même relevé) : les palettes 1-4 de `dip.s` portent leur couleur
| dans l'entrée 1, du noir dans 2 à 15.
|
| LES CODES. Lu dans « 68k/Z80 communication » : trois codes sont réservés au système —
| $01 (préparer un changement de slot : le pilote coupe le son, répond $01 et boucle en
| RAM), $02 (musique de l'eye-catcher, sans réponse), $03 (reset). La page ne donne aucune
| table des autres, dont le sens dépend du pilote. Ils sont SAUTÉS : le numéro passe de
| $00 à $04 et de $04 à $00 ; les 253 autres, $00 compris, s'envoient tels quels.
| « PLAY 07 FIRST IF SILENT » : mesuré (jig `bench/jukebox.lua`, 2026-10-21), aof, kof98,
| kof2003 ne déclenchent après le $03, avant $07, que $7F ; $07 éteint mslug : on ne
| l'envoie donc pas d'office, l'aide le dit.
| COUPER LE SON (B) : la page ne documente aucun code d'arrêt ; on relance le pilote par
| $03 puis 8 trames. SUPPOSÉ : qu'un pilote fraîchement relancé se taise.
|
| LES COMMANDES, P1, actives à l'état bas (lu dans « Memory mapped registers » : REG_P1CNT
| bits 0-5 haut, bas, gauche, droite, A, B ; REG_STATUS_B bit 0 START P1). Haut/bas : ±1,
| gauche/droite : ±16, avec répétition tenue (20 trames puis toutes les 4 : choix, 256 crans
| un à un seraient longs). A : envoie le code à REG_SOUND. B : coupe. START : sortie.
|
| L'ÉCONOMISEUR D'ÉCRAN, le 2026-10-27 (DECISIONS §25, décision de l'utilisateur : copier
| UniBIOS 4.0). MESURÉ chez lui (`measured/2026-10-27-attentes-reference.tsv`) : dans son JUKEBOX
| PLAYER seulement, l'écran devient entièrement noir ~7 220 trames (~2 min) après la dernière entrée,
| la musique continue, une touche rend l'écran. Ici : INACTIF trames sans aucune entrée de P1 (les
| huit de REG_P1CNT, START), les entrées 1 des palettes 1-4 — les seules couleurs de cet écran, le
| reste étant noir — sont mises à zéro, juste après le passage de la ligne $1F0 ; le Z80 n'est pas
| touché. Une entrée tenue les rend, et cette trame-là ne fait rien d'autre : ni code, ni pas, ni
| sortie ; tenue ensuite, elle n'a plus de front. Les quatre couleurs sont gardées dans %a1 et %a3.
|
| LA SORTIE. La poignée de main $01 de `menu.s` (envoi, une trame, lecture de l'écho,
| 60 fois au plus — l'écho n'est lu qu'une trame après l'envoi : la dernière réponse du
| pilote peut déjà valoir $01), une trame, REG_BRDFIX. Le pilote est alors dans sa boucle
| en RAM, comme `dip.s` l'avait laissé ; `dip.s` fera à sa sortie REG_CRTFIX et $03 comme
| sans jukebox.
| ==================================================================================

        .section .haut, "ax"
        .global _jukebox

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    WATCHDOG, 0x300001
        .equ    SOUND,    0x320000
        .equ    STATUS_B, 0x380000
        .equ    BRDFIX,   0x3A000B
        .equ    CRTFIX,   0x3A001B
        .equ    PALETTES, 0x400000

        .equ    PAL_VIDE, 5             | la palette d'effacement, toute à zéro
        | La mise en page, en cases du plan fixe ($7000 + 32 × colonne + ligne).
        .equ    CASE_TITRE, 0x7000 + 3 * 32 + 4
        .equ    CASE_NOM,   0x7000 + 3 * 32 + 6
        .equ    CASE_SON,   0x7000 + 3 * 32 + 12
        .equ    CASE_CODE,  0x7000 + 15 * 32 + 12
        .equ    CASE_AIDE1, 0x7000 + 3 * 32 + 23
        .equ    CASE_AIDE2, 0x7000 + 3 * 32 + 24
        .equ    CASE_AIDE3, 0x7000 + 3 * 32 + 26
        .equ    CASE_AIDE4, 0x7000 + 3 * 32 + 27
        .equ    DELAI1,   20            | trames avant la répétition
        .equ    DELAI2,   4             | trames entre deux répétitions
        .equ    INACTIF,  7100          | trames sans entrée avant l'écran noir : ~2 min à 59,185 Hz

| %d7 : le code ; %d5 : les boutons de la trame d'avant ; %d6 : le compte de répétition ;
| %a0 : REG_VRAMRW ; %a5 : le bloc soft-DIP.
_jukebox:
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        movea.l %a1, %a5
        lea     VRAMRW, %a0

        | L'ENTRÉE : la cartouche au Z80, son pilote relancé, l'écran sous sa S ROM.
        bsr     .Lsync
        move.b  %d0, CRTFIX
        move.b  #0x03, SOUND
        lea     PALETTES + PAL_VIDE * 32, %a2
        moveq   #16 - 1, %d0
1:      clr.w   (%a2)+
        dbra    %d0, 1b
        move.w  #1, VRAMMOD
        move.w  #0x7000, VRAMADDR
        move.w  #(PAL_VIDE << 12) + 0x020, %d0
        move.w  #1280 - 1, %d1          | 18 cycles par tour : au-dessus des 12 (« VRAM »)
2:      move.w  %d0, (%a0)
        dbra    %d1, 2b
        move.w  #32, VRAMMOD            | une écriture = une colonne
        move.w  #CASE_TITRE, %d1
        lea     .Ltxt_titre, %a2
        moveq   #L_TITRE, %d4
        move.w  #0x3000, %d3
        bsr     .Lecrire
        move.l  %a5, %d0
        beq.s   3f
        move.w  #CASE_NOM, %d1          | le nom du jeu, octets $00-$0F du bloc
        movea.l %a5, %a2
        moveq   #16, %d4
        move.w  #0x3000, %d3
        bsr     .Lecrire
3:      move.w  #CASE_SON, %d1
        lea     .Ltxt_son, %a2
        moveq   #L_SON, %d4
        move.w  #0x1000, %d3
        bsr     .Lecrire
        move.w  #CASE_AIDE1, %d1
        lea     .Ltxt_aide1, %a2
        moveq   #L_AIDE1, %d4
        move.w  #0x4000, %d3
        bsr     .Lecrire
        move.w  #CASE_AIDE2, %d1
        lea     .Ltxt_aide2, %a2
        moveq   #L_AIDE2, %d4
        move.w  #0x4000, %d3
        bsr     .Lecrire
        move.w  #CASE_AIDE3, %d1
        lea     .Ltxt_aide3, %a2
        moveq   #L_AIDE3, %d4
        move.w  #0x4000, %d3
        bsr     .Lecrire
        move.w  #CASE_AIDE4, %d1
        lea     .Ltxt_aide4, %a2
        moveq   #L_AIDE4, %d4
        move.w  #0x4000, %d3
        bsr     .Lecrire
        moveq   #0, %d7
        bsr     .Lcode
        bsr     .Lattendre              | le pilote repart avant le premier code
        moveq   #0, %d5
        bsr     .Lentrees               | un bouton déjà tenu (le A qui ouvre) ne compte pas
        moveq   #0, %d6                 | 0 : pas de répétition armée (voir LES DIRECTIONS)
        moveq   #0, %d3                 | %d3 : les trames sans entrée (L'ÉCONOMISEUR)

| LA BOUCLE, une trame par tour.
.Lboucle:
        bsr     .Lsync
        bsr     .Lentrees               | %d0 les fronts, %d5 l'état
        | L'ÉCONOMISEUR (voir l'en-tête) : %d3 s'arrête à INACTIF, l'écran noir.
        move.l  %d0, %d1                | les fronts gardés
        jsr     _panneau_p1             | %d0 : P1, manette ou panneau traduit (`panneau.s`)
        exg     %d0, %d1
        not.b   %d1
        or.b    %d5, %d1                | C et D comptent aussi, que `.Lentrees` ne lit pas
        bne.s   8f
        cmpi.w  #INACTIF, %d3
        bcc.s   9f                      | déjà noir
        addq.w  #1, %d3
        cmpi.w  #INACTIF, %d3
        bcs.s   9f
        bsr     .Leteindre
        bra     .Lboucle
8:      cmpi.w  #INACTIF, %d3
        bcs.s   7f
        bsr     .Lrallumer              | la trame du réveil ne fait rien d'autre
        moveq   #0, %d3
        moveq   #0, %d6
        bra     .Lboucle
7:      moveq   #0, %d3
9:      btst    #6, %d0
        bne     .Lsortie
        btst    #4, %d0                 | A : le code au pilote
        beq.s   1f
        move.b  %d7, SOUND
        bra     .Lboucle
1:      btst    #5, %d0                 | B : le pilote relancé
        beq.s   2f
        move.b  #0x03, SOUND
        bsr     .Lattendre
        bra     .Lboucle
        | LES DIRECTIONS : un front agit et arme DELAI1 ; tenues, elles agissent quand le
        | compte tombe à zéro, puis toutes les DELAI2 trames. %d6 à 0, rien n'est armé : une
        | direction déjà tenue à l'ouverture ne répète jamais avant d'avoir été relâchée.
2:      move.b  %d0, %d2
        andi.b  #0x0F, %d2
        beq.s   3f
        moveq   #DELAI1, %d6
        bra.s   4f
3:      move.b  %d5, %d2
        andi.b  #0x0F, %d2
        beq     .Lboucle
        tst.w   %d6
        beq     .Lboucle                | rien d'armé
        subq.w  #1, %d6
        bne     .Lboucle
        moveq   #DELAI2, %d6
4:      moveq   #1, %d1                 | haut
        btst    #0, %d2
        bne.s   5f
        moveq   #-1, %d1                | bas
        btst    #1, %d2
        bne.s   5f
        moveq   #16, %d1                | droite
        btst    #3, %d2
        bne.s   5f
        moveq   #-16, %d1               | gauche
5:      add.b   %d1, %d7                | modulo 256
        cmpi.b  #1, %d7
        bcs.s   6f
        cmpi.b  #3, %d7
        bhi.s   6f
        moveq   #4, %d7                 | $01-$03 réservés : sautés dans le sens du pas
        tst.b   %d1
        bpl.s   6f
        moveq   #0, %d7
6:      andi.l  #0xFF, %d7
        bsr     .Lcode
        bra     .Lboucle

| LA SORTIE : le pilote en boucle en RAM, puis la police de la carte (voir l'en-tête).
.Lsortie:
        moveq   #60 - 1, %d4
1:      move.b  #0x01, SOUND
        bsr     .Lsync
        cmpi.b  #0x01, SOUND
        dbeq    %d4, 1b
        bsr     .Lsync                  | une trame pour que le pilote entre en boucle
        move.b  %d0, BRDFIX
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rts

| L'ÉCRAN NOIR, puis rendu : les entrées 1 des palettes 1-4, gardées dans %a1 (1, 2) et %a3 (3, 4).
| Clobbers %d1.
.Leteindre:
        move.w  PALETTES + 1 * 32 + 2, %d1
        swap    %d1
        move.w  PALETTES + 2 * 32 + 2, %d1
        movea.l %d1, %a1
        move.w  PALETTES + 3 * 32 + 2, %d1
        swap    %d1
        move.w  PALETTES + 4 * 32 + 2, %d1
        movea.l %d1, %a3
        clr.w   PALETTES + 1 * 32 + 2
        clr.w   PALETTES + 2 * 32 + 2
        clr.w   PALETTES + 3 * 32 + 2
        clr.w   PALETTES + 4 * 32 + 2
        rts
.Lrallumer:
        move.l  %a1, %d1
        move.w  %d1, PALETTES + 2 * 32 + 2
        swap    %d1
        move.w  %d1, PALETTES + 1 * 32 + 2
        move.l  %a3, %d1
        move.w  %d1, PALETTES + 4 * 32 + 2
        swap    %d1
        move.w  %d1, PALETTES + 3 * 32 + 2
        rts

| LES BOUTONS. Bits : 0 haut, 1 bas, 2 gauche, 3 droite, 4 A, 5 B, 6 START. %d5 l'état
| d'avant, mis à jour ; %d0 les fronts. Clobbers %d1, %d2.
.Lentrees:
        jsr     _panneau_p1             | %d0 : P1, manette ou panneau traduit (`panneau.s`)
        move.b  %d0, %d2
        not.b   %d2
        andi.b  #0x3F, %d2
        move.b  STATUS_B, %d1
        not.b   %d1
        andi.b  #0x01, %d1
        lsl.b   #6, %d1
        or.b    %d1, %d2
        move.b  %d5, %d0
        not.b   %d0
        and.b   %d2, %d0
        move.b  %d2, %d5
        rts

| LE CODE %d7, deux chiffres hexadécimaux sous la palette 2. Clobbers %d0, %d1, %a2.
.Lcode:
        lea     .Lchiffres, %a2
        move.w  #CASE_CODE, VRAMADDR
        move.w  %d7, %d0
        lsr.w   #4, %d0
        andi.w  #0x0F, %d0
        moveq   #0, %d1
        move.b  (%a2,%d0.w), %d1
        addi.w  #0x2000, %d1
        move.w  %d1, (%a0)
        move.w  %d7, %d0
        andi.w  #0x0F, %d0
        moveq   #0, %d1
        move.b  (%a2,%d0.w), %d1
        addi.w  #0x2000, %d1
        move.w  %d1, (%a0)
        rts

| HUIT TRAMES (~135 ms), après un $03 : « within 100ms ». Clobbers %d0, %d4.
.Lattendre:
        moveq   #8 - 1, %d4
1:      bsr.s   .Lsync
        dbra    %d4, 1b
        rts

| ÉCRIRE %d4 caractères de %a2 à partir de la case %d1, REG_VRAMMOD à 32, comme `dip.s`.
| %d3 : palette << 12. Hors de $20-$7E, une espace. Clobbers %d2, %d4, %a2.
.Lecrire:
        move.w  %d1, VRAMADDR
        subq.w  #1, %d4
1:      moveq   #0, %d2
        move.b  (%a2)+, %d2
        cmpi.b  #0x20, %d2
        bcs.s   2f
        cmpi.b  #0x7E, %d2
        bls.s   3f
2:      moveq   #0x20, %d2
3:      add.w   %d3, %d2
        move.w  %d2, (%a0)
        dbra    %d4, 1b
        rts

| LE PASSAGE DE LA LIGNE $1F0, comme `dip.s` ; watchdog à chaque tour. Clobbers %d0.
| BORNÉE à SYNC_TOURS tours par attente, ≈ 2 trames, ligne vue ou non : le compte est dans
| `ecran.s`, dont c'est la copie identique.
        .equ    SYNC_TOURS, 5800
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
| LES DONNÉES : les seuls caractères mesurés dans la police des cartouches.
        .balign 2
.Lchiffres:
        .ascii  "0123456789ABCDEF"
.Ltxt_titre:
        .ascii  "JUKEBOX"
        .equ    L_TITRE, . - .Ltxt_titre
.Ltxt_son:
        .ascii  "SOUND CODE"
        .equ    L_SON, . - .Ltxt_son
.Ltxt_aide1:
        .ascii  "UP/DOWN:1  LEFT/RIGHT:16"
        .equ    L_AIDE1, . - .Ltxt_aide1
.Ltxt_aide2:
        .ascii  "A:PLAY  B:STOP  START:EXIT"
        .equ    L_AIDE2, . - .Ltxt_aide2
.Ltxt_aide3:
        .ascii  "CODES 01-03 SKIPPED"
        .equ    L_AIDE3, . - .Ltxt_aide3
.Ltxt_aide4:
        .ascii  "PLAY 07 FIRST IF SILENT"
        .equ    L_AIDE4, . - .Ltxt_aide4
        .balign 2
