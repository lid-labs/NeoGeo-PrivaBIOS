#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
# Construit les BIOS Neo Geo libres tiers, pour les passer au banc.
#
#   bench/tiers/construire.sh <dossier-de-travail>
#
# Les deux projets sont clonés, compilés dans un conteneur, et leurs images déposées dans
# <dossier-de-travail>/images/. Rien n'est installé sur la machine : c'est la règle du dépôt, et
# ici elle tombe bien, les deux chaînes voulant des outils m68k différents.
#
# DEUX PIÈGES, payés en écrivant ce script :
#
#  - `neogeo-bios` liste `cmake` et `gcc-m68k-linux-gnu` comme prérequis. C'est INSUFFISANT : sans
#    `libc6-dev-m68k-cross`, `#include <string.h>` se résout vers les en-têtes de l'hôte et la
#    compilation échoue à 96 %. Le Dockerfile d'à côté l'ajoute.
#  - le Makefile de NeoPen veut des outils `m68k-elf-*`, absents de Debian. On lui passe les
#    `m68k-linux-gnu-*`, qui visent le même ELF 68000. **L'image produite n'est alors pas celle
#    que le projet publiait** : mesurée plus grosse de 2,7 Kio que son binaire de 2015, et moins
#    compatible au banc. Chaîne de 2026 contre chaîne de 2015, ou code qui a bougé après la
#    release — non tranché. Mesurer les deux images, pas une seule.
#
# Les conteneurs tournent SOUS L'UTILISATEUR COURANT : en root, les fichiers écrits dans la source
# montée appartiendraient à root sur un hôte Linux, et le `git clean` du run suivant échouerait.
#
# La compilation tourne SANS RÉSEAU : les dépendances sont dans l'image et la source est montée,
# donc un CMakeLists ou un Makefile piégé ne peut ni télécharger ni exfiltrer.
set -eu

# SOURCES ÉPINGLÉES. Le co-simulateur (non publié) applique déjà cette discipline à son RTL, et
# pour la même raison : un relevé publié doit pouvoir être refait à l'identique, et un amont qui
# bouge — ou qui est compromis — ne doit pas se compiler en silence. Ce sont les commits mesurés
# par la campagne du 2026-10-10. Pour suivre l'amont, changer le SHA ici et refaire la mesure.
NEOGEO_BIOS_SHA=93c02a9b68dabea96fde301fa6a7f9eaff3ae704   # 2026-01-02
NEOPENBIOS_SHA=2b28ff0f4adf296757467f179d70d0e64a847f29    # 2015-08-03

WORK="${1:?dossier de travail attendu}"
ICI="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$WORK/src" "$WORK/images"
WORK="$(cd "$WORK" && pwd)"

docker build -q -t sprixe-bios-tiers "$ICI" >/dev/null

cloner() { # <url> <sha> <dossier>
  [ -d "$3/.git" ] || git clone --quiet --no-checkout "$1" "$3"
  git -C "$3" fetch --quiet --depth 1 origin "$2"
  git -C "$3" checkout --quiet --force "$2"
  git -C "$3" clean -qfdx
}
cloner https://github.com/neogeo-projects/neogeo-bios.git "$NEOGEO_BIOS_SHA" "$WORK/src/neogeo-bios"
cloner https://github.com/neogeodev/neopenbios.git        "$NEOPENBIOS_SHA"  "$WORK/src/neopenbios"

docker run --rm --network none --user "$(id -u):$(id -g)" -v "$WORK/src/neogeo-bios:/src" -v "$WORK/images:/out" sprixe-bios-tiers bash -lc '
  rm -rf build
  cmake -S . -B build -DSYSTEM=MVS -DREGION=EUROPE >/dev/null
  cmake --build build --parallel >/dev/null
  cp build/neogeo/sp-s2.sp1 /out/neogeo-bios.sp1'

docker run --rm --network none --user "$(id -u):$(id -g)" -v "$WORK/src/neopenbios:/src" -v "$WORK/images:/out" sprixe-bios-tiers bash -lc '
  make AS=m68k-linux-gnu-as GCC=m68k-linux-gnu-gcc LD=m68k-linux-gnu-ld OBJC=m68k-linux-gnu-objcopy >/dev/null
  cp neopenbios.bin /out/neopen-src.sp1'

for f in "$WORK"/images/*.sp1; do
  t=$(wc -c < "$f")
  [ "$t" -eq 131072 ] || { echo "$(basename "$f") : $t octets, 131072 attendus"; exit 1; }
  printf '%-20s %s octets\n' "$(basename "$f")" "$t"
done
