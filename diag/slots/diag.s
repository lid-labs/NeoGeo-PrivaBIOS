| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| SLOT DIAGNOSTIC IMAGE — a standalone sp1, for ONE trial on a real board.
|
| This is not ReBIOS: no cartridge is launched. At reset, the image reads the system
| registers, then, for each slot 0 to 7 and for six ways of accessing it, the 16 bytes of
| $000100-$00010F (the start of the header, "68k program header": "NEO-GEO" then the
| NGH). It displays them in hexadecimal with the board's font (SFIX, fix layer), and
| holds the screen indefinitely while kicking the watchdog.
|
| WHY, and what each variant tests (docs/ESSAI-MATERIEL.md, feedback of 2026-10-24):
| image no. 8 read the header under REG_BRDFIX and found the bus floating on an MV-2F.
| Main hypothesis (SLOTCS gated by SYSTEMB, wiki "NEO-F0", "MVS cartridge pinout",
| "Signals"): the cartridge only answers under REG_CRTFIX. The variants:
|   A  REG_BRDFIX, the BIOS's vectors, REG_SLOT byte at $380021, reads as words — image no. 8;
|   B  REG_CRTFIX, otherwise like A — the fix, and the reference's measured order;
|   C  B plus REG_SWPROM during the read;
|   D  B, but REG_SLOT written as a word at $380020 (the number in the low byte);
|   E  B, then 8 frames of waiting between the choice of the slot and the read;
|   F  B, reads as bytes (16 `move.b`), like the reference.
| A is measured first, for all the slots, before any write of REG_CRTFIX.
|
| THE SCREEN, 8×8 font (tile = ASCII code, palette in the 4 high bits; `src/c0/dip.s`,
| `measured/2026-10-20-sfix-glyphes.tsv`), fix layer $7000 + 32 × column + line, lines 2
| to 29 visible ("Fix layer"). Two pages, alternating every 240 frames (~4 s):
| page 1 the variants A, B, C; page 2 D, E, F. One line per slot and per variant:
|   "0B 4E454F2D47454F00 0201xxxxxxxxxxxx Y": slot, variant, 16 bytes, and Y if the
| first seven are "NEO-GEO" — columns 1 to 38, the first and the last left at the
| edge of the screen. At the top: REG_SYSTYPE ($300081), REG_STATUS_A ($320001),
| the word at $380000 (REG_STATUS_B in the high byte, "Memory mapped registers"),
| REG_DIPSW ($300001), and whether the Z80 answered $01 (Z80 OK or NO).
|
| Sources: NeoGeo Development Wiki — "Memory mapped registers", "Fix layer",
| "Palettes", "VRAM", "Watchdog", "68k/Z80 communication", "Sprites" (size 0 in
| SCB3: sprite not displayed). No BIOS or game code read.
| ==================================================================================
        .equ    WATCHDOG, 0x300001
        .equ    DIPSW,    0x300001
        .equ    SYSTYPE,  0x300081
        .equ    STATUS_A, 0x320001
        .equ    SOUND,    0x320000
        .equ    STATUS_B, 0x380000
        .equ    REGSLOT,  0x380021
        .equ    SWPBIOS,  0x3A0003
        .equ    SWPROM,   0x3A0013
        .equ    BRDFIX,   0x3A000B
        .equ    CRTFIX,   0x3A001B
        .equ    PALBANK0, 0x3A001F
        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    IRQACK,   0x3C000C
        .equ    PALETTES, 0x400000
        .equ    FOND,     0x401FFE
        .equ    RES,      0x100000      | 6 variants × 8 slots × 16 bytes
        .equ    VARS,     0x100400      | registers read at boot, 8 bytes
        .equ    SYNC_TOURS, 5800

        .section .vectors, "a"
        .long   0x10F300
        .long   _reset
        .rept   30
        .long   _exception
        .endr

        .org    0x400
        .byte   0x80, 0x02              | MVS, Europe ("System ROM")
        .org    0x402
        .global _reset
_reset:
        jmp     _diag

        .org    0x800
