extends SceneTree
## Persona playtests (docs/playtests/): simulated players with different skill levels and build
## goals play the same seeds, and every run is logged for the design report.
##   godot --headless --path . --script res://tools/playtest.gd -- <persona> [runs=40] [first_seed=1] [out=user://playtest_<persona>.json]
## Personas are listed in PERSONAS. Won runs continue into Overtime until they lose (or round 60).
## Output: one JSON object per run (rounds, placements, shop visits, final build). Aggregate with
## `python tools/playtest_report.py <json files...>`. Dev-only; it never touches saves.

const PERSONAS := {
	# Skill ladder (same shop brain, different hands).
	"random": {"placement": "random", "shop": "none",
		"about": "Places a random legal piece anywhere. Never shops. The floor."},
	"newcomer": {"placement": "casual", "shop": "newcomer",
		"about": "Clears lines when it sees them, otherwise places loosely. Buys the first Joker it can afford."},
	"steady": {"placement": "smart", "shop": "full",
		"about": "The existing balance bot: one-placement preview plus a one-step lookahead. Buys by rarity."},
	"planner": {"placement": "expert", "shop": "meta",
		"about": "Searches whole-tray sequences with the real resolver. Buys the strongest known cards, sells weak ones, rerolls."},
	# Build goals (planner hands, focused shopping).
	"line_hunter": {"placement": "expert", "shop": "meta",
		"jokers": ["jackpot_window", "wide_awake", "compound_interest", "keystone", "chain_link", "crossbar", "showboat", "patience", "clean_sweep", "first_strike"],
		"tools": ["encore_stamp", "neon_tubing", "refund_stamp"],
		"about": "Chases multi-line clears and combos: Jackpot Window, Wide Awake, Compound Interest, Encore."},
	"painter": {"placement": "expert", "shop": "meta",
		"jokers": ["blue_mood", "color_cycle", "hot_hand", "showboat", "golden_ratio"],
		"tools": ["repaint", "prism_coat"],
		"about": "Color build: Blue Mood, Color Cycle, Repaint to blue, Prism."},
	"engineer": {"placement": "expert", "shop": "meta",
		"jokers": ["specialist", "foundry", "collector", "hoarder", "recycler", "pressure_cooker", "postmaster"],
		"tools": ["schematic", "chrome_plating", "encore_stamp", "copier", "neon_tubing"],
		"about": "Bag engine: Schematics, Chrome, Encore, Foundry, Specialist."},
	"minimalist": {"placement": "expert", "shop": "meta",
		"jokers": ["lean_bag", "specialist", "square_deal", "recycler", "hollow_point"],
		"tools": ["shredder", "schematic", "encore_stamp"], "shred": true,
		"about": "Thin bag: Shredder down to 12 pieces, Lean Bag, Schematics on what is left."},
	"glassblower": {"placement": "expert", "shop": "meta",
		"jokers": ["glass_cannon", "breakage_bonus", "foundry", "compound_interest"],
		"tools": ["glassworks", "encore_stamp", "copier"],
		"about": "Glass build: Glassworks, Glass Cannon, Breakage Bonus."},
	"tycoon": {"placement": "expert", "shop": "meta",
		"jokers": ["loan_shark", "spare_parts", "overflow", "recycler", "pressure_cooker", "foundry"],
		"tools": ["tip_stamp", "gold_leaf", "refund_stamp"], "items": ["cash_out"], "rerolls": 4,
		"about": "Economy first: Loan Shark, Spare Parts, Tip and Gold, then rerolls for rares."},
	"gambler": {"placement": "expert", "shop": "meta", "kit": "tetromino",
		"jokers": ["hot_hand", "card_sharp", "square_deal", "golden_ratio", "countdown"],
		"tools": ["schematic", "encore_stamp"],
		"about": "Tetromino Kit and Tray Hands: Hot Hand, Card Sharp, Square Deal."},
	# Kit sweep (planner play).
	"kit_compact": {"placement": "expert", "shop": "meta", "kit": "compact", "about": "Planner with the Compact Kit."},
	"kit_high_roller": {"placement": "expert", "shop": "meta", "kit": "high_roller", "about": "Planner with the High Roller Kit."},
	"kit_chunky": {"placement": "expert", "shop": "meta", "kit": "chunky", "about": "Planner with the Chunky Kit."},
	"kit_tetromino": {"placement": "expert", "shop": "meta", "kit": "tetromino", "about": "Planner with the Tetromino Kit."},
	# Opportunity probes: how often a 2+ or 3+ line clear is on offer at all.
	"probe_steady": {"placement": "smart", "shop": "full", "probe": true, "about": "Steady, logging multi-line opportunities."},
	"probe_planner": {"placement": "expert", "shop": "meta", "probe": true, "about": "Planner, logging multi-line opportunities."},
	# Ceiling probes: a finished build handed over at round 1 (not a fair run; it measures how
	# far the scoring engine can go at all).
	"dream_mixed": {"placement": "expert", "shop": "meta",
		"start_jokers": ["jackpot_window", "compound_interest", "hot_hand", "golden_ratio", "color_cycle"],
		"jokers": ["jackpot_window", "compound_interest", "hot_hand", "golden_ratio", "color_cycle"],
		"tools": ["encore_stamp", "glassworks", "neon_tubing"],
		"about": "Ceiling probe: starts with the five strongest xMult Jokers."},
	"dream_legend": {"placement": "expert", "shop": "meta",
		"start_jokers": ["hall_of_mirrors", "supernova", "avalanche", "snowball", "jackpot_window"],
		"jokers": ["hall_of_mirrors", "supernova", "avalanche", "philosophers_stone", "snowball", "hot_streak"],
		"tools": ["encore_stamp", "glassworks", "neon_tubing", "rack_extender"],
		"about": "Ceiling probe: three Legendaries (Mirrors, Supernova, Avalanche) plus Snowball and Jackpot Window from round 1."},
	"dream_dupes": {"placement": "expert", "shop": "meta",
		"start_jokers": ["compound_interest", "compound_interest", "compound_interest", "hot_hand", "hot_hand"],
		"jokers": ["compound_interest", "hot_hand"],
		"tools": ["encore_stamp", "glassworks", "neon_tubing"],
		"about": "Ceiling probe: three Compound Interest and two Hot Hand (duplicates stack)."},
}

