| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| MEMORY EDITOR — the work RAM ($100000-$10FFFF) in hexadecimal, from the in-game menu
| (`menu.s`): view it, move around in it, modify a byte, FREEZE up to GL_MAX of them (the custom
| cheat: `cheats.s` rewrites each freeze at each call of SYSTEM_IO). On 2026-10-23.
|
| NO ORACLE: the memory editor of no BIOS is read. "measured": a named record; "read
| in": a page of the NeoGeo Development Wiki; "ASSUMED": neither one nor the other.
|
| WHAT IS READ, WHAT IS WRITTEN. All of the work RAM is read, the BIOS area included
| ($10F300-$10FFFF, "BIOS RAM locations": the page gives it to the BIOS). Nothing is written or
| frozen from $10F300 on: neither the BIOS RAM, nor the menu's save area ($10F4C0-$10FB1F,
| in that area). The screen says so (READ ONLY), A and D do nothing there, and the freeze engine
| itself refuses an offset of $F300 or more (`cheats.s`). The read goes through the 68000 and
| touches no register of the board. During the pause the game is stopped: what is read is
| the RAM as it left it at its call of SYSTEM_IO.
|
| THE SCREEN, the frame of the menu's sub-screens (28 × 14, `menu.s`), the cartridge's font:
|   0      MEMORY EDITOR (title), and the cursor's address (column 20);
|   2-9    eight lines of eight bytes: the address (column 2), four bytes (column 9),
|          four (column 18). The cursor's byte under the choice's palette, a frozen byte under
|          the title's;
|   10, 13 the help;
|   11-12  FROZEN, and the freezes: "10XXXX:VV", two per line, or NONE.
|
| THE CONTROLS, P1 on edge (a held direction repeats: after REP_DEBUT frames, once
| every REP_PAS):
|   up/down one line (8 bytes), left/right one byte; B held and up/down one page
|   (64 bytes); all wrapping over the 64 KiB;
|   C: GOTO, the four-digit address (left/right the digit, up/down its value, A goes
|       there, B gives up);
|   A: SET VALUE (up/down ±1, left/right ±$10, A writes the byte — and the freeze's value if
|       it is frozen —, B gives up);
|   D: freezes the byte at its value, or unfreezes it if it is frozen; GL_MAX taken: nothing;
|   START: the menu.
| The cursor and the window (ME_ADR, ME_HAUT) stay from one opening to the next; cleared at boot.
| ==================================================================================

        .section .haut, "ax"
        .global _memoire_ecran

        .equ    RAM,       0x100000
        .equ    BORNE,     0xF300       | $10F300: the BIOS area (`cheats.s`, GL_BORNE)
        .equ    GL_MAX,    4
        | In the area of `cheats.s` measured free, after the freezes: kept between two openings.
        .equ    ME_ADR,    0x10FB1C     | .w the cursor's offset
        .equ    ME_HAUT,   0x10FB1E     | .w that of the first line, a multiple of 8
        | Under the menu's stack (`menu.s`), after GAME SETTINGS.
        .equ    ME_MODE,   0x10F9D4     | .w 0 browse, 1 SET VALUE, 2 GOTO
        .equ    ME_VAL,    0x10F9D6     | .w the current value, or GOTO's address
        .equ    ME_CHIF,   0x10F9D8     | .w GOTO's digit, 0 the highest
        .equ    REP_DEBUT, 20
        .equ    REP_PAS,   4
        .equ    L_HEX,     2            | the frame line of the first line of bytes

_memoire_ecran:
        bsr     _mn_sous_ouvrir
        clr.w   ME_MODE
        clr.w   MN_REP
        andi.w  #0xFFF8, ME_HAUT        | any window left by a game: realigned
        bsr     .Lcaler
        bsr     .Ltout

.Lboucle:
        bsr     _mn_sync
        bsr     _mn_entrees
        | THE REPETITION: a held direction gives an edge again, after REP_DEBUT frames, then
        | every REP_PAS.
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
        btst    #8, %d0                 | START: the menu, whatever the mode
        beq.s   1f
        rts
1:      move.w  ME_MODE, %d1
        beq.s   .Lparcourir
        subq.w  #1, %d1
        beq     .Lvaleur
        bra     .Lgoto

| ----------------------------------------------------------------------------------
| BROWSE. %d0: the edges; %d5: the state (B held).
.Lparcourir:
        move.w  ME_ADR, %d1
        btst    #0, %d0                 | up
        beq.s   2f
        moveq   #-8, %d2
        btst    #5, %d5                 | B held: one page
        beq.s   1f
        moveq   #-64, %d2
1:      add.w   %d2, %d1
        btst    #5, %d5
        beq     .Lp_poser
        add.w   %d2, ME_HAUT            | the page: the window follows, the cursor keeps its place in it
        bra     .Lp_poser
