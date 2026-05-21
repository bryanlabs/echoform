#!/bin/bash
# Renders the master icon and builds Resources/Echoform.icns.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Rendering master icon"
swift Scripts/IconGen.swift

SRC="$ROOT/Resources/icon-1024.png"
ICONSET="$ROOT/dist/Echoform.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

resize() { sips -z "$1" "$1" "$SRC" --out "$ICONSET/$2" >/dev/null; }
resize 16  icon_16x16.png
resize 32  icon_16x16@2x.png
resize 32  icon_32x32.png
resize 64  icon_32x32@2x.png
resize 128 icon_128x128.png
resize 256 icon_128x128@2x.png
resize 256 icon_256x256.png
resize 512 icon_256x256@2x.png
resize 512 icon_512x512.png
cp "$SRC" "$ICONSET/icon_512x512@2x.png"

echo "==> Building icns"
iconutil -c icns "$ICONSET" -o "$ROOT/Resources/Echoform.icns"
rm -rf "$ICONSET"
echo "==> Wrote Resources/Echoform.icns"
