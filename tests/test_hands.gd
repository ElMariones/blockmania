extends BMTestCase
## Tray Hands (docs/design/round_play_update.md §2).

const EMPTY_ROWS := ["........", "........", "........", "........", "........", "........", "........", "........"]


func _p(family: StringName, color: int, material: String = "") -> Dictionary:
	return BMPieces.make(-1, family, 0, color, material)


## A run whose next natural deal draws exactly `pieces` (in order).
func _run_dealing(pieces: Array) -> BMRun:
	var run := BMRun.new_run(99)
	run.board = BMBoard.new()
	var uids: Array = []
	for p in pieces:
		var added := BMBag.add_piece(run, p)
		uids.append(int(added.uid))
	run.draw_pile = uids
	run.discard_pile = []
	return run


func test_detect_each_hand() -> void:
	eq(BMHands.detect([_p(&"bar3", 0), _p(&"bar3", 1), _p(&"l3", 2)]), BMHands.TWINS, "two of a family")
	eq(BMHands.detect([_p(&"bar2", 0), _p(&"bar3", 1), _p(&"square2", 2)]), BMHands.STAIRCASE, "2-3-4 cells")
	eq(BMHands.detect([_p(&"bar2", 4), _p(&"l3", 4), _p(&"t4", 4)]), BMHands.MONOCHROME, "one color")
	eq(BMHands.detect([_p(&"t4", 0), _p(&"t4", 1), _p(&"t4", 2)]), BMHands.TRIPLETS, "three of a family")
	eq(BMHands.detect([_p(&"t4", 3), _p(&"t4", 3), _p(&"t4", 3)]), BMHands.GRAND_SLAM, "family and color")
	eq(BMHands.detect([_p(&"single", 0), _p(&"bar3", 1), _p(&"plus5", 2)]), "", "no pattern")


func test_monochrome_beats_staircase_and_prism_is_wild() -> void:
	eq(BMHands.detect([_p(&"bar2", 5), _p(&"bar3", 5), _p(&"square2", 5)]), BMHands.MONOCHROME, "higher rank wins")
	eq(BMHands.detect([_p(&"bar2", 1), _p(&"l3", 0, "prism"), _p(&"t4", 1)]), BMHands.MONOCHROME, "prism counts as any color")


func test_temporary_or_missing_pieces_never_form_a_hand() -> void:
	eq(BMHands.detect([_p(&"single", 0), _p(&"single", 0), BMPieces.temporary_single(0)]), "", "temporary breaks it")
	eq(BMHands.detect([_p(&"t4", 0), _p(&"t4", 0), {}]), "", "needs three pieces")


func test_natural_deal_marks_pieces_and_grants_staircase_placement() -> void:
	var run := _run_dealing([_p(&"bar2", 0), _p(&"bar3", 1), _p(&"square2", 2)])
	var before := run.round_state.placements_left
	eq(run._deal_fresh_tray(), BMHands.STAIRCASE, "staircase dealt")
	for p in run.tray:
		eq(p.hand, BMHands.STAIRCASE, "piece marked")
	eq(run.round_state.placements_left, before + 1, "+1 placement")
	eq(run.round_state.hands_formed, 1, "counted")


func test_triplets_and_grand_slam_rewards() -> void:
	var run := _run_dealing([_p(&"t4", 0), _p(&"t4", 1), _p(&"t4", 2)])
	var refreshes := run.round_state.refreshes_left
	eq(run._deal_fresh_tray(), BMHands.TRIPLETS, "triplets")
	eq(run.round_state.refreshes_left, refreshes + 1, "+1 refresh")
	run = _run_dealing([_p(&"t4", 3), _p(&"t4", 3), _p(&"t4", 3)])
	var credits := run.credits
	eq(run._deal_fresh_tray(), BMHands.GRAND_SLAM, "grand slam")
	eq(run.credits, credits + BMHands.GRAND_SLAM_CREDITS, "+3 credits")


