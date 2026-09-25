extends SceneTree
## Release-style playability study (docs/playtests/2026-09-26_release_study.md): a population of
## simulated participants with different skills, shopping habits, item habits, round-card taste and
## attitudes to duplicate Jokers, plus paired-seed experiments. Every shop offer, purchase, sale,
## item (obtained, used, wasted) and round is logged, so the report can list what each run used
## and never used. Dev-only; it never touches saves.
##   godot --headless --path . --script res://tools/study.gd -- population <participants> <first_id> <out.json> [runs_each=3]
##   godot --headless --path . --script res://tools/study.gd -- <experiment arm> <runs> <first_seed> <out.json>
## Arms are listed in ARMS. Aggregate with `python tools/study_report.py <out_dir> <json files...>`.
## Won runs stop at the campaign win (no Overtime) unless the arm sets "overtime".

const PT := preload("res://tools/playtest.gd")

## Build families used to name what a run was "going for" (report only).
const TAGS := {
	"color": ["blue_mood", "color_cycle", "rainbow_road"],
	"multi_line": ["jackpot_window", "wide_awake", "crossbar", "keystone", "snowball", "demolition_crew", "chain_link", "compound_interest", "supernova", "avalanche"],
	"bag_engine": ["foundry", "specialist", "hoarder", "collector", "lean_bag", "recycler", "postmaster", "neon_sign", "glass_cannon", "veteran", "philosophers_stone", "double_stamp", "breakage_bonus"],
	"economy": ["loan_shark", "spare_parts", "overflow", "coin_pusher", "full_pockets", "vending_machine", "fire_sale"],
	"shape": ["small_change", "heavy_hand", "architect", "straight_edge", "square_deal", "big_game_hunter", "countdown"],
	"hands": ["hot_hand", "card_sharp"],
	"scaling": ["hot_streak", "overachiever", "bonsai", "tally_counter"],
	"safety": ["tiny_insurance", "second_look", "insurance_policy", "patch_panel", "periscope", "draftsman", "long_game", "mirror_maze"],
}

## Favorite lists a participant can adopt (a human who likes a style).
const FAVORITES := {
	"color": ["blue_mood", "color_cycle", "rainbow_road", "hot_hand", "golden_ratio"],
	"multi_line": ["jackpot_window", "wide_awake", "keystone", "snowball", "compound_interest", "demolition_crew"],
	"bag_engine": ["foundry", "specialist", "collector", "recycler", "veteran", "hoarder"],
	"economy": ["coin_pusher", "spare_parts", "loan_shark", "full_pockets", "overflow", "bonsai"],
	"scaling": ["hot_streak", "overachiever", "snowball", "bonsai", "tally_counter"],
	"shape": ["big_game_hunter", "square_deal", "heavy_hand", "straight_edge", "small_change"],
	"xmult": ["compound_interest", "golden_ratio", "color_cycle", "hot_hand", "last_stand"],
}

## Paired-seed experiment arms. Every arm plays the same seeds. Keys override participant traits.
const BASE_ARM := {"placement": "expert_lite", "shop": "meta", "items": "smart", "item_buy": 0.5,
	"cards": "standard", "dup": "neutral", "favorites": "", "rerolls": 2, "locked": false, "variant": ""}
const ARMS := {
	# E1 items: how much are items worth, and how much does the way they are used matter?
	"items_never": {"items": "never"},
	"items_hoarder": {"items": "hoarder", "item_buy": 0.7},
	"items_impulse": {"items": "impulse", "item_buy": 0.7},
	"items_smart": {"items": "smart", "item_buy": 0.7},
	"items_savvy": {"items": "savvy", "item_buy": 0.7},
	"items_lover": {"items": "savvy", "item_buy": 1.0, "reserve": 0},
	# E2 duplicates: attitudes under the current shop, and two shop variants.
	"dup_avoid": {"dup": "avoid"},
	"dup_neutral": {"dup": "neutral"},
	"dup_stack": {"dup": "stack"},
	"dup_stack_fav": {"dup": "stack", "favorites": "xmult"},
	"shop_no_owned": {"dup": "stack", "variant": "no_owned"},
	"shop_fresh": {"dup": "stack", "variant": "fresh"},
	"shop_current": {"dup": "stack"},
	# E3 round cards.
	"cards_standard": {"cards": "standard"},
	"cards_random": {"cards": "random"},
	"cards_greedy": {"cards": "greedy"},
	"cards_ev": {"cards": "ev"},
	# E4 profile: a fresh install (14 Jokers locked) vs everything unlocked.
	"profile_fresh": {"locked": true, "dup": "stack"},
	"profile_full": {"locked": false, "dup": "stack"},
	# E5 skill ladder with the same shop brain.
	"skill_casual": {"placement": "casual", "shop": "newcomer", "items": "hoarder"},
	"skill_smart": {"placement": "smart", "shop": "full", "items": "hoarder"},
	"skill_lite": {"placement": "expert_lite"},
	"skill_expert": {"placement": "expert"},
}


