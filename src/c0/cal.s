| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| READ_CALENDAR — entry $C0045C of the call table: the date and time of the µPD4990A.
|
| The six-byte slot of `c0.s` carries only a `jmp` to `_read_calendar`: the game
| arrives there by `jsr` and leaves by our `rts`.
|
| THREE KINDS OF CLAIMS, and each one says so:
|   "measured":  `measured/2026-10-19-read-calendar.tsv`, under MAME, 311 complete calls
|                on blazstar and trally;
|   "read in":   the pages "READ CALENDAR", "UPD4990" and "Memory mapped registers"
|                of the NeoGeo Development Wiki, and NEC's µPD4990A data sheet ("IC-1755,
|                1st edition, March 1997"), consulted on 2026-10-19;
|   "ASSUMED":   neither one nor the other, and it is said.
|
| THE ACCESSES, measured (point 1): REG_RTCCTRL ($380051), DATA IN = bit 0, CLK = bit 1,
| STB = bit 2; REG_STATUS_A ($320001), bit 7. Command $3 then command $1, four
| bits each, least significant first, each bit written D, D|CLK, D, then STB, 0; then 52
| times: read bit 7, CLK, 0. That is 132 writes and 52 reads. Read in the data sheet, p. 7:
| [0,0,1,1] "Time Read" copies the counters into the shift register, [0,0,0,1]
| "Register Shift" shifts it out on DATA OUT, one bit per clock stroke.
|
| THE 52 BITS, measured (point 2), and read in the data sheet, p. 4, figure 1: second, minute,
| hour, day (8 BCD bits each), day of week (4), month (4, in BINARY — "except
| months in hexadecimal"), year (8, BCD), then the 4 bits of the command register, read and
| not written.
|
| THE SEVEN WRITES, measured (point 3), in this order: $10FDD8 second, $10FDD7 minute,
| $10FDD6 hour, $10FDD4 day, $10FDD5 day of week, $10FDD3 month converted to BCD,
| $10FDD2 year. Nothing else in work RAM, the stack aside.
|
| THE GAP BETWEEN TWO WRITES. Read in the data sheet, p. 2 (A.C. characteristics, at
| VDD − VSS = 2.0 V) and figures 2 (p. 11) and 5 (p. 13): tDSU, tDHLD, tHLD and tSTB are
| 1 µs at minimum; "CLK Input Frequency" DC to 500 kHz, duty cycle 50%, hence 1 µs
| per half-period. At 12 MHz, 1 µs = 12 cycles. Counted on the code below, cycles of the
| instructions executed between two writes only: 38 at least (CLK then 0, STB then 0),
| that is 3.2 µs — below the 4.5 µs measured under the reference, above the data sheet's
| minimum. An interrupt only lengthens a gap.
|
| THE "TIME READ" DELAY, read in the data sheet, p. 11: the new mode is valid at most
| 20 µs after STB in Time Read (td2), 1 µs in the others (td1). ASSUMED: the data sheet does not
| say whether CLK may toggle during td2; it is waited for after each command, and the first
| write that follows STB's 0 comes at least 332 cycles later, 27.7 µs.
|
| NO REGISTER MODIFIED, except the CCR. ASSUMED: "READ CALENDAR" says nothing of what
| the call preserves; touching nothing is the choice that breaks no caller. The SR is not
| touched, interrupts stay open: the record sees a call of the reference
| leave the BIOS ROM in its middle, an interrupt probably (its "limit of
| the instrument").
|
| OUTSIDE THE BATCH, nothing is written: the clock's initialisation at boot ($8 then $7, point 4
| of the record), SETUP_CALENDAR ($C00462) and the TP signal.
| ==================================================================================

        .text
        .global _read_calendar
        .global _read_calendar_jeu

| ----------------------------------------------------------------------------------
| READ_CALENDAR FOR THE GAMES, entry $C0045C: `_read_calendar`, then, if the SCORE
| RESET setting is OFF (`reglages.s`, `dip.s`), the frozen date over the real one — year, month, day
| and day of week ($10FDD2-$10FDD5); the time stays the clock's. The boot screen
| calls `_read_calendar` itself: its CLOCK line keeps the real date.
| WHY: some games reset their record tables to factory values when the date they
| read has changed since the last time. Measured on 2026-10-24 (`measured/2026-10-24-scores-
| date.tsv`): 32 games of the catalogue call READ_CALENDAR; after a 38-day jump of
| the clock, 16 of them rewrite a table of their save, and initials set at the top
| disappear (aof, wh2, kof2001; on screen, wh2's BEST HEROES: "SPX", then the factory
| initials). A date that no longer moves no longer triggers anything. UniBIOS 4.0 has an option of that name (`docs/ATTENTES.md`
| §1); its mechanism is not read. ASSUMED: that no game uses the date for anything
| other than a display or these resets — the setting is ON by default, the real date.
| No register modified, except the CCR, like `_read_calendar`.
| ----------------------------------------------------------------------------------
_read_calendar_jeu:
        bsr.s   _read_calendar
        movem.l %d0-%d1/%a0-%a1, -(%sp)
        jsr     _reglages_scores        | %d0.b: 1, the games' date is frozen
        tst.b   %d0
        beq.s   1f
        move.b  0xD00219, 0x10FDD2      | year, month, day, day of week frozen
        move.b  0xD0021A, 0x10FDD3
        move.b  0xD0021B, 0x10FDD4
        move.b  0xD0021C, 0x10FDD5
1:      movem.l (%sp)+, %d0-%d1/%a0-%a1
        rts

_read_calendar:
        movem.l %d0-%d4/%a0-%a1, -(%sp)
        lea     0x380051, %a0           | REG_RTCCTRL
        lea     0x320001, %a1           | REG_STATUS_A, bit 7: DATA OUT
        moveq   #3, %d1                 | Time Read
        bsr     .Lcommande
        moveq   #1, %d1                 | Register Shift
        bsr     .Lcommande

        | 52 bits, the first read into the least significant bit: %d2 = day:hour:minute:second,
        | %d3.w = year:month:day of week, then 4 command bits discarded.
        moveq   #31, %d4
1:      bsr     .Lbit
        roxr.l  #1, %d2                 | X ← the bit read, it enters at the top
        dbra    %d4, 1b
        moveq   #15, %d4
2:      bsr     .Lbit
        roxr.w  #1, %d3
        dbra    %d4, 2b
        moveq   #3, %d4
3:      bsr     .Lbit
        dbra    %d4, 3b

        move.b  %d2, 0x10FDD8           | second
        lsr.l   #8, %d2
        move.b  %d2, 0x10FDD7           | minute
        lsr.l   #8, %d2
        move.b  %d2, 0x10FDD6           | hour
        lsr.l   #8, %d2
        move.b  %d2, 0x10FDD4           | day
        moveq   #0x0F, %d0
        and.b   %d3, %d0
        move.b  %d0, 0x10FDD5           | day of week
        move.b  %d3, %d0
        lsr.b   #4, %d0                 | month in binary, 0 to 15
        cmpi.b  #10, %d0
        bcs.s   4f
        addq.b  #6, %d0                 | 10 to 15 → $10 to $15
4:      move.b  %d0, 0x10FDD3           | month in BCD
        lsr.w   #8, %d3
        move.b  %d3, 0x10FDD2           | year
        movem.l (%sp)+, %d0-%d4/%a0-%a1
        rts

| A four-bit command (%d1), least significant first, then STB and the wait for td2.
| Minimum gaps, in cycles excluding writes: 42 within a bit, 60 from one bit to the next,
| 38 from STB to 0.
.Lcommande:
        moveq   #3, %d4
1:      moveq   #1, %d0
        and.b   %d1, %d0
        bsr     .Lecrire                | D
        or.b    #2, %d0
        bsr     .Lecrire                | D|CLK
        and.b   #1, %d0
        bsr     .Lecrire                | D
        lsr.b   #1, %d1
        dbra    %d4, 1b
        moveq   #4, %d0
        bsr     .Lecrire                | STB
        moveq   #0, %d0
        bsr     .Lecrire                | 0
        moveq   #23, %d0                | 4 + 23 × 10 + 14 = 248 cycles, 20.7 µs: td2
2:      dbra    %d0, 2b
        rts

| A bit: bit 7 of REG_STATUS_A goes into X, then a clock stroke. Nothing after the
| `add.b` touches X (`moveq`, `move`, `bsr`, `rts`): the caller picks it up with `roxr`.
| Minimum gaps: 38 cycles from CLK to 0, 94 from 0 to the CLK of the next bit.
.Lbit:
        move.b  (%a1), %d0
        add.b   %d0, %d0                | X ← bit 7
        moveq   #2, %d0
        bsr     .Lecrire                | CLK
        moveq   #0, %d0
        bsr     .Lecrire                | 0
        rts

.Lecrire:
        move.b  %d0, (%a0)
        rts
