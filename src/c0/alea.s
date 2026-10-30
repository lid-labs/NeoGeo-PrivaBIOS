| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| THE RANDOM TABLE — 256 bytes of data at $C04200-$C042FF, no code.
|
| MEASURED (`measured/2026-10-16-kof98-diagnostic-remise.tsv`): `kof98` indexes
| the BIOS ROM at $C04200 + (x & $FF) as a random table, and redraws until it gets a
| value different from the previous one modulo 9. On a constant $FF padding, all the
| draws are equal: the loop does not exit, the watchdog is no longer fed, the board
| restarts every ~9 frames. The causal test "table only" makes the game leave the draw.
|
| THE BYTES ARE OURS, and they are computed here, not copied. ASSUMED: that a
| "varied enough" sequence suffices — nothing says which distribution the games expect, the
| only measured requirement being values different modulo 9. A permutation
| of 0..255 is taken: a linear congruential generator x ← (77·x + $3B) mod 256, of full period
| (77 ≡ 1 mod 4 and $3B odd — the Hull-Dobell theorem, nothing specific to the Neo Geo),
| each output of which goes through x ^ (x >> 4), a bijection on the byte (the high nibble
| is kept, the low one depends on it) that breaks the even/odd alternation of the low bit. Each
| value from 0 to 255 therefore appears there exactly once.
|
| THE ADDRESS IS HELD BY `build/bios.ld`, which places `.alea` at $C04200 at the end of `.text`,
| after the sine table of `sinus.s` ($C04000-$C041FF). The isolated reads that
| the record notes at $C04000 + k × $40 (k = 0..7) read the $FF padding there; they read
| the table since, and kof98 plays the same (DECISIONS §18).
| ==================================================================================

        .section .alea, "a"
        .global _table_alea
_table_alea:
        .set    alea_x, 0x5A            | seed: a choice, for no other reason
        .rept   256
        .set    alea_x, (alea_x * 77 + 0x3B) & 0xFF
        .byte   alea_x ^ (alea_x >> 4)
        .endr
