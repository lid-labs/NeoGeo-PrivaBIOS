#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
# Compatibility matrix: each game, under each BIOS, no window.
#
#   bench/matrice.sh <dossier-roms> <dossier-travail>
#
# Settings through the environment:
#   BIOS_NULLBIOS  zip containing sp-s2.sp1, the nullbios (mandatory without BIOS_SANS_NULLBIOS=1)
#   BIOS_SANS_NULLBIOS  1: no nullbios column. It is only a third-party landmark, and its slow
#                  runs (54 to 63% speed on garou, kof98, kof2003, mslug3) weigh 70% of the
#                  emulated time of a four-column matrix — computed from the speeds in
#                  measured/2026-10-22-matrice-durcissement.tsv, not timed.
#   BIOS_VARIANTES extra BIOSes to compare, "name=path" separated by spaces.
#                  The path is either a raw 128 KiB 68000 image, or a zip that contains
#                  an sp-s2.sp1 member. Example:
#                    BIOS_VARIANTES="neopen=$HOME/neopen.sp1 neogeo-bios=$HOME/build/sp-s2.sp1"
#                  The names `snk`, `unibios40` and `nullbios` are reserved, and a path containing
#                  a space is not supported — the list is split on whitespace.
#   BIOS_JEUX      sets to measure, separated by spaces (default: every *.zip of the folder)
#   BIOS_SECONDES  emulated duration per run (default 62, i.e. ~3,720 frames)
#   BIOS_SHOTS     record frames (default: every 100 up to 3,500)
#   BIOS_IMAGES    frames whose picture is written (default 3500)
#   BIOS_REF       SNK BIOS set of the `snk` column, MAME name (default euro; japan, us…).
#                  The variants stay under `-bios euro`: it is the sp-s2.sp1 member of the euro
#                  set that they replace, and their region is their own, not this one.
#   BIOS_CACHE     folder where the runs of the snk and unibios40 columns are kept, and taken back
#                  from: they depend on no image under test. The key covers MAME (version and
#                  effective configuration, `-showconfig`), this script, bios-probe.lua, the day (the
#                  machine takes the host's date), the game, its romset and neogeo.zip (name, size,
#                  date to the second), the BIOS and the settings BIOS_SECONDES, BIOS_SHOTS, BIOS_IMAGES.
#                  Only a run that exited with 0, started and finished the same day, is kept. The
#                  vitesse_pct column of a reused run is that of the original run (recorded, never judged)
#
# NO ROM IS VERSIONED in this repository, neither BIOS nor game. The ROM folder is yours.
#
# THREE PITFALLS, all paid for while writing this bench:
#
#  1. THE GAME ZIPS ARE NON-MERGED: each one carries its OWN full copy of the BIOS set.
#     MAME looks at the game's zip BEFORE neogeo.zip, so substituting in neogeo.zip does NOTHING.
#     An all-zero BIOS produced a run identical to the real one before anyone noticed.
#     The substitution is therefore made IN the game's zip, which is what this script does.
#  2. MAME accepts a BIOS with the wrong CRC, displaying "WRONG CHECKSUMS … the machine might not
#     run correctly". That line in the log is the PROOF that the substitution is active;
#     its absence means MAME found the real BIOS elsewhere.
#  3. NEVER WRITE THROUGH A SYMBOLIC LINK. A first version linked the user's ROMs into the
#     work folder then opened those paths for writing: it truncated a romset to 22 bytes.
#     This script copies, and refuses to write to a link.
set -eu

