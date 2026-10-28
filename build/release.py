#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
"""Les fichiers d'une release, à partir d'une image construite et du CHANGELOG.

    python3 -I build/release.py <version> <image.sp1> <dossier-de-sortie>

<version> sans le « v » du tag : 0.1.0, ou 0.1.0-beta.1 pour une préversion (SemVer). Le script
REFUSE une version que le CHANGELOG ne date pas : il veut un titre « ## [<version>] - AAAA-MM-JJ »
et une section non vide sous lui. C'est la technique du [Unreleased] (Keep a Changelog) : les
entrées s'accumulent sous « ## [Unreleased] », et la release les renomme en version datée
(`docs/RELEASE.md`). Une section encore « Unreleased » n'est donc pas publiable.

Sortie, dans <dossier-de-sortie> :
  sprixe-bios-<version>.rom              l'image telle quelle, ordre de MAME (`sp-s2.sp1`) ;
  sprixe-bios-<version>-byteswapped.bin  l'autre ordre, pour un graveur réglé à l'envers ;
  SHA256SUMS                             les deux, au format de `sha256sum -c` ;
  notes.md                               la section du CHANGELOG, puis les sommes.
"""
import datetime
import hashlib
import os
import re
import sys
import zlib

TAILLE = 131072  # `build/construire.sh` : l'image fait exactement 128 Kio
# SemVer 2.0.0 : pas de zéro en tête d'un nombre, identifiants de préversion non vides.
NUM = r"(0|[1-9]\d*)"
SEMVER = rf"{NUM}\.{NUM}\.{NUM}(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?"


def notes_de(changelog, version):
    """La section de <version> : le texte entre son titre et le titre suivant, sans les lignes
    vides du bord. Refus si le titre manque, n'est pas daté, ou si la section est vide."""
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
        # Toute définition de lien (« [0.1.0]: https://… ») est retirée de la section : celles du
        # bas du fichier tombent dans la dernière. Une entrée ne doit donc pas utiliser de lien par
        # référence ; un lien en ligne, [texte](url), reste.
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
    noms = {f"sprixe-bios-{version}.rom": rom, f"sprixe-bios-{version}-byteswapped.bin": bytes(inverse)}
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
