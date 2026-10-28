| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| La fenêtre de la table d'aléa que `build/bios.ld` exige ($C04200, 256 octets) : vide ici,
| l'image de diagnostic n'en tire rien. Elle n'existe que pour que `build/construire.sh` la lie.
        .section .alea, "a"
        .global _table_alea
_table_alea:
        .space  256
