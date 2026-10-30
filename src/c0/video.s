| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| FIX_CLEAR ($C004C2) AND LSP_1st ($C004C8) — two entries of the call table, the video.
|
| The six-byte slots of `c0.s` carry only a `jmp`: the code lives here, in
| `.text`, which `build/bios.ld` links after `.vectors`, hence beyond $C00800.
|
| THREE KINDS OF CLAIMS, and each one says so:
|   "measured":  a contract of `specs/traces/`, named — `appel_C004C2.md` (8 calls),
|                `appel_C004C8.md` (4 calls);
|   "read in":   a page of the NeoGeo Development Wiki, named;
|   "ASSUMED":   neither one nor the other, and it is said.
|
| THE VRAM IS SEEN ONLY THROUGH THREE REGISTERS. Read in "VRAM": REG_VRAMADDR ($3C0000)
| sets the address, REG_VRAMRW ($3C0002) carries the data, REG_VRAMMOD ($3C0004) is the step
| added to the address after each write. These two calls write nothing else.
|
| THE PACE OF THE WRITES. Read in "VRAM", Access timing: 12 CPU cycles at least
| between two data, 16 between a data and the address that follows. The loop
| `move.w %d0,(%a0)` (8 cycles) + `dbra` taken (10) puts 18 between two data; after
| the loop exit, `dbra` not taken (14) precedes the next address write.
|
| WHAT THESE ROUTINES DO NOT DO, deliberately: the writes "d'une partie des
| appels seulement" of the two contracts ($10F2xx, $10FD9x-$10FEFx, $3800xx, $3A00xx,
| backup RAM). The $10F2xx stack is the reference's; the rest, a SYSTEM_INT1
| that fell during the call in its case. IRQs are not masked here, AND OUR INT1 WRITES THE
| VRAM REGISTERS: `int1.s` calls MESS_OUT (`mess.s`), which sets REG_VRAMADDR, REG_VRAMMOD and
| writes REG_VRAMRW as soon as the BIOS_MESS_BUFFER buffer is not empty and BIOS_MESS_BUSY
| ($10FDC2) is not raised (read in the code). A FIX_CLEAR or an LSP_1st called with IRQs open
| with a non-empty buffer can therefore be cut by an INT1: the rest of the fill restarts
| from the address and the step that MESS_OUT left, some targeted cells stay unwritten and
| others wrongly receive a write. Nothing here guards against it; it is up to the caller to mask
| the IRQs or empty the buffer before the call. The BIOS itself calls them with IRQs masked.
| ==================================================================================

        | In the high zone since 2026-10-25: $C02000-$C03FFF is the grid (`grille.s`).
        .section .haut, "ax"
        .global _fix_clear
        .global _lsp_1st

| ----------------------------------------------------------------------------------
| FIX_CLEAR — reached by `jmp` from $C004C2; the game enters it by `jsr` and
| leaves by our `rts`.
|
| Read in "FIX_CLEAR": "Clears all the fix layer with tile # $FF, palette 0. The
| leftmost and rightmost columns are cleared with tile # $20, palette 0." Read in
| "Fix layer": the map is in VRAM at $7000, 40 × 32 = 1,280 words, one word per cell
| (palette in the 4 high bits, tile in the 12 low ones), stored "top to bottom, and
| left to right" — a column is therefore 32 consecutive words. Hence, with a step of 1:
|   $7000-$701F  column 0   ← $0020, 32 words
|   $7020-$74DF  columns 1 to 38 ← $00FF, 38 × 32 = 1,216 words
|   $74E0-$74FF  column 39  ← $0020, 32 words
| Measured (`appel_C004C2.md`, core): $3C0000 ← $7000 and $7020, $3C0002 ← $0020 and
| $00FF, $3C0004 ← $0001 — these values, and no other. The 5,173 to 6,279 accesses per
| call are the order of magnitude of the 1,280 writes and their loop.
|
| THE ADDRESS $7020 IS REDUNDANT: the auto-increment is already at the end of column 0 there.
| It is written because the contract shows it at each call. The order of the three zones,
| which the contract does not give (its lists are sorted), is ASSUMED: that of the addresses.
| Column 39 follows 38 without a new address, which explains why $74E0 does not appear
| in the contract.
|
| REGISTERS. Read in "FIX_CLEAR": "register contents aren't preserved ! (Uses D0, D1,
| and A0)". Only these three are used; the others are returned intact.
| On exit, REG_VRAMMOD is $0001, the only value the contract shows.
| ----------------------------------------------------------------------------------
_fix_clear:
        lea     0x3C0002, %a0           | REG_VRAMRW
        move.w  #0x0001, 0x3C0004       | REG_VRAMMOD:  step of 1
        move.w  #0x7000, 0x3C0000       | REG_VRAMADDR: column 0

        move.w  #0x0020, %d0            | tile $20, palette 0: the edge mask
        moveq   #32-1, %d1
