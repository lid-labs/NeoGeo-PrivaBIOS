| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| GAME SETTINGS — les soft-DIP de la cartouche, réglés pendant la partie, depuis le menu en
| jeu (`menu.s`). Le 2026-10-23.
|
| AUCUN ORACLE : le menu de réglage d'aucun BIOS n'est lu. « mesuré » : un relevé nommé ; « lu
| dans » : une page du NeoGeo Development Wiki ; « SUPPOSÉ » : ni l'un ni l'autre.
|
| LE MOTEUR EST CELUI DE L'ÉDITEUR DU BOOT (`dip.s`) : le pointeur du bloc (`_dip_bloc`, la
| région en cours), la table des réglages (`_dip_table` : temps, compte, nombre de fois, à
| choix), le pas d'une valeur (`_dip_pas_valeur`), les défauts (`_dip_defauts`), le texte d'une
| valeur (`_dip_valeur`). Ni la région ni le mode ne sont ici : ils restent au boot.
| ÉCART À L'ÉDITEUR DU BOOT : un bloc dans la zone banquée ($200000-$2FFFFF) est refusé ici.
| Au boot il est lu dans la banque en place ; en partie, le jeu a pu changer de banque, et la
| table lue serait celle d'un autre morceau de sa ROM — des bornes fausses, donc des valeurs
| hors bornes écrites dans GAME_DIP. SUPPOSÉ : aucun jeu du corpus ne le montre, faute d'en
| avoir mesuré un. Les valeurs reçues ne sont pas rendues valides à l'entrée (l'éditeur du boot
| le fait) : une valeur que le joueur ne touche pas reste celle que le jeu voit.
|
| LES INTITULÉS EN RÉGION JAPAN, le 2026-10-27 (DECISIONS §19). Le bloc japonais code ses
| intitulés hors de l'ASCII, et l'écran les rendait en espaces. Le BIOS SNK japonais les écrit en
| $300/$400 + octet sous la police de la carte ; MESURÉ (`measured/2026-10-27-intitules-japon.tsv`,
| section 3) : la S ROM de cinq cartouches n'a aucun de ces glyphes à ces tuiles, et REG_BRDFIX
| couperait la M1 du jeu (`menu.s`). ÉCART PROPRE À REBIOS : en région JAPAN, les intitulés (ceux
| des réglages et ceux des choix) viennent du bloc USA de la cartouche (pointeur $11A, « 68k program
| header »), à la même place dans son bloc, si sa structure est celle du bloc japonais : octets $10-$15
| égaux (temps, compte, nombre de fois), et pour $16-$1F le nombre de choix (quartet bas) seul. Le
| quartet haut, le défaut, n'entre pas dans la comparaison : la table, les valeurs et l'enregistrement
| restent ceux du bloc japonais, et un défaut ne change pas la place d'un intitulé ; MESURÉ (même
| relevé, section 4) : 25 jeux du catalogue n'ont que leurs défauts de différents. Bloc USA nul, hors
| de la P-ROM fixe (refusé comme le bloc japonais ici), ou de structure différente : les intitulés du
| bloc japonais, en espaces, comme avant. SUPPOSÉ : qu'une même structure veuille dire les mêmes
| réglages dans le même ordre ; vu à l'écran sur ssideki seul (scène gs-japon).
|
| QUAND L'EFFET EST PRIS. Chaque pas écrit BIOS_GAME_DIP ($10FD84-$10FD93, « BIOS RAM
| locations ») à l'instant. Le jeu le prend quand il le relit. Mesuré sous MAME 0.286 le
| 2026-10-23 (tap de lecture sur $10FD84-$10FD93, lectures du jeu seules : PC < $C00000, lu et non consigné ; pièce à 400,
| START à 500, 9 000 trames ; `measured/2026-10-23-menu-en-jeu-complet.tsv`, section 1) : six
| jeux sur six relisent des octets EN PARTIE, certains à chaque trame (aof l'octet 13, kof98 le
| 11, mslug 7 et 13, puzzledp 6, 8, 9, samsho2 7 et 14), d'autres à un moment de la partie (aof
| l'octet 4, ROUND TIME, au début de chaque round : trames 1897 et 4191) ; d'autres encore ne
| sont lus qu'au titre ou à la démo (aof 6, 8, 11 ; puzzledp 5, CONTINUE), ou à la demande 0
| (kof98, les seize, trames 186-187). D'où la ligne d'aide « SOME CHANGES NEED RESTART », et la
| ligne RESTART GAME : elle enregistre et relance, et le boot relit le bloc (`_relire_dip`).
|
| L'ENREGISTREMENT, comme au boot : GAME_DIP recopié dans le bloc du jeu, $D00220 + 16 × index,
| l'index étant celui de l'entrée du slot servi ($D00124 + 4 × $D00108, + 2 ; `c0.s`). Au
| retour (START) et avant RESTART GAME, si une valeur a changé ; un index hors de 0-7 : rien
| d'écrit. REG_SRAMUNLOCK puis REG_SRAMLOCK : la backup RAM est verrouillée à l'appel, `_io_commun`
| la refermant avant le crochet du menu (`io.s`).
|
| L'ÉCRAN, le cadre des sous-écrans du menu (28 × 14, `menu.s`), la police de la cartouche :
|   0  —
|   1  GAME SETTINGS (titre)
|   3-10  huit lignes de la liste, qui défile : « > », l'intitulé (12 caractères de la
|         cartouche, colonne 2), la valeur (colonne 15) ; la ligne choisie sous la palette du choix
|   12 SOME CHANGES NEED RESTART
|   13 L/R/A:CHANGE START:BACK
| La liste : les réglages de la cartouche, RESET TO DEFAULTS, RESTART GAME ; sans bloc (refusé,
| ou nul), NO SOFT DIP DATA à la place des réglages.
|
| LES COMMANDES, P1 sur front, comme l'éditeur du boot : haut/bas la ligne, en boucle ;
| droite/gauche la valeur, bornée ; A la suivante, en boucle. Sur RESET TO DEFAULTS, droite,
| gauche ou A remettent les défauts ; sur RESTART GAME, ils enregistrent et relancent. START :
| enregistre et rend la main au menu.
| ==================================================================================

        .section .haut, "ax"
        .global _reglages_jeu_ecran

        .equ    GAME_DIP,  0x10FD84
        .equ    SRAMUNLOCK, 0x3A001D
        .equ    SRAMLOCK,  0x3A000D
        | Sous la pile du menu, dans sa zone mesurée libre (`menu.s`).
        .equ    GS_N,      0x10F900     | .w lignes de la liste
        .equ    GS_CHOIX,  0x10F902     | .w la ligne choisie
        .equ    GS_HAUT,   0x10F904     | .w la première ligne affichée
        .equ    GS_CHANGE, 0x10F906     | .w non nul : une valeur a changé
        .equ    GS_TABLE,  0x10F908     | N_MAX × T_ENTREE → $10F9D4
        .equ    T_ENTREE,  12           | le format de `dip.s`
        .equ    N_MAX,     17           | 2 temps + 2 comptes + 10 à choix + la remise + la relance
        .equ    VISIBLES,  8
        .equ    L_LISTE,   3            | la ligne du cadre de la première ligne affichée
        | Genres, ceux de `dip.s` (0 temps, 1 compte, 2 nombre de fois, 3 à choix, 4 remise), et :
        .equ    G_SANS,    9            | NO SOFT DIP DATA
        .equ    G_RELANCE, 10           | RESTART GAME

