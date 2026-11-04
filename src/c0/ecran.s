| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| THE "PrivaBIOS" BOOT SCREEN — about three seconds, skippable, only once per boot.
|
| Called by `jsr` from `_demarrage` (`c0.s`), after BIOS_MESS_POINT is set and before the
| sound handshake. Neither SYSTEM_RETURN nor the coin goes through it: their path
| (`_retour_systeme`, `_retour_piece`) branches off further down, at the hand-over.
|
| NO ORACLE: SNK never wrote this screen. It is a creation (`docs/DECISIONS.md` §5); the
| hand-over is "Couche 3 → l'écran de boot, le 2026-10-20"
| (`docs/RELECTURE-CONTRATS.md`). The criterion is the capture under MAME.
|
| THREE KINDS OF CLAIMS, and each one says so:
|   "measured" : a record from `measured/`, named;
|   "read in"  : a page of the NeoGeo Development Wiki, named;
|   "ASSUMED"  : neither, and it is said.
|
| THE TIMELINE, in frames counted by the line counter (one frame = one pass of line $1F0,
| like the hand-over in `c0.s`), 180 in all with PAUSE = 126, ≈ 3.04 s at 59.185 Hz:
|   0       synchronisation, palettes set, fixed texts and values written in black;
|   1-12    the title decodes: its letters go in pairs, pair p (0 to 4) draws random
|           glyphs, then freezes at frame 2 + 2p, from left to right (the last at 10, then
|           redrawn frozen); a space in the title would stay empty;
|   13      the URL and the version light up;
|   13-20   a white glint sweeps the title, one pair of letters per frame;
|   21-45   five status lines, one every 5 frames: the label prints, then the value
|           lights up in green in three steps (2, 3 and 4 frames later);
|   46-171  everything stays displayed, PAUSE frames; the reminder "PRESS A BUTTON TO SKIP"
|           blinks at the bottom, 16 frames on, 16 off;
|   172-179 fade: each colour at 7/8, 6/8 … 0/8 of its value, black on the last frame;
|           the reminder fades out from its phase of the moment (off with PAUSE = 126).
| The bounds 46-171 and 172-179 follow PAUSE (T_FONDU = 46 + PAUSE, T_FIN = T_FONDU + 7).
| A pressed button (A, B, C, D, START, SELECT except on MVS, P1 or P2) jumps to the exit
| from the next frame.
|
| THE ONLY LAYER: THE FIX LAYER. Read in "Fix layer": map at $7000, 40 × 32 words stored
| top to bottom then left to right — the address of a cell is $7000 + 32 × column +
| row —, palette in the 4 high bits, and only the first 16 palettes are used; 28 rows
| displayed, two hidden at the top, so rows 2 to 29 are visible.
|
| THE GLYPHS, measured (`measured/2026-10-20-sfix-glyphes.tsv`): 8×16 font in two stacked
| cells, top = tile $100 + ASCII code, bottom = tile $200 + ASCII code. Measured in the record:
| the capitals A B C D E F G H I K L M N O P R S T U W X, the digits 0 1 2 6, "/" and the
| space. The rest, which the hand-over left ASSUMED to follow the same ASCII rule, is MEASURED
| on our captures under MAME (mslug, -bios euro, MAME's board SFIX, frame 50, 2026-10-20;
| not versioned): the lower-case letters of "ReBIOS", "sprixe.dev/rebios" and "v0.1", the
| full stop, the digits 3 to 9, J Q V Y Z, ":", "-", "?" and "!" all read at their ASCII
| place. Lower-case letters other than c, d, e, i, o, p, r, s, v, x have not been seen,
| except the "b" of "sprixe.dev/bios", read at its ASCII place on our capture of 2026-10-28
| (aof, -bios euro, frame 100; not versioned), and the "a" and "m" of "privabios.com", read
| the same way on our capture of 2026-11-04 (same conditions; not versioned).
| The randomly drawn glyphs come only from the characters of the record.
|
| THE COLOURS. Read in "Palettes": palette RAM at $400000, 256 palettes of 16 entries,
| entry 0 transparent; the reference colour ($400000) "always has to be pure black
| ($8000)", the background (backdrop) is the last colour of the bank, $401FFE; the bank
| is chosen by REG_PALBANK0/1, addresses read in "Memory mapped registers" ($3A000F /
| $3A001F, odd byte, any data); writing during display makes snow, hence all palette
| writes just after the pass of line $1F0.
| Read in "Colors": bit 15 "Dark", bits 14-12 the low bits of R, G, B, then R, G, B on
| four bits each in $0RGB. Only this $0RGB is used; the fade reduces each nibble of it.
| THE GLYPH INDEXES, measured on a test capture (same conditions as above: entry 1 red,
| 2 green, 3 to 15 blue): the stroke of the 8×16 glyphs is index 1, the background of
| their cells index 2, and no blue pixel. Each palette therefore carries its colour in
| entry 1 and black in entries 2 to 15 — the cells' background merges with the screen
| background. FIX_CLEAR puts its tiles $FF and $020 under palette 0, and $020 is full of
| index 2 (`measured/2026-10-21-sfix-tuiles-pleines.tsv`): palette 0 is therefore set at
| frame 0 with the others, entries 1 to 15 black, like `plantage.s` — its content at
| power-on is written nowhere. It is reset to zero at the exit, with the others.
| Palettes used, 1 to 14, and palette 0 in black:
|   1-6  one per pair of title letters (1-5 for the nine letters);   7  URL and version;   8  the labels;
|   9-13 one per line value, so that each lights up in turn;
|   14   the reminder, which blinks on its own.
| Per pair and not per letter: the title may have up to twelve characters, and only the first
| 16 palettes serve the fix layer, 0 being taken by FIX_CLEAR and 15 by the board
| switch 8 message.
| Bank 0 is chosen: ASSUMED, nothing says which one is in place at power-on; the game
| chooses its own.
|
| THE PACE OF VRAM WRITES, read in "VRAM" (cf. `video.s`): at least 12 cycles between two
| data, 16 between a datum and the next address. `.Lglyphe` holds 12 cycles between its
| two data (`addi.w` 8 + `nop` 4) and returns through `subi.w` (8) and `rts` (16) before
| any next address.
|
| THE STATE HANDED TO THE GAME: fix layer cleared by FIX_CLEAR (REG_VRAMMOD at 1),
| palettes 0 to 14 (entries 1-15) and the background reset to zero, the reference left at
| $8000 ("Palettes": "always has to be pure black ($8000)"), registers returned intact.
| Still changed, by the hand-over's request: the sprites hidden by LSP_1st, palette
| bank 0, and $10FDD2-$10FDD8 which READ_CALENDAR filled — the game reads them again on
| its call.
| The boot code that follows (`c0.s`) assumes no register except %sp: it sets all those
| it reads, and %d0 serves there only as "any value" data. Everything is saved anyway.
|
| IRQs STAY MASKED (SR = $2700, set by `_demarrage`). The watchdog gets kicked on every
| turn of the line waits, so several times per frame.
| ==================================================================================

        .section .haut, "ax"
        .global _ecran_boot
        .global _txt_version            | the version, reused by the ABOUT screen (`about.s`)

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    LSPCMODE, 0x3C0006
        .equ    WATCHDOG, 0x300001
        .equ    P2CNT,    0x340000
        .equ    STATUS_B, 0x380000
        .equ    PALBANK0, 0x3A000F
        .equ    PALETTES, 0x400000
        .equ    FOND,     0x401FFE

        | A cell of the fix layer, column c, row l ("Fix layer"). Rows 2-3 in the margin;
        | title, URL and version centred on column 19.
        .equ    CASE_TITRE,   0x7000 + 15 * 32 + 4     | "PRIVABIOS", 9 characters, columns 15-23
        .equ    CASE_URL,     0x7000 + 13 * 32 + 8     | 13 characters, columns 13-25
        .equ    CASE_VERSION, 0x7000 + 15 * 32 + 10    | "v0.1 BETA", 9 characters, columns 15-23
        .equ    CASE_LIGNES,  0x7000 +  7 * 32 + 15    | labels, columns 7-20, rows 15-24
        .equ    CASE_VALEURS, 0x7000 + 22 * 32 + 15    | values, from column 22
        .equ    CASE_RAPPEL,  0x7000 +  9 * 32 + 27    | 22 characters, columns 9-30, rows 27-28
        .equ    CASE_GEL1,    0x7000 + 11 * 32 + 11    | "DIP SWITCH 8 IS ON", columns 11-28, rows 11-12
        .equ    CASE_GEL2,    0x7000 +  9 * 32 + 15    | 22 characters, columns 9-30, rows 15-16

        | The colours, in $0RGB ("Colors"). A choice of look, for no other reason.
        .equ    C_TITRE,  0x04BF        | sky blue, the frozen title
        .equ    C_TIRAGE, 0x0346        | dark blue, a letter still searching
        .equ    C_MI,     0x09DF        | edge of the glint
        .equ    C_BLANC,  0x0FFF        | core of the glint
        .equ    C_DOUX,   0x0777        | URL and version
        .equ    C_ETIQ,   0x0BBB        | labels
        .equ    C_VERT,   0x02F4        | values
        .equ    C_RAPPEL, 0x0999        | the reminder, lit

        | THE PAUSE, in frames: everything stays displayed, the reminder blinks. The only
        | duration setting; decoding, lines and fade keep their own.
        .equ    PAUSE,    126
        .equ    T_PAUSE,  46            | first pause frame, the lines finished
        .equ    T_FONDU,  T_PAUSE + PAUSE
        .equ    T_FIN,    T_FONDU + 7   | last frame; frame 0 is the synchronisation
        .equ    N_PAL,    14            | palettes used, 1 to N_PAL
        .equ    N_TITRE,  9             | title characters, two per palette 1 to 5, the last alone

