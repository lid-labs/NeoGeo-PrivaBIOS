| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| SYSTEM_IO ($C0044A) AND CREDIT_CHECK ($C00450) — two entries of the call table.
|
| The six-byte slots of `c0.s` carry only a `jmp`: the code lives here, in `.text`,
| which `build/bios.ld` links after `.vectors`, hence beyond $C00800.
|
| THREE KINDS OF CLAIM, and each says which it is:
|   "measured"  : a contract from `specs/traces/`, named — `appel_C0044A.md` (80 calls),
|                 `appel_C00450.md` (69), `appel_C00438.md` (48, INT1); the ratios in /32,
|                 /23 and /16 below date from their versions of 32, 23 and 16 calls,
|                 `protocole.md` (the hand-overs);
|   "read in"   : a page of the NeoGeo Development Wiki, named;
|   "ASSUMED"   : neither one nor the other, and it is said.
|
| THE STRUCTURE. "SYSTEM_INT1" says INT1 calls SYSTEM_IO: the input read, the coin edge,
| the credit, the displays and the timer are therefore ONE routine, `_io_commun`, which
| the public entry `_systeme_io` and `_systeme_int1` (`int1.s`) call. The two measured
| cores almost overlap: that of $C00438 additionally has $300001, $3C000C, $10FEE4,
| $10FE8C, $10FEC6 and the MESS_OUT variables, which `int1.s` keeps to itself — $10FE8C
| and $10FEC6 are NOT in the core of $C0044A.
|
| COIN_SOUND AND PLAYER_START ARE ONLY IN THE PUBLIC ENTRY. Neither one is called from
| INT1: the protocol log shows no hand-over to $000134 or to $000128 during the frames
| where INT1 credits a coin (trace 2, frame 500.9) — they only leave from a call entered
| at $C0044A (traces 3 and 4). The hand-over for a coin outside a game, for its part,
| only leaves from SYSTEM_IO since 2026-10-22 (end of `_io_commun`).
|
| THE FORCED START ("game start compulsion"), set aside until 2026-10-17: armed on the
| coin (`_io_crediter`), counted down and triggered on the title (`_io_compulsion`).
| Measured: `measured/2026-10-17-diagnostic-b2b-minasan.tsv`, MINASAN game.
|
| WHAT THESE ROUTINES DO NOT DO, deliberately:
|   - DEMO_END ($00012E) outside the measured cases, the coin that makes the credit during
|     the demo (`_io_fin_demo`, 2026-10-22) and SELECT (`_io_select`, 2026-10-23);
|   - give a meaning to $10FEE0, $D0002C, $D00039: no page names them. Since 2026-10-23,
|     their measured values are written at their places, nothing more (`_io_crediter`,
|     `_io_commun`; $10FEE0 in `_retour_demo_end`, `c0.s`);
|   - the scattered bookkeeping writes $D08324-$D0A1D2 (1/32, pairs $0000/$0001 or
|     $0002): "Backup RAM" places them in the daily and monthly data blocks, dated
|     "YYMMDDdd"; without a calendar, no date, hence set aside;
|   - $D00042 ("Game select", "1=Free", which the 2026-10-25 batch did not measure), the
|     coin mechanism lockout ($3800E5/E7), coins 3 and 4 and the service button;
|   - the reference BIOS's stack ($10F25E-$10F2BC, "retenue (§8)"): our own return
|     addresses replace it.
| ==================================================================================

        .text
        .global _systeme_io
        .global _credit_check
        .global _io_commun
        .global _io_temps

        .equ    BORNE, 0x10FB20         | the cabinet settings in RAM (`reglages.s`, `_borne_ram`)
        .equ    DIPSW, 0x300001         | on read: the board switches, active low
        | The autofire in RAM, set by `autofire.s` (its layout is described there).
        .equ    AF_MASQUE, 0x10FB41
        .equ    AF_PH1,   0x10FB42
        .equ    AF_PH2,   0x10FB43
        .equ    AF_REL,   0x10FB44
        .equ    AF_SUIV,  0x10FB4C

| ----------------------------------------------------------------------------------
| SYSTEM_IO, THE PUBLIC ENTRY — reached by `jmp` from $C0044A, hence the game entered it
| by `jsr` and leaves it by our `rts`.
|
| NO REGISTER IS SAVED. Read in "SYSTEM_IO": "This call does NOT save registers". We
| follow the page, and it is also what lets PLAYER_START and COIN_SOUND, called from
| here, use all the registers.
| ----------------------------------------------------------------------------------
_systeme_io:
        | THE GAME'S %d7 RETURNED INTACT: it was so before `_io_commun` read it as a flag
        | (under SYSTEM_IO here, under INT1 in `int1.s`); we do not change what the call
        | returns to the game.
        move.l  %d7, -(%sp)
        moveq   #1, %d7                 | under SYSTEM_IO (end of `_io_commun`)
        bsr     _io_commun             | %d6: coins accepted on this frame
        move.l  (%sp)+, %d7
        | THE IN-GAME MENU (`menu.s`, high area, hence the absolute `jsr`): the gesture, on
        | each call, and the menu if it is made. Returns all the registers.
        jsr     _menu_en_jeu

        | BIOS_FRAME_SKIP ($10FEE1), read in "BIOS RAM locations": "Number of frames to
        | skip in the routine which checks demo_end or if the player has pressed start",
        | "Decremented in SYSTEM_IO". Measured (`protocole.md`, trace 9): $FF set on each
        | request, $0A on the next frame (239.41, 244.41), then −1 per frame down to $00
        | (254.00). A hand-over of request 2 or 3 now enters at $09 (`c0.s`,
        | `_remettre_a_user`, measured there): the reload below now only serves after a
        | request 0 given by SYSTEM_RETURN, entered at $FF — measured on the reference, $0A
        | set under the game two frames after that hand-over (log of 2026-10-22).
        | ASSUMED: the $FF → $0A reload done here, without a countdown on the same frame.
        | Non-zero: neither START nor COIN_SOUND; `_io_commun`, above, credited anyway
        | (measured under MAME on `neomrdo`: credit set during the countdown).
        | %d0 ZERO-EXTENDED before the hand-overs (COIN_SOUND below, PLAYER_START in
        | `_io_start`): otherwise its bits 8-31 are the game's at the entry of the call.
        | Measured under MAME on 2026-10-21 on `flipshot`: its PLAYER_START routine ($0007DA)
        | chooses where to jump from %d0 as the BIOS leaves it, bytes 8-15 included — a
        | non-zero byte 8-15 sends it to $0000565D, address error.
        | The code of `menu.s` added, its cycles move the instant at which the vblank
        | interrupts the game, hence what it leaves in %d0: the defect, latent, appeared on
        | the START of frame 1,300 of the bench. ASSUMED: that the reference BIOS zeroes %d0
        | likewise (the game runs under it); nothing else says so.
        moveq   #0, %d0
        move.b  0x10FEE1, %d0
        beq.s   3f
        cmpi.b  #0xFF, %d0
        bne.s   1f
        move.b  #0x0A, 0x10FEE1
        bra.s   2f
1:      subq.b  #1, 0x10FEE1

        | THE DEFERRED SOUND. Measured under MAME on `neomrdo`: coin around frame 243, during
        | the countdown, and COIN_SOUND around frame 255, the first after zero — trace 9,
        | hand-over to $000134 at 255.15, from a call entered at $C0044A. The coin is
        | therefore remembered. The cell, $10FEE2: no page names it; measured,
        | `appel_C0044A.md` writes it on 3/80 calls, $00 or $01, and `appel_C00438.md` on
        | 3/48, $01 only — a mark set, then cleared by SYSTEM_IO. That it carries that sound
        | is ASSUMED, as is its value $01. INT1 sets it too in the reference; here, only for
        | a coin outside a game (`_io_son_piece`).
2:      tst.b   %d6
        beq.s   4f
        cmpi.b  #2, 0x10FDAF
        bcs.s   4f                      | outside a game: already marked (`_io_son_piece`)
        move.b  #0x01, 0x10FEE2
4:      bra     _io_temps               | the play time, at the end of the call

        | COIN_SOUND, at zero FRAME_SKIP: coin of this frame, or remembered coin. Measured:
        | `protocole.md`, trace 4, hand-over to $000134 from a call entered at $C0044A, on
        | the coin's frame. "68k program header": $000134 carries "JMP to COIN_SOUND
        | subroutine"; the page does not say how the BIOS reaches it. ASSUMED: by `jsr`,
        | the game returning by `rts`, and once per frame whatever the coin — and as soon
        | as the coin is accepted, even if it does not yet make a credit.
        | THE CALL ITSELF is made in `_io_commun` (`_io_son_piece`), coin of this frame as
        | well as remembered coin, at the place the reference gives it: it has already left
        | here.
3:

| ----------------------------------------------------------------------------------
| THE FORCED START ("game start compulsion"). Output: %d4 = bit 0 at 1 if the timer has
| just reached 00/00, which `_io_start` adds to the press of START P1 — the start then
| follows the path of a START, without duplicating flag, PLAYER_START or deduction.
|
| Read in "BIOS RAM locations": $10FDDA (BIOS_COMPULSION_TIMER) in BCD seconds,
| $10FDDB the frame timer, "When it underflows, the timer is reset to 59 and
| START_COMPULSION_TIMER is decremented". Read in "PLAYER START subroutine": the
| routine is also called "when the time runs out while the game's title screen is
| being displayed". Measured (MINASAN log, `measured/2026-10-17-diagnostic-b2b-minasan.tsv`):
| −1 per frame from $3B to $00, then seconds −1 and $3B; at 00/00, title mode and one credit,
| $000128 reached with $10FDB4 = $01, then mode 2 and one credit deducted. Measured too (same
| log, two coins): reload at 901, 00 and PLAYER_START at 2700, i.e. 1799 frames,
| 30 s — the start falls when the seconds go from 01 to 00, without one more second at
| 00/3B (measured under MAME on our image before this fix: start at 2771).
| "Title" = BIOS_USER_MODE ($10FDAF) at 1, "Title/Demo" ("BIOS RAM locations"), AND
| BIOS_USER_REQUEST ($10FDAE) at 3: the demo without credit does not count down. Measured under
| MAME on 2026-10-22 (-bios euro, puzzledp, two coins per credit; `measured/2026-10-22-ecarts-remise-
| credit.tsv`): armed at $30 by a coin without credit during the demo, $10FDDA stays there 400
| frames, until the next coin.
| THE DEMO WITH A CREDIT COUNTS DOWN. Measured under MAME on 2026-10-22 (-bios euro, puzzledp and
| mslug; `measured/2026-10-22-piece-demo-end.tsv`): on the coin that makes the credit during
| the demo, $10FDDB goes from $3B to $3A in the very call that calls DEMO_END (on the coin's
| frame, or on the first zero FRAME_SKIP if it falls during the skip). Hence the
| condition: title, or demo with a credit. ASSUMED: the title without credit still counts
| down (never seen on the reference, which does not go there without credit) — we change
| nothing there.
| Read in "Backup RAM": $D00043, "Game start compulsion (0 = enabled, 1 =
| disabled)"; honoured here. ASSUMED: any non-zero value disables.
|
| ASSUMED: here, under zero FRAME_SKIP, and not on each call. The trigger goes through
| `_io_start`, which is only reached at zero FRAME_SKIP; a 00/00 reached during the skip
| would be lost, or would require a cell that no page names. "BIOS RAM
| locations" says the skip covers "the routine which checks [...] if the player has
| pressed start"; that the forced start is part of it is the assumption.
| A timer at 00/00 is disarmed: nothing counts down or retriggers without a new
| coin. ASSUMED: a refused start (no P1 credit, or PLAYER_START clearing the
| bit) is not retried.
| ----------------------------------------------------------------------------------
_io_compulsion:
        moveq   #0, %d4                 | no forced start
        cmpi.b  #1, 0x10FDAF
        bne.s   _io_select              | outside the title: no countdown
        cmpi.b  #3, 0x10FDAE
        beq.s   2f                      | the title counts down
        tst.b   0xD00034
        beq.s   _io_select              | the demo without credit: no countdown
2:      tst.b   0xD00043
        bne.s   _io_select              | disabled
        tst.w   0x10FDDA
        beq.s   _io_select              | 00/00: disarmed
        move.b  0x10FDDB, %d1
        subq.b  #1, %d1
        bcc.s   1f                      | not below zero
        move.b  0x10FDDA, %d2           | seconds ≥ 01 here: no borrow
        moveq   #1, %d3
        move.w  #0, %ccr                | X at 0 before `sbcd`
        sbcd    %d3, %d2
        move.b  %d2, 0x10FDDA
        moveq   #0, %d1                 | seconds gone from 01 to 00: 00/00, start
        tst.b   %d2
        beq.s   1f
        moveq   #0x3B, %d1
1:      move.b  %d1, 0x10FDDB
        tst.w   0x10FDDA
        bne.s   _io_select
        moveq   #1, %d4                 | 00/00 reached: START P1 forced

| ----------------------------------------------------------------------------------
| THE GAME SELECTION BY SELECT, on a board with several slots. Does not return if it
| leaves (`_retour_selection`, `c0.s`); otherwise, what follows: the end of demo, START.
| AFTER THE FORCED START. MEASURED under MAME on 2026-10-23 (-bios euro, puzzledp + aof, SELECT
| on frames 1200 and 1213; `measured/2026-10-23-titre-apres-game-over.tsv`, section 2), the
| reference, in the SELECT call: $10FDDB counted down, $380031 ← $FF, $10FEE0 ← $00,
| $10FD81 ← $04, then DEMO_END ($00012E read). Our image tested SELECT before the countdown,
| and did not call DEMO_END. $10FEE0, $10FD81 and DEMO_END: `_retour_selection`. ASSUMED, the
| %d4 guard: a forced start fallen in the same call goes before SELECT, the reference
| testing START before it (the $FF of `_io_verrous_hauts`, "at the end of the START test").
| RE-ENTRY GUARD, DELIBERATE DEPARTURE (`docs/DECISIONS.md` §10). MEASURED under MAME on
| 2026-10-23 (b2b + puzzledp, SELECT at 1050 then at 1052; `measured/2026-10-23-titre-apres-game-over.tsv`,
| section 6): b2b calls SYSTEM_IO from the DEMO_END of the SELECT, and the reference takes the
| second edge there: DEMO_END called again while the first has not finished, which is never resumed.
| We correct: the game's routine, re-entered midway, precedes the save of its RAM. Here,
| SELECT is ignored as long as $10FD81 is $04/$05: set by `_retour_selection` before
| DEMO_END, returned to $02 before the hand-over. Measured: `measured/2026-10-23-garde-select.tsv`.
|
| MEASURED on the reference (`bench/multislot.lua`, -bios euro, MV-6F, 2026-10-22;
| `measured/2026-10-22-multi-slot-lot4.tsv`):
|   - SELECT P1 ("Next Game" in MAME, bit 1 of REG_STATUS_B) → BIOS_SYSRET_STATUS ←
|     $04 and the next occupied slot; SELECT P2 ("Previous Game", bit 3) → $05 and the
|     previous occupied slot; empty ones skipped, wrap-around in both directions (2 and 3
|     cartridges, an empty slot between two);
|   - taken on the title with a credit (request 3, mode 1, $D00034 ≠ 0), fresh NVRAM as well as
|     kept; ignored in demo without credit, in a game with or without credit, and on the title
|     as long as BIOS_FRAME_SKIP is not at zero: a SELECT 9 frames after the hand-over is
|     lost, one at 10 frames taken, on the frame where FRAME_SKIP is read at $00 — the START
|     rule here, hence the place of this test. The hand-over sets FRAME_SKIP to $09 like the
|     reference (`c0.s`, `_remettre_a_user`): taken at 10 frames on ours too;
|   - on the edge only: held 80 frames, a single change;
|   - the credit is not touched.
| The credit is never seen at zero on the title on the reference (a coin that does not make
| a credit does not lead there, measured) nor non-zero in demo (the boot zeroes $D00034): the
| test is therefore the narrowest that covers the measured cases, request 3 AND credit, ASSUMED.
| Read in "BIOS RAM locations": "Game selection can only be done on MVS systems when
| this byte is < 2" ($10FDAF), and BIOS_STATCHANGE without its SELECT bits on MVS (`_io_commun`),
| hence the read of BIOS_STATCHANGE_RAW ($10FEDD). On AES (BIOS_MVS_FLAG zero), nothing.
| ASSUMED: both SELECTs on the same edge, P1 wins.
|
| A SINGLE CARTRIDGE: SELECT IGNORED, DELIBERATE DEPARTURE. Measured, the reference takes the
| same path on the slot itself (code 4 or 5, save then restore of the same block, title
| restarted); the mandate of this batch keeps the single cartridge and the single-slot MVS unchanged.
| ----------------------------------------------------------------------------------
_io_select:
        tst.b   %d4
        bne.s   _io_fin_demo            | the forced start has just fallen: START first
        tst.b   0x10FD82                | BIOS_MVS_FLAG: the AES mode has its rule, below
        beq.s   _io_select_aes
        cmpi.b  #1, 0x10FDAF            | BIOS_USER_MODE: title / demo
        bne.s   _io_fin_demo
        cmpi.b  #3, 0x10FDAE            | BIOS_USER_REQUEST: title
        bne.s   _io_fin_demo
        tst.b   0xD00034                | a credit
        beq.s   _io_fin_demo
_io_select_garde:
        cmpi.b  #4, 0x10FD81            | a SELECT in progress (the game's DEMO_END): ignored
        beq.s   _io_fin_demo
        cmpi.b  #5, 0x10FD81
        beq.s   _io_fin_demo
        move.b  0x10FEDD, %d0           | BIOS_STATCHANGE_RAW: new presses
        moveq   #4, %d6                 | SELECT P1: code 4, the next
        btst    #1, %d0
        bne.s   1f
        moveq   #5, %d6                 | SELECT P2: code 5, the previous
        btst    #3, %d0
        beq.s   _io_fin_demo
1:      jsr     _slot_suivant           | %d1; clobbers %d2, %d3, %d5, %a1
        cmp.b   0xD00108, %d1
        beq.s   _io_fin_demo            | no other occupied slot: ignored
        bsr     _io_verrous_hauts
        jmp     _retour_selection       | `c0.s`, %d6: the code; does not return

| SELECT IN AES MODE — on an MVS board with several slots, the multi-slot being kept
| (decision D3). The MVS rule does not apply there: it wants the BIOS title with a credit,
| and the AES mode has neither one nor the other. THE MOST RESTRICTED PATH, DELIBERATE
| DEPARTURE (DECISIONS §11): SELECT is only taken in demo (mode 1, request 2), with the same
| re-entry guard and the same FRAME_SKIP skip as in MVS, and it leads to the demo of the next
| game (`_retour_selection`), never to the title. In a game, the BIOS does not touch it: the
| game receives it (BIOS_STATCHANGE, its pause). No reference: the AES has only one slot.
_io_select_aes:
        cmpi.b  #1, 0x10FDAF            | BIOS_USER_MODE: title / demo
        bne.s   _io_fin_demo
        cmpi.b  #2, 0x10FDAE            | BIOS_USER_REQUEST: the demo
        bne.s   _io_fin_demo
        bra.s   _io_select_garde

| ----------------------------------------------------------------------------------
| THE END OF THE DEMO BY THE COIN. MEASURED under MAME on 2026-10-22 (-bios euro, one
| cartridge, `measured/2026-10-22-piece-demo-end.tsv`): the coin that makes the credit
| during the demo leads, in the same call and after COIN_SOUND, to DEMO_END then to the
| title (`_retour_demo_end`, `c0.s`). During the BIOS_FRAME_SKIP countdown, the reference
| only credits, and sounds then calls DEMO_END on the first call that reads it at $00 (coin
| 3 or 7 frames after the demo hand-over: both on frame 760 on puzzledp) — hence the
| place of this test, after the skip, like START and SELECT, and after the forced start: the
| reference counts $10FDDB down once in that very call (see `_io_compulsion`).
| ASSUMED, the condition: demo (mode 1, request 2) and a credit, rather than a mark of the
| coin — the reference is never in demo with a credit outside this case (the boot clears it).
| ----------------------------------------------------------------------------------
_io_fin_demo:
        cmpi.b  #1, 0x10FDAF            | BIOS_USER_MODE: title / demo
        bne.s   _io_start
        cmpi.b  #2, 0x10FDAE            | BIOS_USER_REQUEST: the demo
        bne.s   _io_start
        tst.b   0xD00034                | a credit
        beq.s   _io_start
        | NO SECOND ENTRY DURING DEMO_END. Measured under MAME on 2026-10-22 (b2b, coin on
        | frame 3300): a game can call SYSTEM_IO from its DEMO_END routine (the
        | reference stays there 35 frames on b2b); on ours, the demo and the credit still
        | holding, the call called DEMO_END again, endlessly, and the machine restarted from zero.
        | ASSUMED, the guard: BIOS_SYSRET_STATUS at $06, set just before DEMO_END
        | (`_retour_demo_end`) and returned to $02 after it.
        cmpi.b  #6, 0x10FD81
        beq.s   _io_start
        bsr     _io_verrous_hauts
        jmp     _retour_demo_end        | `c0.s`: does not return

