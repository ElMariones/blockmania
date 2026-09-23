class_name BMEndless
extends RefCounted
## A separate, deterministic arcade ruleset. No shops, bags or targets.

const SCHEMA := 3
const OFFER_IDS := [&"single", &"bar2", &"bar3", &"l3", &"square2", &"bar4", &"l4", &"t4", &"zigzag4", &"plus5", &"bar5", &"rect2x3", &"square3"]
const WEIGHTS := [6, 13, 15, 12, 12, 10, 9, 8, 6, 4, 2, 2, 1]
const COMBO_LADDER := [1, 2, 3, 5, 8, 10]
const CLEAN_BOARD_BONUS := 500

var seed := 0
var rng: BMRngStream
var board := BMBoard.new()
var tray: Array = [{}, {}, {}]
var held: Dictionary = {}
var hold_used := false
var score := 0
var placements := 0
var lines := 0
var combo := 1
var clear_chain := 0
var misses := 0
var best_combo := 1
var perfect_clears := 0
var largest_clear := 0
var coverage_peak := 0
var best_streak := 0
var consecutive_clears := 0
var duration_ms := 0
var time_since_placement_ms := 0
var placement_time_total_ms := 0
var score_samples: Array = [{"p": 0, "score": 0}]
var stats_complete := true
var over := false
var history: Array = []


static func new_game(seed_value: int) -> BMEndless:
	var g := BMEndless.new()
	g.seed = seed_value
	g.rng = BMRngStream.new(seed_value, "endless")
	g._deal()
	return g


func _deal() -> void:
	for i in 3:
		tray[i] = _draw_shape()
	if not _any_tray_fits() and board.empty_count() > 0:
		# A bad random trio must not end an otherwise playable board. Exactly one
		# replacement is selected from legal shapes using the same seeded stream.
		tray[rng.randi_range(0, 2)] = _draw_legal_shape()
	_check_game_over()


func _draw_shape() -> Dictionary:
	var id: StringName = OFFER_IDS[rng.weighted_index(WEIGHTS)]
	var rotations := BMShapes.rotations(id)
	return BMShapes.make_shape(id, rng.randi_range(0, rotations.size() - 1), rng.randi_range(0, BMShapes.OFFER_COLOR_COUNT - 1))


func _draw_legal_shape() -> Dictionary:
	var candidates: Array = []
	var weights: Array = []
	for i in OFFER_IDS.size():
		var id: StringName = OFFER_IDS[i]
		for rot in BMShapes.rotations(id).size():
			var shape := BMShapes.make_shape(id, rot, 0)
			if board.fits_anywhere(shape.cells):
				candidates.append([id, rot])
				weights.append(WEIGHTS[i])
	if candidates.is_empty():
		return {}
	var choice: Array = candidates[rng.weighted_index(weights)]
	return BMShapes.make_shape(choice[0], choice[1], rng.randi_range(0, BMShapes.OFFER_COLOR_COUNT - 1))


func fits(index: int) -> bool:
	return index >= 0 and index < 3 and not tray[index].is_empty() and board.fits_anywhere(tray[index].cells)


func _any_tray_fits() -> bool:
	for i in 3:
		if fits(i):
			return true
	return false


func _check_game_over() -> void:
	# An empty Hold is storage, not an extra offered shape. Only a shape already
	# stored there can rescue a tray with no legal placement.
	var hold_can_rescue := not hold_used and not held.is_empty() and board.fits_anywhere(held.cells)
	over = not _any_tray_fits() and not hold_can_rescue