1:      move.w  %d0, (%a0)
        dbra    %d1, 1b

        move.w  #0x7020, 0x3C0000       | REG_VRAMADDR: column 1
        move.w  #0x00FF, %d0            | tile $FF, palette 0: the space
        move.w  #(38*32)-1, %d1
2:      move.w  %d0, (%a0)
        dbra    %d1, 2b

        move.w  #0x0020, %d0            | column 39, following on: $74E0-$74FF
        moveq   #32-1, %d1
3:      move.w  %d0, (%a0)
        dbra    %d1, 3b
        rts

| ----------------------------------------------------------------------------------
| LSP_1st — reached by `jmp` from $C004C8; the game enters it by `jsr` and leaves
| by our `rts`.
|
| Read in "LSP_1st" ("LSP_1ST ($C004C8): Clear sprites"):
|   - "all SCB2 is set to $0FFF" (maximum shrink);
|   - "all SCB3 is set to $0000" (height 0, Y = 496);
|   - "all SCB4 is set to $BE00" (X = 380);
|   - "The map of sprite #0 is set to tiles # $FF (SCB1 $0000~$0040 to $00FF,$0000)".
| Read in "Sprites": SCB2, SCB3 and SCB4 start at $8000, $8200 and $8400 and are
| $200 words each — contiguous, hence 1,536 words in one piece from $8000. Read in
| "VRAM": going from the low zone ($0000-$7FFF) to the high one requires setting the
| address again, not counting on the auto-increment — hence the contract's two addresses.
|
| Measured (`appel_C004C8.md`, core): $3C0000 ← $0000 and $8000, $3C0002 ← $0000, $00FF,
| $0FFF, $BE00, $3C0004 ← $0001 and $0002. 6,344 accesses per call.
|
| SCB1 WITH A STEP OF 2 — ASSUMED, and it is the choice that weighs. The contract shows $0002 on
| REG_VRAMMOD at each call, and only two addresses, $0000 and $8000. A step of 2
| from $0000 touches the even words of sprite 0's map — its 32 tile numbers
| ("Sprites", SCB1: one tile word then one attribute word per tile) — and ends at
| $0040, the bound the page writes. The attribute words (odd) are then NOT
| written: reaching them would require address $0001, absent from the contract. The page says
| "$00FF,$0000"; I read the "$0000" as the observed attribute, not as a write
| — a debatable reading. No consequence on screen: SCB3 at $0000 gives sprite 0 a
| zero height. The other reading — step of 1, $00FF/$0000 pairs over 64 words — also
| fits the contract, but gives no role there to the value $0002.
|
| THE ORDER — ASSUMED. The contract sorts its lists, the page enumerates without ordering. SCB1
| first, the high zone next: REG_VRAMMOD ends at $0001, the value FIX_CLEAR
| also leaves, which serves a game that chains the two and then writes without setting
| the step again. REG_VRAMADDR ends at $8600: "VRAM address is modified", says the page.
|
| REGISTERS. Read in "LSP_1st": "Uses D0, D1, and A0". Like FIX_CLEAR.
| ----------------------------------------------------------------------------------
_lsp_1st:
        lea     0x3C0002, %a0           | REG_VRAMRW

        | SCB1 of sprite 0: 32 tile numbers, step of 2.
        move.w  #0x0002, 0x3C0004       | REG_VRAMMOD:  step of 2
        move.w  #0x0000, 0x3C0000       | REG_VRAMADDR: SCB1, sprite 0
        move.w  #0x00FF, %d0            | tile $FF
        moveq   #32-1, %d1
1:      move.w  %d0, (%a0)
        dbra    %d1, 1b

        | SCB2, SCB3, SCB4: 3 × 512 words in a row, step of 1.
        move.w  #0x0001, 0x3C0004       | REG_VRAMMOD:  step of 1
        move.w  #0x8000, 0x3C0000       | REG_VRAMADDR: SCB2
        move.w  #0x0FFF, %d0            | SCB2: maximum shrink
        move.w  #512-1, %d1
2:      move.w  %d0, (%a0)
        dbra    %d1, 2b
        moveq   #0, %d0                 | SCB3 ($8200): height 0, Y = 496
        move.w  #512-1, %d1
3:      move.w  %d0, (%a0)
        dbra    %d1, 3b
        move.w  #0xBE00, %d0            | SCB4 ($8400): X = 380
        move.w  #512-1, %d1
4:      move.w  %d0, (%a0)
        dbra    %d1, 4b
        rts
