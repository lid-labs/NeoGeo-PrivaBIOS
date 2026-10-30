| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| THE SELF-TESTS — a sub-menu of the TEST screen (`dip.s`), line "HARDWARE TESTS".
|
| Called by `jsr _autotests` from the soft-DIP editor, IRQs masked (SR = $2700
| since `_demarrage`), backup RAM unlocked, fix layer on the board's font
| (REG_BRDFIX, set by `dip.s`). Exit: all registers given back, palettes 0-15 of
| bank 0 at zero apart from the reference, bank 0 selected; the caller redraws its screen.
|
| NO ORACLE: neither the reference BIOS's tests nor those of a third-party BIOS are read.
| The hand-over is "Layer 3 → the self-tests, 2026-10-21" (`docs/RELECTURE-CONTRATS.md`).
| "measured": a named record; "read in": a page of the NeoGeo Development Wiki;
| "ASSUMED": neither one nor the other.
|
| THE FOUR MEMORY TESTS, the same patterns everywhere: four data patterns ($0000,
| $FFFF, $5555, $AAAA: each bit at 0 and at 1, neighbouring bits opposite), each written over
| the whole area then read back; then two address patterns: each word receives a value drawn
| from its address, then its complement, the whole area written before any read-back — a
| stuck or shorted address line makes two words overlap, and the
| first one read back carries the value of the other. Result: OK, or the first faulty word,
| the value written and the value read. Word accesses, at even addresses only.
|   WORK RAM    $100000-$10FFFF, in two stages (see `.Lt_ram`).
|   PALETTE RAM $400000-$401FFF, both banks, in slices during blanking.
|   VRAM        through REG_VRAMADDR / REG_VRAMRW / REG_VRAMMOD: $0000-$85FF and $8700-$87FF.
|   BACKUP RAM  $D00000-$D0FFFF, NON-destructive: complement word by word.
| Then INPUT TEST, COLOR BARS and CROSSHATCH, and CARTRIDGE CRC (`crc.s`, 2026-10-25), just
| before EXIT: from WORK RAM, "down" four and five times still lead to INPUT TEST and COLOR
| BARS; CROSSHATCH is at "up" three times, CARTRIDGE CRC at two, EXIT at one.
|
| THE DISPLAY, like `dip.s`: fix layer only, $7000 + 32 × column + line, REG_VRAMMOD at
| 32 to write a line; 8×8 font = ASCII tile, 8×16 = $100/$200 + ASCII;
| stroke colour in entry 1, entries 2-15 black (`measured/2026-10-20-sfix-glyphes.tsv`).
| Palettes: 1 the text, 2 the chosen line, 3 the title, 4 the help, 5 OK / pressed, 6 FAIL.
| ==================================================================================

        .section .haut, "ax"
        .global _autotests

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    P1CNT,    0x300000
        .equ    WATCHDOG, 0x300001      | on write
        .equ    DIPSW,    0x300001      | on read
        .equ    SYSTYPE,  0x300081
        .equ    STATUS_A, 0x320001
        .equ    P2CNT,    0x340000
        .equ    STATUS_B, 0x380000
        .equ    SRAMUNLOCK, 0x3A001D
        .equ    PALBANK0, 0x3A000F
        .equ    PALBANK1, 0x3A001F
        .equ    PALETTES, 0x400000
        .equ    FOND,     0x401FFE

        | The work RAM ("Memory map": $100000-$10FFFF), in two areas.
        .equ    RAM_BAS,  0x100000
        .equ    RAM_H,    0x10F000      | the high area, kept by copying
        .equ    RAM_FIN,  0x110000
        .equ    COPIE,    0x100000      | where the high area is set aside, already tested
        .equ    TRANCHE,  4096          | bytes between two watchdog kicks

        | The results, in the frame: 4 tests × R_TAILLE. +0 state (0 not run, 1 OK,
        | 2 FAIL, 3 in progress), +1 bank, +2 address, +6 written, +8 read.
        .equ    R_TAILLE, 12
        .equ    N_MEM,    4             | the memory tests
        .equ    F_RES,    -(N_MEM * R_TAILLE)

        | The layout: the menu line, column 3.
        .equ    CASE_TITRE, 0x7000 + 13 * 32 + 3       | 8×16, lines 3-4
        .equ    CASE_MENU,  0x7000 + 3 * 32            | + the line
        .equ    CASE_AIDE1, 0x7000 + 3 * 32 + 26
        .equ    CASE_AIDE2, 0x7000 + 3 * 32 + 27
        .equ    N_LIGNES,   9

| ----------------------------------------------------------------------------------
_autotests:
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        link    %a6, #F_RES
        lea     F_RES(%a6), %a0
        moveq   #(N_MEM * R_TAILLE / 4) - 1, %d0
1:      clr.l   (%a0)+
        dbra    %d0, 1b
        moveq   #0, %d7                 | %d7: the chosen line
        bsr     .Lmenu
        moveq   #0, %d5                 | a button already held (the A that opens) does not count
        bsr     .Lentrees

| THE MENU LOOP, one frame per turn. %d5: the buttons of the previous frame.
.Lboucle:
        bsr     .Lsync
        bsr     .Lentrees
        btst    #5, %d0                 | START: back to the TEST screen
        bne     .Lsortie
        btst    #0, %d0                 | up
        beq.s   2f
        move.w  %d7, %d0
        subq.w  #1, %d7
        bpl.s   1f
        moveq   #N_LIGNES - 1, %d7
1:      bsr     .Lligne                 | the old one, then the new one
        move.w  %d7, %d0
        bsr     .Lligne
        bra.s   .Lboucle
2:      btst    #1, %d0                 | down
        beq.s   3f
        move.w  %d7, %d0
        addq.w  #1, %d7
        cmpi.w  #N_LIGNES, %d7
        bcs.s   1b
        moveq   #0, %d7
        bra.s   1b
3:      andi.b  #0x18, %d0              | A or right: run
        beq.s   .Lboucle

| RUN LINE %d7.
        cmpi.w  #N_LIGNES - 1, %d7      | EXIT
        beq     .Lsortie
        cmpi.w  #4, %d7
        bcc.s   .Lmire
        lea     F_RES(%a6), %a3         | a memory test: "TESTING" first
        move.w  %d7, %d0
        mulu    #R_TAILLE, %d0
        move.b  #3, (%a3,%d0.w)
        move.w  %d7, %d0
        bsr     .Lligne
        move.w  %d7, %d0
        lsl.w   #2, %d0
        lea     .Ltests, %a0
        movea.l (%a0,%d0.w), %a0
        movem.l %d5/%d7/%a6, -(%sp)
        jsr     (%a0)                   | exit: %d0 0 or 1, %a2, %d1, %d2, %d3
        movem.l (%sp)+, %d5/%d7/%a6
        lea     F_RES(%a6), %a3
        move.w  %d7, %d4
        mulu    #R_TAILLE, %d4
        adda.w  %d4, %a3
        move.b  #1, (%a3)
        tst.l   %d0
        beq.s   1f
        move.b  #2, (%a3)