func apply_action(action: Dictionary) -> Dictionary:
	if over:
		return {"ok": false, "error": "Game over."}
	if action.get("a", "") == "clock":
		_track_time(int(action.get("ms", 0)))
		history.append({"a": "clock", "ms": int(action.get("ms", 0))})
		return {"ok": true, "type": "clock"}
	if action.get("a", "") == "hold":
		var held_result := _hold_piece(int(action.get("i", -1)))
		if held_result.ok:
			_track_time(int(action.get("ms", 0)))
			history[history.size() - 1]["ms"] = maxi(0, int(action.get("ms", 0)))
		return held_result
	if action.get("a", "") != "place":
		return {"ok": false, "error": "Unknown action."}
	var index := int(action.get("i", -1))
	var anchor := Vector2i(int(action.get("x", -1)), int(action.get("y", -1)))
	if index < 0 or index >= 3 or tray[index].is_empty():
		return {"ok": false, "error": "Pick an offered piece."}
	var shape: Dictionary = tray[index]
	if not board.can_place(shape.cells, anchor):
		return {"ok": false, "error": "That piece does not fit."}
	_track_time(int(action.get("ms", 0)))
	var placed := board.place(shape.cells, anchor, int(shape.color))
	coverage_peak = maxi(coverage_peak, board.occupied_count())
	var rows := board.full_rows()
	var cols := board.full_cols()
	var cleared := board.clear_cells(BMBoard.line_union(rows, cols))
	var line_count := rows.size() + cols.size()
	var earned: int = shape.cells.size() * 10
	var clean_board := line_count > 0 and board.empty_count() == 64
	var callouts: Array[String] = []
	if line_count > 0:
		consecutive_clears += 1
		best_streak = maxi(best_streak, consecutive_clears)
		largest_clear = maxi(largest_clear, line_count)
		clear_chain += 1
		combo = COMBO_LADDER[mini(clear_chain - 1, COMBO_LADDER.size() - 1)]
		misses = 0
		best_combo = maxi(best_combo, combo)
		earned += 100 * line_count * combo
		lines += line_count
		if line_count == 2:
			callouts.append("DOUBLE CLEAR")
		elif line_count == 3:
			callouts.append("TRIPLE CLEAR")
		elif line_count >= 4:
			callouts.append("MEGA CLEAR")
		if clean_board:
			perfect_clears += 1
			earned += CLEAN_BOARD_BONUS * combo
			callouts.append("PERFECT")
			callouts.append("CLEAN BOARD")
		if combo == 10 and clear_chain == 6:
			callouts.append("BLOCKSTORM")
	else:
		consecutive_clears = 0
		misses += 1
		if misses >= 3:
			clear_chain = 0
			combo = 1
			misses = 0
	score += earned
	placements += 1
	placement_time_total_ms += time_since_placement_ms
	time_since_placement_ms = 0
	_record_score_sample()
	hold_used = false
	tray[index] = {}
	if tray.all(func(s: Dictionary) -> bool: return s.is_empty()):
		_deal()
	else:
		_check_game_over()
	history.append({"a": "place", "i": index, "x": anchor.x, "y": anchor.y, "ms": maxi(0, int(action.get("ms", 0)))})
	return {"ok": true, "type": "place", "shape": shape, "placed": placed, "rows": rows, "cols": cols,
		"cleared": cleared, "mirror_cleared": [], "points": earned, "score": score,
		"combo": combo, "misses": misses, "clean_board": clean_board,
		"callouts": callouts, "over": over}


func _track_time(ms: int) -> void:
	var amount := maxi(0, ms)
	duration_ms += amount
	time_since_placement_ms += amount


func _record_score_sample() -> void:
	score_samples.append({"p": placements, "score": score})
	if score_samples.size() <= 256:
		return
	var reduced := []
	for i in score_samples.size():
		if i % 2 == 0 or i == score_samples.size() - 1:
			reduced.append(score_samples[i])
	score_samples = reduced


func summary() -> Dictionary:
	return {"score": score, "seed": seed, "lines": lines, "placements": placements,
		"combo": best_combo, "perfect_clears": perfect_clears, "largest_clear": largest_clear,
		"duration_ms": duration_ms, "coverage_peak": roundi(coverage_peak * 100.0 / 64.0),
		"average_placement_ms": roundi(float(placement_time_total_ms) / maxf(1.0, placements)),
		"score_per_placement": float(score) / maxf(1.0, placements), "best_streak": best_streak,
		"score_samples": score_samples.duplicate(true), "stats_complete": stats_complete}