2:      btst    #1, %d0                 | down
        beq.s   2f
        moveq   #8, %d2
        btst    #5, %d5
        beq.s   1b
        moveq   #64, %d2
        bra.s   1b
2:      btst    #2, %d0                 | left
        beq.s   2f
        subq.w  #1, %d1
        bra     .Lp_poser
2:      btst    #3, %d0                 | right
        beq.s   2f
        addq.w  #1, %d1
        bra     .Lp_poser
2:      btst    #6, %d0                 | C: GOTO
        beq.s   2f
        move.w  %d1, ME_VAL
        clr.w   ME_CHIF
        move.w  #2, ME_MODE
        bra     .Lp_dessin
2:      cmpi.w  #BORNE, %d1
        bcc     .Lboucle                | the BIOS area: neither A nor D
        lea     RAM, %a0
        andi.l  #0xFFFF, %d1
        btst    #4, %d0                 | A: SET VALUE
        beq.s   2f
        moveq   #0, %d2
        move.b  (%a0,%d1.l), %d2
        move.w  %d2, ME_VAL
        move.w  #1, ME_MODE
        bra.s   .Lp_dessin
2:      btst    #7, %d0                 | D: freeze, or unfreeze
        beq     .Lboucle
        bsr     .Lchercher_gel          | %d3: its number, or -1
        bmi.s   3f
        bclr    %d3, GL_MASQUE + 1      | unfrozen
        bra.s   .Lp_dessin
3:      moveq   #0, %d3                 | the first free one
4:      btst    %d3, GL_MASQUE + 1
        beq.s   5f
        addq.w  #1, %d3
        cmpi.w  #GL_MAX, %d3
        bcs.s   4b
        bra     .Lboucle                | all taken: nothing
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

| THE WINDOW realigned on the cursor (unsigned words, wrapping over the 64 KiB). Clobbers %d1, %d2.
.Lcaler:
        move.w  ME_ADR, %d1
        move.w  %d1, %d2
        sub.w   ME_HAUT, %d2
        cmpi.w  #64, %d2
        bcs.s   9f                      | in the window
        cmp.w   ME_HAUT, %d1
        bcc.s   1f
        andi.w  #0xFFF8, %d1            | above: its line at the top
        move.w  %d1, ME_HAUT
        rts
1:      andi.w  #0xFFF8, %d1            | below: its line at the bottom
        subi.w  #56, %d1
        move.w  %d1, ME_HAUT
9:      rts

| THE FREEZE OF BYTE %d1 (offset): %d3 its number and N at 0, or -1 and N at 1. Clobbers %d2, %a1.
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
| SET VALUE. Up/down ±1, left/right ±$10; A writes, B gives up.
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
        btst    #5, %d0                 | B: nothing written
        bne.s   8f
        btst    #4, %d0                 | A: the byte written
        beq.s   9f
        move.w  ME_ADR, %d1
        cmpi.w  #BORNE, %d1             | guarded here too: the mode does not open beyond
        bcc.s   8f
        andi.l  #0xFFFF, %d1
        lea     RAM, %a0
        move.b  ME_VAL + 1, (%a0,%d1.l)
        bsr     .Lchercher_gel
        bmi.s   8f
        lsl.w   #2, %d3                 | frozen: its value follows
        lea     GL_TABLE, %a1
        move.b  ME_VAL + 1, 2(%a1,%d3.w)
8:      clr.w   ME_MODE
9:      bsr     .Ltout
        bra     .Lboucle

| GOTO. Left/right the digit, up/down its value; A goes there, B gives up.
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
        moveq   #3, %d3                 | the digit's shift: 4 × (3 − digit)
        sub.w   %d2, %d3
        lsl.w   #2, %d3
        moveq   #1, %d1
        lsl.w   %d3, %d1                | one unit of that digit
        move.w  #0x000F, %d4
        lsl.w   %d3, %d4                | its mask
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
2:      and.w   %d4, %d6                | only the digit changes, without carry
        not.w   %d4
        and.w   %d4, %d2
        or.w    %d6, %d2
        move.w  %d2, ME_VAL
3:      btst    #5, %d0                 | B: nothing
        bne.s   8f
        btst    #4, %d0                 | A: the cursor goes there, its line at the top
        beq.s   9f
        move.w  ME_VAL, %d1
        move.w  %d1, ME_ADR
        andi.w  #0xFFF8, %d1
        move.w  %d1, ME_HAUT
8:      clr.w   ME_MODE
9:      bsr     .Ltout
        bra     .Lboucle

| ----------------------------------------------------------------------------------
| THE WHOLE SCREEN, line by line. Clobbers %d0-%d4, %d6, %a0-%a3.
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

