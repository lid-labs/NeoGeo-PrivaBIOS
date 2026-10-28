| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| LES DEBUG DIPS — seize interrupteurs que des jeux lisent pour ouvrir leurs outils de mise au
| point. Un écran de l'écran TEST : CABINET SETTINGS (`dip.s`), cinquième ligne, DEBUG DIPS.
|
| AUCUN ORACLE : ni le BIOS de référence ni un BIOS tiers ne sont lus, ni le code d'un jeu.
| « mesuré » : un relevé nommé ; « lu dans » : une page du NeoGeo Development Wiki ; « SUPPOSÉ » :
| ni l'un ni l'autre.
|
| CE QUE SONT LES DEBUG DIPS, lu dans « Debug DIPs » et « 68k program header » : deux octets
| de la RAM de travail du jeu, « usually » les deux premiers de la zone que pointe le long de
| $10E de l'en-tête — la zone que le BIOS sauve en backup RAM (`c0.s`, `_sauver_jeu`). « The
| Unibios, a debug BIOS, and some emulators allow them to be set ». MESURÉ
| (`measured/2026-10-25-debug-dips.tsv`) : sur kof94, DIP 1 bit 0 ouvre DEBUG OBJE, un visualiseur
| de sprites, DIP 2 bits 1, 4, 5 et 7 quatre outils ; sur 36 des 128 jeux relevés, ces deux octets
| quittent zéro en jeu sans qu'on y touche : ce sont alors des données du jeu.
|
| D'OÙ LE MODÈLE : UN MASQUE, PAS UNE VALEUR. Le BIOS tient DD_MASQUE (DIP 1 à l'octet haut,
| DIP 2 au bas), en RAM seulement, comme les cheats (remis à zéro au boot et à chaque passage de
| slot, `_cheats_oublier`) : il met ces bits à 1 dans les deux premiers octets de la zone du jeu,
| et ne touche à aucun autre. À CHAQUE APPEL DE SYSTEM_IO, par le moteur des cheats (`cheats.s`,
| bit 15 de GL_MASQUE), en démo comme en partie : MESURÉ, kof94 remet $100000 à zéro à chaque
| départ de démo (même relevé, section 4), une pose unique n'y tenait pas cinq trames.
| Le BIOS ne les laisse jamais partir en backup RAM : `_sauver_jeu` (`c0.s`) les retire de la zone
| le temps de la copie, puis les remet. Une mise hors tension les efface donc, et un jeu dont ces
| octets sont des données ne garde en sauvegarde que ses propres bits. Ce que ça coûte : un bit que
| le jeu aurait posé lui-même, au même endroit que le masque, part à zéro en sauvegarde ; et tant
| que le masque est posé, ces bits restent à 1 dans ses données.
| LA ZONE : le long de $10E et la taille de $112, comme `_bloc_jeu` (`c0.s`, mêmes bornes), lus à
| la pose ; deux octets au moins, sinon le masque est oublié.
|
| CHEATS/DEBUG OFF (DECISIONS §16) : la ligne DEBUG DIPS dit OFF et ne s'ouvre plus, et
| `_dd_poser` remet le masque à zéro à la sortie de l'écran TEST : le BIOS n'écrit plus aucun bit.
| Ce qu'un autre BIOS aurait laissé dans la sauvegarde du jeu n'est pas effacé : rien ne le
| distingue d'une donnée du jeu.
|
| POURQUOI L'ÉCRAN TEST, et pas le menu en jeu : une ligne de plus au menu en jeu y déplaçait les
| chemins de touches des relevés (« haut » depuis RESUME mène à MEMORY EDITOR, « haut » deux fois à
| GAME SETTINGS) et changeait le dessin de sa boucle, dont les cycles décident d'une trame de
| RESTART (DECISIONS §16, point 7) ; la cinquième ligne de CABINET SETTINGS ne déplace aucun
| chemin. Et le masque est posé avant que le jeu ne parte : un outil que le jeu n'ouvre qu'à son
| démarrage le voit (SUPPOSÉ pour d'autres jeux que kof94, qui lit ses bits en continu).
|
| L'ÉCRAN, `_debug_dips` : appelé par `jsr` depuis `dip.s`, dans son état (REG_BRDFIX, palettes
| 1-4 de `dip.s` : 1 le texte, 2 le choisi, 3 le titre, 4 l'aide ; IRQ masquées). Tous les
| registres rendus ; `dip.s` redessine son écran au retour. Deux rangées de huit bits, 0 ou 1.
| Gauche / droite : le bit ; haut / bas : la rangée ; A : le bit basculé, dans DD_MASQUE aussitôt.
| START : retour. Plan fixe seul, $7000 + 32 × colonne + ligne, REG_VRAMMOD à 32, police 8×8 du
| SFIX (tuile = ASCII).
| ==================================================================================

        .section .haut, "ax"
        .global _debug_dips, _dd_poser, _dd_appliquer, _dd_retirer, _dd_remettre
        .global DD_MASQUE

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    WATCHDOG, 0x300001
        .equ    P1CNT,    0x300000
        .equ    STATUS_B, 0x380000

        | Dans la zone mesurée libre de `menu.s` ($10F4B4-$10FBFF), au-dessus de la borne ($10FB20) ;
        | remis à zéro par le vidage du boot (`c0.s`, $10F300-$10FFFF).
        .equ    DD_MASQUE, 0x10FB22     | .w DIP 1 à l'octet haut ($10FB22), DIP 2 au bas
        .equ    DD_ZONE,   0x10FB24     | .l les deux octets dans la RAM du jeu
        .equ    BORNE_RAM, 0x10FB20     | bit 3 : CHEATS/DEBUG OFF (`reglages.s`)

        .equ    CASE_TITRE, 0x7000 + 15 * 32 + 3       | 8×16, lignes 3-4
        .equ    CASE_NGH,   0x7000 + 15 * 32 + 6
        .equ    CASE_BITS,  0x7000 + 12 * 32 + 9       | « 0 1 2 … 7 », colonnes 12-26
        .equ    CASE_DIP1,  0x7000 +  3 * 32 + 11
        .equ    CASE_DIP2,  0x7000 +  3 * 32 + 13
        .equ    CASE_NOTE,  0x7000 +  3 * 32 + 17
        .equ    CASE_AIDE1, 0x7000 +  3 * 32 + 28
        .equ    CASE_AIDE2, 0x7000 +  3 * 32 + 29
        .equ    COL_BIT0,   12          | le bit 0 en colonne 12, un bit toutes les deux colonnes

| ----------------------------------------------------------------------------------
| L'ÉCRAN. %d6 : la rangée (0 DIP 1, 1 DIP 2) ; %d7 : le bit ; %d5 : les boutons d'avant.
_debug_dips:
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        bsr     .Lsync
        jsr     _fix_clear
        move.w  #32, VRAMMOD
        move.w  #CASE_TITRE, %d1
        move.w  #0x3100, %d3
        lea     .Ltxt_titre, %a2
        bsr     .Lchaine_en
        move.w  #CASE_TITRE + 1, %d1
        move.w  #0x3200, %d3
        lea     .Ltxt_titre, %a2
        bsr     .Lchaine_en
        move.w  #CASE_NGH, %d1          | le jeu : son NGH, lu dans l'en-tête sous REG_CRTFIX
        move.w  #0x3000, %d3            | par `c0.s`, recopié en $D00124 (« Backup RAM »)
        lea     .Ltxt_ngh, %a2
        bsr     .Lchaine_en
        moveq   #0, %d0
        move.b  0xD00108, %d0
        lsl.w   #2, %d0
        lea     0xD00124, %a0
        move.w  (%a0,%d0.w), %d4
        swap    %d4
        moveq   #4, %d0
        bsr     .Lhex
        move.w  #CASE_BITS, %d1
        move.w  #0x1000, %d3
        lea     .Ltxt_bits, %a2
        bsr     .Lchaine_en
        move.w  #CASE_DIP1, %d1
        lea     .Ltxt_dip1, %a2
        bsr     .Lchaine_en
        move.w  #CASE_DIP2, %d1
        lea     .Ltxt_dip2, %a2
        bsr     .Lchaine_en
        move.w  #CASE_NOTE, %d1
        move.w  #0x4000, %d3
        lea     .Ltxt_note, %a2
        bsr     .Lchaine_en
        move.w  #CASE_AIDE1, %d1
        lea     .Ltxt_aide1, %a2
        bsr     .Lchaine_en
        move.w  #CASE_AIDE2, %d1
        lea     .Ltxt_aide2, %a2
        bsr     .Lchaine_en
        moveq   #0, %d6
        moveq   #0, %d7
        bsr     .Lrangees
        moveq   #0, %d5
        bsr     .Lentrees               | un bouton déjà tenu ne compte pas

.Lboucle:
        bsr     .Lsync
        bsr     .Lentrees
        btst    #5, %d0                 | START : retour
        bne.s   .Lsortie
        btst    #0, %d0                 | haut, bas : l'autre rangée
        bne.s   1f
        btst    #1, %d0
        beq.s   2f
1:      eori.w  #1, %d6
        bra.s   8f
2:      btst    #2, %d0                 | gauche
        beq.s   3f
        subq.w  #1, %d7
        andi.w  #7, %d7
        bra.s   8f
3:      btst    #3, %d0                 | droite
        beq.s   4f
        addq.w  #1, %d7
        andi.w  #7, %d7
        bra.s   8f
4:      btst    #4, %d0                 | A : le bit basculé
        beq.s   .Lboucle
        move.w  %d7, %d0
        tst.w   %d6
        bne.s   5f
        addq.w  #8, %d0                 | DIP 1 : l'octet haut
5:      move.w  DD_MASQUE, %d1
        bchg    %d0, %d1
        move.w  %d1, DD_MASQUE
8:      bsr.s   .Lrangees
        bra.s   .Lboucle

.Lsortie:
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rts

| LES DEUX RANGÉES, les bits de DD_MASQUE en 0 / 1, le choisi sous la palette 2.
| Clobbers %d0-%d4, %a2.
.Lrangees:
        moveq   #0, %d4                 | la rangée
1:      move.w  #CASE_DIP1 + COL_BIT0 * 32, %d1
        tst.w   %d4
        beq.s   2f
        move.w  #CASE_DIP2 + COL_BIT0 * 32, %d1
2:      move.w  %d1, VRAMADDR
        move.b  DD_MASQUE + 1, %d0      | DIP 2
        tst.w   %d4
        bne.s   3f
        move.b  DD_MASQUE, %d0          | DIP 1
3:      moveq   #0, %d2                 | le bit
4:      move.w  #0x1000, %d3
        cmp.w   %d6, %d4
        bne.s   5f
        cmp.w   %d7, %d2
        bne.s   5f
        move.w  #0x2000, %d3            | le choisi
5:      moveq   #0x30, %d1              | « 0 »
        btst    %d2, %d0
        beq.s   6f
        moveq   #0x31, %d1              | « 1 »
6:      add.w   %d3, %d1
        move.w  %d1, VRAMRW
        move.w  #0x1020, VRAMRW         | une espace : > 12 cycles après l'écriture d'avant
        addq.w  #1, %d2
        cmpi.w  #8, %d2
        bcs.s   4b
        addq.w  #1, %d4
        cmpi.w  #2, %d4
        bcs.s   1b
        rts

| ----------------------------------------------------------------------------------
| LA POSE, à la sortie de l'écran TEST (`dip.s`), REG_CRTFIX en place : CHEATS/DEBUG OFF, un
| masque nul, ou une zone refusée : le masque oublié, le moteur arrêté ; sinon DD_ZONE notée, le
| bit 15 de GL_MASQUE allumé, et les bits posés une première fois. Rend tous les registres.
_dd_poser:
        movem.l %d2/%a0, -(%sp)
        btst    #3, BORNE_RAM
        bne.s   8f
        tst.w   DD_MASQUE
        beq.s   8f
        bsr.s   .Lzone
        bmi.s   8f
        move.l  %a0, DD_ZONE
        bset    #7, GL_MASQUE           | le bit 15 du mot
        bsr.s   _dd_appliquer
        bra.s   9f
8:      clr.w   DD_MASQUE
        bclr    #7, GL_MASQUE
9:      movem.l (%sp)+, %d2/%a0
        rts

| LA ZONE DU JEU, comme `_bloc_jeu` (`c0.s`, mêmes bornes) mais sans bloc, et deux octets au moins :
| %a0 ; N si refusée. Clobbers %d2, %a0.
.Lzone:
        movea.l 0x10E, %a0
        moveq   #0, %d2
        move.w  0x112, %d2
        cmpi.w  #2, %d2
        bcs.s   9f
        cmpi.w  #0x1000, %d2
        bhi.s   9f
        cmpa.l  #0x100000, %a0
        blo.s   9f
        cmpa.l  #0x10F200, %a0
        bhs.s   9f
        move.l  %a0, -(%sp)
        add.l   %d2, (%sp)
        cmpi.l  #0x10F200, (%sp)+
        bhi.s   9f
        moveq   #0, %d2                 | N à 0
        rts
9:      moveq   #-1, %d2
        rts

| LE MOTEUR : les bits du masque mis à 1 dans la zone. Appelé par `cheats.s` à chaque SYSTEM_IO, le
| bit 15 de GL_MASQUE allumé. Rend tous les registres.
_dd_appliquer:
        move.l  %a0, -(%sp)
        movea.l DD_ZONE, %a0
        move.w  %d0, -(%sp)
        move.w  DD_MASQUE, %d0
        or.b    %d0, 1(%a0)             | DIP 2
        lsr.w   #8, %d0
        or.b    %d0, (%a0)              | DIP 1
        move.w  (%sp)+, %d0
        movea.l (%sp)+, %a0
        rts

| RETIRER / REMETTRE LE MASQUE dans la zone %a0, %d2 le compte de `dbra` de `_bloc_jeu` (0 : un
| seul octet). Appelés par `_sauver_jeu` (`c0.s`) autour de sa copie, le masque vu non nul ; le
| passage de slot l'ayant remis à zéro, c'est la zone du jeu de la pose. Rendent tous les registres.
_dd_retirer:
        movem.l %d0-%d1, -(%sp)
        move.w  DD_MASQUE, %d0
        not.w   %d0
        move.w  %d0, %d1
        lsr.w   #8, %d1
        and.b   %d1, (%a0)              | DIP 1
        tst.w   %d2
        beq.s   9f
        and.b   %d0, 1(%a0)             | DIP 2
9:      movem.l (%sp)+, %d0-%d1
        rts
_dd_remettre:
        movem.l %d0-%d1, -(%sp)
        move.w  DD_MASQUE, %d0
        move.w  %d0, %d1
        lsr.w   #8, %d1
        or.b    %d1, (%a0)
        tst.w   %d2
        beq.s   9f
        or.b    %d0, 1(%a0)
9:      movem.l (%sp)+, %d0-%d1
        rts

| ----------------------------------------------------------------------------------
| LES OUTILS, comme `tests.s`.
.Lchaine_en:
        move.w  %d1, VRAMADDR
.Lchaine:
        moveq   #0, %d2
        move.b  (%a2)+, %d2
        beq.s   1f
        bsr.s   .Lcar
        bra.s   .Lchaine
1:      rts
.Lcar:
        add.w   %d3, %d2
        move.w  %d2, VRAMRW
        rts
| %d0 CHIFFRES HEXADÉCIMAUX, les hauts de %d4 d'abord. Clobbers %d0, %d2, %d4.
.Lhex:
        subq.w  #1, %d0
1:      rol.l   #4, %d4
        moveq   #0x0F, %d2
        and.w   %d4, %d2
        cmpi.w  #10, %d2
        bcs.s   2f
        addq.w  #7, %d2
2:      addi.w  #0x30, %d2
        bsr.s   .Lcar
        dbra    %d0, 1b
        rts

| LES BOUTONS DE P1, comme `tests.s`. %d5 : l'état d'avant ; %d0 : les fronts. Bits : 0 haut,
| 1 bas, 2 gauche, 3 droite, 4 A, 5 START. Clobbers %d1, %d2.
.Lentrees:
        move.b  P1CNT, %d2
        not.b   %d2
        andi.b  #0x1F, %d2
        move.b  STATUS_B, %d1
        not.b   %d1
        andi.b  #0x01, %d1
        lsl.b   #5, %d1
        or.b    %d1, %d2
        move.b  %d5, %d0
        not.b   %d0
        and.b   %d2, %d0
        move.b  %d2, %d5
        rts

| LE PASSAGE DE LA LIGNE $1F0, copie de celle de `tests.s`. Clobbers %d0.
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

        .balign 2
.Ltxt_titre:    .asciz  "DEBUG DIPS"
.Ltxt_ngh:      .asciz  "NGH "
.Ltxt_bits:     .asciz  "0 1 2 3 4 5 6 7"
.Ltxt_dip1:     .asciz  "DIP 1"
.Ltxt_dip2:     .asciz  "DIP 2"
.Ltxt_note:     .asciz  "SET UNTIL POWER OFF"
.Ltxt_aide1:    .asciz  "LEFT/RIGHT/UP/DOWN:SELECT  A:FLIP"
.Ltxt_aide2:    .asciz  "START:BACK"
        .balign 2
