#!/usr/bin/env bash
# Downloads and installs the official Godot 4.7.2 export templates (about 1 GB, once).
set -euo pipefail
DEST="$HOME/.local/share/godot/export_templates/4.7.2.stable"
[ -f "$DEST/version.txt" ] && { echo "templates already installed"; exit 0; }
TMP="$(mktemp -d)"
[ -n "${TEMPLATES_TPZ:-}" ] && cp "$TEMPLATES_TPZ" "$TMP/t.tpz" || curl -sSL -o "$TMP/t.tpz" https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz
mkdir -p "$DEST"
# Only what the three desktop presets need.
unzip -q "$TMP/t.tpz" -d "$TMP" templates/version.txt templates/windows_release_x86_64.exe \
  templates/windows_debug_x86_64.exe templates/macos.zip templates/linux_release.x86_64 templates/linux_debug.x86_64
mv "$TMP"/templates/* "$DEST"/
rm -rf "$TMP"
echo "installed templates to $DEST"
