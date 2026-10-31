| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| THE IN-GAME MENU — opened during play by holding the board's TEST button, it pauses the
| game then gives it back as it was. TEST opens the BIOS menus (`dip.s` at boot).
|
| NO ORACLE: neither the reference BIOS nor a third-party BIOS is read. The hand-over is
| "Couche 3 → le menu en jeu, le 2026-10-21" (`docs/RELECTURE-CONTRATS.md`).
| "measured": a named record (jig `bench/menu.lua` and lua probes of 2026-10-21, MAME
| 0.286, -bios euro, our image, 22 games of the corpus, ~3,600 frames each, coin and START
| scheduled like `bios-probe.lua`; records not versioned, handed to the main
| session); "read in": a page of the NeoGeo Development Wiki; "ASSUMED": neither one
| nor the other.
|
| THE HOOK. `_menu_en_jeu`, called by `jsr` from SYSTEM_IO (`io.s`) right after
| `_io_commun`, on every call. Without the gesture: a few instructions, no register
| touched. It starts with the cheat and freeze engine (`cheats.s`), which with no cheat or
| freeze active is a single test.
| MEASURED: the 22 games call SYSTEM_IO from their vblank handler (SR at the
| time of the call: IPL 1, or 7 for kof94, kof98, samsho2; only trally has calls at
| IPL 0, outside play). The menu therefore opens INSIDE the game's interrupt, and its main
| program is suspended somewhere — including in the middle of a queue of VRAM writes
| (see THE VRAM ADDRESS).
|
| THE GESTURE. TEST held SEUIL calls in a row, in play (BIOS_USER_MODE $10FDAF = 2, "BIOS
| RAM locations"). After closing, everything must be released before counting again. SEUIL:
| a choice (~1/3 s). TEST: REG_SYSTYPE ($300081) bit 7, active low (measured in `dip.s`).
| Measured (read taps, 22 games, 3,600 frames): only ridhero reads $300081 in play
| (3,199 reads); with TEST held, its RAM differs from a witness run by one byte ($100152), and
| no other game diverges (garou, measured under the SNK BIOS, does not read $300081). START +
| SELECT, the first gesture, had been ruled out: under MAME 0.286 the single-cartridge sets have
| no SELECT field. TAKEN UP AGAIN on 2026-10-25 IN ADDITION TO TEST, for a consolized MVS, which
| has no TEST button and whose pads have START and SELECT: P1's START and SELECT held together
| SEUIL calls in a row (REG_STATUS_B $380000 bits 0 and 1, active low). SELECT because no game
| sees it on MVS ("BIOS RAM locations": "On MVS the select bits are always read as 0"); measured
| (`measured/2026-10-25-dip-free-play.tsv`, section 5, SNK BIOS, MV-6F): SELECT held for one
| second in play changes no image on 154 of the 157 catalogue games played; kof94 and lastbld2
| are only shifted by one frame there, pbobblen does not repeat from one run to the next. The BIOS
| reads it only on the title with a credit (`io.s`, `_io_select`), the gesture only in play.
| START, for its part, goes to the game as usual (a game that pauses on START will see it under
| the menu). At rest, $380000 reads $FF under
| MAME on all MVS machines; ASSUMED on the hardware. THE CYCLES: without TEST, two
| more `btst` and one more branch per SYSTEM_IO call when START is not held (+30);
| measured with no effect on the run-through and on the catalogue matrix, on 2026-10-25.
| THE ADAPTER, since 2026-10-27: START + SELECT do not count if P1's A, B, C and D
| are ALL FOUR held (REG_P1CNT $300000 bits 4-7, active low); the count then restarts from
| zero. With one, two or three of them held, the gesture counts as if alone. OBSERVED on the
| hardware by the tester on 2026-10-26 (image no. 14, `docs/ESSAI-MATERIEL.md`): the BlueRetro
| adapter holds L/R, A, B, C, D, START and SELECT for about one second at start-up, and plugged
| in during play it opened the menu. "A-D released" is ruled out: a player who brushes A would
| see the gesture refused. TEST does not depend on it. $300000 is read only once START and
| SELECT are seen held: the gesture that counts costs 30 more cycles per call, the other paths
| nothing. DECISIONS §17 pt 5.
|
| THE SAVE AREA, $10F4C0-$10F7EB (the frame and the line being drawn) and $10F800-$10FAFF (the
| rest, and the stack). MEASURED free: write taps on $10F300-$10FFFF,
| 22 games, show no game write between $10F4B4 and $10FBFF (nam1975 writes
| $10F300-$10F4B3, four games $10FC00-$10FC69); our BIOS writes there only the boot
| clear (`c0.s`). The gesture counter is written there on every call.
|
| WHAT THE MENU TOUCHES, AND HOW IT GIVES IT BACK:
|   - SR (IRQs masked, $2700) and the 15 registers: saved, given back. The game's stack
|     receives only the `jsr` return address; the menu runs on its own stack, MN_PILE;
|   - REG_VRAMMOD: readable back ("Memory mapped registers": "Reads VRAM address
|     modulo"); saved, given back;
|   - THE VRAM ADDRESS: not readable back (same page: REG_VRAMADDR reads like REG_VRAMRW,
|     "address doesn't change"). Yet the game's program may be in the middle of a queue
|     of writes: MEASURED, 9 games out of 22 write REG_VRAMRW, on return from SYSTEM_IO,
|     without setting an address again (neomrdo 82 times in 3,600 frames, trally 93, lbowling 8…).
|     So we FIND IT AGAIN: write two probe pairs there in place of four words read,
|     sweep $0000-$87FF to see them, put the read words back, and set that address again
|     on exit (`.Lsonder`). One sweep, ~0.15 s. ASSUMED, the edges: A ≥ $8800 (a
|     mirror of $8000-$87FF, "VRAM") is found at its canonical address, set again as
|     is; A in $87FD-$87FF, the probes cross the edge of the sweep and failure follows. Measured
|     (jig, 11 closings on aof, mslug, kof98, neomrdo): found every time, equal to the one
|     MAME holds (item `m_vram_offset`), VRAM identical to the byte. ASSUMED: that
|     reading REG_VRAMRW returns the word at the current address even right after a
|     data write (the page says so only after an address write);
|   - the fix layer: only the cells of the frame (20 × 10 without cheats, 28 × (10 + V) with V
|     cheat lines, 28 × 14 for the sub-screens, 392 at most), read through
|     REG_VRAMRW before being written, given back afterwards;
|   - three palettes of the current bank, the ones the fix layer does not use
|     (`.Lchoisir_palettes`; failing that, used ones, the case of kof98 in the record): read,
|     given back ("Palettes": "can be read and written at full speed at any time"). The bank
|     is not changed: the page says of it "one usable at a time", so the one the CPU sees
|     is the game's; nothing to deduce. Written right after line $1F0 passes (the same
|     page: writing during display makes snow). During the pause, the game's sprites that
|     use these palettes take our colours;
|   - the Z80: NOTHING. Neither $01, nor REG_BRDFIX, nor REG_CRTFIX, nor $03: the game's driver
|     plays during the pause, as under UniBIOS (`measured/2026-10-23-unibios-menu-en-jeu.tsv`).
|     The former $03 restarted it without giving it back: in the middle of play, no more FM
|     key-on nor ADPCM-B, aof silent until the game's next $03, mslug 160 s at least; the $03
|     alone, without the menu, does the same, and replaying the game's commands does not repair
|     mslug (`measured/2026-10-23-menu-en-jeu-son.tsv`);
|   - the fix layer stays on the cartridge's S ROM: the game's HUD outside the frame keeps its
|     tiles. The text there is in ITS font: 0-9, A-Z, space, ": - / ." identical to the SFIX
|     on 20 games out of 22, trally legible (`measured/2026-10-21-police-cartouche.tsv`); ">"
|     legible by eye on mslug, aof, kof98, not measured. kof2003: its S ROM has no font,
|     the menu text is invisible there (deduced, not measured);
|   - the pending IRQs: on exit we wait for the line where the menu opened
|     (REG_LSPCMODE, `.Lsync`), then we acknowledge (REG_IRQACK, "68k interrupts": bit 2
|     vblank, bit 1 timer) the interrupts raised during the pause: always the vblank —
|     the one of the call is being serviced, another one pending is stale —, the timer
|     if the call let it through (IPL < 2). ASSUMED: that a timer pending under an IPL
|     ≥ 2 at the time of the call is not wrongly acknowledged by letting it through.
| NOT GIVEN BACK: the auto-animation counter and the LSPC timer, which run during the pause,
| and the music, which goes on. After resuming, the sound is that of the witness run (measured,
| FM key-on under menu / witness run: mslug 212/218, aof 363/361, kof98 78/87;
| `measured/2026-10-23-menu-en-jeu-son.tsv`).
|
| CHEATS/DEBUG OFF (CABINET SETTINGS of `dip.s`, bit 3 of BORNE_RAM, 2026-10-25): neither cheat
| line (`_cheats_trouver` no longer gives an entry) nor MEMORY EDITOR — its line stays blank, and
| the last choice is GAME SETTINGS: "up" from RESUME leads to it. The frame does not change size.
| THE CHOICES: RESUME, RESTART GAME, then one line per cheat of the game (`cheats.s`), its name
| and ON / OFF; A or START on a cheat line toggles its bit in CH_ETATS and the menu
| stays open. THE WINDOW, 2026-10-29: MN_VIS cheat lines at most (V), and the game's N cheats,
| up to CH_MAX, scroll through it behind the choice (`.Lfenetre`); beyond MN_VIS, the
| line under the title says which are shown ("CHEATS 5-8/12"). The choices do not change:
| cheat k is always at "down" k + 2 times from RESUME, and the lines after it up to N.
| THE CARD, 2026-10-31 (DECISIONS §33): one more line, RESTART TO CARD, just before AUTOFIRE, at
| "up" four times from RESUME (three under CHEATS/DEBUG OFF), so that no earlier key path moves. It
| restarts the machine like RESTART GAME, a mark left in backup RAM (CARTE_DEMANDE); `dip.s` reads
| the mark at boot and opens the card manager. The frame does not grow: the help takes the last
| blank line, line 9, and the save area stays that of 28 × 14. The mark's cell, $D001A8: read in
| "Backup RAM", undocumented; measured, no write on 21 games (`reglages.s`, header); ASSUMED for the
| rest of the catalogue.
| Then GAME SETTINGS (`reglages-jeu.s`) and MEMORY EDITOR (`memoire.s`),
| 2026-10-23, always there, AFTER the cheats: the key paths of the earlier records
| (RESTART at "down", the first cheat at "down, down") remain; from RESUME, "up" leads
| to MEMORY EDITOR, "up, up" to GAME SETTINGS, whatever the game. The frame without cheats
| is therefore no longer the one from before the cheats: two more lines.
| AUTOFIRE (`autofire.s`, 2026-10-27, DECISIONS §22): one more line, BETWEEN THE CHEATS
| AND GAME SETTINGS, at "up" three times from RESUME (two under CHEATS/DEBUG OFF): "down",
| "down, down" and "up", "up, up" lead where they led. The frame does not grow: the blank
| line under MEMORY EDITOR leaves it its place, and the help line stays where it was. The loop
| keeps its cycles, and GAME SETTINGS opens at the same cycles as before (`reglages-jeu.s`, THE
| CYCLES; see the choice, `.Lboucle`). AUTOFIRE stays under CHEATS/DEBUG OFF.
| THE SUB-SCREENS (GAME SETTINGS, MEMORY EDITOR, AUTOFIRE) take a fixed frame of SOUS_NCOL ×
| SOUS_NLIG cells, saved and given back like the menu's (`_mn_sous_ouvrir`, `_mn_sous_fermer`):
| the menu's frame is given back first, theirs saved next, then the reverse on return. Same
| palettes, same one-frame-per-turn loop, same buttons (`_mn_entrees`).
| RESTART GAME: the restart through the watchdog of `dip.s` (measured), IRQs masked.
| The display like `dip.s`: 8×8 glyphs = ASCII tile, stroke at index 1; tile $020
| is filled with index 2, under the S ROM too, 22 games out of 22, and the glyphs there have only
| indexes 1 and 2 (`measured/2026-10-23-menu-en-jeu-plan-fixe.tsv`), hence an
| opaque frame: entries 2 to 15 carry the frame colour.
| ==================================================================================

        .section .haut, "ax"
        .global _menu_en_jeu
        .global _mn_sync, _mn_entrees, _mn_ligne, _mn_vider, _mn_texte
        .global _mn_sous_ouvrir, _mn_relancer
        .global MN_BUF, MN_COUL, MN_REP

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    IRQACK,   0x3C000C
        .equ    WATCHDOG, 0x300001
        .equ    P1CNT,    0x300000
        .equ    SYSTYPE,  0x300081
        .equ    STATUS_B, 0x380000
        .equ    PALETTES, 0x400000
        .equ    BORNE_RAM, 0x10FB20     | bit 3: CHEATS/DEBUG OFF (`reglages.s`)
        .equ    CARTE_DEMANDE, 0xD001A8 | .b non-zero: open the card manager at boot (`dip.s`)
        .equ    SRAMUNLOCK, 0x3A001D
        .equ    SRAMLOCK, 0x3A000D

        .equ    SEUIL,    20            | SYSTEM_IO calls, gesture held
        .equ    S1,       0x5AC3        | the probe pair of `.Lsonder`, arbitrary choice
        .equ    S2,       0xA53C
        .equ    T1,       0x3C96        | the second pair, arbitrary choice
        .equ    T2,       0xC369

        | The area, measured free (see the header).
        .equ    MN_COMPTE, 0x10F800     | .w gesture held; $FFFF: wait for the release
        .equ    MN_SR,    0x10F802      | .w SR of the call
        .equ    MN_SP,    0x10F804      | .l the game's stack
        .equ    MN_REGS,  0x10F808      | 15 .l, D0-D7 then A0-A6
        .equ    MN_MOD,   0x10F844      | .w REG_VRAMMOD
        .equ    MN_LIGNE, 0x10F846      | .w display line at opening
        .equ    MN_ADR,   0x10F848      | .w VRAM address found again
        .equ    MN_ADROK, 0x10F84A      | .w 1 if found again
        .equ    MN_R0,    0x10F84C      | .w the word under the current address
        .equ    MN_R1,    0x10F84E      | .w the next three words
        .equ    MN_R2,    0x10F850
        .equ    MN_R3,    0x10F852
        .equ    MN_ADR2,  0x10F854      | .w A according to the second probe pair
        .equ    MN_NCH,   0x10F856      | .w the game's cheats (`cheats.s`), 0 to CH_MAX
        .equ    MN_NCOL,  0x10F858      | .w the frame layout (`.Lmise_en_page`)
        .equ    MN_NLIG,  0x10F85A
        .equ    MN_CASE0, 0x10F85C      | .w the top-left cell
        .equ    MN_CURS,  0x10F85E      | .w the cursor column
        .equ    MN_PAD,   0x10F860      | .w the margin of the fixed lines
        | .w the last choice: 5 + N, or 4 + N under CHEATS/DEBUG OFF (GAME SETTINGS), set by
        | `.Lmise_en_page`. Read by the loop in as many cycles as the old computation (MN_NCH + 3):
        | measured, two more tests per turn and per line moved RESTART GAME's restart from GAME
        | SETTINGS on ncombat one frame earlier (scene gs-mmss, RESET at 2417 instead of 2418).
        .equ    MN_DERNIER, 0x10F862
        .equ    MN_NVIS,  0x10F864      | .w cheat lines of the frame: N, at most MN_VIS
        .equ    MN_HAUT,  0x10F866      | .w the first cheat shown (`.Lfenetre`)
        .equ    MN_CHOIX, 0x10F870      | .w line chosen: 0 RESUME, 1 RESTART, 2… the cheats, then RESTART TO
                                        | CARD (2 + N), AUTOFIRE (3 + N), GAME SETTINGS (4 + N), EDITOR (5 + N)
        .equ    MN_PALS,  0x10F872      | 3 .w: the palettes taken (title, chosen, text)
        .equ    MN_USAGE, 0x10F878      | .w one bit per palette seen on the fix layer
        .equ    MN_PAL,   0x10F880      | 3 palettes, 96 bytes
        .equ    MN_COUL,  0x10F8E0      | 28 bytes: the role of each cell of MN_BUF
                                        | (0 text, 1 title, 2 chosen), for `_mn_ligne`
        .equ    MN_REP,   0x10F8FC      | .w the repeat of a held direction (`memoire.s`)
        | $10F900-$10F9DF: the states of `reglages-jeu.s` and of `memoire.s`, under the stack.
        | The saved frame, 392 .w at most (28 × 14), column by column, and the line being
        | drawn: under $10F800, in the same area measured free ($10F4B4-$10FBFF, see the header).
        .equ    MN_FIX,   0x10F4C0      | → $10F7CF
        .equ    MN_BUF,   0x10F7D0      | 28 bytes → $10F7EB
        .equ    MN_PILE,  0x10FB00      | top of the menu stack (grows down towards $10FA20)
        | $10FB00 and beyond: the states of the cheats and freezes (`cheats.s`), and of the memory
        | editor (`memoire.s`).

        | The frame ("Fix layer": $7000 + 32 × column + line; lines 2-29 and columns 1-38
        | visible, like `dip.s`). Without cheats: columns 10-29, lines 11-20. With V cheat lines
        | (MN_NVIS): 28 columns (6-33), 10 + V lines starting at 11 − V/2 — the 16-character name and
        | its state do not fit in 20.
        .equ    COL0,     10
        .equ    NCOL,     20
        .equ    LIG0,     11
        .equ    NLIG,     10
        .equ    COL0_C,   6
        .equ    NCOL_C,   28
        .equ    PAD_C,    4             | fixed lines centred in the 28 columns
        | The sub-screen frame: 28 × 14 = 392 cells, what MN_FIX holds; columns 6-33,
        | lines 9-22. 28 × (10 + MN_VIS) fits in it too, hence MN_VIS = 4; the other cheats scroll.
        .equ    MN_VIS,   4
        .equ    SOUS_NCOL, 28
        .equ    SOUS_NLIG, 14
        .equ    SOUS_CASE0, 0x7000 + 32 * 6 + 9
        .equ    NPAL,     3             | title, chosen line, text

        | The colours, $0RGB ("Colors"). A choice of looks.
        .equ    C_CADRE,  0x0124

| ----------------------------------------------------------------------------------
| THE HOOK. Destroys no register, only the condition codes.
_menu_en_jeu:
        bsr     _cheats_appliquer       | the active cheats (`cheats.s`); none: one test
        btst    #7, SYSTYPE             | TEST held: bit 7 at 0
        bne.s   4f                      | released: the gesture without a TEST button, further down
3:      cmpi.b  #2, 0x10FDAF            | in play only
        bne.s   1f
        tst.w   MN_COMPTE
        bmi.s   2f                      | closed a short while ago: we wait for the release
        addq.w  #1, MN_COMPTE
        cmpi.w  #SEUIL, MN_COMPTE
        bcc.s   _menu_ouvrir
2:      rts
| P1'S START AND SELECT HELD (see the header), separately: the TEST-held path keeps its cycles
| from before to the cycle. Measured: two more cycles on this path (a `beq` taken instead of a
| `bne` not taken) moved the RESET of RESTART GAME in scene gs-fois one frame earlier.
4:      btst    #0, STATUS_B
        bne.s   1f
        btst    #1, STATUS_B
        beq.s   5f
1:      clr.w   MN_COMPTE
        rts
| P1'S A, B, C AND D ALL FOUR HELD (REG_P1CNT bits 4-7 at 0): the BlueRetro adapter, not
| the gesture (see the header); the count restarts from zero, like START or SELECT released.
| A single read, separately: START not held, or SELECT not held, keeps its cycles from before.
5:      cmpi.b  #0x10, P1CNT
        bcc.s   3b                      | at least one of the four released: the gesture
        bra.s   1b                      | all four held: refused

| ----------------------------------------------------------------------------------
| THE OPENING. SR first: it is the menu's first write (the jig takes its "before" record
| there).
_menu_ouvrir:
        move.w  %sr, MN_SR
        move.w  #0x2700, %sr
        movem.l %d0-%d7/%a0-%a6, MN_REGS
        move.l  %sp, MN_SP
        lea     MN_PILE, %sp
        move.b  %d0, WATCHDOG
        | BOARD SWITCH 3 read here, at opening, and not after: P1 in the menu and its sub-screens
        | (`panneau.s`, DECISIONS §30).
        jsr     _panneau_verrou
        move.w  LSPCMODE, %d0           | the line: bits 15-7 (`.Lsync`)
        lsr.w   #7, %d0
        move.w  %d0, MN_LIGNE
        move.w  VRAMMOD, MN_MOD
        clr.w   MN_CHOIX
        clr.w   MN_HAUT
        bsr     .Lsonder
        bsr     _cheats_trouver         | CH_ENTREE, CH_NB (`cheats.s`)
        bsr     .Lmise_en_page

        | PALETTES. Three that the fix layer does not use, so that the game's text outside the
        | frame keeps its colours (the sprites that would use them do lose them): the highest
        | from 1 to 15 absent from the 1,280 cells; failing that, 15, 14, 13. Saved then set
        | right after line $1F0.
        bsr     .Lchoisir_palettes
        bsr     .Lsync
        lea     MN_PALS, %a4
        lea     MN_PAL, %a3
        lea     .Lcouleurs, %a5
        moveq   #NPAL - 1, %d2