func test_hand_rewards_score_on_each_placement() -> void:
	var twins := run_with(EMPTY_ROWS, [_p(&"single", 0)])
	twins.tray[0].hand = BMHands.TWINS
	var r := twins.place(0, Vector2i(0, 0))
	eq(r.chips, 10, "cell chips")
	eq(r.mult, 1.0 + BMHands.TWINS_MULT, "twins +1 Mult")
	var mono := run_with(EMPTY_ROWS, [_p(&"bar2", 4)])
	mono.tray[0].hand = BMHands.MONOCHROME
	r = mono.place(0, Vector2i(0, 0))
	eq(r.mult, BMHands.MONOCHROME_X_MULT, "x2")
	var trip := run_with(EMPTY_ROWS, [_p(&"bar2", 4)])
	trip.tray[0].hand = BMHands.TRIPLETS
	r = trip.place(0, Vector2i(0, 0))
	eq(r.mult, (1.0 + BMHands.TRIPLETS_MULT) * BMHands.TRIPLETS_X_MULT, "+2 then x1.5")
	var slam := run_with(EMPTY_ROWS, [_p(&"bar2", 4)])
	slam.tray[0].hand = BMHands.GRAND_SLAM
	r = slam.place(0, Vector2i(0, 0))
	eq(r.mult, (1.0 + BMHands.TRIPLETS_MULT) * BMHands.MONOCHROME_X_MULT, "+2 then x2")


func test_refresh_never_forms_a_hand_without_card_sharp() -> void:
	var run := _run_dealing([_p(&"single", 0), _p(&"bar3", 1), _p(&"plus5", 2), _p(&"t4", 0), _p(&"t4", 1), _p(&"t4", 2)])
	run._deal_fresh_tray()
	var r := run.refresh()
	check(r.ok, "refreshed")
	eq(r.hand, "", "no hand from a refresh")
	for p in run.tray:
		check(not p.has("hand"), "unmarked")


func test_card_sharp_lets_a_refresh_form_a_hand() -> void:
	var run := _run_dealing([_p(&"single", 0), _p(&"bar3", 1), _p(&"plus5", 2), _p(&"t4", 0), _p(&"t4", 1), _p(&"t4", 2)])
	run.jokers.assign(["card_sharp"])
	run._deal_fresh_tray()
	var r := run.refresh()
	eq(r.hand, BMHands.TRIPLETS, "card sharp")


func test_hot_hand() -> void:
	var run := run_with(EMPTY_ROWS, [_p(&"single", 0), _p(&"single", 1)], ["hot_hand"])
	run.tray[0].hand = BMHands.STAIRCASE
	var r := run.place(0, Vector2i(0, 0))
	eq(r.mult, 1.5, "hand tray: x1.5")
	r = run.place(1, Vector2i(3, 3))
	eq(r.mult, 1.0, "no hand: no trigger")


func test_hand_mark_survives_save_and_preview() -> void:
	var run := _run_dealing([_p(&"bar3", 0), _p(&"bar3", 1), _p(&"l3", 2)])
	run._deal_fresh_tray()
	var copy := BMRun.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	eq(copy.tray[0].hand, BMHands.TWINS, "saved")
	var preview := run.preview_place(0, Vector2i(0, 0))
	var real := run.place(0, Vector2i(0, 0))
	eq(preview.points, real.points, "preview equals result")


func test_starter_bag_odds() -> void:
	var o := BMHands.odds(BMPieces.starter_bag())
	check(absf(o[BMHands.TWINS] - 0.215) < 0.002, "twins %.3f" % o[BMHands.TWINS])
	check(absf(o[BMHands.STAIRCASE] - 0.179) < 0.002, "staircase %.3f" % o[BMHands.STAIRCASE])
	check(absf(o.any - 0.41) < 0.003, "any %.3f" % o.any)
