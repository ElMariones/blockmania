class_name BMAutoplayer
extends RefCounted
## Deterministic bot for determinism tests, balance simulation, and content experiments.
## Not a player-facing feature and not a model of a skilled human: it is a consistent,
## reasonably competent baseline so content can be compared on paired seeds.
##
## Placement: heuristic prefilter (lines, compactness, isolated holes, dead ends), then the
## top candidates are scored with the real resolver preview plus a one-step lookahead that
## values setting up multi-line clears with the other tray pieces (so multi-line and combo
## cards get a fair test). Shop policy is configurable:
##   "none"   never buys
##   "jokers" buys Jokers only
##   "full"   Jokers, then Workshop tools (with sensible targets), pieces, and items

var shop_policy := "full"
## Items the bot knows how to use (it cannot aim board tools, paint, or Blueprints).
const BOT_ITEMS := ["polish", "spark", "second_tray", "extra_turn", "cash_out", "emergency_brick", "overclock", "coffee_break", "coin_roll"]
var top_k := 6
## Weight of the best follow-up clear (lines^2) available to the remaining tray pieces.
## Weight for "potential": rows/columns that are nearly full after the placement (sets up
## multi-line clears and combos the way a human builds toward them).
var potential_weight := float(OS.get_environment("BM_POTENTIAL")) if OS.get_environment("BM_POTENTIAL") != "" else 0.0
var lookahead_weight := float(OS.get_environment("BM_LOOKAHEAD")) if OS.get_environment("BM_LOOKAHEAD") != "" else 300.0
## Per-Joker telemetry: id -> {placements: seen while owned, triggers: placements it scored}.
var joker_stats := {}
## Workshop/piece purchases by id.
var purchases := {}

static var _default := BMAutoplayer.new()


# --- Static convenience API (tests) ----------------------------------------------------------

static func step(run: BMRun) -> Dictionary:
	return _default.act(run)


static func play(run: BMRun, max_actions: int = 5000) -> BMRun:
	return _default.play_run(run, max_actions)


# --- Instance API ----------------------------------------------------------------------------

func play_run(run: BMRun, max_actions: int = 5000) -> BMRun:
	for i in max_actions:
		var r := act(run)
		if r.is_empty():
			break
		if not r.ok:
			push_error("Autoplayer action failed: %s" % r.error)
			break
	return run


func act(run: BMRun) -> Dictionary:
	match run.phase:
		BMRun.Phase.ROUND:
			return _round_step(run)
		BMRun.Phase.ROUND_RESULT:
			return run.continue_after_round()
		BMRun.Phase.SHOP:
			return _shop_step(run)
	return {}


func _round_step(run: BMRun) -> Dictionary:
	var rs := run.round_state
	if rs.status == BMRun.OUT_OF_PLACEMENTS:
		var i := run.consumables.find("extra_turn")
		return run.use_consumable(i) if i >= 0 else run.concede_round()
	if rs.status == BMRun.STUCK:
		if run.refreshes_available() > 0:
			return run.refresh()
		var cb := run.consumables.find("coffee_break")
		if cb >= 0 and run.consumable_usable(cb) == "":
			return run.use_consumable(cb)
		var st := run.consumables.find("second_tray")
		if st >= 0 and run.consumable_usable(st) == "":
			return run.use_consumable(st)
		var bk := run.consumables.find("emergency_brick")
		if bk >= 0 and run.board.empty_count() > 0:
			return run.use_consumable(bk, {"slot": 0})
		return run.concede_round()
	# A stored piece that fits while nothing in the tray does: swap it in.
	var any_tray := false
	for i in run.tray.size():
		if run.slot_fits(i):
			any_tray = true
	if not any_tray and not rs.held.is_empty() and not rs.hold_used and run.board.fits_anywhere(rs.held.cells):
		for i in run.tray.size():
			if not run.slot_locked(i):
				return run.hold(i)
	for instant in ["cash_out", "coin_roll"]:
		var ci := run.consumables.find(instant)
		if ci >= 0:
			return run.use_consumable(ci)
	var best := choose_placement(run)
	if best.is_empty():
		return run.refresh() if run.refreshes_available() > 0 else run.concede_round()
	# Dead end ahead and a Refresh in hand: take a fresh tray instead.
	if best.dead_end and run.refreshes_available() > 0 and rs.placements_made > 0:
		return run.refresh()
	# Save Polish/Spark for a clearing placement.
	if best.lines > 0:
		for i in run.consumables.size():
			if run.consumables[i] in ["polish", "spark", "overclock"] and run.consumable_usable(i) == "":
				return run.use_consumable(i)
	var r := run.place(best.slot, best.anchor)
	if r.ok:
		_record_jokers(run, r)
	return r


