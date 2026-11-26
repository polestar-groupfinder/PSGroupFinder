#!/usr/bin/env bash
# Builds the installable zip: PSGroupFinder/ at the zip's root, versioned,
# in dist/ (or in the folder given as the first argument).
set -euo pipefail
cd "$(dirname "$0")"
ver=$(awk '/^## Version:/{print $3; exit}' PSGroupFinder/PSGroupFinder.toc)
dest=${1:-dist}
mkdir -p "$dest"
zip="$dest/PSGroupFinder-${ver}.zip"
rm -f "$zip"
python3 - "$zip" <<'PY'
import sys, zipfile
from pathlib import Path
out, root = Path(sys.argv[1]), Path("PSGroupFinder")
with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED) as z:
    for p in sorted(root.rglob("*")):
        if p.is_file() and p.name != ".DS_Store":
            z.write(p, p.as_posix())
PY
echo "$zip"
