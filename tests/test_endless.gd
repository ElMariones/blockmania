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


func test_consecutive_clears_grow_multiplier() -> void:
	var g := BMEndless.new_game(18)
	for y in 2:
		for x in 7:
			g.board.set_cell(Vector2i(x, y), 0)
	g.board.set_cell(Vector2i(7, 7), 0)
	g.tray = [BMShapes.make_shape(&"single", 0, 0), BMShapes.make_shape(&"single", 0, 1), BMShapes.make_shape(&"bar2", 0, 2)]
	check(g.apply_action({"a": "place", "i": 0, "x": 7, "y": 0}).ok, "first clear")
	var second := g.apply_action({"a": "place", "i": 1, "x": 7, "y": 1})
	eq(g.combo, 2, "second clear grows chain")
	eq(second.points, 210, "x2 line score")


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


func test_no_legal_offer_ends_game_and_save_round_trips() -> void:
	var g := BMEndless.new_game(19)
	for y in 8:
		for x in 8:
			if x != 7 or y != 7:
				g.board.set_cell(Vector2i(x, y), 0)
	g.tray = [BMShapes.make_shape(&"square2", 0, 0), BMShapes.make_shape(&"bar2", 0, 1), BMShapes.make_shape(&"l3", 0, 2)]
	g.hold_used = true
	g._check_game_over()
	check(g.over, "no offered piece fits")
	check(not g.apply_action({"a": "place", "i": 0, "x": 0, "y": 0}).ok, "cannot play after loss")
	var copy := BMEndless.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	eq(copy.board.debug_string(), g.board.debug_string(), "board restored")
	eq(copy.score, g.score, "score restored")
	check(copy.over, "loss restored")


func test_unused_hold_can_rescue_a_stuck_tray() -> void:
	var g := BMEndless.new_game(211)
	for y in 8:
		for x in 8:
			if x != 7 or y != 7:
				g.board.set_cell(Vector2i(x, y), 0)
	g.tray = [BMShapes.make_shape(&"square2", 0, 0), BMShapes.make_shape(&"bar2", 0, 1), BMShapes.make_shape(&"l3", 0, 2)]
	g._check_game_over()
	check(not g.over, "unused Hold prevents premature loss")
	var swap := g.apply_action({"a": "hold", "i": 0})
	check(swap.ok and g.fits(0), "Hold draws a legal replacement")


func test_same_seed_produces_same_offers() -> void:
	var a := BMEndless.new_game(12345)
	var b := BMEndless.new_game(12345)
	eq(a.to_dict().tray, b.to_dict().tray, "three starting offers match")
	var resumed := BMEndless.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	eq(resumed._draw_shape().family, b._draw_shape().family, "next draw after resume")


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
	eq(g.held.family, &"single", "stored Single")
	check(not g.tray[0].is_empty(), "replacement drawn")
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