## Returns {slot, anchor, lines, dead_end, value} or {} when nothing fits.
func choose_placement(run: BMRun) -> Dictionary:
	var candidates: Array = []
	for slot in run.tray.size():
		var piece: Dictionary = run.tray[slot]
		if piece.is_empty() or run.slot_locked(slot):
			continue
		for anchor in run.board.legal_anchors(piece.cells):
			candidates.append(_heuristic(run, slot, anchor))
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.h > b.h)
	var best := {}
	var best_value := -INF
	for i in mini(top_k, candidates.size()):
		var c: Dictionary = candidates[i]
		var p := run.preview_place(c.slot, c.anchor)
		var points: int = p.points if p.ok else 0
		# Points now, plus board health so the bot survives long enough to score, plus the
		# best clear the remaining tray could make next (rewards multi-line setups).
		var follow := _best_followup_lines(run, c.slot, c.anchor)
		var value: float = points + c.quality + lookahead_weight * follow * follow
		if value > best_value:
			best_value = value
			best = c
	return best


func _heuristic(run: BMRun, slot: int, anchor: Vector2i) -> Dictionary:
	var piece: Dictionary = run.tray[slot]
	var b := run.board.duplicate_board()
	var placed := b.place(piece.cells, anchor, 0)
	var lines := b.full_rows().size() + b.full_cols().size()
	var touch := 0
	for p in placed:
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q: Vector2i = p + d
			if not BMBoard.in_bounds(q):
				touch += 1
			elif run.board.get_cell(q) != BMBoard.EMPTY:
				touch += 2
	b.clear_cells(BMBoard.line_union(b.full_rows(), b.full_cols()))
	var holes := _isolated_holes(b)
	var dead_end := true
	for i in run.tray.size():
		if i != slot and not run.tray[i].is_empty() and b.fits_anywhere(run.tray[i].cells):
			dead_end = false
	if dead_end:
		# The tray empties after this placement, so a new tray will be dealt: only a board with
		# almost no room is a real dead end.
		var others := 0
		for i in run.tray.size():
			if i != slot and not run.tray[i].is_empty():
				others += 1
		dead_end = others > 0 or b.empty_count() < 6
	var quality := touch * 6.0 - holes * 45.0 - (800.0 if dead_end else 0.0) + b.empty_count() * 2.0
	if potential_weight > 0.0:
		quality += potential_weight * _line_potential(b)
	return {"slot": slot, "anchor": anchor, "lines": lines, "dead_end": dead_end,
		"quality": quality, "h": lines * 400.0 + quality + placed.size() * 5.0}


## Most lines another tray piece could complete right after this placement (and its clears).
static func _best_followup_lines(run: BMRun, slot: int, anchor: Vector2i) -> int:
	var b := run.board.duplicate_board()
	b.place(run.tray[slot].cells, anchor, 0)
	b.clear_cells(BMBoard.line_union(b.full_rows(), b.full_cols()))
	var row_empty := PackedInt32Array()
	var col_empty := PackedInt32Array()
	row_empty.resize(BMBoard.SIZE)
	col_empty.resize(BMBoard.SIZE)
	for y in BMBoard.SIZE:
		for x in BMBoard.SIZE:
			if b.get_cell(Vector2i(x, y)) == BMBoard.EMPTY:
				row_empty[y] += 1
				col_empty[x] += 1
	var best := 0
	for i in run.tray.size():
		if i == slot or run.tray[i].is_empty():
			continue
		var cells: Array[Vector2i] = run.tray[i].cells
		for a in b.legal_anchors(cells):
			var in_row := {}
			var in_col := {}
			for c in cells:
				var q: Vector2i = c + a
				in_row[q.y] = int(in_row.get(q.y, 0)) + 1
				in_col[q.x] = int(in_col.get(q.x, 0)) + 1
			var lines := 0
			for y in in_row:
				if in_row[y] == row_empty[y]:
					lines += 1
			for x in in_col:
				if in_col[x] == col_empty[x]:
					lines += 1
			best = maxi(best, lines)
	return best


## Sum over rows and columns with 5-7 filled cells of (filled - 4)^2.
static func _line_potential(b: BMBoard) -> float:
	var total := 0.0
	for i in BMBoard.SIZE:
		var r := 0
		var c := 0
		for j in BMBoard.SIZE:
			if b.get_cell(Vector2i(j, i)) != BMBoard.EMPTY:
				r += 1
			if b.get_cell(Vector2i(i, j)) != BMBoard.EMPTY:
				c += 1
		if r >= 5 and r < 8:
			total += (r - 4) * (r - 4)
		if c >= 5 and c < 8:
			total += (c - 4) * (c - 4)
	return total


static func _isolated_holes(b: BMBoard) -> int:
	var n := 0
	for y in BMBoard.SIZE:
		for x in BMBoard.SIZE:
			var p := Vector2i(x, y)
			if b.get_cell(p) != BMBoard.EMPTY:
				continue
			var open := false
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if b.is_empty(p + d):
					open = true
					break
			if not open:
				n += 1
	return n