_ecran_boot:
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        movea.l %sp, %a6                | the entry stack, to jump to the exit
        move.b  %d0, WATCHDOG
        | BOARD SWITCH 3 read here, at the opening, and not later: P1 in this screen and those
        | it opens (`panneau.s`, DECISIONS §30).
        jsr     _panneau_verrou

        | A CLEAN SCREEN: VRAM is arbitrary at power-on. LSP_1st hides the sprites,
        | FIX_CLEAR fills the fix layer and leaves REG_VRAMMOD at 1 (`video.s`).
        jsr     _lsp_1st
        jsr     _fix_clear
        | The time, once: `_read_calendar` stores the date and time in BCD at $10FDD2-$10FDD8
        | (`cal.s`).
        jsr     _read_calendar

        lea     VRAMRW, %a0
        lea     VRAMADDR, %a1

        | FRAME 0. Palettes after the pass of line $1F0: everything written afterwards is
        | black, except the title letters, dark.
        bsr     .Lsync
        move.b  %d0, PALBANK0
        move.w  #0x8000, PALETTES       | reference: "pure black ($8000)", "Palettes"
        move.w  #0x8000, FOND           | the background in black
        moveq   #0, %d5                 | palette 0, under FIX_CLEAR: entries 1-15 black
        moveq   #0, %d6
        bsr     .Lpalette
        moveq   #1, %d4
