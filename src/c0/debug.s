| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| THE DEBUG DIPS — sixteen switches that games read to open their debugging tools. A screen of
| the TEST screen: CABINET SETTINGS (`dip.s`), fifth line, DEBUG DIPS.
|
| NO ORACLE: neither the reference BIOS nor a third-party BIOS is read, nor the code of a game.
| "measured": a named record; "read in": a page of the NeoGeo Development Wiki; "ASSUMED":
| neither one nor the other.
|
| WHAT THE DEBUG DIPS ARE, read in "Debug DIPs" and "68k program header": two bytes
| of the game's work RAM, "usually" the first two of the area that the long at
| $10E of the header points to — the area the BIOS saves to backup RAM (`c0.s`, `_sauver_jeu`). "The
| Unibios, a debug BIOS, and some emulators allow them to be set". MEASURED
| (`measured/2026-10-25-debug-dips.tsv`): on kof94, DIP 1 bit 0 opens DEBUG OBJE, a sprite
| viewer, DIP 2 bits 1, 4, 5 and 7 four tools; on 36 of the 128 games recorded, these two bytes
| leave zero in game without anyone touching them: they are then the game's data.
|
| HENCE THE MODEL: A MASK, NOT A VALUE. The BIOS holds DD_MASQUE (DIP 1 in the high byte,
| DIP 2 in the low one), in RAM only, like the cheats (reset to zero at boot and at each slot
| switch, `_cheats_oublier`): it sets these bits to 1 in the first two bytes of the game's area,
| and touches no other. AT EACH CALL OF SYSTEM_IO, through the cheat engine (`cheats.s`,
| bit 15 of GL_MASQUE), in demo as in a game: MEASURED, kof94 resets $100000 to zero at each
| demo start (same record, section 4), a single set did not hold there five frames.
| The BIOS never lets them go to backup RAM: `_sauver_jeu` (`c0.s`) removes them from the area
| for the time of the copy, then puts them back. A power-off therefore erases them, and a game whose
| bytes these are data keeps in its save only its own bits. What it costs: a bit that
| the game would have set itself, at the same place as the mask, goes to zero in the save; and as long
| as the mask is set, these bits stay at 1 in its data.
| THE AREA: the long at $10E and the size at $112, like `_bloc_jeu` (`c0.s`, same bounds), read at
| the set; two bytes at least, otherwise the mask is forgotten.
|
| CHEATS/DEBUG OFF (DECISIONS §16): the DEBUG DIPS line says OFF and no longer opens, and
| `_dd_poser` resets the mask to zero at the exit of the TEST screen: the BIOS no longer writes any bit.
| What another BIOS would have left in the game's save is not erased: nothing distinguishes it
| from a game's data.
|
| WHY THE TEST SCREEN, and not the in-game menu: one more line in the in-game menu moved the
| key paths of the records there ("up" from RESUME leads to MEMORY EDITOR, "up" twice to
| GAME SETTINGS) and changed the drawing of its loop, whose cycles decide a frame of
| RESTART (DECISIONS §16, point 7); the fifth line of CABINET SETTINGS moves no
| path. And the mask is set before the game starts: a tool the game only opens at its
| start-up sees it (ASSUMED for games other than kof94, which reads its bits continuously).
|
| THE SCREEN, `_debug_dips`: called by `jsr` from `dip.s`, in its state (REG_BRDFIX, palettes
| 1-4 of `dip.s`: 1 the text, 2 the chosen one, 3 the title, 4 the help; IRQs masked). All
| registers returned; `dip.s` redraws its screen on return. Two rows of eight bits, 0 or 1.
| Left / right: the bit; up / down: the row; A: the bit toggled, in DD_MASQUE at once.
| START: back. Fix layer only, $7000 + 32 × column + line, REG_VRAMMOD at 32, 8×8 font of the
| SFIX (tile = ASCII).
| ==================================================================================

        .section .haut, "ax"
        .global _debug_dips, _dd_poser, _dd_appliquer, _dd_retirer, _dd_remettre
        .global DD_MASQUE

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    WATCHDOG, 0x300001
        .equ    STATUS_B, 0x380000

        | In the area of `menu.s` measured free ($10F4B4-$10FBFF), above the bound ($10FB20);
        | reset to zero by the boot clearing (`c0.s`, $10F300-$10FFFF).
        .equ    DD_MASQUE, 0x10FB22     | .w DIP 1 in the high byte ($10FB22), DIP 2 in the low one
        .equ    DD_ZONE,   0x10FB24     | .l the two bytes in the game's RAM
        .equ    BORNE_RAM, 0x10FB20     | bit 3: CHEATS/DEBUG OFF (`reglages.s`)

        .equ    CASE_TITRE, 0x7000 + 15 * 32 + 3       | 8×16, lines 3-4
        .equ    CASE_NGH,   0x7000 + 15 * 32 + 6
        .equ    CASE_BITS,  0x7000 + 12 * 32 + 9       | "0 1 2 … 7", columns 12-26
        .equ    CASE_DIP1,  0x7000 +  3 * 32 + 11
        .equ    CASE_DIP2,  0x7000 +  3 * 32 + 13
        .equ    CASE_NOTE,  0x7000 +  3 * 32 + 17
        .equ    CASE_AIDE1, 0x7000 +  3 * 32 + 28
        .equ    CASE_AIDE2, 0x7000 +  3 * 32 + 29
        .equ    COL_BIT0,   12          | bit 0 in column 12, one bit every two columns

