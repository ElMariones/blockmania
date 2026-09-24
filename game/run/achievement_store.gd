class_name BMAchievementStore
extends RefCounted
## Local achievements, lifetime collections and personal records (GDD §20). One ConfigFile,
## separate from runs, settings and the Kit profile. Nothing here feeds back into the rules.
##
## Sections: [unlocked] id = unix time, [seen] id = true (the Trophy Case has shown it),
## [life] hands_seen / endless_best / legends_seen, [records] furthest_round / best_placement /
## best_round_score / machine_broken (round, 0 = never).

const PATH := "user://achievements.cfg"

static var path := PATH ## Tests redirect this.
static var _cache: Dictionary = {}


static func _blank() -> Dictionary:
	return {"unlocked": {}, "seen": {}, "life": {"hands_seen": [], "endless_best": 0, "legends_seen": []},
		"records": {"furthest_round": 0, "best_placement": 0, "best_round_score": 0, "machine_broken": 0}}


static func data() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	_cache = _blank()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return _cache
	for section in ["unlocked", "seen"]:
		if cfg.has_section(section):
			for k in cfg.get_section_keys(section):
				_cache[section][k] = cfg.get_value(section, k)
	for section in ["life", "records"]:
		for k in _cache[section]:
			_cache[section][k] = cfg.get_value(section, k, _cache[section][k])
	return _cache


static func save() -> void:
	var d := data()
	var cfg := ConfigFile.new()
	for section in ["unlocked", "seen", "life", "records"]:
		for k in d[section]:
			cfg.set_value(section, k, d[section][k])
	cfg.save(path)


## Forget the cache (tests, or after `path` changes).
static func reload() -> void:
	_cache = {}


static func is_unlocked(id: String) -> bool:
	return data().unlocked.has(id)


static func unlocked_count() -> int:
	return data().unlocked.size()


static func unlock_time(id: String) -> int:
	return int(data().unlocked.get(id, 0))


static func life() -> Dictionary:
	return data().life


static func records() -> Dictionary:
	return data().records


## Unlocks every id not yet unlocked (plus the meta badge when due). Returns the new ids in
## catalog order. Saves only when something changed.
static func unlock(candidates: Array) -> Array[String]:
	var d := data()
	var fresh: Array[String] = []
	for id in BMAchievements.ids():
		if candidates.has(id) and not d.unlocked.has(id):
			d.unlocked[id] = int(Time.get_unix_time_from_system())
			fresh.append(id)
	if not fresh.is_empty():
		for id in BMAchievements.check_meta(d.unlocked):
			if not d.unlocked.has(id):
				d.unlocked[id] = int(Time.get_unix_time_from_system())
				fresh.append(id)
		save()
	return fresh


## Lifetime collections a campaign action adds to (Tray Hands seen). Call before checking.
static func note_campaign(run: BMRun) -> void:
	var seen: Array = data().life.hands_seen
	var changed := false
	for p in run.tray:
		var h := String(p.get("hand", "")) if not p.is_empty() else ""
		if h != "" and not seen.has(h):
			seen.append(h)
			changed = true
	# Legendary Jokers owned in any run (Pantheon).
	var legends: Array = data().life.legends_seen
	for id in run.jokers:
		if BMJokers.is_legendary(id) and not legends.has(id):
			legends.append(id)
			changed = true
	if changed:
		save()


static func note_endless(game: BMEndless) -> void:
	var l: Dictionary = data().life
	if game.score > int(l.endless_best):
		l.endless_best = game.score
		save()


## Personal records from a run that just ended. Returns the records it beat, in display order,
## as [{key, label, value, before}]. A run that ends twice (won, then lost in Overtime) can
## improve its own earlier records.
static func record_run(run: BMRun) -> Array:
	var rec: Dictionary = data().records
	var values := {
		"furthest_round": run.round_number,
		"best_placement": int(run.stats.get("best_placement", 0)),
		"best_round_score": int(run.stats.get("best_round_score", 0)),
		"machine_broken": run.round_number if run.machine_broken else 0,
	}
	var beaten: Array = []
	for k in BMAchievements.RECORD_KEYS:
		var v := int(values[k])
		var before := int(rec.get(k, 0))
		# Breaking the machine sooner is the better record.
		var better := v > before if k != "machine_broken" else (v > 0 and (before == 0 or v < before))
		if better:
			rec[k] = v
			beaten.append({"key": k, "label": record_label(k), "value": v, "before": before})
	if not beaten.is_empty():
		save()
	return beaten


static func record_label(key: String) -> String:
	return {"furthest_round": "Furthest round", "best_placement": "Best placement",
		"best_round_score": "Best round score", "machine_broken": "Machine broken in round"}.get(key, key)


## Trophy Case "NEW!" tags: unlocked but not yet shown there.
static func is_new(id: String) -> bool:
	var d := data()
	return d.unlocked.has(id) and not d.seen.has(id)


static func mark_seen(page_ids: Array) -> void:
	var d := data()
	var changed := false
	for id in page_ids:
		if d.unlocked.has(id) and not d.seen.has(id):
			d.seen[id] = true
			changed = true
	if changed:
		save()