1:      move.w  %d4, %d5
        move.w  #C_TIRAGE, %d6
        cmpi.w  #6, %d4
        bls.s   2f
        moveq   #0, %d6
2:      bsr     .Lpalette
        addq.w  #1, %d4
        cmpi.w  #N_PAL, %d4
        bls.s   1b

        | BOARD SWITCH 8, "FREEZE", ON AT BOOT. The SNK BIOS and UniBIOS 4.0 stop on a black
        | screen just after their memory test and resume when it goes back to OFF (measured,
        | `measured/2026-10-27-dip-2-8.tsv`, section 3). DELIBERATE DEPARTURE (DECISIONS §21):
        | the same stop, but two lines say so, instead of a black screen one would take for
        | a fault.
        tst.b   0x300001                | REG_DIPSW, bit 7 active low: the sign
        bmi.s   .Lsans_gel
        moveq   #15, %d5
        move.w  #C_BLANC, %d6
        bsr     .Lpalette
        move.w  #0xF000, %d3
        move.w  #CASE_GEL1, %d1
        lea     .Lgel1, %a2
        bsr     .Ltexte
        move.w  #CASE_GEL2, %d1
        lea     .Lgel2, %a2
        bsr     .Ltexte
1:      bsr     .Lsync                  | watchdog served on every turn
        tst.b   0x300001
        bpl.s   1b
        moveq   #15, %d5
        moveq   #0, %d6
        bsr     .Lpalette
        jsr     _fix_clear
        lea     VRAMRW, %a0
        lea     VRAMADDR, %a1
