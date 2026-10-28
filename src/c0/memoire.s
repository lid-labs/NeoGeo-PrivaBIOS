| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| MEMORY EDITOR — la RAM de travail ($100000-$10FFFF) en hexadécimal, depuis le menu en jeu
| (`menu.s`) : la voir, s'y déplacer, modifier un octet, en GELER jusqu'à GL_MAX (le cheat
| personnalisé : `cheats.s` réécrit chaque gel à chaque appel de SYSTEM_IO). Le 2026-10-23.
|
| AUCUN ORACLE : l'éditeur mémoire d'aucun BIOS n'est lu. « mesuré » : un relevé nommé ; « lu
| dans » : une page du NeoGeo Development Wiki ; « SUPPOSÉ » : ni l'un ni l'autre.
|
| CE QUI SE LIT, CE QUI S'ÉCRIT. Toute la RAM de travail se lit, la zone du BIOS comprise
| ($10F300-$10FFFF, « BIOS RAM locations » : la page la donne au BIOS). Rien ne s'écrit ni ne
| se gèle à partir de $10F300 : ni la RAM du BIOS, ni la sauvegarde du menu ($10F4C0-$10FB1F,
| dans cette zone). L'écran le dit (READ ONLY), A et D n'y font rien, et le moteur des gels
| refuse lui-même un décalage de $F300 ou plus (`cheats.s`). La lecture passe par le 68000 et
| ne touche à aucun registre de la carte. Pendant la pause le jeu est arrêté : ce qu'on lit est
| la RAM telle qu'il l'a laissée à son appel de SYSTEM_IO.
|
| L'ÉCRAN, le cadre des sous-écrans du menu (28 × 14, `menu.s`), la police de la cartouche :
|   0      MEMORY EDITOR (titre), et l'adresse du curseur (colonne 20) ;
|   2-9    huit lignes de huit octets : l'adresse (colonne 2), quatre octets (colonne 9),
|          quatre (colonne 18). L'octet du curseur sous la palette du choix, un octet gelé sous
|          celle du titre ;
|   10, 13 l'aide ;
|   11-12  FROZEN, et les gels : « 10XXXX:VV », deux par ligne, ou NONE.
|
| LES COMMANDES, P1 sur front (une direction tenue se répète : après REP_DEBUT trames, une fois
| toutes les REP_PAS) :
|   haut/bas une ligne (8 octets), gauche/droite un octet ; B tenu et haut/bas une page
|   (64 octets) ; tout en boucle sur les 64 Kio ;
|   C : GOTO, l'adresse à quatre chiffres (gauche/droite le chiffre, haut/bas sa valeur, A y
|       va, B renonce) ;
|   A : SET VALUE (haut/bas ±1, gauche/droite ±$10, A écrit l'octet — et la valeur du gel s'il
|       est gelé —, B renonce) ;
|   D : gèle l'octet à sa valeur, ou le dégèle s'il l'est ; GL_MAX pris : rien ;
|   START : le menu.
| Le curseur et la fenêtre (ME_ADR, ME_HAUT) restent d'une ouverture à l'autre ; vidés au boot.
| ==================================================================================

        .section .haut, "ax"
        .global _memoire_ecran

        .equ    RAM,       0x100000
        .equ    BORNE,     0xF300       | $10F300 : la zone du BIOS (`cheats.s`, GL_BORNE)
        .equ    GL_MAX,    4
        | Dans la zone mesurée libre de `cheats.s`, après les gels : gardés entre deux ouvertures.
        .equ    ME_ADR,    0x10FB1C     | .w le décalage du curseur
        .equ    ME_HAUT,   0x10FB1E     | .w celui de la première ligne, multiple de 8
        | Sous la pile du menu (`menu.s`), après GAME SETTINGS.
        .equ    ME_MODE,   0x10F9D4     | .w 0 parcourir, 1 SET VALUE, 2 GOTO
        .equ    ME_VAL,    0x10F9D6     | .w la valeur en cours, ou l'adresse de GOTO
        .equ    ME_CHIF,   0x10F9D8     | .w le chiffre de GOTO, 0 le plus haut
        .equ    REP_DEBUT, 20
        .equ    REP_PAS,   4
        .equ    L_HEX,     2            | la ligne du cadre de la première ligne d'octets

_memoire_ecran:
        bsr     _mn_sous_ouvrir
        clr.w   ME_MODE
        clr.w   MN_REP
        andi.w  #0xFFF8, ME_HAUT        | une fenêtre quelconque laissée par un jeu : recalée
        bsr     .Lcaler
        bsr     .Ltout