_diag:
        move.w  #0x2700, %sr
        move.l  #0x10F300, %sp
        move.b  %d0, WATCHDOG
        move.b  %d0, SWPBIOS
        move.b  %d0, BRDFIX
        move.b  %d0, PALBANK0
        move.w  #0x4000, LSPCMODE
        move.w  #7, IRQACK

        | THE REGISTERS, before everything else.
        lea     VARS, %a0
        move.b  SYSTYPE, (%a0)+
        move.b  STATUS_A, (%a0)+
        move.w  STATUS_B, %d0
        move.w  %d0, (%a0)+
        move.b  DIPSW, (%a0)+
        clr.b   (%a0)+                  | Z80: 0 no reply

        | A: under REG_BRDFIX, as at reset, all the slots first.
        moveq   #0, %d6                 | variant
        bsr     _variante

        | THE Z80 PARKED ($01, its echo, 60 frames at most) before the first REG_CRTFIX switch,
        | which changes its ROM; then one frame.
        moveq   #60-1, %d4
1:      move.b  #0x01, SOUND
        bsr     _sync
        cmpi.b  #0x01, SOUND
        dbeq    %d4, 1b
        bne.s   2f
        move.b  #1, VARS + 5
2:      bsr     _sync

        moveq   #1, %d6
3:      bsr     _variante               | B to F
        addq.w  #1, %d6
        cmpi.w  #6, %d6
        blo.s   3b
        move.b  #0, REGSLOT
        move.b  %d0, BRDFIX
        move.b  %d0, SWPBIOS

        bsr     _ecran_init
        moveq   #0, %d7                 | frames
_boucle:
        bsr     _sync
        moveq   #0, %d0
        move.w  %d7, %d0
        divu    #240, %d0
        andi.w  #1, %d0                 | the page, 0 or 1
        bsr     _page
        addq.w  #1, %d7
        bra.s   _boucle

| ----------------------------------------------------------------------------------
| ONE VARIANT %d6 (0-5) over the eight slots. Result at RES + 128 × %d6 + 16 × slot.
| Returns under REG_BRDFIX and REG_SWPBIOS, REG_SLOT at 0.
_variante:
        moveq   #0, %d5                 | slot
        move.w  %d6, %d0
        lsl.w   #7, %d0
        lea     RES, %a1
        adda.w  %d0, %a1
1:      move.b  %d0, WATCHDOG
        tst.w   %d6
        beq.s   2f                      | A: REG_BRDFIX
        bsr.s   _choisir                | REG_SLOT, REG_CRTFIX, REG_SLOT: the reference's order
        move.b  %d0, CRTFIX
2:      bsr.s   _choisir
        cmpi.w  #4, %d6
        bne.s   5f
        moveq   #8-1, %d4               | E: 8 frames
6:      bsr     _sync
        dbra    %d4, 6b
5:      cmpi.w  #2, %d6
        bne.s   7f
        move.b  %d0, SWPROM             | C: the cartridge's vectors
7:      lea     0x100, %a0
        cmpi.w  #5, %d6
        beq.s   8f
        move.w  (%a0)+, (%a1)+          | as words
        move.w  (%a0)+, (%a1)+
        move.w  (%a0)+, (%a1)+
        move.w  (%a0)+, (%a1)+
        move.w  (%a0)+, (%a1)+
        move.w  (%a0)+, (%a1)+
        move.w  (%a0)+, (%a1)+
        move.w  (%a0)+, (%a1)+
        bra.s   9f
8:      moveq   #16-1, %d4              | F: as bytes
10:     move.b  (%a0)+, (%a1)+
        dbra    %d4, 10b
9:      move.b  %d0, SWPBIOS
        move.b  %d0, BRDFIX
        addq.w  #1, %d5
        cmpi.w  #8, %d5
        blo.s   1b
        move.b  #0, REGSLOT
        rts

| THE SLOT %d5 in REG_SLOT: as a byte at $380021, or as a word at $380020 for variant D.
_choisir:
        cmpi.w  #3, %d6
        bne.s   1f
        move.w  %d5, 0x380020           | D: REG_SLOT as a word
        rts
1:      move.b  %d5, REGSLOT
        rts

| ----------------------------------------------------------------------------------
| THE PASSING OF LINE $1F0 ("LSPC": the line counter in REG_LSPCMODE, bits 7-15),
| bounded, watchdog at each turn — the same wait as `src/c0/c0.s`. Clobbers %d0.
_sync:
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
| THE SCREEN: palettes, black background, sprites hidden (SCB3 at zero: size 0), fix layer cleared.
_ecran_init:
        bsr     _sync
        lea     PALETTES, %a0
        move.w  #0x100 - 1, %d1         | palettes 0 to 15, 16 entries
