#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Local preview of the site: assembles site/ and docs/screenshots/ the way the Pages workflow does
# (.github/workflows/pages.yml), in .site-preview/ (ignored by git), then serves it.
#
#   site/serve.sh [port]        (default port 8000)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

out=.site-preview
rm -rf "$out"
mkdir -p "$out/img"
cp -R site/. "$out/"
rm -f "$out/serve.sh"
cp docs/screenshots/* "$out/img/"

echo "http://localhost:${1:-8000}/"
cd "$out"
exec python3 -m http.server "${1:-8000}" --bind 127.0.0.1