.Lboucle:
        bsr     _mn_sync
        bsr     _mn_entrees
        | LA RÉPÉTITION : une direction tenue redonne un front, après REP_DEBUT trames, puis
        | toutes les REP_PAS.
        move.w  %d5, %d1
        andi.w  #0x0F, %d1
        bne.s   1f
        clr.w   MN_REP
        bra.s   2f
1:      addq.w  #1, MN_REP
        move.w  MN_REP, %d2
        subi.w  #REP_DEBUT, %d2
        bcs.s   2f
        andi.w  #REP_PAS - 1, %d2
        bne.s   2f
        or.w    %d1, %d0
2:      tst.w   %d0
        beq.s   .Lboucle
        btst    #8, %d0                 | START : le menu, quel que soit le mode
        beq.s   1f
        rts
1:      move.w  ME_MODE, %d1
        beq.s   .Lparcourir
        subq.w  #1, %d1
        beq     .Lvaleur
        bra     .Lgoto

| ----------------------------------------------------------------------------------
| PARCOURIR. %d0 : les fronts ; %d5 : l'état (B tenu).
.Lparcourir:
        move.w  ME_ADR, %d1
        btst    #0, %d0                 | haut
        beq.s   2f
        moveq   #-8, %d2
        btst    #5, %d5                 | B tenu : une page
        beq.s   1f
        moveq   #-64, %d2
1:      add.w   %d2, %d1
        btst    #5, %d5
        beq     .Lp_poser
        add.w   %d2, ME_HAUT            | la page : la fenêtre suit, le curseur y garde sa place
        bra     .Lp_poser
2:      btst    #1, %d0                 | bas
        beq.s   2f
        moveq   #8, %d2
        btst    #5, %d5
        beq.s   1b
        moveq   #64, %d2
        bra.s   1b
2:      btst    #2, %d0                 | gauche
        beq.s   2f
        subq.w  #1, %d1
        bra     .Lp_poser
2:      btst    #3, %d0                 | droite
        beq.s   2f
        addq.w  #1, %d1
        bra     .Lp_poser
2:      btst    #6, %d0                 | C : GOTO
        beq.s   2f
        move.w  %d1, ME_VAL
        clr.w   ME_CHIF
        move.w  #2, ME_MODE
        bra     .Lp_dessin
2:      cmpi.w  #BORNE, %d1
        bcc     .Lboucle                | la zone du BIOS : ni A ni D
        lea     RAM, %a0
        andi.l  #0xFFFF, %d1
        btst    #4, %d0                 | A : SET VALUE
        beq.s   2f
        moveq   #0, %d2
        move.b  (%a0,%d1.l), %d2
        move.w  %d2, ME_VAL
        move.w  #1, ME_MODE
        bra.s   .Lp_dessin
2:      btst    #7, %d0                 | D : geler, ou dégeler
        beq     .Lboucle
        bsr     .Lchercher_gel          | %d3 : son numéro, ou -1
        bmi.s   3f
        bclr    %d3, GL_MASQUE + 1      | dégelé
        bra.s   .Lp_dessin
3:      moveq   #0, %d3                 | le premier libre
4:      btst    %d3, GL_MASQUE + 1
        beq.s   5f
        addq.w  #1, %d3
        cmpi.w  #GL_MAX, %d3
        bcs.s   4b
        bra     .Lboucle                | tous pris : rien
5:      lea     GL_TABLE, %a1
        move.w  %d3, %d2
        lsl.w   #2, %d2
        move.w  %d1, (%a1,%d2.w)
        move.b  (%a0,%d1.l), 2(%a1,%d2.w)
        bset    %d3, GL_MASQUE + 1
        bra.s   .Lp_dessin
.Lp_poser:
        move.w  %d1, ME_ADR
        bsr.s   .Lcaler
.Lp_dessin:
        bsr     .Ltout
        bra     .Lboucle

| LA FENÊTRE recalée sur le curseur (mots non signés, en boucle sur les 64 Kio). Clobbers %d1, %d2.
.Lcaler:
        move.w  ME_ADR, %d1
        move.w  %d1, %d2
        sub.w   ME_HAUT, %d2
        cmpi.w  #64, %d2
        bcs.s   9f                      | dans la fenêtre
        cmp.w   ME_HAUT, %d1
        bcc.s   1f
        andi.w  #0xFFF8, %d1            | au-dessus : sa ligne en haut
        move.w  %d1, ME_HAUT
        rts
1:      andi.w  #0xFFF8, %d1            | en dessous : sa ligne en bas
        subi.w  #56, %d1
        move.w  %d1, ME_HAUT