ROMS="${1:?dossier des romsets attendu}"
WORK="${2:?dossier de travail attendu}"
ICI="$(cd "$(dirname "$0")" && pwd)"
# Every path becomes absolute BEFORE the first subshell: further down, each run does a `cd`, and
# a relative path would resolve there from the new directory — that is, for the unsubstituted
# variants, in the user's ROM folder.
mkdir -p "$WORK"
ROMS="$(cd "$ROMS" && pwd)"
WORK="$(cd "$WORK" && pwd)"
NULLBIOS="${BIOS_NULLBIOS:-}"
AUTRES="${BIOS_VARIANTES:-}"
SECONDES="${BIOS_SECONDES:-62}"
SHOTS="${BIOS_SHOTS:-$(seq -s, 100 100 3500)}"
IMAGES="${BIOS_IMAGES:-3500}"
REF="${BIOS_REF:-euro}"
case "$REF" in ''|*[!a-z0-9-]*) echo "BIOS_REF refusé : $REF"; exit 1 ;; esac

command -v mame >/dev/null || { echo "mame introuvable"; exit 1; }
# A name unknown to MAME makes it fall back to the default BIOS, with neither error nor "WRONG
# CHECKSUMS": the `snk` column would measure Europe under the name of another region. So it is
# checked against the list that MAME itself publishes.
mame -listbios neogeo 2>/dev/null | awk 'NR > 1 {print $1}' | grep -qx -- "$REF" \
  || { echo "BIOS_REF inconnu de MAME pour neogeo : $REF"; exit 1; }
# `rm -f` before each write: it removes a possible symbolic link instead of writing through
# it. It is the same precaution as the refusal further down, applied to the BIOS images.
mkdir -p "$WORK/M"
if [ "${BIOS_SANS_NULLBIOS:-0}" = 1 ]; then
  VARIANTES=""
else
  [ -n "$NULLBIOS" ] || { echo "BIOS_NULLBIOS attendu (zip contenant sp-s2.sp1), ou BIOS_SANS_NULLBIOS=1"; exit 1; }
  mkdir -p "$WORK/img/nullbios"
  rm -f "$WORK/img/nullbios/sp-s2.sp1"
  unzip -p "$NULLBIOS" sp-s2.sp1 > "$WORK/img/nullbios/sp-s2.sp1"
  VARIANTES="nullbios"
fi

# Each variant of BIOS_VARIANTES is placed under the same member name, sp-s2.sp1, since that is
# the file `-bios euro` makes MAME load. A zip is accepted as well as a bare image: third-party
# projects ship sometimes one, sometimes the other, and requiring one format would make people
# redo by hand what two lines do here.
for paire in $AUTRES; do
  case "$paire" in *=*) ;; *) echo "variante mal formée, « nom=chemin » attendu : $paire"; exit 1 ;; esac
  nom="${paire%%=*}"; src="${paire#*=}"
  # Restricted character set, rather than a case-insensitive comparison: the name becomes a path
  # component, and the macOS file system ignores case. `NullBIOS` would therefore pass the
  # checks below while designating the SAME folder as `nullbios`, whose image it would
  # overwrite — two matrix rows measuring the same BIOS, each with `controle=ok`.
  case "$nom" in ''|.|..|*[!a-z0-9._-]*) echo "nom de variante refusé : $nom"; exit 1 ;; esac
  # RESERVED NAMES. `snk` and `unibios40` designate the original BIOSes in the measurement loop
  # further down: a variant so named would be taken for them there, measured WITHOUT substitution,
  # and would come out `controle=ok`. It is the package's invariant bypassed through the name.
  # `nullbios` is already taken.
  case " snk unibios40 nullbios " in *" $nom "*) echo "nom de variante réservé : $nom"; exit 1 ;; esac
  case " $VARIANTES " in *" $nom "*) echo "variante en double : $nom"; exit 1 ;; esac
  [ -s "$src" ] || { echo "image introuvable pour $nom : $src"; exit 1; }
  mkdir -p "$WORK/img/$nom"
  rm -f "$WORK/img/$nom/sp-s2.sp1"
  if unzip -l "$src" >/dev/null 2>&1; then
    unzip -p "$src" sp-s2.sp1 > "$WORK/img/$nom/sp-s2.sp1"
  else
    cp "$src" "$WORK/img/$nom/sp-s2.sp1"
  fi
  taille=$(wc -c < "$WORK/img/$nom/sp-s2.sp1")
  [ "$taille" -eq 131072 ] || { echo "$nom : image de $taille octets, 131072 attendus"; exit 1; }
  VARIANTES="$VARIANTES $nom"
