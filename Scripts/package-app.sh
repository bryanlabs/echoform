#!/bin/bash
# Assembles and code-signs Echoform.app from a release build of the Echoform
# executable. Output: dist/Echoform.app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="release"
APP="$ROOT/dist/Echoform.app"

# Code-signing identity. Defaults to the first available Apple Development
# identity so a rebuild keeps the same Screen Recording grant; falls back to
# ad-hoc signing, which works on any machine. Override with SIGN_ID=...
if [ -z "${SIGN_ID:-}" ]; then
	SIGN_ID="$(security find-identity -v -p codesigning 2>/dev/null \
		| sed -n 's/.*"\(Apple Development[^"]*\)".*/\1/p' | head -n 1)"
	[ -z "$SIGN_ID" ] && SIGN_ID="-"
fi

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

if [ "$SIGN_ID" = "-" ]; then
	echo "==> Signing ad-hoc (build it yourself to trust it)"
else
	echo "==> Signing with: $SIGN_ID"
fi
codesign --force --sign "$SIGN_ID" --timestamp=none "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Done: $APP"