.Lsans_gel:

        | The fixed texts, under palettes still black.
        move.w  #0x7000, %d3
        move.w  #CASE_URL, %d1
        lea     .Lurl, %a2
        bsr     .Ltexte
        move.w  #CASE_VERSION, %d1
        lea     .Lversion, %a2
        bsr     .Ltexte
        move.w  #0xE000, %d3
        move.w  #CASE_RAPPEL, %d1
        lea     .Lrappel, %a2
        bsr     .Ltexte

        | THE VALUES, read once and written straight away, each under its palette.
        |
        | SYSTEM, palette 9: THE MODE, BIOS_MVS_FLAG ($10FD82; "BIOS RAM locations", 0 AES,
        | $80 MVS), which `c0.s` sets before this screen — the descriptor, or the mode chosen
        | in the editor (`reglages.s`). So it no longer displays the descriptor: an MVS in AES
        | mode says AES, which is what the games see (DECISIONS §11).
        move.w  #0x9000, %d3
        move.w  #CASE_VALEURS, %d1
        lea     .Lmvs, %a2
        tst.b   0x10FD82
        bmi.s   1f
        lea     .Laes, %a2
1:      bsr     .Ltexte

        | REGION, palette 10. Read in "System ROM": 0 Japan, 1 US, 2 Europe. Outside 0-2,
        | "UNKNOWN" — ASSUMED, no page names any other value. Read in BIOS_COUNTRY_CODE,
        | which `c0.s` sets before this screen: the descriptor, or the region chosen in the
        | editor (`reglages.s`).
        move.w  #0xA000, %d3
        move.w  #CASE_VALEURS + 2, %d1
        moveq   #0, %d0
        move.b  0x10FD83, %d0
        cmpi.b  #3, %d0
        bcs.s   1f
        moveq   #3, %d0
1:      lsl.w   #2, %d0
        lea     .Lregions, %a2
        movea.l (%a2,%d0.w), %a2
        bsr     .Ltexte

        | THE CLOCK, palette 11, "MM/DD/YY DDD". Measured (`2026-10-19-read-calendar.tsv`,
        | point 3): $10FDD3 month, $10FDD4 day, $10FDD2 year, in BCD — two nibbles, so two
        | digits —, $10FDD5 day of week, Sunday = 0 (read in "READ CALENDAR", quoted in the
        | same record). A day of week outside 0-6 displays nothing: ASSUMED.
        move.w  #0xB000, %d3
        move.w  #CASE_VALEURS + 4, %d1
        move.b  0x10FDD3, %d4
        bsr     .Lhex2
        moveq   #0x2F, %d2           | "/"
        bsr     .Lcar
        move.b  0x10FDD4, %d4
        bsr     .Lhex2
        moveq   #0x2F, %d2           | "/"
        bsr     .Lcar
        move.b  0x10FDD2, %d4
        bsr     .Lhex2
        addi.w  #32, %d1                | one background cell between the year and the day
        moveq   #0, %d0
        move.b  0x10FDD5, %d0
        cmpi.b  #6, %d0
        bhi.s   1f
        lsl.w   #2, %d0
        lea     .Ljours, %a2
        adda.w  %d0, %a2
        bsr     .Ltexte
1:

        | THE MEMORY CARD, palette 12. Read in "Memory mapped registers": REG_STATUS_B,
        | bits 5-4 at 00 when the card is "correctly inserted". Measured
        | (`2026-10-19-card-avec-carte.tsv`): the high byte of $380000 is $FF without a card,
        | $8F with one — bits 5-4 at 11 then 00.
        move.w  #0xC000, %d3
        move.w  #CASE_VALEURS + 6, %d1
        lea     .Lsans_carte, %a2
        move.b  STATUS_B, %d0
        andi.b  #0x30, %d0
        bne.s   1f
        lea     .Lavec_carte, %a2
