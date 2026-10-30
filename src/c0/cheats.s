| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| THE CHEATS — one table per game, an engine that writes into work RAM the values of the
| active cheats on every SYSTEM_IO call, and their lines in the in-game menu (`menu.s`).
|
| NO ORACLE: neither the reference BIOS, nor a third-party BIOS, nor a third-party cheat base
| (UniBIOS's, MAME's cheat.xml, a code site) is read. The hand-over is
| "Couche 3 → les cheats, le 2026-10-21" (`docs/RELECTURE-CONTRATS.md`).
| "measured": jig `bench/cheats.lua` under MAME 0.286, -bios euro, -video none, our image,
| 2026-10-21 (records handed to the coordinating agent); "read in": a page of the NeoGeo
| Development Wiki; "ASSUMED": neither one nor the other.
|
| THE TABLE FORMAT, `_cheats_table`, big-endian words:
|   per game, the JEU macro: NGH (.w), EMPREINTE (.w), NUMBER of cheats (.w, 1 to CH_MAX),
|   then NUMBER records of FICHE = 32 bytes, the CHEAT macro:
|     +0   the name, 16 ASCII characters padded with spaces;
|     +16  two 8-byte writes: address (.l, $100000-$10F2FF), size (.w: 1 byte,
|          2 word, 0 no write), value (.w; the low byte for a size 1).
|   The table ends with a zero NGH. The macro's guards refuse at link time an address outside
|   the game's work RAM, a word at an odd address, a name of more than 16 characters.
|
| THE IDENTIFICATION, on every opening of the menu (`_cheats_trouver`) — that is the only place
| the table is used, since no cheat is active before being chosen in the menu. NGH: the word
| $000108, "68k program header". EMPREINTE: the 16-bit sum of the 64 words $000100-$00017E
| of the P-ROM (the same header: name, NGH, sizes, pointers, the USER, PLAYER_START,
| DEMO_END, COIN_SOUND jumps). Outside the first 128 bytes that REG_SWPBIOS swaps ("Memory mapped
| registers"), and in the fixed P-ROM: read as the game sees it. ASSUMED: that another
| revision of the same NGH moves at least one of these pointers; none is in the corpus, and
| measured only that the 21 games that boot have distinct NGH/EMPREINTE pairs, then the
| 81 games of the table on 2026-10-29, with NGHs all distinct (`measured/2026-10-2[59]-cheats-table.tsv`).
|
| THE STATES, $10FB00-$10FB07: CH_ENTREE (.l, the game's first record, 0 without an entry), CH_NB
| (.w), CH_ETATS (.w, one bit per cheat, bit 0 = the first record). Area measured free: write
| taps on 22 games show no game write between $10F4B4 and $10FBFF
| (`measured/2026-10-21-ecrivains-ram-bios.tsv`); the menu takes $10F4C0-$10F7FF and
| $10F800-$10FAFF, its stack grows down from $10FB00 exclusive. The boot clear (`c0.s`) sets them
| to zero: lost on restart, as the hand-over wants (measured: RESTART GAME with an active cheat,
| CH_ETATS at 0 after the reset, no more engine writes). And lost on every slot
| change (`_cheats_oublier`, called by `_passer_au_slot` of `c0.s`): found by the audit of
| 2026-10-21, otherwise they survived the change of game.
|
| THE ENGINE, `_cheats_appliquer`, called at the start of the menu hook (`menu.s`), hence on every
| SYSTEM_IO call. No active cheat: the `bsr`, an absolute-address `tst.l`, a taken `beq`
| and the `rts`, nothing written. Active, and in play only (BIOS_USER_MODE
| $10FDAF = 2, "BIOS RAM locations"): CH_ENTREE checked against the table (a game's first
| record, otherwise CH_ETATS reset to zero), then the writes of the active records, and nothing
| else. One write per frame is enough, measured for every cheat of the table: the game may count
| down between two calls, the value comes back on the next call (vblank, measured in `menu.s`).
|
| THE FREEZES, the custom cheat of the memory editor (`memoire.s`), 2026-10-23: GL_MAX
| bytes of the game's work RAM, each rewritten to its value on every call, by the same
| engine and under the same conditions (in play only). GL_MASQUE (.w, one bit per freeze), then
| GL_MAX records of 4 bytes: the offset from $100000 (.w), the value (.b), a spare byte.
| BOUNDED at application itself, not only when set: an offset of $F300 or more (the BIOS
| area, $10F300-$10FFFF, where these states and the menu's save area live) is never written,
| and its bit is cleared — same guard as CH_ENTREE, nothing protecting this RAM from a game.
| Bit 15 of GL_MASQUE is that of the DEBUG DIPS (`debug.s`, 2026-10-25): the engine sets them on
| every call, in demo as in play, through the same `tst.l` with no cheat or freeze; bits 0 to
| GL_MAX − 1 remain those of the freezes, in the low byte that `memoire.s` reads. Area
| $10FB08-$10FB1B, measured free like the cheat states; cleared at boot, and forgotten with them
| on every slot change.
|
| CHEATS/DEBUG OFF (CABINET SETTINGS sub-screen of `dip.s`, bit 3 of the BORNE_RAM copy, $10FB20,
| `reglages.s`), 2026-10-25: `_cheats_trouver` no longer gives an entry (the menu has no more
| cheat lines, `menu.s`), and the engine, if it still finds an active cheat or freeze, clears them
| all without writing anything. This test is only in the active-cheats branch: with no cheat or
| freeze, the hook keeps its single `tst.l` (DECISIONS §12, point 7).
| ==================================================================================

        .section .haut, "ax"
        .global _cheats_appliquer
        .global _cheats_trouver
        .global _cheats_oublier
        .global CH_ENTREE, CH_NB, CH_ETATS
        .global GL_MASQUE, GL_TABLE

        .equ    CH_ENTREE, 0x10FB00     | .l the game's first record; 0: no entry
        .equ    CH_NB,     0x10FB04     | .w number of cheats of the game
        .equ    CH_ETATS,  0x10FB06     | .w one bit per active cheat
        .equ    FICHE,     32
        | CH_MAX: one bit of CH_ETATS per cheat, hence 16. The menu shows MN_VIS of them at a time and
        | scrolls the others (`menu.s`); CH_ETATS stays a word, contiguous with GL_MASQUE for the `tst.l`.
        .equ    CH_MAX,    16
        .equ    GL_MASQUE, 0x10FB08     | .w one bit per active freeze; CONTIGUOUS with CH_ETATS (the `tst.l`)
        .equ    GL_TABLE,  0x10FB0A     | GL_MAX × (.w offset, .b value, .b spare)
        .equ    GL_MAX,    4
        .equ    GL_BORNE,  0xF300       | $10F300: the BIOS area, never written
        .equ    BORNE_RAM, 0x10FB20     | .b the cabinet in RAM (`reglages.s`); bit 3: CHEATS/DEBUG OFF

| ----------------------------------------------------------------------------------
| THE ENGINE. Destroys no register, only the condition codes.
_cheats_appliquer:
        | A SINGLE TEST with no cheat or freeze: CH_ETATS and GL_MASQUE, contiguous, with one `tst.l`
        | (20 cycles against 16 for the `tst.w` from before the freezes). Measured (matrix, svc,
        | 2026-10-23, `measured/2026-10-23-menu-en-jeu-complet.tsv`, section 3): one more `tst.w` per
        | call (two instructions, 26 cycles) is enough to make svc's play diverge, vifs 67805 instead
        | of 66944; the `tst.l` alone leaves it equal to main.
        tst.l   CH_ETATS
        beq.w   9f                      | .w: 10 cycles taken, like .s (the target is too far)
        btst    #3, BORNE_RAM           | CHEATS/DEBUG OFF: everything cleared, nothing written
        bne.w   .Lcoupes
        tst.w   GL_MASQUE
        beq.s   1f
        bsr.s   .Lgels
1:      tst.w   CH_ETATS
        beq.s   9f
        cmpi.b  #2, 0x10FDAF            | in play only
        bne.s   9f
        movem.l %d0-%d3/%a0-%a2, -(%sp)
        | CH_ENTREE VALIDATED before any write: it must be the first record of a game of
        | `_cheats_table`, exactly where `_cheats_trouver` sets it, and CH_ETATS keeps only
        | the bits of its records. ASSUMED, a guard: the RAM $10FB00-$10FB07 is written only by
        | this file and `menu.s` (read in the code), but nothing protects it from a game; an
        | arbitrary pointer or bits would make values of the table be written anywhere.
        | Outside the table: CH_ETATS reset to zero, nothing written.
        move.l  CH_ENTREE, %d1
        lea     _cheats_table, %a0
6:      move.w  (%a0)+, %d2             | NGH; 0: end of table
        beq.s   8f
        addq.l  #2, %a0                 | the fingerprint
        move.w  (%a0)+, %d2             | the number of records, 1 to CH_MAX
        cmpa.l  %d1, %a0
        beq.s   7f
        lsl.w   #5, %d2                 | × FICHE
        adda.w  %d2, %a0
        bra.s   6b
7:      moveq   #1, %d0                 | %d0: CH_ETATS & (2^number - 1)
        lsl.w   %d2, %d0                | 16: the word goes to 0, and the mask to $FFFF
        subq.w  #1, %d0
        and.w   CH_ETATS, %d0
1:      lsr.w   #1, %d0                 | this record's bit into X/C
        bcc.s   4f
        lea     16(%a0), %a1            | its two writes
        moveq   #2 - 1, %d1
2:      movea.l (%a1)+, %a2
        move.w  (%a1)+, %d2             | size
        move.w  (%a1)+, %d3             | value
        subq.w  #1, %d2
        bmi.s   4f                      | 0: nothing more for this record
        bne.s   3f
        move.b  %d3, (%a2)
        bra.s   5f
3:      move.w  %d3, (%a2)
5:      dbra    %d1, 2b
4:      lea     FICHE(%a0), %a0
        tst.w   %d0
        bne.s   1b
        bra.s   3f
8:      clr.w   CH_ETATS                | CH_ENTREE outside the table
3:      movem.l (%sp)+, %d0-%d3/%a0-%a2
9:      rts
.Lcoupes:
        clr.l   CH_ETATS                | CH_ETATS and GL_MASQUE, contiguous
        rts

| THE FREEZES (see the header). Destroys no register, only the condition codes.
.Lgels:
        tst.w   GL_MASQUE               | bit 15: the debug dips (`debug.s`), in demo as in play
        bpl.s   1f
        jsr     _dd_appliquer           | registers given back
1:      cmpi.b  #2, 0x10FDAF            | in play only
        bne.s   9f
        movem.l %d0-%d2/%a0-%a1, -(%sp)
        lea     GL_TABLE, %a0
        lea     0x100000, %a1
        moveq   #0, %d0                 | the freeze
1:      btst    %d0, GL_MASQUE + 1
        beq.s   3f
        moveq   #0, %d1
        move.w  (%a0), %d1
        cmpi.l  #GL_BORNE, %d1
        bcs.s   2f
        bclr    %d0, GL_MASQUE + 1      | outside the game's RAM: cleared, nothing written
        bra.s   3f
2:      move.b  2(%a0), (%a1,%d1.l)
3:      addq.l  #4, %a0
        addq.w  #1, %d0
        cmpi.w  #GL_MAX, %d0
        bcs.s   1b
        andi.w  #0x8000 + (1 << GL_MAX) - 1, GL_MASQUE  | beyond GL_MAX: cleared, except bit 15
        movem.l (%sp)+, %d0-%d2/%a0-%a1
9:      rts

| ----------------------------------------------------------------------------------
| THE IDENTIFICATION (see the header). Sets CH_ENTREE and CH_NB; without an entry, 0 and 0, and
| CH_ETATS reset to zero. CHEATS/DEBUG OFF: never an entry. Clobbers %d0-%d4, %a0.
_cheats_trouver:
        btst    #3, BORNE_RAM
        bne.s   8f
        lea     0x100, %a0
        moveq   #0, %d0
        moveq   #64 - 1, %d1
1:      add.w   (%a0)+, %d0
        dbra    %d1, 1b
        move.w  0x108, %d1              | NGH
        lea     _cheats_table, %a0
2:      move.w  (%a0)+, %d2
        beq.s   8f                      | end of table
        move.w  (%a0)+, %d3
        move.w  (%a0)+, %d4
        cmp.w   %d1, %d2
        bne.s   3f
        cmp.w   %d0, %d3
        bne.s   3f
        move.l  %a0, CH_ENTREE
        move.w  %d4, CH_NB
        rts
3:      lsl.w   #5, %d4                 | × FICHE
        adda.w  %d4, %a0
        bra.s   2b
8:      clr.l   CH_ENTREE
        clr.w   CH_NB
        clr.w   CH_ETATS
        rts

| ----------------------------------------------------------------------------------
| FORGETTING, on every slot change: no entry, no active cheat. Touches no
| register; the condition codes only.
_cheats_oublier:
        clr.l   CH_ENTREE
        clr.w   CH_NB
        clr.w   CH_ETATS
        clr.w   GL_MASQUE               | the freezes of the game being left, and its debug dips
        clr.w   DD_MASQUE               | (`debug.s`)
        rts

| ----------------------------------------------------------------------------------
| THE TABLE.
        | The guards are written as differences (`.iflt`, `.ifgt`, `.ifne`): a first writing
        | as `(a < b) | (a > c)` let an out-of-bounds address through (measured, test image).
        | .Lch_attendu / .Lch_compte: the CHEATs announced by the last JEU, and those seen since.
        .set    .Lch_attendu, 0
        .set    .Lch_compte, 0

        .macro  COMPTE_JUSTE
        .ifne   .Lch_compte - .Lch_attendu
        .error  "JEU : le nombre annoncé n'est pas celui des CHEAT qui suivent"
        .endif
        .endm

        .macro  JEU ngh, empreinte, nombre
        COMPTE_JUSTE
        .ifeq   \ngh
        .error  "JEU : un NGH nul terminerait la table"
        .endif
        .iflt   \nombre - 1
        .error  "JEU : de 1 à CH_MAX cheats"
        .endif
        .ifgt   \nombre - CH_MAX
        .error  "JEU : de 1 à CH_MAX cheats"
        .endif
        .set    .Lch_attendu, \nombre
        .set    .Lch_compte, 0
        .word   \ngh, \empreinte, \nombre
        .endm

        .macro  FIN_TABLE
        COMPTE_JUSTE
        .word   0                       | end of table
        .endm

        .macro  ECRITURE adr, taille, valeur
        .iflt   \taille
        .error  "CHEAT : taille 0, 1 ou 2"
        .endif
        .ifgt   \taille - 2
        .error  "CHEAT : taille 0, 1 ou 2"
        .endif
        .if     \taille
        .if     \adr < 0x100000
        .error  "CHEAT : adresse sous la RAM de travail du jeu"
        .endif
        .if     \adr >= 0x10F300
        .error  "CHEAT : adresse au-dessus de la RAM de travail du jeu"
        .endif
        .if     (\taille == 2) & (\adr & 1)
        .error  "CHEAT : un mot à une adresse impaire"
        .endif
        .endif
        .long   \adr
        .word   \taille, \valeur
        .endm

        .macro  CHEAT nom, a1, t1, v1, a2=0, t2=0, v2=0
.Lnom\@:
        .ascii  "\nom"
        .if     (. - .Lnom\@) > 16
        .error  "CHEAT : nom de plus de 16 caractères"
        .endif
        .fill   16 - (. - .Lnom\@), 1, 0x20
        ECRITURE \a1, \t1, \v1
        ECRITURE \a2, \t2, \v2
        .set    .Lch_compte, .Lch_compte + 1
        .endm

| THE CHEATS, measured except those of `measured/2026-10-30-cheats-importes.tsv`, imported (jig `bench/cheats.lua`, modes `releve` then `forcer`: the cell
| found by filtering RAM records over a game with scheduled inputs, then forced by
| lua on every frame, the effect observed on screen and on the course of the game). Records of the
| search handed to the coordinating agent.
        | ITS SECTION, `.cheats`, linked at the end of the high area (`build/bios.ld`): in the middle
        | of the code, the growing table pushed `_mess_out` out of range of the `bsr.w` of `int1.s`
        | (measured on 2026-10-29, "relocation truncated to fit" with nine more cheats). Read through
        | an absolute `lea` and through CH_ENTREE, it can be anywhere in the image.
        .section .cheats, "a"
        .balign 2
_cheats_table:
        | METAL SLUG. Measured: lives $100377 (−1 on every death; forced to 3, no game over
        | in 11 deaths, the witness run ends at the 4th — BIOS_GAME_DIP set by lua to 3 lives, see
        | below); bombs $1004C0 (−1 per grenade, 10 on every life; forced, BOMB stays 10);
        | mission time $106E93 (seconds, binary, 60 at start; forced, 60 on screen
        | for 5,400 frames). Under our image, its soft-DIP block ($2783D0) is outside the
        | fixed P-ROM and `c0.s` refuses it: GAME_DIP stays at zero, the game starts with 0 lives and the
        | counter goes from 0 to $FF at the first death, without game over (measured).
        JEU     0x0201, 0x33C2, 11
        CHEAT   "INFINITE LIVES",  0x100377, 1, 0x03
        CHEAT   "INFINITE BOMBS",  0x1004C0, 1, 0x0A
        CHEAT   "INFINITE TIME",   0x106E93, 1, 0x3C
        CHEAT   "P2 INF LIVES", 0x100417, 1, 0x03
        CHEAT   "TANK INVINCIBLE", 0x1005C5, 1, 0xFF
        CHEAT   "P1 INVINCIBILITY", 0x100485, 1, 0x40
        CHEAT   "P2 INVINCIBILITY", 0x100525, 1, 0x40
        CHEAT   "P2 INF BOMBS", 0x100560, 1, 0x0A
        CHEAT   "INF TANK GAS", 0x1005E7, 1, 0x30
        CHEAT   "INF TANK CANNON", 0x100610, 1, 0x0A
        CHEAT   "INF VEHICLE CANN", 0x10060E, 2, 0x0001
        | ART OF FIGHTING. Measured: round seconds $108406 (BCD, $60 at start; forced, 60 on
        | screen, and the game ends like the witness run); P1's life $1092CD ($60 at start, 0 at
        | KO; forced, gauge full, no game over in 8,000 frames, the witness run ends at 6,079).
        JEU     0x0044, 0x42B6, 7
        CHEAT   "INFINITE TIME",   0x108406, 1, 0x60
        CHEAT   "P1 INFINITE LIFE", 0x1092CD, 1, 0x60
        CHEAT   "P2 INF ENERGY", 0x1093CD, 1, 0x60
        CHEAT   "P1 INF POWER", 0x1094A4, 1, 0x80
        CHEAT   "P2 INF POWER", 0x1095A4, 1, 0x80
        CHEAT   "P1 ALTERNATE OUT", 0x109052, 1, 0x03, 0x109752, 1, 0x03
        CHEAT   "P2 ALTERNATE OUT", 0x10A052, 1, 0x03, 0x10A752, 1, 0x03
        | THE KING OF FIGHTERS '94. Measured: the frame countdown of the second $10882F (50 → 0,
        | then −1 to the seconds $10882E); forced to 50, TIME stays 60 and the end-of-round
        | countdown, which writes $10882E without going through it, runs. Forcing $10882E itself
        | freezes the game at KO (measured: gauge empty, nothing follows any more). P1's life
        | $108221 ($CF at start; forced, gauge full, no game over in 9,000 frames, the witness run
        | ends at 8,466).
        JEU     0x0055, 0x4489, 5
        CHEAT   "INFINITE TIME",   0x10882F, 1, 0x32
        CHEAT   "P1 INFINITE LIFE", 0x108221, 1, 0xCF
        CHEAT   "P2 INF ENERGY", 0x108421, 1, 0xCF
        CHEAT   "P1 MAX POW", 0x108219, 1, 0x7F
        CHEAT   "P2 MAX POW", 0x108419, 1, 0x7F
        | THE CATALOGUE OF 2026-10-25: one or two cheats per game, each found and proven like those
        | above (standalone record `measured/2026-10-25-cheats-table.tsv`: method, measurement, effect
        | seen on screen, jig; the search, `2026-10-25-cheats-recherche.tsv`), and enabled through the
        | in-game menu under `bench/cheats-catalogue.sh`. INFINITE TIME: the displayed timer no longer
        | goes down, and the round still ends by KO. INFINITE LIVES: no more game over.
        | THE KING OF FIGHTERS '95: like kof94, the frame countdown of the second ($32 to 0) next to
        | the seconds $10A836 (BCD), which we do not force (forced, the round no longer starts); P1's
        | life $CF at the start of the round.
        JEU     0x0084, 0x0A7E, 7
        CHEAT   "INFINITE TIME",   0x10A837, 1, 0x32
        CHEAT   "P1 INFINITE LIFE", 0x108221, 1, 0xCF
        CHEAT   "BOSS CODE + TIME", 0x100000, 1, 0x04
        CHEAT   "P2 INF ENERGY", 0x108421, 1, 0xCF
        CHEAT   "P1 MAX POW", 0x108219, 1, 0x7F
        CHEAT   "P2 MAX POW", 0x108419, 1, 0x7F
        CHEAT   "HIDDEN CHARS", 0x10E79A, 1, 0x01
        | THE KING OF FIGHTERS '99: the frame countdown of the second, seconds at $10A7E6.
        | On 2026-10-29: $108422, the damage taken by P1 (0 at the round, rises with hits; forced to 0).
        JEU     0x0251, 0xB157, 16
        CHEAT   "INFINITE TIME",   0x10A7E7, 1, 0x32
        CHEAT   "P1 INFINITE LIFE", 0x108422, 1, 0x00
        CHEAT   "P1 INF ENERGY", 0x108239, 1, 0x65
        CHEAT   "P2 INF ENERGY", 0x108439, 1, 0x65
        CHEAT   "P1 MAXIMUM POWER", 0x1081E8, 1, 0x90
        CHEAT   "P1 STUN GAUGE NE", 0x108244, 1, 0x10
        CHEAT   "P2 MAXIMUM POWER", 0x1083E8, 1, 0x90
        CHEAT   "P2 STUN GAUGE NE", 0x108444, 1, 0x10
        CHEAT   "9999 BATTLE POIN", 0x10EC78, 2, 0x9999
        CHEAT   "9999 BATTLE PO 2", 0x10DAA2, 2, 0x9999
        CHEAT   "P1 INF STRIKERS", 0x1082E3, 1, 0x05
        CHEAT   "P1 NEVER GET DIZ", 0x10823F, 1, 0x65
        CHEAT   "P1 NEVER GET GUA", 0x108247, 1, 0x65
        CHEAT   "P1 GUARD BAR NEV", 0x10824C, 1, 0x10
        CHEAT   "P1 AUTOGUARD", 0x108195, 1, 0x0A
        CHEAT   "P1 ALL MOVES COM", 0x10817D, 1, 0x0C
        | THE KING OF FIGHTERS 2000: the seconds, BCD.
        JEU     0x0257, 0xE65C, 16
        CHEAT   "INFINITE TIME",   0x10A7E6, 1, 0x60
        CHEAT   "INF SELECTION TI", 0x1085D3, 1, 0x0F
        CHEAT   "P1 INF ENERGY", 0x108239, 1, 0x66
        CHEAT   "P2 INF ENERGY", 0x108439, 1, 0x66
        CHEAT   "P1 MAXIMUM POWER", 0x1081E8, 1, 0x90
        CHEAT   "P1 STUN GAUGE NE", 0x108244, 1, 0x10
        CHEAT   "P2 MAXIMUM POWER", 0x1083E8, 1, 0x90
        CHEAT   "P2 STUN GAUGE NE", 0x108444, 1, 0x10
        CHEAT   "MAI S BOOBS BOUN", 0x10A7F4, 1, 0x00
        CHEAT   "9999 BATTLE POIN", 0x10EC78, 2, 0x9999
        CHEAT   "9999 BATTLE PO 2", 0x10DAA2, 2, 0x9999
        CHEAT   "P1 INF STRIKERS", 0x1082E3, 1, 0x05
        CHEAT   "P1 NEVER GET DIZ", 0x10823F, 1, 0x66
        CHEAT   "P1 NEVER GET GUA", 0x108247, 1, 0x66
        CHEAT   "P1 GUARD BAR NEV", 0x10824C, 1, 0x10
        CHEAT   "P2 INF STRIKERS", 0x1084E3, 1, 0x05
        | THE KING OF FIGHTERS 2002: the frame countdown of the second, seconds at $10A7D2.
        JEU     0x0265, 0xC423, 13
        CHEAT   "INFINITE TIME",   0x10A7D3, 1, 0x32
        CHEAT   "P1 INF ENERGY", 0x108239, 1, 0x66
        CHEAT   "P2 INF ENERGY", 0x108439, 1, 0x66
        CHEAT   "P1 MAXIMUM POWER", 0x1082E3, 1, 0x05
        CHEAT   "P1 INF STUN GAUG", 0x10823F, 1, 0x66
        CHEAT   "P1 NEAR-INSTANT", 0x108244, 1, 0x10
        CHEAT   "P2 MAXIMUM POWER", 0x1084E3, 1, 0x05
        CHEAT   "P2 INF STUN GAUG", 0x10843F, 1, 0x66
        CHEAT   "P2 NEAR-INSTANT", 0x108444, 1, 0x10
        CHEAT   "P1 INF GUARD BAR", 0x108247, 1, 0x66
        CHEAT   "P1 NEAR-INSTAN 2", 0x10824C, 1, 0x22
        CHEAT   "P2 INF GUARD BAR", 0x108447, 1, 0x66
        CHEAT   "P2 NEAR-INSTAN 2", 0x10844C, 1, 0x22
        | SAMURAI SHODOWN: the seconds, BCD, 99 at start.
        JEU     0x0045, 0x39BC, 1
        CHEAT   "INFINITE TIME",   0x100A08, 1, 0x99
        | SAMURAI SHODOWN II: the seconds, BCD, 99 at start.
        JEU     0x0063, 0xB2EF, 1
        CHEAT   "INFINITE TIME",   0x100AC6, 1, 0x99
        | SAMURAI SHODOWN IV: the frame countdown of the second ($3C), seconds at $108368.
        JEU     0x0222, 0x2643, 8
        CHEAT   "INFINITE TIME",   0x108369, 1, 0x3C
        CHEAT   "INFINITE TIME 2", 0x108368, 1, 0x61
        CHEAT   "P1 INF ENERGY", 0x108443, 1, 0xFC
        CHEAT   "P2 INF ENERGY", 0x108643, 1, 0xFC
        CHEAT   "P1 INF POWER", 0x10844C, 1, 0x40
        CHEAT   "P1 POWER GAUGE", 0x108558, 1, 0x00
        CHEAT   "P2 INF POWER", 0x10864C, 1, 0x40
        CHEAT   "P2 POWER GAUGE", 0x108758, 1, 0x00
        | SAMURAI SHODOWN V: the seconds, BCD.
        JEU     0x0270, 0x1B2F, 11
        CHEAT   "INFINITE TIME",   0x10836A, 1, 0x60
        CHEAT   "P1 INF ENERGY", 0x108445, 1, 0x7D
        CHEAT   "P1 BLUE ENRG GAU", 0x1085FE, 1, 0x7C
        CHEAT   "P2 INF ENERGY", 0x108655, 1, 0x7D
        CHEAT   "P2 BLUE ENRG GAU", 0x10880E, 1, 0x7C
        CHEAT   "P1 MAXIMUM POWER", 0x10844E, 1, 0x40
        CHEAT   "P1 MAX SWORD POW", 0x1085F8, 1, 0x78
        CHEAT   "P1 LONGER SWORD", 0x108554, 1, 0x82
        CHEAT   "P2 MAXIMUM POWER", 0x10865E, 1, 0x40
        CHEAT   "P2 MAX SWORD POW", 0x108808, 1, 0x78
        CHEAT   "P2 LONGER SWORD", 0x108764, 1, 0x82
        | SAMURAI SHODOWN V SPECIAL: the seconds, BCD.
        JEU     0x0272, 0x1851, 12
        CHEAT   "INFINITE TIME",   0x10836A, 1, 0x60
        CHEAT   "P1 INFINITE LIFE", 0x10854E, 1, 0x11
        CHEAT   "P1 INF ENERGY", 0x108445, 1, 0x7D
        CHEAT   "P1 BLUE ENRG GAU", 0x1085FE, 1, 0x7C
        CHEAT   "P2 INF ENERGY", 0x108655, 1, 0x7D
        CHEAT   "P2 BLUE ENRG GAU", 0x10880E, 1, 0x7C
        CHEAT   "P1 MAXIMUM POWER", 0x10844E, 1, 0x40
        CHEAT   "P1 MAX SWORD POW", 0x1085F8, 1, 0x78
        CHEAT   "P1 LONGER SWORD", 0x108554, 1, 0x82
        CHEAT   "P2 MAXIMUM POWER", 0x10865E, 1, 0x40
        CHEAT   "P2 MAX SWORD POW", 0x108808, 1, 0x78
        CHEAT   "P2 LONGER SWORD", 0x108764, 1, 0x82
        | FATAL FURY 3: the seconds, BCD.
        JEU     0x0069, 0xEF51, 6
        CHEAT   "INFINITE TIME",   0x105680, 1, 0x60
        CHEAT   "P1 INF ENERGY", 0x100489, 1, 0x78
        CHEAT   "P2 INF ENERGY", 0x100589, 1, 0x78
        CHEAT   "EASY SUPERS", 0x10E001, 1, 0x01
        CHEAT   "P1 INFINITE SDMS", 0x1004A2, 1, 0x00
        CHEAT   "P2 INFINITE SDMS", 0x1005A2, 1, 0x00
        | FATAL FURY SPECIAL: the seconds, BCD.
        JEU     0x0058, 0x189F, 3
        CHEAT   "INFINITE TIME",   0x10092A, 1, 0x60
        CHEAT   "P1 INF ENERGY", 0x10049A, 1, 0x60
        CHEAT   "P2 INF ENERGY", 0x10059A, 1, 0x60
        | THE LAST BLADE: the seconds, BCD.
        JEU     0x0234, 0xB3E9, 1
        CHEAT   "INFINITE TIME",   0x10E32B, 1, 0x60
        | ART OF FIGHTING 2: the seconds, BCD, the same cell as aof.
        JEU     0x0056, 0x2DFA, 5
        CHEAT   "INFINITE TIME",   0x108406, 1, 0x60
        CHEAT   "P1 INF ENERGY", 0x1092ED, 1, 0x60
        CHEAT   "P2 INF ENERGY", 0x1093ED, 1, 0x60
        CHEAT   "P1 INF POWER", 0x1094A4, 1, 0x80
        CHEAT   "P2 INF POWER", 0x1095A4, 1, 0x80
        | WORLD HEROES: the seconds, BCD, 99 at start.
        JEU     0x0053, 0x783E, 3
        CHEAT   "INFINITE TIME",   0x10B008, 1, 0x99
        CHEAT   "P1 INF ENERGY", 0x10600A, 1, 0x68, 0x10602E, 1, 0x68
        CHEAT   "P2 INF ENERGY", 0x10610A, 1, 0x68, 0x10612E, 1, 0x68
        | WORLD HEROES 2: the seconds, BCD, 99 at start.
        JEU     0x0057, 0x1419, 5
        CHEAT   "INFINITE TIME",   0x10C109, 1, 0x99
        CHEAT   "P1 INF ENERGY", 0x10600C, 2, 0x7676
        CHEAT   "P2 INF ENERGY", 0x10610C, 2, 0x7676
        CHEAT   "DEATHMATCH PDOWN", 0x106111, 1, 0x00
        CHEAT   "DEATHMATCH CPU D", 0x106011, 1, 0x06
        | SNK VS. CAPCOM: the seconds, BCD.
        JEU     0x0269, 0xD6D2, 12
        CHEAT   "INFINITE TIME",   0x10AC14, 1, 0x60
        CHEAT   "INFINITE TIME 2", 0x10AC15, 1, 0x5B
        CHEAT   "INF TIME IN PSEL", 0x10CD6C, 1, 0x0F
        CHEAT   "P1 INF ENERGY", 0x10A239, 1, 0xE0
        CHEAT   "P2 INF ENERGY", 0x10A4B9, 1, 0xE0
        CHEAT   "P1 NO POWER", 0x10A1E8, 1, 0x00, 0x10A1E9, 1, 0x00
        CHEAT   "P2 NO POWER", 0x10A468, 1, 0x00, 0x10A469, 1, 0x00
        CHEAT   "STAGE 1 CLEAR TO", 0x10ABDD, 1, 0x08
        CHEAT   "P1 INF EXCEED", 0x10D01A, 2, 0x0258
        CHEAT   "P1 INF GUARD", 0x10A247, 1, 0x70
        CHEAT   "P2 INF EXCEED", 0x10D1DE, 2, 0x0258
        CHEAT   "P2 INF GUARD", 0x10A4C7, 1, 0x70
        | BREAKERS REVENGE: the seconds, binary, 99 at start.
        JEU     0x0245, 0xB255, 7
        CHEAT   "INFINITE TIME",   0x107C27, 1, 0x63
        CHEAT   "P1 INF ENERGY", 0x10734E, 1, 0x1E
        CHEAT   "P2 INF ENERGY", 0x1078AE, 1, 0x1E
        CHEAT   "P1 INFINITE CHI", 0x107361, 1, 0x03
        CHEAT   "P1 PLAY WITH BAI", 0x107171, 1, 0x08
        CHEAT   "P2 INFINITE CHI", 0x1078C1, 1, 0x03
        CHEAT   "P2 PLAY WITH BAI", 0x1076D1, 1, 0x08
        | KARNOV'S REVENGE: the seconds, binary, 99 at start.
        | On 2026-10-29: $103A74, the high byte of P1's life word ($0FFF at the highest).
        JEU     0x0066, 0x6A32, 4
        CHEAT   "INFINITE TIME",   0x103A70, 1, 0x63
        CHEAT   "P1 INFINITE LIFE", 0x103A74, 1, 0x0F
        CHEAT   "P1 INF ENERGY", 0x1037B7, 1, 0xFF, 0x1037B8, 1, 0xFF
        CHEAT   "P2 INF ENERGY", 0x1039B7, 1, 0xFF, 0x1039B8, 1, 0xFF
        | DOUBLE DRAGON: the seconds, BCD, 99 at start.
        JEU     0x0082, 0x1CB9, 4
        CHEAT   "INFINITE TIME",   0x102242, 1, 0x99
        CHEAT   "INF CHAR SELECTI", 0x105BA3, 1, 0x78
        CHEAT   "P1 INF ENERGY", 0x100450, 1, 0x00
        CHEAT   "P2 INF ENERGY", 0x100550, 1, 0x00
        | METAL SLUG 2: the lives, 2 at the start of the game (HUD 1UP=2).
        | On 2026-10-29, by known value (the HUD read at two frames, then the bytes that equal what it
        | displays): the mission time $1013B4, binary, 60. On 2026-10-30, by expected sequence in the
        | bomb scenario: the bombs $10C348, 10 at start ($10127C is only a copy of it).
        JEU     0x0241, 0xBE57, 13
        CHEAT   "INFINITE LIVES",  0x101276, 1, 0x02
        CHEAT   "INFINITE TIME",   0x1013B4, 1, 0x3C
        CHEAT   "INFINITE BOMBS",  0x10C348, 1, 0x0A
        CHEAT   "P1 INF VEHICLE E", 0x10E89B, 1, 0x30
        CHEAT   "P2 INF VEHICLE E", 0x10E8BF, 1, 0x30
        CHEAT   "P2 INF LIVES", 0x10131E, 1, 0x63
        CHEAT   "P1 INVINCIBILITY", 0x101517, 1, 0x77
        CHEAT   "P2 INVINCIBILITY", 0x1015BF, 1, 0x77
        CHEAT   "P1 INFINITE AMMO", 0x10C34D, 1, 0xFF
        CHEAT   "P2 INF BOMBS", 0x10C349, 1, 0x63
        CHEAT   "P2 INFINITE AMMO", 0x10C34F, 1, 0xFF
        CHEAT   "P1 INF CANNON", 0x10E8A1, 1, 0x0A
        CHEAT   "P2 INF CANNON", 0x10E8C5, 1, 0x0A
        | METAL SLUG X: the lives, 2 at start.
        JEU     0x0250, 0x92D4, 13
        CHEAT   "INFINITE LIVES",  0x101288, 1, 0x02
        CHEAT   "INFINITE TIME", 0x1013DE, 1, 0x5A
        CHEAT   "P1 INF VEHICLE E", 0x10C621, 1, 0x30
        CHEAT   "P2 INF VEHICLE E", 0x10C645, 1, 0x30
        CHEAT   "P2 INF LIVES", 0x101338, 1, 0x02
        CHEAT   "P1 INVINCIBILITY", 0x101523, 1, 0x40, 0x101549, 1, 0x99
        CHEAT   "P2 INVINCIBILITY", 0x1015D3, 1, 0x40, 0x1015F9, 1, 0x71
        CHEAT   "P1 INFINITE AMMO", 0x10C725, 1, 0xFF
        CHEAT   "P1 INF BOMBS", 0x10C720, 1, 0x63
        CHEAT   "P2 INFINITE AMMO", 0x10C727, 1, 0xFF
        CHEAT   "P2 INF BOMBS", 0x10C721, 1, 0x14
        CHEAT   "P1 INF VEHICLE C", 0x10C627, 1, 0x63
        CHEAT   "P2 INF VEHICLE C", 0x10C64B, 1, 0x19
        | METAL SLUG 3: the lives, 2 at start. The bombs (2026-10-30, bomb scenario): $10EAF5, 10.
        JEU     0x0256, 0xE095, 13
        CHEAT   "INFINITE LIVES",  0x1002BB, 1, 0x02
        CHEAT   "INFINITE BOMBS",  0x10EAF5, 1, 0x0A
        CHEAT   "INFINITE TIME", 0x10ED78, 1, 0x99
        CHEAT   "P2 INF LIVES", 0x10036B, 1, 0x64
        CHEAT   "P1 INVINCIBILITY", 0x100581, 1, 0x02
        CHEAT   "P2 INVINCIBILITY", 0x100631, 1, 0x02
        CHEAT   "P1 INFINITE AMMO", 0x10EAFA, 2, 0x03E7
        CHEAT   "P1 NO BOMB THROW", 0x10EAF0, 1, 0x00
        CHEAT   "P2 INFINITE AMMO", 0x10EB08, 2, 0x03E7
        CHEAT   "P2 INF BOMBS", 0x10EB03, 1, 0x63
        CHEAT   "P2 NO BOMB THROW", 0x10EAFE, 1, 0x00
        CHEAT   "P1 15 PRISONERS", 0x10ED05, 1, 0x0F
        CHEAT   "P2 15 PRISONERS", 0x10ED0D, 1, 0x0F
        | METAL SLUG 4: the lives, 2 at start.
        | On 2026-10-29, by known value: the mission time $10ED5C, BCD, 60. The bombs
        | (2026-10-30, bomb scenario): $10EDED, 10.
        JEU     0x0263, 0xD875, 14
        CHEAT   "INFINITE LIVES",  0x100A89, 1, 0x02
        CHEAT   "INFINITE TIME",   0x10ED5C, 1, 0x60
        CHEAT   "P2 INF. LIVES",   0x100CFC, 1, 0x02
        CHEAT   "INFINITE BOMBS",  0x10EDED, 1, 0x0A
        CHEAT   "P2 INF LIVES", 0x100B39, 1, 0x09
        CHEAT   "P1 INVINCIBILITY", 0x100D17, 1, 0x40
        CHEAT   "P1 INVINCIBLE FI", 0x100D41, 1, 0x01
        CHEAT   "P2 INVINCIBILITY", 0x100DC7, 1, 0x40
        CHEAT   "P2 INVINCIBLE FI", 0x100DF1, 1, 0x01
        CHEAT   "P1 NO BOMB THROW", 0x10EDE7, 1, 0x00
        CHEAT   "P2 INF BOMBS", 0x10EDFD, 1, 0x63
        CHEAT   "P2 NO BOMB THROW", 0x10EDF7, 1, 0x00
        CHEAT   "P1 INFINITE ARMS", 0x10EDF2, 2, 0xFFFF
        CHEAT   "P2 INFINITE ARMS", 0x10EE02, 2, 0xFFFF
        | METAL SLUG 5: the lives, 2 at start. The bombs (2026-10-30, bomb scenario): $10D457, 10.
        JEU     0x0268, 0x1581, 15
        CHEAT   "INFINITE LIVES",  0x100A41, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x1050C2, 1, 0x05
        CHEAT   "INFINITE BOMBS",  0x10D457, 1, 0x0A
        CHEAT   "INFINITE TIME", 0x10D67E, 1, 0x99
        CHEAT   "INF CHAR SELECT", 0x10095E, 1, 0x63
        CHEAT   "P2 INF LIVES", 0x100B05, 1, 0x09
        CHEAT   "P1 INVINCIBILITY", 0x100D49, 1, 0x01
        CHEAT   "P2 INVINCIBILITY", 0x100E39, 1, 0x01
        CHEAT   "P2 INF BOMBS", 0x10D467, 1, 0x63
        CHEAT   "P1 INF BULLETS", 0x10D45C, 2, 0xFFFF
        CHEAT   "P1 INF CANNONS", 0x10DCDF, 1, 0x63
        CHEAT   "P1 PIG", 0x100D56, 1, 0x01
        CHEAT   "P1 15 PRISONERS", 0x10DDDD, 1, 0x0F
        CHEAT   "P2 INF BULLETS", 0x10D46C, 2, 0xFFFF
        CHEAT   "P2 INF CANNONS", 0x10DD0B, 1, 0x63
        | PULSTAR: the lives, 2 at start.
        JEU     0x0089, 0xA232, 4
        CHEAT   "INFINITE LIVES",  0x10132A, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x10132B, 1, 0x02
        CHEAT   "MAXIMUM SPEED", 0x1017DE, 1, 0x07
        CHEAT   "FULL CHARGE", 0x101696, 1, 0xFF
        | BLAZING STAR: the lives, 2 at start.
        JEU     0x0239, 0xA454, 4
        CHEAT   "INFINITE LIVES",  0x101BA1, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x101BA3, 1, 0x02
        CHEAT   "P1 MAX POWER", 0x101B79, 1, 0x03
        CHEAT   "P2 MAX POWER", 0x101B7B, 1, 0x03
        | ANDRO DUNOS: the lives, 3 at start.
        JEU     0x0049, 0x03FF, 13
        CHEAT   "INFINITE LIVES",  0x100343, 1, 0x03
        CHEAT   "P2 INF LIVES", 0x100383, 1, 0x03
        CHEAT   "P1 MAX SHOT POW", 0x100350, 1, 0x07
        CHEAT   "P1 MAX BOMB POW", 0x100351, 1, 0x05
        CHEAT   "P1 MAX MISSILE P", 0x100352, 1, 0x08
        CHEAT   "P1 MAX UNIT POW", 0x100353, 1, 0x08
        CHEAT   "P2 MAX SHOT POW", 0x100390, 1, 0x07
        CHEAT   "P2 MAX BOMB POW", 0x100391, 1, 0x05
        CHEAT   "P2 MAX MISSILE P", 0x100392, 1, 0x08
        CHEAT   "P2 MAX UNIT POW", 0x100393, 1, 0x08
        CHEAT   "P1 INF CONTINUES", 0x1000D8, 1, 0xFF
        CHEAT   "P1 PERFECT BONUS", 0x1001A7, 1, 0x07, 0x1001A9, 1, 0x00
        CHEAT   "P2 INF CONTINUES", 0x1000D9, 1, 0xFF
        | GHOST PILOTS: the lives, 3 at start.
        JEU     0x0020, 0xA0C5, 9
        CHEAT   "INFINITE LIVES",  0x103F37, 1, 0x03
        CHEAT   "P2 INF. LIVES",   0x103FB7, 1, 0x03
        CHEAT   "P1 MAX WEAP POW", 0x103F3D, 1, 0x1C
        CHEAT   "P2 MAX WEAP POW", 0x103FBD, 1, 0x1C
        CHEAT   "P1 INF BOMBS", 0x103F40, 1, 0x09
        CHEAT   "P2 INF BOMBS", 0x103FC0, 1, 0x09
        CHEAT   "INF CONTINUES", 0x10A689, 1, 0x64
        CHEAT   "P1 MAXIMUM STARS", 0x103F44, 1, 0x99
        CHEAT   "P2 MAXIMUM STARS", 0x103FC4, 1, 0x99
        | LAST RESORT: the lives, 2 at start.
        JEU     0x0024, 0x03A4, 16
        CHEAT   "INFINITE LIVES",  0x108030, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x107596, 1, 0x02
        CHEAT   "P2 INF LIVES", 0x108031, 1, 0x02
        CHEAT   "P1 INVINCIBILITY", 0x104229, 1, 0x7D
        CHEAT   "P2 INVINCIBILITY", 0x1042A9, 1, 0x7D
        CHEAT   "P1 MAXIMUM POWER", 0x104265, 1, 0x04
        CHEAT   "P2 MAXIMUM POWER", 0x1042E5, 1, 0x04
        CHEAT   "P1 MAXIMUM SPEED", 0x104267, 1, 0x05
        CHEAT   "P1 INFINITE SHOT", 0x10425E, 2, 0x0000
        CHEAT   "P1 INF POD SHOT", 0x104260, 2, 0x0000
        CHEAT   "P1 INF LASER", 0x104258, 2, 0x0000
        CHEAT   "P1 INF HOMING", 0x10424C, 2, 0x0000
        CHEAT   "P1 INF GRENADE", 0x10425C, 2, 0x0000
        CHEAT   "P2 MAXIMUM SPEED", 0x1042E7, 1, 0x05
        CHEAT   "P2 INFINITE SHOT", 0x1042DE, 2, 0x0000
        CHEAT   "P2 INF POD SHOT", 0x1042E0, 2, 0x0000
        | MAGICIAN LORD: the lives, 2 at start.
        JEU     0x0005, 0x9330, 9
        CHEAT   "INFINITE LIVES",  0x103B00, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x103C00, 1, 0x02
        CHEAT   "INFINITE TIME", 0x1039FC, 2, 0x0005, 0x1039FE, 2, 0xDBFF
        CHEAT   "P1 INF ENERGY", 0x103B07, 1, 0x05
        CHEAT   "P2 INF ENERGY", 0x103C07, 1, 0x05
        CHEAT   "P1 INVINCIBILITY", 0x103B09, 1, 0x9F
        CHEAT   "P2 INVINCIBILITY", 0x103C09, 1, 0x9F
        CHEAT   "P1 INF POWER", 0x103B04, 1, 0x02
        CHEAT   "P2 INF POWER", 0x103C04, 1, 0x02
        | STRIKERS 1945 PLUS: the lives, 2 at start.
        JEU     0x0254, 0xD5FF, 11
        CHEAT   "INFINITE LIVES",  0x1000E9, 1, 0x02
        CHEAT   "P2 INF LIVES", 0x100145, 1, 0x09
        CHEAT   "P1 MAX FIREPOWER", 0x1000ED, 1, 0x04
        CHEAT   "P2 MAX FIREPOWER", 0x100149, 1, 0x04
        CHEAT   "P1 INF BOMBS", 0x1000EB, 1, 0x09
        CHEAT   "P1 INSTANT BOMBE", 0x100109, 1, 0x00
        CHEAT   "P2 INF BOMBS", 0x100147, 1, 0x09
        CHEAT   "P2 INSTANT BOMBE", 0x100165, 1, 0x00
        CHEAT   "MISSION 1 LEVEL", 0x1002FB, 1, 0x00
        CHEAT   "P1 INF SUPER SHO", 0x1000F5, 1, 0x08, 0x1000F1, 1, 0x08
        CHEAT   "P2 INF SUPER SHO", 0x100151, 1, 0x08, 0x10014D, 1, 0x08
        | ZED BLADE: the lives, 3 at start.
        JEU     0x0076, 0x9553, 16
        CHEAT   "INFINITE LIVES",  0x100229, 1, 0x03
        CHEAT   "P2 INF. LIVES",   0x100029, 1, 0x03
        CHEAT   "INF SELECT TIME", 0x109024, 1, 0x09
        CHEAT   "P1 INVINCIBILITY", 0x10023E, 1, 0x01
        CHEAT   "P2 INVINCIBILITY", 0x10003E, 1, 0x01
        CHEAT   "P1 INF BOMBS", 0x10022F, 1, 0x03
        CHEAT   "P1 HYPERBOMB", 0x10021D, 1, 0x01
        CHEAT   "P2 INF BOMBS", 0x10002F, 1, 0x03
        CHEAT   "P2 HYPERBOMB", 0x10001D, 1, 0x01
        CHEAT   "P1 INF CONTINUES", 0x10909E, 1, 0x65
        CHEAT   "P1 MAX SHOT", 0x100261, 1, 0x03
        CHEAT   "P1 MAX MISSILE", 0x100265, 1, 0x01
        CHEAT   "P1 MAX REAR SHOT", 0x100269, 1, 0x03
        CHEAT   "P2 INF CONTINUES", 0x10909F, 1, 0x65
        CHEAT   "P2 MAX SHOT", 0x100061, 1, 0x03
        CHEAT   "P2 MAX MISSILE", 0x100065, 1, 0x03
        | THE LIVES OF THE ACTION GAMES, 2026-10-29 (`bench/cheats-recherche.py`, sub-command action:
        | a record of the action scenario filtered, then each candidate forced alone from frame 700,
        | against a witness run). Kept: the cell whose forcing removes every game over in 12,000 frames
        | without freezing the picture, when the witness run loses its game; the value is the highest of
        | the record. Records and other candidates: `measured/2026-10-29-cheats-action-recherche.tsv`.
        | The witness-run frames cited below are those of the forcing by lua, not those of the menu.
        | BANG BANG BUSTERS: the lives, 4 at the highest; the witness run loses the game at frame 4860.
        JEU     0x0071, 0xE928, 2
        CHEAT   "INFINITE LIVES",  0x106907, 1, 0x04
        CHEAT   "P2 INF. LIVES",   0x106967, 1, 0x04
        | BLUE'S JOURNEY: the lives, 2 at the highest; the witness run loses the game at frame 3846.
        JEU     0x0022, 0xC32D, 16
        CHEAT   "INFINITE LIVES",  0x107000, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x107400, 1, 0x02
        CHEAT   "INF SHOP TIME", 0x10783F, 1, 0x09
        CHEAT   "P1 INF ENERGY", 0x107011, 1, 0x05, 0x107020, 1, 0x05
        CHEAT   "P1 1 COCOON FOR", 0x107017, 1, 0x04
        CHEAT   "P2 INF ENERGY", 0x107411, 1, 0x05, 0x107420, 1, 0x05
        CHEAT   "P2 1 COCOON FOR", 0x107417, 1, 0x04
        CHEAT   "P1 INVINCIBILITY", 0x107009, 1, 0x7F
        CHEAT   "P2 INVINCIBILITY", 0x107409, 1, 0x7F
        CHEAT   "P1 INF MONEY", 0x107010, 1, 0xFF, 0x10701B, 1, 0xFF
        CHEAT   "P1 NEVER LOSE FL", 0x10701C, 1, 0x01
        CHEAT   "P1 NEVER GET CUR", 0x107019, 1, 0x00
        CHEAT   "P1 THE CLUB", 0x10701A, 1, 0x01
        CHEAT   "P1 THE SPIKES", 0x107013, 1, 0x01
        CHEAT   "P1 THE SPRING", 0x107014, 1, 0x01
        CHEAT   "P1 THE SWIN FIN", 0x107015, 1, 0x01
        | CAPTAIN TOMADAY: the lives, 2 at the highest; the witness run loses the game at frame 3831.
        JEU     0x0249, 0xE6CD, 9
        CHEAT   "INFINITE LIVES",  0x104026, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x101399, 1, 0x02
        CHEAT   "P1 INF LIVES", 0x10137D, 1, 0x0A
        CHEAT   "P1 INVINCIBILITY", 0x10413D, 1, 0x07
        CHEAT   "P2 INVINCIBILITY", 0x10432D, 1, 0x07
        CHEAT   "P1 MAX POW RIGHT", 0x104201, 1, 0x05
        CHEAT   "P1 MAX POW LEFT", 0x1041AB, 1, 0x05
        CHEAT   "P2 MAX POW RIGHT", 0x1043F1, 1, 0x05
        CHEAT   "P2 MAX POW LEFT", 0x10439B, 1, 0x05
        | GANRYU: the lives, 3 at the highest; the witness run loses the game at frame 4912. The time,
        | $100453, binary, 99 at the highest: forced alone, TIME stays at 99 on the HUD.
        JEU     0x0252, 0x0111, 6
        CHEAT   "INFINITE LIVES",  0x1004A1, 1, 0x03
        CHEAT   "INFINITE TIME",   0x100453, 1, 0x63
        CHEAT   "P2 INF LIVES", 0x1004C1, 1, 0x07
        CHEAT   "INVINCIBILITY", 0x109D11, 1, 0x01
        CHEAT   "P1 INF WEAPONS", 0x100497, 1, 0x63
        CHEAT   "P2 INF WEAPONS", 0x1004B7, 1, 0x63
        | NINJA COMBAT: the lives, 3 at the highest; the witness run loses the game at frame 5956.
        JEU     0x0009, 0x8C0D, 14
        CHEAT   "INFINITE LIVES",  0x102402, 1, 0x03
        CHEAT   "P1 INFINITE TIME", 0x101818, 2, 0x7FFF
        CHEAT   "P2 INFINITE TIME", 0x101828, 2, 0x7FFF
        CHEAT   "P1 INF ENERGY", 0x100632, 1, 0x20
        CHEAT   "P2 INF ENERGY", 0x100682, 1, 0x20
        CHEAT   "P2 INF LIVES", 0x102403, 1, 0x0A
        CHEAT   "P1 INVINCIBILITY", 0x10261B, 1, 0x01, 0x10261E, 1, 0x02
        CHEAT   "P2 INVINCIBILITY", 0x10266B, 1, 0x01, 0x10266E, 1, 0x02
        CHEAT   "P1 MAX FIRE POW", 0x1018C0, 1, 0x02, 0x10063B, 1, 0x02
        CHEAT   "P2 MAX FIRE POW", 0x1018E0, 1, 0x02, 0x10068B, 1, 0x02
        CHEAT   "P1 INF CONTINUES", 0x101811, 1, 0x64
        CHEAT   "P1 MAXIMUM SPEED", 0x1018C1, 1, 0x02, 0x102635, 1, 0x02
        CHEAT   "P2 INF CONTINUES", 0x101821, 1, 0x64
        CHEAT   "P2 MAXIMUM SPEED", 0x1018E1, 1, 0x02, 0x102685, 1, 0x02
        | NEO BOMBERMAN: the lives, 2 at the highest; the witness run loses the game at frame 2500.
        JEU     0x0093, 0x5602, 1
        CHEAT   "INFINITE LIVES",  0x101658, 1, 0x02
        | NEO MR. DO!: the lives, 2 at the highest; the witness run loses the game at frame 5227.
        JEU     0x0207, 0x94A1, 5
        CHEAT   "INFINITE LIVES",  0x10465B, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x10465D, 1, 0x02
        CHEAT   "INF EXTRA BONUS", 0x104257, 1, 0x63
        CHEAT   "P1 INVINCIBILITY", 0x100E55, 1, 0x02
        CHEAT   "P2 INVINCIBILITY", 0x100E71, 1, 0x02
        | PREHISTORIC ISLE 2: the lives, 3 at the highest; the witness run loses the game at frame 5119.
        JEU     0x0255, 0x8E0D, 10
        CHEAT   "INFINITE LIVES",  0x105055, 1, 0x03
        CHEAT   "P2 INF. LIVES",   0x1062D5, 1, 0x03
        CHEAT   "P1 INVINCIBILITY", 0x10507D, 1, 0x02
        CHEAT   "P2 INVINCIBILITY", 0x1062FD, 1, 0x02
        CHEAT   "P1 MAX POWER UP", 0x105076, 1, 0x10
        CHEAT   "P2 MAX POWER UP", 0x1062F6, 1, 0x10
        CHEAT   "P1 INF BOMBS", 0x105071, 1, 0x0A
        CHEAT   "P2 INF BOMBS", 0x1062F1, 1, 0x0A
        CHEAT   "P1 999 STARS", 0x10506A, 1, 0x03, 0x10506B, 1, 0xE7
        CHEAT   "P2 999 STARS", 0x1062EA, 1, 0x03, 0x1062EB, 1, 0xE7
        | SENGOKU 2: the lives, 3 at the highest; the witness run loses the game at frame 4646.
        JEU     0x0040, 0xCEF6, 12
        CHEAT   "INFINITE LIVES",  0x1001AF, 1, 0x03
        CHEAT   "P2 INF. LIVES",   0x1001B1, 1, 0x03
        CHEAT   "P1 INF NINJA MOR", 0x102D5F, 1, 0x3C
        CHEAT   "P1 INF OLD MAN M", 0x102D60, 1, 0x3C
        CHEAT   "P1 INF DOG MORPH", 0x102D61, 1, 0x3C
        CHEAT   "P2 INF NINJA MOR", 0x102E5F, 1, 0x3C
        CHEAT   "P2 INF OLD MAN M", 0x102E60, 1, 0x3C
        CHEAT   "P2 INF DOG MORPH", 0x102E61, 1, 0x3C
        CHEAT   "P1 INF ENERGY", 0x102CF3, 1, 0x06
        CHEAT   "P2 INF ENERGY", 0x102DF3, 1, 0x06
        CHEAT   "P1 PERMANENT WEA", 0x102D1E, 1, 0x10
        CHEAT   "P2 PERMANENT WEA", 0x102E1E, 1, 0x10
        | SENGOKU 3: the lives, 2 at the highest; the witness run loses the game at frame 7669.
        JEU     0x0261, 0x83B6, 15
        CHEAT   "INFINITE LIVES",  0x1083E1, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x1083FF, 1, 0x02
        CHEAT   "INFINITE TIME", 0x108457, 1, 0x63
        CHEAT   "INF SELECT TIME", 0x1083C6, 1, 0x09
        CHEAT   "P1 INF COMBO TIM", 0x1083DB, 1, 0x40
        CHEAT   "P2 INF COMBO TIM", 0x1083F9, 1, 0x40
        CHEAT   "P1 INF ENERGY", 0x102C19, 1, 0x60
        CHEAT   "P2 INF ENERGY", 0x102D13, 1, 0x60
        CHEAT   "P1 INVINCIBILITY", 0x102C5D, 1, 0x32
        CHEAT   "P2 INVINCIBILITY", 0x102D57, 1, 0x32
        CHEAT   "ENABLE ALL CHARS", 0x108417, 1, 0x01
        CHEAT   "P1 INF THROWING", 0x1083EB, 1, 0x09
        CHEAT   "P1 INF MAGIC", 0x1083E3, 1, 0x38
        CHEAT   "P2 INF THROWING", 0x108409, 1, 0x09
        CHEAT   "P2 INF MAGIC", 0x108401, 1, 0x38
        | SHOCK TROOPERS 2ND SQUAD: the lives, 3 at the highest; the witness run loses the game at
        | frame 4699.
        JEU     0x0246, 0x5240, 11
        CHEAT   "INFINITE LIVES",  0x10905B, 1, 0x03
        CHEAT   "P2 INF. LIVES",   0x10915B, 1, 0x03
        CHEAT   "INFINITE TIME", 0x108F7B, 1, 0x99
        CHEAT   "P1 INVINCIBILITY", 0x100127, 1, 0xFF
        CHEAT   "P2 INVINCIBILITY", 0x102127, 1, 0xFF
        CHEAT   "P1 MAX POWER LV3", 0x109021, 1, 0x24
        CHEAT   "P2 MAX POWER LV3", 0x109121, 1, 0x24
        CHEAT   "P1 INFINITE AMMO", 0x109016, 1, 0x40
        CHEAT   "P2 INFINITE AMMO", 0x109116, 1, 0x40
        CHEAT   "P1 INF GRENADES", 0x10901F, 1, 0x0A
        CHEAT   "P2 INF GRENADES", 0x10911F, 1, 0x0A
        | AERO FIGHTERS 2: the lives, 2 at the highest; the witness run loses the game at frame 6646.
        JEU     0x0075, 0xECD1, 10
        CHEAT   "INFINITE LIVES",  0x100615, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x100619, 1, 0x02
        CHEAT   "P1 INF LIVES", 0x10E43F, 1, 0x05
        CHEAT   "P2 INF LIVES", 0x10E4A1, 1, 0x05
        CHEAT   "P1 MAX FIRE POW", 0x10E443, 1, 0x03
        CHEAT   "P2 MAX FIRE POW", 0x10E4A5, 1, 0x03
        CHEAT   "P1 INF BOMBS", 0x10E457, 1, 0x03
        CHEAT   "P2 INF BOMBS", 0x10E4B9, 1, 0x03
        CHEAT   "P1 RAPID FIRE", 0x10E5C5, 1, 0x00
        CHEAT   "P2 RAPID FIRE", 0x10E5CA, 1, 0x00
        | AERO FIGHTERS 3: the lives, 2 at the highest; the witness run loses the game at frame 2517.
        JEU     0x0097, 0x63E9, 9
        CHEAT   "INFINITE LIVES",  0x10E89B, 1, 0x02
        CHEAT   "P2 INF LIVES", 0x10E8F1, 1, 0x05
        CHEAT   "P1 INVINCIBILITY", 0x10E8BF, 1, 0x01
        CHEAT   "P2 INVINCIBILITY", 0x10E915, 1, 0x01
        CHEAT   "P1 INF BOMBS", 0x10E8BA, 1, 0x03
        CHEAT   "P2 INF BOMBS", 0x10E910, 1, 0x03
        CHEAT   "ENEMIES CAN T FI", 0x10EA57, 1, 0x01
        CHEAT   "P1 RAPID FIRE", 0x10EA3C, 1, 0x00
        CHEAT   "P2 RAPID FIRE", 0x10EA42, 1, 0x00
        | SPIN MASTER: the lives, 2 at the highest; the witness run loses the game at frame 9562.
        JEU     0x0062, 0x915F, 8
        CHEAT   "INFINITE LIVES",  0x105015, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x10503D, 1, 0x02
        CHEAT   "P1 INF ENERGY", 0x105F62, 1, 0x05
        CHEAT   "P2 INF ENERGY", 0x106022, 1, 0x05
        CHEAT   "P1 INVINCIBILITY", 0x105F95, 1, 0x02
        CHEAT   "P2 INVINCIBILITY", 0x106055, 1, 0x02
        CHEAT   "P1 INF BOMBS", 0x105FBD, 1, 0x05
        CHEAT   "P2 INF BOMBS", 0x10607D, 1, 0x05
        | THE SUPER SPY: 8 at the highest; ASSUMED lives, perhaps the energy (the cheat removes the
        | game over); the witness run loses the game at frame 9666.
        JEU     0x0011, 0xB441, 4
        CHEAT   "INFINITE LIVES",  0x10181F, 1, 0x08
        CHEAT   "INF KNIFE POWER", 0x101878, 1, 0x10
        CHEAT   "INF PISTOL AMMO", 0x1017F6, 2, 0x0999
        CHEAT   "INF M. GUN AMMO", 0x101854, 2, 0x0999
        | TWINKLE STAR SPRITES: the lives, 3 at the highest; the witness run loses the game at frame
        | 9296. P2's (2026-10-30, P2 alone): $10D005; $100540, the cell ruled out on 2026-10-29, is
        | only a copy of it (game over under the cheat).
        JEU     0x0224, 0xC6FE, 9
        CHEAT   "INFINITE LIVES",  0x103745, 1, 0x03
        CHEAT   "P2 INF. LIVES",   0x10D005, 1, 0x03
        CHEAT   "P1 INF ENERGY", 0x10C014, 1, 0x28
        CHEAT   "P2 INF ENERGY", 0x10D014, 1, 0x28
        CHEAT   "P1 INF LIVES", 0x10C005, 1, 0x05
        CHEAT   "P1 INF POWER", 0x10C08A, 1, 0x30, 0x10C08B, 1, 0x00
        CHEAT   "P2 INF POWER", 0x10D08A, 1, 0x30, 0x10D08B, 1, 0x00
        CHEAT   "P1 INF BOMBS", 0x10C021, 1, 0x02
        CHEAT   "P2 INF BOMBS", 0x10D021, 1, 0x02
        | VIEWPOINT: the lives, 3 at the highest; the witness run loses the game at frame 5989.
        JEU     0x0051, 0x691F, 6
        CHEAT   "INFINITE LIVES",  0x108D99, 1, 0x03
        CHEAT   "P2 INF. LIVES",   0x1090ED, 1, 0x03
        CHEAT   "P1 INVINCIBILITY", 0x108D3C, 1, 0x08
        CHEAT   "P2 INVINCIBILITY", 0x109090, 1, 0x08
        CHEAT   "P1 FAST FULL CHA", 0x108D97, 1, 0x50
        CHEAT   "P2 FAST FULL CHA", 0x1090EB, 1, 0x50
        | ZUPAPA!: the lives, 3 at the highest; the witness run loses the game at frame 6482.
        JEU     0x0070, 0xEC13, 9
        CHEAT   "INFINITE LIVES",  0x1002C1, 1, 0x03
        CHEAT   "INF BONUS TIME", 0x101C16, 1, 0x1E
        CHEAT   "P2 INF LIVES", 0x1002C3, 1, 0x03
        CHEAT   "P1 INVINCIBILITY", 0x10A2DD, 1, 0x02
        CHEAT   "P2 INVINCIBILITY", 0x10A2E5, 1, 0x02
        CHEAT   "P1 SPEED UP", 0x10B4DD, 1, 0x28
        CHEAT   "P1 SUPER PUNCH", 0x10B4DE, 1, 0x01
        CHEAT   "P2 SPEED UP", 0x10B4E5, 1, 0x28
        CHEAT   "P2 SUPER PUNCH", 0x10B4E6, 1, 0x01
        | P1'S LIVES IN FIGHTING GAMES, 2026-10-29 (`bench/cheats-recherche.py` releve, then
        | bisect in an active or weak scenario: P1 hits a little, and wins on time when its life is
        | forced); P1's bars seen full on the HUD banners, P2's dented.
        | THE KING OF FIGHTERS '96: $108422, the damage taken by P1, forced to 0. The time, by known
        | value: $10A837, the frame countdown (forcing the seconds blocks the end of the round).
        JEU     0x0214, 0xEB0F, 13
        CHEAT   "P1 INFINITE LIFE", 0x108422, 1, 0x00
        CHEAT   "INFINITE TIME",   0x10A837, 1, 0x32
        CHEAT   "P1 INF ENERGY", 0x108239, 1, 0x67
        CHEAT   "P2 INF ENERGY", 0x108439, 1, 0x67
        CHEAT   "P1 STUN GAUGE NE", 0x108244, 1, 0x10
        CHEAT   "P2 STUN GAUGE NE", 0x108444, 1, 0x10
        CHEAT   "HIDDEN CHARS", 0x10E752, 1, 0x01
        CHEAT   "P1 NEVER GET DIZ", 0x10823F, 1, 0x67
        CHEAT   "P1 NEVER GET GUA", 0x108247, 1, 0x67
        CHEAT   "P1 GUARD BAR NEV", 0x10824C, 1, 0x10
        CHEAT   "P2 NEVER GET DIZ", 0x10843F, 1, 0x67
        CHEAT   "P2 NEVER GET GUA", 0x108447, 1, 0x67
        CHEAT   "P2 GUARD BAR NEV", 0x10844C, 1, 0x10
        | NINJA MASTER'S: $100050, P1's life, $D0 at the highest. The time: $10C021; the doubt of
        | 2026-10-25 (characters frozen under forcing) lifted on 2026-10-30: the game goes on, and only a
        | P1 that does not strike keeps the round endless (`measured/2026-10-30-cheats-table.tsv`).
        JEU     0x0217, 0x4720, 6
        CHEAT   "P1 INFINITE LIFE", 0x100050, 1, 0xD0
        CHEAT   "INFINITE TIME",   0x10C021, 1, 0x99
        CHEAT   "P2 INF ENERGY", 0x101050, 1, 0xD0
        CHEAT   "P1 INF POWER", 0x1000AE, 1, 0x60
        CHEAT   "P2 INF POWER", 0x1010AE, 1, 0x60
        CHEAT   "BOSS CODE", 0x10C007, 1, 0x01
        | RAGE OF THE DRAGONS: $1023E6, P1's life, $10 at the highest. The time, by known value:
        | $106B11, the seconds, binary.
        JEU     0x0264, 0x8D79, 11
        CHEAT   "P1 INFINITE LIFE", 0x1023E6, 1, 0x10
        CHEAT   "INFINITE TIME",   0x106B11, 1, 0x3C
        CHEAT   "INF CHAR SELECTI", 0x106BDE, 1, 0x02
        CHEAT   "P1 NO WAIT TIME", 0x1024E5, 1, 0x28
        CHEAT   "P2 NO WAIT TIME", 0x10236D, 1, 0x28
        CHEAT   "P1 INF ENRG ACTI", 0x1024CF, 1, 0xB4, 0x1024D3, 1, 0xB4
        CHEAT   "P1 INF ENRG INAC", 0x1027BF, 1, 0xB4, 0x1027C3, 1, 0xB4
        CHEAT   "P2 INF ENRG ACTI", 0x102357, 1, 0xB4, 0x10235B, 1, 0xB4
        CHEAT   "P2 INF ENRG INAC", 0x102647, 1, 0xB4, 0x10264B, 1, 0xB4
        CHEAT   "P1 INF POWER", 0x1024E3, 1, 0xD8
        CHEAT   "P2 INF POWER", 0x10236B, 1, 0xD8
        | THE TIMERS OF FIGHTING GAMES, 2026-10-29, by known value: the HUD's TIME read at
        | three frames, then the RAM bytes that equal these numbers at the same frames, each
        | forced alone; the timer's area computed on the pictures (the
        | pixels frozen under the cheat, changing in the witness run). Value: the highest of the record.
        | FIGHT FEVER: the seconds, BCD.
        JEU     0x0060, 0x06A2, 3
        CHEAT   "INFINITE TIME",   0x108110, 1, 0x99
        CHEAT   "P1 INF ENERGY", 0x10C602, 1, 0x78
        CHEAT   "P2 INF ENERGY", 0x10C702, 1, 0x78
        | MATRIMELEE: the seconds, binary.
        JEU     0x0266, 0x5F99, 5
        CHEAT   "INFINITE TIME",   0x10B90B, 1, 0x3C
        CHEAT   "P1 MAXIMUM POW", 0x10307D, 1, 0xF0
        CHEAT   "P2 MAXIMUM POW", 0x102EB1, 1, 0xF0
        CHEAT   "P1 SSS RANK", 0x10B84D, 1, 0x07
        CHEAT   "P2 SSS RANK", 0x10B87D, 1, 0x07
        | REAL BOUT FATAL FURY 2: the seconds, BCD.
        JEU     0x0240, 0x7F97, 9
        CHEAT   "INFINITE TIME",   0x107C28, 1, 0x60
        CHEAT   "P1 INF ENERGY", 0x10048B, 1, 0xC0
        CHEAT   "P2 INF ENERGY", 0x10058B, 1, 0xC0
        CHEAT   "P1 INF POWER", 0x1004BC, 1, 0x3C
        CHEAT   "P2 INF POWER", 0x1005BC, 1, 0x3C
        CHEAT   "P1 MOTION BLUR F", 0x1004CD, 1, 0x5F
        CHEAT   "P1 MAX KAISER WA", 0x1004FB, 1, 0x03
        CHEAT   "P2 MOTION BLUR F", 0x1005CD, 1, 0x5F
        CHEAT   "P2 MAX KAISER WA", 0x1005FB, 1, 0x03
        | SAMURAI SHODOWN III: the seconds, BCD.
        JEU     0x0087, 0xE4CB, 5
        CHEAT   "INFINITE TIME",   0x10849E, 1, 0x99
        CHEAT   "P1 INF ENERGY", 0x108573, 1, 0x80
        CHEAT   "P2 INF ENERGY", 0x108673, 1, 0x80
        CHEAT   "P1 INF POWER", 0x10857C, 1, 0x40
        CHEAT   "P2 INF POWER", 0x10867C, 1, 0x40
        | WORLD HEROES 2 JET: the seconds, BCD.
        JEU     0x0064, 0x8B26, 6
        CHEAT   "INFINITE TIME",   0x10C109, 1, 0x99
        CHEAT   "P1 INF ENERGY", 0x10600C, 2, 0x6060
        CHEAT   "P2 INF ENERGY", 0x10610C, 2, 0x6060
        CHEAT   "ALWAYS ROUND 1", 0x10C121, 1, 0x01
        CHEAT   "DEATHMATCH PDOWN", 0x106111, 1, 0x00
        CHEAT   "DEATHMATCH CPU D", 0x106011, 1, 0x06
        | KING OF THE MONSTERS 2: the seconds, BCD.
        JEU     0x0039, 0x9C61, 5
        CHEAT   "INFINITE TIME",   0x1013D2, 1, 0x70
        CHEAT   "P1 INF ENERGY", 0x101417, 1, 0x40
        CHEAT   "P2 INF ENERGY", 0x101517, 1, 0x40
        CHEAT   "P1 INF LIVES", 0x1013B8, 1, 0x09
        CHEAT   "P2 INF LIVES", 0x1013B9, 1, 0x09
        | THE TIMERS OF FIGHTING GAMES FOUND ON 2026-10-29 AND PROVED ON 2026-10-30: same
        | search; the catalogue judges them on the digits' pixels only (the scenery scrolls behind),
        | or earlier in the round. Value: the highest of the record.
        | ART OF FIGHTING 3.
        JEU     0x0096, 0xC5DF, 5
        CHEAT   "INFINITE TIME",   0x10DF0F, 1, 0x3C
        CHEAT   "P1 INF ENERGY", 0x100468, 1, 0x10, 0x100469, 1, 0x00
        CHEAT   "P2 INF ENERGY", 0x100568, 1, 0x10, 0x100569, 1, 0x00
        CHEAT   "P1 INF POWER", 0x10046A, 1, 0x10, 0x10046B, 1, 0x00
        CHEAT   "P2 INF POWER", 0x10056A, 1, 0x10, 0x10056B, 1, 0x00
        | BREAKERS.
        JEU     0x0230, 0x9C95, 7
        CHEAT   "INFINITE TIME",   0x107C0B, 1, 0x63
        CHEAT   "P1 INF ENERGY", 0x107332, 1, 0x1E
        CHEAT   "P2 INF ENERGY", 0x107892, 1, 0x1E
        CHEAT   "P1 INFINITE CHI", 0x107345, 1, 0x03
        CHEAT   "P1 PLAY WITH BAI", 0x107155, 1, 0x08
        CHEAT   "P2 INFINITE CHI", 0x1078A5, 1, 0x03
        CHEAT   "P2 PLAY WITH BAI", 0x1076B5, 1, 0x08
        | FATAL FURY 2.
        JEU     0x0047, 0xAED3, 3
        CHEAT   "INFINITE TIME",   0x10092A, 1, 0x90
        CHEAT   "P1 INF ENERGY", 0x1003CB, 1, 0x60
        CHEAT   "P2 INF ENERGY", 0x1004CB, 1, 0x60
        | THE KING OF FIGHTERS '98.
        JEU     0x0242, 0x8F29, 7
        CHEAT   "INFINITE TIME",   0x10A83B, 1, 0x32
        CHEAT   "P1 INF ENERGY", 0x108239, 1, 0x67
        CHEAT   "P2 INF ENERGY", 0x108439, 1, 0x67
        CHEAT   "P1 NEVER GET DIZ", 0x10823F, 1, 0x67
        CHEAT   "P1 NEVER GET GUA", 0x108247, 1, 0x67
        CHEAT   "P2 NEVER GET DIZ", 0x10843F, 1, 0x67
        CHEAT   "P2 NEVER GET GUA", 0x108447, 1, 0x67
        | SAVAGE REIGN.
        JEU     0x0059, 0xF782, 1
        CHEAT   "INFINITE TIME",   0x1084A8, 1, 0x60
        | GAROU: MARK OF THE WOLVES.
        JEU     0x0253, 0x6078, 7
        CHEAT   "INFINITE TIME",   0x107490, 1, 0x60
        CHEAT   "P1 INF ENERGY", 0x10048E, 1, 0x78
        CHEAT   "P2 INF ENERGY", 0x10058E, 1, 0x78
        CHEAT   "P1 INF POWER", 0x1004BE, 1, 0x80
        CHEAT   "P2 INF POWER", 0x1005BE, 1, 0x80
        CHEAT   "P1 INF CREDITS", 0x10E008, 1, 0x09
        CHEAT   "P2 INF CREDITS", 0x10E009, 1, 0x09
        | WORLD HEROES PERFECT.
        JEU     0x0090, 0x5FA2, 9
        CHEAT   "INFINITE TIME",   0x10C109, 1, 0x99
        CHEAT   "P1 INF ENERGY", 0x10600C, 2, 0xC0C0
        CHEAT   "P2 INF ENERGY", 0x10610C, 2, 0xC0C0
        CHEAT   "P1 INVINCIBLE PA", 0x1060D6, 2, 0x0009
        CHEAT   "P2 INVINCIBLE PA", 0x1061D6, 2, 0x0009
        CHEAT   "P1 MAXIMUM POWER", 0x106A16, 2, 0x00DF, 0x106A18, 2, 0x00DF
        CHEAT   "P2 MAXIMUM POWER", 0x106B16, 2, 0x00DF, 0x106B18, 2, 0x00DF
        CHEAT   "ALWAYS WINS", 0x10C123, 1, 0x0F
        CHEAT   "P1 ALWAYS WINS", 0x10C122, 1, 0x0F
        | THE LAST BLADE 2.
        JEU     0x0243, 0xB546, 3
        CHEAT   "INFINITE TIME",   0x10E595, 1, 0x61
        CHEAT   "P1 INVINCIBILITY", 0x10E4B2, 1, 0x01, 0x10E44C, 1, 0x01
        CHEAT   "P2 INVINCIBILITY", 0x10E4B3, 1, 0x01, 0x10E450, 1, 0x01
        | GOWCAIZER.
        JEU     0x0094, 0x4B34, 3
        CHEAT   "INFINITE TIME",   0x1062E1, 1, 0x3C
        CHEAT   "P1 INF ENERGY", 0x102D09, 1, 0x64
        CHEAT   "P2 INF ENERGY", 0x1035BF, 1, 0x64
        | THE TIMES OF ACTION GAMES BY EXPECTED SEQUENCE, 2026-10-29: the byte that follows exactly
        | v0, v0 − 1… from 30, 50, 59, 60, 90 or 99 (`bench/cheats-recherche.py`, filtre_suite), forced
        | alone; the digits' area computed on the pictures of the forcing.
        | BURNING FIGHT: the time, BCD, 60; slow, judged in the counter genre.
        JEU     0x0018, 0xA9E4, 7
        CHEAT   "INFINITE TIME",   0x10D002, 1, 0x60
        CHEAT   "INF CHAR SELECT", 0x103D72, 1, 0x99
        CHEAT   "P1 INF ENERGY", 0x100221, 1, 0xFF
        CHEAT   "P2 INF ENERGY", 0x1002A1, 1, 0xFF
        CHEAT   "P1 INF LIVES", 0x100230, 1, 0x09
        CHEAT   "P2 INF LIVES", 0x1002B0, 1, 0x09
        CHEAT   "INF CONTINUES", 0x103E78, 1, 0xFF
        | THE LIVES BY EXPECTED SEQUENCE IN THE JUMP SCENARIO, 2026-10-29: P1 moves forward jumping
        | without shooting (the user's idea, to die quickly); the byte that follows exactly 3, 2, 1…
        | (or from 1 to 5), forced alone from frame 700: no more game over, the witness run loses its own.
        | ALPHA MISSION II: the lives, 2 at start.
        JEU     0x0007, 0x799C, 10
        CHEAT   "INFINITE LIVES",  0x1010F2, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x1011F2, 1, 0x02
        CHEAT   "P1 SPEC WEAP POW", 0x1010DD, 1, 0x18
        CHEAT   "P2 SPEC WEAP POW", 0x1011DD, 1, 0x18
        CHEAT   "P1 MAXIMUM GOLD", 0x1010B0, 2, 0x9999
        CHEAT   "P1 RAPID FIRE LA", 0x10108D, 1, 0x00
        CHEAT   "P1 RAPID FIRE MI", 0x1010A6, 1, 0x00
        CHEAT   "P2 MAXIMUM GOLD", 0x1011B0, 2, 0x9999
        CHEAT   "P2 RAPID FIRE LA", 0x10118D, 1, 0x00
        CHEAT   "P2 RAPID FIRE MI", 0x1011A6, 1, 0x00
        | CROSSED SWORDS: the lives, 5 at start.
        JEU     0x0037, 0xB3BC, 10
        CHEAT   "INFINITE LIVES",  0x10405C, 1, 0x05
        CHEAT   "P2 INF. LIVES",   0x1040DC, 1, 0x05
        CHEAT   "P1 INF ENERGY", 0x10405B, 1, 0x32
        CHEAT   "P2 INF ENERGY", 0x1040DB, 1, 0x32
        CHEAT   "P1 MAX WEAP POW", 0x104052, 1, 0xFF
        CHEAT   "P2 MAX WEAP POW", 0x1040D2, 1, 0xFF
        CHEAT   "P1 INF CONTINUES", 0x106023, 1, 0x64
        CHEAT   "P1 INF MONEY", 0x104066, 1, 0xFF, 0x104067, 1, 0xFF
        CHEAT   "P2 INF CONTINUES", 0x106043, 1, 0x64
        CHEAT   "P2 INF MONEY", 0x1040E6, 1, 0xFF, 0x1040E7, 1, 0xFF
        | EIGHT MAN: the lives, 3 at start.
        JEU     0x0025, 0xBDFA, 15
        CHEAT   "INFINITE LIVES",  0x100CF7, 1, 0x03
        CHEAT   "P2 INF. LIVES",   0x10131B, 1, 0x02
        CHEAT   "INFINITE TIME", 0x100482, 1, 0x99
        CHEAT   "P1 INF ENERGY", 0x100CF6, 1, 0x06
        CHEAT   "P2 INF ENERGY", 0x1011F6, 1, 0x06
        CHEAT   "P2 INF LIVES", 0x1011F7, 1, 0x63
        CHEAT   "P1 INVINCIBILITY", 0x100C67, 1, 0x02
        CHEAT   "P2 INVINCIBILITY", 0x101167, 1, 0x02
        CHEAT   "P1 MAX WEAP POW", 0x100CF8, 1, 0x02
        CHEAT   "P1 PERMANENT 8 P", 0x100CC2, 1, 0x01
        CHEAT   "P2 MAX WEAP POW", 0x1011F8, 1, 0x02
        CHEAT   "P2 PERMANENT 8 P", 0x1011C2, 1, 0x01
        CHEAT   "P1 INF BOMBS", 0x100CF5, 1, 0x06
        CHEAT   "P2 INF BOMBS", 0x1011F5, 1, 0x06
        CHEAT   "INF CONTINUES", 0x100490, 1, 0x64
        | NIGHTMARE IN THE DARK: the lives, 3 at start.
        JEU     0x0260, 0x3085, 13
        CHEAT   "INFINITE LIVES",  0x100055, 1, 0x03
        CHEAT   "P2 INF. LIVES",   0x10028B, 1, 0x03
        CHEAT   "INFINITE TIME", 0x100002, 1, 0x63, 0x100003, 1, 0x3B
        CHEAT   "BIG DIAMOND EVER", 0x10000B, 1, 0x01
        CHEAT   "P1 INVINCIBILITY", 0x102C1B, 1, 0x03
        CHEAT   "P2 INVINCIBILITY", 0x102EE5, 1, 0x03
        CHEAT   "P1 FIRE POWER UP", 0x100052, 1, 0xFF
        CHEAT   "P1 SPEED POW UP", 0x100051, 1, 0xFF
        CHEAT   "P1 FIRING RANGE", 0x100053, 1, 0xFF
        CHEAT   "P2 FIRE POWER UP", 0x100288, 1, 0xFF
        CHEAT   "P2 SPEED POW UP", 0x100287, 1, 0xFF
        CHEAT   "P2 FIRING RANGE", 0x100289, 1, 0xFF
        CHEAT   "BONUS RATIO X 64", 0x100282, 1, 0x06
        | ROBO ARMY: the lives, 2 at start.
        JEU     0x0032, 0x95B5, 6
        CHEAT   "INFINITE LIVES",  0x1000D2, 1, 0x02
        CHEAT   "P1 INF ENERGY", 0x1000D3, 1, 0x0A
        CHEAT   "P2 INF ENERGY", 0x1001D3, 1, 0x0A
        CHEAT   "P2 INF LIVES", 0x1001D2, 1, 0x09
        CHEAT   "P1 INF BOMBS", 0x1000D4, 1, 0x06
        CHEAT   "P2 INF BOMBS", 0x1001D4, 1, 0x06
        | CYBER-LIP: the lives, 2 at start (expected sequence, action scenario).
        JEU     0x0010, 0x6484, 15
        CHEAT   "INFINITE LIVES",  0x10209D, 1, 0x02
        CHEAT   "INFINITE TIME", 0x107E25, 1, 0x59
        CHEAT   "P2 INF LIVES", 0x10219D, 1, 0x99
        CHEAT   "P1 INF CONTINUES", 0x107E3C, 1, 0x65
        CHEAT   "P1 INF AUTO GUN", 0x1020EC, 2, 0x9999
        CHEAT   "P1 INF WIDE GUN", 0x1020F0, 2, 0x9999
        CHEAT   "P1 INF BAZOOKA", 0x1020F2, 2, 0x9999
        CHEAT   "P1 INFINITE FIRE", 0x1020EE, 2, 0x9999
        CHEAT   "P1 INF GRENADES", 0x1020F4, 2, 0x9999
        CHEAT   "P2 INF CONTINUES", 0x107E3E, 1, 0x65
        CHEAT   "P2 INF AUTO GUN", 0x1021EC, 2, 0x9999
        CHEAT   "P2 INF WIDE GUN", 0x1021F0, 2, 0x9999
        CHEAT   "P2 INF BAZOOKA", 0x1021F2, 2, 0x9999
        CHEAT   "P2 INFINITE FIRE", 0x1021EE, 2, 0x9999
        CHEAT   "P2 INF GRENADES", 0x1021F4, 2, 0x9999
        | IRONCLAD: the lives, 5 at start (expected sequence, action scenario).
        JEU     0x0220, 0xD34D, 7
        CHEAT   "INFINITE LIVES",  0x10B113, 1, 0x05
        CHEAT   "P1 INF ENERGY", 0x10027D, 1, 0x04
        CHEAT   "P2 INF ENERGY", 0x101F7D, 1, 0x04
        CHEAT   "P1 MAXIMUM POWER", 0x108A15, 1, 0x0C
        CHEAT   "P2 MAXIMUM POWER", 0x108C15, 1, 0x0C
        CHEAT   "P1 MAXIMUM LEVEL", 0x108A17, 1, 0x20
        CHEAT   "P2 MAXIMUM LEVEL", 0x108C17, 1, 0x20
        | MUTATION NATION: the lives, 3 at start (expected sequence, action scenario).
        JEU     0x0014, 0x7834, 8
        CHEAT   "INFINITE LIVES",  0x102530, 1, 0x03
        CHEAT   "INFINITE TIME", 0x101562, 1, 0x63
        CHEAT   "P1 INF ENERGY", 0x102019, 1, 0x40
        CHEAT   "P2 INF ENERGY", 0x102119, 1, 0x40
        CHEAT   "P1 INVINCIBILITY", 0x10202E, 1, 0x03
        CHEAT   "P2 INVINCIBILITY", 0x10212E, 1, 0x03
        CHEAT   "P1 INF ATTACK IT", 0x10153F, 1, 0x05
        CHEAT   "P2 INF ATTACK IT", 0x101541, 1, 0x05
        | P2'S LIVES, 2026-10-29: P2 plays alone (its coin, its START; scenarios action2 and saut2
        | of `bench/cheats-recherche.py`), expected-sequence filter, each candidate forced alone: no
        | more game over. Kept, the cell that is not P1's (which also holds in several
        | games): often P1's at a structure offset, + $80, + $100, + 2… Added as the last
        | record of the action games above.
        | THE OTHER FAMILIES (puzzle, quiz, sport), 2026-10-29: record of the action scenario,
        | expected-sequence filter, each candidate forced alone from frame 700. NO GAME OVER: the cell
        | whose forcing removes the game over; ASSUMED, what it counts (lives, a line of bubbles,
        | continues): only the effect is proven, hence this name. And INFINITE TIME, by the time sequence.
        | CHIBI MARUKO-CHAN DELUXE QUIZ.
        JEU     0x0206, 0x88FB, 4
        CHEAT   "NO GAME OVER",     0x101303, 1, 0x03
        CHEAT   "INF ANSWER TIME", 0x100429, 1, 0x0F
        CHEAT   "P2 INF LIVES", 0x101403, 1, 0x03
        CHEAT   "ANSWER A CORRECT", 0x10040D, 1, 0x01
        | PUZZLE BOBBLE 2.
        JEU     0x0248, 0x5F90, 3
        CHEAT   "NO GAME OVER",     0x1057CA, 1, 0x02
        CHEAT   "P1 INFINITE TIME", 0x10D617, 1, 0x14
        CHEAT   "P2 INFINITE TIME", 0x10D6AD, 1, 0x14
        | PUZZLE BOBBLE.
        JEU     0x0083, 0x19FA, 1
        CHEAT   "NO GAME OVER",     0x102284, 1, 0x02
        | POWER SPIKES II.
        JEU     0x0068, 0xB80B, 5
        CHEAT   "NO GAME OVER",     0x102D4A, 1, 0x02
        CHEAT   "P1 FULL ENERGY", 0x1018F9, 1, 0x60, 0x102CD5, 1, 0x60
        CHEAT   "P2 FULL ENERGY", 0x1018FB, 1, 0x60, 0x102CD7, 1, 0x60
        CHEAT   "P1 MAX POWER", 0x102CD9, 1, 0x30
        CHEAT   "P2 MAX POWER", 0x102CDB, 1, 0x30
        | QUIZ MEITANTEI NEO & GEO.
        JEU     0x0042, 0xBE81, 5
        CHEAT   "NO GAME OVER",     0x101AC4, 1, 0x03
        CHEAT   "P2 INF LIVES", 0x101FC4, 1, 0x05
        CHEAT   "RAPIDSHOT QUIZ G", 0x101A2B, 1, 0x00
        CHEAT   "INFINITE GOLD", 0x100956, 1, 0xFF, 0x100957, 1, 0xFF
        CHEAT   "ANSWER A CORRECT", 0x100977, 1, 0x00
        | QUIZ DAISOUSA SEN.
        JEU     0x0023, 0x3ECF, 6
        CHEAT   "NO GAME OVER",     0x1022B3, 1, 0x03
        CHEAT   "P2 INF LIVES", 0x1023B3, 1, 0x04
        CHEAT   "2 GOOD ANSWERS N", 0x105A65, 1, 0x00
        CHEAT   "ANSWER A CORRECT", 0x105A8E, 1, 0x00
        CHEAT   "P1 INF CONTINUES", 0x1022A1, 1, 0x64
        CHEAT   "P2 INF CONTINUES", 0x1023A1, 1, 0x64
        | QUIZ KING OF FIGHTERS.
        JEU     0x0080, 0x7AA7, 5
        CHEAT   "NO GAME OVER",     0x10150A, 1, 0x03
        CHEAT   "INF BONUS TIME", 0x1085F5, 1, 0x59
        CHEAT   "P2 INF LIVES", 0x10158A, 1, 0x05
        CHEAT   "FASTER ROUND PRO", 0x10446F, 1, 0x05
        CHEAT   "ANSWER A CORRECT", 0x10446B, 1, 0x00
        | SUPER SIDEKICKS.
        JEU     0x0052, 0xFEF0, 5
        CHEAT   "INFINITE TIME",    0x108ED3, 1, 0x59
        CHEAT   "P1 SCORE 0", 0x1090F2, 1, 0x00
        CHEAT   "P1 PENALTIES SCO", 0x1090F6, 1, 0x00
        CHEAT   "P2 SCORE 0", 0x1090F3, 1, 0x00
        CHEAT   "P2 PENALTIES SCO", 0x1090F7, 1, 0x00
        | STREET HOOP.
        JEU     0x0079, 0x6DB5, 7
        CHEAT   "NO GAME OVER",     0x102D21, 1, 0x02
        CHEAT   "INFINITE TIME",    0x101A53, 1, 0x59
        CHEAT   "INF SELECT TEAM", 0x10E0C4, 1, 0x21
        CHEAT   "P1 0 POINTS", 0x101A0B, 1, 0x00
        CHEAT   "P1 SUPERSHOOT FU", 0x101A5A, 1, 0xC0
        CHEAT   "P2 0 POINTS", 0x101A0F, 1, 0x00
        CHEAT   "P2 SUPERSHOOT FU", 0x101A5C, 1, 0xC0
        | TECMO WORLD SOCCER 96.
        JEU     0x0086, 0xCB1D, 4
        CHEAT   "NO GAME OVER",     0x1014D7, 1, 0x05
        CHEAT   "P1 SCORE 0", 0x1014CF, 1, 0x00
        CHEAT   "P1 WIN PENALTY S", 0x1014D3, 1, 0x01, 0x1014D5, 1, 0x00
        CHEAT   "P2 SCORE 0", 0x1014D1, 1, 0x00
        | ON 2026-10-30, the same search by expected sequence, in the action scenario; judged by the
        | menu at frame 1500, or as soon as the game starts (trally 2600, zintrckb 2500).
        | GURURIN.
        JEU     0x0067, 0x97E7, 2
        CHEAT   "NO GAME OVER",     0x101C17, 1, 0x02
        CHEAT   "NO MORE LEVEL GA", 0x101C5D, 1, 0x00
        | THRASH RALLY.
        JEU     0x0038, 0x5FF9, 2
        CHEAT   "NO GAME OVER",     0x107105, 1, 0x05
        CHEAT   "INFINITE TIME", 0x103611, 1, 0x99, 0x103613, 1, 0x3B
        | ZINTRICK.
        JEU     0x0211, 0x1F3E, 6
        CHEAT   "NO GAME OVER",     0x100349, 1, 0x02
        CHEAT   "INFINITE TIME", 0x10C419, 1, 0x64
        CHEAT   "P1 INF ENERGY", 0x10C455, 1, 0x12
        CHEAT   "P2 INF ENERGY", 0x10C4D5, 1, 0x12
        CHEAT   "P1 INFINITE ITEM", 0x10C444, 1, 0x12
        CHEAT   "P2 INFINITE ITEM", 0x10C4C4, 1, 0x12
        | NINJA COMMANDO, 2026-10-30: the search by expected sequence
        | up to frame 20,000 (the witness run loses the game around 16,400); the lives, 2 at start.
        JEU     0x0050, 0x004D, 6
        CHEAT   "INFINITE LIVES",  0x106030, 1, 0x02
        CHEAT   "P1 INFINITE TIME", 0x106029, 1, 0xCC
        CHEAT   "P2 INFINITE TIME", 0x106129, 1, 0xCC
        CHEAT   "P2 INF ENERGY", 0x106130, 1, 0x02
        CHEAT   "P1 INVINCIBILITY", 0x1000C0, 1, 0x35
        CHEAT   "P2 INVINCIBILITY", 0x1001C0, 1, 0x35
        | FIGHTING GAME TIMERS BY EXPECTED SEQUENCE, 2026-10-30: passive scenario, the byte that
        | counts down from 60 or 99 and is reset at each round (filtre_suite), seen frozen on the
        | images under the cheat; the digits' zone searched on the images of a CAT_DENSE run.
        | THE KING OF FIGHTERS 2003.
        JEU     0x0271, 0x0F9A, 1
        CHEAT   "INFINITE TIME",   0x107D62, 1, 0x60
        | REAL BOUT FATAL FURY.
        JEU     0x0095, 0x8E2F, 8
        CHEAT   "INFINITE TIME",   0x106AA8, 1, 0x60
        CHEAT   "P1 INF ENERGY", 0x100489, 1, 0xC0
        CHEAT   "P2 INF ENERGY", 0x100589, 1, 0xC0
        CHEAT   "P1 INF POWER", 0x1004BA, 1, 0x3C
        CHEAT   "P2 INF POWER", 0x1005BA, 1, 0x3C
        CHEAT   "LEFT WALL SOLID", 0x10969F, 1, 0x0A
        CHEAT   "RIGHT WALL SOLID", 0x1096A1, 1, 0x0A
        CHEAT   "EASY SUPERS", 0x10E001, 1, 0x01
        | KIZUNA ENCOUNTER: the fight only starts around frame 2700.
        JEU     0x0216, 0x073D, 3
        CHEAT   "INFINITE TIME",   0x10892A, 1, 0x99
        CHEAT   "P1 INF ENERGY", 0x108313, 1, 0xC0
        CHEAT   "P2 INF ENERGY", 0x108513, 1, 0xC0
        | THE KING OF FIGHTERS '97: the frame countdown of the second, as kof96 and kof98; forcing
        | the seconds $10A83A instead freezes the game at KO.
        JEU     0x0232, 0xFC0D, 9
        CHEAT   "INFINITE TIME",   0x10A83B, 1, 0x32
        CHEAT   "P1 INF ENERGY", 0x108239, 1, 0x67
        CHEAT   "P2 INF ENERGY", 0x108439, 1, 0x67
        CHEAT   "HIDDEN CHARS EXC", 0x10EC34, 1, 0x1F
        CHEAT   "BACKDROP RED", 0x10EC35, 1, 0x01
        CHEAT   "P1 NEVER GET DIZ", 0x10823F, 1, 0x67
        CHEAT   "P1 NEVER GET GUA", 0x108247, 1, 0x67
        CHEAT   "P2 NEVER GET DIZ", 0x10843F, 1, 0x67
        CHEAT   "P2 NEVER GET GUA", 0x108447, 1, 0x67
        | The games below come from the MAME XML Cheats Collection (`bench/cheats-importer.py`),
        | not proven one by one here.
        JEU     0x0030, 0xAC3A, 4
        CHEAT   "INF SELECT TIME", 0x105BA4, 1, 0x02
        CHEAT   "INF GAME TIME", 0x104290, 1, 0x59
        CHEAT   "INF CONTINUES", 0x1000C1, 1, 0x64
        CHEAT   "INF TOTAL OUTS", 0x1000C0, 1, 0x16
        JEU     0x0043, 0xC733, 1
        CHEAT   "INFINITE TIME", 0x10A19E, 1, 0x09, 0x10A19F, 1, 0x59
        JEU     0x0074, 0x93C1, 3
        CHEAT   "INFINITE TIME", 0x10B649, 1, 0xFA, 0x10B64A, 2, 0x0000
        CHEAT   "P1 INF ENERGY", 0x100066, 1, 0x0B, 0x100067, 1, 0xFF
        CHEAT   "P2 INF ENERGY", 0x100166, 1, 0x0B, 0x100167, 1, 0xFF
        JEU     0x0036, 0xD5F1, 1
        CHEAT   "INF MOVE TIME", 0x1000FD, 1, 0xEF
        JEU     0x0259, 0xA494, 3
        CHEAT   "INFINITE TIME", 0x1044C9, 1, 0x06, 0x1044CB, 1, 0x00
        CHEAT   "P1 MAX MIRACLE P", 0x10444C, 1, 0x80, 0x104461, 1, 0x03
        CHEAT   "P2 MAX MIRACLE P", 0x104476, 1, 0x80, 0x10448B, 1, 0x03
        JEU     0x0002, 0xEF35, 5
        CHEAT   "INFINITE TIME", 0x10004A, 1, 0x59
        CHEAT   "INFINITE INNINGS", 0x101083, 1, 0x09
        CHEAT   "INFINITE STRIKES", 0x10107E, 1, 0x00
        CHEAT   "INFINITE BALLS", 0x10107D, 1, 0x00
        CHEAT   "INFINITE OUTS", 0x10107C, 1, 0x00
        JEU     0x0041, 0x86F9, 9
        CHEAT   "INFINITE TIME", 0x1041D8, 1, 0x59
        CHEAT   "P1 MAX POW", 0x104422, 1, 0x63
        CHEAT   "P2 MAX POW", 0x104423, 1, 0x63
        CHEAT   "INF TOTAL OUTS", 0x10000D, 1, 0x16
        CHEAT   "INFINITE STRIKES", 0x10442C, 1, 0x00
        CHEAT   "INFINITE BALLS", 0x10442D, 1, 0x00
        CHEAT   "INFINITE OUTS", 0x10442B, 1, 0x00
        CHEAT   "P1 WIN GAME", 0x1043F2, 1, 0x99
        CHEAT   "P2 WIN GAME", 0x1043F3, 1, 0x99
        JEU     0x0054, 0x594F, 4
        CHEAT   "P1 INF ENERGY", 0x103072, 2, 0x1388
        CHEAT   "P2 INF ENERGY", 0x1030F2, 2, 0x1388
        CHEAT   "P1 INF BOMBS", 0x103074, 1, 0x63
        CHEAT   "P2 INF BOMBS", 0x1030F4, 1, 0x63
        JEU     0x0066, 0x9922, 6
        CHEAT   "P1 INF ENERGY", 0x102091, 1, 0xA0
        CHEAT   "P2 INF ENERGY", 0x1020AD, 1, 0xA0
        CHEAT   "P1 INF LIVES", 0x102093, 1, 0x04
        CHEAT   "P2 INF LIVES", 0x1020AF, 1, 0x04
        CHEAT   "P1 INF BOMBS", 0x10219F, 1, 0x03
        CHEAT   "P2 INF BOMBS", 0x1021A1, 1, 0x03
        JEU     0x0033, 0xA9A5, 3
        CHEAT   "P1 INF ENERGY", 0x1003B8, 2, 0x6060
        CHEAT   "P2 INF ENERGY", 0x1004B8, 2, 0x6060
        CHEAT   "INF ENERGY CPU", 0x1005B8, 2, 0x6060
        JEU     0x0034, 0x6160, 3
        CHEAT   "INFINITE TIME", 0x100AD8, 1, 0x99, 0x100AD9, 1, 0x99
        CHEAT   "P1 SCORE 00", 0x104368, 1, 0x00, 0x104369, 1, 0x00
        CHEAT   "P2 SCORE 00", 0x104468, 1, 0x00, 0x104469, 1, 0x00
        JEU     0x0078, 0x086F, 5
        CHEAT   "INFINITE TIME", 0x101252, 1, 0xFF, 0x101253, 1, 0xDB
        CHEAT   "P1 INF ENERGY", 0x10103C, 1, 0xFF
        CHEAT   "P2 INF ENERGY", 0x101152, 1, 0xFF
        CHEAT   "P1 PLAY WITH FEL", 0x105C7F, 1, 0x03
        CHEAT   "P2 PLAY WITH FEL", 0x105C81, 1, 0x03
        JEU     0x0228, 0xB962, 1
        CHEAT   "INFINITE TIME", 0x10C846, 2, 0x0909
        JEU     0x0209, 0x80F0, 3
        CHEAT   "INFINITE TIME", 0x1004E5, 1, 0x3C
        CHEAT   "P1 SCORE 0", 0x1004F1, 1, 0x00
        CHEAT   "P2 SCORE 0", 0x1004F3, 1, 0x00
        JEU     0x0236, 0xB0C1, 2
        CHEAT   "INFINITE TIME", 0x10A857, 1, 0x63, 0x10A859, 1, 0x09
        CHEAT   "INFINITE LIVES", 0x10808F, 1, 0x03
        JEU     0x0048, 0x4DD5, 1
        CHEAT   "INF MOVE TIME", 0x108418, 1, 0x05
        JEU     0x0021, 0xB9B7, 6
        CHEAT   "P1 INF CONTINUES", 0x10090C, 1, 0x64
        CHEAT   "P1 MIN PIECE SPE", 0x100642, 1, 0x00, 0x100643, 1, 0x00
        CHEAT   "P1 MAX L-BALL", 0x100904, 1, 0x0C
        CHEAT   "P2 INF CONTINUES", 0x100C1C, 1, 0x64
        CHEAT   "P2 MIN PIECE SPE", 0x100952, 1, 0x00, 0x100953, 1, 0x00
        CHEAT   "P2 MAX L-BALL", 0x100C14, 1, 0x0C
        JEU     0x0262, 0xCFA8, 6
        CHEAT   "INFINITE TIME", 0x10A7D3, 1, 0x46
        CHEAT   "P1 INF ENERGY", 0x108239, 1, 0x66
        CHEAT   "P2 INF ENERGY", 0x108439, 1, 0x66
        CHEAT   "P1 MAXIMUM POW", 0x1082E3, 1, 0x04
        CHEAT   "P2 MAXIMUM POW", 0x1084E3, 1, 0x04
        CHEAT   "MAI S BOOBS BOUN", 0x10A7E0, 1, 0x00
        JEU     0x0016, 0x5114, 6
        CHEAT   "INF ENRG ENEMY 1", 0x10226B, 1, 0x3C
        CHEAT   "INF ENRG ENEMY 2", 0x10236B, 1, 0x3C
        CHEAT   "P1 INF ENERGY", 0x10206B, 1, 0x3C
        CHEAT   "P2 INF ENERGY", 0x10216B, 1, 0x3C
        CHEAT   "P1 MAXIMUM POWER", 0x1020C1, 1, 0x0A
        CHEAT   "P2 MAXIMUM POWER", 0x1021C1, 1, 0x0A
        JEU     0x0300, 0xBF37, 1
        CHEAT   "INFINITE LIVES", 0x100172, 2, 0x0063
        JEU     0x0019, 0x93E6, 4
        CHEAT   "P1 INFINITE TIME", 0x1010A5, 1, 0x99
        CHEAT   "P2 INFINITE TIME", 0x1011A5, 1, 0x99
        CHEAT   "P3 INFINITE TIME", 0x1012A5, 1, 0x99
        CHEAT   "P4 INFINITE TIME", 0x1013A5, 1, 0x99
        JEU     0x0029, 0x7711, 4
        CHEAT   "P1 INFINITE TIME", 0x100369, 1, 0x00
        CHEAT   "P2 INFINITE TIME", 0x100769, 1, 0x00
        CHEAT   "P1 INF ENERGY", 0x100363, 1, 0x78
        CHEAT   "P2 INF ENERGY", 0x100763, 1, 0x78
        JEU     0x0221, 0x3333, 5
        CHEAT   "NO MORE LEVEL GA", 0x100A5F, 1, 0x00
        CHEAT   "P1 QUOTA 200", 0x100A4B, 1, 0xC8
        CHEAT   "P1 PLAY AS BLACK", 0x100117, 1, 0x0A, 0x100805, 1, 0x09
        CHEAT   "P2 QUOTA 200", 0x100A6B, 1, 0xC8
        CHEAT   "P2 PLAY AS BLACK", 0x100118, 1, 0x0A, 0x100905, 1, 0x09
        JEU     0x0233, 0xFB9F, 4
        CHEAT   "NO MORE LEVEL GA", 0x100626, 1, 0x00
        CHEAT   "UNLOCK SECRET CH", 0x100112, 2, 0x0303
        CHEAT   "P1 QUOTA 200", 0x100611, 1, 0xC8
        CHEAT   "P2 QUOTA 200", 0x100651, 1, 0xC8
        JEU     0x0004, 0xACC8, 2
        CHEAT   "INF MAIN GAME TI", 0x10019D, 1, 0xFF
        CHEAT   "INF MOVE TIME", 0x100227, 1, 0xFF
        JEU     0x0231, 0x4B17, 2
        CHEAT   "NO MORE LEVEL GA", 0x107546, 1, 0x00
        CHEAT   "MAX CHAIN 09", 0x1030FB, 1, 0x09
        JEU     0x0027, 0xD5BB, 2
        CHEAT   "INF MOVE TIME", 0x1000CD, 1, 0xF4
        CHEAT   "MAKE 1 STEP ALWA", 0x10131C, 1, 0x01
        JEU     0x0203, 0x47EA, 16
        CHEAT   "P1 INFINITE TIME", 0x10B064, 2, 0x0980
        CHEAT   "P2 INFINITE TIME", 0x10B074, 2, 0x0980
        CHEAT   "P1 INF PAWNS IN", 0x10B8B4, 1, 0x09
        CHEAT   "P1 INF LANCES IN", 0x10B8B5, 1, 0x09
        CHEAT   "P1 INF KNIGHTS I", 0x10B8B6, 1, 0x09
        CHEAT   "P1 INF SILVERS I", 0x10B8B7, 1, 0x09
        CHEAT   "P1 INF GOLDS IN", 0x10B8B8, 1, 0x09
        CHEAT   "P1 INF BISHOPS I", 0x10B8B9, 1, 0x09
        CHEAT   "P1 INF ROOKS IN", 0x10B8BA, 1, 0x09
        CHEAT   "P2 INF PAWNS IN", 0x10B8C4, 1, 0x09
        CHEAT   "P2 INF LANCES IN", 0x10B8C5, 1, 0x09
        CHEAT   "P2 INF KNIGHTS I", 0x10B8C6, 1, 0x09
        CHEAT   "P2 INF SILVERS I", 0x10B8C7, 1, 0x09
        CHEAT   "P2 INF GOLDS IN", 0x10B8C8, 1, 0x09
        CHEAT   "P2 INF BISHOPS I", 0x10B8C9, 1, 0x09
        CHEAT   "P2 INF ROOKS IN", 0x10B8CA, 1, 0x09
        JEU     0x0001, 0xD38B, 7
        CHEAT   "P1 INVINCIBILITY", 0x1010F0, 1, 0x02
        CHEAT   "P2 INVINCIBILITY", 0x1011F0, 1, 0x02
        CHEAT   "P1 INFINITE AMMO", 0x1010E7, 1, 0x99
        CHEAT   "P2 INFINITE AMMO", 0x1011E7, 1, 0x99
        CHEAT   "INF CONTINUES", 0x10A625, 1, 0x64
        CHEAT   "P1 INF GRENADES", 0x1010ED, 1, 0x99
        CHEAT   "P2 INF GRENADES", 0x1011ED, 1, 0x99
        JEU     0x0244, 0xAB34, 3
        CHEAT   "INFINITE TIME", 0x10517C, 1, 0x00, 0x10517B, 1, 0x00
        CHEAT   "P1 SCORE 0", 0x1051EA, 1, 0x00
        CHEAT   "P2 SCORE 0", 0x1051EE, 1, 0x00
        JEU     0x0213, 0xA303, 8
        CHEAT   "INFINITE TIME", 0x103334, 1, 0x17, 0x103335, 1, 0x70
        CHEAT   "STOP TOTAL TIME", 0x103378, 1, 0x00, 0x103379, 1, 0x00
        CHEAT   "STOP TOTAL TIM 2", 0x10339A, 1, 0x00, 0x10339B, 1, 0x00
        CHEAT   "STOP TOTAL TIM 3", 0x1033BC, 1, 0x00, 0x1033BD, 1, 0x00
        CHEAT   "STOP TOTAL TIM 4", 0x1033DE, 1, 0x00, 0x1033DF, 1, 0x00
        CHEAT   "STOP TOTAL TIM 5", 0x103400, 1, 0x00, 0x103401, 1, 0x00
        CHEAT   "STOP TOTAL TIM 6", 0x103422, 1, 0x00, 0x103423, 1, 0x00
        CHEAT   "STOP TOTAL TIM 7", 0x103444, 1, 0x00, 0x103445, 1, 0x00
        JEU     0x0212, 0xE076, 4
        CHEAT   "INFINITE TIME", 0x10B004, 1, 0x99
        CHEAT   "INF SELECT TIME", 0x10B066, 1, 0x12
        CHEAT   "FINISH 1ST PLACE", 0x10E0FD, 1, 0x00
        CHEAT   "GO AT MAX SPEED", 0x104851, 1, 0xFF
        JEU     0x0073, 0xB4AC, 4
        CHEAT   "P1 MIN POWER UP", 0x1038CD, 1, 0x00
        CHEAT   "P2 MIN POWER UP", 0x103B6F, 1, 0x00
        CHEAT   "P1 NO MORE LEVEL", 0x103941, 1, 0x00
        CHEAT   "P2 NO MORE LEVEL", 0x103BE3, 1, 0x00
        JEU     0x0219, 0x6FFA, 1
        CHEAT   "INF NORMAL TIME", 0x104C28, 1, 0x6F
        JEU     0x0267, 0xBDF1, 2
        CHEAT   "P1 FLOOD THE OPP", 0x102C15, 1, 0x55
        CHEAT   "MAX INTRUDERS AT", 0x10C82A, 2, 0x10FF
        JEU     0x0237, 0xA3D4, 2
        CHEAT   "P1 INF LIVES", 0x10823D, 1, 0x63
        CHEAT   "P2 INF LIVES", 0x10824B, 1, 0x63
        JEU     0x0235, 0xCFF1, 2
        CHEAT   "INF TIME SOLO", 0x107D23, 1, 0x78
        CHEAT   "INF CONTINUES", 0x100219, 1, 0x64
        JEU     0x0202, 0xCF3A, 2
        CHEAT   "INF TIME SOLO", 0x107D23, 1, 0x78
        CHEAT   "INF CONTINUES", 0x100219, 1, 0x64
        JEU     0x0223, 0x2249, 9
        CHEAT   "P1 INF SELECT TI", 0x102588, 1, 0x0A
        CHEAT   "P2 INF SELECT TI", 0x102688, 1, 0x0A
        CHEAT   "P1 INF ENERGY", 0x10048B, 1, 0xC0
        CHEAT   "P2 INF ENERGY", 0x10058B, 1, 0xC0
        CHEAT   "P1 INF POWER", 0x1004BC, 1, 0x3C
        CHEAT   "P2 INF POWER", 0x1005BC, 1, 0x3C
        CHEAT   "EASY SUPERS", 0x10E001, 1, 0x01
        CHEAT   "P1 QUICK ACTION", 0x10046F, 1, 0x00
        CHEAT   "P2 QUICK ACTION", 0x10056F, 1, 0x00
        JEU     0x0006, 0x9D17, 7
        CHEAT   "INF TIME - W.G.P", 0x1000F8, 1, 0x99
        CHEAT   "INF TIME - STORY", 0x10011B, 1, 0x99
        CHEAT   "INF TIME REMAINI", 0x1000FC, 1, 0x08, 0x1000FD, 1, 0x60
        CHEAT   "INFINITE TURBOS", 0x100F79, 1, 0x04
        CHEAT   "WIN EVERY RACE A", 0x100F89, 1, 0x01
        CHEAT   "RIDE AT MAX SPEE", 0x100F52, 1, 0x01, 0x100F53, 1, 0x99
        CHEAT   "INF MONEY STORY", 0x100C1C, 1, 0x99, 0x100C1D, 1, 0x99
        JEU     0x0208, 0xFF82, 2
        CHEAT   "P1 MAX POWER", 0x105FD2, 2, 0x8FFF
        CHEAT   "P2 MAX POWER", 0x105FDA, 2, 0x8FFF
        JEU     0x0017, 0x836D, 14
        CHEAT   "P1 CHANGE TIME N", 0x100365, 1, 0x60
        CHEAT   "P1 CHANGE TIME S", 0x100367, 1, 0x60
        CHEAT   "P1 CHANGE TIME D", 0x100369, 1, 0x60
        CHEAT   "P2 CHANGE TIME N", 0x100465, 1, 0x60
        CHEAT   "P2 CHANGE TIME S", 0x100467, 1, 0x60
        CHEAT   "P2 CHANGE TIME D", 0x100469, 1, 0x60
        CHEAT   "P1 INF ENERGY", 0x100305, 1, 0x06
        CHEAT   "P2 INF ENERGY", 0x100405, 1, 0x06
        CHEAT   "P1 INF LIVES", 0x1000B3, 1, 0x02
        CHEAT   "P2 INF LIVES", 0x1000B5, 1, 0x02
        CHEAT   "P1 PERMANENT WEA", 0x100380, 1, 0x04
        CHEAT   "P2 PERMANENT WEA", 0x100480, 1, 0x04
        CHEAT   "P1 TRANSFORMATIO", 0x100336, 1, 0x0F
        CHEAT   "P2 TRANSFORMATIO", 0x100436, 1, 0x0F
        JEU     0x0238, 0xE4F2, 15
        CHEAT   "INFINITE TIME", 0x108D01, 1, 0x99
        CHEAT   "P1 INF ENERGY", 0x1001B5, 1, 0x80
        CHEAT   "P2 INF ENERGY", 0x1021B5, 1, 0x80
        CHEAT   "P1 INVINCIBILITY", 0x100127, 1, 0xFF
        CHEAT   "P2 INVINCIBILITY", 0x102127, 1, 0xFF
        CHEAT   "P1 INF NORMAL AM", 0x108DBB, 1, 0xD0
        CHEAT   "P1 INF SPEC AMMO", 0x108DC3, 1, 0x63
        CHEAT   "P1 INF SPEC AM 2", 0x108DC7, 1, 0x63
        CHEAT   "P1 INF SPEC AM 3", 0x108DCB, 1, 0x63
        CHEAT   "P2 INF NORMAL AM", 0x108FBB, 1, 0xD0
        CHEAT   "P2 INF SPEC AMMO", 0x108FC3, 1, 0x63
        CHEAT   "P2 INF SPEC AM 2", 0x108FC7, 1, 0x63
        CHEAT   "P2 INF SPEC AM 3", 0x108FCB, 1, 0x63
        CHEAT   "P1 INF CREDITS H", 0x108342, 1, 0x99
        CHEAT   "P2 INF CREDITS H", 0x108343, 1, 0x99
        JEU     0x0031, 0x0B89, 8
        CHEAT   "INFINITE TIME", 0x10BDB9, 1, 0x59, 0x10BDB8, 1, 0x99
        CHEAT   "P1 MAX ENERGY", 0x10B3A8, 1, 0x60
        CHEAT   "P2 MAX ENERGY", 0x10B3B0, 1, 0x60
        CHEAT   "P1 SCORE 0", 0x10B3A2, 1, 0x00
        CHEAT   "P1 WIN PENALTY S", 0x10D49F, 1, 0x03, 0x10D4A1, 1, 0x00
        CHEAT   "P1 INF PENALTY K", 0x10D4A3, 1, 0x02
        CHEAT   "P2 SCORE 0", 0x10B3A4, 1, 0x00
        CHEAT   "P2 INF PENALTY K", 0x10D4A5, 1, 0x02
        JEU     0x0061, 0x3C6E, 4
        CHEAT   "INFINITE TIME", 0x1067A4, 1, 0x00, 0x1067A3, 1, 0x00
        CHEAT   "P1 WIN TOSS", 0x100884, 1, 0x07
        CHEAT   "P1 SCORE 0", 0x1044C4, 1, 0x00
        CHEAT   "P2 SCORE 0", 0x1044C8, 1, 0x00
        JEU     0x0081, 0xA84D, 3
        CHEAT   "INFINITE TIME", 0x10517C, 1, 0x00, 0x10517B, 1, 0x00
        CHEAT   "P1 SCORE 0", 0x1051EA, 1, 0x00
        CHEAT   "P2 SCORE 0", 0x1051EE, 1, 0x00
        JEU     0x0215, 0x4AD3, 7
        CHEAT   "INFINITE TIME", 0x105A1F, 1, 0x00, 0x105A1E, 1, 0x00
        CHEAT   "P1 MAXIMUM POWER", 0x105A4F, 1, 0x5F, 0x10BE7B, 1, 0x5F
        CHEAT   "P2 MAXIMUM POWER", 0x105A53, 1, 0x5F, 0x10BE7D, 1, 0x5F
        CHEAT   "P1 SCORE 0", 0x105A2A, 1, 0x00
        CHEAT   "P1 TEAM SNK SUPE", 0x1059DE, 1, 0x50
        CHEAT   "P2 SCORE 0", 0x105A2E, 1, 0x00
        CHEAT   "P2 TEAM SNK SUPE", 0x1059FE, 1, 0x50
        JEU     0x0088, 0xDD15, 16
        CHEAT   "INF TIME IN TRAI", 0x100022, 1, 0x32
        CHEAT   "P1 POWER - 1", 0x102998, 1, 0x44
        CHEAT   "P1 POWER - 2", 0x102AD6, 1, 0x44
        CHEAT   "P1 POWER - 3", 0x102C14, 1, 0x44
        CHEAT   "P1 POWER - 4", 0x102D52, 1, 0x44
        CHEAT   "P1 POWER - 5", 0x102E90, 1, 0x44
        CHEAT   "P1 POWER - 6", 0x102FCE, 1, 0x44
        CHEAT   "P1 POWER - 7", 0x10310C, 1, 0x44
        CHEAT   "P1 INF MONEY", 0x10029E, 1, 0xFF
        CHEAT   "P1 EXTRA SPEED", 0x1002B8, 1, 0x0A
        CHEAT   "P1 HAVE MAX SPEE", 0x100275, 1, 0x08
        CHEAT   "P1 HAVE MAX STAM", 0x100277, 1, 0x08
        CHEAT   "P1 HAVE MAX STRE", 0x10027B, 1, 0x08
        CHEAT   "P2 INF MONEY", 0x100336, 1, 0xFF
        CHEAT   "P2 EXTRA SPEED", 0x100350, 1, 0x0A
        CHEAT   "P2 HAVE MAX SPEE", 0x10030D, 1, 0x08
        JEU     0x0227, 0x8D04, 15
        CHEAT   "INF SHOP TIME", 0x108943, 1, 0x0A
        CHEAT   "P1 INF POWER", 0x1089E2, 1, 0xEA
        CHEAT   "P2 INF POWER", 0x108BA0, 1, 0xFF
        CHEAT   "P1 INF MONEY", 0x108B5C, 1, 0xFF, 0x108B5D, 1, 0xFF
        CHEAT   "P1 EXTRA SPEED", 0x1089C0, 1, 0x23
        CHEAT   "P1 HAVE MAX SPEE", 0x1080F8, 1, 0x07
        CHEAT   "P1 HAVE MAX STAM", 0x1080F9, 1, 0x07
        CHEAT   "P1 HAVE MAX BURS", 0x1080FA, 1, 0x07
        CHEAT   "P2 INF MONEY", 0x10800A, 1, 0xFF, 0x10800B, 1, 0xFF
        CHEAT   "P2 EXTRA SPEED", 0x108B7E, 1, 0x23
        CHEAT   "P2 HAVE MAX SPEE", 0x108138, 1, 0x07
        CHEAT   "P2 HAVE MAX STAM", 0x108139, 1, 0x07
        CHEAT   "P2 HAVE MAX BURS", 0x10813A, 1, 0x07
        CHEAT   "P1 ALL SPEC MOVE", 0x1080D9, 1, 0xFF
        CHEAT   "P2 ALL SPEC MOVE", 0x108119, 1, 0xFF
        JEU     0x0046, 0xB343, 5
        CHEAT   "INFINITE TIME", 0x108CC2, 1, 0x99
        CHEAT   "P1 INF LIVES", 0x108D1D, 1, 0x64
        CHEAT   "P2 INF LIVES", 0x108D21, 1, 0x64
        CHEAT   "P1 POWER", 0x108D0D, 1, 0x05
        CHEAT   "P2 POWER", 0x108D11, 1, 0x05
        JEU     0x0003, 0x8AC7, 4
        CHEAT   "INFINITE TIME", 0x10021B, 1, 0x3B
        CHEAT   "INFINITE STROKES", 0x100106, 1, 0x01
        CHEAT   "P1 INF HOLES", 0x10022C, 1, 0x63
        CHEAT   "P2 INF HOLES", 0x1002AC, 1, 0x63
        JEU     0x0200, 0xB925, 4
        CHEAT   "P1 INF STROKES", 0x107006, 1, 0x01
        CHEAT   "P1 INF HOLES", 0x10D572, 1, 0x63
        CHEAT   "P2 INF STROKES", 0x10702C, 1, 0x01
        CHEAT   "P2 INF HOLES", 0x10D5D2, 1, 0x63
        JEU     0x0225, 0x7F39, 2
        CHEAT   "P1 INF ENERGY", 0x10014A, 1, 0xFF, 0x10014B, 1, 0xE4
        CHEAT   "P2 INF ENERGY", 0x10028A, 1, 0xFF, 0x10028B, 1, 0xE4
        JEU     0x0065, 0x2657, 3
        CHEAT   "INF SET TIME", 0x10008D, 1, 0x99
        CHEAT   "P1 SCORE 0", 0x100873, 1, 0x00
        CHEAT   "P2 SCORE 0", 0x1008F3, 1, 0x00
        FIN_TABLE
        .balign 2
