| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| THE CRASH SCREEN — an exception that nobody handles, displayed, then START restarts.
|
| NO ORACLE: neither the reference BIOS nor a third-party BIOS is read. The hand-over is
| "Couche 3 → l'écran de plantage, le 2026-10-21" (`docs/RELECTURE-CONTRATS.md`).
| "measured": a named record; "read in": a page of the NeoGeo Development Wiki;
| "ASSUMED": neither one nor the other.
|
| WHERE WE COME FROM. Two doors, one entry point per door, each one pushes its code:
|   - the slots $C00408-$C00432 of the entry area (`c0.s`), where the cartridges' vector
|     tables lead. "BIOS calls" only says of them "$C00402 to $C00432", "Entry
|     point (system boots here)". Read in "68k vector table", template "For cartridge
|     systems": $C00408 bus error; $C0040E address error AND illegal
|     instruction; $C0041A privilege; $C00420 trace; $C00426 reserved and autovectors 3 to
|     7; $C0042C uninitialized interrupt; $C00432 spurious interrupt.
|     MEASURED, and it differs: the tables of 20 cartridges of the corpus, read by lua under MAME
|     after the hand-over (2026-10-21, our image; garou and trally unreadable;
|     record not versioned, handed to the coordinating agent). All 20 put the illegal
|     instruction at $C00414, not at $C0040E — the slot of the "For CD systems" template —, and:
|       $C00408  vector 2, all 20;              $C0040E  vector 3, all 20;
|       $C00414  vector 4, all 20; lines A/F also in b2b and neomrdo;
|       $C0041A  vector 8, all 20; division, CHK and TRAPV also in lbowling;
|       $C00420  vector 9, all 20;              $C0042C  vector 15, 19 out of 20;
|       $C00426  division/CHK/TRAPV (aof, flipshot, puzzledp), lines A/F, reserved,
|                vector 15 (kof2003), autovectors 3 to 7;
|       $C00432  vector 24, all 20.
|     A shared slot therefore does not tell the exception: it takes a code of its own (32 to 34),
|     displayed as the list of its possible causes, without a vector number;
|   - the BIOS's vector table (`c0.s`, vectors 2 to 31), active from power-on
|     to REG_SWPROM: one vector, one entry point, hence the exact exception. What
|     would take it is a defect of our own boot (IRQs masked throughout):
|     displaying it is better than the silent loop from before, and an identifiable loop remains,
|     `_plantage_double`, for an exception raised by this handler itself.
|
| $C0040E SERVES TWO EXCEPTIONS WITH DIFFERENT FRAMES in the template (none of the 20
| measured cartridges follows it there, but nothing forbids another one from doing so). Read in
| "68k vector table":
| address error, frame A (status word, access address, IR, SR, PC); illegal
| instruction, frame B (SR, PC); and the address error is a "Misaligned (odd)" access.
| The long at SP+2 is therefore the access address, odd, in a frame A, and the PC of an
| illegal instruction, even, in a frame B. We decide on that bit, read by byte.
| Measured (`measured/2026-10-17-diagnostic-b2b-minasan.tsv`, point 1): under MAME, an
| address error of b2b does push the address $544505 and the IR $34D9.
|
| THE FRAME, read in "68k vector table", Stack frames: format A, +0 status word (bit 4
| "0:Write 1:Read", bit 3 "0:Instruction", bits 2-0 function code), +2 access
| address, +6 IR, +8 SR, +10 PC; format B, +0 SR, +2 PC. A7 displayed = the stack before the
| frame, SP + 14 or SP + 6.
|
| NO NEW EXCEPTION. The game's stack received the frame, so SP is even (ASSUMED,
| no page read says so: on an odd stack, the push itself would raise an
| address error, and the 68000 would halt on a double fault): we read it by words, nothing of
| what it contains is dereferenced. The door's code then the 15 registers are
| pushed there BELOW the frame (62 bytes), which stays intact; everything is read before the first
| write at $10F400+. Then the stack restarts from $10F300, like `c0.s`. ASSUMED: a game
| stack less than 62 bytes above $100000 would lose its registers into the P-ROM.
| An exception in this very handler, once the save is written, finds DRAPEAU
| armed and falls into `_plantage_double`: the first save is kept, the second
| overwrites nothing. ASSUMED: that before (the reading of the frame and the copy, even
| accesses in RAM), nothing raises one.
|
| THE SAVE, in the BIOS's RAM. Read in "Memory map": $10F300-$10FFFF "System
| ROM-reserved RAM"; `c0.s` clears it at boot. $10F400-$10F45B is written by no
| other file of `src/c0/` (read in the code), but THE AREA IS NOT FREE: nam1975
| writes $10F300-$10F4B3 (measured, `measured/2026-10-21-ecrivains-ram-bios.tsv`). The game's
| stack can therefore be there at the moment of the exception: hence the frame read first, and
| the copy of the registers in the direction that rereads nothing overwritten. The screen being
| terminal, whatever of the game's data the save overwrites is given back to no one.
|
| THE SCREEN IS TERMINAL: nothing is given back to the game, START restarts the machine through
| the watchdog (`dip.s`, measured). What follows from it:
|   - REG_BRDFIX for the board's font, after the slot-change handshake
|     of `dip.s` ("68k/Z80 communication": $01, the driver cuts the sound, loops in
|     RAM, answers $01). Bounded at 60 frames, then we switch anyway: a driver that does not
|     answer costs one second, not a frozen screen. No REG_CRTFIX nor $03 on the
|     way back: the watchdog reset takes everything up again (ASSUMED, as in `dip.s`);
|   - the game's video state is overwritten, not read: REG_NOSHADOW ("Memory mapped registers",
|     a game may have darkened the output), palette bank 0, palettes 0 to 5,
|     the backdrop, LSP_1st (zero-height sprites, `video.s`), FIX_CLEAR, REG_VRAMMOD set;
|   - bit 7 of $10FD80 (who has the vblank) does not matter: the IRQs stay masked
|     (SR = $2700 from the first instruction), no INT1 runs;
|   - palette 0 is not left to the game: tile $FF of FIX_CLEAR and column $20
|     of the borders are under it. Entries 1-15 at the backdrop colour, the reference $400000 at
|     $8000 ("Palettes": "always has to be pure black ($8000)").
| The glyphs: 8×8 = ASCII tile, 8×16 = $100/$200 + ASCII, stroke at index 1, cell
| background at index 2 (`measured/2026-10-20-sfix-glyphes.tsv`, `ecran.s`, `dip.s`). Here
| entries 2-15 carry the backdrop colour, so that the cells do not make black blocks.
| ==================================================================================

        .section .haut, "ax"
        .global _plantage_double

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    WATCHDOG, 0x300001
        .equ    SOUND,    0x320000
        .equ    STATUS_B, 0x380000
        .equ    NOSHADOW, 0x3A0001
        .equ    BRDFIX,   0x3A000B
        .equ    PALBANK0, 0x3A000F
        .equ    PALETTES, 0x400000
        .equ    FOND,     0x401FFE

        | The save. D0-D7, A0-A6 then A7 are contiguous: A n at SV_D + 32 + 4n.
        .equ    SV_D,     0x10F400      | 15 longs, by `movem`
        .equ    SV_A7,    0x10F43C      | the stack before the frame
        .equ    SV_USP,   0x10F440
        .equ    SV_PC,    0x10F444
        .equ    SV_ACC,   0x10F448      | access address, frame A
        .equ    SV_SR,    0x10F44C
        .equ    SV_IR,    0x10F44E      | frame A
        .equ    SV_ETAT,  0x10F450      | status word, frame A
        .equ    SV_CODE,  0x10F452      | high byte: the vector; low: the slot ($C004xx)
        .equ    DRAPEAU,  0x10F458      | MARQUE: the handler is already running
        .equ    MARQUE,   0x504C4E54    | "PLNT"
        .equ    C3_OU_4,  0xFF          | code of $C0040E: address or illegal, to be decided
        .equ    C_426,    32            | code of $C00426: several causes (see the header)
        .equ    C_414,    33            | code of $C00414: illegal, or lines A/F
        .equ    C_41A,    34            | code of $C0041A: privilege, or division/CHK/TRAPV

        | A cell of the fix layer ("Fix layer"): $7000 + 32 × column + row.
        .equ    COL,      3
        .equ    CASE_TITRE, 0x7000 + 32 * COL + 3      | 8×16, rows 3-4
        .equ    CASE_NOM,   0x7000 + 32 * COL + 6
        .equ    CASE_VIA,   0x7000 + 32 * COL + 7
        .equ    CASE_PC,    0x7000 + 32 * COL + 9
        .equ    CASE_ACC,   0x7000 + 32 * COL + 10
        .equ    CASE_IR,    0x7000 + 32 * COL + 11
        .equ    CASE_REGS,  0x7000 + 32 * COL + 13     | D0/A0 to D7/A7, rows 13-20
        .equ    CASE_USP,   0x7000 + 32 * COL + 21
        .equ    CASE_NGH,   0x7000 + 32 * COL + 23
        .equ    CASE_START, 0x7000 + 32 * COL + 26

        | The colours, $0RGB ("Colors"). A choice of look.
        .equ    C_FOND,   0x0006        | midnight blue
        .equ    N_PAL,    5             | palettes 1 to 5, see `.Lcouleurs`