1:      move.w  (%a4)+, %d0
        lsl.w   #5, %d0
        lea     PALETTES, %a2
        adda.w  %d0, %a2
        moveq   #16 - 1, %d1
2:      move.w  (%a2)+, (%a3)+
        dbra    %d1, 2b
        lea     -30(%a2), %a2           | entry 1; entry 0 stays with the game
        move.w  (%a5)+, (%a2)+          | the stroke
        moveq   #14 - 1, %d1
3:      move.w  #C_CADRE, (%a2)+        | entries 2-15, the frame
        dbra    %d1, 3b
        dbra    %d2, 1b
        bsr     .Lsauver_fix
        bsr     .Ldessiner

| ----------------------------------------------------------------------------------
| THE LOOP, one frame per turn. P1 only, on edges. Read in "Memory mapped registers":
| REG_P1CNT bits 0 up, 1 down, 4 A; REG_STATUS_B bit 0 START; active low.
| %d5: the state of the previous frame, taken at opening (START held does not count there).
        bsr     .Lentrees
.Lboucle:
        bsr     .Lsync
        bsr     .Lentrees
        move.w  MN_DERNIER, %d1         | %d1: the last choice (`.Lmise_en_page`)
        nop                             | the cycles of the former `addq`: see MN_DERNIER
        btst    #0, %d0                 | up: the previous one, from the first to the last
        beq.s   1f
        subq.w  #1, MN_CHOIX
        bpl.s   3f
        move.w  %d1, MN_CHOIX
        bra.s   3f
