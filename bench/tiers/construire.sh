#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
# Builds the third-party free Neo Geo BIOSes, to put them through the bench.
#
#   bench/tiers/construire.sh <dossier-de-travail>
#
# Both projects are cloned, compiled in a container, and their images dropped into
# <dossier-de-travail>/images/. Nothing is installed on the machine: that is the repository's rule,
# and here it comes in handy, the two toolchains wanting different m68k tools.
#
# TWO PITFALLS, paid for while writing this script:
#
#  - `neogeo-bios` lists `cmake` and `gcc-m68k-linux-gnu` as prerequisites. That is NOT ENOUGH:
#    without `libc6-dev-m68k-cross`, `#include <string.h>` resolves to the host's headers and the
#    compilation fails at 96%. The Dockerfile next to this script adds it.
#  - NeoPen's Makefile wants `m68k-elf-*` tools, absent from Debian. We pass it the
#    `m68k-linux-gnu-*` ones, which target the same 68000 ELF. **The produced image is then not
#    the one the project published**: measured 2.7 KiB larger than its 2015 binary, and less
#    compatible on the bench. 2026 toolchain versus 2015 toolchain, or code that moved after the
#    release — not settled. Measure both images, not just one.
#
# The containers run AS THE CURRENT USER: as root, the files written into the mounted source would
# belong to root on a Linux host, and the `git clean` of the next run would fail.
#
# The compilation runs WITHOUT NETWORK: the dependencies are in the image and the source is
# mounted, so a booby-trapped CMakeLists or Makefile can neither download nor exfiltrate.
set -eu

# PINNED SOURCES. The co-simulator (unpublished) already applies this discipline to its RTL, and
# for the same reason: a published record must be reproducible identically, and an upstream that
# moves — or is compromised — must not be compiled silently. These are the commits measured by
# the 2026-10-10 campaign. To follow upstream, change the SHA here and redo the measurement.
NEOGEO_BIOS_SHA=93c02a9b68dabea96fde301fa6a7f9eaff3ae704   # 2026-01-02
NEOPENBIOS_SHA=2b28ff0f4adf296757467f179d70d0e64a847f29    # 2015-08-03

WORK="${1:?dossier de travail attendu}"
ICI="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$WORK/src" "$WORK/images"
WORK="$(cd "$WORK" && pwd)"

docker build -q -t privabios-tiers "$ICI" >/dev/null

cloner() { # <url> <sha> <directory>
  [ -d "$3/.git" ] || git clone --quiet --no-checkout "$1" "$3"
  git -C "$3" fetch --quiet --depth 1 origin "$2"
  git -C "$3" checkout --quiet --force "$2"
  git -C "$3" clean -qfdx
}
cloner https://github.com/neogeo-projects/neogeo-bios.git "$NEOGEO_BIOS_SHA" "$WORK/src/neogeo-bios"
cloner https://github.com/neogeodev/neopenbios.git        "$NEOPENBIOS_SHA"  "$WORK/src/neopenbios"

docker run --rm --network none --user "$(id -u):$(id -g)" -v "$WORK/src/neogeo-bios:/src" -v "$WORK/images:/out" privabios-tiers bash -lc '
  rm -rf build
  cmake -S . -B build -DSYSTEM=MVS -DREGION=EUROPE >/dev/null
  cmake --build build --parallel >/dev/null
  cp build/neogeo/sp-s2.sp1 /out/neogeo-bios.sp1'

docker run --rm --network none --user "$(id -u):$(id -g)" -v "$WORK/src/neopenbios:/src" -v "$WORK/images:/out" privabios-tiers bash -lc '
  make AS=m68k-linux-gnu-as GCC=m68k-linux-gnu-gcc LD=m68k-linux-gnu-ld OBJC=m68k-linux-gnu-objcopy >/dev/null
  cp neopenbios.bin /out/neopen-src.sp1'

for f in "$WORK"/images/*.sp1; do
  t=$(wc -c < "$f")
  [ "$t" -eq 131072 ] || { echo "$(basename "$f") : $t octets, 131072 attendus"; exit 1; }
  printf '%-20s %s octets\n' "$(basename "$f")" "$t"
done