| ----------------------------------------------------------------------------------
| THE ENTRY POINTS. Each one: SR to $2700 first (a group 0 or 1 error does not touch
| the mask, an IRQ could follow), its code pushed without touching a register — below
| the frame, never at $10F400+ (see THE SAVE) —, then the common trunk. 12 bytes
| each.
        .macro  ENTREE nom, vecteur, creneau
        .global \nom
\nom:
        move.w  #0x2700, %sr
        move.w  #((\vecteur) << 8) + (\creneau), -(%sp)
        bra.w   _pl_commun
        .endm

        | The slots of the entry area, reached by the `jmp`s of `c0.s`.
        ENTREE  _pl_c408, 2, 0x08       | bus error
        ENTREE  _pl_c40e, C3_OU_4, 0x0E | address error or illegal instruction
        ENTREE  _pl_c414, C_414, 0x14   | illegal instruction, lines A/F
        ENTREE  _pl_c41a, C_41A, 0x1A   | privilege, division, CHK, TRAPV
        ENTREE  _pl_c420, 9, 0x20       | trace
        ENTREE  _pl_c426, C_426, 0x26   | division … autovectors 3 to 7
        ENTREE  _pl_c42c, 15, 0x2C      | uninitialized interrupt
        ENTREE  _pl_c432, 24, 0x32      | spurious interrupt

        | The BIOS's vector table, 2 to 31: slot 0.
        .irp    n, 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
        ENTREE  _pl_v\n, \n, 0
        .endr

