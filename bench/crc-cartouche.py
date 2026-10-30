#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
"""The CRC32 that the CARTRIDGE CRC screen (`src/c0/crc.s`) must display, computed OUTSIDE MAME,
from the romset zip: to judge the screen on something other than MAME itself.

    python3 -I bench/crc-cartouche.py <roms-dir> <game> [<game>…]

One tab-separated line per game: game, FIXED (size in KiB, CRC), BANKS (count, CRC), and the source
of each file read with its CRC from `-listxml` — or "non reconstruit" (not rebuilt) and why.

THE 68000'S VIEW, rebuilt the way MAME 0.286 loads the P-ROM (source read:
`src/mame/neogeo/neogeo.cpp`, `ROM_LOAD16_WORD_SWAP`, `ROM_CONTINUE`, `write_banksel`, `init_cpu`;
the list of files and their offsets: `mame -listxml <game>`, region `cslot1:maincpu`):
  - each file at its offset, its bytes in file order — that is the order the screen sums
    (each word low byte first), hence no swap here;
  - a single 2 MiB file at offset $100000: its first MiB at $100000, the second at $000000
    (`ROM_CONTINUE( 0x000000, 0x100000 )`, mslug, kof94…);
  - the region is at least 1 MiB, zeros beyond the files (measured on aof, lua, on 2026-10-25).
Not rebuilt: files at odd offsets (two interleaved 8-bit chips), and the games that
MAME decrypts at load time — the screen sums the plaintext there, which only MAME knows; the script
cannot recognise them, the comparison shows them (kof98, `measured/2026-10-25-crc-cartouche.tsv`).

THE SCREEN'S RULES, the same as `crc.s`:
  - FIXED: $000000-$0FFFFF, halved as long as the upper half is the mirror of the lower one (64 KiB
    at least);
  - BANKS: none if the window $200000-$2FFFFF equals the fixed P-ROM (MAME leaves the P-ROM of a
    cartridge of 1 MiB at most there); otherwise banks 0, 1… up to the first one equal to an earlier
    bank, bank n being MiB n + 1 of the region, or bank 0 beyond it (`write_banksel`). The screen
    compares signatures (sixteen 4 KiB slices); here, the whole bank.
No ROM byte is written or kept: the CRCs only.
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