1:      btst    #1, %d0                 | down: the next one, from the last to the first
        beq.s   2f
        addq.w  #1, MN_CHOIX
        cmp.w   MN_CHOIX, %d1
        bcc.s   3f
        clr.w   MN_CHOIX
3:      bsr     .Ldessiner
        bra.s   .Lboucle
2:      andi.w  #0x0110, %d0            | A or START
        beq.s   .Lboucle
        move.w  MN_CHOIX, %d1
        beq.s   .Lreprendre
        subq.w  #1, %d1
        beq.w   .Lrelance
        | %d1: the choice minus 4 minus N — negative a cheat, the card or AUTOFIRE, 0 GAME SETTINGS, 1
        | the editor. `subq #3` and `blt` instead of `subq #1` and `bcs`: same cycles, and GAME SETTINGS
        | opens at the cycles from before AUTOFIRE (see `reglages-jeu.s`, THE CYCLES; scene gs-mmss).
        subq.w  #3, %d1
        sub.w   MN_NCH, %d1
        blt.s   4f
        beq.s   5f
        bsr     _memoire_ecran          | `memoire.s`
        bra.s   6f
5:      bsr     _reglages_jeu_ecran     | `reglages-jeu.s`
6:      bsr     .Lsous_fermer
        bsr     .Lentrees               | a button still held (START) does not count
        bra     .Lboucle
