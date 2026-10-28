| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| L'ÉCRAN ABOUT — les mentions légales et les crédits. Un écran de l'écran TEST : la ligne ABOUT
| (`dip.s`), juste avant CABINET SETTINGS.
|
| CE QU'IL DIT : le nom et la version (la chaîne de l'écran de boot, `ecran.s`, pour n'en tenir
| qu'une), le copyright, l'absence de garantie, le droit de redistribuer sous la GPL version 3 ou
| ultérieure, où lire la licence et le source, et le testeur du matériel. Ce sont les « Appropriate
| Legal Notices » que la GPLv3 définit (§0), et que son §5 d) demande à une interface interactive
| d'une version transmise d'afficher.
|
| L'ÉCRAN, `_a_propos` : appelé par `jsr` depuis `dip.s`, dans son état (REG_BRDFIX, palettes 1-4
| de `dip.s` : 1 le texte, 3 le titre, 4 l'aide ; IRQ masquées). Tous les registres rendus ;
| `dip.s` redessine son écran au retour. START : retour, rien d'autre ne compte. Plan fixe seul,
| $7000 + 32 × colonne + ligne, REG_VRAMMOD à 32. Le titre en 8×16 (tuiles $100 / $200 + ASCII,
| comme `debug.s`), pour le « v » minuscule de la version, mesuré dans cette police seulement
| (`ecran.s`, LES GLYPHES) ; le reste en majuscules, police 8×8 du SFIX (tuile = ASCII).
| ==================================================================================

        .section .haut, "ax"
        .global _a_propos

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    WATCHDOG, 0x300001
        .equ    STATUS_B, 0x380000

        .equ    CASE_TITRE, 0x7000 + 3 * 32 + 3        | 8×16, lignes 3-4
        .equ    COL3,       0x7000 + 3 * 32             | la colonne 3, ligne 0

| ----------------------------------------------------------------------------------
| L'ÉCRAN. %d5 : les boutons d'avant.
_a_propos:
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        bsr     .Lsync
        jsr     _fix_clear
        move.w  #32, VRAMMOD
        move.w  #CASE_TITRE, %d1
        move.w  #0x3100, %d3
        bsr.s   .Ltitre
        move.w  #CASE_TITRE + 1, %d1
        move.w  #0x3200, %d3
        bsr.s   .Ltitre
        lea     .Llignes, %a0           | .w la case, .w la palette, le texte, aligné
1:      move.w  (%a0)+, %d1
        beq.s   2f
        move.w  (%a0)+, %d3
        movea.l %a0, %a2
        bsr.s   .Lchaine_en
        move.l  %a2, %d0                | après le zéro, au mot suivant
        addq.l  #1, %d0
        andi.w  #0xFFFE, %d0
        movea.l %d0, %a0
        bra.s   1b
2:      moveq   #0, %d5
        bsr.s   .Lentrees               | un bouton déjà tenu ne compte pas
.Lboucle:
        bsr.s   .Lsync
        bsr.s   .Lentrees
        btst    #5, %d0                 | START : retour
        beq.s   .Lboucle
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rts

| UNE RANGÉE DU TITRE : le nom, puis la version, à la suite (REG_VRAMMOD avance d'une colonne).
.Ltitre:
        move.w  %d1, VRAMADDR
        lea     .Ltxt_nom, %a2
        bsr.s   .Lchaine
        lea     _txt_version, %a2
        bra.s   .Lchaine

| ----------------------------------------------------------------------------------
| LES OUTILS, comme `debug.s`.
.Lchaine_en:
        move.w  %d1, VRAMADDR
.Lchaine:
        moveq   #0, %d2
        move.b  (%a2)+, %d2
        beq.s   1f
        add.w   %d3, %d2
        move.w  %d2, VRAMRW
        bra.s   .Lchaine
1:      rts

| LES BOUTONS DE P1, comme `debug.s`. %d5 : l'état d'avant ; %d0 : les fronts. Bit 5 : START.
| Clobbers %d1, %d2.
.Lentrees:
        jsr     _panneau_p1             | %d0 : P1, manette ou panneau traduit (`panneau.s`)
        move.b  %d0, %d2
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

| LE PASSAGE DE LA LIGNE $1F0, copie de celle de `debug.s`. Clobbers %d0.
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
| LES DONNÉES. Chaque ligne : la case (colonne 3), la palette, le texte ; une case nulle clôt.
        .balign 2
.Ltxt_nom:      .asciz  "SPRIXE BIOS "
        .balign 2
.Llignes:
        .word   COL3 + 7, 0x1000
        .asciz  "COPYRIGHT 2026 THIBAUT LION"
        .balign 2
        .word   COL3 + 9, 0x1000
        .asciz  "THIS PROGRAM COMES WITH"
        .balign 2
        .word   COL3 + 10, 0x1000
        .asciz  "ABSOLUTELY NO WARRANTY."
        .balign 2
        .word   COL3 + 12, 0x1000
        .asciz  "IT IS FREE SOFTWARE: YOU MAY"
        .balign 2
        .word   COL3 + 13, 0x1000
        .asciz  "REDISTRIBUTE IT UNDER THE GNU"
        .balign 2
        .word   COL3 + 14, 0x1000
        .asciz  "GPL VERSION 3 OR LATER."
        .balign 2
        .word   COL3 + 16, 0x1000
        .asciz  "LICENSE AND SOURCE CODE:"
        .balign 2
        .word   COL3 + 17, 0x1000
        .asciz  "GITHUB.COM/LID-LABS/SPRIXE-BIOS"
        .balign 2
        .word   COL3 + 20, 0x1000
        .asciz  "HARDWARE TESTING:"
        .balign 2
        .word   COL3 + 21, 0x1000
        .asciz  "SEBASTIAN KLOETZER"
        .balign 2
        .word   COL3 + 29, 0x4000
        .asciz  "START:BACK"
        .balign 2
        .word   0