| LINE %d4 in MN_BUF and MN_COUL. Clobbers %d0-%d4, %d6, %a0-%a3.
.Lcomposer:
        tst.w   %d4
        bne.s   .Lc_hex
        lea     .Ltxt_titre, %a3
        moveq   #L_TITRE, %d4
        moveq   #2, %d0
        moveq   #1, %d1
        bsr     _mn_texte
        move.w  ME_ADR, %d2             | the address: the cursor's, or GOTO's
        cmpi.w  #2, ME_MODE
        bne.s   1f
        move.w  ME_VAL, %d2
1:      lea     MN_BUF + 20, %a1
        bsr     .Ladresse
        cmpi.w  #2, ME_MODE
        bne.s   9f
        lea     MN_COUL + 22, %a1       | GOTO's digit, under the choice's palette
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
        add.w   ME_HAUT, %d6            | %d6: the offset of the line's first byte
        move.w  %d6, %d2
        lea     MN_BUF + 2, %a1
        bsr     .Ladresse
        moveq   #0, %d4                 | the byte of the line, 0 to 7
1:      moveq   #9, %d0                 | its column: 9 + 2 × k, + 1 for the second group
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
        add.w   %d4, %d1                | the byte's offset
        andi.l  #0xFFFF, %d1
        lea     RAM, %a0
        moveq   #0, %d2
        move.b  (%a0,%d1.l), %d2
        moveq   #0, %d3                 | the role
        movem.l %d1-%d2/%a1, -(%sp)
        bsr     .Lchercher_gel
        movem.l (%sp)+, %d1-%d2/%a1
        bmi.s   3f
        moveq   #1, %d3                 | frozen: the title
3:      cmp.w   ME_ADR, %d1
        bne.s   4f
        moveq   #2, %d3                 | the cursor: the choice
        cmpi.w  #1, ME_MODE
        bne.s   4f
        move.w  ME_VAL, %d2             | SET VALUE: the current value
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
        lea     .Ltxt_page, %a3         | the help of line 10, depending on the mode
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
        lea     .Ltxt_aide, %a3         | the help of line 13
        moveq   #L_AIDE, %d4
        move.w  ME_MODE, %d1
        bne.s   3f
        cmpi.w  #BORNE, ME_ADR
        bcs.s   1b
        lea     .Ltxt_lecture, %a3      | the BIOS area
        moveq   #L_LECTURE, %d4
        bra.s   1b
3:      lea     .Ltxt_val, %a3
        moveq   #L_VAL, %d4
        subq.w  #1, %d1
        beq.s   1b
        lea     .Ltxt_goto, %a3
        moveq   #L_GOTO, %d4
        bra.s   1b

| LINES 11 AND 12: FROZEN, then freezes k and k + 1 (k = 0 on line 11, 2 on line 12), or
| NONE if there is none.
.Lc_gels:
        cmpi.w  #11, %d4
        beq.s   1f
        cmpi.w  #12, %d4
        bne     9f
1:      move.w  %d4, %d6
        subi.w  #11, %d6
        add.w   %d6, %d6                | the line's first freeze
        tst.w   %d6
        bne.s   2f
        lea     .Ltxt_gels, %a3
        moveq   #6, %d4
        moveq   #2, %d0
        moveq   #0, %d1
        bsr     _mn_texte
        tst.b   GL_MASQUE + 1           | the freezes; bit 15 is the debug dips' one (`debug.s`)
        bne.s   2f
        lea     .Ltxt_aucun, %a3
        moveq   #4, %d4
        moveq   #9, %d0
        moveq   #0, %d1
        bra     _mn_texte
2:      moveq   #0, %d0                 | the rank of the freeze shown on the line, 0 or 1
        moveq   #0, %d3                 | the freeze, 0 to GL_MAX − 1
        moveq   #0, %d4                 | the active freezes already seen
3:      btst    %d3, GL_MASQUE + 1
        beq.s   5f
        move.w  %d4, %d1
        sub.w   %d6, %d1
        bcs.s   4f                      | a freeze of an earlier line
        cmpi.w  #2, %d1
        bcc.s   9f                      | the line is full
        lea     MN_BUF + 9, %a1         | column 9, or 19 for the second
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
        move.b  #0x3A, (%a1)+           | ":"
        moveq   #0, %d2
        move.b  2(%a0), %d2
        bsr.s   .Loctet
        movem.l (%sp)+, %d3-%d4
4:      addq.w  #1, %d4
5:      addq.w  #1, %d3
        cmpi.w  #GL_MAX, %d3
        bcs.s   3b
9:      rts

| "10XXXX" at (%a1)+, %d2.w the offset. Clobbers %d2, %d3.
.Ladresse:
        move.b  #0x31, (%a1)+
        move.b  #0x30, (%a1)+
        move.w  %d2, -(%sp)
        lsr.w   #8, %d2
        bsr.s   .Loctet
        move.w  (%sp)+, %d2             | then the low byte: `.Loctet`, which follows

| BYTE %d2.b as two hexadecimal digits at (%a1)+. Clobbers %d2, %d3.
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
| THE DATA.
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
