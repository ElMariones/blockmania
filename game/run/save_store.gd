class_name BMSaveStore
extends RefCounted
## Local persistence. Run state and settings are separate files. Runs are saved only between
## complete actions (BMRun.to_dict), written to a temp file then renamed so a crash cannot
## leave a half-written save. A save with an unknown future schema is ignored, not deleted.

const RUN_PATH := "user://run.json"
const SETTINGS_PATH := "user://settings.cfg"

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


static func load_settings() -> Dictionary:
	var s := {"reduced_motion": false, "block_patterns": false, "fast_animations": false, "crt": "soft",
		"endless_skin": "classic", "endless_skins_unlocked": [],
		# Audio: volumes are 0..1; "muted" silences everything, "music_on" only the soundtrack.
		"master_volume": 0.8, "music_volume": 0.6, "sfx_volume": 0.8,
		"muted": false, "music_on": true, "mute_unfocused": false}
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for k in s:
			s[k] = cfg.get_value("settings", k, s[k])
	return s


static func save_settings(s: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for k in s:
		cfg.set_value("settings", k, s[k])
	cfg.save(SETTINGS_PATH)



## Lifetime counters for Kit unlocks (meta progression; separate from runs and settings).
## Keys: lines, wins, bosses, hands, runs.
static func load_profile() -> Dictionary:
	var p := {"lines": 0, "wins": 0, "bosses": 0, "hands": 0, "runs": 0}
	var cfg := ConfigFile.new()
	if cfg.load(profile_path) == OK:
		for k in p:
			p[k] = int(cfg.get_value("profile", k, p[k]))
	return p


## Adds a finished run's statistics to the profile. Returns the Kit ids it unlocked.
static func record_run(run: BMRun) -> Array[String]:
	var before := load_profile()
	var after := before.duplicate()
	after.lines += int(run.stats.get("lines_cleared", 0))
	after.bosses += int(run.stats.get("bosses_beaten", 0))
	after.hands += int(run.stats.get("hands", 0))
	after.runs += 1
	if run.phase == BMRun.Phase.RUN_WON and run.kit_id == "standard":
		after.wins += 1
	var cfg := ConfigFile.new()
	for k in after:
		cfg.set_value("profile", k, after[k])
	cfg.save(profile_path)
	var unlocked: Array[String] = []
	for k in BMRunConfig.KITS:
		if not BMRunConfig.kit_unlocked(k.id, before) and BMRunConfig.kit_unlocked(k.id, after):
			unlocked.append(String(k.id))
	return unlocked