1:      move.b  %d3, 1(%a3)
        move.l  %a2, 2(%a3)
        move.w  %d1, 6(%a3)
        move.w  %d2, 8(%a3)
        cmpi.w  #1, %d7
        bne.s   1f
        bsr     .Lp_nettoyer
1:      cmpi.w  #2, %d7
        bne.s   .Lapres
        bsr     .Lv_remettre
        bra.s   .Lapres
.Lmire:
        move.w  %d7, %d0
        lsl.w   #2, %d0
        lea     .Ltests, %a0
        movea.l (%a0,%d0.w), %a0
        movem.l %d5/%d7/%a6, -(%sp)
        jsr     (%a0)
        movem.l (%sp)+, %d5/%d7/%a6
.Lapres:
        bsr     .Lmenu
        bsr     .Lentrees               | a button still held does not count
        bra     .Lboucle

.Lsortie:
        bsr     .Lsync
        bsr     .Lpal_zero
        unlk    %a6
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rts

| ----------------------------------------------------------------------------------
| WORK RAM. What the BIOS occupies during this test, read in the code: the stack (set at
| $10F300 by `_demarrage`, it grows down), and the BIOS variables of $10F300-$10FFFF
| still read after the editor — BIOS_COUNTRY_CODE, BIOS_GAME_DIP (which the editor holds
| in its table), BIOS_MESS_POINT, the flag of `plantage.s` — not counting the frame of
| `dip.s`, in the stack. The stack depth here, counted in the code: 4 (jsr from
| `c0.s`) + 60 (movem of `dip.s`) + 4 + 386 (its frame, `link #F_LIEN`: 22 × 12 of table, 32
| of buffer, 4, 1, 1, 4, 4, eight bytes of states, 2, 2, 5 × 12 of the CABINET SETTINGS
| sub-screen, and 4 of the 8×16 list) + 8
| (bsr, jsr) + 60 (movem here) + 4 + 48 (this frame) + 16 (movem and jsr of the run) + 12 (three
| calls at most; the test does not call `.Lsync`) = 602 bytes, so nothing below $10F0A6: the low
| area $100000-$10EFFF is free and is tested without precaution; the game's save is restored
| there after the editor (`_slot_present`, `c0.s`), which makes this test non-destructive for
| the game. The high area $10F000-$10FFFF (4 KiB) is first copied into the low area
| just tested, the stack is moved there by the same offset, the high area is tested, then
| copied back. Nothing else writes to the work RAM: IRQs masked, no call to the game.
| Finally the low area outside the copy is read back: its last address pattern must be
| intact there, otherwise a write to the high area touched it (lines A12-A15). The low → high
| direction is not taken: one of these lines stuck at 1 sends the writes of $10E0F8-$10E2FF
| onto the real stack before it is moved, and the machine crashes or restarts instead of a FAIL.
| Exit: %d0 0 or 1, %a2 the address, %d1 written, %d2 read, %d3 = 0.
.Lt_ram:
        lea     RAM_BAS, %a4
        lea     RAM_H, %a5
        bsr     .Lm_complet
        tst.l   %d0
        bne.s   9f
        lea     RAM_H, %a0
        lea     COPIE, %a1
        move.w  #(0x1000 / 4) - 1, %d3
1:      move.l  (%a0)+, (%a1)+
        dbra    %d3, 1b
        suba.l  #RAM_H - COPIE, %sp     | the stack in the copy: its contents are there
        lea     RAM_H, %a4
        lea     RAM_FIN, %a5
        bsr     .Lm_complet             | %d0-%d2, %a2: the result, kept below
        lea     COPIE, %a0
        lea     RAM_H, %a1
        move.w  #(0x1000 / 4) - 1, %d3
1:      move.l  (%a0)+, (%a1)+
        dbra    %d3, 1b
        adda.l  #RAM_H - COPIE, %sp
        tst.l   %d0
        bne.s   9f
        lea     COPIE + 0x1000, %a4
        lea     RAM_H, %a5
        moveq   #-1, %d1                | the last pattern: the complemented address
        moveq   #1, %d6
        bsr     .Lm_relire_tout
9:      moveq   #0, %d3
        rts

| A COMPLETE TEST on [%a4, %a5): the six patterns. Clobbers %d0-%d2, %d4, %d6, %a0-%a3.
.Lm_complet:
        lea     .Lmotifs, %a3
        moveq   #6 - 1, %d4
1:      move.w  (%a3)+, %d1
        move.w  (%a3)+, %d6
        bsr.s   .Lm_ecrire_tout
        bsr.s   .Lm_relire_tout
        tst.l   %d0
        bne.s   9f
        dbra    %d4, 1b
9:      rts

| THE WHOLE AREA [%a4, %a5), in slices of TRANCHE bytes, a watchdog kick
| between two (at worst the read-back of the address pattern: ≈ 54 cycles per word, ≈ 110,000
| per slice, ≈ 1/29 of the 3,244,030 watchdog cycles that `c0.s` cites). %d1, %d6: see `.Lm_remplir`.
.Lm_ecrire_tout:
        movea.l %a4, %a0
1:      lea     TRANCHE(%a0), %a1
        cmpa.l  %a5, %a1
        bls.s   2f
        movea.l %a5, %a1
2:      bsr.s   .Lm_remplir
        move.b  %d0, WATCHDOG
        movea.l %a1, %a0
        cmpa.l  %a5, %a0
        bcs.s   1b
        rts
.Lm_relire_tout:
        movea.l %a4, %a0
1:      lea     TRANCHE(%a0), %a1
        cmpa.l  %a5, %a1
        bls.s   2f
        movea.l %a5, %a1
2:      bsr.s   .Lm_verif
        bne.s   9f
        move.b  %d0, WATCHDOG
        movea.l %a1, %a0
        cmpa.l  %a5, %a0
        bcs.s   1b
        moveq   #0, %d0
9:      rts

| WRITE [%a0, %a1). %d6 = 0: the data %d1 everywhere; otherwise the address pattern, the word at
| address a receiving (a >> 1) xor %d1 — 15 bits of word index over 64 KiB, hence one
| value per word of the area. Clobbers %d0, %a2.
.Lm_remplir:
        movea.l %a0, %a2
        tst.w   %d6
        bne.s   2f
1:      move.w  %d1, (%a2)+
        cmpa.l  %a1, %a2
        bcs.s   1b
        rts
2:      move.l  %a2, %d0
        lsr.l   #1, %d0
        eor.w   %d1, %d0
        move.w  %d0, (%a2)+
        cmpa.l  %a1, %a2
        bcs.s   2b
        rts

| READ BACK [%a0, %a1), same values. Exit: %d0 = 0 and Z, or %d0 = 1 with %a2 the faulty
| word, %d1 the written, %d2 the read. Clobbers %d0, %d2, %a2 (and %d1 on an address fault).
.Lm_verif:
        movea.l %a0, %a2
        tst.w   %d6
        bne.s   2f