1:      bsr     .Ltexte

        | THE GAME, palette 13. Read in "68k program header": the NGH is the word at $108,
        | "NGH number in BCD". Four hexadecimal digits: a conforming NGH shows only decimal
        | ones. TAKEN FROM THE SLOT TABLE ($D00124, the entry of the served slot $D00108),
        | which the detection in `c0.s` has just written under REG_CRTFIX — NOT READ AGAIN AT
        | $108: this screen runs under REG_BRDFIX, the board's font, and on the hardware the
        | cartridge does not answer there (SLOTCS, see the detection). Image no. 8 read it
        | again: E05C on a real MV-2F, the word that followed that read. Served slot empty: 0000.
        move.w  #0xD000, %d3
        move.w  #CASE_VALEURS + 8, %d1
        moveq   #0, %d4
        move.b  0xD00108, %d4           | the served slot
        lsl.w   #2, %d4
        lea     0xD00124, %a2
        move.w  (%a2,%d4.w), %d4        | its NGH
        ror.w   #8, %d4
        bsr     .Lhex2
        ror.w   #8, %d4
        bsr     .Lhex2

        | ------------------------------------------------------------------------------
        | FRAMES 1 TO T_FIN. %d7: the frame. %a0, %a1, %a6 and %d7 do not change.
        moveq   #1, %d7
.Lboucle:
        bsr     .Ltrame

        | THE TITLE DECODING, frames 1 to 12.
        cmpi.w  #12, %d7
        bhi.s   .Lapres_decode
        moveq   #0, %d4                 | %d4: the letter, 0 to N_TITRE - 1
        move.w  #CASE_TITRE, %d1
.Ldecode:
        lea     .Ltitre, %a2
        moveq   #0, %d2
        move.b  (%a2,%d4.w), %d2        | the frozen letter
        cmpi.b  #0x20, %d2              | the space does not decode
        beq.s   .Ldecode_poser
        move.w  %d4, %d5
        lsr.w   #1, %d5                 | its pair, 0 to 4
        add.w   %d5, %d5
        addq.w  #2, %d5                 | its freezing frame: 2 + 2 × pair
        cmp.w   %d5, %d7
        bcs.s   .Ldecode_hasard
        bne.s   .Ldecode_poser
        move.w  %d4, %d5                | frozen at this frame: its title colour
        lsr.w   #1, %d5
        addq.w  #1, %d5
        move.w  #C_TITRE, %d6
        bsr     .Lpalette               | %d2 returned intact
        bra.s   .Ldecode_poser
.Ldecode_hasard:
        | Draw: _table_alea (`alea.s`, a permutation of 0-255) at index N_TITRE × frame
        | + letter, its 5 low bits choosing among 32 measured characters.
        move.w  %d7, %d2
        mulu    #N_TITRE, %d2
        add.w   %d4, %d2
        andi.w  #0xFF, %d2
        lea     _table_alea, %a2
        move.b  (%a2,%d2.w), %d2
        andi.w  #31, %d2
        lea     .Lhasard, %a2
        move.b  (%a2,%d2.w), %d2
.Ldecode_poser:
        move.w  %d4, %d0
        lsr.w   #1, %d0
        addq.w  #1, %d0
        ror.w   #4, %d0                 | palette 1 + pair in the 4 high bits
        or.w    %d0, %d2
        bsr     .Lglyphe
        addi.w  #32, %d1
        addq.w  #1, %d4
        cmpi.w  #N_TITRE, %d4
        bcs.s   .Ldecode
.Lapres_decode:

        | THE URL AND THE VERSION, frame 13.
        cmpi.w  #13, %d7
        bne.s   1f
        moveq   #7, %d5
        move.w  #C_DOUX, %d6
        bsr     .Lpalette
1:

        | THE GLINT, frames 13 to 20: pair h = frame - 13 in white, its neighbours in
        | half-tone, the others in title colour. h = 5 to 7 finish leaving.
        cmpi.w  #13, %d7
        bcs.s   .Lapres_reflet
        cmpi.w  #20, %d7
        bhi.s   .Lapres_reflet
        move.w  %d7, %d3
        subi.w  #13, %d3
        moveq   #0, %d4
1:      move.w  #C_TITRE, %d6
        move.w  %d4, %d0
        sub.w   %d3, %d0
        beq.s   2f
        bpl.s   3f
        neg.w   %d0