_reglages_jeu_ecran:
        bsr     _mn_sous_ouvrir
        lea     GAME_DIP, %a5
        bsr     _dip_bloc               | %a3 : le bloc soft-DIP, 0 si refusé
        cmpa.l  #0x100000, %a3
        bcs.s   1f
        suba.l  %a3, %a3                | la zone banquée : refusée (voir l'en-tête)
1:      lea     GS_TABLE, %a4
        movea.l %a4, %a2
        moveq   #0, %d6
        move.l  %a3, %d0
        bne.s   2f
        move.b  #G_SANS, (%a2)
        clr.b   1(%a2)
        move.l  #.Ltxt_sans, 6(%a2)
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        bra.s   3f
4:      bsr     .Lusa                   | en région JAPAN : les intitulés du bloc USA
        bra.s   3f
| LES CYCLES. RESTART GAME relance par le watchdog, et la trame du RESET suit à quelques cycles
| près ceux de l'ouverture de cet écran : 26 cycles de plus l'avançaient d'une trame sur ncombat
| (scène gs-mmss), 60 sur puzzledp (gs-fois), mesuré le 2026-10-27. Hors du Japon, le test
| (tst.b 16, beq.s non pris 8, nop 4 : 28) est donc rendu plus bas, à l'identique : deux octets
| de l'entrée posés d'un seul mot (16 de moins) et deux mots de RAM effacés d'un seul long (12).
2:      bsr     _dip_table
        tst.b   0x10FD83                | BIOS_COUNTRY_CODE : 0, JAPAN
        beq.s   4b
        nop
3:      move.w  #0x0400, (%a2)          | genre 4, la remise ; octet 1 à zéro
        move.l  #.Ltxt_defaut, 6(%a2)
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        move.b  #G_RELANCE, (%a2)
        clr.b   1(%a2)
        move.l  #.Ltxt_relance, 6(%a2)
        addq.w  #1, %d6
        move.w  %d6, GS_N
        clr.w   GS_CHOIX
        clr.l   GS_HAUT                 | GS_HAUT et GS_CHANGE
        bsr     .Ltout

| LA BOUCLE, une trame par tour, une action par trame, START d'abord.
.Lboucle:
        bsr     _mn_sync
        bsr     _mn_entrees
        btst    #8, %d0
        bne.s   .Lsortie
        move.w  GS_CHOIX, %d1
        btst    #0, %d0                 | haut
        beq.s   2f
        subq.w  #1, %d1
        bpl.s   1f
        move.w  GS_N, %d1
        subq.w  #1, %d1
1:      move.w  %d1, GS_CHOIX
        bsr     .Ltout
        bra.s   .Lboucle
2:      btst    #1, %d0                 | bas
        beq.s   2f
        addq.w  #1, %d1
        cmp.w   GS_N, %d1
        bcs.s   1b
        moveq   #0, %d1
        bra.s   1b
2:      moveq   #1, %d2                 | droite
        btst    #3, %d0
        bne.s   3f
        moveq   #-1, %d2                | gauche
        btst    #2, %d0
        bne.s   3f
        moveq   #2, %d2                 | A
        btst    #4, %d0
        beq.s   .Lboucle
3:      bsr.s   .Lchanger
        bra.s   .Lboucle

.Lsortie:
        bsr.s   .Lenregistrer
        rts

| LA LIGNE CHOISIE CHANGÉE, %d2 le sens. Clobbers %d0-%d4, %d6, %a2, %a4.
.Lchanger:
        move.w  GS_CHOIX, %d0
        mulu    #T_ENTREE, %d0
        lea     GS_TABLE, %a2
        adda.w  %d0, %a2
        move.b  (%a2), %d0
        cmpi.b  #4, %d0
        bcs.s   1f
        beq.s   2f
        cmpi.b  #G_RELANCE, %d0
        bne.s   9f
        bsr.s   .Lenregistrer           | RESTART GAME : enregistré, puis le watchdog
        bra     _mn_relancer
1:      bsr     _dip_pas_valeur         | un réglage : GAME_DIP à l'instant
        bra.s   3f
2:      lea     GS_TABLE, %a4           | RESET TO DEFAULTS
        move.w  GS_N, %d6
        bsr     _dip_defauts
3:      move.w  #1, GS_CHANGE
        bra.s   .Ltout
9:      rts

| GAME_DIP DANS LE BLOC DU JEU (voir l'en-tête), si une valeur a changé. Clobbers %d1, %a0, %a1.
.Lenregistrer:
        tst.w   GS_CHANGE
        beq.s   9f
        moveq   #0, %d1
        move.b  0xD00108, %d1           | le slot servi
        andi.w  #7, %d1
        lsl.w   #2, %d1
        lea     0xD00124, %a0
        move.w  2(%a0,%d1.w), %d1       | l'index de son bloc
        cmpi.w  #7, %d1
        bhi.s   9f
        lsl.w   #4, %d1
        lea     0xD00220, %a1
        adda.w  %d1, %a1
        lea     GAME_DIP, %a0
        move.b  %d0, SRAMUNLOCK
        move.l  (%a0)+, (%a1)+
        move.l  (%a0)+, (%a1)+
        move.l  (%a0)+, (%a1)+
        move.l  (%a0)+, (%a1)+
        move.b  %d0, SRAMLOCK
        clr.w   GS_CHANGE
9:      rts

| ----------------------------------------------------------------------------------
| TOUT L'ÉCRAN : la fenêtre de la liste recalée sur la ligne choisie, puis les 14 lignes du
| cadre. Clobbers %d0-%d4, %d6, %a0-%a3.
.Ltout:
        move.w  GS_CHOIX, %d0
        move.w  GS_HAUT, %d1
        cmp.w   %d1, %d0
        bcc.s   1f
        move.w  %d0, %d1                | au-dessus de la fenêtre
1:      move.w  %d1, %d2
        addq.w  #VISIBLES, %d2
        cmp.w   %d2, %d0
        bcs.s   2f
        move.w  %d0, %d1                | en dessous
        subq.w  #VISIBLES - 1, %d1
2:      move.w  %d1, GS_HAUT
        moveq   #0, %d4                 | la ligne du cadre
.Lt_ligne:
        bsr     _mn_vider
        cmpi.w  #1, %d4
        bne.s   1f
        lea     .Ltxt_titre, %a3
        moveq   #L_TITRE, %d4
        moveq   #(28 - L_TITRE) / 2, %d0
        moveq   #1, %d1                 | le titre
        bsr     _mn_texte
        moveq   #1, %d4
        bra.s   .Lt_ecrire
1:      cmpi.w  #12, %d4
        bne.s   1f
        lea     .Ltxt_aide1, %a3
        moveq   #L_AIDE1, %d4
        moveq   #1, %d0
        moveq   #0, %d1
        bsr     _mn_texte
        moveq   #12, %d4
        bra.s   .Lt_ecrire
1:      cmpi.w  #13, %d4
        bne.s   1f
        lea     .Ltxt_aide2, %a3
        moveq   #L_AIDE2, %d4
        moveq   #2, %d0
        moveq   #0, %d1
        bsr     _mn_texte
        moveq   #13, %d4
        bra.s   .Lt_ecrire
1:      move.w  %d4, %d0
        subq.w  #L_LISTE, %d0
        bcs.s   .Lt_ecrire
        cmpi.w  #VISIBLES, %d0
        bcc.s   .Lt_ecrire
        add.w   GS_HAUT, %d0            | l'entrée de cette ligne
        cmp.w   GS_N, %d0
        bcc.s   .Lt_ecrire
        move.w  %d4, -(%sp)
        bsr.s   .Lentree
        move.w  (%sp)+, %d4
.Lt_ecrire:
        bsr     _mn_ligne
        addq.w  #1, %d4
        cmpi.w  #14, %d4
        bcs     .Lt_ligne
        rts

| L'ENTRÉE %d0 dans MN_BUF : « > » et la palette du choix si elle est choisie, l'intitulé, la
| valeur. Clobbers %d0-%d4, %a0-%a3.
.Lentree:
        move.w  %d0, %d1
        mulu    #T_ENTREE, %d1
        lea     GS_TABLE, %a2
        adda.w  %d1, %a2
        cmp.w   GS_CHOIX, %d0
        bne.s   2f
        move.b  #0x3E, MN_BUF + 1       | « > »
        lea     MN_COUL, %a0
        moveq   #28 - 1, %d1
1:      move.b  #2, (%a0)+
        dbra    %d1, 1b
2:      moveq   #12, %d4                | l'intitulé
        move.b  (%a2), %d0
        cmpi.b  #4, %d0
        bne.s   1f
        moveq   #L_DEFAUT, %d4
1:      cmpi.b  #G_SANS, %d0
        bne.s   1f
        moveq   #L_SANS, %d4
1:      movea.l 6(%a2), %a3
        lea     MN_BUF + 2, %a1
        bsr     _dip_copier
        cmpi.b  #4, (%a2)
        bcc.s   9f
        lea     MN_BUF + 15, %a1        | la valeur
        bsr     _dip_valeur
9:      rts

| ----------------------------------------------------------------------------------
| L'EMPRUNT AU BLOC USA (voir l'en-tête, LES INTITULÉS EN RÉGION JAPAN), en région JAPAN seulement
| (le test est chez l'appelant). %a3 : le bloc japonais,
| non nul, sous $100000 ; %a4 à %a2 : les entrées que `_dip_table` vient de remplir. Bloc USA
| refusé, ou de structure différente : rien ne change. Clobbers %d0-%d3, %a0, %a1.
.Lusa:
        move.l  0x11A, %d0              | le pointeur du bloc USA (« 68k program header »)
        beq.s   9f
        cmpi.l  #0x100000 - 0x20, %d0
        bhi.s   9f                      | hors de la P-ROM fixe : refusé, comme le bloc japonais ici
        movea.l %d0, %a0
        moveq   #0x10, %d1              | la structure, octets $10-$1F
1:      move.b  (%a3,%d1.w), %d2
        move.b  (%a0,%d1.w), %d3
        cmpi.w  #0x16, %d1
        bcs.s   2f
        andi.b  #0x0F, %d2              | un réglage à choix : son nombre de choix seul,
        andi.b  #0x0F, %d3              | le défaut (quartet haut) reste celui du Japon
2:      cmp.b   %d2, %d3
        bne.s   9f
        addq.w  #1, %d1
        cmpi.w  #0x20, %d1
        bcs.s   1b
        sub.l   %a3, %d0                | du bloc japonais au bloc USA
        movea.l %a4, %a1
3:      cmpa.l  %a2, %a1
        bhs.s   9f
        add.l   %d0, 6(%a1)             | genres 0 à 3 : l'intitulé, à la même place du bloc USA
        lea     T_ENTREE(%a1), %a1
        bra.s   3b
9:      rts

| ----------------------------------------------------------------------------------
| LES DONNÉES.
        .balign 2
.Ltxt_titre:
        .ascii  "GAME SETTINGS"
        .equ    L_TITRE, . - .Ltxt_titre
.Ltxt_sans:
        .ascii  "NO SOFT DIP DATA"
        .equ    L_SANS, . - .Ltxt_sans
.Ltxt_defaut:
        .ascii  "RESET TO DEFAULTS"
        .equ    L_DEFAUT, . - .Ltxt_defaut
.Ltxt_relance:
        .ascii  "RESTART GAME"           | 12 caractères, comme un intitulé
.Ltxt_aide1:
        .ascii  "SOME CHANGES NEED RESTART"
        .equ    L_AIDE1, . - .Ltxt_aide1
.Ltxt_aide2:
        .ascii  "L/R/A:CHANGE START:BACK"
        .equ    L_AIDE2, . - .Ltxt_aide2
        .balign 2