class Participant extends "res://tools/playtest.gd".Persona:
	var traits := {}
	var items_style := "smart"
	var item_buy := 0.5
	var cards_style := "standard"
	var dup := "neutral"
	var favorites: Array = []
	var reserve_items := 3
	var cur: BMRun
	var card_done := false
	var fill := 0
	var considered := {}
	## Item uses: {id, round, mode, delta, pct, status}
	var item_log: Array = []
	var last_round_left := 0.5

	func _init(t: Dictionary, seed_value: int) -> void:
		var cfg := {"placement": "expert" if String(t.placement) == "expert_lite" else String(t.placement),
			"shop": String(t.shop), "jokers": FAVORITES.get(String(t.get("favorites", "")), []),
			"rerolls": int(t.get("rerolls", 2))}
		super(cfg, seed_value)
		traits = t
		if String(t.placement) == "expert_lite":
			widths = [4, 2, 2]
		items_style = String(t.items)
		item_buy = float(t.item_buy)
		cards_style = String(t.cards)
		dup = String(t.dup)
		favorites = FAVORITES.get(String(t.get("favorites", "")), [])
		reserve_items = int(t.get("reserve", 3))
		rng.seed = hash("participant%s/%d" % [String(t.get("pid", "")), seed_value])

	# --- Round ---------------------------------------------------------------------------

	func _round_step(run: BMRun) -> Dictionary:
		cur = run
		var rs := run.round_state
		if rs.status == BMRun.OUT_OF_PLACEMENTS:
			var i := run.consumables.find("extra_turn")
			if i >= 0:
				return _use(run, i, {}, "rescue")
			return run.concede_round()
		if rs.status == BMRun.STUCK:
			return _rescue(run)
		var any_tray := false
		for i in run.tray.size():
			if run.slot_fits(i):
				any_tray = true
		if not any_tray and not rs.held.is_empty() and not rs.hold_used and run.board.fits_anywhere(rs.held.cells):
			for i in run.tray.size():
				if not run.slot_locked(i):
					return run.hold(i)
		var pre := _proactive(run)
		if not pre.is_empty():
			return pre
		var best := choose_placement(run)
		if best.is_empty():
			return run.refresh() if run.refreshes_available() > 0 else run.concede_round()
		if bool(best.get("dead_end", false)) and rs.placements_made > 0:
			if run.refreshes_available() > 0:
				plan = []
				return run.refresh()
			if items_style in ["smart", "savvy"]:
				for id in ["second_tray", "coffee_break"]:
					var k := run.consumables.find(id)
					if k >= 0 and run.consumable_usable(k) == "":
						plan = []
						return _use(run, k, {}, "tempo")
		var b := _boost(run, best)
		if not b.is_empty():
			return b
		var r := run.place(best.slot, best.anchor)
		if r.ok:
			_record_jokers(run, r)
		return r

	## Uses an item and logs it; boosts log the points they added to the next placement.
	func _use(run: BMRun, index: int, target: Dictionary, mode: String, best: Dictionary = {}) -> Dictionary:
		var id := run.consumables[index]
		var entry := {"id": id, "round": run.round_number, "mode": mode, "status": String(run.round_state.status),
			"target": run.round_state.target}
		if not best.is_empty():
			var p0 := run.preview_place(best.slot, best.anchor)
			var c := run.clone()
			c.use_consumable(index, target)
			var p1 := c.preview_place(best.slot, best.anchor)
			if p0.ok and p1.ok:
				entry.delta = int(p1.points) - int(p0.points)
				entry.pct = float(entry.delta) / maxf(1.0, float(run.round_state.target))
		var r := run.use_consumable(index, target)
		if r.ok:
			item_log.append(entry)
		return r

	func _rescue(run: BMRun) -> Dictionary:
		if run.refreshes_available() > 0:
			plan = []
			return run.refresh()
		for id in ["coffee_break", "second_tray", "blueprint", "emergency_brick", "eraser", "punch", "color_purge"]:
			var i := run.consumables.find(id)
			if i < 0 or run.consumable_usable(i) != "":
				continue
			var t := _rescue_target(run, id)
			if t.get("ok", false):
				plan = []
				t.erase("ok")
				return _use(run, i, t, "rescue")
		if run.round_state.patch_ready:
			var best_p := Vector2i(-1, -1)
			var best_fit := 0
			for y in BMBoard.SIZE:
				for x in BMBoard.SIZE:
					var p := Vector2i(x, y)
					if run.board.is_empty(p):
						continue
					var f := _fit_after(run, [p])
					if f > best_fit:
						best_fit = f
						best_p = p
			if best_fit > 0:
				plan = []
				item_log.append({"id": "patch_panel", "round": run.round_number, "mode": "rescue", "status": "stuck", "target": run.round_state.target})
				return run.patch_cell(best_p)
		return run.concede_round()

	## Tray pieces that fit after removing `cells` from the board.
	func _fit_after(run: BMRun, cells: Array) -> int:
		var b := run.board.duplicate_board()
		var typed: Array[Vector2i] = []
		typed.assign(cells)
		b.clear_cells(typed)
		var n := 0
		for i in run.tray.size():
			if not run.tray[i].is_empty() and not run.slot_locked(i) and b.fits_anywhere(run.tray[i].cells):
				n += 1
		return n

	func _occupied(run: BMRun) -> Array:
		var out: Array = []
		for y in BMBoard.SIZE:
			for x in BMBoard.SIZE:
				if not run.board.is_empty(Vector2i(x, y)):
					out.append(Vector2i(x, y))
		return out

	func _rescue_target(run: BMRun, id: String) -> Dictionary:
		match id:
			"coffee_break", "second_tray":
				return {"ok": true}
			"blueprint":
				for s in run.tray.size():
					if run.tray[s].is_empty() or run.slot_locked(s):
						continue
					for ch in BMConsumables.BLUEPRINT_CHOICES.size():
						var pick: Array = BMConsumables.BLUEPRINT_CHOICES[ch]
						var sh := BMShapes.make_shape(StringName(pick[0]), int(pick[1]), 0)
						if run.board.fits_anywhere(sh.cells):
							return {"ok": true, "slot": s, "choice": ch}
			"emergency_brick":
				if run.board.empty_count() > 0:
					for s in run.tray.size():
						if not run.slot_locked(s) and not run.slot_fits(s):
							return {"ok": true, "slot": s}
			"eraser":
				var occ := _occupied(run)
				var best: Array = []
				var best_f := 0
				for a in occ:
					var f := _fit_after(run, [a])
					if f > best_f:
						best_f = f
						best = [a]
				if best_f == 0:
					for i in occ.size():
						for j in range(i + 1, occ.size()):
							var f := _fit_after(run, [occ[i], occ[j]])
							if f > best_f:
								best_f = f
								best = [occ[i], occ[j]]
				if best_f > 0:
					var cells: Array = []
					for p in best:
						cells.append([p.x, p.y])
					return {"ok": true, "cells": cells}
			"punch":
				var best_c := Vector2i(-1, -1)
				var best_f := 0
				for y in BMBoard.SIZE:
					for x in BMBoard.SIZE:
						var hits: Array = []
						for p in BMConsumables.punch_cells(Vector2i(x, y)):
							if not run.board.is_empty(p):
								hits.append(p)
						if hits.is_empty():
							continue
						var f := _fit_after(run, hits)
						if f > best_f:
							best_f = f
							best_c = Vector2i(x, y)
				if best_f > 0:
					return {"ok": true, "cells": [[best_c.x, best_c.y]]}
			"color_purge":
				var best_col := -1
				var best_f := 0
				for col in BMShapes.OFFER_COLOR_COUNT:
					var hits: Array = []
					for p in _occupied(run):
						if run.board.get_cell(p) == col:
							hits.append(p)
					if hits.is_empty():
						continue
					var f := _fit_after(run, hits)
					if f > best_f:
						best_f = f
						best_col = col
				if best_f > 0:
					return {"ok": true, "color": best_col}
		return {"ok": false}

	## Items used outside emergencies, by habit.
	func _proactive(run: BMRun) -> Dictionary:
		if items_style in ["never", "hoarder"]:
			return {}
		for i in run.consumables.size():
			var id := run.consumables[i]
			if run.consumable_usable(i) != "":
				continue
			match id:
				"cash_out":
					return _use(run, i, {}, "economy")
				"coin_roll":
					if items_style != "savvy" or run.round_number >= 6 or run.consumables.size() >= BMRunConfig.CONSUMABLE_SLOTS:
						return _use(run, i, {}, "economy")
				"tune_up":
					if items_style == "impulse":
						for s in run.tray.size():
							if not run.tray[s].is_empty() and not run.slot_locked(s):
								plan = []
								return _use(run, i, {"slot": s}, "upgrade")
					else:
						var s := _most_common_family_slot(run)
						if s >= 0:
							plan = []
							return _use(run, i, {"slot": s}, "upgrade")
				"lucky_paint":
					var t := _paint_target(run)
					if not t.is_empty():
						plan = []
						return _use(run, i, t, "setup")
				"blueprint", "emergency_brick":
					if items_style == "savvy":
						var t := _clear_maker(run, id)
						if not t.is_empty():
							plan = []
							return _use(run, i, t, "setup")
		return {}

	func _most_common_family_slot(run: BMRun) -> int:
		var fams := {}
		for p in run.bag:
			fams[String(p.family)] = int(fams.get(String(p.family), 0)) + 1
		var best := -1
		var best_n := -1
		for s in run.tray.size():
			if run.tray[s].is_empty() or run.slot_locked(s) or bool(run.tray[s].get("temporary", false)):
				continue
			var n := int(fams.get(String(run.tray[s].family), 0))
			if n > best_n:
				best_n = n
				best = s
		return best

	func _paint_target(run: BMRun) -> Dictionary:
		if items_style == "impulse":
			for s in run.tray.size():
				if not run.tray[s].is_empty() and not run.slot_locked(s):
					return {"slot": s, "color": (int(run.tray[s].color) + 1) % BMShapes.OFFER_COLOR_COUNT}
			return {}
		if run.jokers.has("blue_mood"):
			for s in run.tray.size():
				if not run.tray[s].is_empty() and not run.slot_locked(s) and int(run.tray[s].color) != BMShapes.COLOR_BLUE:
					return {"slot": s, "color": BMShapes.COLOR_BLUE}
		return {}

	## Savvy: a Blueprint shape or a Brick that clears a line when nothing in the tray does.
	func _clear_maker(run: BMRun, id: String) -> Dictionary:
		var cur_best := 0
		for c in _all_candidates(run):
			cur_best = maxi(cur_best, int(c.lines))
		var choices: Array = []
		if id == "blueprint":
			for ch in BMConsumables.BLUEPRINT_CHOICES.size():
				choices.append(ch)
		else:
			choices.append(-1)
		var best_lines := 0
		var best_ch := -2
		for ch in choices:
			var cells: Array[Vector2i]
			if ch < 0:
				cells = [Vector2i.ZERO]
			else:
				var pick: Array = BMConsumables.BLUEPRINT_CHOICES[ch]
				cells = BMShapes.make_shape(StringName(pick[0]), int(pick[1]), 0).cells
			for a in run.board.legal_anchors(cells):
				var b := run.board.duplicate_board()
				b.place(cells, a, 0)
				var lines := b.full_rows().size() + b.full_cols().size()
				if lines > best_lines:
					best_lines = lines
					best_ch = ch
		if best_lines < maxi(1, cur_best + 1):
			return {}
		# Replace the piece that fits worst (or the first open slot).
		var slot := -1
		for s in run.tray.size():
			if run.slot_locked(s) or run.tray[s].is_empty():
				continue
			if slot < 0 or not run.slot_fits(s):
				slot = s
		if slot < 0:
			return {}
		if id == "blueprint":
			return {"slot": slot, "choice": best_ch}
		return {"slot": slot}

	## Chips/Mult/Turbo before a placement, by habit.
	func _boost(run: BMRun, best: Dictionary) -> Dictionary:
		if items_style in ["never", "hoarder"]:
			return {}
		var lines := int(best.get("lines", 0))
		var rs := run.round_state
		for i in run.consumables.size():
			var id := run.consumables[i]
			if not id in ["polish", "spark", "overclock"] or run.consumable_usable(i) != "":
				continue
			var go := false
			match items_style:
				"impulse":
					go = true
				"smart":
					go = lines >= 1
				"savvy":
					if id == "overclock":
						go = lines >= 2 or (lines >= 1 and (BMRunConfig.is_boss_round(run.round_number) or rs.placements_left <= 4))
					else:
						go = lines >= 1
					if rs.placements_left <= 1:
						go = true
			if go:
				return _use(run, i, {}, "boost", best)
		return {}

	# --- Shop ----------------------------------------------------------------------------

	func pval(run: BMRun, id: String, owned_check: bool = true) -> float:
		if id == "":
			return -1.0
		var v := 0.0
		match shop_style:
			"meta":
				v = float(PT.META_VALUE.get(id, 20))
			"full":
				v = 30.0 + 30.0 * int(BMJokers.get_def(id).rarity)
			_:
				v = 40.0
		var f := favorites.find(id)
		if f >= 0:
			v += 100.0 - f * 6.0
		if owned_check and run.jokers.has(id):
			match dup:
				"avoid":
					v = -1000.0
				"stack":
					v += 35.0
		return v

	func joker_value(id: String) -> float:
		return pval(cur, id, false) if cur != null else float(PT.META_VALUE.get(id, 20))

	func _shop_step(run: BMRun) -> Dictionary:
		cur = run
		if run.round_number != shop_round:
			shop_round = run.round_number
			rerolls_this_shop = 0
			card_done = false
			fill += 1
			considered = {}
		if run.has_crate():
			return _crate(run)
		if not card_done:
			card_done = true
			var k := _pick_card(run)
			if k > 0:
				return run.pick_round(k)
		var j := _joker_step(run)
		if not j.is_empty():
			return j
		if shop_style != "newcomer" and shop_style != "none":
			var t := _tool_step(run)
			if not t.is_empty():
				return t
		var it := _item_step(run)
		if not it.is_empty():
			return it
		if shop_style == "meta":
			var full := run.jokers.size() >= run.joker_slots()
			var want_more := not favorites.is_empty() or not full
			var reroll_cost := int(run.shop.get("reroll_cost", BMRunConfig.REROLL_BASE))
			if want_more and rerolls_this_shop < max_rerolls and run.credits >= reroll_cost + 5 and run.round_number >= 2:
				rerolls_this_shop += 1
				fill += 1
				considered = {}
				return run.reroll_shop()
		if shop_style in ["meta", "full"]:
			var full := run.jokers.size() >= run.joker_slots()
			var reserve := 3 if not full else 0
			for i in run.shop.pieces.size():
				var d: Dictionary = run.shop.pieces[i]
				if d.is_empty() or run.credits - reserve < int(d.cost) or run.bag.size() >= 30:
					continue
				if String(d.material) != "" or String(d.stamp) != "":
					purchases["piece"] = int(purchases.get("piece", 0)) + 1
					return run.buy_piece(i)
		return run.leave_shop()

	func _crate(run: BMRun) -> Dictionary:
		var cj: String = run.shop.crate[0].id
		var full := run.jokers.size() >= run.joker_slots()
		var item_ok := run.consumables.size() < BMRunConfig.CONSUMABLE_SLOTS
		if items_style == "savvy" and item_buy >= 1.0 and item_ok and (full or pval(run, cj) < 60.0):
			return run.open_crate(1)
		match shop_style:
			"meta":
				var cw := _worst_owned_p(run)
				if cj != "" and (not full or (cw >= 0 and pval(run, cj) > pval(run, run.jokers[cw], false) + 10)):
					if full:
						return run.sell_joker(cw)
					return run.open_crate(0)
				return run.open_crate(2)
			_:
				if cj != "" and not full and not (dup == "avoid" and run.jokers.has(cj)):
					return run.open_crate(0)
				return run.open_crate(2)

	func _worst_owned_p(run: BMRun) -> int:
		var worst := -1
		var worst_v := INF
		for i in run.jokers.size():
			var id := run.jokers[i]
			if id == "loan_shark" and run.loan_debt > 0:
				continue
			var v := pval(run, id, false)
			if v < worst_v:
				worst_v = v
				worst = i
		return worst

	func _joker_step(run: BMRun) -> Dictionary:
		var full := run.jokers.size() >= run.joker_slots()
		if shop_style == "newcomer":
			if full:
				return {}
			for i in run.shop.jokers.size():
				var id: String = run.shop.jokers[i]
				if id != "" and run.credits >= BMJokers.cost(id) and pval(run, id) > 0.0:
					return run.buy_joker(i)
			return {}
		var best_i := -1
		var best_v := 0.0
		for i in run.shop.jokers.size():
			var id: String = run.shop.jokers[i]
			if id == "":
				continue
			var v := pval(run, id)
			if shop_style == "full" and run.credits < BMJokers.cost(id):
				continue
			if v > best_v:
				best_v = v
				best_i = i
		if best_i < 0:
			return {}
		var bid: String = run.shop.jokers[best_i]
		var price := BMJokers.cost(bid)
		if not full and run.credits >= price and best_v >= 15.0:
			return run.buy_joker(best_i)
		if full and shop_style == "meta":
			var w := _worst_owned_p(run)
			if w >= 0 and best_v > pval(run, run.jokers[w], false) + 20.0 \
					and run.credits + BMJokers.sell_value(run.jokers[w]) >= price:
				return run.sell_joker(w)
		return {}

	func _tool_step(run: BMRun) -> Dictionary:
		var full := run.jokers.size() >= run.joker_slots()
		var reserve := 3 if not full else 0
		for pass_i in 2:
			for i in run.shop.tools.size():
				var o: Dictionary = run.shop.tools[i]
				if o.is_empty():
					continue
				var wished := wish_tools.has(o.id)
				if pass_i == 0 and not wished:
					continue
				var cost := int(BMTools.get_def(o.id).cost)
				if run.credits - (0 if wished else reserve) < cost:
					continue
				var plan_t := persona_tool_plan(run, o)
				if plan_t.ok:
					var r := run.buy_tool(i, plan_t.targets, int(plan_t.get("color", -1)))
					if r.ok:
						purchases[o.id] = int(purchases.get(o.id, 0)) + 1
						return r
		return {}

	func _item_step(run: BMRun) -> Dictionary:
		if items_style == "never" or run.consumables.size() >= BMRunConfig.CONSUMABLE_SLOTS:
			return {}
		var full := run.jokers.size() >= run.joker_slots()
		var reserve := (reserve_items if not full else 0)
		for i in run.shop.consumables.size():
			var id: String = run.shop.consumables[i]
			if id == "":
				continue
			var key := "%d/%d" % [fill, i]
			if considered.has(key):
				continue
			if run.credits - reserve < BMConsumables.cost(id):
				continue
			considered[key] = true
			if items_style == "smart" and id == "lucky_paint" and not run.jokers.has("blue_mood"):
				continue
			if rng.randf() < item_buy:
				return run.buy_consumable(i)
		return {}

	func _pick_card(run: BMRun) -> int:
		var cards: Array = run.shop.get("round_cards", [])
		if cards.size() < 2:
			return 0
		match cards_style:
			"random":
				return rng.randi_range(0, cards.size() - 1)
			"greedy":
				var best := 0
				var best_r := 0
				for i in cards.size():
					var r := int(BMRoundCards.get_def(String(cards[i])).reward)
					if r > best_r:
						best_r = r
						best = i
				return best
			"ev":
				var slack := last_round_left
				var pref: Array
				if slack >= 0.4:
					pref = ["double_or_nothing", "tight_budget", "scholarship", "treasure_hunt", "gold_rush", "mult_fever"]
				elif slack >= 0.2:
					pref = ["gold_rush", "scholarship", "treasure_hunt", "rush_hour", "mult_fever"]
				else:
					pref = ["rush_hour", "gold_rush"]
				for want in pref:
					if want == "treasure_hunt" and run.consumables.size() >= BMRunConfig.CONSUMABLE_SLOTS:
						continue
					var k := cards.find(want)
					if k > 0:
						return k
		return 0


