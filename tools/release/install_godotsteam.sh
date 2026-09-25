#!/usr/bin/env bash
# Installs the GodotSteam GDExtension (MIT, https://godotsteam.com) into addons/godotsteam/: only the
# desktop libraries BLOCKMANIA ships (Windows x86_64, Linux x86_64, macOS universal) and the Steamworks
# redistributables, with a manifest trimmed to them. The folder is git-ignored; run this once per checkout
# (build_release.sh runs it when missing). Without it the game runs fine and BMSteam is a no-op.
set -euo pipefail
VERSION="4.22.1"
URL="https://codeberg.org/godotsteam/godotsteam/releases/download/v${VERSION}-gde/godotsteam-${VERSION}-gdextension-plugin-4.4.zip"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEST="$ROOT/addons/godotsteam"
[ -f "$DEST/VERSION" ] && [ "$(cat "$DEST/VERSION")" = "$VERSION" ] && { echo "GodotSteam $VERSION already installed"; exit 0; }
TMP="$(mktemp -d)"
ZIP="${GODOTSTEAM_ZIP:-}"
[ -n "$ZIP" ] || { ZIP="$TMP/gs.zip"; curl -sSL -o "$ZIP" "$URL"; }
unzip -q "$ZIP" -d "$TMP" "addons/godotsteam/win64/*" "addons/godotsteam/linux64/*" "addons/godotsteam/osx/*" "addons/godotsteam/license.md"
rm -rf "$DEST" && mkdir -p "$DEST"
mv "$TMP/addons/godotsteam/"* "$DEST/"
cat > "$DEST/godotsteam.gdextension" <<'EOF'
[configuration]
entry_symbol = "godotsteam_init"
compatibility_minimum = "4.4"

[libraries]
linux.debug.x86_64 = "res://addons/godotsteam/linux64/libgodotsteam.linux.template_debug.x86_64.so"
linux.release.x86_64 = "res://addons/godotsteam/linux64/libgodotsteam.linux.template_release.x86_64.so"
macos.debug = "res://addons/godotsteam/osx/libgodotsteam.macos.template_debug.universal.dylib"
macos.release = "res://addons/godotsteam/osx/libgodotsteam.macos.template_release.universal.dylib"
windows.debug.x86_64 = "res://addons/godotsteam/win64/libgodotsteam.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://addons/godotsteam/win64/libgodotsteam.windows.template_release.x86_64.dll"

[dependencies]
linux.x86_64 = { "res://addons/godotsteam/linux64/libsteam_api.so": "" }
macos.universal = { "res://addons/godotsteam/osx/libsteam_api.dylib": "" }
windows.x86_64 = { "res://addons/godotsteam/win64/steam_api64.dll": "" }
EOF
echo "$VERSION" > "$DEST/VERSION"
rm -rf "$TMP"
echo "installed GodotSteam $VERSION to $DEST"