| ----------------------------------------------------------------------------------
| THE SCREEN. %d6: the row (0 DIP 1, 1 DIP 2); %d7: the bit; %d5: the previous buttons.
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
        move.w  #CASE_NGH, %d1          | the game: its NGH, read from the header under REG_CRTFIX
        move.w  #0x3000, %d3            | by `c0.s`, copied to $D00124 ("Backup RAM")
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
        bsr     .Lentrees               | a button already held does not count

.Lboucle:
        bsr     .Lsync
        bsr     .Lentrees
        btst    #5, %d0                 | START: back
        bne.s   .Lsortie
        btst    #0, %d0                 | up, down: the other row
        bne.s   1f
        btst    #1, %d0
        beq.s   2f
1:      eori.w  #1, %d6
        bra.s   8f
2:      btst    #2, %d0                 | left
        beq.s   3f
        subq.w  #1, %d7
        andi.w  #7, %d7
        bra.s   8f
3:      btst    #3, %d0                 | right
        beq.s   4f
        addq.w  #1, %d7
        andi.w  #7, %d7
        bra.s   8f
4:      btst    #4, %d0                 | A: the bit toggled
        beq.s   .Lboucle
        move.w  %d7, %d0
        tst.w   %d6
        bne.s   5f
        addq.w  #8, %d0                 | DIP 1: the high byte
5:      move.w  DD_MASQUE, %d1
        bchg    %d0, %d1
        move.w  %d1, DD_MASQUE
8:      bsr.s   .Lrangees
        bra.s   .Lboucle

.Lsortie:
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rts

| THE TWO ROWS, the bits of DD_MASQUE as 0 / 1, the chosen one under palette 2.
| Clobbers %d0-%d4, %a2.
.Lrangees:
        moveq   #0, %d4                 | the row
1:      move.w  #CASE_DIP1 + COL_BIT0 * 32, %d1
        tst.w   %d4
        beq.s   2f
        move.w  #CASE_DIP2 + COL_BIT0 * 32, %d1
2:      move.w  %d1, VRAMADDR
        move.b  DD_MASQUE + 1, %d0      | DIP 2
        tst.w   %d4
        bne.s   3f
        move.b  DD_MASQUE, %d0          | DIP 1
3:      moveq   #0, %d2                 | the bit
4:      move.w  #0x1000, %d3
        cmp.w   %d6, %d4
        bne.s   5f
        cmp.w   %d7, %d2
        bne.s   5f
        move.w  #0x2000, %d3            | the chosen one
5:      moveq   #0x30, %d1              | "0"
        btst    %d2, %d0
        beq.s   6f
        moveq   #0x31, %d1              | "1"
6:      add.w   %d3, %d1
        move.w  %d1, VRAMRW
        move.w  #0x1020, VRAMRW         | a space: > 12 cycles after the previous write
        addq.w  #1, %d2
        cmpi.w  #8, %d2
        bcs.s   4b
        addq.w  #1, %d4
        cmpi.w  #2, %d4
        bcs.s   1b
        rts

| ----------------------------------------------------------------------------------
| THE SET, at the exit of the TEST screen (`dip.s`), REG_CRTFIX in place: CHEATS/DEBUG OFF, a
| zero mask, or a refused area: the mask forgotten, the engine stopped; otherwise DD_ZONE noted,
| bit 15 of GL_MASQUE lit, and the bits set a first time. Returns all registers.
_dd_poser:
        movem.l %d2/%a0, -(%sp)
        btst    #3, BORNE_RAM
        bne.s   8f
        tst.w   DD_MASQUE
        beq.s   8f
        bsr.s   .Lzone
        bmi.s   8f
        move.l  %a0, DD_ZONE
        bset    #7, GL_MASQUE           | bit 15 of the word
        bsr.s   _dd_appliquer
        bra.s   9f
8:      clr.w   DD_MASQUE
        bclr    #7, GL_MASQUE
9:      movem.l (%sp)+, %d2/%a0
        rts

| THE GAME'S AREA, like `_bloc_jeu` (`c0.s`, same bounds) but without block, and two bytes at least:
| %a0; N if refused. Clobbers %d2, %a0.
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
        moveq   #0, %d2                 | N at 0
        rts
9:      moveq   #-1, %d2
        rts

| THE ENGINE: the mask's bits set to 1 in the area. Called by `cheats.s` at each SYSTEM_IO, with
| bit 15 of GL_MASQUE lit. Returns all registers.
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

| REMOVE / PUT BACK THE MASK in area %a0, %d2 the `dbra` count of `_bloc_jeu` (0: a
| single byte). Called by `_sauver_jeu` (`c0.s`) around its copy, the mask seen non-zero; the
| slot switch having reset it to zero, it is the game's area of the set. Return all registers.
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
| THE TOOLS, like `tests.s`.
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
| %d0 HEXADECIMAL DIGITS, the high ones of %d4 first. Clobbers %d0, %d2, %d4.
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

| P1'S BUTTONS, like `tests.s`. %d5: the previous state; %d0: the edges. Bits: 0 up,
| 1 down, 2 left, 3 right, 4 A, 5 START. Clobbers %d1, %d2.
.Lentrees:
        jsr     _panneau_p1             | %d0: P1, joystick or translated panel (`panneau.s`)
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

| THE PASSING OF LINE $1F0, copy of the one in `tests.s`. Clobbers %d0.
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