## General card sense for the "meta" shopper (a player who has read the cards and seen them
## work): a base value per Joker. Cards the bots cannot operate (Patch Panel, Periscope) are 0.
const META_VALUE := {
	"recycler": 70, "foundry": 70, "pressure_cooker": 65, "color_cycle": 60, "collector": 60,
	"compound_interest": 60, "blue_mood": 50, "patience": 50, "chain_link": 45, "hollow_point": 45,
	"hoarder": 45, "hot_hand": 50, "jackpot_window": 55, "wide_awake": 45, "golden_ratio": 45,
	"showboat": 40, "straight_edge": 35, "last_piece": 35, "clean_sweep": 35, "corner_office": 30,
	"small_change": 30, "neon_sign": 30, "insurance_policy": 45, "architect": 25, "long_game": 25,
	"square_deal": 25, "heavy_hand": 20, "spare_parts": 25, "neat_freak": 25, "first_strike": 25,
	"countdown": 25, "full_tank": 25, "postmaster": 15, "glass_cannon": 30, "mimic": 40,
	"specialist": 25, "lean_bag": 15, "keystone": 30, "last_stand": 20, "mirror_maze": 20,
	"loan_shark": 20, "overflow": 15, "crossbar": 30, "second_look": 20, "tiny_insurance": 25,
	"breakage_bonus": 10, "draftsman": 5, "card_sharp": 10, "fire_sale": 10,
	"patch_panel": 0, "periscope": 0, "locksmith": 25,
	# Engine update (2026-09-24).
	"snowball": 55, "tally_counter": 40, "bonsai": 55, "coin_pusher": 40, "hot_streak": 60,
	"big_game_hunter": 35, "rainbow_road": 35, "solo_act": 20, "double_stamp": 30,
	"vending_machine": 30, "demolition_crew": 45, "overachiever": 50, "full_pockets": 35,
	"avalanche": 200, "hall_of_mirrors": 220, "philosophers_stone": 180, "supernova": 210,
}


