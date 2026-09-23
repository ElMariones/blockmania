class_name BMEndless
extends RefCounted
## A separate, deterministic arcade ruleset. No shops, bags, targets or rescue draws.

const SCHEMA := 1
const OFFER_IDS := [&"single", &"bar2", &"bar3", &"l3", &"square2", &"bar4", &"l4", &"t4", &"zigzag4", &"plus5", &"bar5", &"square3"]
const WEIGHTS := [5, 13, 17, 13, 14, 11, 9, 8, 6, 3, 1, 0]

var seed := 0
var rng: BMRngStream
var board := BMBoard.new()
var tray: Array = [{}, {}, {}]
var score := 0
var placements := 0
var lines := 0
var combo := 1
var clear_chain := 0
var misses := 0
var best_combo := 1
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
	_check_game_over()


func _draw_shape() -> Dictionary:
	var total := 0
	for w in WEIGHTS:
		total += w
	var roll := rng.randi_range(0, total - 1)
	var id: StringName = OFFER_IDS[0]
	for i in OFFER_IDS.size():
		roll -= WEIGHTS[i]
		if roll < 0:
			id = OFFER_IDS[i]
			break
	var rotations := BMShapes.rotations(id)
	return BMShapes.make_shape(id, rng.randi_range(0, rotations.size() - 1), rng.randi_range(0, BMShapes.OFFER_COLOR_COUNT - 1))


func fits(index: int) -> bool:
	return index >= 0 and index < 3 and not tray[index].is_empty() and board.fits_anywhere(tray[index].cells)


func _check_game_over() -> void:
	for i in 3:
		if fits(i):
			return
	over = true


func apply_action(action: Dictionary) -> Dictionary:
	if over:
		return {"ok": false, "error": "Game over."}
	if action.get("a", "") != "place":
		return {"ok": false, "error": "Unknown action."}
	var index := int(action.get("i", -1))
	var anchor := Vector2i(int(action.get("x", -1)), int(action.get("y", -1)))
	if index < 0 or index >= 3 or tray[index].is_empty():
		return {"ok": false, "error": "Pick an offered piece."}
	var shape: Dictionary = tray[index]
	if not board.can_place(shape.cells, anchor):
		return {"ok": false, "error": "That piece does not fit."}
	var placed := board.place(shape.cells, anchor, int(shape.color))
	var rows := board.full_rows()
	var cols := board.full_cols()
	var cleared := board.clear_cells(BMBoard.line_union(rows, cols))
	var line_count := rows.size() + cols.size()
	var earned: int = shape.cells.size() * 10
	if line_count > 0:
		clear_chain += 1
		combo = maxi(1, clear_chain)
		misses = 0
		best_combo = maxi(best_combo, combo)
		earned += 100 * line_count * combo
		lines += line_count
	else:
		misses += 1
		if misses >= 2:
			clear_chain = 0
			combo = 1
			misses = 0
	score += earned
	placements += 1
	tray[index] = {}
	if tray.all(func(s: Dictionary) -> bool: return s.is_empty()):
		_deal()
	else:
		_check_game_over()
	history.append({"a": "place", "i": index, "x": anchor.x, "y": anchor.y})
	return {"ok": true, "type": "place", "shape": shape, "placed": placed, "rows": rows, "cols": cols,
		"cleared": cleared, "mirror_cleared": [], "points": earned, "score": score,
		"combo": combo, "misses": misses, "over": over}


func to_dict() -> Dictionary:
	var offers := []
	for shape in tray:
		offers.append({} if shape.is_empty() else {"family": String(shape.family), "rot": shape.rot, "color": shape.color})
	return {"schema": SCHEMA, "seed": seed, "rng": rng.get_state(), "board": board.to_dict(),
		"tray": offers, "score": score, "placements": placements, "lines": lines,
		"combo": combo, "clear_chain": clear_chain, "misses": misses,
		"best_combo": best_combo, "over": over, "history": history.duplicate(true)}


static func from_dict(d: Dictionary) -> BMEndless:
	if int(d.get("schema", 0)) != SCHEMA:
		return null
	var g := BMEndless.new()
	g.seed = int(d.seed)
	g.rng = BMRngStream.new()
	g.rng.set_state(d.rng)
	g.board = BMBoard.from_dict(d.board)
	g.tray = []
	for s in d.tray:
		g.tray.append({} if s.is_empty() else BMShapes.make_shape(StringName(s.family), int(s.rot), int(s.color)))
	g.score = int(d.score)
	g.placements = int(d.placements)
	g.lines = int(d.lines)
	g.combo = int(d.combo)
	g.clear_chain = int(d.clear_chain)
	g.misses = int(d.misses)
	g.best_combo = int(d.best_combo)
	g.over = bool(d.over)
	g.history = d.get("history", []).duplicate(true)
	return g