| ----------------------------------------------------------------------------------
| START WITH CREDIT.
|
| Read in "PLAYER START subroutine": the BIOS calls it when a START button is
| pressed and the player "has enough credits"; BIOS_START_FLAG ($10FDB4) carries the
| players as bits active at 1 — "The 4 LSBs correspond to the player who pushed start"
| ("BIOS RAM locations") —, the routine leaves them at 1 if the game can start, clears
| them otherwise, and "After returning, the System ROM deducts credits according to
| BIOS_CREDIT_DEC" — contradicted by the measurement, see THE DEDUCTION below.
|
| Measured (`appel_C0044A.md`, the call of 84,043 accesses; `protocole.md`, trace 3,
| hand-over to $000128 from $C0044A): $10FDB4 ← $01, $10FD81 ← $03, $D00034 ← $00, and
| control to the game along the way — its 16,466 writes are the start of the game.
|
| "ENOUGH CREDITS": a non-zero player credit, without looking at BIOS_CREDIT_DEC.
| Measured under MAME on `wjammers`: the reference accepts a START with $D00034 = $01 while
| $10FDB0 is $00 at the moment of the decision — it zeroes $10FDB0 on each
| frame where the game's request exceeds the credit (on the title, $0202 requested for 1 credit).
| Neither "DEC zero → refusal" nor "request > credit → refusal", which the previous guard
| carried: the measurement refutes them both. Credit in BCD, so any non-zero byte
| is worth at least 1. Free play ($D00042) stays set aside from this batch.
| The START P1 bit is bit 0 of BIOS_STATCHANGE, that of P2 bit 2
| ("BIOS RAM locations", layout of REG_STATUS_B); in BIOS_START_FLAG, P1 is
| bit 0 and P2 bit 1 — measured, START P2 alone makes the reference write $02 there.
|
| THE START OF P2, and the two writes of BIOS_START_FLAG. Measured under MAME on
| 2026-10-22 under the reference (`-bios euro`), cyberlip, kof94 and aof, same input
| plans as our image ("start of P2" log, RAM values written by the
| reference):
|   - on each START edge, $10FDB4 first receives the bits of the pressed players
|     ($01 for P1, $02 for P2), then the decision: the accepted bits, or $00 — without
|     credit ($D00034 at $00, in demo as in a game), the reference writes $02 then $00
|     and does not call PLAYER_START;
|   - in a game (mode 2), START P2 with $D00034 = $01 and $D00035 = $00: $10FDB4 ← $02,
|     PLAYER_START, then one credit taken from $D00034 if the game keeps the bit (kof94: P2
|     joins, $D00034 $01 → $00); none if the game clears it (cyberlip, aof);
|   - on the title (mode 1), START P2 starts BOTH players: with $D00034 = $02,
|     $10FDB4 ← $02 then $03, PLAYER_START with $03, and two credits taken from $D00034
|     ($02 → $01 → $00); with $D00034 = $01, $02 then $00, nothing else;
|   - $D00035 is never read as credit nor written outside the boot: the credit is shared
|     (likewise CREDIT_CHECK, below, and coin 2, `_io_crediter`).
| ASSUMED: mode 0 follows the title's rule (only the title, the demo without credit and the
| game were measured); START P1 and P2 on the same edge — never measured —: P1 first,
| P2 in a game if a credit remains after it; a START P1 in a game with a credit,
| like P2 (measured under the reference: sbp, PLAYER_START called, log of refused
| starts).
| ----------------------------------------------------------------------------------
_io_start:
        moveq   #0, %d0                 | zero-extended: see `_systeme_io`
        move.b  0x10FDAD, %d0           | BIOS_STATCHANGE: new presses
        or.b    %d4, %d0                | plus the forced START P1 (`_io_compulsion`)
        moveq   #0, %d1                 | the pressed players, in BIOS_START_FLAG bits
        btst    #0, %d0
        beq.s   1f
        bset    #0, %d1
1:      btst    #2, %d0
        beq.s   2f
        bset    #1, %d1
2:      tst.b   %d1
        beq     9f
        btst    #1, BORNE               | NO CONTINUE: see `_io_sans_continue`
        bne     _io_sans_continue
_io_presses:
        move.b  %d1, 0x10FDB4           | first write: the pressed ones (measured)

        | THE DECISION, %d2: the accepted players. Shared credit $D00034, BCD — the order
        | of BCD bytes is that of the integers, hence the unsigned `cmpi`.
        | The AES mode, without credit, is refused here and taken up again on the refusal
        | (`_io_start_refus`).
        moveq   #0, %d2
        move.b  0xD00034, %d3
        btst    #0, %d1
        beq.s   1f
        tst.b   %d3
        beq.s   1f                      | zero credit: P1 refused
        bset    #0, %d2
1:      btst    #1, %d1
        beq.s   2f
        cmpi.b  #2, 0x10FDAF            | BIOS_USER_MODE: in a game?
        beq.s   3f
        cmpi.b  #2, %d3                 | title: both players, two credits
        bcs.s   2f
        moveq   #3, %d2
        bra.s   2f
3:      moveq   #1, %d5                 | game: one credit for P2...
        btst    #0, %d2
        beq.s   4f
        moveq   #2, %d5                 | ...plus that of P1 accepted on the same edge
4:      cmp.b   %d5, %d3
        bcs.s   2f
        bset    #1, %d2
2:      move.b  %d2, 0x10FDB4           | second write: the decision (measured)
        beq     _io_start_refus         | refused: neither PLAYER_START nor deduction, in MVS

        | PLAYER_START. "68k program header": $000128 carries "JMP to PLAYER_START
        | subroutine". ASSUMED: by `jsr`, return by `rts` — the contract shows the call
        | returning to the game through $00026A after this detour. All registers are lost.
        jsr     0x128

        | THE DEDUCTION: one credit per player left at 1 in BIOS_START_FLAG, read again after
        | the return (the game can clear a player during PLAYER_START), taken from the shared
        | credit $D00034 for P2 too (measured, see the header: kof94 and the title for two).
        | Measured under MAME on `wjammers`, coin mechanism by default "1 coin 1 credit": the
        | reference deducts 1 with 2 credits ($02 → $01) while the game requests $0202 and
        | $10FDB0 is $00 before as after the decision, and 1 with 1 credit while DEC is still
        | $00 on return — the game only sets $0101 on the next frame. The wiki sentence
        | quoted above therefore does not hold in this regime. ASSUMED: the 1 is the
        | "credits per start" setting at its default value; the soft-DIPs are outside this batch.
        | BCD subtraction: "Backup RAM" gives the credits in BCD. The guard saw a
        | non-zero credit, but nothing says that a PLAYER_START does not consume it itself:
        | if the credit is at zero on return, the borrow of `sbcd` says so and the credit stays
        | at zero instead of wrapping to $99 — ASSUMED, nothing documents this case.
        move.b  0x10FDB4, %d1
        | THE FORCED START IS DISARMED WHEN THE GAME STARTS. Measured under MAME (diagnostic of
        | 2026-10-22, $10FDB4 and $10FDDA written by the reference, `sbp` and `trally` logs):
        | after the return from PLAYER_START, if the game left its bit, the reference writes the
        | word $10FDDA ← $0000 (sbp 400, trally 700); if the game cleared it — START in the middle
        | of a game, sbp 700 and 1000, trally 1000 —, it does not touch it. Without this, sbp
        | stayed on the title (mode 1) with its credit deducted, on each START; forced to zero
        | under our image, it goes to mode 2 (diagnostic, same log).
        | BIOS_SYSRET_STATUS ($10FD81) ← 3, under the same condition and just after. Read in
        | "BIOS RAM locations": 3 = "After a gameover, save the playtime for bookeeping,
        | switch to DEMO mode, reset the workbackup ram"; the end-of-game SYSTEM_RETURN
        | reads it (`c0.s`, `_retour_systeme`). MEASURED under the reference
        | (`measured/2026-10-22-repetition-et-start.tsv`: aof, mslug, alpham2, garou): written
        | after the return from PLAYER_START, after $10FDDA and before the deduction, only if
        | the game left a bit — no START cleared by the game writes it. Our image
        | wrote it before PLAYER_START, on any accepted START.
        | BIOS_FRAME_SKIP ← $01 FIRST, under the same condition. MEASURED under MAME on 2026-10-23
        | (-bios euro, nam1975 and aof, START at 2100; `measured/2026-10-23-led-et-remises.tsv`,
        | section 2), the reference: $10FEE1 ← $01, then $10FDDA, $10FD81, the deduction; on
        | the next call, the countdown at $00. A START cleared by the game (aof, P2 in a game) does
        | not write it. Our image left it at $00: START and the coin sound were read from
        | the next call, one frame before the reference.
        tst.b   %d1
        beq.s   7f
        move.b  #0x01, 0x10FEE1         | BIOS_FRAME_SKIP
        move.w  #0, 0x10FDDA            | BIOS_COMPULSION_TIMER and its frame timer
        move.b  #3, 0x10FD81
7:      move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        moveq   #1, %d3                 | one credit per player started
        btst    #0, %d1
        beq.s   3f
        move.b  0xD00034, %d2
        move.w  #0, %ccr                | X at 0 before `sbcd`
        sbcd    %d3, %d2
        bcc.s   6f
        moveq   #0, %d2                 | borrow: not below zero
