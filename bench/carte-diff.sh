#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
# CARD differential with a card: the same forced calls (`forcer.lua`) under the SNK BIOS and
# under a romset where our image is substituted, starting from the same cards; compares the
# response and the interface after the call, the call's writes to BIOS RAM (CARD variables only:
# the record also carries the game's vblank interrupt, which differs from one BIOS to the other)
# and the bytes of the card on exit, and the card registers written during the call (addresses).
#
#   bench/carte-diff.sh <roms> <romset-substitué> <dossier-des-cartes> <travail>
#
# <dossier-des-cartes>: formatee.neo (a save of aof, NGH $0044, sub-save 0, made by the
# reference) and vierge.neo (an unformatted card). Neither is under version control.
set -euo pipefail
ROMS=$1; SUBST=$2; CARTES=$3; W=$4
ICI=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$W"

# name|starting card (formatee, vierge, aucune)|entry|interface from $10FDC4
CAS='
charger|formatee|C00468|0200000000107100004000440000
chercher-44|formatee|C00468|0100000000107100004000440000
chercher-66|formatee|C00468|0100000000107100004000660000
sauver-remplace|formatee|C00468|0300000000107100004000440000
sauver-nouvelle|formatee|C00468|0300000000107100004000440200
supprimer|formatee|C00468|0400000000107100004000440000
titre|formatee|C00468|0500000000107100004000440000
nom-sauver|formatee|C00468|0600000000107100004000440000
nom-charger|formatee|C00468|0700000000107100004000440000
formater|formatee|C00468|0000000000107100004000440000
non-formatee|vierge|C00468|0200000000107100004000440000
sans-carte|aucune|C00468|0200000000107100004000440000
erreur-sauver|vierge|C0046E|0300810000107100004000440000
'

passe() { # $1 bios (snk|nous) $2 name $3 card $4 entry $5 interface
  local D="$W/$1-$2" RP="$ROMS" M=()
  [ "$1" = nous ] && RP="$SUBST"
  rm -rf "$D"; mkdir -p "$D/nv"
  if [ "$3" != aucune ]; then cp "$CARTES/$3.neo" "$D/c.neo"; M=(-memc "$D/c.neo"); fi
  ( cd "$D" && A_BRUT=1 A_F=1200 A_FIN=1500 A_ENTREE=$4 A_IFACE=$5 A_REMPLIR=107100:40 A_OUT="$D/o.txt" \
    SDL_MAC_BACKGROUND_APP=1 SDL_VIDEODRIVER=dummy mame aof -bios euro -rompath "$RP" ${M[@]+"${M[@]}"} \
    -video none -sound none -nothrottle -seconds_to_run 30 -nvram_directory "$D/nv" \
    -skip_gameinfo -autoboot_script "$ICI/forcer.lua" > "$D/mame.log" 2>&1 ) || true
}

# The call's writes to BIOS RAM: CARD variables, and the data buffer.
ecritures() { { grep -o 'ram: .*' "$1" || true; } | tr ' ' '\n' \
  | { grep -E '^(10FCF4|10FD0|10FD1|10FDC[4-9A-F]|10FDD[01]|1071)' || true; } | regrouper; }
# forcer.lua outputs the addresses one by one (A_BRUT=1): the filter applies to each write, not
# to the first one of a group. We group afterwards: a write by the game between two variables
# (vblank during a call spanning several frames) thus splits no group.
regrouper() { python3 -c '
import re, sys
g = []
for t in sys.stdin.read().split():
    m = re.match(r"([0-9A-F]+)-([0-9A-F]+)\((\d+)\)", t)
    d, f, c = int(m[1], 16), int(m[2], 16), int(m[3])
    if g and g[-1][0] <= d <= g[-1][1] + 2:
        g[-1] = [g[-1][0], max(f, g[-1][1]), g[-1][2] + c]
    else:
        g.append([d, f, c])
print(" ".join("%06X-%06X(%d)" % tuple(x) for x in g), end=" ")'; }
# The card registers written during the call, addresses only: the data does not count.
registres() { { grep -o 'registres ecrits: .*' "$1" || true; } | tr ' ' '\n' \
  | { grep -E '^(3A000[4-9]|3A001[4-9]|380010)' || true; } | cut -d= -f1 | tr '\n' ' '; }

ok=0; ko=0
while IFS='|' read -r nom carte entree iface; do
  [ -n "$nom" ] || continue
  passe snk "$nom" "$carte" "$entree" "$iface"
  passe nous "$nom" "$carte" "$entree" "$iface"
  a=$(grep -o 'apres: .*' "$W/snk-$nom/o.txt" || echo 'apres: AUCUN RETOUR')
  b=$(grep -o 'apres: .*' "$W/nous-$nom/o.txt" || echo 'apres: AUCUN RETOUR')
  ea=$(ecritures "$W/snk-$nom/o.txt"); eb=$(ecritures "$W/nous-$nom/o.txt")
  ra=$(registres "$W/snk-$nom/o.txt"); rb=$(registres "$W/nous-$nom/o.txt")
  carte_eq=sans-carte
  if [ "$carte" != aucune ]; then
    if cmp -s "$W/snk-$nom/c.neo" "$W/nous-$nom/c.neo"; then carte_eq=egale
    else carte_eq="DIFFERE ($({ cmp -l "$W/snk-$nom/c.neo" "$W/nous-$nom/c.neo" || true; } | wc -l | tr -d ' ') octets)"; fi
  fi
  # A call without a return (MAME crashed, silent jig) fails, even if identical on both sides.
  if [ "$a" = "$b" ] && [ "${a#*AUCUN}" = "$a" ] && [ "$ea" = "$eb" ] && [ "$ra" = "$rb" ] && { [ "$carte_eq" = egale ] || [ "$carte_eq" = sans-carte ]; }; then
    ok=$((ok+1)); printf 'PASS  %-16s %s | carte %s\n' "$nom" "$a" "$carte_eq"
  else
    ko=$((ko+1)); printf 'FAIL  %-16s\n      snk  %s\n      nous %s\n      carte %s\n      ram snk  %s\n      ram nous %s\n      reg snk  %s\n      reg nous %s\n' \
      "$nom" "$a" "$b" "$carte_eq" "$ea" "$eb" "$ra" "$rb"
  fi
done <<< "$CAS"
echo "PASS=$ok FAIL=$ko"
