| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| LA TABLE D'ALÉA — 256 octets de données à $C04200-$C042FF, aucun code.
|
| MESURÉ (`measured/2026-10-16-kof98-diagnostic-remise.tsv`) : `kof98` indexe
| la ROM du BIOS en $C04200 + (x & $FF) comme table d'aléa, et retire jusqu'à obtenir une
| valeur différente de la précédente modulo 9. Sur un padding $FF constant, tous les
| tirages sont égaux : la boucle ne sort pas, le watchdog n'est plus nourri, la carte
| repart toutes les ~9 trames. Le test causal « table seule » fait sortir le jeu du tirage.
|
| LES OCTETS SONT LES NÔTRES, et ils sont calculés ici, pas recopiés. SUPPOSÉ : qu'une
| suite « assez variée » suffise — rien ne dit quelle distribution les jeux attendent, la
| seule exigence mesurée étant des valeurs différentes modulo 9. On prend une permutation
| de 0..255 : un générateur congruentiel x ← (77·x + $3B) mod 256, de période pleine
| (77 ≡ 1 mod 4 et $3B impair — le théorème de Hull-Dobell, rien de propre au Neo Geo),
| dont chaque sortie passe par x ^ (x >> 4), une bijection sur l'octet (le quartet haut
| est gardé, le bas en dépend) qui casse l'alternance pair/impair du bit bas. Chaque
| valeur de 0 à 255 y figure donc une fois exactement.
|
| L'ADRESSE EST TENUE PAR `build/bios.ld`, qui range `.alea` à $C04200 au bout de `.text`,
| après la table du sinus de `sinus.s` ($C04000-$C041FF). Les lectures isolées que
| le relevé note à $C04000 + k × $40 (k = 0..7) y lisaient le remplissage $FF ; elles lisent
| la table depuis, et kof98 joue pareil (DECISIONS §18).
| ==================================================================================

        .section .alea, "a"
        .global _table_alea
_table_alea:
        .set    alea_x, 0x5A            | graine : un choix, sans autre raison
        .rept   256
        .set    alea_x, (alea_x * 77 + 0x3B) & 0xFF
        .byte   alea_x ^ (alea_x >> 4)
        .endr