6:      move.b  %d2, 0xD00034
3:      btst    #1, %d1
        beq.s   4f
        move.b  0xD00034, %d2           | P2 too: the shared credit
        move.w  #0, %ccr
        sbcd    %d3, %d2
        bcc.s   6f
        moveq   #0, %d2
6:      move.b  %d2, 0xD00034
4:      move.b  %d0, 0x3A000D           | REG_SRAMLOCK
9:      bsr.s   _io_verrous_hauts
        bra     _io_temps               | the play time, at the end of the call

| START IN AES MODE, WITHOUT CREDIT — reached by the refusal of `_io_start`, the only path where
| the mode is tested: a START accepted in MVS keeps its cycles identical (DECISIONS §11). %d1: the
| pressed players.
| MEASURED under MAME on 2026-10-23 (`aes -bios asia`; `measured/2026-10-23-mode-aes.tsv`), aof,
| kof98, mslug, samsho2, puzzledp, kof94: in demo as in a game, PLAYER_START on the frame of
| the press, $10FDB4 ← $01 for START P1, $02 for P2 alone (not $03: P2 does not start
| both); neither $10FEE1 (FRAME_SKIP) nor $10FD81 written, no credit. Decision D2.
| DELIBERATE DEPARTURE: $10FD81 ← 3 when the game keeps a player, as in MVS, where the AES
| reference leaves it at $02 — the end of game then returns through code 3, the demo on the same
| slot (code 2 would make it turn to the next slot on a board with several slots); the demo after
| game over falls at R+3 on both (measured). The second $10FDB4, $00 on refusal, is rewritten.
| ASSUMED: mode 0 (request 0 or 1 in progress) refused, as the MVS refuses it without credit at
| boot; not measured on the reference.
_io_start_refus:
        tst.b   0x10FD82
        bne.s   _io_libre               | MVS: refused, except FREE PLAY
        tst.b   0x10FDAF
        beq.s   9b                      | mode 0: refused
        move.b  %d1, 0x10FDB4           | the pressed ones, accepted
        moveq   #0, %d0                 | zero-extended: see `_systeme_io`
        jsr     0x128                   | PLAYER_START
        tst.b   0x10FDB4
        beq.s   9b
        move.w  #0, 0x10FDDA            | BIOS_COMPULSION_TIMER, as in MVS
        move.b  #3, 0x10FD81
        bra.s   9b

| THE DISPLAY LATCHES RAISED ($380031 ← $FF), at the end of the START test — after the
| deduction, before DEMO_END, the selection and the play time. MEASURED under MAME on 2026-10-23
| (-bios euro, puzzledp, nam1975, puzzledp + aof; `measured/2026-10-23-led-et-remises.tsv`,
| section 1), the reference: this $FF is only written by a SYSTEM_IO that reads FRAME_SKIP at $00
| — after the countdown of the forced start, after PLAYER_START and the deduction, just before
| DEMO_END or SELECT. Counted over the reference's 17 runs: 2,132 calls out of 2,133 (the
| last: puzzledp's PLAYER_START, which only returns control two frames later, $FF
| on its return); none of the 130 calls during the skip nor of the 63 under INT1 — 9 $FF follow an
| INT1 further in the frame, written by the held frames of code 2 and of SELECT.
_io_verrous_hauts:
        move.b  #0xFF, 0x380031         | REG_LEDLATCHES
        rts

| FREE PLAY, IN MVS MODE — reached by the refusal of `_io_start`, like the AES mode: a START
| accepted with a credit keeps its cycles identical. %d1: the pressed players.
| MEASURED under MAME on 2026-10-25 (`measured/2026-10-25-free-play.tsv`, section 1), the SNK BIOS
| (-bios euro, aof) with the board's "Free Play" switch: START P1 in demo, without a coin,
| starts the game on the press (PLAYER_START, $10FDB4 = $01, mode 2); START P2 in demo starts
| both ($03); in a game, START P2 joins P2 ($02); no credit is ever taken, and
| aof's demo says "PUSH 1P OR 2P START BUTTON" instead of "INSERT COIN" (CREDIT_CHECK, below,
| no longer refuses anything: bit 7 of BORNE). Here the same path, under the FREE PLAY setting (bit
| 0 of BORNE, at zero in AES mode). Mode 0 is refused, as the SNK BIOS does during its
| logo (START on frame 600, measured). DEPARTURE, DECISIONS §15: a credit present is taken by the
| START accepted above, where the SNK BIOS takes none.
| DEMO SOUND: a start from the demo resets $D00046 to 0 (`reglages.s`, `_borne_remise`).
| BOARD SWITCH 7, "Freeplay" (REG_DIPSW $300001 bit 6, active low: "Memory
| mapped registers"; "Free Play", mask $40, SW:7, in the MAME source), since
| 2026-10-25: one OR the other suffices. MEASURED under MAME 0.286 (`measured/2026-10-25-dip-free-play.tsv`),
| the SNK BIOS and UniBIOS 4.0, ng_mv2f and MV-6F, aof, samsho4, ssideki, mslug: at ON, START P1 without
| a coin launches the game, START P2 both players, no credit taken; and the switch is read
| HOT, in both directions, from the frame that follows the toggle. Hence the read here, on each
| refusal, and not at boot: this path is only taken by a refused START, and a START accepted
| with a credit keeps its cycles.
_io_libre:
        btst    #0, BORNE
        bne.s   8f                      | FREE PLAY from CABINET SETTINGS
        btst    #6, DIPSW
        bne     9b                      | neither one nor the switch: refused
8:      tst.b   0x10FDAF
        beq     9b                      | mode 0: refused
        cmpi.b  #1, 0x10FDAF
        bne.s   1f                      | in a game: the pressed ones
        btst    #1, %d1
        beq.s   1f
        moveq   #3, %d1                 | title or demo, START P2: both players
1:      move.b  %d1, 0x10FDB4
        moveq   #0, %d0                 | zero-extended: see `_systeme_io`
        jsr     0x128                   | PLAYER_START
        tst.b   0x10FDB4
        beq     9b
        move.b  #0x01, 0x10FEE1         | BIOS_FRAME_SKIP, like an accepted START
        move.w  #0, 0x10FDDA
        move.b  #3, 0x10FD81
        tst.b   0xD00046
        beq     9b
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        clr.b   0xD00046                | the demo is over: the sound
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
        bra     9b

| NO CONTINUE ("1CC") — a START is not taken for a player whose game offers the continue.
| Read in "BIOS RAM locations": BIOS_PLAYER_MOD1 ($10FDB6), "0:Never played, 1:Playing,
| 2:Continue option being displayed, 3:Game over", set by the game; P2 at $10FDB7 (measured: the
| word $0303 at aof's game over with two players). MEASURED under MAME on 2026-10-25 (same log,
| section 2): aof, puzzledp and kof94 set $02 during their continue countdown (aof from 6116 to
| 6716, puzzledp from 7424 to 8003), and a START at that moment goes through PLAYER_START, takes a
| credit and resets the player to $01 — the continue is therefore taken by the BIOS. Reached from
| `_io_start`, bit 1 of BORNE (at zero in AES mode: no paid continue). THE MOST RESTRICTED: only the
| player at $02 is removed from the pressed ones; a player at $03 (game over) who joins a game in
| progress, or the start of a new game on the title, do not change. With no pressed one left,
| nothing is written, as without START. With FREE PLAY, the continue is refused too.
_io_sans_continue:
        cmpi.b  #2, 0x10FDB6
        bne.s   1f
        bclr    #0, %d1                 | P1: its continue is not taken
1:      cmpi.b  #2, 0x10FDB7
        bne.s   2f
        bclr    #1, %d1                 | P2 likewise
2:      tst.b   %d1
        bne     _io_presses
        bra     9b

| ----------------------------------------------------------------------------------
| CREDIT_CHECK — reached by `jmp` from $C00450; the game enters it by `jsr` (measured:
| return to $0013FC on `puzzledp`) and leaves it by our `rts`.
|
| Read in "CREDIT_CHECK": the game sets the wanted credit in BIOS_CREDIT_DEC1 ($10FDB0)
| and BIOS_CREDIT_DEC2 ($10FDB1); if a player does not have enough credits, its variable is
| set to 0. Credits: $D00034 and $D00035, BCD ("Backup RAM").
|
| Measured (`appel_C00450.md`): $10FDB1 ← $00 and the WORD $10FDB2 ← $0000 on each call,
| $10FDB0 ← $00 on 10/23 — the calls where P1 does not have its credit. Measured on our image:
| `puzzledp` writes $0101 into $10FDB0 before each call, so DEC2 is 1 and P2, without
| credit, is zeroed each time.
|
| ASSUMED: P3 and P4 never have credit (no 4-player board handled), so their
| two bytes $10FDB2-$10FDB3 are zeroed unconditionally, in one word — the width
| is that of the contract. Register %d0 is returned intact: the page says nothing about
| registers, and it is the choice that cannot break the caller.
|
| P2'S REQUEST IS COMPARED TO THE SHARED CREDIT, $D00034, not to $D00035. Measured under
| MAME (diagnostic of 2026-10-22, `cyberlip-` and `ncommand-credit-check-ref` logs):
| in a game (mode 2), DEC2 = $01 is left with $D00034 at $01, $02 or $03 and $D00035 at
| $00; zeroed with $D00034 at $00. On ours, compared to $D00035 (always $00 with the
| default coin mechanism), it dropped on each call: P2 could never join.
| ON THE TITLE (mode 1), measured (`trally-` and `dragonsh-credit-check-ref` logs): DEC2 =
| $01 zeroed with one credit (65/66 and 96/96 calls), left with two (100/100).
| ASSUMED, the rule that covers these counts: on the title, P2 wants one credit more than its
| request — that of P1, who starts before it. Only the request $01 was measured.
|
| THE ORDER: the word $10FDB2 first, then $10FDB0, then $10FDB1 — MEASURED under the reference
| (`measured/2026-10-22-repetition-et-start.tsv`, aof, mslug, alpham2, garou: all calls).
| The decisions do not depend on one another; only the order of the writes changes.
|
| IN AES MODE, NO REQUEST IS REFUSED. MEASURED under MAME on 2026-10-23 (`aes -bios asia`,
| aof in STORY MODE then puzzledp in demo; `measured/2026-10-23-aes-credit.tsv`): the
| reference never writes $10FDB0-$10FDB3 after the first frame, CREDIT_CHECK calls
| included (8 on aof, 8,496 on puzzledp); the game reads back the request it set ($01 for P2),
| and aof then displays "PUSH START" for P2 instead of "INSERT COIN". On ours, zero credit
| in AES mode (the coin is ignored, D2): P2 dropped to $00 on each call. No game reads
| $D00034 itself (same log). The mode test is only on the two refusal paths: an
| MVS call whose request passes keeps its instructions identical (DECISIONS §11). The word
| $10FDB2 stays written in AES, where the reference does not write it: ASSUMED without effect, aof and
| puzzledp themselves set $0000 there before each call (measured, same log).
| FREE PLAY LIKEWISE, since 2026-10-25: the test reads bit 7 of BORNE, set at boot for AES
| mode and for FREE PLAY (`reglages.s`, `_borne_ram`) — same width, same cycles as the test of
| BIOS_MVS_FLAG it replaces. Measured: under the SNK BIOS in free play, aof's demo says "PUSH
| 1P OR 2P START BUTTON" (`measured/2026-10-25-free-play.tsv`, section 1); under ours too.
| BOARD SWITCH 7 LIKEWISE, read again on each refusal (see `_io_libre`): under both reference
| BIOSes, the demo goes from "INSERT COIN" to "PUSH 1P OR 2P START BUTTON" within the ten
| frames that follow the toggle, and back (`measured/2026-10-25-dip-free-play.tsv`, section 2).
| One more `btst` and `beq`, on the two refusal paths only: a request that passes
| keeps its instructions.
| ----------------------------------------------------------------------------------
_credit_check:
        move.l  %d0, -(%sp)
        move.w  #0, 0x10FDB2            | P3 and P4
        move.b  0xD00034, %d0           | P1 credit
        cmp.b   0x10FDB0, %d0
        bcc.s   1f                      | credit ≥ request: we leave it
        tst.b   BORNE                   | bit 7: AES mode or FREE PLAY, the request stays (above)
        bmi.s   1f
        btst    #6, DIPSW               | switch 7 at ON (bit at 0): likewise
        beq.s   1f
        move.b  #0, 0x10FDB0
