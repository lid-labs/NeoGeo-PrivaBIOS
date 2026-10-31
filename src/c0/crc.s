| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| THE CARTRIDGE CRC32 — a screen of the HARDWARE TESTS sub-menu (`tests.s`), line
| CARTRIDGE CRC, just before EXIT. It computes the CRC32 of the P-ROM of the slot served, as
| the 68000 sees it, so it can be compared with the one MAME publishes for the same romset
| (`hash/neogeo.xml`, `-listxml`) or the one computed from the zip.
|
| CALL: `jsr _crc_cartouche` from `tests.s`, in the self-test state: IRQs masked,
| REG_BRDFIX (the board's font), REG_SWPROM set by the switch to the slot (`c0.s`; nothing sets
| it again here: without a cartridge, the boot leaves REG_SWPBIOS, and only the $100 header is
| read, then NO CARTRIDGE; the Z80, which has no driver parked there, then sees an absent M1),
| the game's sound driver parked in its loop in RAM (`dip.s`), palettes 1-6 of `tests.s` in
| bank 0 (the stroke at entry 1, black elsewhere). All registers restored. On return:
| REG_BRDFIX, the P-ROM bank put back to 0 if it was changed, the fix layer to be redrawn
| (`tests.s` does it).
|
| NO ORACLE: neither the reference BIOS nor a third-party BIOS is read, nor a game's code.
| "measured": a named record; "read in": a page of the NeoGeo Development Wiki or the
| source of MAME 0.286; "ASSUMED": neither.
|
| THE CARTRIDGE ANSWERS ONLY UNDER REG_CRTFIX (DECISIONS §13): the whole computation is done
| under it, and the screen with it. REG_CRTFIX also switches the Z80's M1 (read in "Memory
| mapped registers"); the driver is parked in RAM (`dip.s`) and REG_SOUND is not written: it
| does not read its ROM meanwhile. The text is therefore in the CARTRIDGE'S FONT, in 8×8 at
| the SFIX places, like `jukebox.s`: 0-9, A-Z, space, ": - / ." only
| (`measured/2026-10-21-police-cartouche.tsv`, 20 games identical out of 22; kof2003 without a
| font, the screen is black there). Ruled out: switching around each read, the S ROM would
| change under the fix layer in mid-picture, thousands of times.
|
| WHAT IS SUMMED, in two CRC32s (reflected polynomial $EDB88320, start and end complemented: the
| CRC of zip and of MAME):
|   FIXED  $000000-$0FFFFF, the fixed P-ROM, vectors included (REG_SWPROM). Its size is halved
|          as long as the high half is the exact mirror of the low one, down to 64 KiB:
|          ASSUMED, a 512 KiB chip on a board with 1 MiB of addresses appears there twice,
|          its A19 line not being wired. MAME, for its part, puts zeros beyond the file (measured
|          on aof, `measured/2026-10-25-crc-cartouche.tsv`): under MAME, a 512 KiB P-ROM
|          therefore gives a 1 MiB CRC, which is not the file's.
|   BANKS  $200000-$2FFFFF, bank after bank, one after the other in a single CRC. Read in the
|          source of MAME (`neogeo.cpp`, `write_banksel`): the word written at $2FFFF0 selects
|          the bank (bits 0-2), bank n being MiB n + 1 of the P-ROM, and a bank
|          beyond the ROM falls back on bank 0; a cartridge of 1 MiB at most keeps
|          its fixed P-ROM in the window. Hence, without reading the game's code:
|            - the window equal to the fixed P-ROM, word for word: NO BANK, and nothing is
|              written at $2FFFF0 (under MAME, writing 0 there would point outside the ROM,
|              measured);
|            - the window that reads only a single word over sixteen 4 KiB slices, one every
|              64 KiB: NO BANK, nothing is written at $2FFFF0. MEASURED on a real
|              ssideki cartridge (512 KiB P-ROM without a bank chip), photo from the tester of
|              2026-10-29: BANKS 1 X 1024K A9F75D87, the 1 MiB CRC32 of the word $5700 alone
|              (`measured/2026-10-29-crc-ssideki-materiel.tsv`). ASSUMED: no real bank
|              is a single word over these spread-out 64 KiB;
|            - otherwise, banks 0, 1, 2… up to the first whose CRC equals that of an
|              earlier bank (a mirror, or the fall-back on 0), eight at most. It is
|              not counted, and its byte does not enter the banks' CRC.
|          Then bank 0, the one at reset under MAME (`init_cpu`). ASSUMED on the hardware.
| THE BYTE ORDER is that of MAME's files: each word low byte first
| (`ROM_LOAD16_WORD_SWAP`). A 1 MiB P-ROM followed by a single bank chip then gives the
| two CRCs of `hash/neogeo.xml` (mslug2: 2A53C5DA and 38883F44, measured). A chip stored
| otherwise (mslug, crossed halves) or decrypted at load time (kof98) cannot: the
| CRC is that of what the 68000 reads, the bench recomputes it from the zip
| (`bench/crc-cartouche.py`).
| PROTECTED CARTRIDGES bank elsewhere than at $2FFFF0, or through a scrambled word (read in
| `neogeo.cpp`, `prot_sma.cpp`, `prot_pvc.cpp`), and their P-ROM is scrambled in the file: the
| figures would be neither their banks nor a file's. So, once the window is known to be a
| bank window, before any write at $2FFFF0:
|   SMA  the word at $2FE446 reads $9A37, whatever the bank (`prot_9a37_r`). A read only.
|        ASSUMED: no normal cartridge reads $9A37 there (none of 157 sets, in any bank:
|        `measured/2026-10-31-crc-protegees.tsv`).
|   PVC  $2FE000 is RAM on the cartridge (`m_cart_ram`, `protection_r`/`_w`): two
|        complementary words read back, then the word put back. Two, because a floating bus
|        cannot return both. A normal cartridge's latch may take this write for a bank
|        (ASSUMED, on the hardware): bank 0 is written next. Nothing is written at $2FFFF0.
| The screen then says which, BANKS NOT READ, and that FIXED is no file's CRC.
|
| THE DURATION: ~170 cycles per word (counted below), ~7.5 s per MiB at 12 MHz, plus one bank
| read again to see that it is a mirror. The watchdog is served every 4 KiB; the count of
| KiB read is shown every 64 KiB; START stops the computation and returns to the menu.
|
| THE DISPLAY: fix layer only, $7000 + 32 × column + row, REG_VRAMMOD at 32. Clearing:
| tile $020 under palette 7, set to zero (like `jukebox.s`: whatever its drawing
| in the S ROM, it is black). Palettes of `tests.s`: 1 the text, 3 the title, 4 the help,
| 5 the CRCs.
| ==================================================================================

        .section .haut, "ax"
        .global _crc_cartouche

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    WATCHDOG, 0x300001
        .equ    STATUS_B, 0x380000
        .equ    BRDFIX,   0x3A000B
        .equ    CRTFIX,   0x3A001B
        .equ    PALETTES, 0x400000
        .equ    BANQUE,   0x2FFFF0      | the bank word (`neogeo.cpp`, `write_banksel`)
        .equ    FENETRE,  0x200000
        .equ    MOT_SMA,  0x2FE446      | reads $9A37 on an SMA cartridge (`prot_9a37_r`)
        .equ    RAM_PVC,  0x2FE000      | the PVC cartridge's RAM, below its registers

        .equ    PAL_VIDE, 7
        .equ    MIO,      0x100000
        .equ    BLOC,     0x1000        | 4 KiB between two kicks of the watchdog
        .equ    N_BANQUES, 8

        | The rows, column 3.
        .equ    CASE_TITRE,  0x7000 + 3 * 32 + 3
        .equ    CASE_SLOT,   0x7000 + 3 * 32 + 6
        .equ    CASE_FIXE,   0x7000 + 3 * 32 + 9
        .equ    CASE_BANQ,   0x7000 + 3 * 32 + 12
        .equ    CASE_PROT,   0x7000 + 3 * 32 + 13
        .equ    CASE_PROT2,  0x7000 + 3 * 32 + 14
        .equ    CASE_ETAT,   0x7000 + 3 * 32 + 16
        .equ    CASE_AIDE1,  0x7000 + 3 * 32 + 25
        .equ    CASE_AIDE2,  0x7000 + 3 * 32 + 26
        .equ    COL_CRC,     22         | the CRC in column 22 on the FIXED and BANKS rows

        | The frame: each bank's signature, the state.
        .equ    F_CRCB,   -(N_BANQUES * 4)
        .equ    F_NB,     F_CRCB - 2    | .w the number of banks
        .equ    F_ECRIT,  F_NB - 2      | .w 1 if $2FFFF0 has been written
        .equ    F_ARRET,  F_ECRIT - 2   | .w 1 if START stopped the computation
        .equ    F_KIO,    F_ARRET - 2   | .w KiB read in the current zone
        .equ    F_ZONE,   F_KIO - 2     | .w the current zone: 0 the fixed one, 1 + n bank n
        .equ    F_TOUCHE, F_ZONE - 2    | .w START already held
        .equ    F_TOTAL,  F_TOUCHE

