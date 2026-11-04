| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| THE ABOUT SCREEN — the legal notices and the credits. A screen of the TEST screen: the ABOUT line
| (`dip.s`), just before CABINET SETTINGS.
|
| WHAT IT SAYS: the name and the version (the string of the boot screen, `ecran.s`, so as to keep
| only one), the copyright, the absence of warranty, the right to redistribute under the GPL version 3 or
| later, where to read the licence and the source, and the hardware tester. These are the "Appropriate
| Legal Notices" that the GPLv3 defines (§0), and that its §5 d) asks an interactive interface
| of a conveyed version to display.
|
| THE SCREEN, `_a_propos`: called by `jsr` from `dip.s`, in its state (REG_BRDFIX, palettes 1-4
| of `dip.s`: 1 the text, 3 the title, 4 the help; IRQs masked). All registers returned;
| `dip.s` redraws its screen on return. START: back, nothing else counts. Fix layer only,
| $7000 + 32 × column + line, REG_VRAMMOD at 32. The title in 8×16 (tiles $100 / $200 + ASCII,
| like `debug.s`), for the lowercase "v" of the version, measured in this font only
| (`ecran.s`, LES GLYPHES); the rest in capitals, 8×8 font of the SFIX (tile = ASCII).
| ==================================================================================

        .section .haut, "ax"
        .global _a_propos

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    WATCHDOG, 0x300001
        .equ    STATUS_B, 0x380000

        .equ    CASE_TITRE, 0x7000 + 3 * 32 + 3        | 8×16, lines 3-4
        .equ    COL3,       0x7000 + 3 * 32             | column 3, line 0

| ----------------------------------------------------------------------------------
| THE SCREEN. %d5: the previous buttons.
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
        lea     .Llignes, %a0           | .w the cell, .w the palette, the text, aligned
1:      move.w  (%a0)+, %d1
        beq.s   2f
        move.w  (%a0)+, %d3
        movea.l %a0, %a2
        bsr.s   .Lchaine_en
        move.l  %a2, %d0                | after the zero, at the next word
        addq.l  #1, %d0
        andi.w  #0xFFFE, %d0
        movea.l %d0, %a0
        bra.s   1b
2:      moveq   #0, %d5
        bsr.s   .Lentrees               | a button already held does not count
.Lboucle:
        bsr.s   .Lsync
        bsr.s   .Lentrees
        btst    #5, %d0                 | START: back
        beq.s   .Lboucle
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rts

| ONE ROW OF THE TITLE: the name, then the version, following on (REG_VRAMMOD advances one column).
.Ltitre:
        move.w  %d1, VRAMADDR
        lea     .Ltxt_nom, %a2
        bsr.s   .Lchaine
        lea     _txt_version, %a2
        bra.s   .Lchaine

| ----------------------------------------------------------------------------------
| THE TOOLS, like `debug.s`.
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

| P1'S BUTTONS, like `debug.s`. %d5: the previous state; %d0: the edges. Bit 5: START.
| Clobbers %d1, %d2.
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

| THE PASSING OF LINE $1F0, copy of the one in `debug.s`. Clobbers %d0.
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
| THE DATA. Each line: the cell (column 3), the palette, the text; a zero cell closes.
        .balign 2
.Ltxt_nom:      .asciz  "PRIVABIOS "
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
        .asciz  "GITHUB.COM/LID-LABS/PRIVABIOS"
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
