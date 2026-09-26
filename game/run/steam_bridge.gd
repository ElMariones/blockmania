class_name BMSteam
extends RefCounted
## Optional Steam achievements. Six Steam achievements mirror local ones (BMAchievements ids), so a
## local unlock also sets the Steam one. Needs the GodotSteam GDExtension (addons/godotsteam); without
## it, or when Steam is not running, every call is a no-op and the game plays exactly the same.
## The Steamworks-side kit (names, descriptions, icons, localization) is store/steam/achievements/,
## built by tools/store/build_achievements.py; keep API names in sync with ACH there.
##
## Never reports from a sandboxed profile (E2E, tools/shoot.py) or a --script tool, so tests cannot
## unlock achievements on a real Steam account. `-- --no-steam` turns it off for a local smoke test.

const APP_ID := 5328810
## Local achievement id -> Steamworks API name. Never rename an API name once published.
const MAP := {
	"crossroads": "ACH_CROSSROADS",
	"boss_buster": "ACH_BOSS_BUSTER",
	"legend_found": "ACH_LEGEND_FOUND",
	"arcade_regular": "ACH_ARCADE_REGULAR",
	"champion": "ACH_BLOCKMANIA",
	"broke_machine": "ACH_BROKE_THE_MACHINE",
}


static var _steam: Object = null
static var _tried := false


## Starts Steam once and pushes local unlocks Steam has not seen yet (players who earned them before
## Steam, or offline). Safe to call when GodotSteam is missing.
static func start() -> void:
	if _tried:
		return
	_tried = true
	if not Engine.has_singleton("Steam") or not _allowed():
		return
	var steam: Object = Engine.get_singleton("Steam")
	var res: Variant = steam.call("steamInitEx", APP_ID)
	if typeof(res) != TYPE_DICTIONARY or int(res.get("status", -1)) != 0:
		push_warning("Steam not initialized: %s" % str(res))
		return
	_steam = steam
	var ids: Array = []
	for id: String in MAP:
		if BMAchievementStore.is_unlocked(id):
			ids.append(id)
	report(ids)


## Sets the Steam achievements for any mapped local ids (already-set ones are harmless).
static func report(local_ids: Array) -> void:
	if _steam == null or not _allowed():
		return
	var changed := false
	for id: Variant in local_ids:
		var api: String = MAP.get(String(id), "")
		if api != "" and _steam.call("setAchievement", api):
			changed = true
	if changed:
		_steam.call("storeStats")


## Pumps Steam callbacks; call every frame.
static func tick() -> void:
	if _steam != null:
		_steam.call("run_callbacks")


static func active() -> bool:
	return _steam != null


## The language the player chose for BLOCKMANIA in Steam (Properties > General > Language), or
## Steam's own UI language when they never chose one, as a Steam API code ("latam",
## "schinese"...). "" without Steam. BMLoc maps it to a UI language.
static func game_language() -> String:
	if _steam == null:
		return ""
	return String(_steam.call("getCurrentGameLanguage"))


static func _allowed() -> bool:
	if BMAchievementStore.path != BMAchievementStore.PATH:
		return false
	return not OS.get_cmdline_args().has("--script") and not OS.get_cmdline_user_args().has("--no-steam")
