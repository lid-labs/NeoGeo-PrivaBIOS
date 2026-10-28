#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
# Verdict d'un relevé : « joue » ou « figé dès la trame N ».
#
# Le critère exige que la signature d'image ne change plus pendant AU MOINS 500 trames jusqu'à la
# fin du relevé. Un seul intervalle immobile ne suffit pas : un écran-titre, une pose ou un fondu
# en produisent aussi. Une première version se contentait du dernier changement et a déclaré
# League Bowling « figé 2 200 trames » alors que sa minuterie passait de 06 à 00 sous les yeux.
#
# Ce verdict ne suffit PAS à lui seul : une image qui change peut rester noire. Croiser avec
# vifs (pixels allumés) — voir docs/COMPATIBILITE.md, « Ce que le verdict ne dit pas ».
#
#   verdict.sh <index.txt>
set -u
awk '{
  for (i = 1; i <= NF; i++) {
    if ($i ~ /^frame=/) f = substr($i, 7)
    if ($i ~ /^somme=/) s = substr($i, 7)
  }
  n++; fr[n] = f; so[n] = s
} END {
  if (n == 0) { printf "aucun relevé"; exit }
  gel = 1
  for (i = n; i > 1; i--) if (so[i] != so[i-1]) { gel = i; break }
  duree = fr[n] - fr[gel]
  if (duree >= 500) printf "FIGE dès %s (%s trames)", fr[gel], duree
  else printf "joue (plus longue pose %s tr.)", duree
}' "$1"
