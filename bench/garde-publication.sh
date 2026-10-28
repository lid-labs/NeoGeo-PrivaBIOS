#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
# Garde de publication : échoue si un fichier suivi porte une donnée privée.
#
# Cinq familles, cherchées dans les fichiers suivis par git (git grep, binaires exclus) :
#   1. un chemin de machine (répertoires personnels, dossiers temporaires de macOS, bureau) ;
#   2. une adresse e-mail autre que les adresses noreply de GitHub et d'Anthropic. LICENSE et
#      CODE_OF_CONDUCT.md sont exclus : l'adresse de contact du code de conduite est voulue ;
#   3. un lien Google Drive ou Google Docs ;
#   4. un numéro de ticket de l'ancien dépôt privé (« # » suivi de quatre chiffres), dans src/,
#      bench/ et build/ seulement : docs/ et measured/ les citent comme références datées. En
#      assembleur, seul le commentaire (après « | ») est lu, car « #3000-1 » y est un opérande
#      immédiat ; ailleurs (shell, Python, Lua, script d'édition de liens), toute la ligne ;
#   5. un fichier de ROM ou d'image suivi (.rom, .sp1, .zip, .bin).
#
# Ce script est exclu de sa propre recherche : il porte les motifs qu'il cherche.
#
#   bench/garde-publication.sh        (depuis n'importe où dans le dépôt)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

moi=bench/garde-publication.sh
echecs=0

signaler() { # signaler <famille> <lignes>
    [ -z "$2" ] && return 0
    printf '== %s\n%s\n' "$1" "$2"
    echecs=$((echecs + 1))
}

# git grep et grep sortent en 1 quand rien ne correspond : seul ce code vaut « rien à signaler ».
# Toute autre erreur (128 : motif invalide, dépôt illisible) fait échouer l'assignation, donc le
# script sous set -e. D'où des assignations, et des filtres appliqués à part : passée en argument
# de fonction, ou suivie d'un grep -v dans le même pipeline, l'erreur serait avalée.
rien() { [ "$1" -eq 1 ] || exit "$1"; }

# 1. Chemins de machine.
chemins=$(git grep -nIE '/Users/|/home/|~/sprixe|/private/tmp|Desktop/' \
    -- . ":!$moi" || rien $?)
signaler "chemin de machine" "$chemins"

# 2. Adresses e-mail.
adresses=$(git grep -nIoE '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}' \
    -- . ":!$moi" ':!LICENSE' ':!CODE_OF_CONDUCT.md' || rien $?)
adresses=$(printf '%s\n' "$adresses" \
    | grep -vE ':[^:]*@users\.noreply\.github\.com$|:noreply@anthropic\.com$|^$' || rien $?)
signaler "adresse e-mail" "$adresses"

# 3. Liens Google Drive.
liens=$(git grep -nIE 'drive\.google\.com|docs\.google\.com' -- . ":!$moi" || rien $?)
signaler "lien Google Drive" "$liens"

# 4. Numéros de tickets privés. Le « [^0-9] » final écarte un nombre plus long.
ticket='#[0-9]{4}([^0-9]|$)'
asm=$(git grep -nIE "[|].*$ticket" -- 'src/*.s' 'bench/*.s' 'build/*.s' || rien $?)
autres=$(git grep -nIE "$ticket" -- src bench build ':!*.s' ":!$moi" || rien $?)
signaler "numéro de ticket privé" "$(printf '%s\n%s' "$asm" "$autres" | sed '/^$/d')"

# 5. Fichiers de ROM ou d'image suivis. -z : sans lui, git cite entre guillemets et en octal un
# nom non ASCII (« "\303\251.zip" »), et l'extension n'est plus en fin de ligne.
fichiers=$(git ls-files -z | tr '\0' '\n')
roms=$(printf '%s\n' "$fichiers" | grep -iE '\.(rom|sp1|zip|bin)$' || rien $?)
signaler "fichier de ROM suivi" "$roms"

if [ "$echecs" -gt 0 ]; then
    echo "garde de publication : $echecs famille(s) en défaut" >&2
    exit 1
fi
echo "garde de publication : rien à signaler"
