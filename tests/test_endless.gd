extends BMTestCase
## Arcade scoring, loss timing, and save determinism.


func test_combo_survives_two_misses_and_resets_after_three() -> void:
	var g := BMEndless.new_game(17)
	for x in 7:
		g.board.set_cell(Vector2i(x, 0), 0)
	g.board.set_cell(Vector2i(7, 7), 0)
	g.tray = [BMShapes.make_shape(&"single", 0, 0), BMShapes.make_shape(&"single", 0, 1), BMShapes.make_shape(&"single", 0, 2)]
	var first := g.apply_action({"a": "place", "i": 0, "x": 7, "y": 0})
	check(first.ok, "clear succeeds")
	eq(first.points, 110, "first clear is x1")
	eq(g.combo, 1, "starts at x1")
	check(g.apply_action({"a": "place", "i": 1, "x": 0, "y": 2}).ok, "first miss")
	eq(g.misses, 1, "one miss remembered")
	eq(g.combo, 1, "one miss preserves multiplier")
	check(g.apply_action({"a": "place", "i": 2, "x": 1, "y": 2}).ok, "second miss")
	eq(g.misses, 2, "second miss remembered")
	eq(g.combo, 1, "second miss preserves multiplier")
	g.tray[0] = BMShapes.make_shape(&"single", 0, 0)
	check(g.apply_action({"a": "place", "i": 0, "x": 2, "y": 2}).ok, "third miss")
	eq(g.misses, 0, "miss counter resets")
	eq(g.combo, 1, "combo resets to x1")
	for x in 7:
		g.board.set_cell(Vector2i(x, 3), 0)
	g.tray[0] = BMShapes.make_shape(&"single", 0, 0)
	var restart := g.apply_action({"a": "place", "i": 0, "x": 7, "y": 3})
	eq(restart.points, 110, "first clear after reset scores at x1")


func test_combo_ladder_and_clean_board_bonus() -> void:
	var g := BMEndless.new_game(91)
	var expected := [1, 2, 3, 5, 8, 10, 10]
	for n in expected.size():
		for x in 7:
			g.board.set_cell(Vector2i(x, 0), 0)
		g.board.set_cell(Vector2i(7, 7), 0)
		g.tray[0] = BMShapes.make_shape(&"single", 0, 0)
		var result := g.apply_action({"a": "place", "i": 0, "x": 7, "y": 0})
		check(result.ok, "clear %d" % n)
		eq(g.combo, expected[n], "ladder level %d" % n)
		eq(result.points, 10 + 100 * expected[n], "line points at level %d" % n)
	check(g.best_combo == 10, "best combo keeps cap")
	var perfect := BMEndless.new_game(92)
	for x in 7:
		perfect.board.set_cell(Vector2i(x, 0), 0)
	perfect.tray[0] = BMShapes.make_shape(&"single", 0, 0)
	var r := perfect.apply_action({"a": "place", "i": 0, "x": 7, "y": 0})
	eq(r.points, 610, "clean board adds 500 x combo")
	check(r.callouts.has("PERFECT") and r.callouts.has("CLEAN BOARD"), "perfect feedback recorded")


func test_empty_hold_does_not_rescue_a_stuck_tray() -> void:
	var g := BMEndless.new_game(211)
	for y in 8:
		for x in 8:
			if x != 7 or y != 7:
				g.board.set_cell(Vector2i(x, y), 0)
	g.tray = [BMShapes.make_shape(&"square2", 0, 0), BMShapes.make_shape(&"bar2", 0, 1), BMShapes.make_shape(&"l3", 0, 2)]
	g._check_game_over()
	check(g.over, "empty Hold cannot create a rescue after the tray is stuck")
	check(not g.apply_action({"a": "hold", "i": 0}).ok, "cannot draw a new shape after loss")


func test_stored_fitting_hold_can_rescue_a_stuck_tray() -> void:
	var g := BMEndless.new_game(211)
	for y in 8:
		for x in 8:
			if x != 7 or y != 7:
				g.board.set_cell(Vector2i(x, y), 0)
	g.tray = [BMShapes.make_shape(&"square2", 0, 0), BMShapes.make_shape(&"bar2", 0, 1), BMShapes.make_shape(&"l3", 0, 2)]
	g.held = BMShapes.make_shape(&"single", 0, 3)
	g._check_game_over()
	check(not g.over, "stored fitting shape remains available")
	var swap := g.apply_action({"a": "hold", "i": 0})
	check(swap.ok and g.fits(0), "Hold swaps in the fitting shape")