| ----------------------------------------------------------------------------------
_crc_cartouche:
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        link    %a6, #F_TOTAL
        clr.w   F_ECRIT(%a6)
        clr.w   F_ARRET(%a6)
        clr.w   F_NB(%a6)
        move.w  #1, F_TOUCHE(%a6)       | the A that opens does not count; START neither
        bsr     .Lsync
        move.b  %d0, CRTFIX             | the cartridge answers, its S ROM on the fix layer
        lea     PALETTES + PAL_VIDE * 32, %a0
        moveq   #16 - 1, %d0
1:      clr.w   (%a0)+
        dbra    %d0, 1b
        bsr     .Leffacer
        move.w  #32, VRAMMOD
        move.w  #CASE_TITRE, %d1
        move.w  #0x3000, %d3
        lea     .Ltxt_titre, %a2
        bsr     .Lchaine_en
        move.w  #CASE_AIDE1, %d1
        move.w  #0x4000, %d3
        lea     .Ltxt_ordre, %a2
        bsr     .Lchaine_en

        | A CARTRIDGE? "NEO-GEO" at $100 ("68k program header"), like the boot (`c0.s`).
        cmpi.l  #0x4E454F2D, 0x100      | "NEO-"
        bne.s   .Lsans
        cmpi.w  #0x4745, 0x104          | "GE"
        bne.s   .Lsans
        cmpi.b  #0x4F, 0x106            | "O"
        beq.s   .Lavec