4:      add.w   MN_NCH, %d1
        addq.w  #2, %d1                 | the choice minus 2: below N a cheat, N the card, N + 1 AUTOFIRE
        cmp.w   MN_NCH, %d1
        bcs.s   7f
        beq.s   .Lvers_carte
        bsr     _af_ecran
        bra.s   6b
7:      move.w  CH_ETATS, %d2           | a cheat: its bit toggled, and we stay in the menu
        bchg    %d1, %d2
        move.w  %d2, CH_ETATS
        bsr     .Ldessiner
        bra     .Lboucle

| RESTART TO CARD: the mark, then the restart of RESTART GAME (see the header).
.Lvers_carte:
        move.b  %d0, SRAMUNLOCK
        move.b  #1, CARTE_DEMANDE
        move.b  %d0, SRAMLOCK
        bra     .Lrelance

| RESUME. Everything released first: a button still held on return would be a press for the
| game. Then the screen given back, and the game at the line where it was.
.Lreprendre:
1:      bsr     .Lsync
        jsr     _panneau_p1             | %d0: P1, pad or translated panel (`panneau.s`)
        not.b   %d0
        andi.b  #0xF0, %d0              | A, B, C, D
        bne.s   1b
        move.b  STATUS_B, %d0
        not.b   %d0
        andi.b  #0x0F, %d0              | START and SELECT, P1 and P2
        | On MVS, STARTs only: read in "BIOS RAM locations", "On MVS the select bits
        | are always read as 0", like `ecran.s`. A SELECT read active at rest would make
        | RESUME wait forever (ASSUMED for the raw register, as in `ecran.s`). The MACHINE,
        | REG_STATUS_B bit 7 ("0:AES 1:MVS"), not the mode: an MVS in AES mode stays an MVS.
        tst.b   STATUS_B                | bit 7, the sign: at 0, AES
        bpl.s   8f
        andi.b  #0x05, %d0