1:      move.w  (%a2)+, %d2
        cmp.w   %d1, %d2
        bne.s   .Lm_faute
        cmpa.l  %a1, %a2
        bcs.s   1b
        moveq   #0, %d0
        rts
2:      move.l  %a2, %d0
        lsr.l   #1, %d0
        eor.w   %d1, %d0
        move.w  (%a2)+, %d2
        cmp.w   %d0, %d2
        bne.s   3f
        cmpa.l  %a1, %a2
        bcs.s   2b
        moveq   #0, %d0
        rts
3:      move.w  %d0, %d1
.Lm_faute:
        subq.l  #2, %a2
        moveq   #1, %d0
        rts

| ----------------------------------------------------------------------------------
| PALETTE RAM. Read in "Palettes": $400000-$401FFF, two banks selected by
| REG_PALBANK0/1, and writing during display makes snow. The whole area is therefore
| touched in slices right after line $1F0 passes: 40 lines of blanking
| ASSUMED (the line counter goes from $1F0 to $1FF then from $F8 to $10F before
| display), ≈ 30,000 cycles. The slices, counted from the 68000's instruction
| timings (ASSUMED: no wait state on the palette RAM): 64 words for the four
| data patterns plus the address write (≈ 18,000 cycles), 128 to read back
| the address and write its complement (≈ 12,000), 256 to read back the complement (≈ 14,000).
| The bench would not see the snow (MAME does not render it): the slicing is not judged there.
| Bank 0 first, bank 1 next; the menu screen flickers meanwhile, its
| palettes being under test. Exit like `.Lt_ram`, %d3 the faulty bank.
.Lt_pal:
        moveq   #0, %d3
.Lp_banque:
        bsr     .Lsync
        move.b  %d0, PALBANK0
        tst.w   %d3
        beq.s   1f
        move.b  %d0, PALBANK1
1:      lea     PALETTES, %a4
.Lp_a:  bsr     .Lsync                  | data, then the address: 64 words per frame
        movea.l %a4, %a0
        lea     128(%a4), %a1
        lea     .Lmotifs, %a3
        moveq   #4 - 1, %d4
1:      move.w  (%a3)+, %d1
        move.w  (%a3)+, %d6
        bsr     .Lm_remplir
        bsr     .Lm_verif
        bne.s   9f
        dbra    %d4, 1b
        moveq   #0, %d1
        moveq   #1, %d6
        bsr     .Lm_remplir
        movea.l %a1, %a4
        cmpa.l  #PALETTES + 0x2000, %a4
        bcs.s   .Lp_a
        lea     PALETTES, %a4
.Lp_b:  bsr     .Lsync                  | the address read back, its complement written
        movea.l %a4, %a0
        lea     256(%a4), %a1
        moveq   #0, %d1
        moveq   #1, %d6
        bsr     .Lm_verif
        bne.s   9f
        moveq   #-1, %d1
        bsr     .Lm_remplir
        movea.l %a1, %a4
        cmpa.l  #PALETTES + 0x2000, %a4
        bcs.s   .Lp_b
        lea     PALETTES, %a4
.Lp_c:  bsr     .Lsync                  | the complement read back
        movea.l %a4, %a0
        lea     512(%a4), %a1
        moveq   #-1, %d1
        moveq   #1, %d6
        bsr     .Lm_verif
        bne.s   9f
        movea.l %a1, %a4
        cmpa.l  #PALETTES + 0x2000, %a4
        bcs.s   .Lp_c
        addq.w  #1, %d3
        cmpi.w  #2, %d3
        bcs     .Lp_banque
        moveq   #0, %d3
        moveq   #0, %d0
9:      rts

| BOTH BANKS RESET TO ZERO, in 1 KiB slices during blanking, the reference
| $400000 at $8000 in each ("Palettes": "always has to be pure black ($8000)";
| ASSUMED for bank 1, the page does not distinguish). Bank 0 stays selected; the menu
| sets its colours again afterwards. Clobbers %d0, %d1, %d3, %a0.
.Lp_nettoyer:
        moveq   #1, %d3
1:      bsr     .Lsync
        move.b  %d0, PALBANK0
        tst.w   %d3
        beq.s   2f
        move.b  %d0, PALBANK1
2:      lea     PALETTES, %a0
3:      bsr     .Lsync
        move.w  #256 - 1, %d1
4:      clr.l   (%a0)+
        dbra    %d1, 4b
        cmpa.l  #PALETTES + 0x2000, %a0
        bcs.s   3b
        bsr     .Lsync
        move.w  #0x8000, PALETTES
        dbra    %d3, 1b
        rts

| ----------------------------------------------------------------------------------
| VRAM. Read in "VRAM": low area $0000-$7FFF (SCB1, fix layer map at $7000,
| extension $7500-$7FFF), high area $8000-$87FF (SCB2-4 up to $85FF, sprite lists
| of the even and odd lines $8600-$86FF, $8700-$87FF free); going from one area to
| the other by setting REG_VRAMADDR again. The lists $8600-$86FF are NOT tested: the page
| gives them to the LSPC, which rewrites them during display and would make the read-back lie
| (ASSUMED as to the timing). That leaves 32,768 + 1,536 + 256 words.
| THE PACE, read in the same page (Access timing): 12 cycles between two data, 16 between
| a data and the next address, 16 between an address and the read of its data. The
| read is done here by setting the address again for every word (the page does not say that
| a read advances the address), then three `nop` (12) before the `move.w` whose data access
| comes after its extension words: more than 16, counted (ASSUMED with no wait state).
| The screen shows the pattern during the test and is redrawn afterwards.
| Exit like `.Lt_ram`, %a2 the VRAM address (word).
.Lt_vram:
        move.w  #1, VRAMMOD
        lea     .Lmotifs, %a3
        moveq   #6 - 1, %d7
1:      move.w  (%a3)+, %d1
        move.w  (%a3)+, %d6
        bsr.s   .Lv_passe
        tst.l   %d0
        bne.s   9f
        dbra    %d7, 1b
9:      moveq   #0, %d3
        rts

| ONE PASS: the three areas written, then read back. Clobbers %d0, %d2-%d5, %a1, %a2, %a4.
.Lv_passe:
        lea     .Lzones, %a4
        moveq   #3 - 1, %d5
1:      move.w  (%a4)+, %d3
        move.w  (%a4)+, %d4
        bsr.s   .Lv_pas
        bsr.s   .Lv_remplir
        dbra    %d5, 1b
        lea     .Lzones, %a4
        moveq   #3 - 1, %d5
2:      move.w  (%a4)+, %d3
        move.w  (%a4)+, %d4
        bsr.s   .Lv_pas
        bsr.s   .Lv_verif
        bne.s   9f
        dbra    %d5, 2b
        moveq   #0, %d0
9:      rts