| ----------------------------------------------------------------------------------
| THE COMMON TRUNK. No register has changed yet (apart from SR), and nothing is written at
| $10F400+ before the frame is read: the save could cover it (see the header).
| First the single read of the flag, then the registers pushed right after the code, below
| the frame. Stack: (SP) the 15 registers, 60(SP) the code, 62(SP) the frame.
_pl_commun:
        cmpi.l  #MARQUE, DRAPEAU
        beq.w   _plantage_double
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        lea     62(%sp), %a0            | the frame

        | $C0040E: bit 0 of the long at SP+2 of the frame, read by byte (see the header). The
        | decided code is rewritten into our own word, below the frame.
        moveq   #0, %d0
        move.b  60(%sp), %d0            | the high byte of the code: the vector
        cmpi.b  #C3_OU_4, %d0
        bne.s   1f
        moveq   #4, %d0                 | even: illegal instruction, frame B
        btst    #0, 5(%a0)
        beq.s   2f
        moveq   #3, %d0                 | odd: address error, frame A
2:      move.b  %d0, 60(%sp)
1:      moveq   #0, %d1                 | %d1 status word, %d2 access address, %d3 IR:
        moveq   #0, %d2                 | zero outside frame A
        moveq   #0, %d3
        cmpi.b  #3, %d0
        bhi.s   3f                      | 4 and above: frame B
        move.w  (%a0)+, %d1             | 2 and 3: frame A
        move.l  (%a0)+, %d2
        move.w  (%a0)+, %d3