# --- Driver --------------------------------------------------------------------------------

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "population"
	var count := int(args[1]) if args.size() > 1 else 10
	var first := int(args[2]) if args.size() > 2 else 1
	var out := args[3] if args.size() > 3 else "user://study_%s.json" % mode
	var runs_each := int(args[4]) if args.size() > 4 else 3
	var results: Array = []
	var started := Time.get_ticks_msec()
	if mode == "population":
		for p in count:
			var pid := first + p
			var t := sample_participant(pid)
			for k in runs_each:
				var seed_value := 50000 + pid * 17 + k * 7919
				var rec := play(t, seed_value)
				results.append(rec)
			print("participant %d (%s): %s, %.0f s" % [pid, t.archetype, ", ".join(results.slice(results.size() - runs_each).map(func(r): return "W" if r.won else str(r.round))), (Time.get_ticks_msec() - started) / 1000.0])
	else:
		if not ARMS.has(mode):
			push_error("Unknown arm %s. Options: population, %s" % [mode, ", ".join(ARMS.keys())])
			quit(1)
			return
		var t := BASE_ARM.duplicate()
		t.merge(ARMS[mode], true)
		t.archetype = mode
		t.pid = mode
		for i in count:
			var rec := play(t, first + i)
			results.append(rec)
			print("%s seed %d: %s round %d, %.0f s" % [mode, first + i, "WON" if rec.won else "lost", rec.round, (Time.get_ticks_msec() - started) / 1000.0])
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"mode": mode, "runs": results}))
	f.close()
	quit()