func _hold_piece(index: int) -> Dictionary:
	if hold_used:
		return {"ok": false, "error": "Hold is available again after a placement."}
	if index < 0 or index >= 3 or tray[index].is_empty():
		return {"ok": false, "error": "Select a piece to hold."}
	var outgoing: Dictionary = tray[index]
	var incoming: Dictionary = held
	if incoming.is_empty():
		# Store this shape and replace its slot. Guarantee a playable replacement
		# if the other offered pieces do not fit.
		tray[index] = _draw_shape()
		if not _any_tray_fits() and board.empty_count() > 0:
			tray[index] = _draw_legal_shape()
	else:
		tray[index] = incoming
		if not _any_tray_fits():
			tray[index] = outgoing
			return {"ok": false, "error": "That swap leaves no playable piece."}
	held = outgoing
	hold_used = true
	_check_game_over()
	history.append({"a": "hold", "i": index})
	return {"ok": true, "type": "hold", "stored": outgoing, "drawn": tray[index], "over": over}


func to_dict() -> Dictionary:
	var offers := []
	for shape in tray:
		offers.append({} if shape.is_empty() else {"family": String(shape.family), "rot": shape.rot, "color": shape.color})
	return {"schema": SCHEMA, "seed": seed, "rng": rng.get_state(), "board": board.to_dict(),
		"tray": offers, "held": _shape_to_dict(held), "hold_used": hold_used,
		"score": score, "placements": placements, "lines": lines,
		"combo": combo, "clear_chain": clear_chain, "misses": misses,
		"best_combo": best_combo, "perfect_clears": perfect_clears,
		"largest_clear": largest_clear, "coverage_peak": coverage_peak,
		"best_streak": best_streak, "consecutive_clears": consecutive_clears,
		"duration_ms": duration_ms, "time_since_placement_ms": time_since_placement_ms,
		"placement_time_total_ms": placement_time_total_ms, "score_samples": score_samples.duplicate(true),
		"stats_complete": stats_complete, "over": over, "history": history.duplicate(true)}


static func from_dict(d: Dictionary) -> BMEndless:
	if int(d.get("schema", 0)) < 1 or int(d.get("schema", 0)) > SCHEMA:
		return null
	var g := BMEndless.new()
	g.seed = int(d.seed)
	g.rng = BMRngStream.new()
	g.rng.set_state(d.rng)
	g.board = BMBoard.from_dict(d.board)
	g.tray = []
	for s in d.tray:
		g.tray.append(_shape_from_dict(s))
	g.held = _shape_from_dict(d.get("held", {}))
	g.hold_used = bool(d.get("hold_used", false))
	g.score = int(d.score)
	g.placements = int(d.placements)
	g.lines = int(d.lines)
	g.combo = int(d.combo)
	g.clear_chain = int(d.clear_chain)
	if int(d.get("schema", 0)) == 1:
		g.combo = COMBO_LADDER[mini(maxi(g.clear_chain - 1, 0), COMBO_LADDER.size() - 1)]
	g.misses = int(d.misses)
	g.best_combo = int(d.best_combo)
	if int(d.get("schema", 0)) == 1:
		g.best_combo = mini(g.best_combo, COMBO_LADDER.back())
	g.perfect_clears = int(d.get("perfect_clears", 0))
	g.largest_clear = int(d.get("largest_clear", 0))
	g.coverage_peak = int(d.get("coverage_peak", g.board.occupied_count()))
	g.best_streak = int(d.get("best_streak", 0))
	g.consecutive_clears = int(d.get("consecutive_clears", 0))
	g.duration_ms = int(d.get("duration_ms", 0))
	g.time_since_placement_ms = int(d.get("time_since_placement_ms", 0))
	g.placement_time_total_ms = int(d.get("placement_time_total_ms", 0))
	g.score_samples = d.get("score_samples", []).duplicate(true)
	g.stats_complete = bool(d.get("stats_complete", int(d.get("schema", 0)) >= 3))
	g.over = bool(d.over)
	g.history = d.get("history", []).duplicate(true)
	if not g.over:
		# Repair older saves made while an empty Hold incorrectly prevented loss.
		g._check_game_over()
	return g


static func _shape_to_dict(shape: Dictionary) -> Dictionary:
	return {} if shape.is_empty() else {"family": String(shape.family), "rot": shape.rot, "color": shape.color}


static func _shape_from_dict(d: Dictionary) -> Dictionary:
	return {} if d.is_empty() else BMShapes.make_shape(StringName(d.family), int(d.rot), int(d.color))