| THE FIRST VALUE %d2 and THE STEP %a1 of an area starting at %d3. Data (%d6 = 0):
| %d1 everywhere. Address: (address xor %d1), which advances by +1 for %d1 = 0 and by -1 for
| %d1 = $FFFF.
.Lv_pas:
        move.w  %d1, %d2
        suba.l  %a1, %a1
        tst.w   %d6
        beq.s   1f
        eor.w   %d3, %d2
        addq.w  #1, %a1
        tst.w   %d1
        beq.s   1f
        subq.w  #2, %a1
1:      rts

| WRITE %d4 words from VRAM address %d3, REG_VRAMMOD at 1. Between two data: 16
| (the write) + 4 + 16 + 10 cycles. Clobbers %d2, %d4.
.Lv_remplir:
        move.w  %d3, VRAMADDR
        subq.w  #1, %d4
1:      move.w  %d2, VRAMRW
        add.w   %a1, %d2
        move.b  %d0, WATCHDOG
        dbra    %d4, 1b
        rts

| READ BACK %d4 words from %d3. Fault: %d0 = 1, %a2 the address, %d1 written, %d2 read.
.Lv_verif:
        subq.w  #1, %d4
1:      move.w  %d3, VRAMADDR
        nop
        nop
        nop
        move.w  VRAMRW, %d0
        cmp.w   %d2, %d0
        bne.s   2f
        addq.w  #1, %d3
        add.w   %a1, %d2
        move.b  %d0, WATCHDOG
        dbra    %d4, 1b
        moveq   #0, %d0
        rts
2:      move.w  %d2, %d1
        move.w  %d0, %d2
        moveq   #0, %d0
        move.w  %d3, %d0
        movea.l %d0, %a2
        moveq   #1, %d0
        rts

| THE VRAM RESTORED: low area and $8700-$87FF at zero (ASSUMED: nothing there expects
| anything else — at power-on it is arbitrary, and `ecran.s` sets there only
| LSP_1st and FIX_CLEAR), then LSP_1st (`video.s`) for SCB1 of sprite 0 and SCB2-4, like
| the boot screen; the menu sets FIX_CLEAR again. $8600-$86FF was not touched.
.Lv_remettre:
        move.w  #1, VRAMMOD
        move.w  #0x0000, VRAMADDR
        moveq   #0, %d0
        move.w  #0x8000 - 1, %d1
1:      move.w  %d0, VRAMRW
        move.b  %d0, WATCHDOG
        dbra    %d1, 1b
        nop
        move.w  #0x8700, VRAMADDR
        move.w  #0x100 - 1, %d1
2:      move.w  %d0, VRAMRW
        move.b  %d0, WATCHDOG
        dbra    %d1, 2b
        jsr     _lsp_1st
        rts

| ----------------------------------------------------------------------------------
| BACKUP RAM, NON-DESTRUCTIVE. Read in "Memory map" / "Backup RAM": $D00000-$D0FFFF, the
| games' data, and our settings ($D00210, `reglages.s`). For each word: read it,
| write its complement, read it back, put the original back at once, then check that it
| came back. The complement tests each bit in the state opposite to its own; neither address
| pattern nor fixed pattern, which would overwrite the area.
| WHY IT IS SAFE: IRQs masked (SR = $2700) and no other write, so at any
| instant at most ONE word differs from the original, for the time of two instructions (its
| read-back, then its restoring). A power cut at that moment leaves that single word
| complemented: on the signature of `c0.s` or the block of `reglages.s`, their check refuses
| it; elsewhere, the game will read it back as is. A faulty word is restored before being
| reported.
| THE LOCK: read in "Memory mapped registers", REG_SRAMUNLOCK ($3A001D) opens writing.
| We write it, but we do NOT close: the editor, after us, still writes the game's block,
| and `c0.s` writes REG_SRAMLOCK right after its return. A watchdog on every word.
.Lt_bram:
        move.b  %d0, SRAMUNLOCK
        lea     0xD00000, %a2
        move.w  #0x8000 - 1, %d4
1:      move.w  (%a2), %d1              | the original
        move.w  %d1, %d3
        not.w   %d3
        move.w  %d3, (%a2)              | the complement
        move.w  (%a2), %d2
        move.w  %d1, (%a2)              | the original, put back
        cmp.w   %d3, %d2
        bne.s   2f
        cmp.w   (%a2), %d1
        bne.s   3f
        addq.l  #2, %a2
        move.b  %d0, WATCHDOG
        dbra    %d4, 1b
        moveq   #0, %d0
        moveq   #0, %d3
        rts
2:      move.w  %d3, %d1                | the complement did not hold
        bra.s   4f
3:      move.w  (%a2), %d2              | the original did not come back
4:      moveq   #1, %d0
        moveq   #0, %d3
        rts

| ----------------------------------------------------------------------------------
| INPUT TEST. Read in "Memory mapped registers", all active low: REG_P1CNT
| ($300000) and REG_P2CNT ($340000) bits 0-7 up, down, left, right, A, B, C, D;
| REG_STATUS_B ($380000) bits 0-3 START P1, SELECT P1, START P2, SELECT P2; REG_STATUS_A
| ($320001) bits 0, 1 coins 1 and 2, bit 2 "Service button"; REG_DIPSW ($300001) the
| board switches. REG_SYSTYPE ($300081) bit 7, the TEST button: measured active
| low (`dip.s`). ASSUMED: the eight switches at bits 0-7, no. n at bit n-1
| (the page names the functions bit by bit without numbering the switches). Coins 3 and 4
| (bits 3, 4 of REG_STATUS_A, 4- or 6-slot boards) not displayed.
| An element lit (palette 5) when its bit is at 0, unlit (palette 4) otherwise, redrawn
| on every frame. EXIT: START P1 held 60 frames in a row (≈ 1 s), since START is
| itself tested; the reminder is on screen.
| BOARD SWITCH 3 ON ("Mahjong Panel") AT OPENING: the mahjong panel page
| (`.Lt_mahjong`, DECISIONS §24). Read once, on entry, like the Japanese SNK BIOS and
| UniBIOS 4.0 (measured, `measured/2026-10-27-attentes-reference.tsv`): toggled during the
| test, the page does not change, and the switch's light comes on as before.
.Lt_entrees:
        btst    #2, DIPSW
        beq     .Lt_mahjong
        bsr     .Lsync
        jsr     _fix_clear
        move.w  #32, VRAMMOD
        bsr     .Ltitre_ecran
        lea     .Le_fixes, %a3          | the fixed labels: cell, string
1:      move.w  (%a3)+, %d1
        beq.s   2f
        move.w  #0x1000, %d3
        movea.l %a3, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        movea.l %a2, %a3
        move.l  %a3, %d0
        addq.l  #1, %d0
        andi.w  #0xFFFE, %d0
        movea.l %d0, %a3
        bra.s   1b
2:      move.w  #CASE_AIDE1, %d1
        move.w  #0x4000, %d3
        lea     .Le_aide, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        moveq   #0, %d6                 | frames of START P1 held
