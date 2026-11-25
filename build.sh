#!/usr/bin/env bash
# Builds the installable zip: PSGroupFinder/ at the zip's root, versioned.
set -euo pipefail
cd "$(dirname "$0")"
ver=$(awk '/^## Version:/{print $3; exit}' PSGroupFinder/PSGroupFinder.toc)
out=../polestar-groupfinder-release
mkdir -p "$out"
zipname="PSGroupFinder-${ver}.zip"
# Do not delete older zips (0.1, 0.2, previous 1.x). Only replace this version.
rm -f "$out/$zipname"
zip -qr "$out/$zipname" PSGroupFinder -x '*.DS_Store'
if [[ -f INSTALLATION.md ]]; then cp -f INSTALLATION.md "$out/INSTALLATION.md"; fi
echo "$out/$zipname"
