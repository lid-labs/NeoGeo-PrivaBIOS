#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
"""The CARTRIDGE CRC screen against `bench/crc-cartouche.py`, set by set: how far FIXED and BANKS, as
the 68000 reads them under MAME, stand from what the romset's files give.

    python3 -I -B bench/crc-recensement.py <roms-dir> <work-dir> [<game>…]

Without games: the catalogue, less the seven protected sets (`measured/2026-10-31-crc-protegees.tsv`)
and the bare boards.
Writes <work-dir>/recensement.tsv, and stops if a run did not use our image or left the screen unread.
"""
import concurrent.futures as cf
import os
import re
import shutil
import subprocess
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
PAQUET = os.path.dirname(ICI)
sys.path.insert(0, ICI)
SANS_JOY = "bakatono irrmaze janshin minasan popbounc vliner".split()   # the jig refuses them: no `:edge:joy`
PROTEGES = "kof99 garou mslug3 kof2000 mslug5 svc kof2003".split()
TRAME = 4600   # eight banks at most, about 440 frames per MiB, from frame 342
ENTREES = "270:haut,280:haut,290:haut,300:A,330:haut,336:haut,342:A"
ENTETE = "jeu\taffiche_fixed\taffiche_banks\thors_mame_fixed\thors_mame_banks\tverdict\tfichier_egal\tfichiers"


def catalogue():
    with open(os.path.join(PAQUET, "measured/2026-10-24-matrice-catalogue.tsv")) as f:
        jeux = dict.fromkeys(l.split("\t")[0] for l in f if not l.startswith("#"))
    return [j for j in jeux if j not in PROTEGES and j not in ("jeu", "ng_mv1", "ng_mv1f", "ng_mv2f", "ng_mv4f")]


def romset(roms, r, jeu, img):
    d = os.path.join(r, jeu + ".zip")
    if not os.path.exists(d):
        shutil.copy(os.path.join(roms, jeu + ".zip"), d + ".part")
        subprocess.run(["zip", "-q", "-j", "-X", d + ".part", img], check=True)
        os.rename(d + ".part", d)


def ecran(rp, travail, jeu):
    """The (FIXED, BANKS) lines of the screen at TRAME."""
    o = os.path.join(travail, "runs", jeu)
    shutil.rmtree(o, ignore_errors=True)
    os.makedirs(o)
    env = dict(os.environ, J_OUT=o, J_TESTS="1-260", J_PIECE="0", J_START="0", J_APPUIS=ENTREES, J_TEXTE=str(TRAME),
               J_FIN=str(TRAME + 10), SDL_VIDEODRIVER="dummy", SDL_MAC_BACKGROUND_APP="1")
    with open(os.path.join(o, "mame.log"), "w") as log:
        subprocess.run(["mame", jeu, "-rompath", rp, "-bios", "euro", "-video", "none", "-sound", "none", "-nothrottle",
                        "-seconds_to_run", "400", "-nvram_directory", o + "/nvram", "-cfg_directory", o + "/cfg",
                        "-skip_gameinfo", "-autoboot_script", os.path.join(ICI, "son.lua")],
                       cwd=o, env=env, stdout=log, stderr=subprocess.STDOUT)
    if not os.path.exists(os.path.join(o, "son.txt")):
        return None, None
    if "WRONG CHECKSUMS" not in open(os.path.join(o, "mame.log"), errors="replace").read():
        sys.exit(f"REFUS : {jeu} n'a pas tourné sur notre image")
    texte = open(os.path.join(o, "son.txt"), errors="replace").read()
    f = re.search(r"FIXED +(\d+K) +([0-9A-F]{8})", texte)
    b = re.search(r"BANKS +(NONE|(\d+) X \d+K +([0-9A-F]{8}))", texte)
    return f, b


def hors_mame(roms, jeu):
    """The line of `crc-cartouche.py`."""
    return subprocess.run([sys.executable, "-I", "-B", os.path.join(ICI, "crc-cartouche.py"), roms, jeu],
                          capture_output=True, text=True, check=True).stdout.splitlines()[1]


def verdict(ligne, f, b):
    if ligne[1] == "-":
        return "non_reconstruit"
    nb = b[2] or "NONE"
    egal = (int(f[1][:-1]), f[2]) == (int(ligne[1]), ligne[2]) and (nb, b[3] or "") == (ligne[3], ligne[4])
    return "egal" if egal else "different"


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    roms, travail = map(os.path.abspath, sys.argv[1:3])
    jeux = sys.argv[3:] or catalogue()
    rp = os.path.join(travail, "roms")
    shutil.rmtree(rp, ignore_errors=True)
    os.makedirs(rp)
    img = os.path.join(rp, "sp-s2.sp1")
    subprocess.run([os.path.join(PAQUET, "build/construire.sh"), os.path.join(PAQUET, "src/c0"), img],
                   env=dict(os.environ, BIOS_OBJ=os.path.join(travail, "obj")), check=True, stdout=subprocess.DEVNULL)
    for j in jeux:
        romset(roms, rp, j, img)
    with cf.ThreadPoolExecutor(12) as ex:
        vus = list(ex.map(lambda j: ecran(rp, travail, j), jeux))
    with cf.ThreadPoolExecutor(12) as ex:
        x = list(ex.map(lambda j: hors_mame(roms, j), jeux))
    lignes, illisibles = [ENTETE], []
    for j, (f, b), l in zip(jeux, vus, x):
        l = l.split("\t")
        if not (f and b):
            if j not in SANS_JOY:
                illisibles.append(j)
            lignes.append("\t".join((j, "-", "-", f"{l[1]} {l[2]}", f"{l[3]} {l[4]}".strip(), "non_lu", "", l[5])))
            continue
        fichiers = re.findall(r"(\S+?)@\w+:\d+K:(\w+)", l[5])
        egal = next((n for n, c in fichiers if c.upper() == f[2]), "")
        lignes.append("\t".join((j, f"{f[1]} {f[2]}", " ".join(b[1].split()), f"{l[1]} {l[2]}", f"{l[3]} {l[4]}".strip(),
                                 verdict(l, f, b), egal, l[5])))
    open(os.path.join(travail, "recensement.tsv"), "w").write("\n".join(lignes) + "\n")
    if illisibles:
        sys.exit("ECHEC : écran illisible sur " + " ".join(illisibles))


if __name__ == "__main__":
    main()
