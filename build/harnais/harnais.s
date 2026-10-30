| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| CHAIN HARNESS — this is NOT layer 0, and it does not claim to boot anything.
|
| Its only role is to prove that `build/construire.sh` produces an image that the co-simulator
| (unpublished) loads and that the 68000 executes: it writes a recognisable pattern in RAM, then loops. If the
| co-simulator's trace carries that write, the chain goes from the source to the loaded image.
|
| It deliberately gives no kick to the watchdog: the bench must therefore reset it
| every eight frames (I3), which can be checked in the same trace.
|
| Writing the BIOS falls to implementation agents (`docs/DECISIONS.md` §1). This file is
| tooling, not an implementation.

        .section .vectors, "a"
        .long   0x10F300        | supervisor stack, below the BIOS RAM
        .long   _reset          | reset vector: where the 68000 jumps

        .text
        .global _reset
_reset:
        move.w  #0x5A17, 0x100000   | the pattern, at the first work RAM address
boucle:
        bra.s   boucle
