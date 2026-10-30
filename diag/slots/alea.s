| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| The window of the random table that `build/bios.ld` requires ($C04200, 256 bytes): empty here,
| the diagnostic image draws nothing from it. It exists only so that `build/construire.sh` links it.
        .section .alea, "a"
        .global _table_alea
_table_alea:
        .space  256
