| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| The window of the grid that `build/bios.ld` requires ($C02000-$C03FFF): empty here, the
| harness draws nothing from it. It exists only so that `build/construire.sh` links it.
        .section .grille, "a"
        .global _grille
_grille:
        .space  0x2000