3:      cmpi.w  #1, %d0
        bne.s   4f
        move.w  #C_MI, %d6
        bra.s   4f
2:      move.w  #C_BLANC, %d6
4:      move.w  %d4, %d5
        addq.w  #1, %d5
        bsr     .Lpalette
        addq.w  #1, %d4
        cmpi.w  #6, %d4
        bcs.s   1b
.Lapres_reflet:

        | THE LINES, frames 21 to 45: line k = (frame - 21) / 5, phase = its remainder.
        | Phase 0: the label prints; phases 2, 3, 4: the value lights up.
        move.w  %d7, %d3
        subi.w  #21, %d3
        bcs.s   .Lapres_lignes
        cmpi.w  #24, %d3
        bhi.s   .Lapres_lignes
        moveq   #0, %d4
2:      cmpi.w  #5, %d3
        bcs.s   3f
        subq.w  #5, %d3
        addq.w  #1, %d4
        bra.s   2b
3:      tst.w   %d3
        bne.s   5f
        tst.w   %d4                     | the first line lights the labels
        bne.s   4f
        moveq   #8, %d5
        move.w  #C_ETIQ, %d6
        bsr     .Lpalette
4:      move.w  %d4, %d0
        mulu    #15, %d0
        lea     .Letiquettes, %a2
        adda.w  %d0, %a2
        move.w  %d4, %d1
        add.w   %d1, %d1
        addi.w  #CASE_LIGNES, %d1
        move.w  #0x8000, %d3
        bsr     .Ltexte
        bra.s   .Lapres_lignes
5:      cmpi.w  #2, %d3
        bcs.s   .Lapres_lignes
        lea     .Lrampe - 2, %a2
        move.b  (%a2,%d3.w), %d3        | 3, 6 then 8 eighths
        move.w  #C_VERT, %d6
        bsr     .Lattenuer
        move.w  %d4, %d5
        addi.w  #9, %d5
        bsr     .Lpalette
.Lapres_lignes:

        | THE BLINKING REMINDER, from T_PAUSE to T_FONDU - 1: lit when bit 4 of
        | (frame - T_PAUSE) is zero, i.e. 16 frames on, 16 off.
        cmpi.w  #T_PAUSE, %d7
        bcs.s   1f
        cmpi.w  #T_FONDU, %d7
        bcc.s   1f
        move.w  %d7, %d0
        subi.w  #T_PAUSE, %d0
        move.w  #C_RAPPEL, %d6
        btst    #4, %d0
        beq.s   2f
        moveq   #0, %d6
2:      moveq   #14, %d5
        bsr     .Lpalette
1:

        | THE FADE, frames T_FONDU to T_FIN: each palette at (T_FIN - frame)/8 of its
        | final colour. The reminder starts from the phase where the blinking left it.
        cmpi.w  #T_FONDU, %d7
        bcs.s   .Lapres_fondu
        moveq   #1, %d4
1:      move.w  %d4, %d0
        add.w   %d0, %d0
        lea     .Lfinales - 2, %a2
        move.w  (%a2,%d0.w), %d6
        move.w  #T_FIN, %d3
        sub.w   %d7, %d3
        bsr     .Lattenuer
        move.w  %d4, %d5
        bsr     .Lpalette
        addq.w  #1, %d4
        cmpi.w  #N_PAL, %d4
        bls.s   1b
.Lapres_fondu:

        addq.w  #1, %d7
        cmpi.w  #T_FIN, %d7
        bls     .Lboucle

| ----------------------------------------------------------------------------------
| THE EXIT, shared by the end and the skip. The palettes first, just after the pass of
| line $1F0, so that their reset to zero falls in the blanking and makes no snow;
| FIX_CLEAR afterwards, its 1,280 VRAM writes not needing to fit in the blanking.
.Lsortie:
        movea.l %a6, %sp
        bsr     .Lsync
        moveq   #0, %d4                 | palette 0 included, set at frame 0