1:      clr.w   (%a0)+
        dbra    %d1, 1b
        clr.w   FOND
        move.w  #0x7FFF, PALETTES + 0x20 + 2    | palette 1, entry 1: white
        move.w  #0x6FF0, PALETTES + 0x40 + 2    | palette 2, entry 1: yellow
        move.w  #0x60F0, PALETTES + 0x60 + 2    | palette 3, entry 1: green
        lea     VRAMRW, %a0
        move.w  #1, VRAMMOD
        move.w  #0x8200, VRAMADDR       | SCB3: 512 words at zero
        nop
        nop
        move.w  #0x200 - 1, %d1
2:      move.b  %d0, WATCHDOG
        clr.w   (%a0)
        dbra    %d1, 2b
        nop
        nop
        move.w  #0x7000, VRAMADDR       | fix layer: 40 × 32, tile $020 palette 0
        nop
        nop
        move.w  #0x500 - 1, %d1
3:      move.b  %d0, WATCHDOG
        move.w  #0x0020, (%a0)
        dbra    %d1, 3b
        nop
        nop
        move.w  #32, VRAMMOD            | one write: one column to the right
        rts

| ----------------------------------------------------------------------------------
| ONE PAGE (%d0 = 0 or 1), redrawn at each frame: header, legend, 24 lines of
| results, footer with the frame counter %d7.
_page:
        movem.l %d0-%d7/%a0-%a3, -(%sp)
        move.w  %d0, %d6                | the page
        | line 2: the title
        moveq   #2, %d1
        moveq   #1, %d2
        move.w  #0x2000, %d3
        lea     .Ltitre, %a2
        bsr     _texte
        | line 3: the registers
        moveq   #3, %d1
        moveq   #1, %d2
        move.w  #0x1000, %d3
        lea     .Lsys, %a2
        bsr     _texte                  | %d2: the next column
        move.b  VARS, %d4
        bsr     _hex2
        lea     .Lsta, %a2
        bsr     _texte
        move.b  VARS + 1, %d4
        bsr     _hex2
        lea     .Lstb, %a2
        bsr     _texte
        move.b  VARS + 2, %d4
        bsr     _hex2
        move.b  VARS + 3, %d4
        bsr     _hex2
        lea     .Ldip, %a2
        bsr     _texte
        move.b  VARS + 4, %d4
        bsr     _hex2
        lea     .Lz80ok, %a2
        tst.b   VARS + 5
        bne.s   1f
        lea     .Lz80no, %a2
1:      bsr     _texte
        | line 4: the page's legend
        moveq   #4, %d1
        moveq   #1, %d2
        move.w  #0x2000, %d3
        lea     .Lleg1, %a2
        tst.w   %d6
        beq.s   2f
        lea     .Lleg2, %a2
2:      bsr     _texte
        | lines 5 to 28: slot-major, three variants per slot
        moveq   #5, %d1
        moveq   #0, %d5                 | slot
3:      moveq   #0, %d4
        move.w  %d6, %d0
        mulu    #3, %d0                 | the page's first variant
        move.w  %d0, %d7
        moveq   #3-1, %d0
4:      bsr     _resultat               | slot %d5, variant %d7, line %d1
        addq.w  #1, %d1
        addq.w  #1, %d7
        dbra    %d0, 4b
        addq.w  #1, %d5
        cmpi.w  #8, %d5
        blo.s   3b
        | line 29: the page and the counter
        movem.l (%sp)+, %d0-%d7/%a0-%a3
        movem.l %d0-%d7/%a0-%a3, -(%sp)
        moveq   #29, %d1
        moveq   #1, %d2
        move.w  #0x2000, %d3
        lea     .Lpage1, %a2
        tst.w   %d0
        beq.s   5f
        lea     .Lpage2, %a2
5:      bsr     _texte
        move.w  %d7, %d4
        lsr.w   #8, %d4
        bsr     _hex2
        move.w  %d7, %d4
        bsr     _hex2
        movem.l (%sp)+, %d0-%d7/%a0-%a3
        rts