9:      rts

| LE GEL DE L'OCTET %d1 (décalage) : %d3 son numéro et N à 0, ou -1 et N à 1. Clobbers %d2, %a1.
.Lchercher_gel:
        lea     GL_TABLE, %a1
        moveq   #0, %d3
1:      btst    %d3, GL_MASQUE + 1
        beq.s   2f
        cmp.w   (%a1), %d1
        beq.s   9f
2:      addq.l  #4, %a1
        addq.w  #1, %d3
        cmpi.w  #GL_MAX, %d3
        bcs.s   1b
        moveq   #-1, %d3
9:      tst.w   %d3
        rts

| ----------------------------------------------------------------------------------
| SET VALUE. Haut/bas ±1, gauche/droite ±$10 ; A écrit, B renonce.
.Lvaleur:
        move.w  ME_VAL, %d1
        btst    #0, %d0
        beq.s   1f
        addq.b  #1, %d1
1:      btst    #1, %d0
        beq.s   1f
        subq.b  #1, %d1
1:      btst    #3, %d0
        beq.s   1f
        addi.b  #0x10, %d1
1:      btst    #2, %d0
        beq.s   1f
        subi.b  #0x10, %d1
1:      andi.w  #0xFF, %d1
        move.w  %d1, ME_VAL
        btst    #5, %d0                 | B : rien d'écrit
        bne.s   8f
        btst    #4, %d0                 | A : l'octet écrit
        beq.s   9f
        move.w  ME_ADR, %d1
        cmpi.w  #BORNE, %d1             | gardé ici aussi : le mode ne s'ouvre pas au-delà
        bcc.s   8f
        andi.l  #0xFFFF, %d1
        lea     RAM, %a0
        move.b  ME_VAL + 1, (%a0,%d1.l)
        bsr     .Lchercher_gel
        bmi.s   8f
        lsl.w   #2, %d3                 | gelé : sa valeur suit
        lea     GL_TABLE, %a1
        move.b  ME_VAL + 1, 2(%a1,%d3.w)
8:      clr.w   ME_MODE
9:      bsr     .Ltout
        bra     .Lboucle

| GOTO. Gauche/droite le chiffre, haut/bas sa valeur ; A y va, B renonce.
.Lgoto:
        move.w  ME_CHIF, %d2
        btst    #2, %d0
        beq.s   1f
        subq.w  #1, %d2
        bpl.s   1f
        moveq   #0, %d2
1:      btst    #3, %d0
        beq.s   1f
        addq.w  #1, %d2
        cmpi.w  #3, %d2
        bls.s   1f
        moveq   #3, %d2
1:      move.w  %d2, ME_CHIF
        moveq   #3, %d3                 | le décalage du chiffre : 4 × (3 − chiffre)
        sub.w   %d2, %d3
        lsl.w   #2, %d3
        moveq   #1, %d1
        lsl.w   %d3, %d1                | une unité de ce chiffre
        move.w  #0x000F, %d4
        lsl.w   %d3, %d4                | son masque
        move.w  ME_VAL, %d2
        btst    #0, %d0
        beq.s   1f
        move.w  %d2, %d6
        add.w   %d1, %d6
        bra.s   2f
1:      btst    #1, %d0
        beq.s   3f
        move.w  %d2, %d6
        sub.w   %d1, %d6
2:      and.w   %d4, %d6                | le chiffre seul change, sans retenue
        not.w   %d4
        and.w   %d4, %d2
        or.w    %d6, %d2
        move.w  %d2, ME_VAL
3:      btst    #5, %d0                 | B : rien
        bne.s   8f
        btst    #4, %d0                 | A : le curseur y va, sa ligne en haut
        beq.s   9f
        move.w  ME_VAL, %d1
        move.w  %d1, ME_ADR
        andi.w  #0xFFF8, %d1
        move.w  %d1, ME_HAUT
8:      clr.w   ME_MODE
9:      bsr     .Ltout
        bra     .Lboucle

| ----------------------------------------------------------------------------------
| TOUT L'ÉCRAN, ligne par ligne. Clobbers %d0-%d4, %d6, %a0-%a3.
.Ltout:
        moveq   #0, %d4
.Lt_ligne:
        bsr     _mn_vider
        move.w  %d4, -(%sp)
        bsr.s   .Lcomposer
        move.w  (%sp)+, %d4
        bsr     _mn_ligne
        addq.w  #1, %d4
        cmpi.w  #14, %d4
        bcs.s   .Lt_ligne
        rts

