#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
# Publication guard: fails if a tracked file carries private data.
#
# Five families, searched in the files tracked by git (git grep, binaries excluded):
#   1. a machine path (home directories, macOS temporary directories, desktop);
#   2. an e-mail address other than the GitHub and Anthropic noreply addresses. LICENSE and
#      CODE_OF_CONDUCT.md are excluded: the contact address of the code of conduct is intended;
#   3. a Google Drive or Google Docs link;
#   4. a ticket number from the former private repository ("#" followed by four digits), in src/,
#      bench/ and build/ only: docs/ and measured/ cite them as dated references. In assembly,
#      only the comment (after "|") is read, because "#3000-1" is an immediate operand there;
#      elsewhere (shell, Python, Lua, linker script), the whole line;
#   5. a tracked ROM or image file (.rom, .sp1, .zip, .bin).
#
# This script is excluded from its own search: it carries the patterns it looks for.
#
#   bench/garde-publication.sh        (from anywhere in the repository)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

moi=bench/garde-publication.sh
echecs=0

signaler() { # signaler <family> <lines>
    [ -z "$2" ] && return 0
    printf '== %s\n%s\n' "$1" "$2"
    echecs=$((echecs + 1))
}

# git grep and grep exit with 1 when nothing matches: only that code means "nothing to report".
# Any other error (128: invalid pattern, unreadable repository) makes the assignment fail, hence
# the script under set -e. Hence assignments, and filters applied separately: passed as a function
# argument, or followed by a grep -v in the same pipeline, the error would be swallowed.
rien() { [ "$1" -eq 1 ] || exit "$1"; }

# 1. Machine paths.
chemins=$(git grep -nIE '/Users/|/home/|~/sprixe|/private/tmp|Desktop/' \
    -- . ":!$moi" || rien $?)
signaler "chemin de machine" "$chemins"

# 2. E-mail addresses.
adresses=$(git grep -nIoE '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}' \
    -- . ":!$moi" ':!LICENSE' ':!CODE_OF_CONDUCT.md' || rien $?)
adresses=$(printf '%s\n' "$adresses" \
    | grep -vE ':[^:]*@users\.noreply\.github\.com$|:noreply@anthropic\.com$|^$' || rien $?)
signaler "adresse e-mail" "$adresses"

# 3. Google Drive links.
liens=$(git grep -nIE 'drive\.google\.com|docs\.google\.com' -- . ":!$moi" || rien $?)
signaler "lien Google Drive" "$liens"

# 4. Private ticket numbers. The final "[^0-9]" rules out a longer number.
ticket='#[0-9]{4}([^0-9]|$)'
asm=$(git grep -nIE "[|].*$ticket" -- 'src/*.s' 'bench/*.s' 'build/*.s' || rien $?)
autres=$(git grep -nIE "$ticket" -- src bench build ':!*.s' ":!$moi" || rien $?)
signaler "numéro de ticket privé" "$(printf '%s\n%s' "$asm" "$autres" | sed '/^$/d')"

# 5. Tracked ROM or image files. -z: without it, git quotes a non-ASCII name in double quotes and
# octal ("\303\251.zip"), and the extension is no longer at the end of the line.
fichiers=$(git ls-files -z | tr '\0' '\n')
roms=$(printf '%s\n' "$fichiers" | grep -iE '\.(rom|sp1|zip|bin)$' || rien $?)
signaler "fichier de ROM suivi" "$roms"

if [ "$echecs" -gt 0 ]; then
    echo "garde de publication : $echecs famille(s) en défaut" >&2
    exit 1
fi
echo "garde de publication : rien à signaler"