| ONE RESULT LINE: slot %d5, variant %d7 (0-5), line %d1. Preserves %d0, %d1, %d5-%d7.
_resultat:
        movem.l %d0/%d5-%d7, -(%sp)
        moveq   #1, %d2
        move.w  #0x1000, %d3
        move.w  %d5, %d4
        bsr     _chiffre
        move.w  %d7, %d4
        addi.w  #0x41, %d4              | "A" + variant
        bsr     _car
        moveq   #0x20, %d4
        bsr     _car
        move.w  %d7, %d0
        lsl.w   #7, %d0
        move.w  %d5, %d4
        lsl.w   #4, %d4
        add.w   %d4, %d0
        lea     RES, %a3
        adda.w  %d0, %a3                | the 16 bytes
        moveq   #16-1, %d5
1:      move.b  (%a3)+, %d4
        bsr     _hex2
        cmpi.w  #8, %d5
        bne.s   2f
        moveq   #0x20, %d4              | a space after the 8th byte
        bsr     _car
2:      dbra    %d5, 1b
        moveq   #0x20, %d4
        bsr     _car
        | "NEO-GEO" in the first seven bytes?
        suba.w  #16, %a3
        lea     .Lneogeo, %a2
        moveq   #7-1, %d5
3:      cmpm.b  (%a2)+, (%a3)+
        dbne    %d5, 3b
        bne.s   4f
        move.w  #0x3000, %d3            | green
        moveq   #0x59, %d4              | "Y"
        bra.s   5f
4:      moveq   #0x2D, %d4              | "-"
5:      bsr     _car
        movem.l (%sp)+, %d0/%d5-%d7
        rts

| ----------------------------------------------------------------------------------
| WRITING IN THE FIX LAYER: line %d1, column %d2, palette %d3 (already shifted by 12).
| _texte: the string %a2 (terminated by 0); _hex2: the byte %d4 as two digits;
| _chiffre: the low nibble of %d4; _car: the character %d4. Each one advances %d2.
| Clobbers %d4 (and %a2 for _texte).
_texte:
        moveq   #0, %d4
        move.b  (%a2)+, %d4
        beq.s   1f
        bsr.s   _car
        bra.s   _texte
1:      rts

_hex2:
        move.w  %d4, -(%sp)
        lsr.b   #4, %d4
        bsr.s   _chiffre
        move.w  (%sp)+, %d4
_chiffre:
        andi.w  #0x0F, %d4
        cmpi.w  #10, %d4
        bcs.s   1f
        addq.w  #7, %d4
1:      addi.w  #0x30, %d4
_car:
        move.l  %d0, -(%sp)
        move.w  %d2, %d0
        lsl.w   #5, %d0
        add.w   %d1, %d0
        addi.w  #0x7000, %d0
        move.w  %d0, VRAMADDR
        andi.w  #0xFF, %d4
        or.w    %d3, %d4
        nop
        nop
        move.w  %d4, VRAMRW
        addq.w  #1, %d2
        move.l  (%sp)+, %d0
        rts

| ----------------------------------------------------------------------------------
| AN EXCEPTION: hidden line 30 cannot be seen, hence line 29, and we stay there, the
| watchdog served — the screen never restarts.
_exception:
        move.w  #0x2700, %sr
        move.l  #0x10F300, %sp
        moveq   #29, %d1
        moveq   #24, %d2
        move.w  #0x2000, %d3
        lea     .Lexc, %a2
        bsr     _texte
1:      move.b  %d0, WATCHDOG
        bra.s   1b

.Ltitre:  .asciz "REBIOS SLOT DIAG 1"
.Lsys:    .asciz "SYS "
.Lsta:    .asciz " STA "
.Lstb:    .asciz " STB "
.Ldip:    .asciz " DIP "
.Lz80ok:  .asciz " Z80 OK"
.Lz80no:  .asciz " Z80 NO"
.Lleg1:   .asciz "A BRDFIX  B CRTFIX  C CRTFIX+SWPROM"
.Lleg2:   .asciz "D SLOT WORD  E 8 FRAMES  F BYTE READ"
.Lpage1:  .asciz "PAGE 1/2  FRAME "
.Lpage2:  .asciz "PAGE 2/2  FRAME "
.Lexc:    .asciz "EXCEPTION"
.Lneogeo: .ascii "NEO-GEO"
        .balign 2
