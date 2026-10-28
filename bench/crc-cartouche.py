#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
"""Le CRC32 que l'écran CARTRIDGE CRC (`src/c0/crc.s`) doit afficher, calculé HORS DE MAME, depuis le
zip du romset : pour juger l'écran sur autre chose que MAME lui-même.

    python3 -I bench/crc-cartouche.py <dossier-roms> <jeu> [<jeu>…]

Une ligne par jeu, tabulée : jeu, FIXED (taille en Kio, CRC), BANKS (nombre, CRC), et la source de
chaque fichier lu avec son CRC de `-listxml` — ou « non reconstruit » et pourquoi.

LA VUE DU 68000, reconstruite comme MAME 0.286 charge la P-ROM (source lu : `src/mame/neogeo/neogeo.cpp`,
`ROM_LOAD16_WORD_SWAP`, `ROM_CONTINUE`, `write_banksel`, `init_cpu` ; la liste des fichiers et leurs
décalages : `mame -listxml <jeu>`, région `cslot1:maincpu`) :
  - chaque fichier à son décalage, ses octets dans l'ordre du fichier — c'est l'ordre que l'écran somme
    (chaque mot octet bas d'abord), donc aucun échange ici ;
  - un seul fichier de 2 Mio au décalage $100000 : son premier Mio en $100000, le second en $000000
    (`ROM_CONTINUE( 0x000000, 0x100000 )`, mslug, kof94…) ;
  - la région fait au moins 1 Mio, des zéros au-delà des fichiers (mesuré sur aof, lua, le 2026-10-25).
Pas reconstruits : les fichiers à des décalages impairs (deux puces 8 bits entrelacées), et les jeux que
MAME déchiffre au chargement — l'écran y somme le clair, que seul MAME connaît ; le script ne sait pas les
reconnaître, la comparaison les montre (kof98, `measured/2026-10-25-crc-cartouche.tsv`).

LES RÈGLES DE L'ÉCRAN, les mêmes que `crc.s` :
  - FIXED : $000000-$0FFFFF, réduit de moitié tant que la moitié haute est le miroir de la basse (64 Kio
    au moins) ;
  - BANKS : aucune si la fenêtre $200000-$2FFFFF égale la P-ROM fixe (MAME y laisse la P-ROM d'une
    cartouche d'1 Mio au plus) ; sinon les banques 0, 1… jusqu'à la première égale à une banque d'avant,
    la banque n étant le Mio n + 1 de la région, ou la banque 0 au-delà (`write_banksel`). L'écran compare
    des signatures (seize tranches de 4 Kio) ; ici, la banque entière.
Aucun octet de ROM n'est écrit ni gardé : les CRC seulement.
"""
import re
import subprocess
import sys
import zipfile
import zlib
from pathlib import Path

MIO = 0x100000


def listxml(jeu):
    x = subprocess.run(["mame", "-listxml", jeu], capture_output=True, text=True, check=True).stdout
    m = re.search(r'<machine name="%s".*?</machine>' % re.escape(jeu), x, re.S)
    if not m:
        raise SystemExit(f"{jeu} : absent de -listxml")
    roms = re.findall(r'<rom name="([^"]+)" size="(\d+)" crc="(\w+)"[^>]*region="cslot1:maincpu" offset="(\w+)"', m[0])
    return [(n, int(s), c, int(o, 16)) for n, s, c, o in roms]


def region(zroms, roms):
    if any(o % 2 for _, _, _, o in roms):
        return None, "fichiers entrelacés (décalage impair)"
    continue_ = len(roms) == 1 and roms[0][3] == MIO and roms[0][1] == 2 * MIO
    taille = 2 * MIO if continue_ else max(MIO, max(o + s for _, s, _, o in roms))
    r = bytearray(taille)
    for n, s, c, o in roms:
        d = zroms.read(n)
        if len(d) != s or f"{zlib.crc32(d):08x}" != c:
            return None, f"{n} : taille ou CRC différents de -listxml"
        if continue_:
            r[MIO:2 * MIO] = d[:MIO]          # ROM_LOAD16_WORD_SWAP( n, 0x100000, 0x100000 )
            r[0:MIO] = d[MIO:]                # ROM_CONTINUE( 0x000000, 0x100000 )
        else:
            r[o:o + s] = d
    return bytes(r), ""


def regles(r):
    fixe = r[:MIO]
    t = MIO
    while t > 0x10000 and fixe[t // 2:t] == fixe[:t // 2]:
        t //= 2
    crc_fixe = zlib.crc32(fixe[:t])
    if len(r) <= MIO:
        return t, crc_fixe, 0, None
    banques = []
    for n in range(8):
        base = (n + 1) * MIO
        b = r[base:base + MIO] if base < len(r) else r[MIO:2 * MIO]
        b = b + bytes(MIO - len(b))
        if b in banques:
            break
        banques.append(b)
    return t, crc_fixe, len(banques), zlib.crc32(b"".join(banques))


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    roms_dir = Path(sys.argv[1])
    print("jeu\tfixed_kio\tfixed_crc\tbanks\tbanks_crc\tfichiers")
    for jeu in sys.argv[2:]:
        roms = listxml(jeu)
        fichiers = " ".join(f"{n}@{o:X}:{s // 1024}K:{c}" for n, s, c, o in roms)
        r, pourquoi = region(zipfile.ZipFile(roms_dir / f"{jeu}.zip"), roms)
        if r is None:
            print(f"{jeu}\t-\t-\t-\t-\tnon reconstruit : {pourquoi} ; {fichiers}")
            continue
        t, cf, nb, cb = regles(r)
        print(f"{jeu}\t{t // 1024:04d}\t{cf:08X}\t{nb or 'NONE'}\t{'' if cb is None else f'{cb:08X}'}\t{fichiers}")


if __name__ == "__main__":
    main()
