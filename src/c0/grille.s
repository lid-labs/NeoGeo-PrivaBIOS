| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| LA GRILLE — 8 192 octets de données à $C02000-$C03FFF, aucun code.
|
| MESURÉ (`measured/2026-10-25-ssideki-demo.tsv`) : ssideki lit la ROM du BIOS comme une
| grille de lignes de $40 octets, en deux plans : un octet du plan haut en $C03000 + d, puis
| souvent celui du plan bas en $C02000 + d. Aucune écriture. Sous notre BIOS, ces adresses
| portent du $FF de remplissage et, de $C02000 à $C0264E, notre
| propre code. Sur le plan haut à $FF, la démo se fige après l'intro du stade (le testeur, et
| MAME). Les deux plans remplis chacun d'une seule valeur, l'intro ne finit que :
|   - plan haut à $00 ou $80, quel que soit le plan bas ($00, $01, $04, $80, $FF essayés) ;
|   - plan haut à $01, $02 ou $03, si le plan bas vaut $01, $02, $04 ou $10 — pas $00, $40,
|     $7F, $80, $81, $C0, $FE ni $FF ;
|   - jamais pour un plan haut à $04, $05, $08, $10, $40, $7F, $81, $83, $C0 ou $FF.
| Le reste du jeu dépend du plan bas : à $FF, le match de démo n'a plus que la moitié de
| ses images ; à $00, une partie se bloque, le jeu relisant les mêmes cases à chaque trame ;
| tiré de 1 à 254, elle se bloque encore, dans les trois scénarios essayés (le relevé dit
| sous quel plan haut). Tiré de 1 à 63, sur un plan haut de 0 à 3 : la démo et cinq parties
| jouées sans blocage, au plus près du témoin SNK.
|
| LES OCTETS SONT LES NÔTRES, calculés ici, dans ces deux intervalles : un générateur
| congruentiel sur 16 bits, x ← ($6255·x + $3619) mod 65536, de période pleine
| (Hull-Dobell : $6255 ≡ 1 mod 4, $3619 impair), dont la période dépasse les 8 192 pas.
| SUPPOSÉ : que ces intervalles conviennent aux autres jeux qui lisent ici — le relevé en
| nomme une trentaine, dont socbrawl, que la grille améliore sans le rendre au témoin.
|
| L'ADRESSE EST TENUE PAR `build/bios.ld`, qui range `.grille` à $C02000 au bout du code et
| refuse le lien si le code dépasse $C02000. La grille ne dépend donc plus du code : celui
| qui ne tient pas dessous va en zone haute (`card.s`, `mess.s` et `video.s` y sont passés).
| ==================================================================================

        .section .grille, "a"
        .global _grille
_grille:
        .set    grille_x, 0x1D2B        | graine : un choix, sans autre raison
        | Le plan bas, $C02000-$C02FFF : 1 à 63, l'octet haut du générateur ramené à cet intervalle.
        .rept   4096
        .set    grille_x, (grille_x * 0x6255 + 0x3619) & 0xFFFF
        .byte   1 + (((grille_x >> 8) * 63) >> 8)
        .endr
        | Le plan haut, $C03000-$C03FFF : 0 à 3, les deux bits hauts du générateur, à la suite.
        .rept   4096
        .set    grille_x, (grille_x * 0x6255 + 0x3619) & 0xFFFF
        .byte   grille_x >> 14
        .endr
