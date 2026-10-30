| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| THE JUKEBOX — opened from the TEST screen (`dip.s`, JUKEBOX line), outside a game: it
| sends to the cartridge's sound driver the code one chooses. The BIOS has no Z80 program
| of its own.
|
| NO ORACLE: neither the reference BIOS nor a third-party BIOS is read, nor the Z80 code of the
| cartridges. The hand-over is "Couche 3 → le jukebox, le 2026-10-21"
| (`docs/RELECTURE-CONTRATS.md`). "measured": a named record; "read in": a page of the
| NeoGeo Development Wiki; "ASSUMED": neither one nor the other.
|
| CALL: `jsr _jukebox` from `dip.s`, %a1 = the cartridge's soft-DIP block (0 if it is
| refused), from which the game's name. All registers returned. On call, the state is that of
| the TEST screen: REG_BRDFIX (the board's font), the game's driver looping in RAM after
| the $01 handshake of `dip.s`, palettes 1-4 of `dip.s` set in bank 0, IRQs
| masked. On return, the same state, except palette 5 left at zero: `dip.s` only uses
| 1-4, `tests.s` and `plantage.s` set their own before use (read in the code).
|
| THE ENTRY. REG_CRTFIX gives the cartridge's M1 back to the Z80 and the S ROM to the fix layer
| (read in "Memory mapped registers"); $03, Z80 "soft reset", "within 100ms", without
| reply (read in "68k/Z80 communication"); then 8 frames (~135 ms) before the first
| code, like `menu.s`. The text is therefore in the CARTRIDGE'S FONT, at the places of the
| SFIX, in 8×8 (tile = ASCII): measured, `measured/2026-10-21-police-cartouche.tsv`, 20 games
| identical to the SFIX on 0-9, A-Z, space, ": - / .", trally readable, kof2003 with nothing
| (its cells are flat fills of index 2): on kof2003 the screen is black, the sound works.
| Only these characters are used (no "$": not measured).
| THE CLEARING: each cell receives tile $020 under palette 5, whose 16 entries
| are set to zero. Whatever the drawing of $020 in the S ROM, any non-zero index is
| black there, like the background; tile $FF of FIX_CLEAR is not measured under the S ROM.
| The stroke at index 1 (same record): palettes 1-4 of `dip.s` carry their colour
| in entry 1, black in 2 to 15.
|
| THE CODES. Read in "68k/Z80 communication": three codes are reserved for the system —
| $01 (prepare a slot switch: the driver cuts the sound, replies $01 and loops in
| RAM), $02 (eye-catcher music, without reply), $03 (reset). The page gives no
| table of the others, whose meaning depends on the driver. They are SKIPPED: the number goes from
| $00 to $04 and from $04 to $00; the 253 others, $00 included, are sent as they are.
| "PLAY 07 FIRST IF SILENT": measured (jig `bench/jukebox.lua`, 2026-10-21), aof, kof98,
| kof2003 trigger after the $03, before $07, only $7F; $07 switches mslug off: it is therefore
| not sent by default, the help says so.
| CUTTING THE SOUND (B): the page documents no stop code; the driver is restarted by
| $03 then 8 frames. ASSUMED: that a freshly restarted driver goes silent.
|
| THE CONTROLS, P1, active low (read in "Memory mapped registers": REG_P1CNT
| bits 0-5 up, down, left, right, A, B; REG_STATUS_B bit 0 START P1). Up/down: ±1,
| left/right: ±16, with held repeat (20 frames then every 4: a choice, 256 notches
| one by one would be long). A: sends the code to REG_SOUND. B: cuts. START: exit.
|
| THE SCREEN SAVER, on 2026-10-27 (DECISIONS §25, the user's decision: the
| behaviour observed on UniBIOS 4.0). MEASURED on it
| (`measured/2026-10-27-attentes-reference.tsv`): in its JUKEBOX
| PLAYER only, the screen goes entirely black ~7,220 frames (~2 min) after the last input,
| the music continues, a key brings the screen back. Here: INACTIF frames without any P1 input (the
| eight of REG_P1CNT, START), entries 1 of palettes 1-4 — the only colours of this screen, the
| rest being black — are set to zero, just after the passing of line $1F0; the Z80 is not
| touched. A held input brings them back, and that frame does nothing else: no code, no step, no
| exit; held afterwards, it no longer has an edge. The four colours are kept in %a1 and %a3.
|
| THE EXIT. The $01 handshake of `menu.s` (send, one frame, read of the echo,
| 60 times at most — the echo is read only one frame after the send: the driver's last
| reply may already be $01), one frame, REG_BRDFIX. The driver is then in its loop
| in RAM, as `dip.s` had left it; `dip.s` will do REG_CRTFIX and $03 at its exit as
| without jukebox.
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

        .equ    PAL_VIDE, 5             | the clearing palette, all at zero
        | The layout, in fix layer cells ($7000 + 32 × column + line).
        .equ    CASE_TITRE, 0x7000 + 3 * 32 + 4
        .equ    CASE_NOM,   0x7000 + 3 * 32 + 6
        .equ    CASE_SON,   0x7000 + 3 * 32 + 12
        .equ    CASE_CODE,  0x7000 + 15 * 32 + 12
        .equ    CASE_AIDE1, 0x7000 + 3 * 32 + 23
        .equ    CASE_AIDE2, 0x7000 + 3 * 32 + 24
        .equ    CASE_AIDE3, 0x7000 + 3 * 32 + 26
        .equ    CASE_AIDE4, 0x7000 + 3 * 32 + 27
        .equ    DELAI1,   20            | frames before the repeat
        .equ    DELAI2,   4             | frames between two repeats
        .equ    INACTIF,  7100          | frames without input before the black screen: ~2 min at 59.185 Hz

| %d7: the code; %d5: the previous frame's buttons; %d6: the repeat count;
| %a0: REG_VRAMRW; %a5: the soft-DIP block.
_jukebox:
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        movea.l %a1, %a5
        lea     VRAMRW, %a0

        | THE ENTRY: the cartridge to the Z80, its driver restarted, the screen under its S ROM.
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
        move.w  #1280 - 1, %d1          | 18 cycles per turn: above the 12 ("VRAM")
2:      move.w  %d0, (%a0)
        dbra    %d1, 2b
        move.w  #32, VRAMMOD            | one write = one column
        move.w  #CASE_TITRE, %d1
        lea     .Ltxt_titre, %a2
        moveq   #L_TITRE, %d4
        move.w  #0x3000, %d3
        bsr     .Lecrire
        move.l  %a5, %d0
        beq.s   3f
        move.w  #CASE_NOM, %d1          | the game's name, bytes $00-$0F of the block
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
        bsr     .Lattendre              | the driver restarts before the first code
        moveq   #0, %d5
        bsr     .Lentrees               | a button already held (the A that opens) does not count
        moveq   #0, %d6                 | 0: no repeat armed (see THE DIRECTIONS)
        moveq   #0, %d3                 | %d3: the frames without input (THE SCREEN SAVER)

| THE LOOP, one frame per turn.
.Lboucle:
        bsr     .Lsync
        bsr     .Lentrees               | %d0 the edges, %d5 the state
        | THE SCREEN SAVER (see the header): %d3 stops at INACTIF, the screen black.
        move.l  %d0, %d1                | the edges kept
        jsr     _panneau_p1             | %d0: P1, joystick or translated panel (`panneau.s`)
        exg     %d0, %d1
        not.b   %d1
        or.b    %d5, %d1                | C and D count too, which `.Lentrees` does not read
        bne.s   8f
        cmpi.w  #INACTIF, %d3
        bcc.s   9f                      | already black
        addq.w  #1, %d3
        cmpi.w  #INACTIF, %d3
        bcs.s   9f
        bsr     .Leteindre
        bra     .Lboucle
8:      cmpi.w  #INACTIF, %d3
        bcs.s   7f
        bsr     .Lrallumer              | the wake-up frame does nothing else
        moveq   #0, %d3
        moveq   #0, %d6
        bra     .Lboucle
7:      moveq   #0, %d3
9:      btst    #6, %d0
        bne     .Lsortie
        btst    #4, %d0                 | A: the code to the driver
        beq.s   1f
        move.b  %d7, SOUND
        bra     .Lboucle
1:      btst    #5, %d0                 | B: the driver restarted
        beq.s   2f
        move.b  #0x03, SOUND
        bsr     .Lattendre
        bra     .Lboucle
        | THE DIRECTIONS: an edge acts and arms DELAI1; held, they act when the
        | count falls to zero, then every DELAI2 frames. %d6 at 0, nothing is armed: a
        | direction already held at opening never repeats before having been released.
2:      move.b  %d0, %d2
        andi.b  #0x0F, %d2
        beq.s   3f
        moveq   #DELAI1, %d6
        bra.s   4f
3:      move.b  %d5, %d2
        andi.b  #0x0F, %d2
        beq     .Lboucle
        tst.w   %d6
        beq     .Lboucle                | nothing armed
        subq.w  #1, %d6
        bne     .Lboucle
        moveq   #DELAI2, %d6
4:      moveq   #1, %d1                 | up
        btst    #0, %d2
        bne.s   5f
        moveq   #-1, %d1                | down
        btst    #1, %d2
        bne.s   5f
        moveq   #16, %d1                | right
        btst    #3, %d2
        bne.s   5f
        moveq   #-16, %d1               | left
5:      add.b   %d1, %d7                | modulo 256
        cmpi.b  #1, %d7
        bcs.s   6f
        cmpi.b  #3, %d7
        bhi.s   6f
        moveq   #4, %d7                 | $01-$03 reserved: skipped in the direction of the step
        tst.b   %d1
        bpl.s   6f
        moveq   #0, %d7
6:      andi.l  #0xFF, %d7
        bsr     .Lcode
        bra     .Lboucle

| THE EXIT: the driver looping in RAM, then the board's font (see the header).
.Lsortie:
        moveq   #60 - 1, %d4
1:      move.b  #0x01, SOUND
        bsr     .Lsync
        cmpi.b  #0x01, SOUND
        dbeq    %d4, 1b
        bsr     .Lsync                  | one frame for the driver to enter its loop
        move.b  %d0, BRDFIX
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rts

| THE BLACK SCREEN, then restored: entries 1 of palettes 1-4, kept in %a1 (1, 2) and %a3 (3, 4).
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

| THE BUTTONS. Bits: 0 up, 1 down, 2 left, 3 right, 4 A, 5 B, 6 START. %d5 the previous
| state, updated; %d0 the edges. Clobbers %d1, %d2.
.Lentrees:
        jsr     _panneau_p1             | %d0: P1, joystick or translated panel (`panneau.s`)
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

| THE CODE %d7, two hexadecimal digits under palette 2. Clobbers %d0, %d1, %a2.
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

| EIGHT FRAMES (~135 ms), after a $03: "within 100ms". Clobbers %d0, %d4.
.Lattendre:
        moveq   #8 - 1, %d4
1:      bsr.s   .Lsync
        dbra    %d4, 1b
        rts

| WRITE %d4 characters of %a2 from cell %d1, REG_VRAMMOD at 32, like `dip.s`.
| %d3: palette << 12. Outside $20-$7E, a space. Clobbers %d2, %d4, %a2.
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

| THE PASSING OF LINE $1F0, like `dip.s`; watchdog at each turn. Clobbers %d0.
| BOUNDED to SYNC_TOURS turns per wait, ≈ 2 frames, line seen or not: the count is in
| `ecran.s`, of which this is the identical copy.
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
| THE DATA: the only characters measured in the cartridges' font.
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