.Lsans:
        move.w  #CASE_ETAT, %d1
        move.w  #0x1000, %d3
        lea     .Ltxt_sans, %a2
        bsr     .Lchaine_en
        bra     .Lfini

.Lavec:
        | SLOT n (1 to 6: $D00108 + 1, "Backup RAM") and the NGH ($108, BCD).
        move.w  #CASE_SLOT, %d1
        move.w  #0x1000, %d3
        lea     .Ltxt_slot, %a2
        bsr     .Lchaine_en
        moveq   #0, %d2
        move.b  0xD00108, %d2
        addi.w  #0x31, %d2
        bsr     .Lcar
        lea     .Ltxt_ngh, %a2
        bsr     .Lchaine
        move.w  0x108, %d4
        swap    %d4
        moveq   #4, %d0
        bsr     .Lhex

        | THE FIXED P-ROM: its size, through the mirrors; then its CRC.
        move.l  #MIO, %d6
1:      cmpi.l  #0x10000, %d6           | 64 KiB at least
        bls.s   2f
        move.l  %d6, %d0
        lsr.l   #1, %d0
        suba.l  %a0, %a0                | the low half
        movea.l %d0, %a1                | the high one
        bsr     .Legal
        bne.s   2f
        lsr.l   #1, %d6
        bra.s   1b
