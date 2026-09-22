class_name BMResolver
extends RefCounted
## Resolves one placement atomically (GDD §5 "Modifier pipeline") and returns an immutable
## resolution record for presentation, receipts, and tests. Presentation never changes the
## outcome; it only reads the record.
##
## Clear waves: removing cells can never complete a new line, and no current card adds cells
## after a clear, so every placement resolves in exactly one wave. The record still stores a
## `waves` array so After Clear effects can add waves later (cap: BMRunConfig.MAX_CLEAR_WAVES).


## Caller (BMRun.place) has validated phase, slot, and legality.
static func resolve_placement(run: BMRun, slot: int, anchor: Vector2i) -> Dictionary:
	var rs := run.round_state
	var shape: Dictionary = run.tray[slot]
	var board := run.board
	var board_before := board.duplicate_board()

	var placements_left_before := rs.placements_left
	var combo_before := rs.combo
	var score_before := rs.score

	# Step 1: snapshot and place.
	var placed := board.place(shape.cells, anchor, shape.color)
	run.tray[slot] = {}
	rs.placements_left -= 1
	rs.placements_made += 1
	rs.color_history.append(int(shape.color))

	# Step 2: Before Clear effects — none in current content. Detect lines on the placed board.
	var rows := board.full_rows()
	var cols := board.full_cols()
	var lines := rows.size() + cols.size()
	var is_clearing := lines > 0
	if is_clearing:
		rs.clearing_placements += 1

	var clear_set := BMBoard.line_union(rows, cols)

	# Mirror Maze: first row clear each round also removes the mirrored row's occupied cells.
	var mirror_extra: Array[Vector2i] = []
	if rows.size() > 0 and not rs.mirror_used and run.has_active_joker("mirror_maze"):
		rs.mirror_used = true
		var mirrored := BMBoard.SIZE - 1 - rows[0]
		if not rows.has(mirrored):
			for x in BMBoard.SIZE:
				var p := Vector2i(x, mirrored)
				if board.get_cell(p) != BMBoard.EMPTY and not clear_set.has(p):
					mirror_extra.append(p)

	var ctx := {
		"cell_count": placed.size(),
		"color": int(shape.color),
		"rows": rows.size(),
		"cols": cols.size(),
		"lines": lines,
		"is_clearing": is_clearing,
		"combo_before": combo_before,
		"empty_before": board_before.empty_count(),
		"occupied_before": board_before.occupied_count(),
		"placement_index": rs.placements_made,
		"clearing_index": rs.clearing_placements,
		"touches_diagonal": _touches_diagonal(board_before, placed),
		"touches_corner": _touches_corner(placed),
		"color_history": rs.color_history.duplicate(),
		"placements_left_before": placements_left_before,
		"refreshes_available": run.refreshes_available(),
		"jokers_sold": run.jokers_sold,
		"mirror_removed": mirror_extra.size(),
	}

	# Step 3: base Chips.
	var items: Array[Dictionary] = []
	var chips := 0
	var cell_chips := BMRunConfig.CHIPS_PER_CELL * placed.size()
	if run.has_active_joker("long_game") and rs.placements_made <= 3:
		items.append({"label": "Cells x%d (Long Game: no cell Chips)" % placed.size(), "kind": "chips", "value": 0, "source": "joker", "joker": "long_game"})
	else:
		items.append({"label": "Cells x%d" % placed.size(), "kind": "chips", "value": cell_chips, "source": "base"})
		chips += cell_chips
	if lines > 0:
		var line_chips := BMRunConfig.CHIPS_PER_LINE * lines
		var line_label := "Lines x%d" % lines
		if run.boss_active("taxman"):
			line_chips -= BMRunConfig.CHIPS_PER_LINE - BMBosses.TAXMAN_FIRST_LINE_CHIPS
			line_label += " (Taxman: first line %d)" % BMBosses.TAXMAN_FIRST_LINE_CHIPS
		items.append({"label": line_label, "kind": "chips", "value": line_chips, "source": "base"})
		chips += line_chips
		if lines > 1:
			var extra := BMRunConfig.CHIPS_PER_EXTRA_LINE * (lines - 1)
			items.append({"label": "Multi-line bonus", "kind": "chips", "value": extra, "source": "base"})
			chips += extra
		if combo_before > 0:
			var combo_chips := BMRunConfig.CHIPS_PER_COMBO * combo_before
			items.append({"label": "Combo %d" % combo_before, "kind": "chips", "value": combo_chips, "source": "base"})
			chips += combo_chips
		if lines > 1 and run.boss_active("last_call"):
			items.append({"label": "Last Call multi-line", "kind": "chips", "value": BMBosses.LAST_CALL_MULTI_LINE_CHIPS, "source": "boss"})
			chips += BMBosses.LAST_CALL_MULTI_LINE_CHIPS

	# Step 4: additive Chips — consumables first, then Jokers left to right.
	if rs.pending_chips != 0:
		items.append({"label": "Polish", "kind": "chips", "value": rs.pending_chips, "source": "consumable"})
		chips += rs.pending_chips
	for i in run.jokers.size():
		var id: String = run.jokers[i]
		if not run.is_joker_active(id):
			continue
		var c := BMJokers.chips(id, ctx)
		if c != 0:
			items.append({"label": BMJokers.get_def(id).name, "kind": "chips", "value": c, "source": "joker", "joker": id, "slot": i})
			chips += c

	# Step 5: additive Mult, floor 1.
	var mult := 1.0
	if rs.pending_mult != 0.0:
		items.append({"label": "Spark", "kind": "mult", "value": rs.pending_mult, "source": "consumable"})
		mult += rs.pending_mult
	for i in run.jokers.size():
		var id: String = run.jokers[i]
		if not run.is_joker_active(id):
			continue
		var m := BMJokers.add_mult(id, ctx)
		if m != 0.0:
			items.append({"label": BMJokers.get_def(id).name, "kind": "mult", "value": m, "source": "joker", "joker": id, "slot": i})
			mult += m
	mult = maxf(1.0, mult)

	# Step 6: multiplicative Mult.
	for i in run.jokers.size():
		var id: String = run.jokers[i]
		if not run.is_joker_active(id):
			continue
		var x := BMJokers.x_mult(id, ctx)
		if x != 1.0:
			items.append({"label": BMJokers.get_def(id).name, "kind": "xmult", "value": x, "source": "joker", "joker": id, "slot": i})
			mult *= x

	# Step 7: Points with full precision, one rounding.
	var points := floori(maxi(0, chips) * maxf(1.0, mult))

	# Step 8: remove cleared cells (crossing cells once) plus Mirror Maze extras.
	var cleared := board.clear_cells(clear_set)
	var mirror_cleared := board.clear_cells(mirror_extra)

	# Step 9: combo, target progress, counters, statistics.
	rs.combo = mini(BMRunConfig.COMBO_CAP, combo_before + 1) if is_clearing else 0
	rs.score += points
	rs.pending_chips = 0
	rs.pending_mult = 0.0
	run.stats.lines_cleared += lines
	run.stats.placements += 1
	run.stats.total_points += points
	run.stats.best_placement = maxi(run.stats.best_placement, points)
	run.stats.highest_combo = maxi(run.stats.highest_combo, rs.combo)
	if lines >= 3:
		run.stats.triple_clears += 1

	var triggered: Array[String] = []
	for it in items:
		if it.source == "joker" and not triggered.has(it.joker):
			triggered.append(it.joker)

	return {
		"ok": true,
		"type": "place",
		"slot": slot,
		"anchor": anchor,
		"shape": shape,
		"placed": placed,
		"rows": rows,
		"cols": cols,
		"lines": lines,
		"cleared": cleared,
		"mirror_cleared": mirror_cleared,
		"waves": [{"chips": chips, "mult": mult, "points": points, "items": items}],
		"items": items,
		"chips": chips,
		"mult": mult,
		"points": points,
		"triggered_jokers": triggered,
		"combo_before": combo_before,
		"combo_after": rs.combo,
		"score_before": score_before,
		"score_after": rs.score,
		"target": rs.target,
	}


static func _touches_diagonal(board_before: BMBoard, placed: Array[Vector2i]) -> bool:
	for p in placed:
		for d in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
			var q: Vector2i = p + d
			if BMBoard.in_bounds(q) and board_before.get_cell(q) != BMBoard.EMPTY:
				return true
	return false


static func _touches_corner(placed: Array[Vector2i]) -> bool:
	var last := BMBoard.SIZE - 1
	for p in placed:
		if (p.x == 0 or p.x == last) and (p.y == 0 or p.y == last):
			return true
	return false
