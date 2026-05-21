#!/bin/bash
# Builds and signs Echoform.app, installs it to /Applications, and installs
# the `echoform` command-line launcher into ~/bin.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DEST="/Applications/Echoform.app"
SHIM="$HOME/bin/echoform"

"$ROOT/Scripts/package-app.sh"

echo "==> Installing to $APP_DEST"
rm -rf "$APP_DEST"
ditto "$ROOT/dist/Echoform.app" "$APP_DEST"

echo "==> Installing launcher to $SHIM"
mkdir -p "$(dirname "$SHIM")"
cat > "$SHIM" <<'EOF'
#!/bin/sh
# Echoform launcher. Pass --demo to preview the visuals without live audio.
if [ "$#" -eq 0 ]; then
	exec open -a Echoform
else
	exec open -a Echoform --args "$@"
fi
EOF
chmod +x "$SHIM"

echo ""
echo "Installed."
echo "  Launch:  echoform          (or open Echoform from /Applications)"
echo "  Preview: echoform --demo"