done

JEUX="${BIOS_JEUX:-$(cd "$ROMS" && ls *.zip 2>/dev/null | sed 's/\.zip$//' | tr '\n' ' ')}"
[ -n "$JEUX" ] || { echo "aucun jeu dans $ROMS"; exit 1; }
for g in $JEUX; do
  case "$g" in */*|..*) echo "nom de set refusé : $g"; exit 1 ;; esac
  # Checked here rather than discovered further down: without this check, a missing set produced
  # a `cp` error in the middle of building the variants, far from its cause.
  [ -s "$ROMS/$g.zip" ] || { echo "set introuvable : $ROMS/$g.zip"; exit 1; }
done

# One romset per variant, obtained by replacing the sole sp-s2.sp1 member of a COPY of the game's zip.
#
# TWO PRECAUTIONS, and both guard against the same accident: measuring one BIOS while
# believing you measure another, without any message.
#
#  - a romset already present is reused only if the hash of the injected image is the SAME.
#    Without this check, changing BIOS_NULLBIOS or BIOS_VARIANTES between two runs in the same work
#    folder left the old image in place and the matrix measured the previous BIOS;
#  - the build goes through a temporary file renamed only after a successful `zip`. An
#    interruption between the copy and the `zip` otherwise left a romset carrying the original
#    SNK BIOS, which the next run accepted as if it were substituted.
for v in $VARIANTES; do
  mkdir -p "$WORK/v-$v"
  empreinte="$(shasum -a 256 "$WORK/img/$v/sp-s2.sp1" | cut -d' ' -f1)"
  marqueur="$WORK/v-$v/.image-sha256"
  # A stale marker (or link) goes BEFORE the romsets are redone: interrupted midway, it would no longer vouch for them.
  { [ ! -L "$marqueur" ] && [ "$(cat "$marqueur" 2>/dev/null)" = "$empreinte" ]; } || rm -f "$marqueur"
  for g in $JEUX; do
    d="$WORK/v-$v/$g.zip"
    [ -L "$d" ] && { echo "REFUS : $d est un lien symbolique"; exit 1; }
    if [ -s "$d" ] && [ "$(cat "$marqueur" 2>/dev/null)" = "$empreinte" ]; then continue; fi
    rm -f "$d.part"
    cp "$ROMS/$g.zip" "$d.part"
    ( cd "$WORK/img/$v" && zip -q -j -X "$d.part" sp-s2.sp1 )
    mv "$d.part" "$d"
  done
  # The marker is set only once ALL the variant's romsets are built: interrupted
  # before, the next run redoes them all rather than accepting one at random.
  echo "$empreinte" > "$marqueur"
done

CACHE="${BIOS_CACHE:-}"
if [ -n "$CACHE" ]; then
  mkdir -p "$CACHE"; CACHE="$(cd "$CACHE" && pwd)"
  empreinte_fichiers() { stat -L -f '%N %z %m' "$@" 2>/dev/null || stat -L -c '%n %s %Y' "$@"; }
  CLE_BASE="$( { mame -version; mame -showconfig; cat "$ICI/matrice.sh" "$ICI/bios-probe.lua"; \
    empreinte_fichiers "$ROMS/neogeo.zip"; echo "$SECONDES $SHOTS $IMAGES"; } 2>&1 | shasum -a 256 | cut -d' ' -f1)"
fi

printf '%s\t%s\t%s\t%s\t%s\t%s\n' jeu bios verdict vifs_max vitesse_pct controle
for g in $JEUX; do
  for v in snk unibios40 $VARIANTES; do
    case "$v" in
      snk)       RP="$ROMS"; B="$REF" ;;
      unibios40) RP="$ROMS"; B=unibios40 ;;
      *)         RP="$WORK/v-$v"; B=euro ;;
    esac
    O="$WORK/M/$g-$v"; rm -rf "$O"; mkdir -p "$O"
    rc=0
    cle=""
    jour="$(date '+%Y-%m-%d')"
    case "$v" in snk|unibios40)
      if [ -n "$CACHE" ]; then
        cle="$( { echo "$CLE_BASE $jour $g $v $B"; empreinte_fichiers "$ROMS/$g.zip"; } | shasum -a 256 | cut -c1-32)"
      fi ;;
    esac
    if [ -n "$cle" ] && [ -s "$CACHE/$cle/rc" ]; then
      rm -rf "$O"; cp -R "$CACHE/$cle" "$O"; rc=$(cat "$O/rc")
    else
    # NVRAM isolated per run ($O is new): without that, MAME shares its nvram/<jeu>/ folder
    # among all the runs of the same game, BIOSes mixed — a credit left by one run is read back
    # under the next, and the determinism claimed above no longer holds as soon as a BIOS credits.
    # SDL_MAC_BACKGROUND_APP: without it, each run comes to the foreground on macOS, even with no window.
    # cfg isolated likewise: without -cfg_directory, MAME rewrites on exit the cfg files of the
    # user's folder (their mame.ini sets one, absolute), key settings included.
    ( cd "$WORK" && SDL_VIDEODRIVER=dummy SDL_MAC_BACKGROUND_APP=1 BIOS_OUT="$O" BIOS_SHOTS="$SHOTS" BIOS_IMAGES="$IMAGES" \
      mame "$g" -rompath "$RP" -video none -sound none -nothrottle -seconds_to_run "$SECONDES" \
      -nvram_directory "$O/nvram" -cfg_directory "$O/cfg" \
      -skip_gameinfo -bios "$B" -autoboot_script "$ICI/bios-probe.lua" >"$O/mame.log" 2>&1 ) || rc=$?
    echo "$rc" > "$O/rc"
    # Kept through a copy renamed in one go, like `parcours.sh`: never a half-written entry.
    if [ -n "$cle" ] && [ "$rc" -eq 0 ] && [ ! -e "$CACHE/$cle" ] && [ "$(date '+%Y-%m-%d')" = "$jour" ]; then
      t="$CACHE/.$cle.$$"
      # A cache write that fails does not make the matrix fail (set -e).
      if mkdir "$CACHE/.$cle.verrou" 2>/dev/null && cp -R "$O" "$t"; then mv "$t" "$CACHE/$cle" || true; fi; rm -rf "$t"
    fi
    fi

    # THE PROOF THAT THE SUBSTITUTION TOOK, read at each run rather than assumed. MAME reports
    # "WRONG CHECKSUMS" when the BIOS image does not match the CRC it expects: this line
    # must therefore be present for a variant, and absent for an original BIOS. Without this
    # check, a silent substitution made the SNK BIOS be measured under a variant's name —
    # exactly the accident that the build guards close upstream, left open downstream.
    controle=ok
    case "$v" in
      snk|unibios40) grep -q 'WRONG CHECKSUMS' "$O/mame.log" && controle='ALERTE:crc-inattendu' ;;
      *)             grep -q 'WRONG CHECKSUMS' "$O/mame.log" || controle='ALERTE:substitution-absente' ;;
    esac
    [ "$rc" -ne 0 ] && controle="ALERTE:mame-exit-$rc"
    [ -s "$O/index.txt" ] || controle='ALERTE:aucun-releve'

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$g" "$v" \
      "$("$ICI/verdict.sh" "$O/index.txt")" \
      "$(grep -ao 'vifs=[0-9]*' "$O/index.txt" 2>/dev/null | cut -d= -f2 | sort -n | tail -1)" \
      "$(grep -ao 'Average speed: [0-9.]*' "$O/mame.log" | tail -1 | awk '{print $3}')" \
      "$controle"
  done
done
