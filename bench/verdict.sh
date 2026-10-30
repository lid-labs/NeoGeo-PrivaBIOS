#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
# Verdict of a record: "plays" or "frozen from frame N".
#
# The criterion requires the picture signature to stop changing for AT LEAST 500 frames up to the
# end of the record. A single still interval is not enough: a title screen, a pause or a fade
# produce one too. A first version settled for the last change and declared League Bowling
# "frozen 2,200 frames" while its timer went from 06 to 00 before our eyes.
#
# This verdict is NOT enough on its own: a picture that changes can stay black. Cross it with
# vifs (lit pixels) — see docs/COMPATIBILITE.md, "What the verdict does not say".
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
