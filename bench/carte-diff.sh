#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
# Différentiel de CARD avec carte : les mêmes appels provoqués (`forcer.lua`) sous le BIOS SNK et
# sous un romset où notre image est substituée, au départ des mêmes cartes ; compare la réponse et
# l'interface après l'appel, les écritures en RAM BIOS de l'appel (variables de CARD seules : le
# relevé porte aussi l'interruption vblank du jeu, qui diffère d'un BIOS à l'autre) et les octets
# de la carte à la sortie, et les registres de la carte écrits pendant l'appel (adresses).
#
#   bench/carte-diff.sh <roms> <romset-substitué> <dossier-des-cartes> <travail>
#
# <dossier-des-cartes> : formatee.neo (une sauvegarde d'aof, NGH $0044, sous-sauvegarde 0, faite
# par la référence) et vierge.neo (une carte non formatée). Aucune n'est versionnée.
set -euo pipefail
ROMS=$1; SUBST=$2; CARTES=$3; W=$4
ICI=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$W"

# nom|carte de départ (formatee, vierge, aucune)|entrée|interface à partir de $10FDC4
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

passe() { # $1 bios (snk|nous) $2 nom $3 carte $4 entrée $5 interface
  local D="$W/$1-$2" RP="$ROMS" M=()
  [ "$1" = nous ] && RP="$SUBST"
  rm -rf "$D"; mkdir -p "$D/nv"
  if [ "$3" != aucune ]; then cp "$CARTES/$3.neo" "$D/c.neo"; M=(-memc "$D/c.neo"); fi
  ( cd "$D" && A_BRUT=1 A_F=1200 A_FIN=1500 A_ENTREE=$4 A_IFACE=$5 A_REMPLIR=107100:40 A_OUT="$D/o.txt" \
    SDL_MAC_BACKGROUND_APP=1 SDL_VIDEODRIVER=dummy mame aof -bios euro -rompath "$RP" ${M[@]+"${M[@]}"} \
    -video none -sound none -nothrottle -seconds_to_run 30 -nvram_directory "$D/nv" \
    -skip_gameinfo -autoboot_script "$ICI/forcer.lua" > "$D/mame.log" 2>&1 ) || true
}

# Les écritures de l'appel en RAM BIOS : variables de CARD, et le tampon des données.
ecritures() { { grep -o 'ram: .*' "$1" || true; } | tr ' ' '\n' \
  | { grep -E '^(10FCF4|10FD0|10FD1|10FDC[4-9A-F]|10FDD[01]|1071)' || true; } | regrouper; }
# forcer.lua sort les adresses une par une (A_BRUT=1) : le filtre porte sur chaque écriture, pas
# sur la première d'un groupe. On regroupe ensuite : une écriture du jeu entre deux variables
# (vblank pendant un appel de plusieurs trames) ne coupe ainsi aucun groupe.
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
# Les registres de la carte écrits pendant l'appel, adresses seules : la donnée ne compte pas.
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
  # Un appel sans retour (MAME planté, jig muet) échoue, même identique des deux côtés.
  if [ "$a" = "$b" ] && [ "${a#*AUCUN}" = "$a" ] && [ "$ea" = "$eb" ] && [ "$ra" = "$rb" ] && { [ "$carte_eq" = egale ] || [ "$carte_eq" = sans-carte ]; }; then
    ok=$((ok+1)); printf 'PASS  %-16s %s | carte %s\n' "$nom" "$a" "$carte_eq"
  else
    ko=$((ko+1)); printf 'FAIL  %-16s\n      snk  %s\n      nous %s\n      carte %s\n      ram snk  %s\n      ram nous %s\n      reg snk  %s\n      reg nous %s\n' \
      "$nom" "$a" "$b" "$carte_eq" "$ea" "$eb" "$ra" "$rb"
  fi
done <<< "$CAS"
echo "PASS=$ok FAIL=$ko"