8:      tst.b   %d0
        bne.s   1b
        btst    #7, SYSTYPE             | and TEST
        beq.s   1b
        bsr     .Lsync
        lea     MN_PALS, %a4
        lea     MN_PAL, %a2
        moveq   #NPAL - 1, %d2
2:      move.w  (%a4)+, %d0
        lsl.w   #5, %d0
        lea     PALETTES, %a3
        adda.w  %d0, %a3
        moveq   #16 - 1, %d1
3:      move.w  (%a2)+, (%a3)+
        dbra    %d1, 3b
        dbra    %d2, 2b
        bsr     .Lrendre_fix
        move.w  MN_MOD, VRAMMOD
        tst.w   MN_ADROK
        beq.s   4f
        move.w  MN_ADR, VRAMADDR        | the game's queue resumes where it was
4:
        | The opening line, then the IRQs raised during the pause (see the header).
        | BOUNDED like `.Lsync` (SYNC_TOURS turns, a kick on every turn): a turn takes
        | 78 cycles here (`cmp.w` abs.l 16 instead of `cmpi.w` 8), ≈ 2.2 frames, then resuming
        | happens anyway. %d1 is free: it is reloaded right after, then given back to the game.
        move.w  #SYNC_TOURS - 1, %d1
5:      move.b  %d0, WATCHDOG
        move.w  LSPCMODE, %d0
        lsr.w   #7, %d0
        cmp.w   MN_LIGNE, %d0
        dbeq    %d1, 5b
        moveq   #4, %d0                 | the vblank
        move.w  MN_SR, %d1
        andi.w  #0x0700, %d1
        cmpi.w  #0x0100, %d1
        bhi.s   6f
        moveq   #6, %d0                 | and the timer
6:      move.w  %d0, IRQACK
        move.b  %d0, WATCHDOG
        move.w  #-1, MN_COMPTE          | nothing before the release; the jig recognises the exit there
        movea.l MN_SP, %sp
        movem.l MN_REGS, %d0-%d7/%a0-%a6
        move.w  MN_SR, %sr              | the jig takes its "after" record here
        rts

| RESTART GAME: without a kick, the watchdog restarts everything (`dip.s`). `_mn_relancer`: the
| same, for GAME SETTINGS.
_mn_relancer:
.Lrelance:
        bra.s   .Lrelance

| ----------------------------------------------------------------------------------
| THE SUB-SCREENS (see the header). Open: the menu's frame given back to the game, the
| sub-screen's saved. Close: the reverse, then the menu redrawn. Clobbers %d0-%d4, %d6, %a0-%a3.
_mn_sous_ouvrir:
        bsr     .Lrendre_fix
        move.w  #SOUS_NCOL, MN_NCOL
        move.w  #SOUS_NLIG, MN_NLIG
        move.w  #SOUS_CASE0, MN_CASE0
        bra     .Lsauver_fix

.Lsous_fermer:
        bsr     .Lrendre_fix
        bsr     .Lmise_en_page
        bsr     .Lsauver_fix
        bra     .Ldessiner

| MN_BUF to spaces, MN_COUL to text. Clobbers %d0, %a0.
_mn_vider:
        lea     MN_BUF, %a0
        moveq   #SOUS_NCOL - 1, %d0
1:      move.b  #0x20, (%a0)+
        dbra    %d0, 1b
        lea     MN_COUL, %a0
        moveq   #SOUS_NCOL - 1, %d0
1:      clr.b   (%a0)+
        dbra    %d0, 1b
        rts

| %d4 characters of %a3 into MN_BUF from column %d0, with role %d1. Clobbers %d0, %d4,
| %a0, %a1, %a3.
_mn_texte:
        lea     MN_BUF, %a0
        adda.w  %d0, %a0
        lea     MN_COUL, %a1
        adda.w  %d0, %a1
        subq.w  #1, %d4
        bmi.s   9f
1:      move.b  (%a3)+, (%a0)+
        move.b  %d1, (%a1)+
        dbra    %d4, 1b
9:      rts

| LINE %d4 OF THE FRAME, MN_NCOL cells of MN_BUF, each under the palette of its role (MN_COUL:
| 0 the text, 1 the title, 2 the chosen line, MN_PALS). REG_VRAMMOD at 32. Outside $20-$7E, a
| space. Clobbers %d0-%d3, %a0-%a3.
_mn_ligne:
        move.w  #32, VRAMMOD
        lea     VRAMRW, %a0
        move.w  MN_CASE0, %d1
        add.w   %d4, %d1
        move.w  %d1, VRAMADDR
        lea     MN_BUF, %a2
        lea     MN_COUL, %a3
        move.w  MN_NCOL, %d2
        subq.w  #1, %d2
1:      moveq   #0, %d0
        move.b  (%a2)+, %d0
        cmpi.b  #0x20, %d0
        bcs.s   2f
        cmpi.b  #0x7E, %d0
        bls.s   3f