func test_final_placement_with_no_fit_ends_even_when_hold_is_empty() -> void:
	var g := BMEndless.new_game(212)
	for y in 8:
		for x in 8:
			if x != y and Vector2i(x, y) != Vector2i(0, 1):
				g.board.set_cell(Vector2i(x, y), 0)
	g.tray = [BMShapes.make_shape(&"single", 0, 0), BMShapes.make_shape(&"square3", 0, 1), BMShapes.make_shape(&"bar4", 0, 2)]
	var result := g.apply_action({"a": "place", "i": 0, "x": 0, "y": 1})
	check(result.ok and result.rows.is_empty() and result.cols.is_empty(), "last legal placement makes no clear")
	check(result.over and g.over, "last legal placement reports game over immediately")
	check(g.held.is_empty() and not g.fits(1) and not g.fits(2), "tray and Hold match blocked state")


func test_saved_stuck_run_is_reclassified_for_results() -> void:
	BMEndlessStore.game_path = "user://test_endless_stuck_progress.json"
	BMEndlessStore.scores_path = "user://test_endless_stuck_scores.json"
	var g := BMEndless.new_game(213)
	for y in 8:
		for x in 8:
			if x != y:
				g.board.set_cell(Vector2i(x, y), 0)
	g.tray = [BMShapes.make_shape(&"square3", 0, 1), {}, BMShapes.make_shape(&"bar4", 0, 2)]
	var old := g.to_dict()
	old.over = false
	var file := FileAccess.open(BMEndlessStore.game_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	var loaded := BMEndlessStore.load_game()
	check(loaded != null and loaded.over, "old stuck save opens as completed result")
	if loaded != null:
		BMEndlessStore.record(loaded)
	check(not FileAccess.file_exists(BMEndlessStore.game_path), "converted run is removed from progress")
	eq(BMEndlessStore.high_scores().size(), 1, "converted score is recorded once")
	DirAccess.remove_absolute(BMEndlessStore.game_path)
	DirAccess.remove_absolute(BMEndlessStore.scores_path)
	BMEndlessStore.game_path = BMEndlessStore.PATH
	BMEndlessStore.scores_path = BMEndlessStore.SCORES_PATH


func test_new_trio_always_contains_a_legal_shape_if_board_has_space() -> void:
	for seed_value in range(1, 31):
		var g := BMEndless.new_game(seed_value)
		for y in 8:
			for x in 8:
				if x != 7 or y != 7:
					g.board.set_cell(Vector2i(x, y), 0)
		g._deal()
		check(not g.over and g._any_tray_fits(), "fair trio at seed %d" % seed_value)
		var restored := BMEndless.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
		eq(restored.to_dict().tray, g.to_dict().tray, "legal trio survives save %d" % seed_value)


func test_hold_swaps_once_per_placement_and_survives_save() -> void:
	var g := BMEndless.new_game(812)
	g.tray = [BMShapes.make_shape(&"single", 0, 0), BMShapes.make_shape(&"bar2", 0, 1), BMShapes.make_shape(&"square2", 0, 2)]
	var stored := g.apply_action({"a": "hold", "i": 0})
	check(stored.ok, "first hold")
	check(not stored.new_trio, "holding before the last offer replaces one slot")
	eq(g.held.family, &"single", "stored Single")
	check(not g.tray[0].is_empty(), "replacement drawn")
	eq(g.tray[1].family, &"bar2", "other offered pieces stay in the tray")
	check(not g.apply_action({"a": "hold", "i": 1}).ok, "one hold before placement")
	var resumed := BMEndless.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	eq(resumed.held.family, &"single", "hold saved")
	check(resumed.hold_used, "cooldown saved")
	check(resumed.apply_action({"a": "place", "i": 0, "x": 4, "y": 4}).ok, "placement restores Hold")
	check(not resumed.hold_used, "hold ready again")
	var swapped := resumed.apply_action({"a": "hold", "i": 1})
	check(swapped.ok, "swap held piece")
	eq(resumed.tray[1].family, &"single", "stored Single returned")
	eq(resumed.held.family, &"bar2", "new shape stored")


func test_holding_last_offer_deals_fair_full_trio_and_saves_deterministically() -> void:
	var g := BMEndless.new_game(814)
	for y in 8:
		for x in 8:
			if x != y:
				g.board.set_cell(Vector2i(x, y), 0)
	g.tray = [{}, BMShapes.make_shape(&"single", 0, 2), {}]
	var twin := BMEndless.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	var held_result := g.apply_action({"a": "hold", "i": 1})
	var twin_result := twin.apply_action({"a": "hold", "i": 1})
	check(held_result.ok and held_result.new_trio, "last piece in empty Hold starts a new trio")
	check(twin_result.ok and twin_result.new_trio, "saved copy makes the same transition")
	eq(g.tray.filter(func(s: Dictionary) -> bool: return not s.is_empty()).size(), 3, "all three slots refill")
	check(g._any_tray_fits() and not g.over, "new trio has a legal placement")
	eq(g.to_dict().tray, twin.to_dict().tray, "seeded new trio matches after save")
	eq(g.rng.get_state(), twin.rng.get_state(), "deal consumes the same RNG")
	eq(g.held.family, &"single", "last piece is stored")
	check(g.hold_used and not g.apply_action({"a": "hold", "i": 0}).ok, "Hold stays used until a placement")
	eq(g.placements, 0, "new trio does not count as a placement")
	eq(g.score, 0, "new trio gives no score")
	var resumed := BMEndless.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	eq(resumed.to_dict().tray, g.to_dict().tray, "refilled tray survives a second save")
	check(resumed.hold_used and not resumed.held.is_empty(), "Hold state survives a second save")


func test_schema_one_endless_save_migrates() -> void:
	var g := BMEndless.new_game(42)
	var old := g.to_dict()
	old.schema = 1
	for key in ["held", "hold_used", "perfect_clears", "largest_clear", "coverage_peak", "best_streak",
		"consecutive_clears", "duration_ms", "time_since_placement_ms", "placement_time_total_ms",
		"score_samples", "stats_complete"]:
		old.erase(key)
	var migrated := BMEndless.from_dict(old)
	check(migrated != null and migrated.held.is_empty(), "old save loads with empty Hold")
	check(not migrated.stats_complete and migrated.score_samples.is_empty(), "old run does not invent statistics")


func test_endless_statistics_record_real_actions_and_survive_save() -> void:
	var g := BMEndless.new_game(306)
	for x in 7:
		g.board.set_cell(Vector2i(x, 0), 0)
	g.tray[0] = BMShapes.make_shape(&"single", 0, 0)
	check(g.apply_action({"a": "clock", "ms": 1200}).ok, "clock records active play")
	var clear := g.apply_action({"a": "place", "i": 0, "x": 7, "y": 0, "ms": 800})
	check(clear.ok and clear.clean_board, "first placement clears the board")
	var stats := g.summary()
	eq(stats.perfect_clears, 1, "clean board counted")
	eq(stats.largest_clear, 1, "largest clear counted")
	eq(stats.coverage_peak, 13, "coverage records pre-clear filled board")
	eq(stats.duration_ms, 2000, "active duration includes the clock and placement")
	eq(stats.average_placement_ms, 2000, "placement timing includes time before placement")
	eq(stats.best_streak, 1, "clearing streak counted")
	eq(stats.score_samples.back().score, g.score, "graph ends at actual score")
	var resumed := BMEndless.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	eq(resumed.duration_ms, g.duration_ms, "duration survives save")
	eq(resumed.perfect_clears, g.perfect_clears, "perfect count survives save")
	eq(int(resumed.score_samples.back().score), g.score, "graph endpoint survives save")


func test_legacy_schema_two_endless_save_keeps_available_stats() -> void:
	var g := BMEndless.new_game(307)
	var old := g.to_dict()
	old.schema = 2
	for key in ["perfect_clears", "largest_clear", "coverage_peak", "best_streak",
		"consecutive_clears", "duration_ms", "time_since_placement_ms", "placement_time_total_ms",
		"score_samples", "stats_complete"]:
		old.erase(key)
	var migrated := BMEndless.from_dict(old)
	check(migrated != null and not migrated.stats_complete, "schema two run loads with missing stats marked")
	eq(migrated.score, g.score, "score remains intact")


func test_high_scores_are_sorted_and_separate_from_progress() -> void:
	BMEndlessStore.game_path = "user://test_endless_progress.json"
	BMEndlessStore.scores_path = "user://test_endless_scores.json"
	var g := BMEndless.new_game(777)
	BMEndlessStore.record(g)
	check(BMEndlessStore.load_game() != null, "unfinished game resumes")
	g.over = true
	g.score = 500
	BMEndlessStore.record(g)
	check(BMEndlessStore.load_game() == null, "finished game is not resumable")
	var h := BMEndless.new_game(778)
	h.over = true
	h.score = 900
	BMEndlessStore.record(h)
	var scores := BMEndlessStore.high_scores()
	eq(scores.size(), 2, "both scores kept")
	eq(int(scores[0].score), 900, "best score first")
	check(scores[0].has("score_samples") and scores[0].has("duration_ms"), "high score stores detailed statistics")
	DirAccess.remove_absolute(BMEndlessStore.game_path)
	DirAccess.remove_absolute(BMEndlessStore.scores_path)
	BMEndlessStore.game_path = BMEndlessStore.PATH
	BMEndlessStore.scores_path = BMEndlessStore.SCORES_PATH


func test_legacy_high_score_rows_remain_readable() -> void:
	BMEndlessStore.scores_path = "user://test_endless_legacy_scores.json"
	var file := FileAccess.open(BMEndlessStore.scores_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 1, "scores": [{"score": 750, "seed": 13,
		"lines": 4, "combo": 2, "date": "2026-09-22"}]}))
	file.close()
	var scores := BMEndlessStore.high_scores()
	eq(scores.size(), 1, "old leaderboard loads")
	eq(int(scores[0].score), 750, "old score preserved")
	check(not scores[0].has("score_samples"), "missing old graph is distinguishable")
	DirAccess.remove_absolute(BMEndlessStore.scores_path)
	BMEndlessStore.scores_path = BMEndlessStore.SCORES_PATH
