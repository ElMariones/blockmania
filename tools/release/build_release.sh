#!/usr/bin/env bash
# Builds the downloadable BLOCKMANIA builds (Windows, macOS, Linux) into build/release/:
#   BLOCKMANIA-Windows.zip  BLOCKMANIA-macOS.zip  BLOCKMANIA-Linux.zip
# Needs the Godot 4.7.2 editor (GODOT, default "godot") and its export templates in
# ~/.local/share/godot/export_templates/4.7.2.stable/ (install_templates.sh fetches them).
# Used locally and by .github/workflows/release.yml.
set -euo pipefail
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/build/release"
cd "$ROOT"
rm -rf "$OUT" && mkdir -p "$OUT/windows" "$OUT/linux"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows Desktop" "$OUT/windows/BLOCKMANIA.exe"
"$GODOT" --headless --path . --export-release "macOS" "$OUT/BLOCKMANIA-macOS.zip"
"$GODOT" --headless --path . --export-release "Linux" "$OUT/linux/BLOCKMANIA.x86_64"
for f in "$OUT/windows/BLOCKMANIA.exe" "$OUT/BLOCKMANIA-macOS.zip" "$OUT/linux/BLOCKMANIA.x86_64"; do
  [ -s "$f" ] || { echo "export failed: $f" >&2; exit 1; }
done
cp "$ROOT/tools/release/PLAY_ME.txt" "$OUT/windows/"
cp "$ROOT/tools/release/PLAY_ME.txt" "$OUT/linux/"
chmod +x "$OUT/linux/BLOCKMANIA.x86_64"
(cd "$OUT/windows" && zip -q -9 -r ../BLOCKMANIA-Windows.zip .)
(cd "$OUT/linux" && zip -q -9 -r ../BLOCKMANIA-Linux.zip .)
ls -la "$OUT"/*.zip
