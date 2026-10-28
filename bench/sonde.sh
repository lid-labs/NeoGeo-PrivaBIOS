#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
# Lance la sonde lua (sonde.lua) sur un jeu, sans fenêtre.
#
#   bench/sonde.sh <dossier-roms> <jeu> <sortie.tsv> [bios]
#
#   <dossier-roms>  là où MAME trouvera <jeu>.zip. POUR MESURER NOTRE BIOS, pointer un
#                   dossier de variante fabriqué par matrice.sh (ex. <travail>/v-sprixe),
#                   dont les zips portent l'image substituée : ce script NE substitue PAS.
#   [bios]          le drapeau -bios de MAME : euro (défaut — le sp-s2.sp1 du zip, ou
#                   l'image substituée d'une variante), unibios40, ...
#
# Réglages par l'environnement, passés à sonde.lua :
#   SONDE_RAM   adresses lues en octet à chaque trame (hex, virgules) — ex. le drapeau que
#               scrute une boucle de gel, trouvé au co-simulateur (non publié)
#   SONDE_DE / SONDE_A   fenêtre de trames (défaut 0..3500)
#
# La durée MAME est bornée d'après SONDE_A (trames NTSC ~59,19 Hz), plus une marge.
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
# NVRAM isolée par run : sans cela, MAME partage son dossier nvram/<jeu>/ entre tous les
# runs, BIOS confondus — un crédit laissé par un run sous un BIOS se relit sous un autre
# (mesuré le 2026-10-16 : une sonde a lu un crédit fantôme laissé par un run précédent).
NV="$(mktemp -d "${TMPDIR:-/tmp}/sonde-nvram.XXXXXX")"
trap 'rm -rf "$NV"' EXIT
# La sortie de MAME part dans un journal à côté du TSV : en cas d'échec, les messages
# `SONDE:` du lua (adresse invalide, variable manquante) sont remontés au lieu d'être avalés.
SDL_VIDEODRIVER=dummy SONDE_OUT="$OUT" mame "$JEU" -rompath "$ROMS" \
  -video none -sound none -nothrottle -seconds_to_run "$SECONDES" \
  -nvram_directory "$NV" -cfg_directory "$NV/cfg" \
  -skip_gameinfo -bios "$BIOSFLAG" -autoboot_script "$ICI/sonde.lua" >"$OUT.log" 2>&1 || true
# L'en-tête part dès le chargement du lua : un fichier non vide ne prouve rien. Deux lignes
# au moins — l'en-tête et une donnée — ou c'est un échec, que le `|| true` de mame ne doit
# pas masquer.
[ -s "$OUT" ] && [ "$(wc -l < "$OUT")" -ge 2 ] || {
	echo "la sonde n'a rien relevé : $OUT" >&2
	grep '^SONDE:' "$OUT.log" >&2 || true
	exit 3
}
rm -f "$OUT.log"
echo "$OUT : $(wc -l < "$OUT" | tr -d ' ') lignes"