3:      move.w  (%a0)+, %d4             | SR
        move.l  (%a0)+, %d5             | PC
        movea.l %a0, %a1                | A7: the stack before the frame
        move.l  %usp, %a2
        move.w  60(%sp), %d7            | the code

        | THE FRAME IS READ. The 15 registers, from the stack to SV_D: the two areas can
        | overlap (game stack at $10F400+), hence a copy in the direction that rereads nothing
        | already overwritten — ascending if SV_D is below the source, descending otherwise.
        movea.l %sp, %a3
        lea     SV_D, %a4
        moveq   #15 - 1, %d6
        cmpa.l  %a3, %a4
        bhi.s   5f
4:      move.l  (%a3)+, (%a4)+
        dbra    %d6, 4b
        bra.s   7f
5:      lea     60(%a3), %a3
        lea     60(%a4), %a4
6:      move.l  -(%a3), -(%a4)
        dbra    %d6, 6b
7:      move.l  %a1, SV_A7              | the rest, from the registers
        move.l  %a2, SV_USP
        move.l  %d5, SV_PC
        move.l  %d2, SV_ACC
        move.w  %d4, SV_SR
        move.w  %d3, SV_IR
        move.w  %d1, SV_ETAT
        move.w  %d7, SV_CODE
        move.l  #MARQUE, DRAPEAU        | from here on, an exception falls into `_plantage_double`
        movea.l #0x10F300, %sp          | the stack can restart

| ----------------------------------------------------------------------------------
| THE Z80 IN RAM, THEN THE BOARD'S FONT (see the header; same loop as `dip.s`).
| The echo is read only one frame after each send, like `menu.s` and `jukebox.s`: the
| last answer of the game's driver may already be $01, and reading it right away would
| take it for the echo.
        moveq   #60-1, %d4
1:      move.b  #0x01, SOUND
        bsr     .Lsync
        cmpi.b  #0x01, SOUND
        dbeq    %d4, 1b
        bsr     .Lsync                  | one frame for the driver to enter its loop
        move.b  %d0, BRDFIX

| THE VIDEO STATE, overwritten. Palettes just after the passing of line $1F0 ("Palettes":
| writing during display makes snow).
        bsr     .Lsync
        move.b  %d0, PALBANK0
        move.b  %d0, NOSHADOW
        lea     PALETTES, %a2
        move.w  #0x8000, (%a2)+         | the reference
        moveq   #15-1, %d1
1:      move.w  #C_FOND, (%a2)+         | palette 0, entries 1-15
        dbra    %d1, 1b
        lea     .Lcouleurs, %a3
        moveq   #N_PAL-1, %d2
2:      clr.w   (%a2)+                  | entry 0, transparent
        move.w  (%a3)+, (%a2)+          | entry 1, the stroke
        moveq   #14-1, %d1
3:      move.w  #C_FOND, (%a2)+         | entries 2-15, the cell background
        dbra    %d1, 3b
        dbra    %d2, 2b
        move.w  #C_FOND, FOND
        jsr     _lsp_1st
        jsr     _fix_clear
        move.w  #32, VRAMMOD            | one write = one column
        lea     VRAMRW, %a0
        lea     VRAMADDR, %a1

