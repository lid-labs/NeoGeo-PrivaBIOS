#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
"""Génère `src/c0/sinus.s`, la table de 256 mots que des jeux lisent en $C04000-$C041FF.

    python3 -I -B bench/generer-sinus.py              # réécrit src/c0/sinus.s
    python3 -I -B bench/generer-sinus.py --verifier   # sortie 1 si le fichier versionné diffère

T[i] = round(65536 · |sin(2πi/256)|), un tour sur 256 ; T[64] et T[192] valent $0001 au lieu de
65536, qui ne tient pas sur 16 bits. Formule et codage de 1,0 tirés du comportement des jeux sur
notre image : des tables posées dans l'image, le jeu jugé à l'écran (`docs/DECISIONS.md` §18 pt 6).
Un premier agent d'enquête avait relevé quatre mots de la ROM du BIOS SNK, qui ont orienté son choix
du codage de 1,0 ; la valeur retenue a été redérivée par un agent neuf, sans ces relevés, par la seule
mesure du jeu (`docs/DECISIONS.md` §28, `docs/METHOD.md`). Le test de cohérence est dans
`bench/test_generer_contrats.py` (classe TableSinus).
"""
import math
import os
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
SORTIE = os.path.join(os.path.dirname(ICI), "src", "c0", "sinus.s")
UN = 0x0001  # le codage de 1,0 : $0000 et $FFFF mesurés faux (DECISIONS §18)


def table():
    t = []
    for i in range(256):
        v = UN if i in (64, 192) else round(65536 * abs(math.sin(2 * math.pi * i / 256)))
        assert 0 <= v <= 0xFFFF, (i, v)
        t.append(v)
    return t


def source():
    t = table()
    lignes = [
        "| SPDX-License-Identifier: GPL-3.0-or-later",
        "| Copyright (C) 2026 Thibaut Lion",
        "|",
        "| ==================================================================================",
        "| LA TABLE DU SINUS — 256 mots à $C04000-$C041FF, aucun code. GÉNÉRÉE par",
        "| `bench/generer-sinus.py` : ne pas éditer à la main, relancer le générateur.",
        "|",
        "| T[i] = round(65536 · |sin(2πi/256)|) : un angle sur un octet, un tour sur 256.",
        "| T[64] et T[192] (1,0) valent $0001 : 65536 ne tient pas sur 16 bits, $0000 fige le",
        "| vaisseau d'alpham2, $FFFF le décale d'un pixel ; mesuré par le jeu sur notre image",
        "| (`docs/DECISIONS.md` §18 pt 6 et §28). L'adresse est tenue par `build/bios.ld`.",
        "| Le commentaire de chaque ligne est l'indice de son premier mot.",
        "| ==================================================================================",
        "",
        '        .section .sinus, "a"',
        "        .global _table_sinus",
        "_table_sinus:",
    ]
    for k in range(0, 256, 8):
        mots = ", ".join("0x%04X" % v for v in t[k:k + 8])
        lignes.append(f"        .word   {mots}  | {k}")
    return "\n".join(lignes) + "\n"


if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["--verifier"]:
        actuel = open(SORTIE, encoding="utf-8").read() if os.path.exists(SORTIE) else ""
        if actuel != source():
            sys.exit(f"{SORTIE} ne correspond pas au générateur : relancer bench/generer-sinus.py")
        print(f"{SORTIE} conforme")
    elif not a:
        open(SORTIE, "w", encoding="utf-8").write(source())
        print(f"{SORTIE} écrit")
    else:
        sys.exit(__doc__)