2:      moveq   #0x20, %d0
3:      moveq   #0, %d1
        move.b  (%a3)+, %d1
        cmpi.b  #2, %d1
        bls.s   4f
        moveq   #0, %d1
4:      add.w   %d1, %d1                | the role → MN_PALS: 0 text (+4), 1 title (+0), 2 chosen (+2)
        lea     .Lroles, %a1
        move.w  (%a1,%d1.w), %d1
        lea     MN_PALS, %a1
        move.w  (%a1,%d1.w), %d3
        ror.w   #4, %d3
        add.w   %d3, %d0
        move.w  %d0, (%a0)
        dbra    %d2, 1b
        rts
.Lroles: .word  4, 0, 2

| ----------------------------------------------------------------------------------
| THE BUTTONS. %d5.w: the previous state, updated; %d0.w: the edges. Bits: those of
| REG_P1CNT ("Memory mapped registers") — 0 up, 1 down, 2 left, 3 right, 4 A, 5 B, 6 C,
| 7 D —, and 8 START. Clobbers %d1, %d2.
_mn_entrees:
.Lentrees:
        moveq   #0, %d2
        jsr     _panneau_p1             | %d0: P1, pad or translated panel (`panneau.s`)
        move.b  %d0, %d2
        not.b   %d2
        move.b  STATUS_B, %d1
        not.b   %d1
        andi.w  #0x01, %d1
        lsl.w   #8, %d1                 | START → bit 8
        or.w    %d1, %d2
        move.w  %d5, %d0
        not.w   %d0
        and.w   %d2, %d0
        move.w  %d2, %d5
        rts

| ----------------------------------------------------------------------------------
| THE GAME'S VRAM ADDRESS, found again (see the header). Nothing must write REG_VRAMADDR
| before the probe: that would lose what we are looking for. So, the current address being A and
| the step set to 1 (REG_VRAMMOD is already saved), four words read then replaced: R0..R3 =
| VRAM[A..A+3], and in their place TWO probe pairs, S1 S2 then T1 T2. A single sweep
| counts each: an S pair found exactly once gives A; otherwise a unique T pair
| gives A + 2 (a natural S pair elsewhere in VRAM therefore does not cause a failure). We put
| R0..R3 back at A..A+3. FAILURE of both (each absent or doubled): MN_ADROK stays at 0, the
| exit does not set an address, and the four probe words STAY in VRAM at A..A+3, where
| the game will resume on a wrong address — ASSUMED rare, two arbitrary pairs.
| Clobbers %d0-%d5, %a0, %a1.
.Lsonder:
        lea     VRAMRW, %a0
        lea     VRAMADDR, %a1
        clr.w   MN_ADROK
        move.w  #1, VRAMMOD
        move.w  (%a0), MN_R0
        move.w  #S1, (%a0)
        nop                             | 16 cycles at least before reading back ("VRAM")
        nop
        nop
        move.w  (%a0), MN_R1
        move.w  #S2, (%a0)
        nop
        nop
        nop
        move.w  (%a0), MN_R2
        move.w  #T1, (%a0)
        nop
        nop
        nop
        move.w  (%a0), MN_R3
        move.w  #T2, (%a0)
        nop
        nop
        nop

        | THE SWEEP of $0000-$87FF ("VRAM": $0000-$7FFF then $8000-$87FF). %d2: the word
        | read at the previous address. Pace: 16 cycles at least between the address and the read —
        | `addq` (4), three `nop` (12), then the `move` that reads. %d4 / %d5: S / T pairs seen.
        moveq   #0, %d4
        moveq   #0, %d5
        moveq   #0, %d1
        moveq   #0, %d2
        move.w  #0x8800 - 1, %d3
1:      move.w  %d1, (%a1)
        addq.w  #1, %d1
        nop
        nop
        nop
        move.w  (%a0), %d0
        cmpi.w  #S2, %d0
        bne.s   2f
        cmpi.w  #S1, %d2
        bne.s   3f
        addq.w  #1, %d4
        move.w  %d1, MN_ADR
        subq.w  #2, MN_ADR              | %d1 has already moved to the word after S2
        bra.s   3f
2:      cmpi.w  #T2, %d0
        bne.s   3f
        cmpi.w  #T1, %d2
        bne.s   3f
        addq.w  #1, %d5
        move.w  %d1, MN_ADR2
        subq.w  #4, MN_ADR2             | T1 is at A + 2
3:      move.w  %d0, %d2
        move.b  %d0, WATCHDOG
        dbra    %d3, 1b
        cmpi.w  #1, %d4
        beq.s   4f
        cmpi.w  #1, %d5
        bne.s   9f
        move.w  MN_ADR2, MN_ADR
4:      move.w  #1, MN_ADROK
        move.w  MN_ADR, (%a1)
        nop
        nop
        nop
        nop
        move.w  MN_R0, (%a0)            | step of 1: A, A+1, A+2, A+3
        move.w  MN_R1, (%a0)
        move.w  MN_R2, (%a0)
        move.w  MN_R3, (%a0)
9:      rts

| ----------------------------------------------------------------------------------
| THE FRAME. Save: MN_NCOL × MN_NLIG cells read one by one. Give back: rewritten column by column.
.Lsauver_fix:
        lea     VRAMRW, %a0
        lea     VRAMADDR, %a1
        lea     MN_FIX, %a2
        move.w  MN_CASE0, %d1
        move.w  MN_NCOL, %d3
        subq.w  #1, %d3
1:      move.w  MN_NLIG, %d2
        subq.w  #1, %d2
        move.w  %d1, %d4                | the column, cell by cell
2:      move.w  %d4, (%a1)
        addq.w  #1, %d4
        nop
        nop
        nop
        move.w  (%a0), (%a2)+
        dbra    %d2, 2b
        addi.w  #32, %d1
        dbra    %d3, 1b
        rts

.Lrendre_fix:
        lea     VRAMRW, %a0
        lea     MN_FIX, %a2
        move.w  #1, VRAMMOD             | one column: MN_NLIG consecutive words
        move.w  MN_CASE0, %d1
        move.w  MN_NCOL, %d3
        subq.w  #1, %d3