2:      move.w  #CASE_FIXE, %d1
        move.w  #0x1000, %d3
        lea     .Ltxt_fixe, %a2
        bsr     .Lchaine_en
        move.l  %d6, %d0
        bsr     .Lkio
        clr.w   F_ZONE(%a6)
        moveq   #-1, %d7                | %d7: the CRC, complemented at the start
        suba.l  %a0, %a0
        move.l  %d6, %d5
        bsr     .Lsommer
        tst.w   F_ARRET(%a6)
        bne     .Lfini
        not.l   %d7
        move.w  #CASE_FIXE + COL_CRC * 32, %d1
        bsr     .Lcrc_ecrire

        | THE BANKS. The window equal to the fixed P-ROM: none.
        lea     FENETRE, %a1
        suba.l  %a0, %a0
        move.l  #MIO, %d0
        bsr     .Legal
        bne.s   .Lbanques
.Lsans_banque:
        move.w  #CASE_BANQ, %d1
        move.w  #0x1000, %d3
        lea     .Ltxt_sans_banque, %a2
        bsr     .Lchaine_en
        bra     .Ltermine

.Lbanques:
        | PROTECTED? (see the header.) An SMA cartridge gets no write at all.
        lea     .Ltxt_sma, %a2
        cmpi.w  #0x9A37, MOT_SMA
        beq.s   .Lprotegee
        | The window that reads only a single word: no chip, the bus floating (see the header),
        | unless the RAM below answers: svc's window reads one word at its reset bank (measured).
        | Before any write at $2FFFF0, as above.
        bsr     .Lconstante
        seq     %d6
        lea     RAM_PVC, %a0
        move.w  (%a0), %d2
        move.w  #0x55AA, %d0
        move.w  %d0, (%a0)
        cmp.w   (%a0), %d0
        bne.s   .Lpas_pvc
        not.w   %d0
        move.w  %d0, (%a0)
        cmp.w   (%a0), %d0
        bne.s   .Lpas_pvc
        move.w  %d2, (%a0)
        lea     .Ltxt_pvc, %a2
.Lprotegee:
        move.w  #CASE_PROT, %d1
        move.w  #0x1000, %d3
        bsr     .Lchaine_en
        move.w  #CASE_PROT2, %d1
        lea     .Ltxt_pas_fichier, %a2
        bsr     .Lchaine_en
        move.w  #CASE_BANQ, %d1
        lea     .Ltxt_non_lues, %a2
        bsr     .Lchaine_en
        bra     .Ltermine
.Lpas_pvc:
        tst.b   %d6
        bne     .Lsans_banque
        move.w  #1, F_ECRIT(%a6)
        moveq   #-1, %d7                | the CRC of all the banks, one after the other
        moveq   #0, %d6                 | %d6: the bank
.Lb_une:
        move.w  %d6, BANQUE
        | ITS SIGNATURE: the CRC of sixteen 4 KiB slices, one every 64 KiB (~0.5 s). Equal to
        | that of an earlier bank: a mirror, end, without it. ASSUMED: two different banks
        | do not agree on these spread-out 64 KiB.
        move.l  %d7, -(%sp)
        moveq   #-1, %d7
        lea     .Ltable, %a1
        lea     FENETRE, %a3
        moveq   #16 - 1, %d5
1:      movea.l %a3, %a0
        move.w  #BLOC / 2 - 1, %d4
        bsr     .Lcrc_mots
        move.b  %d0, WATCHDOG
        adda.l  #0x10000, %a3
        dbra    %d5, 1b
        lea     F_CRCB(%a6), %a3
        move.w  %d6, %d0
        bra.s   3f