.Le_trame:
        bsr     .Lsync
        lea     .Le_elements, %a3
1:      move.l  (%a3)+, %d0             | the register, 0 at the end of the table
        beq.s   3f
        movea.l %d0, %a0
        move.b  (%a3)+, %d0             | the bit
        moveq   #0, %d1
        move.b  (%a3)+, %d1             | the cell
        lsl.w   #8, %d1
        move.b  (%a3)+, %d1
        move.w  #0x5000, %d3            | pressed
        move.b  (%a0), %d2
        btst    %d0, %d2
        beq.s   2f
        move.w  #0x4000, %d3            | released
2:      movea.l %a3, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        move.l  %a2, %d0
        addq.l  #1, %d0
        andi.w  #0xFFFE, %d0
        movea.l %d0, %a3
        bra.s   1b
3:      addq.w  #1, %d6
        btst    #0, STATUS_B
        beq.s   4f
        moveq   #0, %d6
4:      cmpi.w  #60, %d6
        bcs.s   .Le_trame
        rts

| ----------------------------------------------------------------------------------
| THE MAHJONG PANEL PAGE, 2026-10-27 (DECISIONS §24, the user's decision:
| copy the Japanese SNK BIOS and UniBIOS 4.0). MEASURED on them (`measured/2026-10-27-attentes-
| reference.tsv`): a page in place of the pads, one cell per key — A to G, H to N, PON, CHI,
| KAN, RON, REACH, START, SELECT —, 1 while it is held, 0 otherwise; then the coins, TEST and
| the switches. Here the same list, each key followed by its 0 or 1 (palette 5 held,
| 4 released), and the lights of the ordinary page for COIN, SERVICE, TEST and DIP. P2 is not
| there, as on theirs. The panel is scanned like `_io_mahjong` (`io.s`): REG_POUTPUT ← $09, $12,
| $24, one row at a time read in REG_P1CNT, active low; START and SELECT in REG_STATUS_B. The
| output stays at $24: the game sets its own at its first SYSTEM_IO. Exit from the screen:
| START P1 held 60 frames, like the ordinary page.
.Lt_mahjong:
        bsr     .Lsync
        jsr     _fix_clear
        move.w  #32, VRAMMOD
        bsr     .Ltitre_ecran
        lea     .Lm_fixes, %a3
1:      move.w  (%a3)+, %d1
        beq.s   2f
        move.w  #0x1000, %d3
        movea.l %a3, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        move.l  %a2, %d0
        addq.l  #1, %d0
        andi.w  #0xFFFE, %d0
        movea.l %d0, %a3
        bra.s   1b
2:      move.w  #CASE_AIDE1, %d1
        move.w  #0x4000, %d3
        lea     .Le_aide, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        moveq   #0, %d6                 | frames of START P1 held
.Lm_trame:
        bsr     .Lsync
        | %d4: the rows in positive logic, byte 0 A-G, 1 H-N, 2 PON-REACH, 3 START/SELECT.
        move.b  #0x09, 0x380001         | REG_POUTPUT: row A-G
        move.b  P1CNT, %d4
        lsl.l   #8, %d4
        move.b  #0x12, 0x380001         | row H-N
        move.b  P1CNT, %d4
        lsl.l   #8, %d4
        move.b  #0x24, 0x380001         | row PON-REACH
        move.b  P1CNT, %d4
        lsl.l   #8, %d4
        move.b  STATUS_B, %d4
        not.l   %d4
        lea     .Lm_touches, %a3
1:      move.w  (%a3)+, %d1             | the cell, 0 at the end of the table
        beq.s   3f
        move.b  (%a3)+, %d0             | the bit in %d4 (row × 8 + bit)
        addq.l  #1, %a3
        move.w  #0x4000, %d3
        moveq   #0x30, %d5              | "0"
        btst    %d0, %d4
        beq.s   2f
        move.w  #0x5000, %d3
        moveq   #0x31, %d5              | "1"
2:      movea.l %a3, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        moveq   #0x20, %d2
        bsr     .Lcar
        move.w  %d5, %d2
        bsr     .Lcar
        move.l  %a2, %d0
        addq.l  #1, %d0
        andi.w  #0xFFFE, %d0
        movea.l %d0, %a3
        bra.s   1b
3:      lea     .Lm_elements, %a3       | COIN, SERVICE, TEST, DIP: the lights of the ordinary page
1:      move.l  (%a3)+, %d0
        beq.s   3f
        movea.l %d0, %a0
        move.b  (%a3)+, %d0
        moveq   #0, %d1
        move.b  (%a3)+, %d1
        lsl.w   #8, %d1
        move.b  (%a3)+, %d1
        move.w  #0x5000, %d3
        move.b  (%a0), %d2
        btst    %d0, %d2
        beq.s   2f
        move.w  #0x4000, %d3
2:      movea.l %a3, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        move.l  %a2, %d0
        addq.l  #1, %d0
        andi.w  #0xFFFE, %d0
        movea.l %d0, %a3
        bra.s   1b
3:      addq.w  #1, %d6
        btst    #0, STATUS_B
        beq.s   4f
        moveq   #0, %d6
4:      cmpi.w  #60, %d6
        bcs     .Lm_trame
        rts

| ----------------------------------------------------------------------------------
| THE TEST PATTERNS. A filled tile: MEASURED under MAME on 2026-10-21 (our image, aof, -bios
| euro, MAME's board SFIX; local lua probe, not versioned, that sets tiles
| $000-$7FF under a palette whose entry i is a red of level i, then reads each
| 8×8 cell of the capture): $000 is filled with index 1, $020 (and $120, $220) filled with
| index 2, $108-$10F filled with index 10; below $700, no tile filled with an index other
| than 1, 2 or 10, and beyond that the contents "may vary" ("SFIX ROM"), so not used. Three
| filled indexes, sixteen palettes: at most 48 colours at once, when four bars of 15 steps
| need 60 — hence two pages: RED, GREEN, BLUE, then WHITE. Step 0 is the black of the
| background. Palette s (1-15): entry 1 = red s, 2 = green s, 10 = blue s ("Colors":
| $0RGB); white page: entry 1 = grey s. Palette 0: entry 1 white for the text,
| 2 black for the background (tile $020 everywhere). A changes page, START exits.
        .equ    T_ROUGE, 0x000
        .equ    T_VERT,  0x020
        .equ    T_BLEU,  0x108
.Lt_barres:
        moveq   #0, %d7                 | the page
        moveq   #0, %d5
        bsr     .Lentrees
.Lb_page:
        bsr     .Lsync
        bsr     .Lpal_zero
        move.w  #0x0FFF, PALETTES + 2   | palette 0, entry 1: the text
        lea     PALETTES + 32, %a0      | palette 1
        moveq   #1, %d4
1:      move.w  %d4, %d0                | red s, or grey s
        lsl.w   #8, %d0
        tst.w   %d7
        beq.s   2f
        move.w  %d4, %d0
        mulu    #0x111, %d0
