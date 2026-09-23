class_name BMResolver
extends RefCounted
## Resolves one placement atomically (GDD §5 "Modifier pipeline", §16.3 piece upgrades) and
## returns an immutable resolution record for presentation, receipts, and tests. Presentation
## never changes the outcome; it only reads the record.
##
## Order inside the pipeline:
##   step 3 base Chips: cells, Chrome, Schematic level, lines, multi-line, combo, boss, Twins hand
##   step 4 additive Chips: Polish, then Jokers top to bottom (Mimic copies the Joker below it)
##   step 5 additive Mult: 1 + Schematic level + Neon cells cleared + Spark + Triplets/Grand Slam
##         hand + Jokers; floor 1
##   step 6 xMult: Encore stamp (on clear), Glass (once per placement), Monochrome/Grand Slam
##         hand, then Jokers
##   step 7 Points = floor(Chips x Mult); step 8 remove cells; step 9 counters, stamps, Gold,
##   Glass shatter rolls (shapes stream), combo, line refills (placements back up to the cap).
##
## Clear waves: removing cells can never complete a new line, and no current card adds cells
## after a clear, so every placement resolves in exactly one wave (record keeps `waves`).


## Caller (BMRun.place) has validated phase, slot, and legality.
static func resolve_placement(run: BMRun, slot: int, anchor: Vector2i) -> Dictionary:
	var rs := run.round_state
	var piece: Dictionary = run.tray[slot]
	var board := run.board
	var board_before := board.duplicate_board()
	var material := String(piece.get("material", ""))
	var stamp := String(piece.get("stamp", ""))
	var prism := material == "prism"
	var hand := String(piece.get("hand", ""))

	var placements_left_before := rs.placements_left
	var combo_before := rs.combo
	var score_before := rs.score
	var credits_before := run.credits
	var discard_before := run.discard_pile.size()

	# Step 1: snapshot and place.
	var placed := board.place(piece.cells, anchor, int(piece.color), int(piece.get("uid", -1)), BMPieces.material_index(material))
	run.tray[slot] = {}
	BMBag.discard(run, piece)
	rs.placements_left -= 1
	rs.placements_made += 1
	rs.color_history.append(-1 if prism else int(piece.color))
	var empties_tray := run.tray_is_empty()

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

	# Materials of every cell leaving the board this placement.
	var neon_cleared := 0
	var gold_cleared := 0
	var glass_cleared := 0
	var glass_owners: Array[int] = []
	for p in clear_set + mirror_extra:
		match BMPieces.MATERIALS[board.get_mat(p)]:
			"neon":
				neon_cleared += 1
			"gold":
				gold_cleared += 1
			"glass":
				glass_cleared += 1
				var o := board.get_owner(p)
				if o >= 0 and not glass_owners.has(o):
					glass_owners.append(o)
	glass_owners.sort()

	var family_level := run.family_level(piece.family)
	var ctx := {
		"cell_count": placed.size(),
		"color": int(piece.color),
		"prism": prism,
		"family": piece.family,
		"material": material,
		"stamp": stamp,
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
		"bag_size": run.bag.size(),
		"upgraded_count": BMBag.upgraded_count(run),
		"distinct_families": BMBag.distinct_families(run),
		"family_level": family_level,
		"discard_size": discard_before,
		"empties_tray": empties_tray,
		"neon_cleared": neon_cleared,
		"gold_cleared": gold_cleared,
		"glass_cleared": glass_cleared,
		"hand": hand,
	}

	# Step 3: base Chips.
	var items: Array[Dictionary] = []
	var chips := 0
	var cell_chips := BMRunConfig.CHIPS_PER_CELL * placed.size()
	if run.has_active_joker("long_game") and rs.placements_made <= 1:
		items.append({"label": "Cells x%d (Long Game: no cell Chips)" % placed.size(), "kind": "chips", "value": 0, "source": "joker", "joker": "long_game"})
	else:
		items.append({"label": "Cells x%d" % placed.size(), "kind": "chips", "value": cell_chips, "source": "base"})
		chips += cell_chips
	if material == "chrome":
		var chrome := BMPieces.CHROME_CHIPS_PER_CELL * placed.size()
		items.append({"label": "Chrome cells x%d" % placed.size(), "kind": "chips", "value": chrome, "source": "piece"})
		chips += chrome
	if family_level > 0:
		var lvl_chips := BMPieces.LEVEL_CHIPS * family_level
		items.append({"label": "%s Lv %d" % [BMShapes.family(piece.family).name, family_level], "kind": "chips", "value": lvl_chips, "source": "piece"})
		chips += lvl_chips
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
	if hand == BMHands.TWINS:
		items.append({"label": "Twins hand", "kind": "chips", "value": BMHands.TWINS_CHIPS, "source": "hand", "hand": hand})
		chips += BMHands.TWINS_CHIPS

	var effects := _joker_effects(run)

	# Step 4: additive Chips — consumables first, then Jokers top to bottom.
	if rs.pending_chips != 0:
		items.append({"label": "Polish", "kind": "chips", "value": rs.pending_chips, "source": "consumable"})
		chips += rs.pending_chips
	for e in effects:
		var c := BMJokers.chips(e.effect, ctx)
		if c != 0:
			items.append({"label": e.label, "kind": "chips", "value": c, "source": "joker", "joker": e.id, "slot": e.slot})
			chips += c

	# Step 5: additive Mult, floor 1.
	var mult := 1.0
	if family_level > 0:
		var lvl_mult := BMPieces.LEVEL_MULT * family_level
		items.append({"label": "%s Lv %d" % [BMShapes.family(piece.family).name, family_level], "kind": "mult", "value": lvl_mult, "source": "piece"})
		mult += lvl_mult
	if neon_cleared > 0:
		var neon := BMPieces.NEON_MULT_PER_CELL * neon_cleared
		items.append({"label": "Neon cells cleared x%d" % neon_cleared, "kind": "mult", "value": neon, "source": "piece"})
		mult += neon
	if rs.pending_mult != 0.0:
		items.append({"label": "Spark", "kind": "mult", "value": rs.pending_mult, "source": "consumable"})
		mult += rs.pending_mult
	if hand in [BMHands.TRIPLETS, BMHands.GRAND_SLAM]:
		items.append({"label": "%s hand" % BMHands.get_def(hand).name, "kind": "mult", "value": BMHands.TRIPLETS_MULT, "source": "hand", "hand": hand})
		mult += BMHands.TRIPLETS_MULT
	for e in effects:
		var m := BMJokers.add_mult(e.effect, ctx)
		if m != 0.0:
			items.append({"label": e.label, "kind": "mult", "value": m, "source": "joker", "joker": e.id, "slot": e.slot})
			mult += m
	mult = maxf(1.0, mult)

	# Step 6: multiplicative Mult.
	if is_clearing and stamp == "encore":
		items.append({"label": "Encore Stamp", "kind": "xmult", "value": BMPieces.ENCORE_X_MULT, "source": "piece"})
		mult *= BMPieces.ENCORE_X_MULT
	if glass_cleared > 0:
		items.append({"label": "Glass cleared", "kind": "xmult", "value": BMPieces.GLASS_X_MULT, "source": "piece"})
		mult *= BMPieces.GLASS_X_MULT
	if hand in [BMHands.MONOCHROME, BMHands.GRAND_SLAM]:
		items.append({"label": "%s hand" % BMHands.get_def(hand).name, "kind": "xmult", "value": BMHands.MONOCHROME_X_MULT, "source": "hand", "hand": hand})
		mult *= BMHands.MONOCHROME_X_MULT
	for e in effects:
		var x := BMJokers.x_mult(e.effect, ctx)
		if x != 1.0:
			items.append({"label": e.label, "kind": "xmult", "value": x, "source": "joker", "joker": e.id, "slot": e.slot})
			mult *= x

	# Step 7: Points with full precision, one rounding.
	var points := floori(maxi(0, chips) * maxf(1.0, mult))

	# Step 8: remove cleared cells (crossing cells once) plus Mirror Maze extras.
	var cleared := board.clear_cells(clear_set)
	var mirror_cleared := board.clear_cells(mirror_extra)

	# Step 9: combo, target progress, piece effects, counters, statistics.
	var events: Array[String] = []
	rs.combo = mini(BMRunConfig.COMBO_CAP, combo_before + 1) if is_clearing else 0
	rs.score += points
	rs.pending_chips = 0
	rs.pending_mult = 0.0
	if gold_cleared > 0:
		run.add_credits(BMPieces.GOLD_CREDITS_PER_CELL * gold_cleared)
		events.append("Gold: +%d Credit%s" % [gold_cleared, "s" if gold_cleared != 1 else ""])
	if stamp == "tip":
		run.add_credits(BMPieces.TIP_CREDITS)
		events.append("Tip Stamp: +%d Credit%s" % [BMPieces.TIP_CREDITS, "s" if BMPieces.TIP_CREDITS != 1 else ""])
	if stamp == "refund":
		rs.placements_left += 1
		events.append("Refund Stamp: this placement was free")
	var refilled := 0
	if lines > 0:
		refilled = clampi(lines * BMRunConfig.REFILL_PER_LINE, 0, maxi(0, rs.placement_cap - rs.placements_left))
		rs.placements_left += refilled
		if refilled > 0:
			events.append("Lines cleared: +%d placement%s" % [refilled, "" if refilled == 1 else "s"])
	if stamp == "memory":
		if run.consumables.size() < BMRunConfig.CONSUMABLE_SLOTS:
			run.consumables.append("spark")
			events.append("Memory Stamp: gained a Spark")
		else:
			events.append("Memory Stamp: item slots full")
	var shattered: Array[int] = []
	for uid in glass_owners:
		# A Glass piece that already shattered can still have cells on the board; it rolls no more.
		if BMBag.piece_by_uid(run, uid).is_empty():
			continue
		if run.rng_shapes.randi_range(1, BMPieces.GLASS_SHATTER_ONE_IN) == 1:
			var name := BMPieces.describe(BMBag.piece_by_uid(run, uid)).get_slice("\n", 0)
			if BMBag.remove_piece(run, uid):
				shattered.append(uid)
				events.append("Glass %s shattered and left your bag" % name)
			else:
				events.append("Glass %s cracked but held (bag at minimum size)" % name)
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
		"shape": piece,
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
		"credits_gained": run.credits - credits_before,
		"events": events,
		"shattered": shattered,
		"placements_refilled": refilled,
	}


## Active scoring effects in resolution order. Mimic resolves as a copy of the Joker directly
## below it (never another Mimic, never a rule-only or disabled card).
static func _joker_effects(run: BMRun) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in run.jokers.size():
		var id: String = run.jokers[i]
		if not run.is_joker_active(id):
			continue
		var name: String = BMJokers.get_def(id).name
		if id == "mimic":
			if i + 1 < run.jokers.size():
				var target: String = run.jokers[i + 1]
				if BMJokers.is_copyable(target) and run.is_joker_active(target):
					out.append({"id": id, "effect": target, "slot": i, "label": "Mimic (%s)" % BMJokers.get_def(target).name})
			continue
		out.append({"id": id, "effect": id, "slot": i, "label": name})
	return out


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