| LA LIGNE %d4 dans MN_BUF et MN_COUL. Clobbers %d0-%d4, %d6, %a0-%a3.
.Lcomposer:
        tst.w   %d4
        bne.s   .Lc_hex
        lea     .Ltxt_titre, %a3
        moveq   #L_TITRE, %d4
        moveq   #2, %d0
        moveq   #1, %d1
        bsr     _mn_texte
        move.w  ME_ADR, %d2             | l'adresse : celle du curseur, ou celle de GOTO
        cmpi.w  #2, ME_MODE
        bne.s   1f
        move.w  ME_VAL, %d2
1:      lea     MN_BUF + 20, %a1
        bsr     .Ladresse
        cmpi.w  #2, ME_MODE
        bne.s   9f
        lea     MN_COUL + 22, %a1       | le chiffre de GOTO, sous la palette du choix
        adda.w  ME_CHIF, %a1
        move.b  #2, (%a1)
9:      rts

.Lc_hex:
        move.w  %d4, %d6
        subq.w  #L_HEX, %d6
        bcs     .Lc_aide
        cmpi.w  #8, %d6
        bcc     .Lc_aide
        lsl.w   #3, %d6
        add.w   ME_HAUT, %d6            | %d6 : le décalage du premier octet de la ligne
        move.w  %d6, %d2
        lea     MN_BUF + 2, %a1
        bsr     .Ladresse
        moveq   #0, %d4                 | l'octet de la ligne, 0 à 7
1:      moveq   #9, %d0                 | sa colonne : 9 + 2 × k, + 1 pour le second groupe
        move.w  %d4, %d1
        add.w   %d1, %d1
        add.w   %d1, %d0
        cmpi.w  #4, %d4
        bcs.s   2f
        addq.w  #1, %d0
2:      lea     MN_BUF, %a1
        adda.w  %d0, %a1
        lea     MN_COUL, %a2
        adda.w  %d0, %a2
        move.w  %d6, %d1
        add.w   %d4, %d1                | le décalage de l'octet
        andi.l  #0xFFFF, %d1
        lea     RAM, %a0
        moveq   #0, %d2
        move.b  (%a0,%d1.l), %d2
        moveq   #0, %d3                 | le rôle
        movem.l %d1-%d2/%a1, -(%sp)
        bsr     .Lchercher_gel
        movem.l (%sp)+, %d1-%d2/%a1
        bmi.s   3f
        moveq   #1, %d3                 | gelé : le titre
3:      cmp.w   ME_ADR, %d1
        bne.s   4f
        moveq   #2, %d3                 | le curseur : le choix
        cmpi.w  #1, ME_MODE
        bne.s   4f
        move.w  ME_VAL, %d2             | SET VALUE : la valeur en cours
4:      move.b  %d3, (%a2)+
        move.b  %d3, (%a2)
        bsr     .Loctet
        addq.w  #1, %d4
        cmpi.w  #8, %d4
        bcs.s   1b
        rts

.Lc_aide:
        cmpi.w  #10, %d4
        bne.s   2f
        lea     .Ltxt_page, %a3         | l'aide de la ligne 10, selon le mode
        moveq   #L_PAGE, %d4
        move.w  ME_MODE, %d1
        beq.s   1f
        lea     .Ltxt_val2, %a3
        moveq   #L_VAL2, %d4
        subq.w  #1, %d1
        beq.s   1f
        lea     .Ltxt_goto2, %a3
        moveq   #L_GOTO2, %d4
1:      moveq   #2, %d0
        moveq   #0, %d1
        bra     _mn_texte
2:      cmpi.w  #13, %d4
        bne.s   .Lc_gels
        lea     .Ltxt_aide, %a3         | l'aide de la ligne 13
        moveq   #L_AIDE, %d4
        move.w  ME_MODE, %d1
        bne.s   3f
        cmpi.w  #BORNE, ME_ADR
        bcs.s   1b
        lea     .Ltxt_lecture, %a3      | la zone du BIOS
        moveq   #L_LECTURE, %d4
        bra.s   1b
3:      lea     .Ltxt_val, %a3
        moveq   #L_VAL, %d4
        subq.w  #1, %d1
        beq.s   1b
        lea     .Ltxt_goto, %a3
        moveq   #L_GOTO, %d4
        bra.s   1b

| LES LIGNES 11 ET 12 : FROZEN, puis les gels k et k + 1 (k = 0 à la ligne 11, 2 à la 12), ou
| NONE s'il n'y en a aucun.
.Lc_gels:
        cmpi.w  #11, %d4
        beq.s   1f
        cmpi.w  #12, %d4
        bne     9f