## A synthetic playtest participant: an archetype plus sampled habits (seeded by the id).
static func sample_participant(pid: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash("study-participant-%d" % pid)
	var roll := r.randf()
	var t := {"pid": str(pid), "reserve": 3, "variant": ""}
	var fav_keys: Array = FAVORITES.keys()
	if roll < 0.20:
		t.archetype = "first_timer"
		t.placement = "casual"
		t.shop = "newcomer"
		t.items = "hoarder" if r.randf() < 0.6 else "impulse"
		t.item_buy = 0.3
		t.cards = "standard" if r.randf() < 0.7 else "random"
		t.dup = "neutral"
		t.favorites = ""
		t.rerolls = 0
		t.locked = true
	elif roll < 0.45:
		t.archetype = "casual_regular"
		t.placement = "smart"
		t.shop = "full" if r.randf() < 0.5 else "newcomer"
		var x := r.randf()
		t.items = "hoarder" if x < 0.5 else ("impulse" if x < 0.75 else "smart")
		t.item_buy = 0.25
		t.cards = "random" if r.randf() < 0.5 else "greedy"
		t.dup = "stack" if r.randf() < 0.4 else "neutral"
		t.favorites = ""
		t.rerolls = 0
		t.locked = r.randf() < 0.5
	elif roll < 0.75:
		t.archetype = "engaged"
		t.placement = "expert_lite"
		t.shop = "meta"
		var x := r.randf()
		t.items = "hoarder" if x < 0.4 else ("smart" if x < 0.8 else "never")
		t.item_buy = 0.2
		var c := r.randf()
		t.cards = "ev" if c < 0.5 else ("standard" if c < 0.8 else "greedy")
		var d := r.randf()
		t.dup = "stack" if d < 0.5 else ("avoid" if d < 0.7 else "neutral")
		t.favorites = fav_keys[r.randi_range(0, fav_keys.size() - 1)]
		t.rerolls = r.randi_range(0, 3)
		t.locked = r.randf() < 0.3
	elif roll < 0.90:
		t.archetype = "expert"
		t.placement = "expert"
		t.shop = "meta"
		var x := r.randf()
		t.items = "smart" if x < 0.5 else ("savvy" if x < 0.8 else "hoarder")
		t.item_buy = 0.35
		t.cards = "ev" if r.randf() < 0.7 else "greedy"
		t.dup = "stack" if r.randf() < 0.6 else "neutral"
		t.favorites = fav_keys[r.randi_range(0, fav_keys.size() - 1)]
		t.rerolls = r.randi_range(1, 4)
		t.locked = false
	else:
		t.archetype = "item_lover"
		t.placement = "smart" if r.randf() < 0.5 else "expert_lite"
		t.shop = "meta"
		t.items = "savvy"
		t.item_buy = 0.8
		t.reserve = 0
		t.cards = "ev" if r.randf() < 0.5 else "random"
		t.dup = "neutral"
		t.favorites = ""
		t.rerolls = 1
		t.locked = r.randf() < 0.5
	return t


func play(t: Dictionary, seed_value: int) -> Dictionary:
	var bot := Participant.new(t, seed_value)
	var locked: Array = BMJokers.locked_for({}) if bool(t.get("locked", false)) else []
	var run := BMRun.new_run(seed_value, String(t.get("kit", "standard")), 0, locked)
	var variant := String(t.get("variant", ""))
	var rec := {"seed": seed_value, "pid": String(t.pid), "archetype": String(t.archetype), "traits": t.duplicate(),
		"won": false, "round": 0, "end_reason": "", "rounds": [], "shops": [], "placements": 0, "clears": 0,
		"multi": 0, "peak": 0, "hands": {}, "feats": {}, "refreshes": 0, "holds": 0,
		"items_obtained": [], "items_used": [], "items_end": [], "joker_offers": [], "joker_buys": [],
		"joker_sells": [], "crates": [], "max_copies": 1, "dup_ids": [], "final_jokers": [], "time_s": 0.0}
	var owned_rounds := {}
	var shop_entry := {}
	var round_log := {}
	var last_offered: Array = []
	var prev_visit_offers: Array = []
	for step in 60000:
		if run.phase == BMRun.Phase.RUN_WON:
			if not rec.won:
				rec.won = true
			if not bool(t.get("overtime", false)) or run.overtime or not run.start_overtime().ok:
				break
			continue
		if run.phase in [BMRun.Phase.RUN_LOST, BMRun.Phase.ABANDONED]:
			break
		if run.round_number > 40:
			break
		# A new round: open its log.
		if run.phase == BMRun.Phase.ROUND and round_log.is_empty():
			round_log = {"round": run.round_number, "card": run.round_card, "boss": run.current_boss(),
				"clears": 0, "multi": 0, "peak": 0, "big": 0, "streak": 0, "max_dry": 0, "refreshes": 0,
				"holds": 0, "items": 0, "stuck": 0, "placements": 0}
		# A new shop visit (or a reroll): log the offers, after the shop variant rewrites them.
		if run.phase == BMRun.Phase.SHOP and shop_entry.is_empty():
			prev_visit_offers = last_offered.duplicate()
			_apply_variant(run, variant, prev_visit_offers)
			last_offered = run.shop.jokers.duplicate()
			shop_entry = {"round": run.round_number, "credits": run.credits, "fills": [_snapshot(run)],
				"bought": [], "sold": [], "rerolls": 0, "cards": run.shop.get("round_cards", []).duplicate(),
				"card": "standard", "affordable_jokers": _affordable_jokers(run), "jokers_in": run.jokers.size(),
				"slots": run.joker_slots()}
			if run.has_crate():
				rec.crates.append({"round": run.round_number, "offer": run.shop.crate.duplicate(true)})
		var before_phase := run.phase
		var rnd := run.round_number
		var credits_before := run.credits
		var items_before := run.consumables.duplicate()
		var status_before := String(run.round_state.status)
		if before_phase == BMRun.Phase.ROUND and status_before == BMRun.STUCK:
			round_log.stuck += 1
		var used_before := bot.item_log.size()
		var r := bot.act(run)
		if r.is_empty() or not r.ok:
			rec.end_reason = "bot error: %s" % str(r.get("error", "no action"))
			break
		var typ := String(r.get("type", ""))
		# Items that arrived without a purchase (crate, Vending Machine, Treasure Hunt, Memory, Draftsman).
		var gained := _new_items(items_before, run.consumables, typ, r)
		var ended := before_phase == BMRun.Phase.ROUND and run.phase != BMRun.Phase.ROUND
		for g in gained:
			rec.items_obtained.append({"id": g, "round": rnd, "source": "round_reward" if ended and typ == "place" else _item_source(typ, r, g)})
		if bot.item_log.size() > used_before:
			var e: Dictionary = bot.item_log[bot.item_log.size() - 1]
			rec.items_used.append(e)
			if before_phase == BMRun.Phase.ROUND:
				round_log.items += 1
		match typ:
			"place":
				rec.placements += 1
				round_log.placements += 1
				var pts := int(r.points)
				rec.peak = maxi(rec.peak, pts)
				round_log.peak = maxi(round_log.peak, pts)
				if pts >= int(r.target) * 0.25:
					round_log.big += 1
				if int(r.lines) > 0:
					rec.clears += 1
					round_log.clears += 1
					round_log.streak = 0
				else:
					round_log.streak += 1
					round_log.max_dry = maxi(round_log.max_dry, round_log.streak)
				if int(r.lines) >= 2:
					rec.multi += 1
					round_log.multi += 1
				for ft in r.get("feats", []):
					rec.feats[ft] = int(rec.feats.get(ft, 0)) + 1
				var hand := String(r.shape.get("hand", ""))
				if hand != "":
					rec.hands[hand] = int(rec.hands.get(hand, 0)) + 1
			"refresh":
				rec.refreshes += 1
				round_log.refreshes += 1
			"hold":
				rec.holds += 1
				round_log.holds += 1
			"buy_joker":
				var id := String(r.item)
				var copies := run.jokers.count(id)
				rec.joker_buys.append({"id": id, "round": rnd, "copies": copies, "price": int(r.price)})
				shop_entry.bought.append({"kind": "joker", "id": id, "price": int(r.price)})
				if copies >= 2 and not rec.dup_ids.has(id):
					rec.dup_ids.append(id)
				rec.max_copies = maxi(rec.max_copies, copies)
			"crate":
				var o: Dictionary = r.offer
				rec.crates[rec.crates.size() - 1].pick = String(o.kind)
				if String(o.kind) == "joker":
					var copies := run.jokers.count(String(o.id))
					rec.joker_buys.append({"id": String(o.id), "round": rnd, "copies": copies, "price": 0, "crate": true})
					if copies >= 2 and not rec.dup_ids.has(String(o.id)):
						rec.dup_ids.append(String(o.id))
					rec.max_copies = maxi(rec.max_copies, copies)
			"buy_tool":
				shop_entry.bought.append({"kind": "tool", "id": String(r.item), "price": int(r.price)})
			"buy_piece":
				var p: Dictionary = r.piece
				shop_entry.bought.append({"kind": "piece", "id": "%s/%s/%s" % [p.family, p.material, p.stamp], "price": int(r.price)})
			"buy_consumable":
				shop_entry.bought.append({"kind": "item", "id": String(r.item), "price": int(r.price)})
			"sell":
				shop_entry.sold.append(String(r.item))
				rec.joker_sells.append({"id": String(r.item), "round": rnd, "held": int(owned_rounds.get(String(r.item), 0))})
			"reroll":
				shop_entry.rerolls += 1
				_apply_variant(run, variant, prev_visit_offers)
				shop_entry.fills.append(_snapshot(run))
			"pick_round":
				shop_entry.card = String(r.card)
			"leave_shop":
				shop_entry.left_with = run.credits
				shop_entry.spent = shop_entry.credits - run.credits
				rec.shops.append(shop_entry)
				shop_entry = {}
		if before_phase == BMRun.Phase.ROUND and run.phase != BMRun.Phase.ROUND:
			var rs := run.round_state
			var won := run.phase in [BMRun.Phase.ROUND_RESULT, BMRun.Phase.RUN_WON]
			round_log.target = rs.target
			round_log.score = rs.score
			round_log.won = won
			round_log.left = rs.placements_left
			round_log.cap = rs.placement_cap
			round_log.jokers = run.jokers.duplicate()
			round_log.items_held = run.consumables.duplicate()
			round_log.credits = run.credits
			rec.rounds.append(round_log)
			bot.last_round_left = float(rs.placements_left) / maxf(1.0, float(rs.placement_cap))
			for id in run.jokers:
				owned_rounds[id] = int(owned_rounds.get(id, 0)) + 1
			round_log = {}
			if not won and rec.end_reason == "":
				rec.end_reason = run.end_reason
	rec.round = BMRunConfig.ROUND_COUNT if rec.won else run.round_number
	if rec.end_reason == "":
		rec.end_reason = run.end_reason
	rec.final_jokers = run.jokers.duplicate()
	rec.items_end = run.consumables.duplicate()
	rec.owned_rounds = owned_rounds
	rec.joker_stats = bot.joker_stats.duplicate(true)
	rec.tools = bot.purchases.duplicate()
	rec.bag = run.bag.size()
	rec.upgraded = BMBag.upgraded_count(run)
	rec.stats = run.stats.duplicate()
	rec.credits_end = run.credits
	rec.time_s = rec.placements * 5.0 + rec.shops.size() * 35.0 + rec.rounds.size() * 8.0 + rec.items_used.size() * 6.0
	return rec


static func _snapshot(run: BMRun) -> Dictionary:
	var tools: Array = []
	for o in run.shop.tools:
		tools.append("" if o.is_empty() else String(o.id))
	var pieces: Array = []
	for d in run.shop.pieces:
		pieces.append("" if d.is_empty() else "%s/%s/%s" % [d.family, d.material, d.stamp])
	var owned: Array = []
	for id in run.shop.jokers:
		owned.append(id != "" and run.jokers.has(id))
	return {"jokers": run.shop.jokers.duplicate(), "owned": owned, "items": run.shop.consumables.duplicate(),
		"tools": tools, "pieces": pieces}


static func _affordable_jokers(run: BMRun) -> int:
	var n := 0
	for id in run.shop.jokers:
		if id != "" and run.credits >= BMJokers.cost(id):
			n += 1
	return n


## Harness-only shop variants (the game is unchanged): "no_owned" never offers a non-unique
## Joker the player owns; "fresh" also avoids the Jokers shown on the previous visit.
static func _apply_variant(run: BMRun, variant: String, prev: Array) -> void:
	if variant == "":
		return
	var offers: Array = run.shop.jokers
	for i in offers.size():
		var id: String = offers[i]
		if id == "":
			continue
		var bad := run.jokers.has(id) or (variant == "fresh" and prev.has(id))
		if not bad:
			continue
		var exclude: Array[String] = []
		for o in offers:
			if o != "":
				exclude.append(o)
		for o in run.jokers:
			exclude.append(o)
		if variant == "fresh":
			for o in prev:
				if o != "":
					exclude.append(o)
		var pick := run._pick_joker(int(BMJokers.get_def(id).rarity), exclude)
		if pick == "":
			for rr in [BMJokers.UNCOMMON, BMJokers.COMMON, BMJokers.RARE]:
				pick = run._pick_joker(rr, exclude)
				if pick != "":
					break
		if pick != "":
			offers[i] = pick


static func _new_items(before: Array, after: Array, typ: String, r: Dictionary) -> Array:
	var left := before.duplicate()
	var out: Array = []
	for id in after:
		var k := left.find(id)
		if k >= 0:
			left.remove_at(k)
		else:
			out.append(id)
	return out


static func _item_source(typ: String, r: Dictionary, id: String) -> String:
	match typ:
		"buy_consumable":
			return "shop"
		"crate":
			return "crate"
		"place":
			return "memory" if id == "spark" else ("draftsman" if id == "eraser" else "placement")
	return typ