1:      move.w  %d4, %d5
        moveq   #0, %d6
        bsr     .Lpalette
        addq.w  #1, %d4
        cmpi.w  #N_PAL, %d4
        bls.s   1b
        | The reference is not reset to zero: it stays at the $8000 of turn 0.
        clr.w   FOND
        jsr     _fix_clear              | REG_VRAMMOD left at 1
        move.b  %d0, WATCHDOG
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rts

| ----------------------------------------------------------------------------------
| ONE FRAME, then the buttons. Read in "Memory mapped registers": REG_P1CNT ($300000)
| and REG_P2CNT ($340000), bits 7-4 D, C, B, A, active low; REG_STATUS_B ($380000),
| bits 3-0 SELECT P2, START P2, SELECT P1, START P1, active low. The directions (bits 3-0
| of the joysticks) and the coins (REG_STATUS_A) are not read: a coin is therefore not
| consumed here.
.Ltrame:
        bsr.s   .Lsync
        jsr     _panneau_p1             | %d0: P1, joystick or translated panel (`panneau.s`)
        andi.b  #0xF0, %d0
        cmpi.b  #0xF0, %d0
        bne.s   .Lsortie
        move.b  P2CNT, %d0
        andi.b  #0xF0, %d0
        cmpi.b  #0xF0, %d0
        bne.s   .Lsortie
        | SELECT ON MVS DOES NOT COUNT. Read in "BIOS RAM locations": "On MVS the select
        | bits are always read as 0". ASSUMED: that the raw register does not carry a
        | reliable SELECT on MVS either; resting in the active state, it would skip the screen
        | from frame 1. Only the two STARTs (bits 0 and 2) are then kept. It is a question of
        | MACHINE, not of mode: REG_STATUS_B bit 7, "0:AES 1:MVS" ("Memory mapped registers");
        | an MVS in AES mode stays an MVS (DECISIONS §11).
        move.b  STATUS_B, %d0
        not.b   %d0
        andi.b  #0x0F, %d0
        tst.b   STATUS_B                | the machine: bit 7, the sign — `tst` rather than
        bpl.s   1f                      | `btst`, the cycles of the earlier `tst.b 0x10FD82`
        andi.b  #0x05, %d0
1:      tst.b   %d0
        bne.s   .Lsortie
        rts

| THE PASS OF LINE $1F0. Measured (`2026-10-17-diagnostic-b2b-minasan.tsv`, quoted by
| `c0.s`): REG_LSPCMODE reads back as a line counter in its bits 15-7. We wait to leave
| it, then to enter it: a single return per frame, even if the caller was brief.
| BOUNDED: each wait returns after SYNC_TOURS turns, line seen or not, so that a line
| counter that never went through $1F0 on a board does not freeze the BIOS. A turn takes
| 70 cycles without wait state (`move.b` Dn to abs.l 16, `move.w` abs.l 16, `lsr.w #7` 20,
| `cmpi.w` 8, `dbcc` taken 10): 5,800 turns ≈ 406,000 cycles ≈ 2.0 frames at 12 MHz
| (202,750 cycles per frame at 59.185 Hz). A wait state on the registers would only
| lengthen the bound. Under MAME the line is seen on every frame: the bound is not
| used. The watchdog gets kicked on every turn. Identical copy in `dip.s`, `tests.s`,
| `menu.s`, `plantage.s`, `jukebox.s`. Clobbers %d0.
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
| ONE 8×16 GLYPH. %d1: the top cell; %d2: palette << 12 | ASCII code, returned intact.
| REG_VRAMMOD at 1: the bottom cell is the next one ("Fix layer", top to bottom).
.Lglyphe:
        move.w  %d1, (%a1)              | REG_VRAMADDR
        addi.w  #0x100, %d2
        move.w  %d2, (%a0)              | top: $100 + ASCII
        addi.w  #0x100, %d2             | 8 cycles
        nop                             | 4: 12 between the two data
        move.w  %d2, (%a0)              | bottom: $200 + ASCII
        subi.w  #0x200, %d2
        rts

| ONE CHARACTER. %d2: ASCII code; %d3: palette << 12; %d1 advances by one column.
.Lcar:
        or.w    %d3, %d2
        bsr.s   .Lglyphe
        addi.w  #32, %d1
        rts

