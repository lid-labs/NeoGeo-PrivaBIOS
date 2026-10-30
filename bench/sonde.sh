#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
# Runs the lua probe (sonde.lua) on a game, without a window.
#
#   bench/sonde.sh <dossier-roms> <jeu> <sortie.tsv> [bios]
#
#   <dossier-roms>  where MAME will find <jeu>.zip. TO MEASURE OUR BIOS, point to a
#                   variant directory made by matrice.sh (e.g. <travail>/v-sprixe),
#                   whose zips carry the substituted image: this script does NOT substitute.
#   [bios]          MAME's -bios flag: euro (default — the zip's sp-s2.sp1, or
#                   a variant's substituted image), unibios40, ...
#
# Settings through the environment, passed to sonde.lua:
#   SONDE_RAM   addresses read as bytes at each frame (hex, commas) — e.g. the flag that
#               a freeze loop polls, found with the co-simulator (unpublished)
#   SONDE_DE / SONDE_A   frame window (default 0..3500)
#
# The MAME duration is bounded from SONDE_A (NTSC frames ~59.19 Hz), plus a margin.
set -eu
ROMS="${1:?dossier des romsets attendu}"
JEU="${2:?nom du set attendu}"
OUT="${3:?fichier tsv de sortie attendu}"
BIOSFLAG="${4:-euro}"
ICI="$(cd "$(dirname "$0")" && pwd)"
ROMS="$(cd "$ROMS" && pwd)"
command -v mame >/dev/null || { echo "mame introuvable" >&2; exit 1; }
[ -s "$ROMS/$JEU.zip" ] || { echo "set introuvable : $ROMS/$JEU.zip" >&2; exit 2; }

A="${SONDE_A:-3500}"
SECONDES=$(( A / 59 + 3 ))
rm -f "$OUT"
# NVRAM isolated per run: without it, MAME shares its nvram/<jeu>/ directory between all
# runs, all BIOSes alike — a credit left by a run under one BIOS is read back under another
# (measured on 2026-10-16: a probe read a ghost credit left by a previous run).
NV="$(mktemp -d "${TMPDIR:-/tmp}/sonde-nvram.XXXXXX")"
trap 'rm -rf "$NV"' EXIT
# MAME's output goes to a log next to the TSV: on failure, the lua's `SONDE:` messages
# (invalid address, missing variable) are reported instead of being swallowed.
SDL_VIDEODRIVER=dummy SONDE_OUT="$OUT" mame "$JEU" -rompath "$ROMS" \
  -video none -sound none -nothrottle -seconds_to_run "$SECONDES" \
  -nvram_directory "$NV" -cfg_directory "$NV/cfg" \
  -skip_gameinfo -bios "$BIOSFLAG" -autoboot_script "$ICI/sonde.lua" >"$OUT.log" 2>&1 || true
# The header is written as soon as the lua loads: a non-empty file proves nothing. Two lines
# at least — the header and one data line — or it is a failure, which mame's `|| true` must
# not hide.
[ -s "$OUT" ] && [ "$(wc -l < "$OUT")" -ge 2 ] || {
	echo "la sonde n'a rien relevé : $OUT" >&2
	grep '^SONDE:' "$OUT.log" >&2 || true
	exit 3
}
rm -f "$OUT.log"
echo "$OUT : $(wc -l < "$OUT" | tr -d ' ') lignes"
