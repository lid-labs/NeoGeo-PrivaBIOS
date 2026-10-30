| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| SYSTEM_INT1 — entry $C00438 of the call table, the BIOS's vblank routine.
|
| The six-byte slot of `c0.s` carries only a `jmp` to `_systeme_int1`: the code
| lives here, in `.text`, which `build/bios.ld` links after the end of `.vectors`, hence beyond
| $C00800 and out of reach of the call table.
|
| THREE KINDS OF CLAIMS, and each one says so:
|   "measured":  the contract `specs/traces/appel_C00438.md`, recorded over 48 calls of the
|                reference BIOS — its "Écritures communes à tous les appels" make the core;
|   "read in":   a page of the NeoGeo Development Wiki, named;
|   "ASSUMED":   neither one nor the other, and it is said.
|
| What "SYSTEM_INT1" says of the call: the BIOS's vblank routine, "Multi-purpose VBL
| call", which calls MESS_OUT and SYSTEM_IO, keeps its own frame counter and a
| flag that skips MESS_OUT and SYSTEM_IO (BIOS_INT1_SKIP, $10FEE3). Nothing more: neither the
| registers preserved, nor the variables written. The rest comes from the contract.
|
| MESS_OUT is the interpreter of `mess.s`, the same as behind the public entry $C004CE:
| the buffer is executed, not only emptied (since 2026-10-17, measured on `b2b`,
| `measured/2026-10-17-b2b-mess-out.tsv`).
|
| WHAT THIS ROUTINE DOES NOT DO, deliberately — all of it is outside the contract's core:
|   - it calls neither COIN_SOUND, nor PLAYER_START, nor DEMO_END, which "SYSTEM_IO" cites:
|     the SYSTEM_IO routine it shares with $C0044A (`io.s`) credits a coin, but
|     those hand-overs are specific to the public entry, like the hand-over to the title on a
|     coin outside a game (`io.s`, end of `_io_commun`): from here, the coin is only credited;
|   - it does not read the calendar: the contract does not write REG_RTCCTRL ($380051).
| ==================================================================================

        .text
        .global _systeme_int1

| ----------------------------------------------------------------------------------
| THE ENTRY. The game arrives here from its vblank handler, without pushing
| anything: under the stack, the IRQ's exception frame (measured on OUR image and
| `joyjoy`: SR and PC $0000129E pushed, then the entry at $C00438). The exit is therefore an
| `rte` that returns control to the interrupted code — the contract does cite $00129E in its
| "Retour vers". SR is not touched: `rte` restores it.
|
| THE REGISTERS ARE ALL RETURNED INTACT. ASSUMED: no page says what SYSTEM_INT1
| preserves. "SYSTEM_IO" writes in bold that that call "does NOT save registers", which
| suggests that the rule is not general; preserving d0-d7/a0-a6 is the choice
| that cannot break a caller. The contract does show stack writes below
| $10F300 ($10F2AA-$10F2F4, measured), but their values are those of the reference BIOS and
| need not be reproduced: these are ours.
| ----------------------------------------------------------------------------------
_systeme_int1:
        movem.l %d0-%d7/%a0-%a6, -(%sp)

        | THE WATCHDOG. $300001 is in the core (measured, varying values); "Watchdog"
        | says to write "any value" there and that the vblank routines usually take care of it.
        move.b  %d0, 0x300001

        | ACKNOWLEDGE. Measured: $3C000C receives $0004 or $0007 at each call. "68k
        | interrupts": bit 2 = v-blank, bit 1 = timer, bit 0 = reset. "Timer interrupt":
        | the timer does not restart without acknowledgement. "Memory mapped registers": REG_LSPCMODE
        | reads back as a line counter, the BIOS therefore cannot know whether the timer is armed.
        | ASSUMED, the condition: BIOS_SYSTEM_MODE ($10FD80) bit 7 at 0, "BIOS wants vblank
        | (system mode)" ("BIOS RAM locations") — the game does not hold the IRQs there, a
        | timer request has no taker: everything is acknowledged ($0007). Bit 7 at 1, the game has
        | the vblank and may use the timer: only the vblank is acknowledged ($0004).
        move.w  #4, %d0
        tst.b   0x10FD80
        bmi.s   1f
        moveq   #7, %d0
1:      move.w  %d0, 0x3C000C

        | BIOS_INT1_FRAME_COUNTER. Measured: $10FEE4, byte, 16 increasing values over 16
        | calls — one per call. "BIOS RAM locations" places it at $10FEE4 ("Frame
        | counter, only used in SYSTEM_INT1"); the "SYSTEM_INT1" page writes $10FDD4, but
        | the contract writes nothing at $10FDD4: the measurement is followed.
        addq.b  #1, 0x10FEE4

        | BIOS_INT1_SKIP ($10FEE3), read in "SYSTEM_INT1" and "BIOS RAM locations":
        | non-zero, MESS_OUT and SYSTEM_IO are skipped. The boot of `c0.s` leaves it at zero.
        tst.b   0x10FEE3
        bne.s   .Lfin

        | MESS_OUT (`mess.s`): it saves its registers itself, and does nothing if
        | BIOS_MESS_BUSY is raised.
        | In the high zone, but a `bsr.w` and not a `jsr`: 2 cycles fewer at each INT1, those
        | from before the move (the `jsr` made scores-gel fail, measured). `ld` refuses the link
        | if the distance exceeds 32 KiB.
        bsr.w   _mess_out
        | SYSTEM_IO: the common routine of `io.s`, the same as behind $C0044A — read in
        | "SYSTEM_INT1", which says that INT1 calls it. Neither COIN_SOUND nor PLAYER_START from here.
        moveq   #0, %d7                 | under INT1 (end of `_io_commun`, `io.s`)
        bsr     _io_commun

        | BIOS_FRAME_SKIP ($10FEE1) COUNTED DOWN HERE TOO. MEASURED under MAME on 2026-10-22 (-bios
        | euro, `bench/multislot.lua` and a wrapper that records the reads of $C00438 and
        | $C0044A and each write of $10FEE1; `measured/2026-10-22-frame-skip-et-mode0.tsv`):
        | after a hand-over, mslug calls SYSTEM_INT1 five frames before its first SYSTEM_IO, and
        | the reference counts FRAME_SKIP down by 1 at each of these calls; $FF is not touched there
        | (the reload to $0A comes from elsewhere), $00 neither. Our image only counted down under
        | SYSTEM_IO: mslug's title restarted 5 frames later. ASSUMED: the countdown
        | skipped with SYSTEM_IO when BIOS_INT1_SKIP is raised, and only once per frame —
        | none of the six games recorded calls INT1 and SYSTEM_IO in the same frame.
        move.b  0x10FEE1, %d0
        beq.s   1f
        cmpi.b  #0xFF, %d0
        beq.s   1f
        subq.b  #1, 0x10FEE1
1:
        | THE PLAY TIME, after the countdown (`io.s`, `_io_temps`, measured there).
        bsr     _io_temps

        | Two sites of INT1's core that the one of $C0044A does not have (measured, by comparing
        | `appel_C00438.md` and `appel_C0044A.md`): they therefore stay here, outside SYSTEM_IO.
        | $10FE8C: $00 at each call, as a byte; no page names it.
        move.b  #0, 0x10FE8C
        | $10FEC6-$10FEC9: the word $0010 then the word $FECA at each call, i.e. the long
        | $0010FECA. Hard contract, written as is. No page names the address; ASSUMED:
        | a pointer, which designates the address just above itself.
        move.l  #0x10FECA, 0x10FEC6

.Lfin:
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rte
