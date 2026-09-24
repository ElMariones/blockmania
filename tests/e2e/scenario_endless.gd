extends BME2ECase
## Endless played end to end: ENDLESS from the title, pieces placed through the Endless
## screen's own placement path, Hold used once, save & quit and CONTINUE through the title's
## popup mid-game, then play to game over. Checks: every placement succeeds, the saved game
## resumes identically, the finished game lands in the top-ten table with its score, and a
## new game starts clean.

const SEED := 777
const MAX_PLACEMENTS := 400


func run() -> void:
	main.title_screen._endless_pressed()
	await frames(3)
	check(main.endless_screen.visible, "ENDLESS opens the Endless screen")
	# Pin the seed so the artifact is repeatable (the title starts a random one).
	main.endless_screen.bind(BMEndless.new_game(SEED))
	await frames(2)
	var es = main.endless_screen
	var placed := 0
	var held := false
	var resumed := false
	while placed < MAX_PLACEMENTS and not es.game.over:
		var g: BMEndless = es.game
		if not held and placed == 3:
			held = true
			es._held = 0
			var hr: Dictionary = main.endless_act({"a": "hold", "i": 0, "ms": 500})
			check(hr.get("ok", false), "Hold stores a piece: %s" % str(hr.get("error", "")))
			es._held = -1
			es.bind(g)
			await frames(1)
			continue
		if not resumed and placed == 20:
			resumed = true
			var before := _play_digest(g)
			main.show_pause()
			await frames(2)
			main.save_and_quit()
			await frames(2)
			check(main.title_screen.visible, "SAVE & QUIT returns to the title")
			main.title_screen._endless_pressed()
			await frames(2)
			# A game in progress asks: CONTINUE or NEW GAME.
			check(is_instance_valid(main.title_screen._highscore_overlay), "the Continue / New Game popup opens")
			main.title_screen._close_high_scores()
			main.continue_endless()
			await frames(2)
			eq(_play_digest(main.endless_screen.game), before, "continued game is identical")
			continue
		var best := _choose(g)
		if best.is_empty():
			# Nothing in the tray fits: the stored piece may still rescue the game.
			if _swap_in_held(g):
				await frames(1)
				continue
			break
		es._held = int(best.i)
		var score_before := g.score
		es._place(best.anchor)
		await frames(1)
		placed += 1
		check(es.game.score >= score_before, "score never goes down")
		if placed == 12:
			await screenshot("endless_mid")
	check(es.game.over, "the game ends when nothing fits (placed %d)" % placed)
	await frames(2)
	await screenshot("endless_over")
	var scores := BMEndlessStore.high_scores()
	check(not scores.is_empty() and int(scores[0].score) == es.game.score, "the finished game is in the top ten")
	facts = {"seed": SEED, "placements": es.game.placements, "score": es.game.score, "lines": es.game.lines,
		"best_combo": es.game.best_combo, "digest": _play_digest(es.game)}
	checkpoint("endless over", facts)
	main.start_endless()
	await frames(2)
	eq(main.endless_screen.game.score, 0, "a new game starts at zero")
	main.show_title()
	await frames(2)


## Board, tray, Hold, score and RNG: everything but the active-time counters (SAVE & QUIT
## legitimately adds the time played so far).
static func _play_digest(g: BMEndless) -> String:
	var d := g.to_dict()
	for k in ["duration_ms", "time_since_placement_ms", "placement_time_total_ms", "score_samples", "history"]:
		d.erase(k)
	return dict_digest(d)


func _swap_in_held(g: BMEndless) -> bool:
	if g.held.is_empty() or g.hold_used or not g.board.fits_anywhere(g.held.cells):
		return false
	for i in 3:
		if not g.tray[i].is_empty():
			var r: Dictionary = main.endless_act({"a": "hold", "i": i, "ms": 500})
			if r.get("ok", false):
				main.endless_screen.bind(main.endless_screen.game)
				return true
	return false


## Greedy but deterministic: most lines, then lowest and leftmost anchor.
func _choose(g: BMEndless) -> Dictionary:
	var best := {}
	var best_value := -1.0e9
	for i in 3:
		if g.tray[i].is_empty():
			continue
		for a in g.board.legal_anchors(g.tray[i].cells):
			var b := g.board.duplicate_board()
			b.place(g.tray[i].cells, a, 0)
			var value := float(b.full_rows().size() + b.full_cols().size()) * 100.0 + float(a.y) * 2.0 - float(a.x) * 0.1 - float(i) * 0.01
			if value > best_value:
				best_value = value
				best = {"i": i, "anchor": a}
	return best