2:      cmp.l   (%a3)+, %d7
        beq.s   .Lb_miroir
3:      dbra    %d0, 2b
        move.l  %d7, (%a3)              | %a3: this bank's entry
        move.l  (%sp)+, %d7
        | ITS CRC, following the others.
        move.w  %d6, %d0
        addq.w  #1, %d0
        move.w  %d0, F_ZONE(%a6)
        lea     FENETRE, %a0
        move.l  #MIO, %d5
        bsr     .Lsommer
        tst.w   F_ARRET(%a6)
        bne     .Lfini
        addq.w  #1, %d6
        move.w  %d6, F_NB(%a6)
        cmpi.w  #N_BANQUES, %d6
        bcs     .Lb_une
        bra.s   .Lb_fin
.Lb_miroir:
        move.l  (%sp)+, %d7
.Lb_fin:
        not.l   %d7
        move.w  #CASE_BANQ, %d1
        move.w  #0x1000, %d3
        lea     .Ltxt_banques, %a2
        bsr     .Lchaine_en
        moveq   #0x30, %d2
        add.w   F_NB(%a6), %d2
        bsr     .Lcar
        lea     .Ltxt_x1024, %a2
        bsr     .Lchaine
        move.w  #CASE_BANQ + COL_CRC * 32, %d1
        bsr     .Lcrc_ecrire

.Ltermine:
        move.w  #CASE_ETAT, %d1
        move.w  #0x5000, %d3
        lea     .Ltxt_fini, %a2
        bsr     .Lchaine_en

| THE END: the help, then START returns to the menu (a START held since the computation does
| not count).
.Lfini:
        tst.w   F_ECRIT(%a6)
        beq.s   1f
        move.w  #0, BANQUE              | the reset bank (`init_cpu`)
1:      tst.w   F_ARRET(%a6)
        bne.s   .Lsortie
        move.w  #CASE_AIDE2, %d1
        move.w  #0x4000, %d3
        lea     .Ltxt_retour, %a2
        bsr     .Lchaine_en
1:      bsr     .Lsync
        bsr     .Lstart
        beq.s   1b
.Lsortie:
        bsr     .Lsync
        move.b  %d0, BRDFIX
        unlk    %a6
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rts

| ----------------------------------------------------------------------------------
| SUM %d5 bytes from %a0, current CRC %d7, in blocks of BLOC bytes: one kick to the
| watchdog per block; every 16 blocks, the KiB count on screen and START checked.
| Clobbers %d0-%d5, %a0-%a2. F_ARRET at 1 if START.
.Lsommer:
        clr.w   F_KIO(%a6)
        bsr     .Lprogres
        lea     .Ltable, %a1
1:      move.w  #BLOC / 2 - 1, %d4
        bsr.s   .Lcrc_mots
        move.b  %d0, WATCHDOG
        addq.w  #4, F_KIO(%a6)
        move.w  F_KIO(%a6), %d0
        andi.w  #63, %d0
        bne.s   2f
        movem.l %d5/%a0/%a1, -(%sp)
        bsr     .Lprogres
        bsr     .Lstart
        movem.l (%sp)+, %d5/%a0/%a1
        beq.s   2f
        move.w  #1, F_ARRET(%a6)
        rts
2:      subi.l  #BLOC, %d5
        bhi.s   1b
        rts

