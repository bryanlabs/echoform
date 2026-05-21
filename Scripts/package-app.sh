#!/bin/bash
# Assembles and code-signs Echoform.app from a release build of the Echoform
# executable. Output: dist/Echoform.app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="release"
SIGN_ID="Apple Development: manager@bryanlabs.net (KSC678R53W)"
APP="$ROOT/dist/Echoform.app"

echo "==> Building Echoform ($CONFIG)"
swift build -c "$CONFIG" --product Echoform

BIN_DIR="$(swift build -c "$CONFIG" --product Echoform --show-bin-path)"
BIN="$BIN_DIR/Echoform"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Echoform"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [ -f "$ROOT/Resources/Echoform.icns" ]; then
	cp "$ROOT/Resources/Echoform.icns" "$APP/Contents/Resources/Echoform.icns"
fi

echo "==> Signing with: $SIGN_ID"
codesign --force --sign "$SIGN_ID" --timestamp=none "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Done: $APP"
