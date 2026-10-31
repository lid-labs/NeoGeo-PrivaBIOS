| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| THE SOFT-DIP EDITOR — opened at boot when the board's TEST button is held.
|
| Called by `jsr` from `c0.s`, on both paths of the slot table (`_slot_inscrit` after
| `_dip_copier`, `_slot_present` after the read-back of the block), before
| REG_SRAMLOCK: the backup RAM is still unlocked. Input: %a1 points JUST AFTER
| the game's save block ($D00220 + 16 × index + 16), where both paths leave it;
| BIOS_GAME_DIP ($10FD84-$10FD93) and this block are equal there. %a3: the index of
| the game's entry in the slot table, on both paths; %d6, 1 if this boot has just
| registered it, 0 otherwise. Output:
| all registers returned intact — except if the region has changed, where we do not return
| (see THE EXIT). Button not held: one `btst` and one `rts`, nothing else.
|
| NO ORACLE: the reference BIOS's settings menu is not read. The hand-overs are
| "Couche 3 → l'éditeur de soft-DIP, le 2026-10-20" and "Couche 3 → la région à chaud
| et la sauvegarde des réglages du BIOS, le 2026-10-20" (`docs/RELECTURE-CONTRATS.md`).
|
| THE REGION LINE, at the top, always there: JAPAN, USA, EUROPE (0, 1, 2, "BIOS RAM
| locations"), starting from BIOS_COUNTRY_CODE. It is not a cartridge setting:
| the reset to defaults does not touch it, and the soft-DIP labels displayed stay those
| of the current region. Changed, it is saved on START (`reglages.s`) and the machine
| restarts.
| THE MODE LINE, after the cartridge settings and before HARDWARE TESTS: MVS, AES (decision
| D7), starting from BIOS_MVS_FLAG ($10FD82). Like REGION, it is not a cartridge
| setting; changed, it is saved on START (`reglages.s`) and the machine restarts. But
| the entry of a known game is not freed: the mode does not change the soft-DIP block read, and
| a request 0 would erase the scores that decision D5 keeps. That of a game this boot
| has just registered (%d6 = 1, `c0.s`) is: its request 0 has not yet taken place, and the next
| boot would restore a block never saved (measured under MAME on 2026-10-23, aof, fresh
| NVRAM: without this, the demo follows the restart without request 0). NOT UNDER REGION: the key
| paths of the records (ROUND TIME at "down", LANGUAGE at "down, down") stay those from before; from the
| first line, "up" four times leads there, whatever the game. DECISIONS §11.
| "measured": a named record; "read in": a page of the NeoGeo Development Wiki;
| "ASSUMED": neither one nor the other.
|
| THE TEST BUTTON. Read in "Memory mapped registers": REG_SYSTYPE ($300081), bit 7
| "Test button", without an active level. Measured under MAME on 2026-10-20 (kof98, -bios euro,
| our image, `:TEST` field "Service Mode"): $80 released, $00 held — active low.
| WITHOUT A TEST BUTTON, since 2026-10-25 (a consolized MVS has none), two other inputs,
| read at the same instant, just after the boot screen:
|   - board switch 1, "Setting Mode" (REG_DIPSW $300001 bit 0, active low:
|     "Memory mapped registers"; mask $01, SW:1, in the MAME source) at ON. MEASURED
|     (`measured/2026-10-25-dip-free-play.tsv`, section 4): the SNK BIOS and UniBIOS 4.0 then open
|     their test menu at each power-on, do not read it hot (toggled in
|     demo, nothing), and EXIT there displays "DIP-SW 1 OFF !!" as long as it stays at ON; toggled to
|     OFF, the machine restarts into the game; toggled to OFF before EXIT, the exit happens without
|     a message (SNK: the machine restarts). DELIBERATE DEPARTURE: here START always leaves it.
|     Switch still at ON, a warning (DIP SWITCH 1 IS ON) stays AVERT_TRAMES frames on screen, or
|     until it is toggled, then the game — we do not hold back in a menu that has no access to the
|     board (`.Lavertir`). Toggled back to OFF during the screen, no warning. It reopens the screen
|     at each boot as long as it is at ON (a region change, which restarts, therefore leads back
|     there);
|   - START and SELECT of P1 held together (REG_STATUS_B bits 0 and 1, active low), the gesture of
|     the in-game menu (`menu.s`, THE GESTURE): they skip the boot screen, and held until here, open
|     the editor. No game runs yet: nothing else reads them. Measured under MAME: at rest,
|     $380000 is $FF on aof, ng_mv1, ng_mv1f, ng_mv2f, ng_mv4f and the MV-6F — SELECT is not
|     read active there. ASSUMED on the hardware: a SELECT read active at rest would make START
|     alone held at boot the entry of the editor, START remaining what leaves it.
|     REFUSED, since 2026-10-27, if A, B, C and D of P1 are held ALL FOUR
|     (REG_P1CNT $300000 bits 4-7, active low: "Memory mapped registers"); one, two or three
|     of them held, it opens the editor as if alone. OBSERVED on the hardware by the tester on
|     2026-10-26 (image no. 14, `docs/ESSAI-MATERIEL.md`): the BlueRetro adapter holds for about
|     one second L/R, A, B, C, D, START and SELECT at its start-up, and opened the TEST screen at
|     each boot. All four at once is its signature; "A-D released" would refuse the gesture to
|     the player who brushes A. ASSUMED: that no other controller holds all four at power-on.
|     TEST and switch 1 do not depend on it. DECISIONS §17 pt 5.
|
| THE CARTRIDGE'S SOFT-DIP BLOCK, read in "Software DIPs": $00-$0F the name; $10-$13
| two times as words, minutes then seconds in BCD, minutes "up to 29", $FFFF = unused;
| $14 a count from 1 to 99, $15 a number of times from 0 ("WITHOUT") to 100 ("INFINITE"),
| $FF = unused; $16-$1F ten choice settings, default in the high nibble, number of
| choices in the low; from $20, labels of 12 characters: one per special
| setting, then for each choice setting its label followed by one per choice. Measured on
| 2026-10-20 on the labels of kof98 and aof (read by lua in their P-ROM, not
| versioned): an unused special setting takes no label (kof98 has none and
| its labels start at the first choice setting; aof, a count, starts with
| its own), and the rest of the table falls exactly right on both games.
|   ASSUMED: a choice setting whose number is 0 takes no label and is not
|   displayed (the page says so only for the "NEXT PAGE" entry; aof sets its own
|   to 1 choice, displayed as is, without effect). The seconds bounded to 59, the time
|   editable from 00:00 to 29:59, in steps of one second.
| The block pointer follows the region as in `c0.s` (`_slot_inscrit`), with the same
| areas and the same refusal (zero, or block that does not fit whole in $000000-$0FFFFF or in
| $200000-$2FFFFF, read in the bank in place: see `c0.s`): refused, the screen shows
| only the reset-to-defaults line, without effect, and START saves GAME_DIP as it
| is. A label that would overflow its block's area is displayed blank. A character
| outside $20-$7E becomes a space, except in the 8×16 list (below).
|
| THE VALUES RECEIVED, made valid on entry. A time that is not BCD within the
| bounds, a count or a choice outside its bounds takes the cartridge's default if it is
| valid, otherwise the minimum (00:00, 1, 0, choice 0). ASSUMED: the page leaves open the
| question of the validation of values. An unused setting takes the value the cartridge
| declares, as at registration (`.Linutilises`): it was not touched, and the START
| saved the bytes of an entry never initialised.
|
| THE FIX LAYER AND THE Z80. At this call, the boot has already written REG_CRTFIX: the fix
| layer reads the cartridge's S ROM, without the board's font. Read in "Memory mapped
| registers" (quoted by `c0.s`): REG_BRDFIX ($3A000B) and REG_CRTFIX ($3A001B) switch
| the S ROM AND the Z80's M1 together. Going back to the board's font would therefore cut the
| ROM from under the game's sound driver. We redo the handshake the page provides for a
| slot change ("68k/Z80 communication"): $01, the driver cuts the sound, loops in
| RAM and answers $01; REG_BRDFIX; the editor; REG_CRTFIX; $03, the Z80 reset, "under
| 100ms", without answer. ASSUMED: waiting 8 frames (≈ 135 ms) after the boot's $03 before
| sending $01, so that the freshly reset driver hears it; the echo awaited
| 60 frames at most, then we switch anyway, like `c0.s`. The $01 of the boot's echo
| could stay in the reply latch and pass for an echo: the page does not say
| how to empty it. Measured on aof (MAME, local lua jig, 2026-10-20): without the editor,
| the latch is $80 on frame 200, with it $01 — the echo seen is therefore the real one; after the
| exit, the Z80 returns into the same loop ($013E-$0146) as without the editor, and the game
| sends it the same sequence of commands (3, 19 then 25 writes of REG_SOUND logged every
| 100 frames), a hundred frames later: the time spent in the editor.
|
| THE COPY. Under REG_BRDFIX, the cartridge's P-ROM does not respond on the hardware (feedback of
| 2026-10-24, `docs/ESSAI-MATERIEL.md`; SLOTCS, `c0.s`): read after the switch, the name and the
| labels were the floating bus — 244 reads on aof as on mslug under
| `bench/bus-flottant.lua`, rows of "Q" on screen. MAME, for its part, serves the P-ROM under
| both. The block is therefore copied into RAM before the switch, then the screen reads only the
| copy: the name, the times and choices, and the labels, up to the end of the table or of the
| block's area, 1,692 bytes at most (138 labels; beyond, the cell stays blank, like a label
| outside its area). Set aside: staying under REG_CRTFIX, the screen would take the cartridge's
| font; switching around each read, the S ROM would change under the fix layer mid-picture. The
| place: the RAM of the in-game menu and its screens, which none uses at boot, cleared on exit
| (the clear of `c0.s` had left it at zero there). The work RAM test (`tests.s`) keeps
| $10F000-$10FFFF, hence the copy.
|
| THE DISPLAY, like `ecran.s` (read in "Fix layer", "Palettes", "VRAM"; measured
| in `measured/2026-10-20-sfix-glyphes.tsv`): fix layer only, $7000 + 32 × column +
| line, lines 2 to 29 visible; 8×8 font = ASCII tile, 8×16 = $100/$200 + ASCII (and
| $300/$400 + byte, the 8×16 list);
| each palette carries its colour in entry 1, black in 2 to 15. Here REG_VRAMMOD
| is 32: a write advances by one column, a line of text is written from a single
| address. The stroke of the 8×8 glyphs at index 1: measured on our captures of the editor
| (not versioned).
| Palettes: 1 the text, 2 the chosen line, 3 the title and the name, 4 the help; and palette
| 0, entries 1-15 black, like `ecran.s` and `plantage.s`: FIX_CLEAR puts its tile
| $020 under it, full of index 2 (`measured/2026-10-21-sfix-tuiles-pleines.tsv`). Written
| once, just after the passing of line $1F0; only the cells change afterwards.
|
| THE 8×16 LIST, 2026-10-27 (DECISIONS §19, user's decision). In the JAPAN region,
| if the copied labels (from byte $20 of the block to COPIE_FIN) carry at least one byte outside
| $20-$7E, the whole list goes to 8×16: two rows per entry, a window of FENETRE = 10
| entries (rows 7 to 26) that follows the chosen line, like GAME SETTINGS. MEASURED
| (`measured/2026-10-27-intitules-japon.tsv`): the Japanese SNK BIOS writes each byte b of a
| label or of a choice at $300 + b (top) and $400 + b (bottom), palette 0 (section 1); under the
| board's font, $300/$400 + b and $100/$200 + b have the same glyph for $20-$5E and $61-$7B,
| not for $5F, $60, $7C-$7E (section 2, 90 out of 95) — hence `.Lecrire16`: $100/$200 + b for the
| former, $300/$400 + b for any other, SNK's rule. The name and the title do not change;
| the CABINET SETTINGS sub-screen stays in 8×8. A block all in ASCII, or another region: the
| 8×8 list from before, to the byte, and writing a line there costs only two tests
| (`.Lligne`, `.Lv_fin`). ASSUMED: that the board's font has these glyphs on the hardware
| as under MAME (MAME's SFIX, read on screen only).
|
| THE SCORE RESET LINE, just before MEMORY CARD ("up" six times): ON, the games read the real
| date; OFF, READ_CALENDAR returns to them the date of the day the setting went to OFF (`cal.s`),
| and the games that reset their records to zero when the date changes no longer do so. Like
| REGION and MODE, it is not a cartridge setting; changed, it is saved on START (`reglages.s`,
| with the date read at that moment), without restart: the game only reads the date by calling it.
| THE HARDWARE TESTS LINE, before the reset to defaults, always there: right, left or A
| open the self-tests (`tests.s`), which return control on START; the screen is then
| redrawn, the values being edited kept (they are in GAME_DIP, which the work RAM
| test preserves). THE JUKEBOX LINE follows it, likewise: `jukebox.s`, which returns
| the Z80 and the fix layer in the state of this screen. THE MEMORY CARD LINE, likewise, opens
| the memory card manager (`gestion-carte.s`); it is just before MODE, and not
| near the two others, to keep the key paths of the records ("up" once
| leads to the reset, twice to the jukebox, three times to the tests, four to the mode): "up" five
| times leads there, whatever the game.
| THE CABINET SETTINGS LINE, just before SCORE RESET ("up" seven times, 2026-10-25): right,
| left or A open a sub-screen of five lines, the cabinet settings (`reglages.s`) —
| FREE PLAY (OFF, ON), NO CONTINUE (OFF, ON), DEMO SOUND (ON, OFF), and CHEATS/DEBUG (ON, OFF; at
| OFF, the in-game menu no longer offers either cheats or MEMORY EDITOR, `menu.s`, and the engine
| of cheats and freezes no longer writes anything, `cheats.s`); START there returns the list, on
| the same line, and it is the list's START that saves, without restart. A sub-screen rather than
| three lines: measured on 2026-10-25 over 159 games (European block, the
| settings used counted), up to 12 cartridge settings (froman2b, pspikes2, tophuntr,
| turfmast): 19 lines today, 22 with three more lines, when the list holds 21; 20
| with one. Placed there, it moves no key path of the records ("up" one to six times,
| "down" towards the cartridge settings). In AES mode (the MODE line at AES), the first three
| values say MVS ONLY and do not change: they are inert in AES (`reglages.s`, `_borne_ram`).
| CHEATS/DEBUG, for its part, holds in both modes: the in-game menu opens in AES too.
| The fifth line, DEBUG DIPS (2026-10-25), opens the debug dips screen (`debug.s`); its
| value is their mask in hexadecimal, or OFF, and then it does not open, under CHEATS/DEBUG
| OFF. After the four others, it moves no path ("down" three times still leads to
| CHEATS/DEBUG).
|
| THE ABOUT LINE, just before CABINET SETTINGS ("up" eight times, 2026-10-28): right, left
| or A open the screen of legal notices and credits (`about.s`), which START closes. Placed
| there, it moves no key path of the records, like CABINET SETTINGS before it. THE
| LIST IS FULL: with the 12 cartridge settings of the measured maximum (see CABINET SETTINGS),
| REGION and the eight BIOS lines, 21 lines out of 21 (counted, not seen on screen). One more
| line would overflow onto the help for froman2b, pspikes2, tophuntr and turfmast.
|
| THE CONTROLS, P1 only, on edge (released → pressed). Read in "Memory mapped
| registers": REG_P1CNT ($300000) bits 0-4 up, down, left, right, A; REG_STATUS_B
| ($380000) bit 0 START P1; active low. Up/down: the line, wrapping.
| Right/left: the value, bounded. A: the next value, which restarts at the minimum after
| the maximum — for a cabinet with a single button. On the last line, right, left or A
| restore the cartridge's defaults. START: saves and exits.
|
| THE SAVE: the 16 bytes of GAME_DIP, in the format of `_dip_copier` (times and
| counts as is, then one choice index per byte), copied into the game's block.
| THE STATE RETURNED: fix layer cleared by FIX_CLEAR (REG_VRAMMOD at 1), palettes 0-4 and the
| background at zero, the reference $400000 left at $8000, registers intact. IRQs masked
| throughout (SR = $2700 since `_demarrage`); kick to the watchdog in each wait.
| ==================================================================================

        .section .haut, "ax"
        .global _editeur_dip
        | THE ENGINE, shared with GAME SETTINGS of the in-game menu (`menu.s`): the block pointer,
        | the settings table, the step of a value, the defaults, the text of a value.
        .global _dip_bloc, _dip_table, _dip_pas_valeur, _dip_defauts, _dip_valeur, _dip_copier

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    WATCHDOG, 0x300001
        .equ    DIPSW,    0x300001      | on read: the board switches, active low
        .equ    P1CNT,    0x300000
        .equ    SYSTYPE,  0x300081
        .equ    CARTE_DEMANDE, 0xD001A8 | .b non-zero: RESTART TO CARD (`menu.s`); ours, like $D001B0
        .equ    SOUND,    0x320000
        .equ    STATUS_B, 0x380000
        .equ    BRDFIX,   0x3A000B
        .equ    CRTFIX,   0x3A001B
        .equ    PALBANK0, 0x3A000F
        .equ    PALETTES, 0x400000
        .equ    FOND,     0x401FFE
        .equ    GAME_DIP, 0x10FD84
        | The copy of the soft-DIP block (see the header, THE COPY): the RAM of the in-game menu,
        | of GAME SETTINGS and of the memory editor (`menu.s`, `reglages-jeu.s`, `memoire.s`), above
        | the flag of `plantage.s` ($10F458-$10F45B) and below the cheats ($10FB00).
        .equ    COPIE_FIN, 0x10F460     | .l the end of what was copied
        .equ    COPIE,     0x10F464     | the block, from its byte $00
        .equ    COPIE_LIM, 0x10FB00     | 1,692 bytes: the name, the times and choices, 138 labels

        | The layout, in fix layer cells.
        .equ    CASE_TITRE, 0x7000 + 11 * 32 + 3       | 8×16, lines 3-4
        .equ    CASE_NOM,   0x7000 + 12 * 32 + 6       | 16 characters
        .equ    CASE_LIGNE, 0x7000 +  3 * 32 + 7       | line 0 of the list, column 3
        | The help on lines 28 and 29: the list holds 21 of them, lines 7 to 27, just below the name.
        .equ    CASE_AIDE1, 0x7000 +  3 * 32 + 28
        .equ    CASE_AIDE2, 0x7000 +  3 * 32 + 29
        .equ    LARGEUR,    31          | one list line: columns 3 to 33
        .equ    COL_VALEUR, 19          | the value in column 22

        | The colours, $0RGB ("Colors"). Choice of look.
        .equ    C_TEXTE,  0x0BBB
        .equ    C_CHOISI, 0x0FE3
        .equ    C_TITRE,  0x04BF
        .equ    C_AIDE,   0x0777

        | The stack frame: the table of lines, a line buffer, the block.
        .equ    N_MAX,    23            | the region + 4 special + 10 choice + ABOUT
                                        | + the cabinet + the scores + the card + the mode
                                        | + the tests + the jukebox + the reset
        .equ    T_ENTREE, 12            | +0 kind, +1 byte of GAME_DIP, +2 number of
                                        | choices, +3 default, +4 default time, +6 label
        .equ    F_TABLE,  -(N_MAX * T_ENTREE)
        .equ    F_TAMPON, F_TABLE - 32
        .equ    F_BLOC,   F_TAMPON - 4
        .equ    F_REGION, F_BLOC - 1    | the displayed region, 0-2
        .equ    F_REGION0, F_BLOC - 2   | the region on entry
        .equ    F_INSCRIT, F_REGION0 - 4 | %a3 received: the index of the game's entry
        .equ    F_SOFTDIP, F_INSCRIT - 4 | the cartridge's soft-DIP block, 0 if refused
        .equ    F_MODE,   F_SOFTDIP - 1 | the displayed mode: 0 MVS, 1 AES
        .equ    F_MODE0,  F_SOFTDIP - 2 | the mode on entry
        .equ    F_NOUVEAU, F_SOFTDIP - 3 | %d6 received: 1, the slot has just been registered
        .equ    F_SCORES, F_SOFTDIP - 4 | SCORE RESET displayed: 0 ON, 1 OFF
        .equ    F_SCORES0, F_SOFTDIP - 5 | SCORE RESET on entry
        .equ    F_BORNE,  F_SOFTDIP - 6 | the displayed cabinet settings, bits of `reglages.s`
        .equ    F_BORNE0, F_SOFTDIP - 7 | the cabinet settings on entry
        .equ    F_SOUS,   F_SOFTDIP - 8 | 1: the CABINET SETTINGS sub-screen is open
        .equ    F_SV_D6,  F_SOFTDIP - 10 | .w the number of lines of the list, sub-screen open
        .equ    F_SV_D7,  F_SOFTDIP - 12 | .w its chosen line
        .equ    F_TABLE_B, F_SV_D7 - 5 * T_ENTREE | the five lines of the sub-screen
        .equ    F_HAUT,   F_TABLE_B - 2 | .w the 8×16 list: the first entry displayed
        .equ    F_GRAND,  F_TABLE_B - 3 | 1: the 8×16 list (see the header, THE 8×16 LIST)
        .equ    F_GRAND0, F_TABLE_B - 4 | F_GRAND, kept during the sub-screen
        .equ    F_LIEN,   F_TABLE_B - 4
        .equ    FENETRE,  10            | the 8×16 list: ten entries, rows 7 to 26
        | Kinds: 0 time, 1 count, 2 number of times, 3 choice, 4 reset to defaults,
        | 5 the region, 6 the self-tests, 7 the jukebox, 8 the mode, 9 the memory card,
        | 10 SCORE RESET, 11 CABINET SETTINGS; in the sub-screen, 12 FREE PLAY, 13 NO CONTINUE,
        | 14 DEMO SOUND, 15 CHEATS/DEBUG (bit 0, 1, 2, 3 of the cabinet settings: kind - 12), 16 DEBUG DIPS
        | (`debug.s`); 17 ABOUT (`about.s`), in the list.

_editeur_dip:
        btst    #7, SYSTYPE             | TEST held: bit 7 at 0 (measured, see the header)
        beq.s   1f
        btst    #0, DIPSW               | switch 1, "Setting Mode", at ON
        beq.s   1f
        btst    #0, STATUS_B            | START and SELECT of P1 held (see the header)
        bne.s   2f
        btst    #1, STATUS_B
        beq.s   3f
| RESTART TO CARD of the in-game menu (`menu.s`, DECISIONS §33): the mark opens this screen too,
| and the manager over it.
2:      tst.b   CARTE_DEMANDE
        bne.s   1f
        rts
| A, B, C AND D OF P1 HELD ALL FOUR (REG_P1CNT bits 4-7 at 0, active low): the start-up
| of the BlueRetro adapter, not a player (see the header). A single read: bits 4-7
| at 0, the byte is below $10. Apart, after the `rts`: TEST, switch 1, START alone and
| SELECT absent keep their cycles from before.
3:      cmpi.b  #0x10, P1CNT
        bcs.s   2b                      | all four held: the gesture is refused
1:      movem.l %d0-%d7/%a0-%a6, -(%sp)
        | SWITCH 3 read here, on opening, and not after: P1 in this screen and those it opens
        | (`panneau.s`, DECISIONS §30).
        jsr     _panneau_verrou
        link    %a6, #F_LIEN
        move.b  %d6, F_NOUVEAU(%a6)
        move.l  %a3, F_INSCRIT(%a6)
        lea     -16(%a1), %a2
        move.l  %a2, F_BLOC(%a6)        | the game's save block
        lea     GAME_DIP, %a5

        bsr     _dip_bloc               | %a3: the soft-DIP block, 0 if refused
        move.l  %a3, F_SOFTDIP(%a6)     | `.Lligne` overwrites %a3: `.Lecran` reads it back here
        bra     .Lapres_bloc

| THE SOFT-DIP BLOCK POINTER, like `_slot_inscrit` (`c0.s`). Output: %a3, 0 if refused.
| Clobbers %d4, %a2.
_dip_bloc:
        suba.l  %a3, %a3
        moveq   #0, %d4
        move.b  0x10FD83, %d4           | BIOS_COUNTRY_CODE
        cmpi.b  #2, %d4
        bls.s   1f
        moveq   #2, %d4
1:      lsl.w   #2, %d4
        lea     0x116, %a2
        move.l  (%a2,%d4.w), %d4
        beq.s   2f
        cmpi.l  #0x100000 - 0x20, %d4
        bls.s   3f                      | fits in the fixed P-ROM
        cmpi.l  #0x200000, %d4
        blo.s   2f                      | overflows the fixed P-ROM, or between the areas
        cmpi.l  #0x300000 - 0x20, %d4
        bhi.s   2f                      | overflows the banked area, or beyond
3:      movea.l %d4, %a3
2:      rts

.Lapres_bloc:
        | THE CURRENT REGION: BIOS_COUNTRY_CODE, which `c0.s` took from the BIOS settings
        | or from the descriptor. Outside 0-2, Europe, like the pointer above.
        move.b  0x10FD83, %d0
        cmpi.b  #2, %d0
        bls.s   1f
        moveq   #2, %d0
1:      move.b  %d0, F_REGION(%a6)
        move.b  %d0, F_REGION0(%a6)
        | THE CURRENT MODE: BIOS_MVS_FLAG, which `c0.s` took from the settings or from the descriptor.
        moveq   #0, %d0                 | bit 7 at 1: MVS
        tst.b   0x10FD82
        bmi.s   1f
        moveq   #1, %d0                 | AES
1:      move.b  %d0, F_MODE(%a6)
        move.b  %d0, F_MODE0(%a6)
        | CURRENT SCORE RESET: that of the settings (`reglages.s`), ON without a valid block.
        jsr     _reglages_scores        | clobbers %d0, %d1, %a0, %a1
        move.b  %d0, F_SCORES(%a6)
        move.b  %d0, F_SCORES0(%a6)
        | THE CURRENT CABINET SETTINGS: those of the settings, 0 without a valid block.
        jsr     _reglages_borne         | clobbers %d0, %d1, %a0, %a1
        move.b  %d0, F_BORNE(%a6)
        move.b  %d0, F_BORNE0(%a6)
        clr.b   F_SOUS(%a6)
        clr.b   F_GRAND(%a6)
        clr.w   F_HAUT(%a6)

        | THE TABLE OF LINES. %a2: the entry to fill; %a1: the next label;
        | %d6: the number of lines. Everything is read by byte: an odd block is accepted.
        | The region first, always there, even without a soft-DIP block.
        lea     F_TABLE(%a6), %a4
        movea.l %a4, %a2
        moveq   #0, %d6
        move.b  #5, (%a2)
        clr.b   1(%a2)
        lea     .Ltxt_region, %a1
        bsr     .Lentree
        move.l  %a3, %d0
        beq     .Ltable_fin
        bsr     _dip_table
        bsr     .Lcopier_bloc           | the block in RAM: nothing more is read in the P-ROM
        bsr     .Lgrand
        bra     .Ltable_fin

| THE 8×16 LIST (see the header): JAPAN region, and a byte outside $20-$7E in the copied
| labels, from byte $20 of the block to COPIE_FIN. Clobbers %d0, %a0, %a1.
.Lgrand:
        tst.b   F_REGION0(%a6)          | 0: JAPAN
        bne.s   9f
        lea     COPIE + 0x20, %a0
        movea.l COPIE_FIN, %a1
1:      cmpa.l  %a1, %a0
        bhs.s   9f
        move.b  (%a0)+, %d0
        cmpi.b  #0x20, %d0
        bcs.s   2f
        cmpi.b  #0x7E, %d0
        bls.s   1b
2:      move.b  #1, F_GRAND(%a6)
9:      rts

| THE LINES OF THE CARTRIDGE SETTINGS (kinds 0 to 3), from block %a3 (non-zero). %a2: the entry
| to fill, advanced; %d6: the number of lines, increased. Clobbers %d0-%d2, %a1.
_dip_table:
        lea     0x20(%a3), %a1
        moveq   #0, %d1                 | the two times, bytes $10 and $12
.Lt_temps:
        move.b  0x10(%a3,%d1.w), %d2
        lsl.w   #8, %d2
        move.b  0x11(%a3,%d1.w), %d2
        cmpi.w  #0xFFFF, %d2
        beq.s   1f                      | unused: neither line nor label
        clr.b   (%a2)
        move.b  %d1, 1(%a2)
        move.w  %d2, 4(%a2)
        bsr     .Lentree
1:      addq.w  #2, %d1
        cmpi.w  #4, %d1
        bcs.s   .Lt_temps
.Lt_comptes:                            | %d1 = 4 then 5: kinds 1 and 2
        move.b  0x10(%a3,%d1.w), %d2
        cmpi.b  #0xFF, %d2
        beq.s   1f
        move.b  %d1, %d0
        subq.b  #3, %d0
        move.b  %d0, (%a2)
        move.b  %d1, 1(%a2)
        move.b  %d2, 3(%a2)
        bsr     .Lentree
1:      addq.w  #1, %d1
        cmpi.w  #6, %d1
        bcs.s   .Lt_comptes
.Lt_choix:                              | %d1 = 6 to 15
        move.b  0x10(%a3,%d1.w), %d2
        moveq   #0x0F, %d0
        and.b   %d2, %d0                | the number of choices
        beq.s   1f                      | 0: ASSUMED, neither line nor label
        move.b  #3, (%a2)
        move.b  %d1, 1(%a2)
        move.b  %d0, 2(%a2)
        lsr.b   #4, %d2
        move.b  %d2, 3(%a2)
        bsr     .Lentree
        mulu    #12, %d0                | the labels of the choices
        adda.w  %d0, %a1
1:      addq.w  #1, %d1
        cmpi.w  #16, %d1
        bcs.s   .Lt_choix
        rts
.Ltable_fin:
        move.b  #17, (%a2)              | ABOUT, before CABINET SETTINGS
        clr.b   1(%a2)
        move.l  #.Ltxt_apropos, 6(%a2)
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        move.b  #11, (%a2)              | CABINET SETTINGS, before SCORE RESET
        clr.b   1(%a2)
        move.l  #.Ltxt_borne, 6(%a2)
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        move.b  #10, (%a2)              | SCORE RESET, before the card
        clr.b   1(%a2)
        move.l  #.Ltxt_scores, 6(%a2)
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        move.b  #9, (%a2)               | the memory card, before the mode
        clr.b   1(%a2)
        move.l  #.Ltxt_carte, 6(%a2)
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        move.b  #8, (%a2)               | the mode, before the self-tests
        clr.b   1(%a2)
        move.l  #.Ltxt_mode, 6(%a2)
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        move.b  #6, (%a2)               | the self-tests, before the reset
        clr.b   1(%a2)
        move.l  #.Ltxt_tests, 6(%a2)
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        move.b  #7, (%a2)               | the jukebox, after the tests
        clr.b   1(%a2)
        move.l  #.Ltxt_jukebox, 6(%a2)
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        move.b  #4, (%a2)               | the reset to defaults, always the last
        clr.b   1(%a2)
        move.l  #.Ltxt_defaut, 6(%a2)
        addq.w  #1, %d6

        | THE VALUES RECEIVED, made valid.
        lea     T_ENTREE(%a4), %a2      | after the region
        move.w  %d6, %d7
        subi.w  #9 + 1, %d7             | the setting lines: region, ABOUT, cabinet,
                                        | scores, card, mode, tests, jukebox, reset excluded
        bmi.s   2f
1:      bsr     .Lnormaliser
        lea     T_ENTREE(%a2), %a2
        dbra    %d7, 1b
2:      bsr     .Linutilises

        | THE Z80 IN RAM, THEN THE BOARD'S FONT (see the header).
        moveq   #8-1, %d4
1:      bsr     .Lsync
        dbra    %d4, 1b
        | The echo is only read one frame after each send, like `menu.s` and `jukebox.s`: read
        | in the loop itself, a previous answer of the driver already at $01 would pass for it.
        moveq   #60-1, %d4
2:      move.b  #0x01, SOUND
        bsr     .Lsync
        cmpi.b  #0x01, SOUND
        dbeq    %d4, 2b
        bsr     .Lsync                  | one frame for the driver to enter its loop
        move.b  %d0, BRDFIX

        lea     VRAMRW, %a0
        moveq   #0, %d7                 | %d7: the chosen line
        bsr     .Lecran

        | THE STATE OF THE BUTTONS ON ENTRY: a button already held does not count.
        moveq   #0, %d5
        bsr     .Lentrees
        tst.b   CARTE_DEMANDE           | RESTART TO CARD: the manager at once, the mark consumed
        beq     .Lboucle
        clr.b   CARTE_DEMANDE
        move.w  %d6, %d7
        subq.w  #5, %d7                 | the MEMORY CARD line, "up" five times
        bsr     .Lch_carte
        bra     .Lboucle

| THE SCREEN, whole. Palettes after the passing of line $1F0, then all the text.
| Called on entry and on return from the self-tests. Clobbers %d0-%d4, %a1-%a3.
.Lecran:
        bsr     .Lsync
        move.b  %d0, PALBANK0           | bank 0, that of `ecran.s`
        move.w  #0x8000, PALETTES       | reference: "pure black ($8000)", "Palettes"
        move.w  #0x8000, FOND
        moveq   #0, %d1                 | palette 0, under FIX_CLEAR: entries 1-15 black
        moveq   #0, %d2                 | (see the header, THE DISPLAY)
        bsr     .Lpalette
        moveq   #1, %d1
        move.w  #C_TEXTE, %d2
        bsr     .Lpalette
        moveq   #2, %d1
        move.w  #C_CHOISI, %d2
        bsr     .Lpalette
        moveq   #3, %d1
        move.w  #C_TITRE, %d2
        bsr     .Lpalette
        moveq   #4, %d1
        move.w  #C_AIDE, %d2
        bsr     .Lpalette
        jsr     _fix_clear
        move.w  #32, VRAMMOD            | one write = one column

        move.w  #CASE_TITRE, %d1        | the title in 8×16
        bsr     .Ltitre
        move.w  #0x3100, %d3
        bsr     .Lecrire
        move.w  #CASE_TITRE + 1, %d1
        bsr     .Ltitre
        move.w  #0x3200, %d3
        bsr     .Lecrire
        move.w  #CASE_NOM, %d1          | the game's name, bytes $00-$0F of the block
        lea     .Ltxt_sans, %a2
        move.l  F_SOFTDIP(%a6), %d0
        beq.s   1f
        movea.l %d0, %a2
1:      moveq   #16, %d4
        move.w  #0x3000, %d3
        bsr     .Lecrire
        move.w  #CASE_AIDE1, %d1
        lea     .Ltxt_aide1, %a2
        moveq   #L_AIDE1, %d4
        move.w  #0x4000, %d3
        bsr     .Lecrire
        move.w  #CASE_AIDE2, %d1
        lea     .Ltxt_aide2, %a2
        moveq   #L_AIDE2, %d4
        tst.b   F_SOUS(%a6)
        beq.s   1f
        lea     .Ltxt_aide2_b, %a2
        moveq   #L_AIDE2_B, %d4
1:      move.w  #0x4000, %d3
        bsr     .Lecrire
        bra     .Ltout

| THE TITLE, %a2 and %d4: that of the list, or CABINET SETTINGS in the sub-screen.
.Ltitre:
        lea     .Ltxt_titre, %a2
        moveq   #L_TITRE, %d4
        tst.b   F_SOUS(%a6)
        beq.s   1f
        lea     .Ltxt_borne, %a2
        moveq   #L_BORNE, %d4
1:      rts

| ----------------------------------------------------------------------------------
| THE LOOP, one frame per round. A single action per frame, START first.
.Lboucle:
        bsr     .Lsync
        bsr     .Lentrees
        btst    #5, %d0
        bne     .Lstart
        btst    #0, %d0                 | up
        beq.s   2f
        move.w  %d7, %d0
        subq.w  #1, %d7
        bpl.s   1f
        move.w  %d6, %d7
        subq.w  #1, %d7
1:      bsr     .Lligne                 | the old line, then the new one
        move.w  %d7, %d0
        bsr     .Lligne
        bra.s   .Lboucle
2:      btst    #1, %d0                 | down
        beq.s   2f
        move.w  %d7, %d0
        addq.w  #1, %d7
        cmp.w   %d6, %d7
        bcs.s   1b
        moveq   #0, %d7
        bra.s   1b
2:      moveq   #1, %d2                 | right
        btst    #3, %d0
        bne.s   3f
        moveq   #-1, %d2                | left
        btst    #2, %d0
        bne.s   3f
        moveq   #2, %d2                 | A
        btst    #4, %d0
        beq.s   .Lboucle
3:      bsr     .Lchanger
        bra.s   .Lboucle

| START: in the sub-screen, the return to the list, on the CABINET SETTINGS line; otherwise the exit.
.Lstart:
        tst.b   F_SOUS(%a6)
        beq.s   .Lsortie
        clr.b   F_SOUS(%a6)
        move.b  F_GRAND0(%a6), F_GRAND(%a6)
        lea     F_TABLE(%a6), %a4
        move.w  F_SV_D6(%a6), %d6
        move.w  F_SV_D7(%a6), %d7
        bsr     .Lecran
        bsr     .Lentrees               | START still held does not count
        bra     .Lboucle

| ----------------------------------------------------------------------------------
| THE EXIT: GAME_DIP into the block, the screen returned, the cartridge put back under the Z80.
| Switch 1 still at ON: the warning first (see the header).
.Lsortie:
        btst    #0, DIPSW               | "Setting Mode": bit 0 at 0, ON
        bne.s   1f
        bsr     .Lavertir
1:
        movea.l F_BLOC(%a6), %a2
        movea.l %a5, %a1
        move.l  (%a1)+, (%a2)+          | GAME_DIP → save block, 16 bytes
        move.l  (%a1)+, (%a2)+
        move.l  (%a1)+, (%a2)+
        move.l  (%a1)+, (%a2)+
        lea     COPIE_FIN, %a2          | the copy cleared: these variables at zero, like the boot
        move.w  #(COPIE_LIM - COPIE_FIN) / 4 - 1, %d4
1:      clr.l   (%a2)+
        dbra    %d4, 1b
        bsr     .Lsync
        moveq   #0, %d4                 | palette 0 included
1:      move.w  %d4, %d1
        moveq   #0, %d2
        bsr     .Lpalette
        addq.w  #1, %d4
        cmpi.w  #4, %d4
        bls.s   1b
        clr.w   FOND                    | the reference stays at $8000
        jsr     _fix_clear              | REG_VRAMMOD left at 1
        move.b  %d0, CRTFIX             | the cartridge's S ROM and M1
        move.b  #0x03, SOUND            | Z80 reset, on the cartridge's M1
        move.b  %d0, WATCHDOG

        | THE REGION OR THE MODE HAS CHANGED: it is saved, then the machine restarts. The games
        | read the region at their init (record quoted by `c0.s`), and the boot derives from it the
        | soft-DIP pointer and CARD_REGION: only a full boot brings them back into agreement.
        | THE RESTART BY THE WATCHDOG, not by a jump to the reset vector. Read in
        | "Watchdog": without a kick, it "resets the whole system", after
        | about 8 frames. A `jmp` to $C00402 would only redo the 68000 and would leave
        | REG_CRTFIX, the palette bank and the sound driver in the editor's state.
        | ASSUMED: that "whole system" covers the Z80 and these switches. Measured (jig
        | `bench/editeur.lua`, aof and kof98, 2026-10-20): START on frame 300, RESET at 309, then the
        | boot screen and BIOS_COUNTRY_CODE set from the next boot. Backup RAM relocked before;
        | IRQs masked.
        | THE GAME'S ENTRY BECOMES FREE AGAIN (%a3 on entry, `c0.s`; index $FFFF, its
        | convention), whether it has just been registered or was before. The next boot
        | registers it again like a first boot: request 0, and the default soft-DIPs of the block
        | of the new region. Otherwise it would read back GAME_DIP decoded under the old region,
        | of which a choice can fall outside the bounds of the new block. What it costs: the
        | chosen soft-DIPs are lost, and request 0 reinitialises the data that the game
        | keeps in backup RAM ("USER subroutine", quoted by `c0.s`). Measured on kof98
        | (same jig): without this line, hand-over in request 2 after the restart; with it, its
        | request 0 comes back (its voluntary reset on frame 501).
        | THE MODE, by the same path, the game's entry kept (see the header).
        | SCORE RESET CHANGED: saved, with the date read now, without restart.
        move.b  F_SCORES(%a6), %d0
        cmp.b   F_SCORES0(%a6), %d0
        beq.s   6f
        jsr     _read_calendar          | registers returned; $10FDD2-$10FDD5: the date
        move.b  F_SCORES(%a6), %d0
        jsr     _reglages_ecrire_scores
        | THE CABINET SETTINGS CHANGED: saved, without restart, and their copy in RAM set again
        | (`reglages.s`).
6:      move.b  F_BORNE(%a6), %d0
        cmp.b   F_BORNE0(%a6), %d0
        beq.s   7f
        jsr     _reglages_ecrire_borne
        jsr     _borne_ram
        | THE DEBUG DIPS (`debug.s`): set in the game's area, or forgotten under CHEATS/DEBUG OFF.
7:      jsr     _dd_poser               | registers returned
        moveq   #0, %d4                 | nothing saved
        move.b  F_REGION(%a6), %d0
        cmp.b   F_REGION0(%a6), %d0
        beq.s   3f
        movea.l F_INSCRIT(%a6), %a2
        move.w  #0xFFFF, (%a2)
        jsr     _reglages_ecrire_region
        moveq   #1, %d4
3:      move.b  F_MODE(%a6), %d0
        cmp.b   F_MODE0(%a6), %d0
        beq.s   4f
        tst.b   F_NOUVEAU(%a6)
        beq.s   5f                      | a known game: its entry stays
        movea.l F_INSCRIT(%a6), %a2
        move.w  #0xFFFF, (%a2)
5:      move.b  F_MODE(%a6), %d0
        addq.b  #1, %d0                 | 1 MVS, 2 AES (`reglages.s`)
        jsr     _reglages_ecrire_mode
        moveq   #1, %d4
4:      tst.b   %d4
        beq.s   1f
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
2:      bra.s   2b                      | without a kick: the watchdog bites
1:      unlk    %a6
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rts

| ----------------------------------------------------------------------------------
| THE SOFT-DIP BLOCK COPIED INTO RAM (see the header, THE COPY), while REG_CRTFIX holds: the name
| and all the labels, from %a3 to %a1 (the end that `_dip_table` leaves), without going beyond the
| block's area or the copy. Then the table's labels (%a4 to %a2, kinds 0 to 3) and the block
| (F_SOFTDIP, %a3) point to the copy. Clobbers %d0-%d2, %a0, %a1.
.Lcopier_bloc:
        move.l  %a1, %d1
        sub.l   %a3, %d1                | the size: $20 + 12 × labels
        move.l  #0x100000, %d2          | the end of the block's area
        cmpa.l  %d2, %a3
        blo.s   1f
        move.l  #0x300000, %d2
1:      sub.l   %a3, %d2
        cmp.l   %d2, %d1
        bls.s   1f
        move.l  %d2, %d1                | not beyond its area
1:      cmpi.l  #COPIE_LIM - COPIE, %d1
        bls.s   1f
        move.l  #COPIE_LIM - COPIE, %d1 | not beyond the copy
1:      lea     COPIE, %a0
        movea.l %a3, %a1
        move.l  %a0, %d0
        add.l   %d1, %d0
        move.l  %d0, COPIE_FIN
        subq.w  #1, %d1
2:      move.b  (%a1)+, (%a0)+
        dbra    %d1, 2b
        move.l  #COPIE, %d0
        sub.l   %a3, %d0                | from the P-ROM to the copy
        movea.l %a4, %a0
3:      cmpa.l  %a2, %a0
        bhs.s   5f
        cmpi.b  #3, (%a0)
        bhi.s   4f                      | the region: a BIOS string
        add.l   %d0, 6(%a0)
4:      lea     T_ENTREE(%a0), %a0
        bra.s   3b
5:      lea     COPIE, %a3
        move.l  %a3, F_SOFTDIP(%a6)
        rts

| ----------------------------------------------------------------------------------
| A TABLE ENTRY: its label, %a1, then on to the next. Advances %a2 and %d6.
.Lentree:
        move.l  %a1, 6(%a2)
        lea     12(%a1), %a1
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        rts

| THE BUTTONS. %d5: the state of the frame before, updated; %d0: the edges.
| Bits: 0 up, 1 down, 2 left, 3 right, 4 A, 5 START. Clobbers %d1, %d2.
.Lentrees:
        jsr     _panneau_p1             | %d0: P1, controller or translated panel (`panneau.s`)
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

| THE ENTRY OF LINE %d0 in %a2.
.Ladresse:
        move.w  %d0, %d1
        mulu    #T_ENTREE, %d1
        lea     (%a4,%d1.w), %a2
        rts

| ----------------------------------------------------------------------------------
| CHANGE THE VALUE OF THE CHOSEN LINE. %d2: +1 right, -1 left, 2 A (next,
| wrapping). Then the line is rewritten. Clobbers %d0-%d4, %a2.
.Lchanger:
        move.w  %d7, %d0
        bsr.s   .Ladresse
        move.b  (%a2), %d0
        cmpi.b  #4, %d0
        beq     .Ldefauts
        cmpi.b  #5, %d0
        beq     .Lch_region
        cmpi.b  #6, %d0
        beq     .Lch_tests
        cmpi.b  #7, %d0
        beq     .Lch_jukebox
        cmpi.b  #8, %d0
        beq     .Lch_mode
        cmpi.b  #9, %d0
        beq     .Lch_carte
        cmpi.b  #10, %d0
        beq     .Lch_scores
        cmpi.b  #11, %d0
        beq     .Lch_borne
        cmpi.b  #16, %d0
        beq     .Lch_debug
        cmpi.b  #17, %d0
        beq     .Lch_apropos
        cmpi.b  #12, %d0
        bcc     .Lch_bval
        bsr.s   _dip_pas_valeur
        bra     .Lch_fin

| A STEP ON THE VALUE OF A CARTRIDGE SETTING (kinds 0 to 3), entry %a2, in GAME_DIP
| (%a5). %d2: +1, -1, or 2 (A: the next, wrapping). Clobbers %d0-%d4.
_dip_pas_valeur:
        moveq   #0, %d1
        move.b  1(%a2), %d1             | the GAME_DIP byte
        tst.b   (%a2)
        beq.s   .Lch_temps
        bsr     .Lbornes                | %d3 min, %d4 max
        moveq   #0, %d0
        move.b  (%a5,%d1.w), %d0
        bsr     .Lpas
        move.b  %d0, (%a5,%d1.w)
        rts
.Lch_temps:
        | In seconds: minutes × 60 + seconds, bounded to 0-1799 (29:59).
        move.w  %d2, -(%sp)             | the direction, which `.Lbcd_bin` overwrites
        move.w  (%a5,%d1.w), %d4
        move.w  %d4, %d0
        lsr.w   #8, %d0
        bsr     .Lbcd_bin
        mulu    #60, %d0
        move.w  %d0, %d3
        move.w  %d4, %d0
        andi.w  #0xFF, %d0
        bsr     .Lbcd_bin
        add.w   %d3, %d0
        moveq   #0, %d3
        move.w  #1799, %d4
        move.w  (%sp)+, %d2
        bsr     .Lpas
        andi.l  #0xFFFF, %d0
        divu    #60, %d0               | minutes in the low word, seconds in the high
        move.w  %d0, %d3
        bsr     .Lbin_bcd
        move.b  %d3, %d4
        lsl.w   #8, %d4
        swap    %d0
        move.w  %d0, %d3
        bsr     .Lbin_bcd
        move.b  %d3, %d4
        move.w  %d4, (%a5,%d1.w)
        rts
.Lch_region:                            | 0 Japan, 1 USA, 2 Europe
        moveq   #0, %d0
        move.b  F_REGION(%a6), %d0
        moveq   #0, %d3
        moveq   #2, %d4
        bsr.s   .Lpas
        move.b  %d0, F_REGION(%a6)
        bra.s   .Lch_fin
.Lch_mode:                              | 0 MVS, 1 AES
        moveq   #0, %d0
        move.b  F_MODE(%a6), %d0
        moveq   #0, %d3
        moveq   #1, %d4
        bsr.s   .Lpas
        move.b  %d0, F_MODE(%a6)
        bra.s   .Lch_fin
.Lch_scores:                            | 0 ON, 1 OFF
        moveq   #0, %d0
        move.b  F_SCORES(%a6), %d0
        moveq   #0, %d3
        moveq   #1, %d4
        bsr.s   .Lpas
        move.b  %d0, F_SCORES(%a6)
.Lch_fin:
        move.w  %d7, %d0
        bra     .Lligne
.Lch_tests:
        jsr     _autotests              | registers returned
        bra.s   1f
.Lch_jukebox:
        movea.l F_SOFTDIP(%a6), %a1     | the game's name; registers returned
        jsr     _jukebox
        bra.s   1f
.Lch_carte:
        jsr     _gestion_carte          | registers returned
        bra.s   1f
.Lch_apropos:
        jsr     _a_propos               | registers returned
        bra.s   1f
.Lch_debug:                             | CHEATS/DEBUG OFF (displayed): the line does not open
        btst    #3, F_BORNE(%a6)
        bne     .Lch_fin
        jsr     _debug_dips             | registers returned
1:      bsr     .Lecran
        bra     .Lentrees               | a button still held (START) does not count

| A STEP. %d0: the value; %d2: the direction; %d3, %d4: the bounds. Result in %d0.
.Lpas:
        cmpi.w  #2, %d2
        beq.s   2f
        add.w   %d2, %d0
        cmp.w   %d3, %d0
        bge.s   1f
        move.w  %d3, %d0
1:      cmp.w   %d4, %d0
        ble.s   3f
        move.w  %d4, %d0
3:      rts
2:      addq.w  #1, %d0                 | A: the next, then the minimum
        cmp.w   %d4, %d0
        ble.s   3b
        move.w  %d3, %d0
        rts

| THE CABINET SETTINGS SUB-SCREEN: the list kept (%d6, %d7), the table of the five lines, the screen.
.Lch_borne:
        move.w  %d6, F_SV_D6(%a6)
        move.w  %d7, F_SV_D7(%a6)
        move.b  #1, F_SOUS(%a6)
        move.b  F_GRAND(%a6), F_GRAND0(%a6)
        clr.b   F_GRAND(%a6)            | the sub-screen stays in 8×8: BIOS text
        lea     F_TABLE_B(%a6), %a4
        movea.l %a4, %a2
        moveq   #12, %d0
        lea     .Ltxt_libre, %a1        | five labels of 12 characters, in a row
2:      move.b  %d0, (%a2)
        clr.b   1(%a2)
        move.l  %a1, 6(%a2)
        lea     12(%a1), %a1
        lea     T_ENTREE(%a2), %a2
        addq.b  #1, %d0
        cmpi.b  #17, %d0
        bcs.s   2b
        moveq   #5, %d6
        moveq   #0, %d7
        bsr     .Lecran
        bra     .Lentrees
| A CABINET SETTINGS VALUE (kinds 12 to 15): bit kind - 12 of F_BORNE, bounded to 0-1 by `.Lpas`.
| The MODE line at AES: nothing changes (MVS ONLY), except CHEATS/DEBUG, which holds in both modes.
| FREE PLAY under board switch 7 at ON: nothing changes either, the value says DIP
| (`.Lv_borne`); the saved bit stays what it was.
.Lch_bval:
        cmpi.b  #15, %d0
        beq.s   1f
        cmpi.b  #1, F_MODE(%a6)
        beq     .Lch_fin
        cmpi.b  #12, %d0
        bne.s   1f
        btst    #6, DIPSW               | "Freeplay", bit 6 at 0: ON
        beq     .Lch_fin
1:      moveq   #0, %d1
        move.b  %d0, %d1
        subi.w  #12, %d1                | the bit
        moveq   #0, %d0
        btst    %d1, F_BORNE(%a6)
        beq.s   2f
        moveq   #1, %d0
2:      moveq   #0, %d3
        moveq   #1, %d4
        bsr     .Lpas
        bclr    %d1, F_BORNE(%a6)
        tst.w   %d0
        beq.s   3f
        bset    %d1, F_BORNE(%a6)
3:      cmpi.w  #3, %d1                 | CHEATS/DEBUG: the DEBUG DIPS line changes with it
        bne     .Lch_fin
        bra     .Ltout

| THE CARTRIDGE'S DEFAULTS, on all lines, then everything is rewritten.
.Ldefauts:
        bsr.s   _dip_defauts
        bra     .Ltout

| THE CARTRIDGE'S DEFAULTS on the %d6 entries of table %a4: only kinds 0 to 3
| (the settings) are touched. Clobbers %d0-%d4, %a2.
_dip_defauts:
        movea.l %a4, %a2
        move.w  %d6, %d4
        subq.w  #1, %d4
        bmi.s   3f
1:      cmpi.b  #4, (%a2)               | neither the reset, nor the region, nor the tests…
        bcc.s   5f
        moveq   #0, %d1
        move.b  1(%a2), %d1
        tst.b   (%a2)
        bne.s   2f
        move.w  4(%a2), (%a5,%d1.w)
        bra.s   4f
2:      move.b  3(%a2), (%a5,%d1.w)
4:      move.w  %d4, -(%sp)
        bsr     .Lnormaliser            | an invalid default falls to the minimum
        move.w  (%sp)+, %d4
5:      lea     T_ENTREE(%a2), %a2
        dbra    %d4, 1b
3:      rts

| ----------------------------------------------------------------------------------
| THE VALIDATION OF GAME_DIP ON READ-BACK (`_relire_dip`, `c0.s`), 2026-10-27 (DECISIONS
| §23 pt 5, user's decision). The editor's rules, without its table: a
| setting that the cartridge declares unused takes the value it declares (`.Linutilises`);
| a time outside the BCD from 00:00 to 29:59, a count outside 1-99, a number of times outside 0-100,
| a choice outside 0 to number - 1 takes the cartridge's default if it is valid, otherwise the
| minimum (`.Lnormaliser`). A valid value is not touched: a block that the editor or
| the registration wrote comes out as is. Read under REG_CRTFIX, which the slot switch has just
| set. Nothing if the block pointer is refused, nor if it is in the banked area: the bank in
| place is only certain at the first boot (`c0.s`, THE BANK IN PLACE), and validating against
| another bank would reset correct values to defaults. GAME_DIP only: the backup RAM block
| keeps its bytes until the editor's next START. Registers returned.
        .global _dip_valider
_dip_valider:
        movem.l %d0-%d5/%a0-%a3, -(%sp)
        bsr     _dip_bloc               | %a3; clobbers %d4, %a2
        move.l  %a3, %d0
        beq     9f
        cmpa.l  #0x100000, %a3
        bcc     9f                      | banked area: no validation
        lea     0x10(%a3), %a0          | bytes $10-$1F of the cartridge's block
        lea     GAME_DIP, %a1
        moveq   #0, %d1                 | the two times, bytes 0 and 2
1:      move.b  (%a0,%d1.w), %d2
        lsl.w   #8, %d2
        move.b  1(%a0,%d1.w), %d2       | the cartridge's time
        cmpi.w  #0xFFFF, %d2
        beq.s   2f                      | unused: $FFFF
        move.w  %d2, %d5
        move.w  (%a1,%d1.w), %d2
        bsr     .Ltemps_valide
        beq.s   3f                      | valid: kept
        move.w  %d5, %d2
        bsr     .Ltemps_valide
        beq.s   2f                      | the default
        moveq   #0, %d2                 | 00:00
2:      move.w  %d2, (%a1,%d1.w)
3:      addq.w  #2, %d1
        cmpi.w  #4, %d1
        bcs.s   1b
4:      move.b  (%a0,%d1.w), %d2        | the count (byte 4), the number of times (byte 5)
        cmpi.b  #0xFF, %d2
        beq.s   6f                      | unused: $FF
        moveq   #1, %d3
        moveq   #99, %d4
        cmpi.w  #5, %d1
        bne.s   5f
        moveq   #0, %d3
        moveq   #100, %d4
5:      move.b  (%a1,%d1.w), %d0
        cmp.b   %d3, %d0
        bcs.s   51f
        cmp.b   %d4, %d0
        bls.s   7f                      | valid: kept
51:     cmp.b   %d3, %d2
        bcs.s   52f
        cmp.b   %d4, %d2
        bls.s   6f                      | the default
52:     move.b  %d3, %d2                | the minimum
6:      move.b  %d2, (%a1,%d1.w)
7:      addq.w  #1, %d1
        cmpi.w  #6, %d1
        bcs.s   4b
8:      move.b  (%a0,%d1.w), %d2        | the ten choices, bytes 6 to 15
        moveq   #0x0F, %d4
        and.b   %d2, %d4                | the number of choices
        lsr.b   #4, %d2                 | the default
        tst.b   %d4
        beq.s   10f                     | no choice: the registration's value
        cmp.b   (%a1,%d1.w), %d4
        bhi.s   11f                     | valid: kept
        cmp.b   %d2, %d4
        bhi.s   10f                     | the default
        moveq   #0, %d2
10:     move.b  %d2, (%a1,%d1.w)
11:     addq.w  #1, %d1
        cmpi.w  #16, %d1
        bcs.s   8b
9:      movem.l (%sp)+, %d0-%d5/%a0-%a3
        rts

| ----------------------------------------------------------------------------------
| THE UNUSED SETTINGS, reset to what the cartridge declares (DECISIONS §23): a time
| $FFFF, a count $FF, a choice setting without choices (low nibble zero) take in GAME_DIP the
| value that `_slot_inscrit` (`c0.s`) writes there at registration — the word or the byte as is,
| the high nibble for a choice. No line shows them and `.Lnormaliser` does not see them: without
| this, an entry never initialised (a backup RAM left by another game, another BIOS)
| kept its bytes in the block saved on START (measured, scene `dip-vierge`). Read in the
| copy; nothing without a block. Clobbers %d0-%d2, %a0.
.Linutilises:
        tst.l   F_SOFTDIP(%a6)
        beq.s   9f
        lea     COPIE + 0x10, %a0
        moveq   #0, %d1                 | the two times, bytes 0 and 2
1:      cmpi.b  #0xFF, (%a0,%d1.w)
        bne.s   2f
        cmpi.b  #0xFF, 1(%a0,%d1.w)
        bne.s   2f
        move.w  #0xFFFF, (%a5,%d1.w)
2:      addq.w  #2, %d1
        cmpi.w  #4, %d1
        bcs.s   1b
3:      cmpi.b  #0xFF, (%a0,%d1.w)      | the two counts, bytes 4 and 5
        bne.s   4f
        move.b  #0xFF, (%a5,%d1.w)
4:      addq.w  #1, %d1
        cmpi.w  #6, %d1
        bcs.s   3b
5:      move.b  (%a0,%d1.w), %d2        | the ten choices, bytes 6 to 15
        moveq   #0x0F, %d0
        and.b   %d2, %d0
        bne.s   6f
        lsr.b   #4, %d2
        move.b  %d2, (%a5,%d1.w)
6:      addq.w  #1, %d1
        cmpi.w  #16, %d1
        bcs.s   5b
9:      rts

| ----------------------------------------------------------------------------------
| A VALUE MADE VALID, that of entry %a2. Clobbers %d0-%d4.
.Lnormaliser:
        moveq   #0, %d1
        move.b  1(%a2), %d1
        tst.b   (%a2)
        bne.s   .Ln_octet
        move.w  (%a5,%d1.w), %d2
        bsr.s   .Ltemps_valide
        beq.s   9f
        move.w  4(%a2), %d2
        bsr.s   .Ltemps_valide
        beq.s   1f
        moveq   #0, %d2                 | 00:00
1:      move.w  %d2, (%a5,%d1.w)
9:      rts
.Ln_octet:
        bsr.s   .Lbornes
        moveq   #0, %d2
        move.b  (%a5,%d1.w), %d2
        cmp.w   %d3, %d2
        bcs.s   1f
        cmp.w   %d4, %d2
        bls.s   9b
1:      moveq   #0, %d2
        move.b  3(%a2), %d2             | the cartridge's default
        cmp.w   %d3, %d2
        bcs.s   2f
        cmp.w   %d4, %d2
        bls.s   3f
2:      move.w  %d3, %d2                | the minimum
3:      move.b  %d2, (%a5,%d1.w)
        rts

| A TIME IN BCD, %d2.w: Z at 1 if it is valid (00:00 to 29:59). Clobbers %d0.
.Ltemps_valide:
        cmpi.w  #0x2959, %d2
        bhi.s   1f
        move.w  %d2, %d0
        andi.w  #0x000F, %d0
        cmpi.w  #9, %d0
        bhi.s   1f
        move.w  %d2, %d0
        andi.w  #0x00F0, %d0
        cmpi.w  #0x50, %d0
        bhi.s   1f
        move.w  %d2, %d0
        andi.w  #0x0F00, %d0
        cmpi.w  #0x0900, %d0
        bhi.s   1f
        moveq   #0, %d0                 | Z = 1
        rts
1:      moveq   #1, %d0                 | Z = 0
        rts

| THE BOUNDS of an entry of kind 1 to 3 (%a2): %d3 min, %d4 max. Read in "Software
| DIPs": count 1 to 99, number of times 0 to 100, choice 0 to number - 1.
.Lbornes:
        moveq   #0, %d3
        moveq   #100, %d4
        cmpi.b  #2, (%a2)
        beq.s   1f
        bhi.s   2f
        moveq   #1, %d3
        moveq   #99, %d4
        rts
2:      moveq   #0, %d4
        move.b  2(%a2), %d4
        subq.w  #1, %d4
1:      rts

| BCD → binary, %d0.w (a valid BCD byte) → %d0.w. Clobbers %d2.
.Lbcd_bin:
        move.w  %d0, %d2
        lsr.w   #4, %d2
        mulu    #10, %d2
        andi.w  #0x0F, %d0
        add.w   %d2, %d0
        rts

| Binary → BCD, %d3.w (0 to 99) → %d3.b. Clobbers %d2.
.Lbin_bcd:
        andi.l  #0xFFFF, %d3
        divu    #10, %d3
        move.w  %d3, %d2
        lsl.w   #4, %d2
        swap    %d3
        or.w    %d2, %d3
        rts

| ----------------------------------------------------------------------------------
| ALL THE LINES of the list. Clobbers %d0-%d4, %a1, %a2.
.Ltout:
        moveq   #0, %d0
1:      move.w  %d0, -(%sp)
        bsr.s   .Lligne
        move.w  (%sp)+, %d0
        addq.w  #1, %d0
        cmp.w   %d6, %d0
        bcs.s   1b
        rts

| LINE %d0: cursor, label, value, composed in the buffer then written under
| palette 2 if it is chosen, 1 otherwise. Clobbers %d0-%d4, %a1, %a2.
| The 8×16 list: the window of FENETRE entries first realigned on the chosen line, %d7;
| if it moves, the whole list is rewritten; a line outside the window is not written.
.Lligne:
        tst.b   F_GRAND(%a6)
        beq.s   .Lligne8
        move.w  F_HAUT(%a6), %d1
        cmp.w   %d1, %d7
        bcc.s   1f
        move.w  %d7, %d1                | above the window
        bra.s   2f
1:      move.w  %d1, %d2
        addi.w  #FENETRE, %d2
        cmp.w   %d2, %d7
        bcs.s   3f
        move.w  %d7, %d1                | below
        subi.w  #FENETRE - 1, %d1
2:      move.w  %d1, F_HAUT(%a6)
        bra     .Ltout
3:      cmp.w   %d1, %d0
        bcs.s   9f                      | outside the window
        cmp.w   %d2, %d0
        bcs.s   .Lligne8
9:      rts
.Lligne8:
        lea     F_TAMPON(%a6), %a1
        moveq   #LARGEUR - 1, %d1
1:      move.b  #0x20, (%a1)+
        dbra    %d1, 1b
        lea     F_TAMPON(%a6), %a1
        move.w  #0x1000, %d3
        cmp.w   %d7, %d0
        bne.s   1f
        move.b  #0x3E, (%a1)            | ">"
        move.w  #0x2000, %d3
1:      move.w  %d3, -(%sp)
        move.w  %d0, -(%sp)
        bsr     .Ladresse
        addq.l  #2, %a1
        moveq   #12, %d4                | the label
        cmpi.b  #4, (%a2)
        bne.s   1f
        moveq   #L_DEFAUT, %d4
1:      cmpi.b  #6, (%a2)
        bne.s   1f
        moveq   #L_TESTS, %d4
1:      cmpi.b  #7, (%a2)
        bne.s   1f
        moveq   #L_JUKEBOX, %d4
1:      cmpi.b  #9, (%a2)
        bne.s   1f
        moveq   #L_CARTE, %d4
1:      cmpi.b  #11, (%a2)
        bne.s   1f
        moveq   #L_BORNE, %d4
1:      cmpi.b  #17, (%a2)
        bne.s   1f
        moveq   #L_APROPOS, %d4
1:      movea.l 6(%a2), %a3             | %a3 is free once the screen is set
        bsr     .Lcopier
        lea     F_TAMPON + COL_VALEUR(%a6), %a1
        move.b  (%a2), %d0
        cmpi.b  #5, %d0
        beq.s   .Lv_region
        cmpi.b  #8, %d0
        beq.s   .Lv_mode
        cmpi.b  #10, %d0
        beq.s   .Lv_scores
        cmpi.b  #17, %d0                | ABOUT: no value
        beq     .Lv_fin
        cmpi.b  #12, %d0
        bcc     .Lv_borne
        bsr.s   _dip_valeur
        bra     .Lv_fin

| THE TEXT OF THE VALUE of a cartridge setting (kinds 0 to 3; the others: nothing), entry
| %a2, at (%a1)+. Clobbers %d0-%d4, %a3.
_dip_valeur:
        moveq   #0, %d1
        move.b  1(%a2), %d1
        moveq   #0, %d2
        move.b  (%a5,%d1.w), %d2
        move.b  (%a2), %d0
        beq     .Lv_temps
        subq.b  #2, %d0
        bcs.s   .Lv_nombre              | kind 1
        beq.s   .Lv_fois                | kind 2
        subq.b  #1, %d0
        bne.s   9f                      | kinds 4 and above: no value
        | Kind 3: the choice's label, at label + 12 × (choice + 1).
        addq.w  #1, %d2
        mulu    #12, %d2
        movea.l 6(%a2), %a3
        adda.l  %d2, %a3
        moveq   #12, %d4
        bra     .Lcopier
9:      rts
.Lv_region:                             | six characters per region
        moveq   #0, %d2
        move.b  F_REGION(%a6), %d2
        mulu    #6, %d2
        lea     .Ltxt_regions, %a3
        adda.w  %d2, %a3
        moveq   #6, %d4
        bsr     .Lcopier
        bra.s   .Lv_fin
.Lv_mode:                               | three characters per mode
        moveq   #0, %d2
        move.b  F_MODE(%a6), %d2
        mulu    #3, %d2
        lea     .Ltxt_modes, %a3
        adda.w  %d2, %a3
        moveq   #3, %d4
        bsr     .Lcopier
        bra.s   .Lv_fin
.Lv_scores:                             | three characters: ON, OFF
        moveq   #0, %d2
        move.b  F_SCORES(%a6), %d2
        mulu    #3, %d2
        lea     .Ltxt_on_off, %a3
        adda.w  %d2, %a3
        moveq   #3, %d4
        bsr     .Lcopier
        bra.s   .Lv_fin
.Lv_fois:
        | Read in "Software DIPs": 0 "WITHOUT", 100 "INFINITE".
        lea     .Ltxt_sans_fois, %a3
        moveq   #7, %d4
        tst.w   %d2
        beq.s   1f
        lea     .Ltxt_infini, %a3
        moveq   #8, %d4
        cmpi.w  #100, %d2
        bne.s   .Lv_nombre
1:      bra     .Lcopier
.Lv_nombre:
        bra     .Ldecimal
.Lv_temps:
        | MM:SS, two BCD bytes validated on entry.
        move.b  (%a5,%d1.w), %d2
        bsr     .Lbcd_ascii
        move.b  #0x3A, (%a1)+           | ":"
        move.b  1(%a5,%d1.w), %d2
        bra     .Lbcd_ascii
.Lv_fin:
        move.w  (%sp)+, %d1             | the line
        tst.b   F_GRAND(%a6)
        bne.s   .Lv_fin16
        addi.w  #CASE_LIGNE, %d1
        move.w  (%sp)+, %d3             | the palette
        lea     F_TAMPON(%a6), %a2
        moveq   #LARGEUR, %d4
        bra     .Lecrire
| In 8×16: two rows per entry, from row 7; the top at $100 + b, the bottom at
| $200 + b, or $300 / $400 + b (`.Lecrire16`).
.Lv_fin16:
        sub.w   F_HAUT(%a6), %d1
        add.w   %d1, %d1
        addi.w  #CASE_LIGNE, %d1
        move.w  (%sp)+, %d3             | the palette
        addi.w  #0x100, %d3
        lea     F_TAMPON(%a6), %a2
        moveq   #LARGEUR, %d4
        bsr     .Lecrire16
        addq.w  #1, %d1
        addi.w  #0x100, %d3
        lea     F_TAMPON(%a6), %a2
        moveq   #LARGEUR, %d4
        bra     .Lecrire16
.Lv_borne:                              | three characters, or MVS ONLY with the MODE line at AES
        cmpi.b  #16, %d0
        beq.s   .Lv_debug
        cmpi.b  #15, %d0
        beq.s   1f                      | CHEATS/DEBUG: in both modes
        cmpi.b  #1, F_MODE(%a6)
        bne.s   1f
        lea     .Ltxt_mvs_seul, %a3
        moveq   #L_MVS_SEUL, %d4
        bsr     .Lcopier
        bra     .Lv_fin
| FREE PLAY UNDER BOARD SWITCH 7 (REG_DIPSW bit 6 at 0): DIP, and locked
| (`.Lch_bval`). The switch suffices to put the cabinet in free play (`io.s`, `_io_libre`):
| OFF would be false, ON would hide where it comes from and would suggest it can be removed here.
| Read again on each write of the line: on opening the sub-screen and on each key.
1:      cmpi.b  #12, %d0
        bne.s   4f
        btst    #6, DIPSW
        bne.s   4f
        lea     .Ltxt_dip, %a3
        moveq   #3, %d4
        bsr     .Lcopier
        bra     .Lv_fin
4:      moveq   #0, %d2
        move.b  %d0, %d2
        subi.w  #12, %d2                | the bit
        moveq   #0, %d3
        btst    %d2, F_BORNE(%a6)
        beq.s   2f
        moveq   #1, %d3
2:      cmpi.w  #2, %d2                 | DEMO SOUND, CHEATS/DEBUG: bit at 1, OFF ("ON OFF")
        bcc.s   3f
        eori.w  #1, %d3                 | FREE PLAY, NO CONTINUE: bit at 1, ON
3:      mulu    #3, %d3
        lea     .Ltxt_on_off, %a3
        adda.w  %d3, %a3
        moveq   #3, %d4
        bsr     .Lcopier
        bra     .Lv_fin

| DEBUG DIPS: OFF under CHEATS/DEBUG OFF (displayed), otherwise the mask of `debug.s` in four
| hexadecimal digits, DIP 1 then DIP 2.
.Lv_debug:
        lea     .Ltxt_on_off + 3, %a3
        moveq   #3, %d4
        btst    #3, F_BORNE(%a6)
        bne.s   2f
        move.w  DD_MASQUE, %d2
        moveq   #4 - 1, %d4
1:      rol.w   #4, %d2
        moveq   #0x0F, %d3
        and.w   %d2, %d3
        addi.b  #0x30, %d3
        cmpi.b  #0x39, %d3
        bls.s   3f
        addq.b  #7, %d3
3:      move.b  %d3, (%a1)+
        dbra    %d4, 1b
        bra     .Lv_fin
2:      bsr     .Lcopier
        bra     .Lv_fin

| COPY %d4 bytes from %a3 to (%a1)+. A cartridge label that would not fit
| whole in $000000-$0FFFFF or in $200000-$2FFFFF is not copied: the cell stays
| blank. Likewise a label of the editor's RAM copy (`.Lcopier_bloc`) that would not fit
| whole before COPIE_FIN. Clobbers %d2, %d4, %a3.
_dip_copier:
.Lcopier:
        move.l  %a3, %d2
        cmpi.l  #0xC00000, %d2
        bcc.s   1f                      | a BIOS string
        cmpi.l  #0x200000, %d2
        bcc.s   4f
        addi.l  #12, %d2
        cmpi.l  #0x100000, %d2
        bls.s   1f                      | in the fixed P-ROM
        cmpa.l  #COPIE, %a3
        blo.s   2f                      | overflows the fixed P-ROM
        cmp.l   COPIE_FIN, %d2
        bhi.s   2f                      | overflows the copy
        bra.s   1f
4:      addi.l  #12, %d2
        cmpi.l  #0x300000, %d2
        bhi.s   2f                      | overflows the banked area, or beyond
1:      subq.w  #1, %d4
3:      move.b  (%a3)+, (%a1)+
        dbra    %d4, 3b
        rts
2:      adda.w  %d4, %a1
        rts

| A NUMBER, %d2.w from 0 to 999, in decimal without leading zero, at (%a1)+. Clobbers %d2-%d3.
.Ldecimal:
        moveq   #0, %d3                 | 1 as soon as a digit is output
        andi.l  #0xFFFF, %d2
        divu    #100, %d2
        tst.w   %d2
        beq.s   1f
        addi.b  #0x30, %d2
        move.b  %d2, (%a1)+
        moveq   #1, %d3
1:      clr.w   %d2
        swap    %d2
        divu    #10, %d2
        tst.w   %d3
        bne.s   2f
        tst.w   %d2
        beq.s   3f
2:      addi.b  #0x30, %d2
        move.b  %d2, (%a1)+
3:      swap    %d2
        addi.b  #0x30, %d2
        move.b  %d2, (%a1)+
        rts

| A BCD BYTE, %d2.b, as two digits at (%a1)+. Clobbers %d2, %d3.
.Lbcd_ascii:
        move.b  %d2, %d3
        lsr.b   #4, %d3
        addi.b  #0x30, %d3
        move.b  %d3, (%a1)+
        andi.b  #0x0F, %d2
        addi.b  #0x30, %d2
        move.b  %d2, (%a1)+
        rts

| ----------------------------------------------------------------------------------
| WRITE %d4 characters from %a2 starting at cell %d1, REG_VRAMMOD at 32: one line.
| %d3: palette << 12 + tile offset ($000 in 8×8, $100 / $200 in 8×16). Outside
| $20-$7E, a space. Timing ("VRAM"): between two data, the loop takes more than
| 12 cycles; after the last, `dbra` not taken (14) and `rts` (16) before any address.
| Clobbers %d2, %d4, %a2.
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

| WRITE IN 8×16, THE 8×16 LIST ONLY (see the header): like `.Lecrire`, %d3 carrying $100 (the
| top) or $200 (the bottom), without filter. A byte whose glyph is the same in both banks
| ($20-$5E, $61-$7B) stays at $100 / $200 + b; any other at $300 / $400 + b. Timing ("VRAM"):
| like `.Lecrire`, more than 12 cycles between two data; `dbra` not taken (14) and `rts` (16) before
| any address. Clobbers %d2, %d4, %a2; %d1 and %d3 returned.
.Lecrire16:
        move.w  %d1, VRAMADDR
        subq.w  #1, %d4
1:      moveq   #0, %d2
        move.b  (%a2)+, %d2
        cmpi.b  #0x20, %d2
        bcs.s   2f
        cmpi.b  #0x7C, %d2
        bcc.s   2f
        cmpi.b  #0x5F, %d2
        bcs.s   3f
        cmpi.b  #0x61, %d2
        bcc.s   3f
2:      addi.w  #0x200, %d2             | $300 / $400 + b
3:      add.w   %d3, %d2
        move.w  %d2, (%a0)
        dbra    %d4, 1b
        rts

| THE SWITCH 1 WARNING: the screen cleared, two lines, then AVERT_TRAMES frames or the
| switch toggled back to OFF, whichever comes first. Clobbers %d0-%d5, %a0, %a2.
        .equ    AVERT_TRAMES, 180       | ~3 s, a choice
.Lavertir:
        bsr     .Lsync
        jsr     _fix_clear              | %a0 on REG_VRAMRW
        move.w  #32, VRAMMOD
        move.w  #0x7000 + 11 * 32 + 13, %d1
        lea     .Ltxt_avert1, %a2
        moveq   #L_AVERT1, %d4
        move.w  #0x2000, %d3            | palette 2, the colour of the chosen line
        bsr     .Lecrire
        move.w  #0x7000 + 6 * 32 + 15, %d1
        lea     .Ltxt_avert2, %a2
        moveq   #L_AVERT2, %d4
        move.w  #0x1000, %d3
        bsr     .Lecrire
        move.w  #AVERT_TRAMES - 1, %d5
1:      bsr     .Lsync
        btst    #0, DIPSW
        dbne    %d5, 1b
        rts

| THE PASSING OF LINE $1F0, like `ecran.s` (measured, `2026-10-17-diagnostic-b2b-minasan.tsv`):
| we wait to leave it then to enter it, kick to the watchdog on each round. Clobbers %d0.
| BOUNDED to SYNC_TOURS rounds per wait, ≈ 2 frames, line seen or not: the count is in
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

| A PALETTE, like `ecran.s` but other registers (%d5 and %d6 hold the state):
| %d1 its number, %d2 the colour of entry 1, entries 2 to 15 at zero. Clobbers %d0,
| %d1, %a2.
.Lpalette:
        lea     PALETTES + 2, %a2
        lsl.w   #5, %d1
        adda.w  %d1, %a2
        move.w  %d2, (%a2)+
        moveq   #14-1, %d0
1:      clr.w   (%a2)+
        dbra    %d0, 1b
        rts

| ----------------------------------------------------------------------------------
| THE DATA.
        .balign 2
.Ltxt_titre:
        .ascii  "SOFT DIP SETTINGS"
        .equ    L_TITRE, . - .Ltxt_titre
.Ltxt_sans:
        .ascii  "NO SOFT DIP DATA"
.Ltxt_defaut:
        .ascii  "RESET TO DEFAULTS"
        .equ    L_DEFAUT, . - .Ltxt_defaut
.Ltxt_tests:
        .ascii  "HARDWARE TESTS"
        .equ    L_TESTS, . - .Ltxt_tests
.Ltxt_jukebox:
        .ascii  "JUKEBOX"
        .equ    L_JUKEBOX, . - .Ltxt_jukebox
.Ltxt_carte:
        .ascii  "MEMORY CARD"
        .equ    L_CARTE, . - .Ltxt_carte
.Ltxt_aide1:
        .ascii  "UP/DOWN:SELECT  LEFT/RIGHT/A:CHANGE"
        .equ    L_AIDE1, . - .Ltxt_aide1
.Ltxt_aide2:
        .ascii  "START:SAVE AND EXIT"
        .equ    L_AIDE2, . - .Ltxt_aide2
.Ltxt_aide2_b:
        .ascii  "START:BACK"
        .equ    L_AIDE2_B, . - .Ltxt_aide2_b
.Ltxt_borne:
        .ascii  "CABINET SETTINGS"
        .equ    L_BORNE, . - .Ltxt_borne
.Ltxt_apropos:
        .ascii  "ABOUT"
        .equ    L_APROPOS, . - .Ltxt_apropos
.Ltxt_libre:                            | the five labels of the sub-screen, 12 characters
        .ascii  "FREE PLAY   "
        .ascii  "NO CONTINUE "
        .ascii  "DEMO SOUND  "
        .ascii  "CHEATS/DEBUG"
        .ascii  "DEBUG DIPS  "
.Ltxt_mvs_seul:
        .ascii  "MVS ONLY"
        .equ    L_MVS_SEUL, . - .Ltxt_mvs_seul
.Ltxt_region:
        .ascii  "REGION      "          | 12 characters, like a cartridge label
.Ltxt_regions:
        .ascii  "JAPAN USA   EUROPE"    | 0, 1, 2 ("BIOS RAM locations")
.Ltxt_mode:
        .ascii  "MODE        "          | 12 characters, like REGION
.Ltxt_modes:
        .ascii  "MVSAES"                | 0, 1 (decision D7)
.Ltxt_scores:
        .ascii  "SCORE RESET "          | 12 characters, like REGION
.Ltxt_on_off:
        .ascii  "ON OFF"                | 0, 1
.Ltxt_dip:
        .ascii  "DIP"                   | FREE PLAY by the board switch
.Ltxt_avert1:
        .ascii  "DIP SWITCH 1 IS ON"
        .equ    L_AVERT1, . - .Ltxt_avert1
.Ltxt_avert2:
        .ascii  "SET IT OFF FOR A NORMAL BOOT"
        .equ    L_AVERT2, . - .Ltxt_avert2
.Ltxt_sans_fois:
        .ascii  "WITHOUT"
.Ltxt_infini:
        .ascii  "INFINITE"
        .balign 2