1:      move.w  %d1, VRAMADDR
        move.w  MN_NLIG, %d2
        subq.w  #1, %d2
2:      move.w  (%a2)+, (%a0)
        dbra    %d2, 2b
        addi.w  #32, %d1
        dbra    %d3, 1b
        rts

| THE LAYOUT, from CH_NB (`_cheats_trouver`). Clobbers %d0, %d1.
.Lmise_en_page:
        move.w  CH_NB, %d0
        move.w  %d0, MN_NCH
        move.w  %d0, %d1
        addq.w  #5, %d1                 | N + 5, MEMORY EDITOR
        btst    #3, BORNE_RAM
        beq.s   2f
        subq.w  #1, %d1                 | CHEATS/DEBUG OFF: GAME SETTINGS is the last
2:      move.w  %d1, MN_DERNIER
        cmpi.w  #MN_VIS, %d0
        bls.s   3f
        moveq   #MN_VIS, %d0            | beyond: the window scrolls
3:      move.w  %d0, MN_NVIS
        tst.w   %d0
        bne.s   1f
        move.w  #NCOL, MN_NCOL          | without cheats: the frame from before, identical
        move.w  #NLIG, MN_NLIG
        move.w  #1, MN_CURS
        clr.w   MN_PAD
        move.w  #0x7000 + 32 * COL0 + LIG0, MN_CASE0
        rts
1:      move.w  #NCOL_C, MN_NCOL
        move.w  #PAD_C, MN_PAD
        move.w  #PAD_C + 1, MN_CURS
        move.w  %d0, %d1
        addi.w  #NLIG, %d1
        move.w  %d1, MN_NLIG
        lsr.w   #1, %d0
        move.w  #0x7000 + 32 * COL0_C + LIG0, %d1
        sub.w   %d0, %d1                | 11 − V/2
        move.w  %d1, MN_CASE0
        rts

| THE WINDOW: MN_HAUT follows the choice when it is a cheat, just enough to show it. Elsewhere
| (RESUME, RESTART, AUTOFIRE and after), it does not move. Clobbers %d0, %d1.
.Lfenetre:
        move.w  MN_CHOIX, %d0
        subq.w  #2, %d0                 | the index of the chosen cheat
        bmi.s   9f                      | RESUME, RESTART
        cmp.w   MN_NCH, %d0
        bcc.s   9f                      | AUTOFIRE and what follows
        cmp.w   MN_HAUT, %d0
        bcc.s   1f
        move.w  %d0, MN_HAUT            | above the window: it becomes its top
        rts
1:      move.w  %d0, %d1
        sub.w   MN_NVIS, %d1
        addq.w  #1, %d1                 | the top that shows it on the last line
        cmp.w   MN_HAUT, %d1
        ble.s   9f                      | signed: negative as long as the index is under MN_NVIS
        move.w  %d1, MN_HAUT
9:      rts

| THE CHOICE OF LINE %d4 OF THE FRAME, in %d0 (negative for lines 0-2): lines 3 and 4,
| then MN_NVIS cheats starting at MN_HAUT, then the fixed lines, N cheats from the start. Clobbers %d1.
.Lchoix_de_ligne:
        move.w  %d4, %d0
        subq.w  #3, %d0
        cmpi.w  #2, %d0
        blt.s   9f                      | lines 0-4: the line minus 3
        move.w  MN_NVIS, %d1
        addq.w  #2, %d1
        cmp.w   %d1, %d0
        bge.s   1f
        add.w   MN_HAUT, %d0            | a cheat of the window
        rts
1:      add.w   MN_NCH, %d0
        sub.w   MN_NVIS, %d0            | after the window: the hidden cheats on top
9:      rts

| THE LINES OF THE FRAME, REG_VRAMMOD at 32: a line is written from one address, from MN_BUF
| (`.Lconstruire`). MN_PALS: the title, the chosen line (and its cursor), the rest.
| Clobbers %d0-%d4, %d6, %a0, %a2, %a3; %d5, the button state, is intact.
.Ldessiner:
        bsr     .Lfenetre
        move.w  #32, VRAMMOD
        moveq   #0, %d4                 | the frame line
1:      bsr     .Lconstruire
        moveq   #0, %d6                 | 1: the line carries the cursor
        move.w  MN_PALS + 4, %d3        | the text
        cmpi.w  #1, %d4
        bne.s   2f
        move.w  MN_PALS, %d3            | the title
2:      bsr     .Lchoix_de_ligne        | the choices from line 3
        cmp.w   MN_CHOIX, %d0
        bne.s   3f
        move.w  MN_PALS + 2, %d3        | the chosen line
        moveq   #1, %d6
3:      ror.w   #4, %d3                 | the palette number in the top 4 bits
        lea     VRAMRW, %a0
        move.w  MN_CASE0, %d1
        add.w   %d4, %d1
        move.w  %d1, VRAMADDR
        lea     MN_BUF, %a2
        move.w  MN_NCOL, %d2
        subq.w  #1, %d2
        move.w  %d2, %d1
        sub.w   MN_CURS, %d1            | %d2 when the column is the cursor's
4:      moveq   #0, %d0
        move.b  (%a2)+, %d0
        tst.w   %d6
        beq.s   5f
        cmp.w   %d1, %d2
        bne.s   5f
        moveq   #0x3E, %d0              | ">"
5:      add.w   %d3, %d0
        move.w  %d0, (%a0)
        dbra    %d2, 4b
        addq.w  #1, %d4
        cmp.w   MN_NLIG, %d4
        bcs.s   1b
        rts

| LINE %d4 OF THE FRAME, as characters in MN_BUF (NCOL_C bytes, spaces beyond
| MN_NCOL). Lines 0-4 and the last five: `.Llignes` 0-9, shifted by MN_PAD; between
| the two, the MN_NVIS cheats of the window: the name at MN_PAD + 3, the state "ON" / "OFF" at
| MN_PAD + 20. Line 2, when cheats are hidden: `.Lrang`. Clobbers %d0-%d2, %a2, %a3.
.Lconstruire:
        lea     MN_BUF, %a2
        moveq   #NCOL_C - 1, %d0
