| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| THE GRID — 8,192 bytes of data at $C02000-$C03FFF, no code.
|
| MEASURED (`measured/2026-10-25-ssideki-demo.tsv`): ssideki reads the BIOS ROM as a
| grid of lines of $40 bytes, in two planes: a byte of the high plane at $C03000 + d, then
| often that of the low plane at $C02000 + d. No write. Under our BIOS, these addresses
| hold $FF padding and, from $C02000 to $C0264E, our
| own code. On the high plane at $FF, the demo freezes after the stadium intro (the tester, and
| MAME). The two planes each filled with a single value, the intro only finishes:
|   - high plane at $00 or $80, whatever the low plane ($00, $01, $04, $80, $FF tried);
|   - high plane at $01, $02 or $03, if the low plane is $01, $02, $04 or $10 — not $00, $40,
|     $7F, $80, $81, $C0, $FE nor $FF;
|   - never for a high plane at $04, $05, $08, $10, $40, $7F, $81, $83, $C0 or $FF.
| The rest of the game depends on the low plane: at $FF, the demo match has only half of
| its pictures left; at $00, a game session locks up, the game rereading the same cells at each frame;
| drawn from 1 to 254, it still locks up, in the three scenarios tried (the record says
| under which high plane). Drawn from 1 to 63, on a high plane from 0 to 3: the demo and five sessions
| played without lock-up, as close as can be to the SNK witness run.
|
| THE BYTES ARE OURS, computed here, within these two ranges: a 16-bit linear
| congruential generator, x ← ($6255·x + $3619) mod 65536, of full period
| (Hull-Dobell: $6255 ≡ 1 mod 4, $3619 odd), whose period exceeds the 8,192 steps.
| ASSUMED: that these ranges suit the other games that read here — the record
| names some thirty of them, among which socbrawl, which the grid improves without bringing it back to the witness run.
|
| THE ADDRESS IS HELD BY `build/bios.ld`, which places `.grille` at $C02000 at the end of the code and
| refuses the link if the code goes beyond $C02000. The grid therefore no longer depends on the code: code
| that does not fit below it goes to the high zone (`card.s`, `mess.s` and `video.s` moved there).
| ==================================================================================

        .section .grille, "a"
        .global _grille
_grille:
        .set    grille_x, 0x1D2B        | seed: a choice, for no other reason
        | The low plane, $C02000-$C02FFF: 1 to 63, the generator's high byte brought into this range.
        .rept   4096
        .set    grille_x, (grille_x * 0x6255 + 0x3619) & 0xFFFF
        .byte   1 + (((grille_x >> 8) * 63) >> 8)
        .endr
        | The high plane, $C03000-$C03FFF: 0 to 3, the generator's two high bits, following on.
        .rept   4096
        .set    grille_x, (grille_x * 0x6255 + 0x3619) & 0xFFFF
        .byte   grille_x >> 14
        .endr