| A STRING terminated by 0. %a2: the string; %d1, %d3 as in `.Lcar`. Clobbers %d2, %a2.
.Ltexte:
        moveq   #0, %d2
        move.b  (%a2)+, %d2
        beq.s   1f
        bsr.s   .Lcar
        bra.s   .Ltexte
1:      rts

| ONE BYTE AS TWO HEXADECIMAL DIGITS. %d4.b: the byte, returned intact. Clobbers %d2.
.Lhex2:
        move.b  %d4, %d2
        lsr.b   #4, %d2
        bsr.s   .Lchiffre
        move.b  %d4, %d2
.Lchiffre:
        andi.w  #0x0F, %d2
        cmpi.w  #10, %d2
        bcs.s   1f
        addq.w  #7, %d2                 | 10-15 → "A"-"F"
1:      addi.w  #0x30, %d2              | "0"
        bra.s   .Lcar

| ONE PALETTE. %d5: its number (1-15); %d6: the stroke colour, entry 1; entries 2 to 15
| at zero (see the header, the glyph indexes). Clobbers %d0, %d5, %a2.
.Lpalette:
        lea     PALETTES + 2, %a2
        lsl.w   #5, %d5                 | 16 entries of 2 bytes
        adda.w  %d5, %a2
        move.w  %d6, (%a2)+
        moveq   #14-1, %d0
1:      clr.w   (%a2)+
        dbra    %d0, 1b
        rts

| A DIMMED COLOUR. %d6: $0RGB; %d3: factor 0 to 8. Each nibble becomes
| nibble × factor / 8; result in %d6. Clobbers %d0, %d2, %d5.
.Lattenuer:
        moveq   #0, %d0
        rol.w   #4, %d6                 | RGB0
        moveq   #3-1, %d5
1:      rol.w   #4, %d6                 | R, then G, then B in the low nibble
        moveq   #0x0F, %d2
        and.w   %d6, %d2
        mulu    %d3, %d2
        lsr.w   #3, %d2
        lsl.w   #4, %d0
        or.w    %d2, %d0
        dbra    %d5, 1b
        move.w  %d0, %d6
        rts

| ----------------------------------------------------------------------------------
| THE DATA.
        .balign 2
.Lfinales:                              | the final colour of palettes 1 to 14, for the fade
        .word   C_TITRE, C_TITRE, C_TITRE, C_TITRE, C_TITRE, C_TITRE
        .word   C_DOUX, C_ETIQ
        .word   C_VERT, C_VERT, C_VERT, C_VERT, C_VERT
        | The reminder starts from its phase at T_FONDU, bit 4 of PAUSE: off, it stays off.
        .word   C_RAPPEL * (1 - ((PAUSE >> 4) & 1))
.Lregions:
        .long   .Ljapon, .Lusa, .Leurope, .Linconnue
.Lrampe:
        .byte   3, 6, 8
.Ltitre:
        .ascii  "PRIVABIOS"
| 32 characters, all measured; the last six repeat the first ones.
.Lhasard:
        .ascii  "ABCDEFGHIKLMNOPRSTUWX0126/ABCDEF"
.Lurl:
        .asciz  "privabios.com"
.Lversion:
_txt_version:
        .asciz  "v0.1 BETA"
.Lrappel:
        .asciz  "PRESS A BUTTON TO SKIP"
| Five labels of 14 characters, 15 bytes each with the zero.
.Letiquettes:
        .asciz  "SYSTEM ......."
        .asciz  "REGION ......."
        .asciz  "CLOCK ........"
        .asciz  "CARD ........."
        .asciz  "GAME NGH ....."
.Lmvs:
        .asciz  "MVS"
.Laes:
        .asciz  "AES"
.Ljapon:
        .asciz  "JAPAN"
.Lusa:
        .asciz  "USA"
.Leurope:
        .asciz  "EUROPE"
.Linconnue:
        .asciz  "UNKNOWN"
.Lsans_carte:
        .asciz  "NONE"
.Lgel1:
        .asciz  "DIP SWITCH 8 IS ON"
.Lgel2:
        .asciz  "SET IT OFF TO CONTINUE"
.Lavec_carte:
        .asciz  "INSERTED"
| Read in "READ CALENDAR": Sunday = 0. Four bytes per day.
.Ljours:
        .asciz  "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"
        .balign 2