2:      move.w  %d0, 2(%a0)
        tst.w   %d7
        bne.s   3f
        move.w  %d4, %d0
        lsl.w   #4, %d0
        move.w  %d0, 4(%a0)             | green s
        move.w  %d4, 20(%a0)            | blue s, entry 10
3:      lea     32(%a0), %a0
        addq.w  #1, %d4
        cmpi.w  #16, %d4
        bcs.s   1b
        bsr     .Lfond_plein
        move.w  #32, VRAMMOD
        tst.w   %d7
        bne.s   5f
        moveq   #6, %d6                 | red, lines 6-11
        move.w  #T_ROUGE, %d4
        bsr.s   .Lbarre
        moveq   #12, %d6                | green, 12-17
        move.w  #T_VERT, %d4
        bsr.s   .Lbarre
        moveq   #18, %d6                | blue, 18-23
        move.w  #T_BLEU, %d4
        bsr.s   .Lbarre
        lea     .Lb_rvb, %a3
        bra.s   6f
5:      moveq   #6, %d6                 | white, 6-23 in three goes
        move.w  #T_ROUGE, %d4
        bsr.s   .Lbarre
        moveq   #12, %d6
        bsr.s   .Lbarre
        moveq   #18, %d6
        bsr.s   .Lbarre
        lea     .Lb_blanc, %a3
6:      moveq   #0, %d3                 | palette 0
1:      move.w  (%a3)+, %d1             | the texts: cell, string
        beq.s   .Lb_attente
        movea.l %a3, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        move.l  %a2, %d0
        addq.l  #1, %d0
        andi.w  #0xFFFE, %d0
        movea.l %d0, %a3
        bra.s   1b
.Lb_attente:
        bsr     .Lsync
        bsr     .Lentrees
        btst    #5, %d0
        bne.s   9f
        btst    #4, %d0
        beq.s   .Lb_attente
        eori.w  #1, %d7
        bra     .Lb_page
9:      rts

| ONE BAR: six lines from %d6, tile %d4, columns 4-35, two columns per step;
| step 0 left to the black background. REG_VRAMMOD at 32. Clobbers %d0-%d2.
.Lbarre:
        moveq   #6 - 1, %d2
1:      move.w  %d6, %d1
        addi.w  #0x7000 + 4 * 32, %d1
        move.w  %d1, VRAMADDR
        moveq   #0, %d1                 | the step, 0-15
2:      move.w  #0x0020, %d0
        tst.w   %d1
        beq.s   3f
        move.w  %d1, %d0
        ror.w   #4, %d0                 | palette s
        or.w    %d4, %d0
3:      move.w  %d0, VRAMRW
        move.w  %d0, VRAMRW             | > 12 cycles: the previous write takes 16
        addq.w  #1, %d1
        cmpi.w  #16, %d1
        bcs.s   2b
        addq.w  #1, %d6
        dbra    %d2, 1b
        rts

| CROSSHATCH: filled 8-pixel strokes (tile $020 under palette 1, entry 2
| white) every four cells, columns 0, 4 … 36 and 39, lines 2, 6 … 26 and 29 —
| the edges of the visible area ("Fix layer": lines 2 to 29). No one-pixel stroke:
| no tile of that drawing is measured. START exits.
.Lt_grille:
        bsr     .Lsync
        bsr     .Lpal_zero
        move.w  #0x0FFF, PALETTES + 32 + 4      | palette 1, entry 2
        move.w  #1, VRAMMOD
        move.w  #0x7000, VRAMADDR
        moveq   #0, %d4                 | the column
1:      moveq   #0, %d6                 | the line
2:      move.w  #0x0020, %d0
        move.w  %d4, %d1
        andi.w  #3, %d1
        beq.s   3f
        cmpi.w  #39, %d4
        beq.s   3f
        cmpi.w  #2, %d6
        bcs.s   4f
        cmpi.w  #29, %d6
        bhi.s   4f
        beq.s   3f
        move.w  %d6, %d1
        subq.w  #2, %d1
        andi.w  #3, %d1
        bne.s   4f
3:      move.w  #0x1020, %d0
4:      move.w  %d0, VRAMRW
        move.b  %d0, WATCHDOG
        addq.w  #1, %d6
        cmpi.w  #32, %d6
        bcs.s   2b
        addq.w  #1, %d4
        cmpi.w  #40, %d4
        bcs.s   1b
        moveq   #0, %d5
        bsr     .Lentrees
1:      bsr     .Lsync
        bsr     .Lentrees
        btst    #5, %d0
        beq.s   1b
        rts

| THE WHOLE FIX LAYER in tile $020, palette 0 (REG_VRAMMOD at 1). Clobbers %d0, %d1.
.Lfond_plein:
        move.w  #1, VRAMMOD
        move.w  #0x7000, VRAMADDR
        move.w  #0x0020, %d0
        move.w  #40 * 32 - 1, %d1
1:      move.w  %d0, VRAMRW
        dbra    %d1, 1b
        rts

| ----------------------------------------------------------------------------------
| THE MENU, all redrawn: palettes after line $1F0 passes, FIX_CLEAR, title,
| lines, help. Clobbers %d0-%d4, %d6, %a0-%a3.
.Lmenu:
        bsr     .Lsync
        bsr     .Lpal_zero
        move.w  #0x8000, FOND           | like `dip.s`
        lea     .Lcouleurs, %a3
        lea     PALETTES + 32 + 2, %a0  | palette 1, entry 1
        moveq   #6 - 1, %d0
1:      move.w  (%a3)+, (%a0)
        lea     32(%a0), %a0
        dbra    %d0, 1b
        jsr     _fix_clear
        move.w  #32, VRAMMOD
        bsr.s   .Ltitre_ecran
        moveq   #0, %d0
1:      move.w  %d0, -(%sp)
        bsr     .Lligne
        move.w  (%sp)+, %d0
        addq.w  #1, %d0
        cmpi.w  #N_LIGNES, %d0
        bcs.s   1b
        move.w  #0x4000, %d3
        move.w  #CASE_AIDE1, %d1
        lea     .Ltxt_aide1, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        move.w  #CASE_AIDE2, %d1
        lea     .Ltxt_aide2, %a2
        bsr     .Lplacer
        bra     .Lchaine

| THE TITLE in 8×16, palette 3. Clobbers %d1-%d3, %a2.
.Ltitre_ecran:
        move.w  #CASE_TITRE, %d1
        move.w  #0x3100, %d3
        lea     .Ltxt_titre, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        move.w  #CASE_TITRE + 1, %d1
        move.w  #0x3200, %d3
        lea     .Ltxt_titre, %a2
        bsr     .Lplacer
        bra     .Lchaine

