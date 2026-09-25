#!/usr/bin/env bash
# Uploads build/steam/content/{windows,macos,linux} (from build_steam.sh) to Steam with SteamCMD.
# Writes the SteamPipe scripts to build/steam/scripts/ and runs one app build with three depots.
#
#   STEAM_USER=<build account> tools/steam/upload_steam.sh
#
# SteamCMD asks for the password and the Steam Guard code itself; they never go through this script.
# Environment:
#   STEAM_USER     Steam account with permission to publish builds (required)
#   STEAMCMD       path to steamcmd (default: build/steamcmd/steamcmd.exe on Windows, else "steamcmd")
#   BRANCH         beta branch to set live after upload (optional; the default branch is set live by hand)
#   DESC           build description shown in Steamworks (default: version + commit)
#   APP_ID, DEPOT_WINDOWS, DEPOT_MACOS, DEPOT_LINUX   override the ids below
#   PREVIEW=1      write the scripts and run a preview build (checks files, uploads nothing)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP_ID="${APP_ID:-5328810}"
DEPOT_WINDOWS="${DEPOT_WINDOWS:-5328811}"
DEPOT_MACOS="${DEPOT_MACOS:-5328812}"
DEPOT_LINUX="${DEPOT_LINUX:-5328813}"
S="$ROOT/build/steam"
: "${STEAM_USER:?set STEAM_USER to the Steam account that uploads builds}"
for d in windows macos linux; do [ -d "$S/content/$d" ] || { echo "missing $S/content/$d: run tools/steam/build_steam.sh" >&2; exit 1; }; done
if command -v cygpath >/dev/null 2>&1; then P() { cygpath -m "$1"; }; else P() { echo "$1"; }; fi
if [ -z "${STEAMCMD:-}" ]; then
  if [ -x "$ROOT/build/steamcmd/steamcmd.exe" ]; then STEAMCMD="$ROOT/build/steamcmd/steamcmd.exe"; else STEAMCMD=steamcmd; fi
fi
VERSION="$(tr -d '[:space:]' < "$ROOT/tools/release/VERSION")"
DESC="${DESC:-BLOCKMANIA $VERSION ($(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo local))}"
mkdir -p "$S/scripts" "$S/output"

depot() { # id, folder
  cat > "$S/scripts/depot_$2.vdf" <<EOF
"DepotBuild"
{
	"DepotID" "$1"
	"ContentRoot" "$(P "$S/content/$2")"
	"FileMapping"
	{
		"LocalPath" "*"
		"DepotPath" "."
		"Recursive" "1"
	}
	"FileExclusion" "steam_appid.txt"
	"FileExclusion" "*.pdb"
}
EOF
}
depot "$DEPOT_WINDOWS" windows
depot "$DEPOT_MACOS" macos
depot "$DEPOT_LINUX" linux
{
  echo '"AppBuild"'
  echo '{'
  echo "	\"AppID\" \"$APP_ID\""
  echo "	\"Desc\" \"$DESC\""
  echo "	\"BuildOutput\" \"$(P "$S/output")\""
  [ "${PREVIEW:-0}" = "1" ] && echo '	"Preview" "1"'
  [ -n "${BRANCH:-}" ] && echo "	\"SetLive\" \"$BRANCH\""
  echo '	"Depots"'
  echo '	{'
  echo "		\"$DEPOT_WINDOWS\" \"$(P "$S/scripts/depot_windows.vdf")\""
  echo "		\"$DEPOT_MACOS\" \"$(P "$S/scripts/depot_macos.vdf")\""
  echo "		\"$DEPOT_LINUX\" \"$(P "$S/scripts/depot_linux.vdf")\""
  echo '	}'
  echo '}'
} > "$S/scripts/app_build.vdf"
echo "Uploading \"$DESC\" to app $APP_ID (depots $DEPOT_WINDOWS / $DEPOT_MACOS / $DEPOT_LINUX)"
"$STEAMCMD" +login "$STEAM_USER" +run_app_build "$(P "$S/scripts/app_build.vdf")" +quit