| THE CRC OF %d4 + 1 WORDS from %a0, table %a1, current CRC %d7 (reflected, complemented by
| the caller). Each word low byte first, the order of MAME's files. Counted (68000 timing,
| without wait state ASSUMED): 8 + 2 × (4 + 4 + 4 + 24 + 8 + 18 + 8) + 22 + 10, ≈ 172
| cycles per word. Clobbers %d1, %d2, %d4, %a0.
.Lcrc_mots:
1:      move.w  (%a0)+, %d1
        moveq   #0, %d2
        move.b  %d1, %d2                | the low byte, the file's first
        eor.b   %d7, %d2
        lsr.l   #8, %d7
        add.w   %d2, %d2
        add.w   %d2, %d2
        move.l  (%a1,%d2.w), %d2
        eor.l   %d2, %d7
        lsr.w   #8, %d1                 | the high byte; the top of the word at zero
        eor.b   %d7, %d1
        lsr.l   #8, %d7
        add.w   %d1, %d1
        add.w   %d1, %d1
        move.l  (%a1,%d1.w), %d1
        eor.l   %d1, %d7
        dbra    %d4, 1b
        rts

| DOES THE WINDOW READ ONLY ONE WORD? Sixteen 4 KiB slices, one every 64 KiB, each word
| compared with the previous one. Z if so. All the reads go through `.Lmot`, the same
| instruction: a floating bus that would return the word following the read (the jig
| `bus-flottant.lua`) then returns the same one everywhere. ~56 cycles per word, ~0.15 s.
| Clobbers %d0-%d4, %a0, %a3.
.Lconstante:
        lea     FENETRE, %a0
        bsr.s   .Lmot
        move.w  %d1, %d2                | %d2: the first word
        lea     FENETRE, %a3
        moveq   #16 - 1, %d3
1:      movea.l %a3, %a0
        move.w  #BLOC / 2 - 1, %d4
2:      bsr.s   .Lmot
        cmp.w   %d1, %d2
        dbne    %d4, 2b
        bne.s   9f
        move.b  %d0, WATCHDOG
        adda.l  #0x10000, %a3
        dbra    %d3, 1b
        moveq   #0, %d0                 | Z
9:      rts
.Lmot:
        move.w  (%a0)+, %d1
        rts

| %d0 EQUAL BYTES at %a0 and %a1? Z if so. In blocks of BLOC bytes, one kick to the
| watchdog per block (~22 cycles per word). Clobbers %d0, %d1, %d2, %a0, %a1.
.Legal:
1:      move.w  #BLOC / 2 - 1, %d1
2:      cmpm.w  (%a0)+, (%a1)+
        dbne    %d1, 2b
        bne.s   9f
        move.b  %d1, WATCHDOG
        subi.l  #BLOC, %d0
        bhi.s   1b
        moveq   #0, %d0                 | Z
9:      rts

| THE STATUS LINE: "READING FIXED 0512K" or "READING BANK 2 0512K". Clobbers %d0-%d4, %a2.
.Lprogres:
        move.w  #CASE_ETAT, %d1
        move.w  #0x1000, %d3
        lea     .Ltxt_lit, %a2
        bsr     .Lchaine_en
        move.w  F_ZONE(%a6), %d0
        bne.s   1f
        lea     .Ltxt_lit_fixe, %a2
        bsr     .Lchaine
        bra.s   2f
1:      lea     .Ltxt_lit_banque, %a2
        bsr     .Lchaine
        moveq   #0x2F, %d2              | "0" - 1: zone 1 is bank 0
        add.w   F_ZONE(%a6), %d2
        bsr     .Lcar
        moveq   #0x20, %d2
        bsr     .Lcar
2:      moveq   #0, %d0
        move.w  F_KIO(%a6), %d0
        lsl.l   #8, %d0                 | KiB → bytes, for `.Lkio`
        lsl.l   #2, %d0                 | then `.Lkio`, just below

| %d0 BYTES in decimal KiB on four digits, then "K" (from 0 to 9999 KiB). Clobbers %d0-%d2,
| %d4, %a2.
.Lkio:
        lsr.l   #8, %d0
        lsr.l   #2, %d0
        moveq   #4 - 1, %d4
        lea     .Lpuissances, %a2
1:      moveq   #0x30, %d2
        move.w  (%a2)+, %d1
2:      cmp.w   %d1, %d0
        bcs.s   3f
        sub.w   %d1, %d0
        addq.w  #1, %d2
        bra.s   2b