1:      move.w  %d4, %d6
        subi.w  #11, %d6
        add.w   %d6, %d6                | le premier gel de la ligne
        tst.w   %d6
        bne.s   2f
        lea     .Ltxt_gels, %a3
        moveq   #6, %d4
        moveq   #2, %d0
        moveq   #0, %d1
        bsr     _mn_texte
        tst.b   GL_MASQUE + 1           | les gels ; le bit 15 est celui des debug dips (`debug.s`)
        bne.s   2f
        lea     .Ltxt_aucun, %a3
        moveq   #4, %d4
        moveq   #9, %d0
        moveq   #0, %d1
        bra     _mn_texte
2:      moveq   #0, %d0                 | le rang du gel affiché sur la ligne, 0 ou 1
        moveq   #0, %d3                 | le gel, 0 à GL_MAX − 1
        moveq   #0, %d4                 | les gels actifs déjà vus
3:      btst    %d3, GL_MASQUE + 1
        beq.s   5f
        move.w  %d4, %d1
        sub.w   %d6, %d1
        bcs.s   4f                      | un gel d'une ligne d'avant
        cmpi.w  #2, %d1
        bcc.s   9f                      | la ligne est pleine
        lea     MN_BUF + 9, %a1         | colonne 9, ou 19 pour le second
        tst.w   %d1
        beq.s   6f
        lea     MN_BUF + 19, %a1
6:      lea     GL_TABLE, %a0
        move.w  %d3, %d2
        lsl.w   #2, %d2
        adda.w  %d2, %a0
        move.w  (%a0), %d2
        movem.l %d3-%d4, -(%sp)
        bsr.s   .Ladresse
        move.b  #0x3A, (%a1)+           | « : »
        moveq   #0, %d2
        move.b  2(%a0), %d2
        bsr.s   .Loctet
        movem.l (%sp)+, %d3-%d4
4:      addq.w  #1, %d4
5:      addq.w  #1, %d3
        cmpi.w  #GL_MAX, %d3
        bcs.s   3b
9:      rts

| « 10XXXX » à (%a1)+, %d2.w le décalage. Clobbers %d2, %d3.
.Ladresse:
        move.b  #0x31, (%a1)+
        move.b  #0x30, (%a1)+
        move.w  %d2, -(%sp)
        lsr.w   #8, %d2
        bsr.s   .Loctet
        move.w  (%sp)+, %d2             | puis l'octet bas : `.Loctet`, qui suit

| L'OCTET %d2.b en deux chiffres hexadécimaux à (%a1)+. Clobbers %d2, %d3.
.Loctet:
        move.b  %d2, %d3
        lsr.b   #4, %d3
        bsr.s   .Lchiffre
        move.b  %d2, %d3
.Lchiffre:
        andi.b  #0x0F, %d3
        addi.b  #0x30, %d3
        cmpi.b  #0x39, %d3
        bls.s   1f
        addq.b  #7, %d3                 | A-F
1:      move.b  %d3, (%a1)+
        rts

| ----------------------------------------------------------------------------------
| LES DONNÉES.
        .balign 2
.Ltxt_titre:
        .ascii  "MEMORY EDITOR"
        .equ    L_TITRE, . - .Ltxt_titre
.Ltxt_page:
        .ascii  "B-UP/DOWN:PAGE START:BACK"
        .equ    L_PAGE, . - .Ltxt_page
.Ltxt_aide:
        .ascii  "A:EDIT C:GOTO D:FREEZE"
        .equ    L_AIDE, . - .Ltxt_aide
.Ltxt_lecture:
        .ascii  "READ ONLY  C:GOTO"
        .equ    L_LECTURE, . - .Ltxt_lecture
.Ltxt_val:
        .ascii  "SET VALUE  A:OK  B:CANCEL"
        .equ    L_VAL, . - .Ltxt_val
.Ltxt_val2:
        .ascii  "UP/DOWN:1  LEFT/RIGHT:10"
        .equ    L_VAL2, . - .Ltxt_val2
.Ltxt_goto:
        .ascii  "GOTO ADDRESS A:OK B:CANCEL"
        .equ    L_GOTO, . - .Ltxt_goto
.Ltxt_goto2:
        .ascii  "L/R:DIGIT  UP/DOWN:VALUE"
        .equ    L_GOTO2, . - .Ltxt_goto2
.Ltxt_gels:
        .ascii  "FROZEN"
.Ltxt_aucun:
        .ascii  "NONE"
        .balign 2
