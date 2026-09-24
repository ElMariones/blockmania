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
## Clear waves: removing cells can never complete a new line on its own. With The Avalanche
## (legendary) blocks fall down their columns after a clear; new full lines clear as extra waves
## (up to BMRunConfig.MAX_CLEAR_WAVES), each scored with the placement's Mult doubled per wave.
## Engine update (2026-09-24): multi-line clears add base Mult, Turbo xMult, Double Stamp,
## Philosopher's Stone (doubled materials, transmutation), Hall of Mirrors (Jokers twice),
## run-long scaling Jokers (BMRun.joker_state).


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
	rs.size_history.append(placed.size())
	var empties_tray := run.tray_spent()

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
	var holes_filled := _holes_filled(board_before, placed)
	var stone := run.has_active_joker("philosophers_stone")
	var stamp_times := 2 if run.has_active_joker("double_stamp") else 1
	var colors_before := {}
	for i in BMBoard.SIZE * BMBoard.SIZE:
		var c := board_before.cells[i]
		if c >= 0 and c < BMShapes.OFFER_COLOR_COUNT:
			colors_before[c] = true
	var feats := BMFeats.detect({"rows": rows.size(), "cols": cols.size(), "lines": lines,
		"combo_before": combo_before, "holes_filled": holes_filled, "placements_left_before": placements_left_before,
		"occupied_after": board.occupied_count() - clear_set.size() - mirror_extra.size()})
	var new_feats := 0
	for f in feats:
		if not rs.feats_seen.has(f):
			new_feats += 1
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
		"holes_filled": holes_filled,
		"feats": feats,
		"new_feats": new_feats,
		"size_history": rs.size_history.duplicate(),
		"at_cap": placements_left_before >= rs.placement_cap,
		"patience_store": rs.patience_store,
		"lines_before_run": int(run.stats.get("lines_cleared", 0)),
		"cells_cleared": clear_set.size(),
		"rounds_won": int(run.stats.get("rounds_won", 0)),
		"credits": run.credits,
		"state": run.joker_state,
		"items_held": run.consumables.size(),
		"glass_in_bag": BMBag.material_count(run, "glass"),
		"colors_before": colors_before.size(),
		"empty_joker_slots": maxi(0, run.joker_slots() - run.jokers.size()),
		"round_lines_before": rs.lines_cleared,
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
		var chrome := BMPieces.CHROME_CHIPS_PER_CELL * placed.size() * (2 if stone else 1)
		items.append({"label": "Chrome cells x%d%s" % [placed.size(), " (Stone: doubled)" if stone else ""], "kind": "chips", "value": chrome, "source": "piece"})
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
	if lines > 1:
		var ml := BMRunConfig.MULT_PER_EXTRA_LINE * (lines - 1)
		items.append({"label": "Multi-line Mult (%d lines)" % lines, "kind": "mult", "value": ml, "source": "base"})
		mult += ml
	if neon_cleared > 0:
		var neon := BMPieces.NEON_MULT_PER_CELL * neon_cleared * (2.0 if stone else 1.0)
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
		var enc := pow(BMPieces.ENCORE_X_MULT, stamp_times)
		items.append({"label": "Encore Stamp" + (" (Double Stamp)" if stamp_times > 1 else ""), "kind": "xmult", "value": enc, "source": "piece"})
		mult *= enc
	if glass_cleared > 0:
		var gx := BMPieces.GLASS_X_MULT * (BMPieces.GLASS_X_MULT if stone else 1.0)
		items.append({"label": "Glass cleared" + (" (Stone: doubled)" if stone else ""), "kind": "xmult", "value": gx, "source": "piece"})
		mult *= gx
	if rs.pending_xmult != 1.0:
		items.append({"label": "Turbo", "kind": "xmult", "value": rs.pending_xmult, "source": "consumable"})
		mult *= rs.pending_xmult
	if hand in [BMHands.MONOCHROME, BMHands.GRAND_SLAM]:
		items.append({"label": "%s hand" % BMHands.get_def(hand).name, "kind": "xmult", "value": BMHands.MONOCHROME_X_MULT, "source": "hand", "hand": hand})
		mult *= BMHands.MONOCHROME_X_MULT
	for e in effects:
		var x := BMJokers.x_mult(e.effect, ctx)
		if x != 1.0:
			items.append({"label": e.label, "kind": "xmult", "value": x, "source": "joker", "joker": e.id, "slot": e.slot})
			mult *= x

	# Step 7: Points with full precision, one rounding. A result at or past the machine's limit
	# (BMRunConfig.SCORE_CAP) "breaks the machine": it scores exactly the cap (BMRun ends the run).
	var raw := float(maxi(0, chips)) * maxf(1.0, mult)
	var broken := is_nan(raw) or is_inf(raw) or raw >= float(BMRunConfig.SCORE_CAP)
	var points := BMRunConfig.SCORE_CAP if broken else floori(maxi(0, chips) * maxf(1.0, mult))

	# Step 8: remove cleared cells (crossing cells once) plus Mirror Maze extras.
	var cleared := board.clear_cells(clear_set)
	var mirror_cleared := board.clear_cells(mirror_extra)
	var waves: Array = [{"chips": chips, "mult": mult, "points": points, "items": items, "cleared": cleared}]
	var wave_lines := 0
	# The Avalanche: blocks fall, and every new full line clears as another, bigger wave.
	if is_clearing and not broken and run.has_active_joker("avalanche"):
		while waves.size() < BMRunConfig.MAX_CLEAR_WAVES:
			var moves := board.settle()
			if moves.is_empty():
				break
			# Tombstones fall with their blocks.
			for t in rs.tombs:
				for mv in moves:
					if int(t[0]) == mv[0].x and int(t[1]) == mv[0].y:
						t[0] = mv[1].x
						t[1] = mv[1].y
						break
			var wr := board.full_rows()
			var wc := board.full_cols()
			var wl := wr.size() + wc.size()
			if wl == 0:
				waves[waves.size() - 1]["moves"] = moves
				break
			waves[waves.size() - 1]["moves"] = moves
			var wset := BMBoard.line_union(wr, wc)
			var n := waves.size() + 1
			var wchips := BMRunConfig.CHIPS_PER_LINE * wl + BMRunConfig.CHIPS_PER_EXTRA_LINE * (wl - 1) + BMRunConfig.CHIPS_PER_CELL * wset.size()
			var wlabel := "Avalanche wave %d: lines x%d" % [n, wl]
			if run.boss_active("echo_chamber"):
				wchips = wchips / 2
				wlabel += " (Echo Chamber: half)"
			var wmult := mult * pow(2.0, n - 1)
			var wraw := float(wchips) * wmult
			var wpoints := 0
			if is_inf(wraw) or wraw + points >= float(BMRunConfig.SCORE_CAP):
				broken = true
				wpoints = BMRunConfig.SCORE_CAP - points
			else:
				wpoints = floori(wraw)
			var witems: Array[Dictionary] = [
				{"label": wlabel, "kind": "chips", "value": wchips, "source": "wave", "wave": n},
				{"label": "Chain x%d" % int(pow(2.0, n - 1)), "kind": "xmult", "value": pow(2.0, n - 1), "source": "wave", "wave": n}]
			var wcleared := board.clear_cells(wset)
			for c in wcleared:
				match BMPieces.MATERIALS[int(c.mat)]:
					"gold":
						gold_cleared += 1
			points += wpoints
			wave_lines += wl
			waves.append({"chips": wchips, "mult": wmult, "points": wpoints, "items": witems, "cleared": wcleared,
				"rows": wr, "cols": wc})
			if broken:
				points = BMRunConfig.SCORE_CAP
				break
		run.stats["best_waves"] = maxi(int(run.stats.get("best_waves", 1)), waves.size())
	var all_lines := lines + wave_lines

	# Step 9: combo, target progress, piece effects, counters, statistics.
	var events: Array[String] = []
	if is_clearing:
		rs.combo = mini(BMRunConfig.COMBO_CAP, combo_before + 1)
		rs.combo_misses = 0
	else:
		rs.combo_misses += 1
		if rs.combo_misses > BMRunConfig.COMBO_GRACE:
			rs.combo = 0
	rs.score = mini(BMRunConfig.SCORE_CAP, rs.score + points)
	rs.pending_chips = 0
	rs.pending_mult = 0.0
	rs.pending_xmult = 1.0
	if gold_cleared > 0:
		var gold := BMPieces.GOLD_CREDITS_PER_CELL * gold_cleared * (2 if stone else 1)
		run.add_credits(gold)
		events.append("Gold: +%d Credit%s" % [gold, "s" if gold != 1 else ""])
	if stamp == "tip":
		run.add_credits(BMPieces.TIP_CREDITS * stamp_times)
		events.append("Tip Stamp: +%d Credits" % (BMPieces.TIP_CREDITS * stamp_times))
	if stamp == "refund":
		rs.placements_left += stamp_times
		events.append("Refund Stamp: this placement was free" + (" (+1 more)" if stamp_times > 1 else ""))
	var refilled := 0
	if all_lines > 0:
		refilled = clampi(all_lines * BMRunConfig.REFILL_PER_LINE, 0, maxi(0, rs.placement_cap - rs.placements_left))
		rs.placements_left += refilled
		if refilled > 0:
			events.append("Lines cleared: +%d placement%s" % [refilled, "" if refilled == 1 else "s"])
		var wasted := all_lines * BMRunConfig.REFILL_PER_LINE - refilled
		if wasted > 0 and run.has_active_joker("overflow"):
			var pay := mini(wasted, BMJokers.OVERFLOW_MAX - rs.overflow_paid)
			if pay > 0:
				rs.overflow_paid += pay
				run.add_credits(pay)
				events.append("Overflow: +%d Credit%s" % [pay, "" if pay == 1 else "s"])
	if run.has_active_joker("patience"):
		rs.patience_store = 0 if is_clearing else mini(BMJokers.PATIENCE_MAX, rs.patience_store + BMJokers.PATIENCE_STEP)
	if rows.size() > 0 and cols.size() > 0 and run.has_active_joker("draftsman"):
		if run.consumables.size() < BMRunConfig.CONSUMABLE_SLOTS:
			run.consumables.append("eraser")
			events.append("Draftsman: gained an Eraser")
		else:
			events.append("Draftsman: item slots full")
	for f in feats:
		if not rs.feats_seen.has(f):
			rs.feats_seen.append(f)
		run.stats["feats"] = int(run.stats.get("feats", 0)) + 1
	var unlocked := -1
	if is_clearing and rs.locked_slot >= 0:
		unlocked = rs.locked_slot
		rs.locked_slot = -1
		events.append("The Warden's bars break: slot %d is free" % (unlocked + 1))
	if is_clearing and not rs.patch_used and not rs.patch_ready and run.has_active_joker("patch_panel"):
		rs.patch_ready = true
		events.append("Patch Panel ready: remove one block")
	if stamp == "memory":
		for i in stamp_times:
			if run.consumables.size() < BMRunConfig.CONSUMABLE_SLOTS:
				run.consumables.append("spark")
				events.append("Memory Stamp: gained a Spark")
			else:
				events.append("Memory Stamp: item slots full")
	if lines >= 2 and run.jokers.has("snowball") and run.is_joker_active("snowball"):
		run._grow_joker("snowball", BMJokers.SNOWBALL_STEP)
		events.append("Snowball grew to x%s Mult" % BMJokers._num(run.joker_value("snowball")))
	# Philosopher's Stone: a plain bag piece turns into a random material for good.
	var transmuted := ""
	if stone and material == "" and int(piece.get("uid", -1)) >= 0 and not bool(piece.get("temporary", false)):
		var bp := BMBag.piece_by_uid(run, int(piece.uid))
		if not bp.is_empty():
			transmuted = BMPieces.MATERIALS[run.rng_shapes.randi_range(1, BMPieces.MATERIALS.size() - 1)]
			bp.material = transmuted
			run.stats["transmuted"] = int(run.stats.get("transmuted", 0)) + 1
			events.append("Philosopher's Stone: it turned %s" % BMPieces.MATERIAL_DEFS[transmuted].name)
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
				if run.has_active_joker("breakage_bonus"):
					run.add_credits(2)
					events.append("Breakage Bonus: +2 Credits")
			else:
				events.append("Glass %s cracked but held (bag at minimum size)" % name)
	run.stats.lines_cleared += all_lines
	rs.lines_cleared += all_lines
	run.stats.placements += 1
	run.stats.total_points = mini(BMRunConfig.SCORE_CAP, run.stats.total_points + points)
	run.stats.best_placement = maxi(run.stats.best_placement, points)
	run.stats["best_round_score"] = maxi(int(run.stats.get("best_round_score", 0)), rs.score)
	run.stats.highest_combo = maxi(run.stats.highest_combo, rs.combo)
	if lines >= 3:
		run.stats.triple_clears += 1
	if lines >= 2:
		run.stats["multi_clears"] = int(run.stats.get("multi_clears", 0)) + 1

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
		"waves": waves,
		"wave_lines": wave_lines,
		"transmuted": transmuted,
		"items": items,
		"chips": chips,
		"mult": mult,
		"points": points,
		"broken": broken,
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
		"feats": feats,
		"new_feats": new_feats,
		"unlocked": unlocked,
	}


## Active scoring effects in resolution order. Mimic resolves as a copy of the Joker directly
## below it (never another Mimic, never a rule-only or disabled card).
static func _joker_effects(run: BMRun) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var twice := run.has_active_joker("hall_of_mirrors")
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
					if twice:
						out.append({"id": id, "effect": target, "slot": i, "label": "Mimic (%s), mirrored" % BMJokers.get_def(target).name, "mirrored": true})
			continue
		out.append({"id": id, "effect": id, "slot": i, "label": name})
		if twice and id != "hall_of_mirrors":
			out.append({"id": id, "effect": id, "slot": i, "label": name + ", mirrored", "mirrored": true})
	return out


## Placed cells that filled a one-block hole: empty before, with all four sides blocked (by
## blocks or the board edge).
static func _holes_filled(board_before: BMBoard, placed: Array[Vector2i]) -> int:
	var n := 0
	for p in placed:
		var closed := true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if BMBoard.in_bounds(q) and board_before.is_empty(q):
				closed = false
				break
		if closed:
			n += 1
	return n


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
