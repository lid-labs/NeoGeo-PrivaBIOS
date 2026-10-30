#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
#
# Assembles a 128 KiB Neo Geo BIOS image, in the format MAME loads (`sp-s2.sp1`).
#
#   ./build/construire.sh <dossier-de-sources> [sortie.sp1]
#
# BIOS_OBJ        directory for intermediate objects (default: `obj/` at the repository root), and
#                 for the default output. The names in it are fixed (`bios.elf`, `bios.bin`,
#                 `<source>_s.o`): two simultaneous builds in the same directory mix together
#                 without error. One directory per build keeps them apart;
#                 `bench/non-regression.sh` does so.
# NGDEVKIT_IMAGE  Docker image of the build toolchain (default: `sprixe-bios-build`). If absent,
#                 it is built here from `docker/Dockerfile`: nothing is pulled from a registry.
#
# The source directory may be outside the repository (a throwaway copy, for example): it is
# mounted separately in the container, read-only.
#
# THE SOURCES ARE `.s` AND `.c`, assembled and linked by the `m68k-neogeo-elf-*` toolchain from the
# public ngdevkit PPA (see `docs/BUILD.md`). Nothing is installed on the machine besides Docker and
# `python3`: everything goes through the container, pinned to `linux/amd64` for lack of an arm64
# package.
#
# TWO PITFALLS, and they cannot be seen:
#
#   1. THE IMAGE COMES OUT IN MAME FORMAT, bytes swapped in pairs. MAME applies a per-word byte
#      swap to the BIOS it loads: an image in native big-endian would go in backwards, and the
#      68000 would read garbage. The final swap of this script is therefore what makes it
#      loadable, not an affectation.
#   2. THE SIZE IS EXACTLY 131,072 BYTES. A short image would break nothing visible under an
#      emulator that returns `0xFF` beyond it — it would only shift what the real hardware would
#      read. We pad, and we refuse anything larger.
#
# `build/bios.ld` places the vectors at offset 0 and links the rest at `$C00000`: see its header.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=${1:?usage: ./build/construire.sh <dossier-de-sources> [sortie.sp1]}
OBJ=${BIOS_OBJ:-obj}
OUT=${2:-$OBJ/bios.sp1}
IMAGE=${NGDEVKIT_IMAGE:-sprixe-bios-build}
TAILLE=131072

[ -d "$SRC" ] || { echo "dossier de sources introuvable : $SRC" >&2; exit 2; }
# The repository root is mounted at `/w` (for `build/bios.ld`), the sources at `/s` and the objects
# at `/o`: each by its absolute path on the host, hence the `pwd -P`. A space or a colon in a path
# would break docker's `-v`: refused rather than guessed.
RACINE=$(pwd -P)
SRC=$(cd "$SRC" && pwd -P)
mkdir -p "$OBJ"
OBJ=$(cd "$OBJ" && pwd -P)
for chemin in "$RACINE" "$SRC" "$OBJ"; do
  case "$chemin" in *[[:space:]:]*) echo "chemin refusé (espace ou deux-points) : $chemin" >&2; exit 2 ;; esac
done
# The build image is made locally from `docker/Dockerfile`, never pulled from a registry: it is
# what fixes the toolchain version, hence the produced image down to the byte.
docker image inspect "$IMAGE" >/dev/null 2>&1 || {
  echo "=== image $IMAGE absente : construction depuis docker/Dockerfile" >&2
  docker build --platform linux/amd64 -t "$IMAGE" "$RACINE/docker" >&2
}

# `find` and not a glob: under `pipefail`, an `ls *.c` with no match makes the pipeline fail, and
# `set -e` exited the script **without a word**. The `sort` makes the order of the objects stable,
# hence the link reproducible — two builds of the same source give the same image.
SOURCES=$(cd "$SRC" && find . -maxdepth 1 \( -name '*.s' -o -name '*.c' \) \
  | sed 's|^\./||' | sort | tr '\n' ' ')
[ -n "$SOURCES" ] || { echo "aucun .s ni .c dans $SRC" >&2; exit 2; }
echo "=== sources : $SOURCES" >&2

# --network none: nothing in the assembly needs the network. The body below is in single quotes:
# no apostrophe inside it, it would close the quote and cut the script.
#
# `tr . _` keeps the extension in the object name. Without it, `foo.s` and `foo.c` would both
# write `obj/foo.o`, and the second would erase the first without a word.
docker run --rm --network none --platform linux/amd64 \
  -v "$RACINE:/w:ro" -v "$SRC:/s:ro" -v "$OBJ:/o" -w /w -u "$(id -u):$(id -g)" "$IMAGE" bash -c '
set -euo pipefail
objets=""
for f in '"$SOURCES"'; do
  objet="/o/$(basename "$f" | tr . _).o"
  case "$f" in
    *.s) m68k-neogeo-elf-as -m68000 -o "$objet" "/s/$f" ;;
    *.c) m68k-neogeo-elf-gcc -m68000 -Os -ffreestanding -c -o "$objet" "/s/$f" ;;
  esac
  objets="$objets $objet"
done
m68k-neogeo-elf-ld -T build/bios.ld -o /o/bios.elf $objets
m68k-neogeo-elf-objcopy -O binary /o/bios.elf /o/bios.bin
'

# The padding and the swap, on the host: the container has no python3 and the byte count is
# clearer here, where it can refuse.
python3 - "$OUT" "$TAILLE" "$OBJ/bios.bin" <<'PY'
import io, sys
out, taille = sys.argv[1], int(sys.argv[2])
brut = io.open(sys.argv[3], "rb").read()
if len(brut) > taille:
    sys.exit(f"l'image fait {len(brut)} octets, le BIOS en veut {taille} au plus")
brut = brut + b"\xff" * (taille - len(brut))
# Compté hors de la f-string : un backslash dans sa partie expression est une SyntaxError avant
# Python 3.12 (PEP 701), et le `python3` livré avec macOS est en 3.9.
utiles = len(brut.rstrip(b"\xff"))
# L'échange de `load16_word_swap` : le banc le défait au chargement.
swap = bytearray(brut)
swap[0::2], swap[1::2] = brut[1::2], brut[0::2]
io.open(out, "wb").write(bytes(swap))
print(f"{out} : {taille} octets, dont {utiles} de code et de données")
PY
