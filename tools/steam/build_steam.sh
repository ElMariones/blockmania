#!/usr/bin/env bash
# Exports the Steam builds into one folder per depot:
#   build/steam/content/windows/  BLOCKMANIA.exe + GodotSteam + steam_api64.dll
#   build/steam/content/macos/    BLOCKMANIA.app (universal: Intel + Apple Silicon)
#   build/steam/content/linux/    BLOCKMANIA.x86_64 + GodotSteam + libsteam_api.so
# Needs Godot 4.7.2 (GODOT, default "godot"), its export templates (tools/release/install_templates.sh)
# and GodotSteam (installed here if missing). Run it on Linux or macOS for a real upload: only a Unix
# filesystem keeps the executable bit the macOS and Linux builds need (the GitHub workflow does this).
set -euo pipefail
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/build/steam/content"
cd "$ROOT"
bash "$ROOT/tools/release/install_godotsteam.sh"
rm -rf "$OUT" && mkdir -p "$OUT/windows" "$OUT/macos" "$OUT/linux"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows Desktop" "$OUT/windows/BLOCKMANIA.exe"
"$GODOT" --headless --path . --export-release "Linux" "$OUT/linux/BLOCKMANIA.x86_64"
"$GODOT" --headless --path . --export-release "macOS" "$ROOT/build/steam/BLOCKMANIA-macOS.zip"
(cd "$OUT/macos" && unzip -q "$ROOT/build/steam/BLOCKMANIA-macOS.zip")
rm -f "$ROOT/build/steam/BLOCKMANIA-macOS.zip"
chmod +x "$OUT/linux/BLOCKMANIA.x86_64" "$OUT/macos/BLOCKMANIA.app/Contents/MacOS/"* 2>/dev/null || true
# Never ship steam_appid.txt: Steam provides the app id at launch.
find "$OUT" -name steam_appid.txt -delete
for f in "$OUT/windows/BLOCKMANIA.exe" "$OUT/windows/steam_api64.dll" "$OUT/linux/BLOCKMANIA.x86_64" \
         "$OUT/linux/libsteam_api.so" "$OUT/macos/BLOCKMANIA.app/Contents/Info.plist"; do
  [ -s "$f" ] || { echo "missing in Steam build: $f" >&2; exit 1; }
done
# Every UI language must be in the depot: the exported game reports the translations and CJK fonts it
# carries (store/steam/LANGUAGES.md). The Linux build runs headless here; on Windows, the .exe.
case "$(uname -s)" in
  Linux) REPORT_BIN="$OUT/linux/BLOCKMANIA.x86_64" ;;
  MINGW*|MSYS*|CYGWIN*) REPORT_BIN="$OUT/windows/BLOCKMANIA.exe" ;;
  *) REPORT_BIN="" ;;
esac
if [ -n "$REPORT_BIN" ]; then
  REPORT="$("$REPORT_BIN" --headless --audio-driver Dummy -- --lang-report --no-splash --no-steam 2>&1 | grep LANG_REPORT || true)"
  echo "$REPORT"
  case "$REPORT" in
    *"missing=none cjk_fonts=3/3"*) ;;
    *) echo "Steam build is missing a language or a CJK font: $REPORT" >&2; exit 1 ;;
  esac
else
  echo "language check skipped on this OS (run it on Linux or Windows)" >&2
fi
du -sh "$OUT"/*