| LINE %d0 OF THE MENU: cursor, label (16), state (12); for a memory test,
| the next line carries the detail of a fault, or spaces. Clobbers %d0-%d4, %d6,
| %a2, %a3.
.Lligne:
        move.w  %d0, %d6
        lea     .Lrangs, %a2
        moveq   #0, %d1
        move.b  (%a2,%d6.w), %d1
        addi.w  #CASE_MENU, %d1
        bsr     .Lplacer
        move.w  #0x1000, %d3
        moveq   #0x20, %d2
        cmp.w   %d7, %d6
        bne.s   1f
        move.w  #0x2000, %d3
        moveq   #0x3E, %d2              | ">"
1:      bsr     .Lcar
        moveq   #0x20, %d2
        bsr     .Lcar
        move.w  %d6, %d0
        lsl.w   #4, %d0
        lea     .Lnoms, %a2
        adda.w  %d0, %a2
        moveq   #16, %d4
        bsr     .Lecrire
        cmpi.w  #4, %d6
        bcc     9f
        lea     F_RES(%a6), %a3
        move.w  %d6, %d0
        mulu    #R_TAILLE, %d0
        adda.w  %d0, %a3
        moveq   #0, %d0
        move.b  (%a3), %d0
        lsl.w   #2, %d0
        lsr.w   #1, %d0
        lea     .Lpal_etats, %a2
        move.w  (%a2,%d0.w), %d3
        lsl.w   #1, %d0
        lea     .Letats, %a2
        movea.l (%a2,%d0.w), %a2
        moveq   #12, %d4
        cmpi.b  #2, (%a3)
        bne.s   3f
        cmpi.w  #1, %d6                 | the palette: the faulty bank
        bne.s   3f
        lea     .Ltxt_fail_banque, %a2
        moveq   #10, %d4                | "FAIL BANK"
        bsr     .Lecrire
        moveq   #0x30, %d2
        add.b   1(%a3), %d2
        bsr     .Lcar
        lea     .Ltxt_espace, %a2
        moveq   #1, %d4
3:      bsr     .Lecrire
        | THE DETAIL, one line lower, column 5.
        lea     .Lrangs, %a2
        moveq   #0, %d1
        move.b  (%a2,%d6.w), %d1
        addi.w  #CASE_MENU + 2 * 32 + 1, %d1
        bsr     .Lplacer
        cmpi.b  #2, (%a3)
        beq.s   4f
        lea     .Ltxt_espace, %a2
        moveq   #32, %d4
        bra     .Lecrire
4:      move.w  #0x6000, %d3
        lea     .Ltxt_at, %a2
        bsr     .Lchaine
        move.l  2(%a3), %d4
        moveq   #8, %d0
        bsr     .Lhex
        lea     .Ltxt_ecrit, %a2
        bsr     .Lchaine
        move.w  6(%a3), %d4
        swap    %d4
        moveq   #4, %d0
        bsr     .Lhex
        lea     .Ltxt_lu, %a2
        bsr     .Lchaine
        move.w  8(%a3), %d4
        swap    %d4
        moveq   #4, %d0
        bra     .Lhex
9:      rts

| ----------------------------------------------------------------------------------
| THE TEXT WRITING, REG_VRAMMOD at 32: one data = one cell to the right.
| `.Lplacer` sets address %d1; `.Lcar` writes %d2 + %d3 (palette << 12 + tile
| offset); between two data, the call alone takes more than 12 cycles, and the `rts` that follows
| the last one more than 16 before the next address ("VRAM").
.Lplacer:
        move.w  %d1, VRAMADDR
        rts
.Lcar:
        add.w   %d3, %d2
        move.w  %d2, VRAMRW
        rts
| A STRING terminated by 0, %a2 advanced past the 0. Clobbers %d2.
.Lchaine:
        moveq   #0, %d2
        move.b  (%a2)+, %d2
        beq.s   1f
        bsr.s   .Lcar
        bra.s   .Lchaine
1:      rts
| %d4 CHARACTERS of %a2, with no string terminator. Clobbers %d2, %d4, %a2.
.Lecrire:
        subq.w  #1, %d4
1:      moveq   #0, %d2
        move.b  (%a2)+, %d2
        bsr.s   .Lcar
        dbra    %d4, 1b
        rts
| %d0 HEXADECIMAL DIGITS, the high ones of %d4 first. Clobbers %d0, %d2, %d4.
.Lhex:
        subq.w  #1, %d0
1:      rol.l   #4, %d4
        moveq   #0x0F, %d2
        and.w   %d4, %d2
        cmpi.w  #10, %d2
        bcs.s   2f
        addq.w  #7, %d2                 | 10-15 → "A"-"F"
2:      addi.w  #0x30, %d2
        bsr.s   .Lcar
        dbra    %d0, 1b
        rts

| P1'S BUTTONS, like `dip.s`. %d5: the previous state, updated; %d0: the edges.
| Bits: 0 up, 1 down, 2 left, 3 right, 4 A, 5 START. Clobbers %d1, %d2.
.Lentrees:
        jsr     _panneau_p1             | %d0: P1, pad or translated panel (`panneau.s`)
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

