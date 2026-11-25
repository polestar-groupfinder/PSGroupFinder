#!/usr/bin/env bash
# Builds the installable zip: Polestar_GroupFinder/ at the zip's root.
set -euo pipefail
cd "$(dirname "$0")"
out=../polestar-groupfinder-release
mkdir -p "$out"
rm -f "$out/Polestar_GroupFinder.zip"
zip -qr "$out/Polestar_GroupFinder.zip" Polestar_GroupFinder -x '*.DS_Store'
echo "$out/Polestar_GroupFinder.zip"
