#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
#
# Assemble une image de BIOS Neo Geo de 128 Kio, au format que MAME charge (`sp-s2.sp1`).
#
#   ./build/construire.sh <dossier-de-sources> [sortie.sp1]
#
# BIOS_OBJ        dossier des objets intermédiaires (défaut : `obj/` à la racine du dépôt), et de
#                 la sortie par défaut. Les noms y sont fixes (`bios.elf`, `bios.bin`,
#                 `<source>_s.o`) : deux constructions simultanées dans le même dossier se
#                 mélangent sans erreur. Un dossier par construction les sépare ;
#                 `bench/non-regression.sh` le fait.
# NGDEVKIT_IMAGE  image Docker de la chaîne de construction (défaut : `sprixe-bios-build`). Absente,
#                 elle est construite ici depuis `docker/Dockerfile` : rien n'est tiré d'un registre.
#
# Le dossier de sources peut être hors du dépôt (une copie jetable, par exemple) : il est monté
# à part dans le conteneur, en lecture seule.
#
# LES SOURCES SONT DU `.s` ET DU `.c`, assemblés et liés par la chaîne `m68k-neogeo-elf-*` du PPA
# public ngdevkit (voir `docs/BUILD.md`). Rien n'est installé sur la machine hors Docker et
# `python3` : tout passe par le conteneur, épinglé à `linux/amd64` faute de paquet arm64.
#
# DEUX PIÈGES, et ils ne se voient pas :
#
#   1. L'IMAGE SORT AU FORMAT MAME, octets inversés par paires. MAME applique un échange d'octets
#      par mot au BIOS qu'il charge : une image en big-endian natif y entrerait à l'envers, et le
#      68000 lirait n'importe quoi. Le swap final de ce script est donc ce qui la rend chargeable,
#      pas une coquetterie.
#   2. LA TAILLE EST EXACTEMENT 131 072 OCTETS. Une image courte ne casserait rien de visible sous
#      un émulateur qui rend `0xFF` au-delà — elle décalerait seulement ce que le matériel réel
#      lirait. On pade, et on refuse ce qui dépasse.
#
# `build/bios.ld` place les vecteurs à l'offset 0 et lie le reste en `$C00000` : voir son en-tête.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=${1:?usage: ./build/construire.sh <dossier-de-sources> [sortie.sp1]}
OBJ=${BIOS_OBJ:-obj}
OUT=${2:-$OBJ/bios.sp1}
IMAGE=${NGDEVKIT_IMAGE:-sprixe-bios-build}
TAILLE=131072

[ -d "$SRC" ] || { echo "dossier de sources introuvable : $SRC" >&2; exit 2; }
# La racine du dépôt est montée en `/w` (pour `build/bios.ld`), les sources en `/s` et les objets
# en `/o` : chacun par son chemin absolu sur l'hôte, d'où les `pwd -P`. Une espace ou un deux-points
# dans un chemin casserait le `-v` de docker : refusé plutôt que deviné.
RACINE=$(pwd -P)
SRC=$(cd "$SRC" && pwd -P)
mkdir -p "$OBJ"
OBJ=$(cd "$OBJ" && pwd -P)
for chemin in "$RACINE" "$SRC" "$OBJ"; do
  case "$chemin" in *[[:space:]:]*) echo "chemin refusé (espace ou deux-points) : $chemin" >&2; exit 2 ;; esac
done
# L'image de construction est faite localement depuis `docker/Dockerfile`, jamais tirée d'un
# registre : c'est elle qui fixe la version de la chaîne, donc l'image produite à l'octet près.
docker image inspect "$IMAGE" >/dev/null 2>&1 || {
  echo "=== image $IMAGE absente : construction depuis docker/Dockerfile" >&2
  docker build --platform linux/amd64 -t "$IMAGE" "$RACINE/docker" >&2
}

# `find` et non un glob : sous `pipefail`, un `ls *.c` sans correspondance fait échouer le
# pipeline, et `set -e` sortait du script **sans rien dire**. Le `sort` rend l'ordre des objets
# stable, donc le lien reproductible — deux constructions de la même source donnent la même image.
SOURCES=$(cd "$SRC" && find . -maxdepth 1 \( -name '*.s' -o -name '*.c' \) \
  | sed 's|^\./||' | sort | tr '\n' ' ')
[ -n "$SOURCES" ] || { echo "aucun .s ni .c dans $SRC" >&2; exit 2; }
echo "=== sources : $SOURCES" >&2

# --network none : rien dans l'assemblage n'a besoin du réseau. Le corps ci-dessous est entre
# quotes simples : pas d'apostrophe dedans, elle fermerait la quote et couperait le script.
#
# `tr . _` garde l'extension dans le nom de l'objet. Sans elle, `foo.s` et `foo.c` écriraient tous
# deux `obj/foo.o`, et le second effacerait le premier sans un mot.
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

# Le padding et le swap, sur l'hôte : le conteneur n'a pas de python3 et le compte d'octets est
# plus clair ici, où il peut refuser.
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
