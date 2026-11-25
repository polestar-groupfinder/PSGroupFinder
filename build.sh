#!/usr/bin/env bash
# Builds the installable zip: PSGroupFinder/ at the zip's root, versioned.
set -euo pipefail
cd "$(dirname "$0")"
ver=$(awk '/^## Version:/{print $3; exit}' PSGroupFinder/PSGroupFinder.toc)
out=../polestar-groupfinder-release
mkdir -p "$out"
zipname="PSGroupFinder-${ver}.zip"
# Prefer the current unpublished release folder when it exists.
dest="$out"
if [[ -d "$out/v${ver}" ]]; then
  dest="$out/v${ver}"
elif [[ -d "$out/v${ver%.*}" ]]; then
  # toc 1.0.0 lives in the unpublished v1.0 folder
  dest="$out/v${ver%.*}"
fi
mkdir -p "$dest"
rm -f "$dest/$zipname"
if command -v zip >/dev/null; then
  zip -qr "$dest/$zipname" PSGroupFinder -x '*.DS_Store'
else
  python3 - "$dest/$zipname" <<'PY'
import zipfile, sys
from pathlib import Path
out, root = Path(sys.argv[1]), Path("PSGroupFinder")
with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED) as z:
    for p in sorted(root.rglob("*")):
        if p.name == ".DS_Store" or not p.is_file():
            continue
        z.write(p, (Path("PSGroupFinder") / p.relative_to(root)).as_posix())
PY
fi
if [[ -f INSTALLATION.md ]]; then
  cp -f INSTALLATION.md "$dest/INSTALLATION.md"
  cp -f INSTALLATION.md "$out/INSTALLATION.md"
fi
echo "$dest/$zipname"