| LINE $1F0 PASSING, like `dip.s` (measured,
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

| PALETTES 0-15 of the current bank at zero, entries 1-15; the reference $400000 at
| $8000. To be called right after `.Lsync`. Clobbers %d0, %a0.
.Lpal_zero:
        lea     PALETTES, %a0
        move.w  #0x8000, (%a0)+
        move.w  #16 * 16 - 2, %d0
1:      clr.w   (%a0)+
        dbra    %d0, 1b
        rts

| ----------------------------------------------------------------------------------
| THE DATA.
        .balign 2
.Ltests:
        .long   .Lt_ram, .Lt_pal, .Lt_vram, .Lt_bram
        .long   .Lt_entrees, .Lt_barres, .Lt_grille, _crc_cartouche
| The patterns: value, then 0 data / 1 address (xor of the value).
.Lmotifs:
        .word   0x0000, 0, 0xFFFF, 0, 0x5555, 0, 0xAAAA, 0, 0x0000, 1, 0xFFFF, 1
| The VRAM areas tested: start, number of words.
.Lzones:
        .word   0x0000, 0x8000, 0x8000, 0x0600, 0x8700, 0x0100
| Entry 1 of palettes 1 to 6, $0RGB ("Colors"). A choice of looks, those of `dip.s`.
.Lcouleurs:
        .word   0x0BBB, 0x0FE3, 0x04BF, 0x0777, 0x02F4, 0x0F44
| The line of each menu entry.
.Lrangs:
        .byte   7, 9, 11, 13, 16, 17, 18, 19, 21
        .balign 2
.Lnoms:                                 | 16 characters each
        .ascii  "WORK RAM        "
        .ascii  "PALETTE RAM     "
        .ascii  "VRAM            "
        .ascii  "BACKUP RAM      "
        .ascii  "INPUT TEST      "
        .ascii  "COLOR BARS      "
        .ascii  "CROSSHATCH      "
        .ascii  "CARTRIDGE CRC   "
        .ascii  "EXIT            "
.Lpal_etats:                             | the palette of each state
        .word   0x1000, 0x5000, 0x6000, 0x2000
.Letats:
        .long   .Ltxt_espace, .Ltxt_ok, .Ltxt_fail, .Ltxt_encours
.Ltxt_espace:   .ascii  "                                  "
.Ltxt_ok:       .ascii  "OK          "
.Ltxt_fail:     .ascii  "FAIL        "
.Ltxt_fail_banque: .ascii "FAIL BANK "
.Ltxt_encours:  .ascii  "TESTING     "
.Ltxt_titre:    .asciz  "HARDWARE TESTS"
.Ltxt_aide1:    .asciz  "UP/DOWN:SELECT  A:RUN"
.Ltxt_aide2:    .asciz  "START:BACK"
.Ltxt_at:       .asciz  "AT "
.Ltxt_ecrit:    .asciz  " WROTE "
.Ltxt_lu:       .asciz  " READ "
.Le_aide:       .asciz  "HOLD START P1 1 SEC TO EXIT"
        .balign 2

| THE INPUT TEST. A cell: $7000 + 32 × column + line.
        .macro  FIXE col, ligne, txt
        .word   0x7000 + 32 * (\col) + (\ligne)
        .asciz  "\txt"
        .balign 2
        .endm
        .macro  ELEM reg, bit, col, ligne, txt
        .long   \reg
        .byte   \bit
        .byte   (0x7000 + 32 * (\col) + (\ligne)) >> 8, (0x7000 + 32 * (\col) + (\ligne)) & 0xFF
        .asciz  "\txt"
        .balign 2
        .endm
.Le_fixes:
        FIXE    3, 7, "P1"
        FIXE    3, 9, "P2"
        FIXE    3, 11, "P1"
        FIXE    3, 12, "P2"
        FIXE    3, 14, "COIN"
        FIXE    3, 18, "DIP"
        .word   0
.Le_elements:
        ELEM    P1CNT, 0, 7, 7, "UP"
        ELEM    P1CNT, 1, 10, 7, "DOWN"
        ELEM    P1CNT, 2, 15, 7, "LEFT"
        ELEM    P1CNT, 3, 20, 7, "RIGHT"
        ELEM    P1CNT, 4, 26, 7, "A"
        ELEM    P1CNT, 5, 28, 7, "B"
        ELEM    P1CNT, 6, 30, 7, "C"
        ELEM    P1CNT, 7, 32, 7, "D"
        ELEM    P2CNT, 0, 7, 9, "UP"
        ELEM    P2CNT, 1, 10, 9, "DOWN"
        ELEM    P2CNT, 2, 15, 9, "LEFT"
        ELEM    P2CNT, 3, 20, 9, "RIGHT"
        ELEM    P2CNT, 4, 26, 9, "A"
        ELEM    P2CNT, 5, 28, 9, "B"
        ELEM    P2CNT, 6, 30, 9, "C"
        ELEM    P2CNT, 7, 32, 9, "D"
        ELEM    STATUS_B, 0, 7, 11, "START"
        ELEM    STATUS_B, 1, 13, 11, "SELECT"
        ELEM    STATUS_B, 2, 7, 12, "START"
        ELEM    STATUS_B, 3, 13, 12, "SELECT"
        ELEM    STATUS_A, 0, 9, 14, "1"
        ELEM    STATUS_A, 1, 11, 14, "2"
        ELEM    STATUS_A, 2, 15, 14, "SERVICE"
        ELEM    SYSTYPE, 7, 3, 16, "TEST"
        ELEM    DIPSW, 0, 9, 18, "1"
        ELEM    DIPSW, 1, 11, 18, "2"
        ELEM    DIPSW, 2, 13, 18, "3"
        ELEM    DIPSW, 3, 15, 18, "4"
        ELEM    DIPSW, 4, 17, 18, "5"
        ELEM    DIPSW, 5, 19, 18, "6"
        ELEM    DIPSW, 6, 21, 18, "7"
        ELEM    DIPSW, 7, 23, 18, "8"
        .long   0

| THE MAHJONG PANEL PAGE. A key: the cell, the bit in %d4 of `.Lm_trame` (row × 8 +
| bit; 24-31: REG_STATUS_B), a spare byte, the label.
        .macro  TOUCHE bit, col, ligne, txt
        .word   0x7000 + 32 * (\col) + (\ligne)
        .byte   \bit, 0
        .asciz  "\txt"
        .balign 2
        .endm
.Lm_fixes:
        FIXE    3, 6, "MAHJONG PANEL"
        FIXE    3, 16, "COIN"
        FIXE    3, 20, "DIP"
        .word   0
.Lm_touches:
        TOUCHE  24, 5, 8, "A"
        TOUCHE  25, 5, 9, "B"
        TOUCHE  26, 5, 10, "C"
        TOUCHE  27, 5, 11, "D"
        TOUCHE  28, 5, 12, "E"
        TOUCHE  29, 5, 13, "F"
        TOUCHE  30, 5, 14, "G"
        TOUCHE  16, 11, 8, "H"
        TOUCHE  17, 11, 9, "I"
        TOUCHE  18, 11, 10, "J"
        TOUCHE  19, 11, 11, "K"
        TOUCHE  20, 11, 12, "L"
        TOUCHE  21, 11, 13, "M"
        TOUCHE  22, 11, 14, "N"
        TOUCHE  8, 17, 8, "PON   "
        TOUCHE  9, 17, 9, "CHI   "
        TOUCHE  10, 17, 10, "KAN   "
        TOUCHE  11, 17, 11, "RON   "
        TOUCHE  12, 17, 12, "REACH "
        TOUCHE  0, 17, 13, "START "
        TOUCHE  1, 17, 14, "SELECT"
        .word   0
.Lm_elements:
        ELEM    STATUS_A, 0, 9, 16, "1"
        ELEM    STATUS_A, 1, 11, 16, "2"
        ELEM    STATUS_A, 2, 15, 16, "SERVICE"
        ELEM    SYSTYPE, 7, 3, 18, "TEST"
        ELEM    DIPSW, 0, 9, 20, "1"
        ELEM    DIPSW, 1, 11, 20, "2"
        ELEM    DIPSW, 2, 13, 20, "3"
        ELEM    DIPSW, 3, 15, 20, "4"
        ELEM    DIPSW, 4, 17, 20, "5"
        ELEM    DIPSW, 5, 19, 20, "6"
        ELEM    DIPSW, 6, 21, 20, "7"
        ELEM    DIPSW, 7, 23, 20, "8"
        .long   0

| THE TEST PATTERNS: texts under palette 0.
.Lb_rvb:
        FIXE    16, 3, "COLOR BARS"
        FIXE    2, 8, "R"
        FIXE    2, 14, "G"
        FIXE    2, 20, "B"
        FIXE    10, 26, "A:WHITE  START:EXIT"
        .word   0
.Lb_blanc:
        FIXE    16, 3, "COLOR BARS"
        FIXE    2, 14, "W"
        FIXE    11, 26, "A:RGB  START:EXIT"
        .word   0
        .balign 2