| ----------------------------------------------------------------------------------
| THE TEXT. %d1: the cell at the start of the line; %d3: palette << 12 + tile offset.
        move.w  #CASE_TITRE, %d1        | the title, 8×16, palette 2
        move.w  #0x2100, %d3
        lea     .Ltitre, %a2
        bsr     .Lligne
        move.w  #CASE_TITRE + 1, %d1
        move.w  #0x2200, %d3
        lea     .Ltitre, %a2
        bsr     .Lligne

        | THE EXCEPTION, palette 3: its name, then "VECTOR n" when the code is exact.
        move.w  #CASE_NOM, %d1
        move.w  #0x3000, %d3
        moveq   #0, %d6
        move.b  SV_CODE, %d6
        move.w  %d6, %d0
        lsl.w   #2, %d0
        lea     .Lnoms, %a2
        movea.l (%a2,%d0.w), %a2
        bsr     .Lligne
        cmpi.w  #C_426, %d6
        bcc.s   1f
        lea     .Lvecteur, %a2
        bsr     .Ltexte
        move.w  %d6, %d4
        bsr     .Ldecimal
1:
        | THE DOOR, palette 4: the slot $C004xx, or the BIOS's table.
        move.w  #CASE_VIA, %d1
        move.w  #0x4000, %d3
        lea     .Lvia_bios, %a2
        move.b  SV_CODE + 1, %d4
        beq.s   1f
        lea     .Lvia, %a2
        bsr     .Lligne
        bsr     .Lhex2
        bra.s   2f
1:      bsr     .Lligne
2:
        | PC AND SR, palette 1.
        move.w  #0x1000, %d3
        move.w  #CASE_PC, %d1
        lea     .Lpc, %a2
        bsr     .Lligne
        move.l  SV_PC, %d4
        bsr     .Lhex8
        lea     .Lsr, %a2
        bsr     .Ltexte
        move.w  SV_SR, %d4
        bsr     .Lhex4

        | FRAME A, bus and address errors only.
        cmpi.w  #3, %d6
        bhi.w   .Lregistres
        move.w  #CASE_ACC, %d1
        lea     .Lacces, %a2
        bsr     .Lligne
        move.l  SV_ACC, %d4
        bsr     .Lhex8
        lea     .Lecriture, %a2         | bit 4: 0 write, 1 read
        btst    #4, SV_ETAT + 1
        beq.s   1f
        lea     .Llecture, %a2
1:      bsr     .Ltexte
        lea     .Linstr, %a2            | bit 3: 0 instruction
        btst    #3, SV_ETAT + 1
        beq.s   1f
        lea     .Ldonnee, %a2
1:      bsr     .Ltexte
        move.w  #CASE_IR, %d1
        lea     .Lir, %a2
        bsr     .Lligne
        move.w  SV_IR, %d4
        bsr     .Lhex4
        lea     .Letat, %a2
        bsr     .Ltexte
        move.w  SV_ETAT, %d4
        bsr     .Lhex4

        | THE 16 REGISTERS, two columns: Dn then An, row n.
.Lregistres:
        moveq   #0, %d7
1:      move.w  #CASE_REGS, %d1
        add.w   %d7, %d1
        lea     .Ld, %a2
        bsr     .Lligne
        moveq   #0x30, %d2
        add.w   %d7, %d2
        bsr     .Lcar
        moveq   #0x20, %d2
        bsr     .Lcar
        move.w  %d7, %d0
        lsl.w   #2, %d0
        lea     SV_D, %a3
        move.l  (%a3,%d0.w), %d4
        bsr     .Lhex8
        lea     .La, %a2
        bsr     .Ltexte
        moveq   #0x30, %d2
        add.w   %d7, %d2
        bsr     .Lcar
        moveq   #0x20, %d2
        bsr     .Lcar
        move.w  %d7, %d0
        lsl.w   #2, %d0
        lea     SV_D + 32, %a3
        move.l  (%a3,%d0.w), %d4
        bsr     .Lhex8
        addq.w  #1, %d7
        cmpi.w  #8, %d7
        bcs.s   1b

        move.w  #CASE_USP, %d1
        lea     .Lusp, %a2
        bsr     .Lligne
        move.l  SV_USP, %d4
        bsr     .Lhex8

        | THE GAME. Read in "68k program header": NGH, word at $108. TAKEN FROM THE SLOT
        | TABLE ($D00124, the entry of the served slot $D00108), not reread at $108: this screen is
        | under REG_BRDFIX, where the cartridge does not answer on the hardware (SLOTCS, the
        | detection of `c0.s`; feedback of 2026-10-24, `docs/ESSAI-MATERIEL.md`).
        move.w  #CASE_NGH, %d1
        lea     .Lngh, %a2
        bsr     .Lligne
        moveq   #0, %d4
        move.b  0xD00108, %d4           | the served slot
        lsl.w   #2, %d4
        lea     0xD00124, %a2
        move.w  (%a2,%d4.w), %d4        | its NGH
        bsr     .Lhex4

        move.w  #CASE_START, %d1
        move.w  #0x5000, %d3
        lea     .Lstart, %a2
        bsr     .Lligne