class Persona extends BMAutoplayer:
	var placement := "smart"
	var shop_style := "full"
	var wish_jokers: Array = []
	var wish_tools: Array = []
	var wish_items: Array = []
	var shred := false
	var max_rerolls := 2
	var noise := 220.0
	var rng := RandomNumberGenerator.new()
	var widths := [7, 4, 3]
	## Planned rest of the tray: [{slot, anchor, uid}]
	var plan: Array = []
	var rerolls_this_shop := 0
	var last_candidates := 0
	var shop_round := -1

	func _init(cfg: Dictionary, seed_value: int) -> void:
		placement = String(cfg.get("placement", "smart"))
		shop_style = String(cfg.get("shop", "full"))
		shop_policy = "none" if shop_style == "none" else "full"
		wish_jokers = cfg.get("jokers", [])
		wish_tools = cfg.get("tools", [])
		wish_items = cfg.get("items", [])
		shred = bool(cfg.get("shred", false))
		max_rerolls = int(cfg.get("rerolls", 2))
		rng.seed = hash("persona%d" % seed_value)

	# --- Placement ------------------------------------------------------------------------

	func _all_candidates(run: BMRun) -> Array:
		var out: Array = []
		for slot in run.tray.size():
			var piece: Dictionary = run.tray[slot]
			if piece.is_empty() or run.slot_locked(slot):
				continue
			for anchor in run.board.legal_anchors(piece.cells):
				out.append(_heuristic(run, slot, anchor))
		return out

	func choose_placement(run: BMRun) -> Dictionary:
		match placement:
			"random":
				var c := _all_candidates(run)
				last_candidates = c.size()
				return {} if c.is_empty() else c[rng.randi_range(0, c.size() - 1)]
			"casual":
				var c := _all_candidates(run)
				last_candidates = c.size()
				if c.is_empty():
					return {}
				var best := {}
				var best_v := -INF
				for x in c:
					# Sees a clear right away; otherwise a loose, noisy sense of "tidy".
					var v: float = x.lines * 400.0 + x.quality * 0.5 + rng.randfn(0.0, noise)
					if v > best_v:
						best_v = v
						best = x
				return best
			"expert":
				return _expert(run)
		var r := super.choose_placement(run)
		return r

	func _expert(run: BMRun) -> Dictionary:
		# Follow the plan made for this tray while its pieces are still there (a step stays at
		# the head until its piece has left the tray, since the round step may use an item first).
		while not plan.is_empty():
			var step: Dictionary = plan[0]
			var slot: int = step.slot
			if slot < run.tray.size() and not run.tray[slot].is_empty() and int(run.tray[slot].uid) == int(step.uid) \
					and run.is_legal(slot, step.anchor):
				return step
			plan.pop_front()
		var res := {"value": -INF, "seq": [], "stuck": false}
		_search(run, [], 0.0, 0, _tray_count(run), res)
		last_candidates = _all_candidates(run).size()
		if res.seq.is_empty():
			return {}
		plan = res.seq.duplicate(true)
		plan[0].dead_end = bool(res.stuck)
		return plan[0]

	static func _tray_count(run: BMRun) -> int:
		var n := 0
		for i in run.tray.size():
			if not run.tray[i].is_empty() and not run.slot_locked(i):
				n += 1
		return n

	func _search(state: BMRun, seq: Array, acc: float, depth: int, max_depth: int, res: Dictionary) -> void:
		var cands: Array = []
		if depth < max_depth and state.phase == BMRun.Phase.ROUND and state.round_state.status == BMRun.PLAYING:
			cands = _all_candidates(state)
		if cands.is_empty():
			var leaf := acc + _board_value(state, depth, max_depth)
			if leaf > res.value:
				res.value = leaf
				res.seq = seq
				res.stuck = depth < max_depth
			return
		cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.h > b.h)
		for i in mini(widths[mini(depth, widths.size() - 1)], cands.size()):
			var c: Dictionary = cands[i]
			var s := state.clone()
			var uid := int(s.tray[c.slot].uid)
			var r := s.place(c.slot, c.anchor)
			if not r.ok:
				continue
			var gained := float(r.points)
			var step := {"slot": c.slot, "anchor": c.anchor, "uid": uid, "lines": int(r.lines), "dead_end": false}
			if s.phase != BMRun.Phase.ROUND or r.get("round_won", false):
				# Crossing the target: finishing sooner keeps placements for the payout.
				var won := s.phase in [BMRun.Phase.ROUND_RESULT, BMRun.Phase.RUN_WON]
				var leaf := acc + gained + (1.0e7 - depth * 1.0e5 if won else -1.0e7)
				if leaf > res.value:
					res.value = leaf
					res.seq = seq + [step]
					res.stuck = false
				continue
			# A new tray was dealt: the plan ends here.
			var next_depth := depth + 1
			if _tray_count(s) >= max_depth - depth and depth + 1 < max_depth:
				next_depth = max_depth
			_search(s, seq + [step], acc + gained, next_depth, max_depth, res)

	## Board health after the planned pieces. It never reads the next tray (a new tray dealt in
	## the search is hidden information for a human without Periscope).
	func _board_value(s: BMRun, depth: int, max_depth: int) -> float:
		if s.phase == BMRun.Phase.RUN_LOST:
			return -1.0e7
		var holes := BMAutoplayer._isolated_holes(s.board)
		var v := -holes * 45.0 + s.board.empty_count() * 6.0
		# Pieces of this tray that found no place: the tray is stuck.
		if depth < max_depth:
			v -= 900.0
		# Placements still in hand matter as much as the points they can earn.
		v += s.round_state.placements_left * 20.0
		v += BMAutoplayer._line_potential(s.board) * 8.0
		return v

	# --- Shop -----------------------------------------------------------------------------

	func joker_value(id: String) -> float:
		if id == "":
			return -1.0
		var v := float(META_VALUE.get(id, 20))
		var w := wish_jokers.find(id)
		if w >= 0:
			v += 100.0 - w * 6.0
		return v

	func _worst_owned(run: BMRun) -> int:
		var worst := -1
		var worst_v := INF
		for i in run.jokers.size():
			var id := run.jokers[i]
			if id == "loan_shark" and run.loan_debt > 0:
				continue
			var v := joker_value(id)
			if v < worst_v:
				worst_v = v
				worst = i
		return worst

	func _shop_step(run: BMRun) -> Dictionary:
		if run.round_number != shop_round:
			shop_round = run.round_number
			rerolls_this_shop = 0
		match shop_style:
			"none":
				if run.has_crate():
					return run.open_crate(2)
				return run.leave_shop()
			"newcomer":
				return _newcomer_shop(run)
			"meta":
				return _meta_shop(run)
		return super._shop_step(run)

	func _newcomer_shop(run: BMRun) -> Dictionary:
		if run.has_crate():
			var take := 0 if run.jokers.size() < run.joker_slots() else 2
			return run.open_crate(take)
		for i in run.shop.jokers.size():
			var id: String = run.shop.jokers[i]
			if id != "" and run.credits >= BMJokers.cost(id) and run.jokers.size() < run.joker_slots():
				return run.buy_joker(i)
		for i in run.shop.consumables.size():
			var id: String = run.shop.consumables[i]
			if id != "" and id in BOT_ITEMS and run.credits >= BMConsumables.cost(id) + 3 \
					and run.consumables.size() < BMRunConfig.CONSUMABLE_SLOTS and rng.randf() < 0.5:
				return run.buy_consumable(i)
		return run.leave_shop()

	func _meta_shop(run: BMRun) -> Dictionary:
		var full := run.jokers.size() >= run.joker_slots()
		if run.has_crate():
			var cj: String = run.shop.crate[0].id
			var cw := _worst_owned(run)
			if cj != "" and (not full or (cw >= 0 and joker_value(cj) > joker_value(run.jokers[cw]) + 10)):
				if full:
					return run.sell_joker(cw)
				return run.open_crate(0)
			return run.open_crate(2)
		# Jokers: best value first; replace the weakest when full.
		var best_i := -1
		var best_v := 0.0
		for i in run.shop.jokers.size():
			var id: String = run.shop.jokers[i]
			if id == "":
				continue
			var v := joker_value(id)
			if v > best_v:
				best_v = v
				best_i = i
		if best_i >= 0:
			var id: String = run.shop.jokers[best_i]
			var price := BMJokers.cost(id)
			if not full and run.credits >= price and best_v >= 15.0:
				return run.buy_joker(best_i)
			if full:
				var w := _worst_owned(run)
				if w >= 0 and best_v > joker_value(run.jokers[w]) + 20.0 \
						and run.credits + BMJokers.sell_value(run.jokers[w]) >= price:
					return run.sell_joker(w)
		# Wished Workshop cards, then the general ones.
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
		# Reroll for wished Jokers while slots are open (or a wishlist upgrade is possible).
		var want_more := not wish_jokers.is_empty() or not full
		var reroll_cost := int(run.shop.get("reroll_cost", BMRunConfig.REROLL_BASE))
		if want_more and rerolls_this_shop < max_rerolls and run.credits >= reroll_cost + 5 and run.round_number >= 2:
			rerolls_this_shop += 1
			return run.reroll_shop()
		for i in run.shop.pieces.size():
			var d: Dictionary = run.shop.pieces[i]
			if d.is_empty() or shred or run.credits - reserve < int(d.cost) or run.bag.size() >= 30:
				continue
			if String(d.material) != "" or String(d.stamp) != "":
				purchases["piece"] = int(purchases.get("piece", 0)) + 1
				return run.buy_piece(i)
		for i in run.shop.consumables.size():
			var id: String = run.shop.consumables[i]
			var usable := id in BOT_ITEMS or wish_items.has(id)
			if id != "" and usable and run.credits - reserve >= BMConsumables.cost(id) + 1 \
					and run.consumables.size() < BMRunConfig.CONSUMABLE_SLOTS:
				return run.buy_consumable(i)
		return run.leave_shop()

	func persona_tool_plan(run: BMRun, offer: Dictionary) -> Dictionary:
		var def := BMTools.get_def(offer.id)
		var by_size := run.bag.duplicate()
		by_size.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.cells.size() > b.cells.size() or (a.cells.size() == b.cells.size() and int(a.uid) < int(b.uid)))
		match def.kind:
			"remove":
				if shred:
					var t: Array = []
					for p in by_size:
						if t.size() < 2 and not BMPieces.is_upgraded(p) and run.bag.size() - t.size() > BMPieces.MIN_BAG:
							t.append(int(p.uid))
					return {"ok": not t.is_empty(), "targets": t}
			"repaint":
				var color := BMShapes.COLOR_BLUE
				if run.jokers.has("blue_mood") or wish_jokers.has("blue_mood"):
					var t: Array = []
					for p in by_size:
						if int(p.color) != color and t.size() < 3:
							t.append(int(p.uid))
					return {"ok": not t.is_empty(), "targets": t, "color": color}
			"schematic":
				# Level the family that shows up most (the one you will place most).
				var count := 0
				var most := 0
				var fams := {}
				for p in run.bag:
					fams[String(p.family)] = int(fams.get(String(p.family), 0)) + 1
				for f in fams:
					most = maxi(most, fams[f])
				count = int(fams.get(String(offer.family), 0))
				return {"ok": count >= 3 and (count >= most - 1 or run.family_level(offer.family) > 0), "targets": []}
			"material":
				if def.value == "prism" and wish_tools.has("prism_coat"):
					var t: Array = []
					for p in by_size:
						if p.material == "" and t.size() < int(def.max_targets):
							t.append(int(p.uid))
					return {"ok": not t.is_empty(), "targets": t}
		return BMAutoplayer.tool_plan(run, offer)


