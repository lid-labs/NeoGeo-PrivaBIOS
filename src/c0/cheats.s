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

| THE CHEATS, all measured (jig `bench/cheats.lua`, modes `releve` then `forcer`: the cell
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
        JEU     0x0201, 0x33C2, 3
        CHEAT   "INFINITE LIVES",  0x100377, 1, 0x03
        CHEAT   "INFINITE BOMBS",  0x1004C0, 1, 0x0A
        CHEAT   "INFINITE TIME",   0x106E93, 1, 0x3C
        | ART OF FIGHTING. Measured: round seconds $108406 (BCD, $60 at start; forced, 60 on
        | screen, and the game ends like the witness run); P1's life $1092CD ($60 at start, 0 at
        | KO; forced, gauge full, no game over in 8,000 frames, the witness run ends at 6,079).
        JEU     0x0044, 0x42B6, 2
        CHEAT   "INFINITE TIME",   0x108406, 1, 0x60
        CHEAT   "P1 INFINITE LIFE", 0x1092CD, 1, 0x60
        | THE KING OF FIGHTERS '94. Measured: the frame countdown of the second $10882F (50 → 0,
        | then −1 to the seconds $10882E); forced to 50, TIME stays 60 and the end-of-round
        | countdown, which writes $10882E without going through it, runs. Forcing $10882E itself
        | freezes the game at KO (measured: gauge empty, nothing follows any more). P1's life
        | $108221 ($CF at start; forced, gauge full, no game over in 9,000 frames, the witness run
        | ends at 8,466).
        JEU     0x0055, 0x4489, 2
        CHEAT   "INFINITE TIME",   0x10882F, 1, 0x32
        CHEAT   "P1 INFINITE LIFE", 0x108221, 1, 0xCF
        | THE CATALOGUE OF 2026-10-25: one or two cheats per game, each found and proven like those
        | above (standalone record `measured/2026-10-25-cheats-table.tsv`: method, measurement, effect
        | seen on screen, jig; the search, `2026-10-25-cheats-recherche.tsv`), and enabled through the
        | in-game menu under `bench/cheats-catalogue.sh`. INFINITE TIME: the displayed timer no longer
        | goes down, and the round still ends by KO. INFINITE LIVES: no more game over.
        | THE KING OF FIGHTERS '95: like kof94, the frame countdown of the second ($32 to 0) next to
        | the seconds $10A836 (BCD), which we do not force (forced, the round no longer starts); P1's
        | life $CF at the start of the round.
        JEU     0x0084, 0x0A7E, 2
        CHEAT   "INFINITE TIME",   0x10A837, 1, 0x32
        CHEAT   "P1 INFINITE LIFE", 0x108221, 1, 0xCF
        | THE KING OF FIGHTERS '99: the frame countdown of the second, seconds at $10A7E6.
        | On 2026-10-29: $108422, the damage taken by P1 (0 at the round, rises with hits; forced to 0).
        JEU     0x0251, 0xB157, 2
        CHEAT   "INFINITE TIME",   0x10A7E7, 1, 0x32
        CHEAT   "P1 INFINITE LIFE", 0x108422, 1, 0x00
        | THE KING OF FIGHTERS 2000: the seconds, BCD.
        JEU     0x0257, 0xE65C, 1
        CHEAT   "INFINITE TIME",   0x10A7E6, 1, 0x60
        | THE KING OF FIGHTERS 2002: the frame countdown of the second, seconds at $10A7D2.
        JEU     0x0265, 0xC423, 1
        CHEAT   "INFINITE TIME",   0x10A7D3, 1, 0x32
        | SAMURAI SHODOWN: the seconds, BCD, 99 at start.
        JEU     0x0045, 0x39BC, 1
        CHEAT   "INFINITE TIME",   0x100A08, 1, 0x99
        | SAMURAI SHODOWN II: the seconds, BCD, 99 at start.
        JEU     0x0063, 0xB2EF, 1
        CHEAT   "INFINITE TIME",   0x100AC6, 1, 0x99
        | SAMURAI SHODOWN IV: the frame countdown of the second ($3C), seconds at $108368.
        JEU     0x0222, 0x2643, 1
        CHEAT   "INFINITE TIME",   0x108369, 1, 0x3C
        | SAMURAI SHODOWN V: the seconds, BCD.
        JEU     0x0270, 0x1B2F, 1
        CHEAT   "INFINITE TIME",   0x10836A, 1, 0x60
        | SAMURAI SHODOWN V SPECIAL: the seconds, BCD.
        JEU     0x0272, 0x1851, 1
        CHEAT   "INFINITE TIME",   0x10836A, 1, 0x60
        | FATAL FURY 3: the seconds, BCD.
        JEU     0x0069, 0xEF51, 1
        CHEAT   "INFINITE TIME",   0x105680, 1, 0x60
        | FATAL FURY SPECIAL: the seconds, BCD.
        JEU     0x0058, 0x189F, 1
        CHEAT   "INFINITE TIME",   0x10092A, 1, 0x60
        | THE LAST BLADE: the seconds, BCD.
        JEU     0x0234, 0xB3E9, 1
        CHEAT   "INFINITE TIME",   0x10E32B, 1, 0x60
        | ART OF FIGHTING 2: the seconds, BCD, the same cell as aof.
        JEU     0x0056, 0x2DFA, 1
        CHEAT   "INFINITE TIME",   0x108406, 1, 0x60
        | WORLD HEROES: the seconds, BCD, 99 at start.
        JEU     0x0053, 0x783E, 1
        CHEAT   "INFINITE TIME",   0x10B008, 1, 0x99
        | WORLD HEROES 2: the seconds, BCD, 99 at start.
        JEU     0x0057, 0x1419, 1
        CHEAT   "INFINITE TIME",   0x10C109, 1, 0x99
        | SNK VS. CAPCOM: the seconds, BCD.
        JEU     0x0269, 0xD6D2, 1
        CHEAT   "INFINITE TIME",   0x10AC14, 1, 0x60
        | BREAKERS REVENGE: the seconds, binary, 99 at start.
        JEU     0x0245, 0xB255, 1
        CHEAT   "INFINITE TIME",   0x107C27, 1, 0x63
        | KARNOV'S REVENGE: the seconds, binary, 99 at start.
        | On 2026-10-29: $103A74, the high byte of P1's life word ($0FFF at the highest).
        JEU     0x0066, 0x6A32, 2
        CHEAT   "INFINITE TIME",   0x103A70, 1, 0x63
        CHEAT   "P1 INFINITE LIFE", 0x103A74, 1, 0x0F
        | DOUBLE DRAGON: the seconds, BCD, 99 at start.
        JEU     0x0082, 0x1CB9, 1
        CHEAT   "INFINITE TIME",   0x102242, 1, 0x99
        | METAL SLUG 2: the lives, 2 at the start of the game (HUD 1UP=2).
        | On 2026-10-29, by known value (the HUD read at two frames, then the bytes that equal what it
        | displays): the mission time $1013B4, binary, 60. On 2026-10-30, by expected sequence in the
        | bomb scenario: the bombs $10C348, 10 at start ($10127C is only a copy of it).
        JEU     0x0241, 0xBE57, 3
        CHEAT   "INFINITE LIVES",  0x101276, 1, 0x02
        CHEAT   "INFINITE TIME",   0x1013B4, 1, 0x3C
        CHEAT   "INFINITE BOMBS",  0x10C348, 1, 0x0A
        | METAL SLUG X: the lives, 2 at start.
        JEU     0x0250, 0x92D4, 1
        CHEAT   "INFINITE LIVES",  0x101288, 1, 0x02
        | METAL SLUG 3: the lives, 2 at start. The bombs (2026-10-30, bomb scenario): $10EAF5, 10.
        JEU     0x0256, 0xE095, 2
        CHEAT   "INFINITE LIVES",  0x1002BB, 1, 0x02
        CHEAT   "INFINITE BOMBS",  0x10EAF5, 1, 0x0A
        | METAL SLUG 4: the lives, 2 at start.
        | On 2026-10-29, by known value: the mission time $10ED5C, BCD, 60. The bombs
        | (2026-10-30, bomb scenario): $10EDED, 10.
        JEU     0x0263, 0xD875, 4
        CHEAT   "INFINITE LIVES",  0x100A89, 1, 0x02
        CHEAT   "INFINITE TIME",   0x10ED5C, 1, 0x60
        CHEAT   "P2 INF. LIVES",   0x100CFC, 1, 0x02
        CHEAT   "INFINITE BOMBS",  0x10EDED, 1, 0x0A
        | METAL SLUG 5: the lives, 2 at start. The bombs (2026-10-30, bomb scenario): $10D457, 10.
        JEU     0x0268, 0x1581, 3
        CHEAT   "INFINITE LIVES",  0x100A41, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x1050C2, 1, 0x05
        CHEAT   "INFINITE BOMBS",  0x10D457, 1, 0x0A
        | PULSTAR: the lives, 2 at start.
        JEU     0x0089, 0xA232, 2
        CHEAT   "INFINITE LIVES",  0x10132A, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x10132B, 1, 0x02
        | BLAZING STAR: the lives, 2 at start.
        JEU     0x0239, 0xA454, 2
        CHEAT   "INFINITE LIVES",  0x101BA1, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x101BA3, 1, 0x02
        | ANDRO DUNOS: the lives, 3 at start.
        JEU     0x0049, 0x03FF, 1
        CHEAT   "INFINITE LIVES",  0x100343, 1, 0x03
        | GHOST PILOTS: the lives, 3 at start.
        JEU     0x0020, 0xA0C5, 2
        CHEAT   "INFINITE LIVES",  0x103F37, 1, 0x03
        CHEAT   "P2 INF. LIVES",   0x103FB7, 1, 0x03
        | LAST RESORT: the lives, 2 at start.
        JEU     0x0024, 0x03A4, 2
        CHEAT   "INFINITE LIVES",  0x108030, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x107596, 1, 0x02
        | MAGICIAN LORD: the lives, 2 at start.
        JEU     0x0005, 0x9330, 2
        CHEAT   "INFINITE LIVES",  0x103B00, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x103C00, 1, 0x02
        | STRIKERS 1945 PLUS: the lives, 2 at start.
        JEU     0x0254, 0xD5FF, 1
        CHEAT   "INFINITE LIVES",  0x1000E9, 1, 0x02
        | ZED BLADE: the lives, 3 at start.
        JEU     0x0076, 0x9553, 2
        CHEAT   "INFINITE LIVES",  0x100229, 1, 0x03
        CHEAT   "P2 INF. LIVES",   0x100029, 1, 0x03
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
        JEU     0x0022, 0xC32D, 2
        CHEAT   "INFINITE LIVES",  0x107000, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x107400, 1, 0x02
        | CAPTAIN TOMADAY: the lives, 2 at the highest; the witness run loses the game at frame 3831.
        JEU     0x0249, 0xE6CD, 2
        CHEAT   "INFINITE LIVES",  0x104026, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x101399, 1, 0x02
        | GANRYU: the lives, 3 at the highest; the witness run loses the game at frame 4912. The time,
        | $100453, binary, 99 at the highest: forced alone, TIME stays at 99 on the HUD.
        JEU     0x0252, 0x0111, 2
        CHEAT   "INFINITE LIVES",  0x1004A1, 1, 0x03
        CHEAT   "INFINITE TIME",   0x100453, 1, 0x63
        | NINJA COMBAT: the lives, 3 at the highest; the witness run loses the game at frame 5956.
        JEU     0x0009, 0x8C0D, 1
        CHEAT   "INFINITE LIVES",  0x102402, 1, 0x03
        | NEO BOMBERMAN: the lives, 2 at the highest; the witness run loses the game at frame 2500.
        JEU     0x0093, 0x5602, 1
        CHEAT   "INFINITE LIVES",  0x101658, 1, 0x02
        | NEO MR. DO!: the lives, 2 at the highest; the witness run loses the game at frame 5227.
        JEU     0x0207, 0x94A1, 2
        CHEAT   "INFINITE LIVES",  0x10465B, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x10465D, 1, 0x02
        | PREHISTORIC ISLE 2: the lives, 3 at the highest; the witness run loses the game at frame 5119.
        JEU     0x0255, 0x8E0D, 2
        CHEAT   "INFINITE LIVES",  0x105055, 1, 0x03
        CHEAT   "P2 INF. LIVES",   0x1062D5, 1, 0x03
        | SENGOKU 2: the lives, 3 at the highest; the witness run loses the game at frame 4646.
        JEU     0x0040, 0xCEF6, 2
        CHEAT   "INFINITE LIVES",  0x1001AF, 1, 0x03
        CHEAT   "P2 INF. LIVES",   0x1001B1, 1, 0x03
        | SENGOKU 3: the lives, 2 at the highest; the witness run loses the game at frame 7669.
        JEU     0x0261, 0x83B6, 2
        CHEAT   "INFINITE LIVES",  0x1083E1, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x1083FF, 1, 0x02
        | SHOCK TROOPERS 2ND SQUAD: the lives, 3 at the highest; the witness run loses the game at
        | frame 4699.
        JEU     0x0246, 0x5240, 2
        CHEAT   "INFINITE LIVES",  0x10905B, 1, 0x03
        CHEAT   "P2 INF. LIVES",   0x10915B, 1, 0x03
        | AERO FIGHTERS 2: the lives, 2 at the highest; the witness run loses the game at frame 6646.
        JEU     0x0075, 0xECD1, 2
        CHEAT   "INFINITE LIVES",  0x100615, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x100619, 1, 0x02
        | AERO FIGHTERS 3: the lives, 2 at the highest; the witness run loses the game at frame 2517.
        JEU     0x0097, 0x63E9, 1
        CHEAT   "INFINITE LIVES",  0x10E89B, 1, 0x02
        | SPIN MASTER: the lives, 2 at the highest; the witness run loses the game at frame 9562.
        JEU     0x0062, 0x915F, 2
        CHEAT   "INFINITE LIVES",  0x105015, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x10503D, 1, 0x02
        | THE SUPER SPY: 8 at the highest; ASSUMED lives, perhaps the energy (the cheat removes the
        | game over); the witness run loses the game at frame 9666.
        JEU     0x0011, 0xB441, 1
        CHEAT   "INFINITE LIVES",  0x10181F, 1, 0x08
        | TWINKLE STAR SPRITES: the lives, 3 at the highest; the witness run loses the game at frame
        | 9296. P2's (2026-10-30, P2 alone): $10D005; $100540, the cell ruled out on 2026-10-29, is
        | only a copy of it (game over under the cheat).
        JEU     0x0224, 0xC6FE, 2
        CHEAT   "INFINITE LIVES",  0x103745, 1, 0x03
        CHEAT   "P2 INF. LIVES",   0x10D005, 1, 0x03
        | VIEWPOINT: the lives, 3 at the highest; the witness run loses the game at frame 5989.
        JEU     0x0051, 0x691F, 2
        CHEAT   "INFINITE LIVES",  0x108D99, 1, 0x03
        CHEAT   "P2 INF. LIVES",   0x1090ED, 1, 0x03
        | ZUPAPA!: the lives, 3 at the highest; the witness run loses the game at frame 6482.
        JEU     0x0070, 0xEC13, 1
        CHEAT   "INFINITE LIVES",  0x1002C1, 1, 0x03
        | P1'S LIVES IN FIGHTING GAMES, 2026-10-29 (`bench/cheats-recherche.py` releve, then
        | bisect in an active or weak scenario: P1 hits a little, and wins on time when its life is
        | forced); P1's bars seen full on the HUD banners, P2's dented.
        | THE KING OF FIGHTERS '96: $108422, the damage taken by P1, forced to 0. The time, by known
        | value: $10A837, the frame countdown (forcing the seconds blocks the end of the round).
        JEU     0x0214, 0xEB0F, 2
        CHEAT   "P1 INFINITE LIFE", 0x108422, 1, 0x00
        CHEAT   "INFINITE TIME",   0x10A837, 1, 0x32
        | NINJA MASTER'S: $100050, P1's life, $D0 at the highest. The time: $10C021; the doubt of
        | 2026-10-25 (characters frozen under forcing) lifted on 2026-10-30: the game goes on, and only a
        | P1 that does not strike keeps the round endless (`measured/2026-10-30-cheats-table.tsv`).
        JEU     0x0217, 0x4720, 2
        CHEAT   "P1 INFINITE LIFE", 0x100050, 1, 0xD0
        CHEAT   "INFINITE TIME",   0x10C021, 1, 0x99
        | RAGE OF THE DRAGONS: $1023E6, P1's life, $10 at the highest. The time, by known value:
        | $106B11, the seconds, binary.
        JEU     0x0264, 0x8D79, 2
        CHEAT   "P1 INFINITE LIFE", 0x1023E6, 1, 0x10
        CHEAT   "INFINITE TIME",   0x106B11, 1, 0x3C
        | THE TIMERS OF FIGHTING GAMES, 2026-10-29, by known value: the HUD's TIME read at
        | three frames, then the RAM bytes that equal these numbers at the same frames, each
        | forced alone; the timer's area computed on the pictures (the
        | pixels frozen under the cheat, changing in the witness run). Value: the highest of the record.
        | FIGHT FEVER: the seconds, BCD.
        JEU     0x0060, 0x06A2, 1
        CHEAT   "INFINITE TIME",   0x108110, 1, 0x99
        | MATRIMELEE: the seconds, binary.
        JEU     0x0266, 0x5F99, 1
        CHEAT   "INFINITE TIME",   0x10B90B, 1, 0x3C
        | REAL BOUT FATAL FURY 2: the seconds, BCD.
        JEU     0x0240, 0x7F97, 1
        CHEAT   "INFINITE TIME",   0x107C28, 1, 0x60
        | SAMURAI SHODOWN III: the seconds, BCD.
        JEU     0x0087, 0xE4CB, 1
        CHEAT   "INFINITE TIME",   0x10849E, 1, 0x99
        | WORLD HEROES 2 JET: the seconds, BCD.
        JEU     0x0064, 0x8B26, 1
        CHEAT   "INFINITE TIME",   0x10C109, 1, 0x99
        | KING OF THE MONSTERS 2: the seconds, BCD.
        JEU     0x0039, 0x9C61, 1
        CHEAT   "INFINITE TIME",   0x1013D2, 1, 0x70
        | THE TIMERS OF FIGHTING GAMES FOUND ON 2026-10-29 AND PROVED ON 2026-10-30: same
        | search; the catalogue judges them on the digits' pixels only (the scenery scrolls behind),
        | or earlier in the round. Value: the highest of the record.
        | ART OF FIGHTING 3.
        JEU     0x0096, 0xC5DF, 1
        CHEAT   "INFINITE TIME",   0x10DF0F, 1, 0x3C
        | BREAKERS.
        JEU     0x0230, 0x9C95, 1
        CHEAT   "INFINITE TIME",   0x107C0B, 1, 0x63
        | FATAL FURY 2.
        JEU     0x0047, 0xAED3, 1
        CHEAT   "INFINITE TIME",   0x10092A, 1, 0x90
        | THE KING OF FIGHTERS '98.
        JEU     0x0242, 0x8F29, 1
        CHEAT   "INFINITE TIME",   0x10A83B, 1, 0x32
        | SAVAGE REIGN.
        JEU     0x0059, 0xF782, 1
        CHEAT   "INFINITE TIME",   0x1084A8, 1, 0x60
        | GAROU: MARK OF THE WOLVES.
        JEU     0x0253, 0x6078, 1
        CHEAT   "INFINITE TIME",   0x107490, 1, 0x60
        | WORLD HEROES PERFECT.
        JEU     0x0090, 0x5FA2, 1
        CHEAT   "INFINITE TIME",   0x10C109, 1, 0x99
        | THE LAST BLADE 2.
        JEU     0x0243, 0xB546, 1
        CHEAT   "INFINITE TIME",   0x10E595, 1, 0x61
        | GOWCAIZER.
        JEU     0x0094, 0x4B34, 1
        CHEAT   "INFINITE TIME",   0x1062E1, 1, 0x3C
        | THE TIMES OF ACTION GAMES BY EXPECTED SEQUENCE, 2026-10-29: the byte that follows exactly
        | v0, v0 − 1… from 30, 50, 59, 60, 90 or 99 (`bench/cheats-recherche.py`, filtre_suite), forced
        | alone; the digits' area computed on the pictures of the forcing.
        | BURNING FIGHT: the time, BCD, 60; slow, judged in the counter genre.
        JEU     0x0018, 0xA9E4, 1
        CHEAT   "INFINITE TIME",   0x10D002, 1, 0x60
        | THE LIVES BY EXPECTED SEQUENCE IN THE JUMP SCENARIO, 2026-10-29: P1 moves forward jumping
        | without shooting (the user's idea, to die quickly); the byte that follows exactly 3, 2, 1…
        | (or from 1 to 5), forced alone from frame 700: no more game over, the witness run loses its own.
        | ALPHA MISSION II: the lives, 2 at start.
        JEU     0x0007, 0x799C, 2
        CHEAT   "INFINITE LIVES",  0x1010F2, 1, 0x02
        CHEAT   "P2 INF. LIVES",   0x1011F2, 1, 0x02
        | CROSSED SWORDS: the lives, 5 at start.
        JEU     0x0037, 0xB3BC, 2
        CHEAT   "INFINITE LIVES",  0x10405C, 1, 0x05
        CHEAT   "P2 INF. LIVES",   0x1040DC, 1, 0x05
        | EIGHT MAN: the lives, 3 at start.
        JEU     0x0025, 0xBDFA, 2
        CHEAT   "INFINITE LIVES",  0x100CF7, 1, 0x03
        CHEAT   "P2 INF. LIVES",   0x10131B, 1, 0x02
        | NIGHTMARE IN THE DARK: the lives, 3 at start.
        JEU     0x0260, 0x3085, 2
        CHEAT   "INFINITE LIVES",  0x100055, 1, 0x03
        CHEAT   "P2 INF. LIVES",   0x10028B, 1, 0x03
        | ROBO ARMY: the lives, 2 at start.
        JEU     0x0032, 0x95B5, 1
        CHEAT   "INFINITE LIVES",  0x1000D2, 1, 0x02
        | CYBER-LIP: the lives, 2 at start (expected sequence, action scenario).
        JEU     0x0010, 0x6484, 1
        CHEAT   "INFINITE LIVES",  0x10209D, 1, 0x02
        | IRONCLAD: the lives, 5 at start (expected sequence, action scenario).
        JEU     0x0220, 0xD34D, 1
        CHEAT   "INFINITE LIVES",  0x10B113, 1, 0x05
        | MUTATION NATION: the lives, 3 at start (expected sequence, action scenario).
        JEU     0x0014, 0x7834, 1
        CHEAT   "INFINITE LIVES",  0x102530, 1, 0x03
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
        JEU     0x0206, 0x88FB, 1
        CHEAT   "NO GAME OVER",     0x101303, 1, 0x03
        | PUZZLE BOBBLE 2.
        JEU     0x0248, 0x5F90, 1
        CHEAT   "NO GAME OVER",     0x1057CA, 1, 0x02
        | PUZZLE BOBBLE.
        JEU     0x0083, 0x19FA, 1
        CHEAT   "NO GAME OVER",     0x102284, 1, 0x02
        | POWER SPIKES II.
        JEU     0x0068, 0xB80B, 1
        CHEAT   "NO GAME OVER",     0x102D4A, 1, 0x02
        | QUIZ MEITANTEI NEO & GEO.
        JEU     0x0042, 0xBE81, 1
        CHEAT   "NO GAME OVER",     0x101AC4, 1, 0x03
        | QUIZ DAISOUSA SEN.
        JEU     0x0023, 0x3ECF, 1
        CHEAT   "NO GAME OVER",     0x1022B3, 1, 0x03
        | QUIZ KING OF FIGHTERS.
        JEU     0x0080, 0x7AA7, 1
        CHEAT   "NO GAME OVER",     0x10150A, 1, 0x03
        | SUPER SIDEKICKS.
        JEU     0x0052, 0xFEF0, 1
        CHEAT   "INFINITE TIME",    0x108ED3, 1, 0x59
        | STREET HOOP.
        JEU     0x0079, 0x6DB5, 2
        CHEAT   "NO GAME OVER",     0x102D21, 1, 0x02
        CHEAT   "INFINITE TIME",    0x101A53, 1, 0x59
        | TECMO WORLD SOCCER 96.
        JEU     0x0086, 0xCB1D, 1
        CHEAT   "NO GAME OVER",     0x1014D7, 1, 0x05
        | ON 2026-10-30, the same search by expected sequence, in the action scenario; judged by the
        | menu at frame 1500, or as soon as the game starts (trally 2600, zintrckb 2500).
        | GURURIN.
        JEU     0x0067, 0x97E7, 1
        CHEAT   "NO GAME OVER",     0x101C17, 1, 0x02
        | THRASH RALLY.
        JEU     0x0038, 0x5FF9, 1
        CHEAT   "NO GAME OVER",     0x107105, 1, 0x05
        | ZINTRICK.
        JEU     0x0211, 0x1F3E, 1
        CHEAT   "NO GAME OVER",     0x100349, 1, 0x02
        | NINJA COMMANDO, 2026-10-30: the search by expected sequence
        | up to frame 20,000 (the witness run loses the game around 16,400); the lives, 2 at start.
        JEU     0x0050, 0x004D, 1
        CHEAT   "INFINITE LIVES",  0x106030, 1, 0x02
        | FIGHTING GAME TIMERS BY EXPECTED SEQUENCE, 2026-10-30: passive scenario, the byte that
        | counts down from 60 or 99 and is reset at each round (filtre_suite), seen frozen on the
        | images under the cheat; the digits' zone searched on the images of a CAT_DENSE run.
        | THE KING OF FIGHTERS 2003.
        JEU     0x0271, 0x0F9A, 1
        CHEAT   "INFINITE TIME",   0x107D62, 1, 0x60
        | REAL BOUT FATAL FURY.
        JEU     0x0095, 0x8E2F, 1
        CHEAT   "INFINITE TIME",   0x106AA8, 1, 0x60
        | KIZUNA ENCOUNTER: the fight only starts around frame 2700.
        JEU     0x0216, 0x073D, 1
        CHEAT   "INFINITE TIME",   0x10892A, 1, 0x99
        FIN_TABLE
        .balign 2
