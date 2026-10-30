| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| The window of the sine table that `build/bios.ld` requires ($C04000, 512 bytes): empty here,
| the harness draws nothing from it. It exists only so that `build/construire.sh` links it.
        .section .sinus, "a"
        .global _table_sinus
_table_sinus:
        .space  512
