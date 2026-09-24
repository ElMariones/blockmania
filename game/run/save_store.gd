class_name BMSaveStore
extends RefCounted
## Local persistence. Run state and settings are separate files. Runs are saved only between
## complete actions (BMRun.to_dict), written to a temp file then renamed so a crash cannot
## leave a half-written save. A save with an unknown future schema is ignored, not deleted.

const RUN_PATH := "user://run.json"
const SETTINGS_PATH := "user://settings.cfg"
static var settings_path := SETTINGS_PATH ## The E2E suite redirects this.

static var run_path := RUN_PATH ## Tests redirect this.
## Lifetime Kit-unlock counters live in their own file (tests redirect this too).
static var profile_path := "user://profile.cfg"


static func has_run() -> bool:
	return load_run() != null


static func save_run(run: BMRun) -> bool:
	var data := {"schema": BMRun.SCHEMA_VERSION, "run": run.to_dict()}
	var tmp := run_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	if FileAccess.file_exists(run_path):
		DirAccess.remove_absolute(run_path)
	return DirAccess.rename_absolute(tmp, run_path) == OK


static func load_run() -> BMRun:
	if not FileAccess.file_exists(run_path):
		return null
	var text := FileAccess.get_file_as_string(run_path)
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary) or not data.has("run"):
		push_warning("Run save is unreadable; ignoring it.")
		return null
	if int(data.get("schema", 0)) > BMRun.SCHEMA_VERSION:
		push_warning("Run save is from a newer version; ignoring it.")
		return null
	# Migrations go here. Schema 1 (pre-Bag prototype, random tray draws) has no bag or piece
	# identities, so it cannot be converted faithfully; those prototype saves are ignored.
	if int(data.get("schema", 0)) < 2:
		push_warning("Run save predates the Bag (schema 1); it cannot be resumed.")
		return null
	# Schema 6 -> 7 (GDD §22): run `heat`, `daily`, `round_card`, `locked_jokers`; round `held`,
	# `hold_used`, `locked_slot2`, `last_family`; shop `round_cards` / `round_pick`. All load
	# with defaults (Heat 0, nothing locked, Standard round, empty Hold).
	# Schema 5 -> 6 (engine update): `joker_state` ({}), `extra_slots` (0) and the round's
	# `pending_xmult` (1), `lines_cleared` (0) and `refresh_used` (false) load with defaults.
	# Schema 4 -> 5 (Overtime): `overtime`, `machine_broken` and `recorded` load with defaults
	# (false, false, {}), and bosses for acts beyond the third are drawn when first needed.
	# Schema 3 -> 4 (round-play update): new fields (tray `hand`/`brick` marks, patch, feats,
	# Patience, Warden lock, tombs, combo misses, loan debt, shop crate) all load with defaults.
	# Schema 2 -> 3: rounds gained `placement_cap` (line clears refill placements up to it).
	# RoundState.from_dict defaults it to the placements left, so an in-progress round resumes
	# with refills capped at its current count.
	var run := BMRun.from_dict(data.run)
	if run.phase in [BMRun.Phase.RUN_WON, BMRun.Phase.RUN_LOST, BMRun.Phase.ABANDONED]:
		return null
	return run


static func clear_run() -> void:
	if FileAccess.file_exists(run_path):
		DirAccess.remove_absolute(run_path)


## Every setting and its default (Settings menu pages, GDD §22.10).
static func default_settings() -> Dictionary:
	return {"reduced_motion": false, "block_patterns": false, "crt": "soft",
		"endless_skin": "classic", "endless_skins_unlocked": [],
		# Game: animation speed (campaign only), contextual tips, boss cinematic.
		"game_speed": "normal", "tips": true, "tips_seen": [], "boss_intro": "cinematic",
		# Kit screen: the Heat picked last time.
		"last_heat": 0,
		# Audio: volumes are 0..1; "muted" silences everything, "music_on" only the soundtrack.
		"master_volume": 0.8, "music_volume": 0.6, "sfx_volume": 0.8,
		"muted": false, "music_on": true, "mute_unfocused": false, "heartbeat": true,
		# Display: window mode, V-Sync, edge effects (boss frame, danger, heat) and the FPS counter.
		"fullscreen": false, "vsync": true, "screen_fx": "full", "show_fps": false,
		# Accessibility: shake and flash strength.
		"shake": "full", "flashes": "full"}


static func load_settings() -> Dictionary:
	var s := default_settings()
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		for k in s:
			s[k] = cfg.get_value("settings", k, s[k])
	return s