# --- Driver --------------------------------------------------------------------------------

const MAX_ROUND := 60


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var persona := args[0] if args.size() > 0 else "steady"
	var runs := int(args[1]) if args.size() > 1 else 40
	var first := int(args[2]) if args.size() > 2 else 1
	var out := args[3] if args.size() > 3 else "user://playtest_%s.json" % persona
	if not PERSONAS.has(persona):
		push_error("Unknown persona %s. Options: %s" % [persona, ", ".join(PERSONAS.keys())])
		quit(1)
		return
	var cfg: Dictionary = PERSONAS[persona]
	var results: Array = []
	var started := Time.get_ticks_msec()
	for i in runs:
		var rec := play_one(persona, cfg, first + i)
		results.append(rec)
		print("%s seed %d: %s round %d%s, peak %d, %.0f s" % [persona, first + i, "WON" if rec.won else "lost",
			rec.campaign_round, (" overtime %d" % rec.overtime_round) if rec.won else "", rec.peak_points,
			(Time.get_ticks_msec() - started) / 1000.0])
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"persona": persona, "about": cfg.about, "kit": cfg.get("kit", "standard"), "runs": results}))
	f.close()
	quit()


func play_one(persona: String, cfg: Dictionary, seed_value: int) -> Dictionary:
	var bot := Persona.new(cfg, seed_value)
	var run := BMRun.new_run(seed_value, String(cfg.get("kit", "standard")))
	if cfg.has("start_jokers"):
		run.jokers.assign(cfg.start_jokers)
	var rec := {"seed": seed_value, "persona": persona, "won": false, "campaign_round": 0, "overtime_round": 0,
		"broken": false, "rounds": [], "shops": [], "peak_points": 0, "peak_mult": 0.0, "peak_xmult": 1.0,
		"peak_ot_points": 0, "placements": 0, "clears": 0, "multi": 0, "triple": 0, "hype": 0,
		"feats": {}, "hands": {}, "refreshes": 0, "stuck": 0, "items_used": 0, "candidates": 0,
		"forced": 0, "sells": 0, "rerolls": 0, "end_reason": "", "bosses": [], "jokers_at": {}}
	var shop_entry := {}
	var round_points: Array = []
	var round_multi := 0
	var round_peak := 0
	for step in 40000:
		if run.phase == BMRun.Phase.RUN_WON:
			if not rec.won:
				rec.won = true
				rec.campaign_round = BMRunConfig.ROUND_COUNT
				rec.jokers_at["win"] = run.jokers.duplicate()
			if run.machine_broken:
				rec.broken = true
				break
			if run.overtime or not run.start_overtime().ok:
				break
			continue
		if run.phase in [BMRun.Phase.RUN_LOST, BMRun.Phase.ABANDONED]:
			break
		if run.round_number > MAX_ROUND:
			break
		if run.phase == BMRun.Phase.SHOP and shop_entry.is_empty():
			shop_entry = {"round": run.round_number, "credits": run.credits, "bought": 0, "spent": 0,
				"affordable": _affordable(run), "crate": run.has_crate(), "rerolls": 0, "sells": 0}
		var before_phase := run.phase
		var rnd := run.round_number
		var status := run.round_state.status
		if before_phase == BMRun.Phase.ROUND and status == BMRun.STUCK:
			rec.stuck += 1
		var credits_before := run.credits
		var avail := 0
		if bool(cfg.get("probe", false)) and before_phase == BMRun.Phase.ROUND and status == BMRun.PLAYING:
			for c in bot._all_candidates(run):
				avail = maxi(avail, int(c.lines))
		var r := bot.act(run)
		if r.is_empty() or not r.ok:
			rec.end_reason = "bot error: %s" % str(r.get("error", "no action"))
			break
		match String(r.get("type", "")):
			"place":
				rec.placements += 1
				if avail >= 2:
					rec.opp2 = int(rec.get("opp2", 0)) + 1
					if int(r.lines) >= 2:
						rec.took2 = int(rec.get("took2", 0)) + 1
				if avail >= 3:
					rec.opp3 = int(rec.get("opp3", 0)) + 1
				rec.candidates += bot.last_candidates
				if bot.last_candidates <= 3:
					rec.forced += 1
				var pts := int(r.points)
				round_points.append(pts)
				round_peak = maxi(round_peak, pts)
				rec.peak_points = maxi(rec.peak_points, pts)
				if BMRunConfig.is_overtime(rnd):
					rec.peak_ot_points = maxi(rec.peak_ot_points, pts)
				rec.peak_mult = maxf(rec.peak_mult, float(r.mult))
				var xm := 1.0
				for it in r.items:
					if it.kind == "xmult":
						xm *= float(it.value)
				rec.peak_xmult = maxf(rec.peak_xmult, xm)
				if int(r.lines) > 0:
					rec.clears += 1
				if int(r.lines) >= 2:
					rec.multi += 1
					round_multi += 1
				if int(r.lines) >= 3:
					rec.triple += 1
				if pts >= int(r.target) * 0.4:
					rec.hype += 1
				for ft in r.get("feats", []):
					rec.feats[ft] = int(rec.feats.get(ft, 0)) + 1
				var hand := String(r.shape.get("hand", ""))
				if hand != "":
					rec.hands[hand] = int(rec.hands.get(hand, 0)) + 1
			"refresh":
				rec.refreshes += 1
			"use":
				rec.items_used += 1
			"buy_joker", "buy_tool", "buy_piece", "buy_consumable":
				shop_entry.bought += 1
				shop_entry.spent += credits_before - run.credits
			"reroll":
				shop_entry.rerolls += 1
				shop_entry.spent += credits_before - run.credits
				rec.rerolls += 1
			"sell":
				shop_entry.sells += 1
				rec.sells += 1
			"leave_shop":
				shop_entry.left_with = run.credits
				shop_entry.jokers = run.jokers.size()
				rec.shops.append(shop_entry)
				shop_entry = {}
		if before_phase == BMRun.Phase.ROUND and run.phase != BMRun.Phase.ROUND:
			var rs := run.round_state
			var won := run.phase in [BMRun.Phase.ROUND_RESULT, BMRun.Phase.RUN_WON]
			var med := 0
			if not round_points.is_empty():
				var sorted := round_points.duplicate()
				sorted.sort()
				med = sorted[sorted.size() / 2]
			rec.rounds.append({"round": rnd, "target": rs.target, "score": rs.score, "won": won,
				"used": rs.placements_made, "left": rs.placements_left, "cap": rs.placement_cap,
				"boss": run.current_boss() if BMRunConfig.is_boss_round(rnd) else "", "multi": round_multi,
				"peak": round_peak, "median": med, "jokers": run.jokers.size(), "credits": run.credits,
				"bag": run.bag.size()})
			if BMRunConfig.is_boss_round(rnd):
				rec.bosses.append([run.current_boss(), won])
			if rnd == 4 or rnd == 8:
				rec.jokers_at[str(rnd)] = run.jokers.duplicate()
			round_points = []
			round_multi = 0
			round_peak = 0
			if not won and rec.end_reason == "":
				rec.end_reason = run.end_reason
		if run.phase == BMRun.Phase.RUN_WON and run.machine_broken:
			rec.broken = true
	if not rec.won:
		rec.campaign_round = run.round_number
	else:
		rec.overtime_round = run.round_number
	if rec.end_reason == "":
		rec.end_reason = run.end_reason
	rec.final_jokers = run.jokers.duplicate()
	rec.final_bag = run.bag.size()
	rec.upgraded = BMBag.upgraded_count(run)
	rec.levels = run.family_levels.duplicate()
	rec.stats = run.stats.duplicate()
	rec.purchases = bot.purchases.duplicate()
	rec.joker_stats = bot.joker_stats.duplicate(true)
	return rec


static func _affordable(run: BMRun) -> int:
	var n := 0
	for id in run.shop.jokers:
		if id != "" and run.credits >= BMJokers.cost(id):
			n += 1
	for o in run.shop.tools:
		if not o.is_empty() and run.credits >= int(BMTools.get_def(o.id).cost):
			n += 1
	for id in run.shop.consumables:
		if id != "" and run.credits >= BMConsumables.cost(id):
			n += 1
	for d in run.shop.pieces:
		if not d.is_empty() and run.credits >= int(d.cost):
			n += 1
	return n
