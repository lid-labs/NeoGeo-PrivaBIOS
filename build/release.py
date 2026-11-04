#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
"""The files of a release, from a built image and the CHANGELOG.

    python3 -I build/release.py <version> <image.sp1> <dossier-de-sortie>

<version> without the "v" of the tag: 0.1.0, or 0.1.0-beta.1 for a pre-release (SemVer). The script
REFUSES a version that the CHANGELOG does not date: it wants a heading "## [<version>] - AAAA-MM-JJ"
and a non-empty section under it. This is the [Unreleased] technique (Keep a Changelog): entries
accumulate under "## [Unreleased]", and the release renames them into a dated version
(`docs/RELEASE.md`). A section still "Unreleased" is therefore not publishable.

Output, in <dossier-de-sortie>:
  privabios-<version>.rom              the image as is, MAME order (`sp-s2.sp1`);
  privabios-<version>-byteswapped.bin  the other order, for a programmer set the other way round;
  SHA256SUMS                           both, in the format of `sha256sum -c`;
  notes.md                             the CHANGELOG section, then the sums.
"""
import datetime
import hashlib
import os
import re
import sys
import zlib

TAILLE = 131072  # `build/construire.sh`: the image is exactly 128 KiB
# SemVer 2.0.0: no leading zero in a number, non-empty pre-release identifiers.
NUM = r"(0|[1-9]\d*)"
SEMVER = rf"{NUM}\.{NUM}\.{NUM}(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?"


def notes_de(changelog, version):
    """The section of <version>: the text between its heading and the next heading, without the
    blank lines at the edges. Refused if the heading is missing, is not dated, or if the section
    is empty."""
    titres = list(re.finditer(r"^## \[([^\]]+)\](.*)$", changelog, re.M))
    if sum(1 for t in titres if t[1] == version) > 1:
        sys.exit(f"REFUS : deux sections « ## [{version}] » dans le CHANGELOG")
    for i, t in enumerate(titres):
        if t[1] != version:
            continue
        m = re.fullmatch(r" - (\d{4}-\d{2}-\d{2})", t[2])
        try:
            datetime.date.fromisoformat(m[1] if m else "")
        except ValueError:
            sys.exit(f"REFUS : « ## [{version}]{t[2]} » n'est pas daté (attendu : « ## [{version}] - AAAA-MM-JJ »)")
        fin = titres[i + 1].start() if i + 1 < len(titres) else len(changelog)
        # Every link definition ("[0.1.0]: https://…") is removed from the section: those at the
        # bottom of the file fall into the last one. An entry must therefore not use a reference
        # link; an inline link, [text](url), stays.
        corps = re.sub(r"^\[[^\]]+\]: .*$", "", changelog[t.end():fin], flags=re.M).strip()
        if not corps:
            sys.exit(f"REFUS : la section [{version}] du CHANGELOG est vide")
        return corps
    sys.exit(f"REFUS : aucune section « ## [{version}] » dans le CHANGELOG")


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    version, image, sortie = sys.argv[1:]
    if not re.fullmatch(SEMVER, version):
        sys.exit(f"REFUS : « {version} » n'est pas une version SemVer (0.1.0, 0.1.0-beta.1)")
    depot = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    with open(os.path.join(depot, "CHANGELOG.md"), encoding="utf-8") as f:
        corps = notes_de(f.read(), version)

    with open(image, "rb") as f:
        rom = f.read()
    if len(rom) != TAILLE:
        sys.exit(f"REFUS : {image} fait {len(rom)} octets, pas {TAILLE}")
    inverse = bytearray(TAILLE)
    inverse[0::2], inverse[1::2] = rom[1::2], rom[0::2]

    os.makedirs(sortie, exist_ok=True)
    noms = {f"privabios-{version}.rom": rom, f"privabios-{version}-byteswapped.bin": bytes(inverse)}
    sommes, lignes = [], []
    for nom, octets in noms.items():
        with open(os.path.join(sortie, nom), "wb") as f:
            f.write(octets)
        sha = hashlib.sha256(octets).hexdigest()
        sommes.append(f"{sha}  {nom}\n")
        lignes.append(f"| `{nom}` | `{zlib.crc32(octets):08X}` | `{sum(octets) & 0xFFFF:04X}` | `{sha}` |")
    with open(os.path.join(sortie, "SHA256SUMS"), "w", encoding="ascii") as f:
        f.writelines(sommes)
    with open(os.path.join(sortie, "notes.md"), "w", encoding="utf-8") as f:
        f.write(corps + "\n\n### Files\n\n"
            "Burn `.rom` as-is, like a MAME `sp-s2.sp1`, on a 27C1024. "
            "Use `-byteswapped.bin` only if your programmer expects the other byte order.\n\n"
            "| File | CRC32 | Byte sum (16-bit) | SHA-256 |\n|---|---|---|---|\n" + "\n".join(lignes) + "\n")
    print(f"{sortie} : {', '.join(noms)}, SHA256SUMS, notes.md")


if __name__ == "__main__":
    main()
