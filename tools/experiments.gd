extends SceneTree
## Content experiments with the autoplayer on paired seeds (same seeds for every variant):
##   godot --headless --path . --script res://tools/experiments.gd -- <mode> [runs=40] [first_seed=1] [out=path]
## Modes:
##   curve     per-round difficulty: win rate per round, placements used, score reached
##   jokers    every implemented Joker given at run start vs. baseline
##   upgrades  piece upgrades / bag edits applied at run start vs. baseline
##   all       curve + jokers + upgrades
## Metrics: avg round reached, win %, points per placement (PPP), trigger rate (Jokers: share of
## placements where the card scored while owned), and deltas vs. baseline. A markdown report is
## printed and written to `out` (default user://experiments.md; pass a res:// path to keep it).

var runs := 40
var first_seed := 1
var lines: PackedStringArray = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "curve"
	runs = int(args[1]) if args.size() > 1 else 40
	first_seed = int(args[2]) if args.size() > 2 else 1
	var out := args[3] if args.size() > 3 else "user://experiments.md"
	var started := Time.get_ticks_msec()
	_out("# BLOCKMANIA content experiments")
	_out("")
	_out("Mode `%s`, %d paired seeds from %d, greedy autoplayer (shop policy: full). Generated %s." % [mode, runs, first_seed, Time.get_datetime_string_from_system()])
	_out("")
	if mode in ["curve", "all"]:
		_curve()
	if mode in ["jokers", "all"]:
		_jokers()
	if mode in ["upgrades", "all"]:
		_upgrades()
	_out("")
	_out("_Elapsed: %d s_" % ((Time.get_ticks_msec() - started) / 1000))
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
	quit()


func _out(s: String) -> void:
	lines.append(s)
	print(s)


## Plays `runs` seeds with an optional setup callable applied to each fresh run.
func _batch(setup: Callable = Callable(), policy: String = "full") -> Dictionary:
	var bot := BMAutoplayer.new()
	bot.shop_policy = policy
	var res := {"rounds": 0.0, "wins": 0, "points": 0, "placements": 0, "per_round": {}, "bot": bot, "credits_spent": 0}
	for i in runs:
		var run := BMRun.new_run(first_seed + i)
		# Every variant (baseline included) re-deals round 1 after setup, so all variants see
		# identical trays and the comparison stays paired.
		if setup.is_valid():
			setup.call(run)
		run._start_round()
		var round_seen := 0
		for step in 6000:
			if run.phase == BMRun.Phase.ROUND and run.round_number != round_seen:
				round_seen = run.round_number
			var before_phase := run.phase
			var before_round := run.round_number
			var r := bot.act(run)
			if r.is_empty() or not r.ok:
				break
			if before_phase == BMRun.Phase.ROUND and run.phase != BMRun.Phase.ROUND:
				var pr: Dictionary = res.per_round.get(before_round, {"reached": 0, "won": 0, "used": 0, "score": 0})
				pr.reached += 1
				pr.score += run.round_state.score
				if run.phase == BMRun.Phase.ROUND_RESULT:
					pr.won += 1
					pr.used += run.round_state.placements_made
				res.per_round[before_round] = pr
		res.rounds += run.round_number
		if run.phase == BMRun.Phase.RUN_WON:
			res.wins += 1
		res.points += int(run.stats.total_points)
		res.placements += int(run.stats.placements)
	res.rounds /= runs
	return res


func _ppp(r: Dictionary) -> float:
	return float(r.points) / maxi(1, r.placements)


func _curve() -> void:
	_out("## Difficulty curve (baseline)")
	_out("")
	var base := _batch()
	_out("Win rate %.0f%%, average round reached %.2f, points per placement %.1f." % [100.0 * base.wins / runs, base.rounds, _ppp(base)])
	_out("")
	_out("| Round | Target | Reached | Cleared | Clear % | Avg placements to clear | Avg final score |")
	_out("|---:|---:|---:|---:|---:|---:|---:|")
	for rnd in range(1, BMRunConfig.ROUND_COUNT + 1):
		if not base.per_round.has(rnd):
			continue
		var pr: Dictionary = base.per_round[rnd]
		_out("| %d | %d | %d | %d | %.0f%% | %.1f | %d |" % [rnd, BMRunConfig.target(rnd), pr.reached, pr.won,
			100.0 * pr.won / maxi(1, pr.reached), float(pr.used) / maxi(1, pr.won), pr.score / maxi(1, pr.reached)])
	var purchases: Dictionary = base.bot.purchases
	if not purchases.is_empty():
		_out("")
		_out("Workshop/piece purchases across the batch: %s" % str(purchases))
	_out("")


