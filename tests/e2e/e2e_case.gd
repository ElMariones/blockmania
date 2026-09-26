class_name BME2ECase
extends Node
## Base class for end-to-end scenarios (tests/e2e/scenario_*.gd). A scenario drives the real
## app root (`BMMain` from main.tscn) through the same entry points the UI uses, checks
## invariants as it goes, and records checkpoints. The runner writes everything to a JSON
## artifact (build/e2e/<scenario>.json) whose `fingerprint` depends only on the seeded
## gameplay, so two runs of the same build produce the same fingerprint.

var main: Node
var failures: Array[String] = []
var checkpoints: Array = []
var shots: Array[String] = []
var artifact_dir := ""
## Deterministic facts that make up the fingerprint (no timings, no dates).
var facts := {}


func run() -> void:
	pass


func check(cond: bool, msg: String) -> bool:
	if not cond:
		failures.append(msg)
	return cond


func eq(a: Variant, b: Variant, msg: String) -> bool:
	return check(a == b, "%s: expected %s, got %s" % [msg, str(b), str(a)])


func checkpoint(label: String, data: Dictionary = {}) -> void:
	var entry := {"label": label}
	entry.merge(data)
	checkpoints.append(entry)


func frames(n: int = 2) -> void:
	for i in n:
		await get_tree().process_frame


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Stable digest of a campaign run: every saved field (including the action history) except
## bookkeeping that only the app sets (profile recording).
static func run_digest(r: BMRun) -> String:
	var d := r.to_dict(true)
	d.erase("recorded")
	d.erase("custom_seed") # how the seed was chosen, not game state (replays cannot know it)
	return JSON.stringify(d, "", true).sha256_text()


static func dict_digest(d: Dictionary) -> String:
	return JSON.stringify(d, "", true).sha256_text()


## Every bag piece is in exactly one of: draw pile, discard pile, tray, Hold (GDD §16, §22.1).
static func bag_accounted(r: BMRun) -> bool:
	var seen := {}
	for uid in r.draw_pile + r.discard_pile:
		seen[int(uid)] = int(seen.get(int(uid), 0)) + 1
	var extra: Array = r.tray.duplicate()
	extra.append(r.round_state.held)
	for p in extra:
		if not p.is_empty() and int(p.get("uid", -1)) >= 0:
			seen[int(p.uid)] = int(seen.get(int(p.uid), 0)) + 1
	for p in r.bag:
		if int(seen.get(int(p.uid), 0)) != 1:
			return false
	return true


## True when the player has a legal placement: an open slot whose piece fits, or a stored piece
## that fits and can be swapped in now.
static func has_legal_move(r: BMRun) -> bool:
	for i in r.tray.size():
		if r.slot_fits(i):
			return true
	var held: Dictionary = r.round_state.held
	return not held.is_empty() and not r.round_state.hold_used and not r.hold_blocked() and r.board.fits_anywhere(held.cells)


## Saves a PNG of the current frame when a real display is present (skipped headless).
func screenshot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := artifact_dir.path_join(name + ".png")
	img.save_png(path)
	shots.append(path.get_file())


## The bot's next action for a campaign run, decided on a copy so the real run is only ever
## changed through the UI. {} when the bot has nothing to do (run over).
static func bot_action(r: BMRun) -> Dictionary:
	var copy := BMRun.from_dict(r.to_dict(true))
	var n := copy.history.size()
	var res := BMAutoplayer.step(copy)
	if res.is_empty() or copy.history.size() <= n:
		return {}
	return copy.history[n]