1:      move.b  #0x20, (%a2)+
        dbra    %d0, 1b
        lea     MN_BUF, %a2
        adda.w  MN_PAD, %a2
        move.w  %d4, %d0
        cmpi.w  #5, %d0
        bcs.s   8f                      | fixed lines 0-4
        subq.w  #5, %d0                 | k = line − 5
        cmp.w   MN_NVIS, %d0
        bcs.s   6f                      | k < V: cheat MN_HAUT + k
        move.w  %d4, %d0
        sub.w   MN_NVIS, %d0            | fixed lines 5-9 (line − V ≥ 5 here)
        bra.s   3f
8:      cmpi.w  #2, %d0
        bne.s   3f
        move.w  MN_NCH, %d1
        cmp.w   MN_NVIS, %d1
        bhi.s   .Lrang                  | hidden cheats
        bra.s   3f
6:      add.w   MN_HAUT, %d0
        movea.l CH_ENTREE, %a3
        move.w  %d0, %d2
        lsl.w   #5, %d2                 | × FICHE (`cheats.s`)
        adda.w  %d2, %a3
        addq.l  #3, %a2
        moveq   #16 - 1, %d2
2:      move.b  (%a3)+, (%a2)+
        dbra    %d2, 2b
        addq.l  #1, %a2
        lea     .Lon, %a3
        move.w  CH_ETATS, %d2
        btst    %d0, %d2
        bne.s   4f
        lea     .Loff, %a3
4:      move.b  (%a3)+, (%a2)+
        move.b  (%a3)+, (%a2)+
        move.b  (%a3)+, (%a2)+
        rts
3:      cmpi.w  #8, %d0                 | MEMORY EDITOR, CHEATS/DEBUG OFF: the line blank
        bne.s   7f
        btst    #3, BORNE_RAM
        bne.s   9f
7:      lea     .Llignes, %a3           | 20 × %d0
        lsl.w   #2, %d0
        adda.w  %d0, %a3
        lsl.w   #2, %d0
        adda.w  %d0, %a3
        moveq   #NCOL - 1, %d2
5:      move.b  (%a3)+, (%a2)+
        dbra    %d2, 5b
9:      rts

| "CHEATS a-b/N" at MN_PAD + 3: the cheats shown, from 1 to N. %a2: MN_BUF + MN_PAD. The end of
| `.Lconstruire`, returned by the `rts` of `.Ldecimal`. Clobbers %d0, %d2, %a2, %a3.
.Lrang:
        addq.l  #3, %a2
        lea     .Lcheats, %a3
        moveq   #7 - 1, %d2
1:      move.b  (%a3)+, (%a2)+
        dbra    %d2, 1b
        move.w  MN_HAUT, %d0
        addq.w  #1, %d0
        bsr.s   .Ldecimal
        move.b  #0x2D, (%a2)+           | "-"
        move.w  MN_HAUT, %d0
        add.w   MN_NVIS, %d0
        bsr.s   .Ldecimal
        move.b  #0x2F, (%a2)+           | "/"
        move.w  MN_NCH, %d0             | then `.Ldecimal`, just below

| %d0.w (0 to 99) in decimal without a leading zero, to (%a2)+. Clobbers %d0.
.Ldecimal:
        andi.l  #0xFFFF, %d0
        divu    #10, %d0                | the tens in the low word, the units in the high one
        tst.w   %d0
        beq.s   1f
        addi.b  #0x30, %d0
        move.b  %d0, (%a2)+
1:      swap    %d0
        addi.b  #0x30, %d0
        move.b  %d0, (%a2)+
        rts

| THE MENU'S PALETTES (see the opening). One bit per palette of the 1,280 cells of the fix layer,
| read through REG_VRAMRW at the pace of `.Lsauver_fix`; then from 15 down to 1, the first three
| absent. MN_PALS receives title, chosen, text. Clobbers %d0-%d3, %a0-%a2.
.Lchoisir_palettes:
        lea     VRAMRW, %a0
        lea     VRAMADDR, %a1
        moveq   #0, %d2                 | the palettes seen
        move.w  #0x7000, %d1
        move.w  #1280 - 1, %d3
1:      move.w  %d1, (%a1)
        addq.w  #1, %d1
        nop
        nop
        nop
        move.w  (%a0), %d0
        rol.w   #4, %d0
        andi.w  #0x0F, %d0
        bset    %d0, %d2
        move.b  %d0, WATCHDOG
        dbra    %d3, 1b
        move.w  %d2, MN_USAGE
        lea     MN_PALS, %a2
        moveq   #15, %d0
        moveq   #NPAL - 1, %d3
2:      btst    %d0, %d2
        bne.s   3f
        move.w  %d0, (%a2)+             | free: taken
        subq.w  #1, %d3
        bmi.s   9f
3:      subq.w  #1, %d0
        bne.s   2b
        | Fewer than three free: all the free ones are already taken, the remaining places
        | take USED ones, from 15 down to 1 — never the same one twice, otherwise the
        | save of an already overwritten palette would give it back wrong to the game. The game's
        | text under them changes colour during the pause.
        moveq   #15, %d0
4:      btst    %d0, %d2
        beq.s   5f                      | free: already taken in the first pass
        move.w  %d0, (%a2)+
        subq.w  #1, %d3
        bmi.s   9f
5:      subq.w  #1, %d0
        bne.s   4b
9:      rts

| LINE $1F0 PASSING, like `dip.s`; watchdog on every turn. Clobbers %d0.
| BOUNDED to SYNC_TOURS turns per wait, ≈ 2 frames, line seen or not: the count is in
| `ecran.s`, of which this is the identical copy.
        .equ    SYNC_TOURS, 5800
_mn_sync:
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
.Lcouleurs:                             | entry 1: title, chosen line, text
        .word   0x04CF                  | the title
        .word   0x0FE3                  | the chosen line
        .word   0x0DDD                  | the text
.Lon:    .ascii  "ON "
.Loff:   .ascii  "OFF"
.Lcheats: .ascii "CHEATS "
.Llignes:                               | NLIG lines of NCOL characters
        .ascii  "                    "
        .ascii  "    IN-GAME MENU    "
        .ascii  "                    "
        .ascii  "   RESUME           "
        .ascii  "   RESTART GAME     "
        .ascii  "   RESTART TO CARD  "
        .ascii  "   AUTOFIRE         "
        .ascii  "   GAME SETTINGS    "
        .ascii  "   MEMORY EDITOR    "
        .ascii  " UP/DOWN A/START:OK "
        .balign 2
