extends BMTestCase
## Arcade scoring, loss timing, and save determinism.


func test_combo_survives_one_miss_and_resets_after_two() -> void:
	var g := BMEndless.new_game(17)
	for x in 7:
		g.board.set_cell(Vector2i(x, 0), 0)
	g.tray = [BMShapes.make_shape(&"single", 0, 0), BMShapes.make_shape(&"single", 0, 1), BMShapes.make_shape(&"single", 0, 2)]
	var first := g.apply_action({"a": "place", "i": 0, "x": 7, "y": 0})
	check(first.ok, "clear succeeds")
	eq(first.points, 110, "first clear is x1")
	eq(g.combo, 1, "starts at x1")
	check(g.apply_action({"a": "place", "i": 1, "x": 0, "y": 2}).ok, "first miss")
	eq(g.misses, 1, "one miss remembered")
	eq(g.combo, 1, "one miss preserves multiplier")
	check(g.apply_action({"a": "place", "i": 2, "x": 1, "y": 2}).ok, "second miss")
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
	g.tray = [BMShapes.make_shape(&"single", 0, 0), BMShapes.make_shape(&"single", 0, 1), BMShapes.make_shape(&"bar2", 0, 2)]
	check(g.apply_action({"a": "place", "i": 0, "x": 7, "y": 0}).ok, "first clear")
	var second := g.apply_action({"a": "place", "i": 1, "x": 7, "y": 1})
	eq(g.combo, 2, "second clear grows chain")
	eq(second.points, 210, "x2 line score")


func test_no_legal_offer_ends_game_and_save_round_trips() -> void:
	var g := BMEndless.new_game(19)
	for y in 8:
		for x in 8:
			if x != 7 or y != 7:
				g.board.set_cell(Vector2i(x, y), 0)
	g.tray = [BMShapes.make_shape(&"square2", 0, 0), BMShapes.make_shape(&"bar2", 0, 1), BMShapes.make_shape(&"l3", 0, 2)]
	g._check_game_over()
	check(g.over, "no offered piece fits")
	check(not g.apply_action({"a": "place", "i": 0, "x": 0, "y": 0}).ok, "cannot play after loss")
	var copy := BMEndless.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	eq(copy.board.debug_string(), g.board.debug_string(), "board restored")
	eq(copy.score, g.score, "score restored")
	check(copy.over, "loss restored")


func test_same_seed_produces_same_offers() -> void:
	var a := BMEndless.new_game(12345)
	var b := BMEndless.new_game(12345)
	eq(a.to_dict().tray, b.to_dict().tray, "three starting offers match")
	var resumed := BMEndless.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	eq(resumed._draw_shape().family, b._draw_shape().family, "next draw after resume")


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