func _record_jokers(run: BMRun, r: Dictionary) -> void:
	for id in run.jokers:
		var s: Dictionary = joker_stats.get(id, {"placements": 0, "triggers": 0})
		s.placements += 1
		if r.triggered_jokers.has(id):
			s.triggers += 1
		joker_stats[id] = s


# --- Shop ------------------------------------------------------------------------------------

func _shop_step(run: BMRun) -> Dictionary:
	if run.has_crate():
		var take := 2
		if run.jokers.size() < run.joker_slots() and String(run.shop.crate[0].id) != "":
			take = 0
		return run.open_crate(take)
	if shop_policy == "none":
		return run.leave_shop()
	# Jokers: best rarity first.
	var best_i := -1
	var best_rarity := -1
	for i in run.shop.jokers.size():
		var id: String = run.shop.jokers[i]
		if id == "" or run.credits < BMJokers.cost(id) or run.jokers.size() >= run.joker_slots():
			continue
		var rarity := int(BMJokers.get_def(id).rarity)
		if rarity > best_rarity:
			best_rarity = rarity
			best_i = i
	if best_i >= 0:
		return run.buy_joker(best_i)
	if shop_policy == "jokers":
		return run.leave_shop()
	# Keep a small reserve for the next Joker once Joker slots are still open.
	var reserve := 3 if run.jokers.size() < run.joker_slots() else 0
	for i in run.shop.tools.size():
		var o: Dictionary = run.shop.tools[i]
		if o.is_empty() or run.credits - reserve < int(BMTools.get_def(o.id).cost):
			continue
		var plan := tool_plan(run, o)
		if plan.ok:
			var r := run.buy_tool(i, plan.targets, int(plan.get("color", -1)))
			if r.ok:
				purchases[o.id] = int(purchases.get(o.id, 0)) + 1
				return r
	for i in run.shop.pieces.size():
		var d: Dictionary = run.shop.pieces[i]
		if d.is_empty() or run.credits - reserve < int(d.cost) or run.bag.size() >= 30:
			continue
		if String(d.material) != "" or String(d.stamp) != "":
			purchases["piece"] = int(purchases.get("piece", 0)) + 1
			return run.buy_piece(i)
	for i in run.shop.consumables.size():
		var id: String = run.shop.consumables[i]
		if id != "" and id in BOT_ITEMS and run.credits - reserve >= BMConsumables.cost(id) + 2 and run.consumables.size() < BMRunConfig.CONSUMABLE_SLOTS:
			return run.buy_consumable(i)
	return run.leave_shop()


## Decides whether and how to use a Workshop offer. Returns {ok, targets, color?}.
static func tool_plan(run: BMRun, offer: Dictionary) -> Dictionary:
	var def := BMTools.get_def(offer.id)
	var by_size := run.bag.duplicate()
	by_size.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.cells.size() > b.cells.size() or (a.cells.size() == b.cells.size() and int(a.uid) < int(b.uid)))
	match def.kind:
		"material":
			if def.value == "prism" and not (run.jokers.has("blue_mood") or run.jokers.has("color_cycle")):
				return {"ok": false}
			var t: Array = []
			for p in by_size:
				if p.material == "" and t.size() < int(def.max_targets):
					t.append(int(p.uid))
			return {"ok": not t.is_empty(), "targets": t}
		"stamp":
			for p in by_size:
				if p.stamp == "":
					return {"ok": true, "targets": [int(p.uid)]}
		"copy":
			for p in by_size:
				if BMPieces.is_upgraded(p):
					return {"ok": true, "targets": [int(p.uid)]}
			for p in run.bag:
				if p.family == &"single":
					return {"ok": true, "targets": [int(p.uid)]}
		"remove":
			var t: Array = []
			for p in run.bag:
				if p.family in [&"zigzag4", &"plus5", &"square3"] and not BMPieces.is_upgraded(p) and t.size() < 2:
					t.append(int(p.uid))
			if not t.is_empty() and run.bag.size() - t.size() >= BMPieces.MIN_BAG:
				return {"ok": true, "targets": t}
		"repaint":
			if run.jokers.has("blue_mood"):
				var t: Array = []
				for p in by_size:
					if int(p.color) != BMShapes.COLOR_BLUE and t.size() < 3:
						t.append(int(p.uid))
				return {"ok": not t.is_empty(), "targets": t, "color": BMShapes.COLOR_BLUE}
		"slot":
			return {"ok": run.joker_slots() < BMRunConfig.MAX_JOKER_SLOTS, "targets": []}
		"schematic":
			var count := 0
			for p in run.bag:
				if String(p.family) == String(offer.family):
					count += 1
			return {"ok": count >= 3, "targets": []}
	return {"ok": false}