| ----------------------------------------------------------------------------------
| THE WAIT FOR START P1, on an edge: released first, then pressed — a START held at the moment
| of the crash restarts nothing. Read in "Memory mapped registers": REG_STATUS_B bit 0,
| START P1, active low (like `dip.s`). Then THE RESTART THROUGH THE WATCHDOG (`dip.s`):
| a loop without a kick, identifiable in a trace.
        moveq   #0, %d6                 | 1 as soon as START has been seen released
.Lattente:
        bsr     .Lsync
        btst    #0, STATUS_B
        beq.s   1f
        moveq   #1, %d6
        bra.s   .Lattente
1:      tst.w   %d6
        beq.s   .Lattente
        clr.l   DRAPEAU                 | else a boot exception, before its clearing, would freeze
.Lrelance:
        bra.s   .Lrelance               | without a kick: the watchdog bites

| AN EXCEPTION IN THIS HANDLER. The loop of `_piege` (`c0.s` until now): kicks to
| the watchdog, so that the board does not restart and the address stays in the trace.
_plantage_double:
        move.b  %d0, WATCHDOG
        bra.s   _plantage_double

| ----------------------------------------------------------------------------------
| THE PASSING OF LINE $1F0, like `ecran.s` and `dip.s` (measured,
| `2026-10-17-diagnostic-b2b-minasan.tsv`); watchdog on every turn. Clobbers %d0.
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

| A LINE: the address %d1, then the string %a2. The `rts` of the previous character and the
| `bsr` take more than 16 cycles between a data word and the address ("VRAM").
.Lligne:
        move.w  %d1, (%a1)
| A STRING terminated by 0, following on. Clobbers %d2, %a2.
.Ltexte:
        moveq   #0, %d2
        move.b  (%a2)+, %d2
        beq.s   1f
        bsr.s   .Lcar
        bra.s   .Ltexte
1:      rts

| A CHARACTER %d2 (ASCII), with %d3. More than 12 cycles between two data words, by the call
| alone. Clobbers %d2.
.Lcar:
        add.w   %d3, %d2
        move.w  %d2, (%a0)
        rts

| %d4 IN HEXADECIMAL DIGITS: 8 (.Lhex8), 4 (.Lhex4, low word) or 2 (.Lhex2, low
| byte). Clobbers %d2, %d4, %d5.
.Lhex2:
        ror.l   #8, %d4
        moveq   #2-1, %d5
        bra.s   .Lhexn
.Lhex4:
        swap    %d4
        moveq   #4-1, %d5
        bra.s   .Lhexn
.Lhex8:
        moveq   #8-1, %d5
.Lhexn:
        rol.l   #4, %d4
        moveq   #0x0F, %d2
        and.w   %d4, %d2
        cmpi.w  #10, %d2
        bcs.s   1f
        addq.w  #7, %d2                 | 10-15 → "A"-"F"
1:      addi.w  #0x30, %d2
        bsr.s   .Lcar
        dbra    %d5, .Lhexn
        rts