func _jokers() -> void:
	_out("## Joker impact (card owned from round 1, paired seeds)")
	_out("")
	var base := _batch()
	_out("Baseline: avg round %.2f, win %.0f%%, PPP %.1f." % [base.rounds, 100.0 * base.wins / runs, _ppp(base)])
	_out("")
	_out("| Joker | Rarity | Avg round | Δ round | Win % | PPP | Δ PPP | Trigger rate |")
	_out("|---|---|---:|---:|---:|---:|---:|---:|")
	var rows: Array = []
	for d in BMJokers.CATALOG:
		if not BMJokers.is_implemented(d.id):
			continue
		var only := OS.get_environment("BM_ONLY")
		if only != "" and not only.split(",").has(d.id):
			continue
		var id: String = d.id
		var setup := func(run: BMRun) -> void:
			run.jokers.assign([id])
			if id == "mimic":
				run.jokers.append("wide_awake")
		var r := _batch(setup)
		var st: Dictionary = r.bot.joker_stats.get(id, {"placements": 0, "triggers": 0})
		var trig := float(st.triggers) / maxi(1, st.placements)
		rows.append({"id": id, "name": d.name + (" (+Wide Awake)" if id == "mimic" else ""), "rarity": BMJokers.RARITY_NAMES[d.rarity],
			"round": r.rounds, "win": 100.0 * r.wins / runs, "ppp": _ppp(r), "trig": trig})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.round > b.round)
	for row in rows:
		_out("| %s | %s | %.2f | %+.2f | %.0f%% | %.1f | %+.1f | %.0f%% |" % [row.name, row.rarity, row.round, row.round - base.rounds,
			row.win, row.ppp, row.ppp - _ppp(base), 100.0 * row.trig])
	_out("")


func _upgrades() -> void:
	_out("## Bag upgrades (applied to the starter bag before round 1, paired seeds)")
	_out("")
	var base := _batch()
	_out("Baseline: avg round %.2f, win %.0f%%, PPP %.1f." % [base.rounds, 100.0 * base.wins / runs, _ppp(base)])
	_out("")
	var scenarios := {
		"4x Chrome (largest pieces)": func(run: BMRun) -> void: _mat(run, "chrome", 4),
		"4x Neon (largest pieces)": func(run: BMRun) -> void: _mat(run, "neon", 4),
		"4x Glass (largest pieces)": func(run: BMRun) -> void: _mat(run, "glass", 4),
		"2x Gold (largest pieces)": func(run: BMRun) -> void: _mat(run, "gold", 2),
		"2x Encore Stamp": func(run: BMRun) -> void: _stamp(run, "encore", 2),
		"2x Refund Stamp": func(run: BMRun) -> void: _stamp(run, "refund", 2),
		"2x Tip Stamp": func(run: BMRun) -> void: _stamp(run, "tip", 2),
		"2x Memory Stamp": func(run: BMRun) -> void: _stamp(run, "memory", 2),
		"Schematic: Bar 3 Lv 2": func(run: BMRun) -> void: run.family_levels["bar3"] = 2,
		"Schematic: L 3 Lv 2": func(run: BMRun) -> void: run.family_levels["l3"] = 2,
		"Shred Zigzags + Plus (-3 pieces)": func(run: BMRun) -> void:
			for fam in [&"zigzag4", &"zigzag4", &"plus5"]:
				for p in run.bag:
					if p.family == fam:
						BMBag.remove_piece(run, int(p.uid))
						break,
		"Copy both Singles (+2 pieces)": func(run: BMRun) -> void:
			for p in run.bag.duplicate():
				if p.family == &"single":
					BMBag.add_piece(run, p),
		"Add Square 3x3 + Bar 5": func(run: BMRun) -> void:
			BMBag.add_piece(run, BMPieces.make(-1, &"square3", 0, 2))
			BMBag.add_piece(run, BMPieces.make(-1, &"bar5", 0, 4)),
		"Lean Bag + shred 6 pieces": func(run: BMRun) -> void:
			run.jokers.assign(["lean_bag"])
			for i in 6:
				BMBag.remove_piece(run, int(run.bag[run.bag.size() - 1].uid)),
		"Foundry + 6 Chrome": func(run: BMRun) -> void:
			run.jokers.assign(["foundry"])
			_mat(run, "chrome", 6),
		"Neon Sign + 6 Neon": func(run: BMRun) -> void:
			run.jokers.assign(["neon_sign"])
			_mat(run, "neon", 6),
		"Specialist + Bar 3 Lv 3": func(run: BMRun) -> void:
			run.jokers.assign(["specialist"])
			run.family_levels["bar3"] = 3,
	}
	_out("| Scenario | Avg round | Δ round | Win % | PPP | Δ PPP |")
	_out("|---|---:|---:|---:|---:|---:|")
	for name in scenarios:
		var r := _batch(scenarios[name])
		_out("| %s | %.2f | %+.2f | %.0f%% | %.1f | %+.1f |" % [name, r.rounds, r.rounds - base.rounds, 100.0 * r.wins / runs, _ppp(r), _ppp(r) - _ppp(base)])
	_out("")


static func _largest(run: BMRun) -> Array:
	var by_size := run.bag.duplicate()
	by_size.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.cells.size() > b.cells.size() or (a.cells.size() == b.cells.size() and int(a.uid) < int(b.uid)))
	return by_size


static func _mat(run: BMRun, material: String, n: int) -> void:
	var k := 0
	for p in _largest(run):
		if k < n and p.material == "":
			p.material = material
			k += 1


static func _stamp(run: BMRun, stamp: String, n: int) -> void:
	var k := 0
	for p in _largest(run):
		if k < n and p.stamp == "":
			p.stamp = stamp
			k += 1