3:      bsr.s   .Lcar
        dbra    %d4, 1b
        moveq   #0x4B, %d2              | "K"
        bra.s   .Lcar

| THE CRC %d7 in eight hexadecimal digits, palette 5, at cell %d1. Clobbers %d0, %d2-%d4.
.Lcrc_ecrire:
        move.w  %d1, VRAMADDR
        move.w  #0x5000, %d3
        move.l  %d7, %d4
        moveq   #8, %d0
        bra.s   .Lhex

| START P1, on edge: NZ if pressed just now (REG_STATUS_B bit 0, active low, "Memory
| mapped registers"). F_TOUCHE keeps the previous state. Clobbers %d0.
.Lstart:
        moveq   #0, %d0
        btst    #0, STATUS_B
        seq     %d0                     | $FF held
        andi.w  #1, %d0
        move.w  F_TOUCHE(%a6), -(%sp)
        move.w  %d0, F_TOUCHE(%a6)
        tst.w   (%sp)+
        beq.s   1f
        moveq   #0, %d0
1:      tst.w   %d0
        rts

| THE CLEARING: each cell of the fix layer to tile $020 under PAL_VIDE (REG_VRAMMOD at 1).
| Clobbers %d0, %d1.
.Leffacer:
        move.w  #1, VRAMMOD
        move.w  #0x7000, VRAMADDR
        move.w  #(PAL_VIDE << 12) + 0x020, %d0
        move.w  #40 * 32 - 1, %d1
1:      move.w  %d0, VRAMRW             | 26 cycles per loop: above the 12 ("VRAM")
        dbra    %d1, 1b
        rts

| THE WRITING, REG_VRAMMOD at 32 (see `tests.s`): `.Lchaine_en` sets the address %d1 then writes
| the string %a2 under %d3; `.Lcar` writes %d2 + %d3. Clobbers %d2, %a2.
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

| THE PASSAGE OF LINE $1F0, copy of the one in `tests.s` (bounded, watchdog on every loop).
| Clobbers %d0.
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
| THE DATA.
        .balign 2
.Lpuissances:
        .word   1000, 100, 10, 1
.Ltxt_titre:      .asciz  "CARTRIDGE CRC32"
.Ltxt_ordre:      .asciz  "BYTES IN MAME FILE ORDER"
.Ltxt_sans:       .asciz  "NO CARTRIDGE"
.Ltxt_slot:       .asciz  "SLOT "
.Ltxt_ngh:        .asciz  "   NGH "
.Ltxt_fixe:       .asciz  "FIXED "
.Ltxt_sans_banque: .asciz "BANKS NONE"
.Ltxt_banques:    .asciz  "BANKS "
.Ltxt_x1024:      .asciz  " X 1024K"
.Ltxt_non_lues:   .asciz  "BANKS NOT READ"
.Ltxt_sma:        .asciz  "SMA PROTECTED CARTRIDGE"
.Ltxt_pvc:        .asciz  "PVC PROTECTED CARTRIDGE"
.Ltxt_pas_fichier: .asciz "FIXED IS NO FILE CRC"
.Ltxt_lit:        .asciz  "READING "
.Ltxt_lit_fixe:   .asciz  "FIXED "
.Ltxt_lit_banque: .asciz  "BANK "
.Ltxt_fini:       .asciz  "DONE                    "
.Ltxt_retour:     .asciz  "START:BACK"
        .balign 4

| THE TABLE of the reflected CRC32, $EDB88320: entry i is i passed eight times through the shift
| register. Computed by the assembler, no value copied.
.Ltable:
        .set    i, 0
        .rept   256
        .set    c, i
        .rept   8
        .if     c & 1
        .set    c, (c >> 1) ^ 0xEDB88320
        .else
        .set    c, c >> 1
        .endif
        .endr
        .long   c
        .set    i, i + 1
        .endr