| %d4.w (0 to 99) IN DECIMAL, without a leading zero. Clobbers %d2, %d4.
.Ldecimal:
        andi.l  #0xFFFF, %d4
        divu    #10, %d4
        tst.w   %d4
        beq.s   1f
        moveq   #0x30, %d2
        add.w   %d4, %d2
        bsr.s   .Lcar
1:      swap    %d4
        moveq   #0x30, %d2
        add.w   %d4, %d2
        bra.s   .Lcar

| ----------------------------------------------------------------------------------
| THE DATA.
        .balign 2
.Lcouleurs:                             | entry 1 of palettes 1 to 5
        .word   0x0BBB                  | 1 the values
        .word   0x0F44                  | 2 the title
        .word   0x0FE3                  | 3 the exception's name
        .word   0x0777                  | 4 the door
        .word   0x02F4                  | 5 START

| The names, by code: the 68000 vector number ("68k vector table"), then 32 to 34
| for the shared slots. 0 and 1 do not arrive here. No comma: it is not
| measured (`measured/2026-10-20-sfix-glyphes.tsv`).
.Lnoms:
        .long   .Ln_res, .Ln_res, .Ln_bus, .Ln_adr, .Ln_ill, .Ln_div, .Ln_chk, .Ln_trapv
        .long   .Ln_priv, .Ln_trace, .Ln_linea, .Ln_linef, .Ln_res, .Ln_res, .Ln_res, .Ln_uninit
        .long   .Ln_res, .Ln_res, .Ln_res, .Ln_res, .Ln_res, .Ln_res, .Ln_res, .Ln_res
        .long   .Ln_spur, .Ln_irq, .Ln_irq, .Ln_irq, .Ln_irq, .Ln_irq, .Ln_irq, .Ln_irq
        .long   .Ln_426, .Ln_414, .Ln_41a
.Ln_bus:        .asciz  "BUS ERROR"
.Ln_adr:        .asciz  "ADDRESS ERROR"
.Ln_ill:        .asciz  "ILLEGAL INSTRUCTION"
.Ln_div:        .asciz  "DIVISION BY ZERO"
.Ln_chk:        .asciz  "CHK INSTRUCTION"
.Ln_trapv:      .asciz  "TRAPV INSTRUCTION"
.Ln_priv:       .asciz  "PRIVILEGE VIOLATION"
.Ln_trace:      .asciz  "TRACE"
.Ln_linea:      .asciz  "LINE A INSTRUCTION"
.Ln_linef:      .asciz  "LINE F INSTRUCTION"
.Ln_uninit:     .asciz  "UNINITIALIZED INTERRUPT"
.Ln_res:        .asciz  "RESERVED VECTOR"
.Ln_spur:       .asciz  "SPURIOUS INTERRUPT"
.Ln_irq:        .asciz  "INTERRUPT AUTOVECTOR"
.Ln_426:        .asciz  "DIV/CHK/TRAPV/LINE A-F/IRQ/RESERVED"
.Ln_414:        .asciz  "ILLEGAL INSTRUCTION OR LINE A/F"
.Ln_41a:        .asciz  "PRIVILEGE/DIVIDE/CHK/TRAPV"
.Ltitre:        .asciz  "SYSTEM CRASH"
.Lvecteur:      .asciz  "  VECTOR "
.Lvia:          .asciz  "ENTRY C004"
.Lvia_bios:     .asciz  "ENTRY BIOS VECTOR TABLE"
.Lpc:           .asciz  "PC "
.Lsr:           .asciz  "   SR "
.Lacces:        .asciz  "ACCESS "
.Llecture:      .asciz  " READ"
.Lecriture:     .asciz  " WRITE"
.Linstr:        .asciz  " INSTRUCTION"
.Ldonnee:       .asciz  " DATA"
.Lir:           .asciz  "IR "
.Letat:         .asciz  "   STATUS "
.Ld:            .asciz  "D"
.La:            .asciz  "   A"
.Lusp:          .asciz  "USP "
.Lngh:          .asciz  "GAME NGH "
.Lstart:        .asciz  "PRESS START TO RESTART"
        .balign 2
