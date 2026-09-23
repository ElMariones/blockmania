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
	old.erase("held")
	old.erase("hold_used")
	var migrated := BMEndless.from_dict(old)
	check(migrated != null and migrated.held.is_empty(), "old save loads with empty Hold")


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
	DirAccess.remove_absolute(BMEndlessStore.game_path)
	DirAccess.remove_absolute(BMEndlessStore.scores_path)
	BMEndlessStore.game_path = BMEndlessStore.PATH
	BMEndlessStore.scores_path = BMEndlessStore.SCORES_PATH