1:      move.b  0xD00034, %d0           | shared credit, for P2 too (see above)
        cmpi.b  #1, 0x10FDAF            | BIOS_USER_MODE: title / demo?
        bne.s   3f                      | outside the title: credit ≥ request suffices
        cmp.b   0x10FDB1, %d0
        bhi.s   2f                      | title: credit > request, we leave it
        bra.s   4f
3:      cmp.b   0x10FDB1, %d0
        bcc.s   2f
4:      tst.b   BORNE                   | AES or FREE PLAY: P2's request stays, "PUSH START" (measured)
        bmi.s   2f
        btst    #6, DIPSW               | switch 7 likewise
        beq.s   2f
        move.b  #0, 0x10FDB1
2:      move.l  (%sp)+, %d0
        rts

| ----------------------------------------------------------------------------------
| THE PART SHARED BY SYSTEM_IO AND SYSTEM_INT1.
|
| The hand-overs to the game are in `_systeme_io`, except that of a coin outside
| a game, which leaves from here and does not return (end of the routine). Input: %d7.b non-zero
| under SYSTEM_IO, zero under INT1. Output: %d6 = mask
| of the coins accepted on this frame (bit 0: coin 1, bit 1: coin 2; bit 7: one
| of them made a credit, set by `_io_crediter`). Registers
| destroyed: %d0-%d3, %d6, %a0.
|
| Everything that follows up to the displays is the core of the two contracts: `appel_C0044A.md`
| and `appel_C00438.md` write the same sites, with the same width.
| ----------------------------------------------------------------------------------
_io_commun:
        | SWITCH 8, "FREEZE" (REG_DIPSW bit 7, active low; neogeo.cpp, SW:8). MEASURED under
        | MAME on 2026-10-27 (`measured/2026-10-27-dip-2-8.tsv`, sections 2 and 3), the SNK BIOS and
        | UniBIOS 4.0: at ON, the game is suspended from the next frame, in demo as in a game —
        | the picture frozen, the inputs no longer reach it —, the Z80 continues, the watchdog is
        | fed; set back to OFF, the game resumes where it was. `tst.b`: bit 7 is the sign.
        tst.b   DIPSW
        bpl     _io_gel
_io_lire:
        | THE MAHJONG PANEL, SWITCH 3 AT OFF: the reference reads it as a joystick, rows
        | A-G and H-N merged (same log, section 8). REG_POUTPUT ($380001, "Joypad
        | ports outputs") chooses the panel's rows, three bits per player (neogeo.cpp,
        | io_control_w; mahjong.cpp, read_ctrl): $1B, rows 0 and 1 of both players. A
        | joystick does not read this output: nothing changes for it.
        move.b  #0x1B, 0x380001
        | SWITCH 3 AT ON (BIOS_P1STATUS at 3, set at the hand-over: `_commutateurs`, `c0.s`):
        | the panel scan, `_io_mahjong`.
        cmpi.b  #3, 0x10FD94
        beq     _io_mahjong
        | THE TWO CONTROLLERS. REG_P1CNT ($300000) and REG_P2CNT ($340000), active
        | low ("Memory mapped registers"); "BIOS RAM locations" wants them in positive
        | logic, hence the `not`.
        |
        | THE AUTOFIRE (`autofire.s`, DECISIONS §22), between the register read and the store in RAM:
        | the game sees it if it reads BIOS_P1CURRENT and the bytes that follow, not if it reads the
        | register itself (measured, `measured/2026-10-27-autofire.tsv`). A button of the setting, held,
        | is seen released at the phases of AF_REL; the phase advances by one cell of AF_SUIV on each
        | call, and restarts from 0 when no button of the setting is held. P1 and P2 follow the same
        | setting, each its own phase. CONSTANT COST, turbo active or not, button held or not: neither
        | branch nor Scc, ~112 cycles per controller — measured, a few games diverge by a few cycles.
        | The tables at zero (boot clear) change nothing in the inputs. The mahjong
        | panel (`_io_mahjong`) does not go through it: no autofire with switch 3 at ON, P2 included.
        lea     AF_REL, %a0
        move.b  0x300000, %d0
        not.b   %d0
        move.b  %d0, %d2
        and.b   AF_MASQUE, %d2          | a button of the setting held?
        neg.b   %d2                     | X at 1 if so
        subx.b  %d2, %d2                | $FF held, $00 otherwise
        moveq   #0, %d1
        move.b  AF_PH1, %d1
        move.b  0(%a0,%d1.w), %d3       | the buttons seen released at this phase
        and.b   %d0, %d3
        eor.b   %d3, %d0
        and.b   AF_SUIV-AF_REL(%a0,%d1.w), %d2 | the next phase, 0 if nothing is held
        move.b  %d2, AF_PH1
        lea     0x10FD94, %a0           | P1 block: BIOS_P1STATUS, then $10FD95-$10FD99
        bsr     _io_manette
        lea     AF_REL, %a0             | P2, likewise
        move.b  0x340000, %d0
        not.b   %d0
        move.b  %d0, %d2
        and.b   AF_MASQUE, %d2
        neg.b   %d2
        subx.b  %d2, %d2
        moveq   #0, %d1
        move.b  AF_PH2, %d1
        move.b  0(%a0,%d1.w), %d3
        and.b   %d0, %d3
        eor.b   %d3, %d0
        and.b   AF_SUIV-AF_REL(%a0,%d1.w), %d2
        move.b  %d2, AF_PH2
        lea     0x10FD9A, %a0           | P2 block, same layout: $10FD9B-$10FD9F
        bsr     _io_manette

        | P3 AND P4. Measured, on each call and always at zero: the byte $10FDA1 then the words
        | $10FDA2 and $10FDA4, the byte $10FDA7 then the words $10FDA8 and $10FDAA — the same
        | five bytes PREVIOUS..TIMER as P1, at the same offset in their blocks of six
        | ("BIOS RAM locations": P2, P3, P4 "same layout as P1"). ASSUMED: no
        | 4-player board is handled here, so these players have no inputs, and zero is
        | their state. The width of the writes is that of the contract, it is part of it.
        clr.b   0x10FDA1
        clr.w   0x10FDA2
        clr.w   0x10FDA4
        clr.b   0x10FDA7
        clr.w   0x10FDA8
        clr.w   0x10FDAA
_io_start_select:

        | START AND SELECT. REG_STATUS_B ($380000), read in "Memory mapped registers": bit
        | 0 Start P1, 1 Select P1, 2 Start P2, 3 Select P2. ASSUMED active low,
        | like the page's other inputs — it says so only for REG_STATUS_A. The
        | variables follow the layout of "BIOS RAM locations" — bits 0 to 3 for P1 and
        | P2, in the same order —, hence a simple $0F mask.
        move.b  0x380000, %d0
        not.b   %d0
        andi.b  #0x0F, %d0              | %d0: current states, raw
        move.b  0x10FEDC, %d1           | the states of the previous frame
        move.b  %d0, 0x10FEDC           | BIOS_STATCURNT_RAW
        not.b   %d1
        and.b   %d0, %d1                | %d1: new presses
        move.b  %d1, 0x10FEDD           | BIOS_STATCHANGE_RAW
        | $10FEDE and $10FEDF: measured, $00 on each call, as a byte, in both contracts.
        | No page names them; ASSUMED: we write the measured value, with no meaning assigned.
        move.b  #0, 0x10FEDE
        move.b  #0, 0x10FEDF
        | "BIOS RAM locations": "On MVS the select bits are always read as 0" for
        | BIOS_STATCURNT and BIOS_STATCHANGE, and the note is missing from the RAW versions. We
        | therefore keep only the Start bits ($55) when BIOS_MVS_FLAG ($10FD82) is non-zero. It is
        | the MODE: in AES mode, the game receives its SELECTs (its pause), on an MVS board too.
        moveq   #-1, %d2
        tst.b   0x10FD82
        beq.s   2f
        moveq   #0x55, %d2