static func save_settings(s: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for k in s:
		cfg.set_value("settings", k, s[k])
	cfg.save(settings_path)



## Lifetime counters for Kit unlocks (meta progression; separate from runs and settings).
## Keys: lines, wins, bosses, hands, runs; heat_won (highest Heat won, -1 = none);
## daily_date / daily_round / daily_won (the latest Daily played and its best result).
static func load_profile() -> Dictionary:
	var p := {"lines": 0, "wins": 0, "bosses": 0, "hands": 0, "runs": 0, "heat_won": -1,
		"daily_date": "", "daily_round": 0, "daily_won": 0}
	var cfg := ConfigFile.new()
	if cfg.load(profile_path) == OK:
		for k in p:
			p[k] = cfg.get_value("profile", k, p[k])
			if not (p[k] is String):
				p[k] = int(p[k])
	return p


## Highest Heat the player may pick for a new run (one above the highest won).
static func heat_available() -> int:
	return clampi(int(load_profile().heat_won) + 1, 0, BMRunConfig.MAX_HEAT)


## Adds a finished run's statistics to the profile. Returns the Kit ids it unlocked.
## A run can end twice (won at round 12, then lost in Overtime): `run.recorded` remembers what
## was already added, so only the difference counts and the run and its win count once.
static func record_run(run: BMRun) -> Array[String]:
	var before := load_profile()
	var after := before.duplicate()
	var done := run.recorded
	var now := {"lines": int(run.stats.get("lines_cleared", 0)), "bosses": int(run.stats.get("bosses_beaten", 0)),
		"hands": int(run.stats.get("hands", 0))}
	for k in now:
		after[k] += maxi(0, now[k] - int(done.get(k, 0)))
	if not done.has("run"):
		after.runs += 1
	var won := run.phase == BMRun.Phase.RUN_WON or run.overtime
	if won and run.kit_id == "standard" and not done.has("won"):
		after.wins += 1
		now["won"] = 1
	elif done.has("won"):
		now["won"] = 1
	now["run"] = 1
	if won:
		after.heat_won = maxi(int(after.heat_won), run.heat)
	if run.daily != "":
		if String(after.daily_date) != run.daily:
			after.daily_date = run.daily
			after.daily_round = 0
			after.daily_won = 0
		after.daily_round = maxi(int(after.daily_round), run.round_number)
		after.daily_won = maxi(int(after.daily_won), 1 if won else 0)
	run.recorded = now
	var cfg := ConfigFile.new()
	for k in after:
		cfg.set_value("profile", k, after[k])
	cfg.save(profile_path)
	var unlocked: Array[String] = []
	for k in BMRunConfig.KITS:
		if not BMRunConfig.kit_unlocked(k.id, before) and BMRunConfig.kit_unlocked(k.id, after):
			unlocked.append(String(k.id))
	return unlocked


# --- Run history (GDD §22.7) -----------------------------------------------------------------

const HISTORY_PATH := "user://history.json"
const HISTORY_MAX := 40
static var history_path := HISTORY_PATH ## Tests redirect this.


## Past runs, newest first: [{time, seed, kit, heat, daily, won, round, overtime, broken,
## best, total, jokers, reason}].
static func load_history() -> Array:
	if not FileAccess.file_exists(history_path):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(history_path))
	return data if data is Array else []


## Records (or updates, for a won run that ends again in Overtime) the run's summary.
static func append_history(run: BMRun) -> void:
	var list := load_history()
	var entry := {"time": int(Time.get_unix_time_from_system()), "seed": run.run_seed, "kit": run.kit_id,
		"heat": run.heat, "daily": run.daily, "won": run.phase == BMRun.Phase.RUN_WON or run.overtime,
		"round": run.round_number, "overtime": run.overtime, "broken": run.machine_broken,
		"best": int(run.stats.get("best_placement", 0)), "total": int(run.stats.get("total_points", 0)),
		"jokers": run.jokers.duplicate(), "reason": run.end_reason}
	if not list.is_empty() and int(list[0].get("seed", -1)) == run.run_seed and String(list[0].get("kit", "")) == run.kit_id \
			and int(list[0].get("heat", 0)) == run.heat and bool(list[0].get("won", false)):
		entry.time = int(list[0].get("time", entry.time))
		list[0] = entry
	else:
		list.push_front(entry)
	while list.size() > HISTORY_MAX:
		list.pop_back()
	var f := FileAccess.open(history_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(list))
		f.close()