2:      and.b   %d2, %d0
        and.b   %d2, %d1
        move.b  %d0, 0x10FDAC           | BIOS_STATCURNT
        move.b  %d1, 0x10FDAD           | BIOS_STATCHANGE

        | BIOS_FRAME_COUNTER, long at $10FE88: "Frame counter, updated by SYSTEM_IO" ("BIOS
        | RAM locations"). Measured: the word $10FE88 at $0000, the word $10FE8A increasing by one
        | per call — an incremented long, which writes its two words.
        addq.l  #1, 0x10FE88

        | $10FEE8-$10FEF3: six words, written on each call in both contracts — $0000
        | at the first four sites of each half, 9 increasing values on $10FEEC and
        | $10FEF2. No page names them. MEASURED under the reference
        | (`measured/2026-10-22-repetition-et-start.tsv`, alpham2 and aof, 386 frames each):
        | the twelve bytes are, at each end of frame, those of the P1 and P2 blocks
        | ($10FD94-$10FD9F), written as six words after them — hence the timer values on
        | $10FEEC and $10FEF2. The meaning of this copy remains unknown: we make it, nothing more.
        move.w  0x10FD94, 0x10FEE8
        move.w  0x10FD96, 0x10FEEA
        move.w  0x10FD98, 0x10FEEC
        move.w  0x10FD9A, 0x10FEEE
        move.w  0x10FD9C, 0x10FEF0
        move.w  0x10FD9E, 0x10FEF2

        | THE CREDIT DISPLAYS, FIRST STEP: the latches raised, before the backup
        | RAM; the data and the falling edge come after the credit (below, before the lock).
        move.b  #0xFF, 0x380031         | REG_LEDLATCHES: latches high

        | THE BACKUP RAM. REG_SRAMUNLOCK ($3A001D) then REG_SRAMLOCK ($3A000D), read in
        | "Memory mapped registers": byte write, data ignored. Measured: both
        | are in the core of the two contracts. All the writes in $D0xxxx are between them.
        move.b  %d0, 0x3A001D           | unlock

        | THE COIN EDGE. "Backup RAM": $D00020/$D00021 carry the old and the
        | new value of REG_STATUS_A, $D00022 a temporary value of the edge
        | search. Measured: the three bytes written on each call. REG_STATUS_A ($320001),
        | "Memory mapped registers": coins 1 to 4 at bits 0, 1, 3 and 4, active
        | low. ASSUMED: the value is stored COMPLEMENTED, in positive logic. The page says
        | "value of REG_STATUS_A" and no more; measured, the two sites receive $00, $C0 and
        | $C1 under INT1, $40, $41, $C0 and $C1 under SYSTEM_IO — bits 6 and 7 are those of the
        | calendar, which we copy without reading them.
        | ASSUMED again: $D00022 keeps the mask of the coins gone from 0 to 1 in this
        | positive logic, that is, inserted since the frame before.
        move.b  0xD00021, %d1           | the old value, already complemented
        move.b  0x320001, %d0           | the new one, raw
        not.b   %d0
        move.b  %d1, 0xD00020
        move.b  %d0, 0xD00021
        not.b   %d1
        and.b   %d1, %d0                | inserted now, absent before
        andi.b  #0x1B, %d0              | the four coins
        move.b  %d0, 0xD00022

        | CREDITING. Coin 1 → player 1, coin 2 → player 2; coins 3 and 4 are set aside.
        | The coin's sound BEFORE the counter pulse (`_io_son_piece`, below).
        | IN AES MODE, NO COIN ARRIVES HERE: the coin mechanisms are locked at boot
        | (`c0.s`, REG_SETCL1/2), decision D2. Nothing is tested here, so that the MVS mode keeps
        | its cycles identical (DECISIONS §11).
        moveq   #0, %d6
        btst    #0, %d0
        beq.s   2f
        moveq   #0, %d1                 | player 1
        bsr     _io_crediter
        bset    #0, %d6
2:      btst    #1, %d0
        beq.s   3f
        moveq   #1, %d1                 | player 2
        bsr     _io_crediter
        bset    #1, %d6
3:      bsr     _io_son_piece

        | $D0002C AND $D00039, AFTER THE SOUND. See `_io_crediter`: $D0002C returns to $00, then
        | $D00039 ← $00, on each accepted coin 1, whether COIN_SOUND leaves on this call or not.
        btst    #0, %d6
        beq.s   1f
        move.b  #0x00, 0xD0002C
        move.b  #0x00, 0xD00039
1:
        | THE COIN COUNTER 1 PULSE — after the credit and the sound: a coin of this
        | frame (re)starts it at $1F, otherwise it counts down. "Memory mapped registers":
        | REG_SETCC1 ($3800E1) "Coin counter 1 sinks current", REG_RESETCC1 ($380061)
        | "floats", data "Any".
        | Measured: $3800E1 ← $10 on 16/32 calls of $C0044A and 1/16 of $C00438; $D00038,
        | byte, on 17/32 and 2/16, from $16 to $1F, and $1E/$1F in INT1 on the coin's
        | frame. What these counts allow to be read, and that nothing documents — "Backup RAM"
        | marks $D00036-$D00039 "undocumented": $D00038 counts down from $1F starting from
        | the coin, and each frame where it is non-zero, the next one included, holds the
        | counter sinking current. ASSUMED therefore: this role of pulse timer, the
        | starting value $1F taken from the measurement, the release by REG_RESETCC1 at zero
        | — the contract never sees this zero, the countdown not reaching it in its windows.
        | The data $10 on $3800E1 is the measured value; the page says it is ignored.
        | THE ORDER, MEASURED under the reference on 2026-10-23 (`measured/2026-10-23-comptabilite.tsv`,
        | section 4): on the coin, $D00038 ← $1F alone; on the following frames, $D00038 then
        | REG_SETCC1, both after the coin edge.
        | ASSUMED: no pulse of counter 2. No measurement shows one, and giving it
        | a timer would require an address that nothing designates.
        btst    #0, %d6
        beq.s   4f
        move.b  #0x1F, 0xD00038         | the counter 1 pulse starts
        bra.s   5f
4:      tst.b   0xD00038
        beq.s   5f
        subq.b  #1, 0xD00038
        move.b  #0x10, 0x3800E1         | REG_SETCC1
        tst.b   0xD00038
        bne.s   5f
        move.b  #0x10, 0x380061         | REG_RESETCC1: pulse over
5:
        | THE PLAY TIME AND THE COPY $10FDBA-$10FDBD: further on, `_io_temps`.
        | THE HHMMSSFF TIMER of $D0005A-$D0005D, read in "Backup RAM": FF counts down from
        | $3C to $00, SS and MM count from $00 to $3B, HH in steps of 4 up to $60. Measured:
        | $D0005D, byte, written on each call in both contracts — a countdown. The three
        | other bytes only move when a second passes, which does not fall within the
        | measured windows. ASSUMED: the exact cadence of the reload (FF is $00 for one
        | frame, then $3C) and the return of HH to zero after $60.
        tst.b   0xD0005D
        beq.s   3f
        subq.b  #1, 0xD0005D
        bra.s   8f
3:      move.b  #0x3C, 0xD0005D
        lea     0xD0005C, %a0           | SS, then MM at $D0005B
        moveq   #1, %d1                 | two rounds of `dbra`: SS, MM
4:      addq.b  #1, (%a0)
        cmpi.b  #0x3C, (%a0)
        bcs.s   8f                      | no overflow: the cascade stops
        move.b  #0, (%a0)
        subq.l  #1, %a0
        dbra    %d1, 4b
        addq.b  #4, 0xD0005A            | MM overflowed: HH, in steps of 4
        cmpi.b  #0x60, 0xD0005A
        bls.s   8f
        move.b  #0, 0xD0005A
8:
        | THE CREDIT DISPLAYS, SECOND STEP. "Memory mapped registers": REG_LEDDATA
        | ($380041) carries the data, REG_LEDLATCHES ($380031) latches it — "Latch LED1
        | data", "Latch LED2 data", "LED data is latched on 1 to 0 transition". "MV-LED":
        | digits in BCD. "Backup RAM": internal credits of P1 and P2 in BCD at $D00034 and
        | $D00035. ASSUMED: the data is the COMPLEMENTED credit — nothing says so, the
        | measured values allow it to be read ($FF for zero, $FE for one).
        | MEASURED under MAME on 2026-10-23 (-bios euro, 17 runs on puzzledp, nam1975, aof, mslug,
        | garou, b2b; `measured/2026-10-23-led-et-remises.tsv`, section 1), the reference, under
        | SYSTEM_IO as under INT1: ONE display per call, LED1 ($380031 ← $EF) when the low byte
        | of BIOS_FRAME_COUNTER ($10FE8B, already advanced) is even, LED2 ($DF) when it is
        | odd (2,341 calls out of 2,341); the data after the
        | credit and the $D0005D timer, before REG_SRAMLOCK (a coin of this call is therefore
        | displayed), the falling edge after it, then REG_POUTPUT ← $12, $1B, $00, then — under
        | SYSTEM_IO at zero FRAME_SKIP only — $380031 ← $FF, at the end of the START test
        | (`_io_verrous_hauts`); under INT1 and during the skip, the latch stays low until the $FF
        | at the start of the next call. Our image latched both, before the coin
        | edge, and wrote only $00 into REG_POUTPUT.
        | REG_POUTPUT ($380001), "Joypad ports outputs" ("Memory mapped registers"): the
        | measured values, in the measured order, and nothing else. The reference reads the
        | controllers and REG_STATUS_B again under $12 and under $1B (same logs, reads without
        | value): not here. ASSUMED: on an ordinary controller, these outputs do not change what
        | is read — we read once, above, as before.
        lea     0xD00034, %a0           | LED1: P1 credit
        moveq   #-17, %d1               | $EF: bit 4 at 0
        btst    #0, 0x10FE8B
        beq.s   1f
        addq.l  #1, %a0                 | LED2: P2 credit
        moveq   #-33, %d1               | $DF: bit 5 at 0
1:      move.b  (%a0), %d0
        not.b   %d0
        move.b  %d0, 0x380041           | REG_LEDDATA
        move.b  %d0, 0x3A000D           | relock the backup RAM
        move.b  %d1, 0x380031           | REG_LEDLATCHES: the falling edge latches
        move.b  #0x12, 0x380001         | REG_POUTPUT, measured
        move.b  #0x1B, 0x380001
        move.b  #0x00, 0x380001

        | THE COIN OUTSIDE A GAME BRINGS BACK THE TITLE. Measured: a coin credited outside a
        | game triggers a new USER hand-over, ~3 frames after it (coin 297 → hand-over
        | 300, coin 299 → 302, 289 without coin); trace 9 of `protocole.md`, at 242.92 —
        | control to the BIOS, under the coin —, $10FEE1 ← $FF and $10FD80 ← $01, then request 3
        | at 244.89; trace 4, the same sequence from 500.92 to 502.89. Read: "USER subroutine",
        | request 3 "is called when a coin is inserted on MVS".
        | "OUTSIDE A GAME" = BIOS_USER_MODE ($10FDAF) < 2. Read in "BIOS RAM locations":
        | 0 init, 1 title / demo, 2 game, and "Game selection can only be done on MVS
        | systems when this byte is < 2" — the threshold where the BIOS can take control back.
        | Measured: the coin of 242.92 falls with $10FDAF at $00 (written by the cartridge at
        | 238.77), so mode 0 is part of it. ASSUMED: a value beyond 2, which the page does not
        | describe, counts as a game — we do not cut what we do not know.
        | ONLY A COIN THAT MAKES A CREDIT (bit 7 of %d6, `_io_crediter`). MEASURED under MAME
        | on 2026-10-22 (`bench/multislot.lua`, -bios euro, puzzledp, two coins per credit
        | set in the NVRAM, $D0003A ← $02; `measured/2026-10-22-ecarts-remise-credit.tsv`):
        | the coin that does not yet make a credit, during the demo, is counted ($D00024 ←
        | $01) and sounded (COIN_SOUND on its frame), without $10FD81 or hand-over — the demo
        | continues; the second makes the credit, then $10FD81 ← $06 and request 3. Our image
        | led the first to the title, without credit.
        | THE SOUND SURVIVES THE HAND-OVER. Measured under MAME on `neomrdo`: coin ~243, COIN_SOUND
        | ~255, on the first SYSTEM_IO at zero FRAME_SKIP after the hand-over. The mark $10FEE2
        | (`_systeme_io`) is therefore set before leaving (`_io_son_piece`): the hand-over does not
        | clear it, and `_systeme_io` would not have set it under INT1 nor at zero FRAME_SKIP.
        | ASSUMED: the hand-over leaves at once, where the reference still gives ~2 frames
        | to the game before it (trace 9, $000200 at 243.88).
        | NO HAND-OVER IF THE TITLE IS ALREADY REQUESTED. Measured under MAME (diagnostic of
        | 2026-10-22, `trally` log): a coin on the title (mode 1, BIOS_USER_REQUEST
        | $10FDAE at 3) is credited by the reference without a new hand-over; on ours, the
        | hand-over restarted the title on each coin and the game did not start. A coin
        | during the demo (request 2) keeps the hand-over, measured (`garou`, `sbp`,
        | `aodk` logs: $10FD80 ← $02, $10FD81 ← $06, then request 3). The sound mark is set
        | in both cases: under SYSTEM_IO, COIN_SOUND leaves on this frame and clears it
        | (`_io_son_piece`); under INT1, on the first SYSTEM_IO at zero FRAME_SKIP — measured on
        | 2026-10-22 (mslug, below).
        | The mark itself is set on the coin, before the pulse (`_io_son_piece`).
        tst.b   %d6
        beq.s   1f
        cmpi.b  #2, 0x10FDAF
        bcc.s   1f                      | mode ≥ 2: the coin only credits
        btst    #7, %d6
        beq.s   1f                      | no credit made: neither hand-over nor title
        cmpi.b  #3, 0x10FDAE
        beq.s   1f                      | title already requested: credit and sound only
        | THE DEMO UNDER SYSTEM_IO (%d7 non-zero, set by `_systeme_io`; `int1.s` sets it to
        | zero): nothing here, `_io_fin_demo` does COIN_SOUND, DEMO_END then the title, measured.
        | UNDER INT1, NOTHING EITHER: the credit and the sound mark only. MEASURED under MAME
        | on 2026-10-22 (-bios euro, mslug; `measured/2026-10-22-frame-skip-et-mode0.tsv`):
        | a coin taken under INT1 during the demo (two frames after its hand-over) is only
        | credited, and the demo continues until the first SYSTEM_IO that reads FRAME_SKIP at $00 —
        | COIN_SOUND, $10FD81 ← $06, DEMO_END, then the title (`_io_fin_demo`); taken under INT1
        | during request 0, it is only credited, the game finishes its request 0, and it is
        | after its SYSTEM_RETURN that the reference gives the title (`_sysret_demo`, `c0.s`).
        | In mode 0 under SYSTEM_IO, the earlier path, which no log covers.
        tst.b   %d7
        beq.s   1f
        cmpi.b  #2, 0x10FDAE
        bne.s   2f
        cmpi.b  #1, 0x10FDAF
        beq.s   1f
2:      jmp     _retour_piece           | `c0.s`: stack and SR restored, title, does not return
1:      rts

| ----------------------------------------------------------------------------------
| THE COIN'S SOUND, in `_io_commun`, after the credit and before the counter pulse.
| %d6: the coins of this call; %d7: non-zero under SYSTEM_IO. Destroys %d1.
|
| MEASURED under MAME on 2026-10-23 (-bios euro, puzzledp, aof, mslug, nam1975, garou, b2b;
| `measured/2026-10-23-comptabilite.tsv`, section 4), the reference, under SYSTEM_IO at
| zero FRAME_SKIP, in order: $D00024, $D00034, $10FDDA, $10FDDB, then $10FEE2 ← $01,
| $10FEE2 ← $00, COIN_SOUND ($000134 read), then $D00038 ← $1F — the backup RAM still
| unlocked; and for a remembered coin (taken during the FRAME_SKIP skip),
| $10FEE2 ← $00 then COIN_SOUND, before the countdown of $D00038. Our image set
| the pulse first, the mark after the lock, and called COIN_SOUND on the return from
| `_io_commun`, the mark cleared after it. Under INT1 and during the skip, the mark alone,
| before the pulse (`2026-10-22-frame-skip-et-mode0.tsv`, section 3).
| The mark is only set outside a game (mode < 2), as before. ASSUMED: COIN_SOUND at the same
| point in a game and in mode 0 (not measured); a single call for two coins of the same frame.
| ----------------------------------------------------------------------------------
_io_son_piece:
        moveq   #3, %d1
        and.b   %d6, %d1
        beq.s   1f                      | no coin: the mark alone decides
        cmpi.b  #2, 0x10FDAF            | BIOS_USER_MODE
        bcc.s   2f                      | in a game: no mark
        move.b  #0x01, 0x10FEE2         | deferred COIN_SOUND
        bra.s   2f
1:      tst.b   0x10FEE2
        beq.s   9f                      | neither coin nor mark
2:      tst.b   %d7
        beq.s   9f                      | under INT1: the mark alone
        tst.b   0x10FEE1
        bne.s   9f                      | non-zero FRAME_SKIP: deferred
        clr.b   0x10FEE2
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        moveq   #0, %d0                 | zero-extended: see `_systeme_io`
        jsr     0x134                   | COIN_SOUND
        movem.l (%sp)+, %d0-%d7/%a0-%a6
9:      rts

| ----------------------------------------------------------------------------------
| THE PLAY TIME, AND THE COPY $10FDBA-$10FDBD — at the end of SYSTEM_IO (after the FRAME_SKIP
| skip and START, `_systeme_io` and `_io_start`) and at the end of SYSTEM_INT1 (`int1.s`), backup
| RAM unlocked separately. Destroys %d1, %a0.
|
| "Backup RAM": $D0004C is a frame timer that starts from $3C and counts down on each
| frame; at zero, PLAY TIME ($D00048-$D0004B, seconds in hexadecimal) advances and the timer
| restarts. Measured: $D0004C written on 20/32 calls of $C0044A, 20 distinct values, never
| under INT1 in this contract.
| $10FDBA-$10FDBD: measured, on 23/32 calls of $C0044A, the word $10FDBA ($0000 or $0100) and
| the word $10FDBC ($0000). "BIOS RAM locations" does not name these four bytes, which follow
| BIOS_PLAYER_MOD1-4 ($10FDB6-$10FDB9); they are its copy, kept on each call with
| BIOS_USER_MODE = 2 (ASSUMED until now, measured below).
| MEASURED under MAME on 2026-10-23 (-bios euro, nam1975 and aof, coin(s) 2000, START 2100;
| `measured/2026-10-23-comptabilite.tsv`, section 1), the reference:
|   - in a game, a SECOND unlocked section after the FRAME_SKIP skip and START
|     (after the credit deduction on the START frame), under SYSTEM_IO as under INT1:
|     $D0004C, then the copy $10FDBA-$10FDBD of $10FDB6-$10FDB9;
|   - the timer only runs if the copy FROM BEFORE carries a player at 1 ("playing"): aof,
|     which sets $10FDB6 ← $01 after this section, does not count on the frame that follows the
|     START, nam1975, which sets it before, does — first countdown at START + 1 and + 2, first
|     second at START + 60 and + 61, like the reference; our image counted at START + 1
|     on both, the copy and the timer being done in `_io_commun`;
|   - the second falls BELOW zero: $D0004C from $3B to $00, then $FF, reloaded to $3B, and PLAY
|     TIME advances in the same call — 60 frames per second. Our image advanced at $00 and
|     reloaded $3C: one frame earlier. The boot sets $3B (`c0.s`, `_bram_valide`): the
|     guard of a timer at zero no longer has a purpose, $00 being a state of the countdown.
_io_temps:
        cmpi.b  #2, 0x10FDAF            | BIOS_USER_MODE: in a game
        bne.s   9f
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        lea     0x10FDBA, %a0           | the copy from before
        moveq   #3, %d1
1:      cmpi.b  #1, (%a0)+
        dbeq    %d1, 1b
        bne.s   2f                      | no player in play
        subq.b  #1, 0xD0004C
        bcc.s   2f
        move.b  #0x3B, 0xD0004C
        addq.l  #1, 0xD00048            | PLAY TIME, one second more
2:      move.w  0x10FDB6, 0x10FDBA
        move.w  0x10FDB8, 0x10FDBC
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
9:      rts

| ----------------------------------------------------------------------------------
| AN ACCEPTED COIN. %d1: the player (0 or 1). Backup RAM unlocked by the caller.
|
| Read in "Backup RAM": $D00024-$D00025 "internal coin counter", which is not the
| credit; $D0003A/$D0003B the number of coins required and of credits added for P1,
| $D0003C/$D0003D for P2; $D00034/$D00035 the credits, BCD.
| Measured (`appel_C0044A.md` and `appel_C00438.md`, on the coin): $D00024 receives $00 and $01
| on the same call, $D00034 receives $01. Both coins credit $D00034 (below).
|
| ASSUMED: $D00024 + player counts the coins of this player; on reaching the required number, it
| returns to zero and the credit advances — hence $01 then $00. A setting at zero, which
| a backup RAM that this BIOS does not initialise leaves, is worth 1. The credit caps at $99,
| the maximum of two BCD digits — nothing says what the reference BIOS does beyond.
| A credit made sets bit 7 of %d6, which the hand-over to the title reads (`_io_commun`).
| Destroys %d2, %d3, %a0.
| ----------------------------------------------------------------------------------
_io_crediter:
        | THE FORCED START IS ARMED (see `_io_compulsion`). Measured (MINASAN log): on the
        | coin, $10FDDA ← $30 and $10FDDB ← $3B, and a second coin reloads $30. Read in
        | "Backup RAM": $D00044, "Game start compulsion time", BCD, "initialized to
        | $30" — the reload is read from it. ARMED ON ANY COIN, EVEN WITHOUT A CREDIT MADE: measured
        | under MAME on 2026-10-22 (-bios euro, puzzledp, two coins per credit;
        | `measured/2026-10-22-ecarts-remise-credit.tsv`), $10FDDA ← $30 on the coin that
        | only counts, in demo as on the title (where it reloads a countdown in progress).
        | ASSUMED: whatever the player and the mode, under INT1 as under SYSTEM_IO.
        | ARMED AFTER THE COUNT AND THE CREDIT (at `9:`, below). MEASURED under the reference on
        | 2026-10-22 (`measured/2026-10-22-frame-skip-et-mode0.tsv`, mslug and puzzledp, one and
        | two coins per credit): $D00024, then $D00034 if there is a credit, then $10FDDA and
        | $10FDDB. Our image armed first; same values.
        lea     0xD00024, %a0
        addq.b  #1, (%a0, %d1.w)        | one more coin
        | $D0002C ← $01 AFTER THE COUNT, for coin 1. "Backup RAM" leaves $D00026-$D0002F
        | and $D00036-$D00039 without description. MEASURED under MAME on 2026-10-23 (-bios euro;
        | `measured/2026-10-23-led-et-remises.tsv`, section 5), the reference, on each accepted
        | coin 1 — demo, game, coin that does not yet make a credit, under SYSTEM_IO as
        | under INT1: $D00024 counted, $D0002C ← $01, then the credit, and after the sound $D0002C ←
        | $00 and $D00039 ← $00 (`_io_commun`). Written at the most restricted: these values, at these
        | places, for coin 1 alone (coin 2 is not measured); the role remains unknown.
        tst.w   %d1
        bne.s   1f
        move.b  #0x01, 0xD0002C
1:      lea     0xD0003A, %a0
        add.w   %d1, %a0                | two setting bytes per player:
        move.b  (%a0, %d1.w), %d2       | coins required, at $D0003A + 2 × player
        bne.s   1f
        moveq   #1, %d2
1:      lea     0xD00024, %a0
        cmp.b   (%a0, %d1.w), %d2
        bhi.s   9f                      | not enough coins yet
        move.b  #0, (%a0, %d1.w)
        lea     0xD0003B, %a0
        add.w   %d1, %a0
        move.b  (%a0, %d1.w), %d3       | credits added
        bne.s   2f
        moveq   #1, %d3
        | THE CREDIT IS SHARED: $D00034, for coin 2 too. Measured under MAME on
        | 2026-10-22 under the reference (`-bios euro`, "start of P2" log, cyberlip,
        | kof94, aof): a coin 2 makes it write $D00034 ← $02, never $D00035, which the
        | reference only writes at boot; START P2 then the title for two take both.
        | Our image credited $D00035, which neither START P2 nor CREDIT_CHECK read any longer.
2:      move.b  0xD00034, %d2
        move.w  #0, %ccr                | X at 0 before `abcd`
        abcd    %d3, %d2
        bcc.s   3f
        move.b  #0x99, %d2              | BCD cap
3:      move.b  %d2, 0xD00034
        bset    #7, %d6                 | a credit made
9:      move.b  0xD00044, 0x10FDDA      | the forced start is armed (see above)
        move.b  #0x3B, 0x10FDDB
        rts

| ----------------------------------------------------------------------------------
| THE FREEZE OF SWITCH 8 (see `_io_commun`). IRQs masked: the game's vblank does not run
| either. The watchdog fed on each round, the switch read again until OFF, then the input
| read resumes as if nothing had happened. ASSUMED: that the reference masks the IRQs;
| measured only that the picture no longer moves (297 to 299 frames out of 299).
_io_gel:
        move.w  %sr, -(%sp)
        ori.w   #0x0700, %sr
1:      move.b  %d0, 0x300001           | watchdog
        tst.b   DIPSW
        bpl.s   1b
        move.w  (%sp)+, %sr
        bra     _io_lire

| ----------------------------------------------------------------------------------
| THE MAHJONG PANEL, SWITCH 3 AT ON. MEASURED under MAME on 2026-10-27
| (`measured/2026-10-27-dip-2-8.tsv`, section 8; janshin machine, -bios japan, euro and
| unibios40, all three identical), each key of the panel alone then A+H+PON and A+B:
|   - BIOS_P1STATUS ($10FD94) at 3, "Mahjong controller" ("BIOS RAM locations");
|   - $10FD95, $10FD96 and $10FD97: the rows A-G, H-N and PON, CHI, KAN, RON, REACH, one
|     key per bit, from bit 0, in positive logic, as long as it is held;
|   - $10FDA1, $10FDA2 and $10FDA3: the same rows, one frame only, on the press (the edge);
|   - no repeat; $10FD98 and $10FD99 do not move.
| REG_POUTPUT receives $09, $12 and $24 (same log, section 4): one row at a time, the same
| for both players. A joystick on the same switch reads there in all three rows at
| once (section 4: CURRENT, PREVIOUS and CHANGE equal, measured on ssideki).
| P2 stays an ordinary controller. P3 and P4: at zero, except the three edges.
_io_mahjong:
        lea     0x10FD95, %a0
        move.b  #0x09, 0x380001         | row A-G
        bsr.s   .Lmj_rangee
        move.b  %d1, %d2
        move.b  #0x12, 0x380001         | row H-N
        bsr.s   .Lmj_rangee
        move.b  %d1, %d3
        move.b  #0x24, 0x380001         | row PON-REACH
        bsr.s   .Lmj_rangee
        lea     0x10FD9A, %a0           | P2, as in `_io_commun`
        move.b  0x340000, %d0
        not.b   %d0
        move.b  %d1, -(%sp)
        bsr     _io_manette
        move.b  (%sp)+, %d1
        move.b  %d2, 0x10FDA1           | the edges
        move.b  %d3, 0x10FDA2
        move.b  %d1, 0x10FDA3
        clr.w   0x10FDA4
        clr.b   0x10FDA7
        clr.w   0x10FDA8
        clr.w   0x10FDAA
        bra     _io_start_select
| One row: read under the output set, stored at (%a0)+; %d1 its edge. Clobbers %d0.
.Lmj_rangee:
        move.b  0x300000, %d0
        not.b   %d0
        move.b  (%a0), %d1
        move.b  %d0, (%a0)+
        not.b   %d1
        and.b   %d0, %d1
        rts

| ----------------------------------------------------------------------------------
| ONE CONTROLLER. %a0: the player's six-byte block (STATUS, then the five that follow);
| %d0: its current inputs in positive logic. Destroys %d1.
|
| Read in "BIOS RAM locations": PREVIOUS (+1) the inputs of the frame before, CURRENT
| (+2) these, CHANGE (+3) the new presses, REPEAT (+4) "Active edge + repeat every
| 8 frames after 16 frames", TIMER (+5) "Repeat timer (counts down from 8 to 0)".
| Measured: the five bytes written on each call, as a byte; STATUS (+0) never.
|
| THE TIMER, the page not holding together (16 frames, a timer that goes down from 8):
| MEASURED under the reference (`measured/2026-10-22-repetition-et-start.tsv`, alpham2 and aof,
| values frame by frame, presses of 1 to 41 frames, directions and buttons added or released):
|   - CURRENT different from the old one — press OR release, something else held or not:
|     TIMER ← $10, REPEAT ← CURRENT (the whole state, not the edge alone);
|   - otherwise TIMER counts down; gone below zero, it reloads $08 and REPEAT ← CURRENT, above
|     REPEAT ← 0. First repeat 17 frames after the press, then every 9; nothing
|     held, it turns from $08 to $00 endlessly.
| The order, measured likewise: TIMER (two writes on the reload, $FF then $08), REPEAT, then
| PREVIOUS, CURRENT, CHANGE.
| ----------------------------------------------------------------------------------
_io_manette:
        move.b  2(%a0), %d1            | the old CURRENT
        cmp.b   %d0, %d1
        beq.s   1f
        move.b  #0x10, 5(%a0)          | TIMER: the state has changed
        move.b  %d0, 4(%a0)            | REPEAT
        bra.s   3f
1:      subq.b  #1, 5(%a0)             | TIMER: the state holds
        bcc.s   2f
        move.b  #8, 5(%a0)             | TIMER: gone below zero
        move.b  %d0, 4(%a0)            | REPEAT
        bra.s   3f
2:      move.b  #0, 4(%a0)             | REPEAT
3:      move.b  %d1, 1(%a0)            | PREVIOUS
        move.b  %d0, 2(%a0)            | CURRENT
        not.b   %d1
        and.b   %d0, %d1
        move.b  %d1, 3(%a0)            | CHANGE
        rts
