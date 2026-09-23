extends BMTestCase
## One trigger/no-trigger check per implemented scoring Joker, plus rule Jokers.

const EMPTY_ROWS := ["........", "........", "........", "........", "........", "........", "........", "........"]
const ONE_ROW := ["1111111.", "........", "........", "........", "........", "........", "........", "........"]


func _joker_value(r: Dictionary, id: String) -> Variant:
	for it in r.items:
		if it.get("joker", "") == id and it.source == "joker":
			return it.value
	return null


func _place(board_rows: Array, s: Dictionary, anchor: Vector2i, jokers: Array, setup: Callable = Callable()) -> Dictionary:
	var run := run_with(board_rows, [s], jokers)
	if setup.is_valid():
		setup.call(run)
	return run.place(0, anchor)


func test_clean_sweep() -> void:
	eq(_joker_value(_place(ONE_ROW, shape(&"single"), Vector2i(7, 0), ["clean_sweep"]), "clean_sweep"), 50, "one line")
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"single"), Vector2i(7, 0), ["clean_sweep"]), "clean_sweep"), null, "no line")


func test_crossbar_needs_row_and_column() -> void:
	var cross := [".......1", ".......1", ".......1", ".......1", ".......1", ".......1", ".......1", "1111111."]
	eq(_joker_value(_place(cross, shape(&"single"), Vector2i(7, 7), ["crossbar"]), "crossbar"), 150, "row+col")
	eq(_joker_value(_place(ONE_ROW, shape(&"single"), Vector2i(7, 0), ["crossbar"]), "crossbar"), null, "row only")


func test_small_change_and_heavy_hand() -> void:
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"bar3"), Vector2i(0, 0), ["small_change"]), "small_change"), 45, "3 cells x 15")
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"bar4"), Vector2i(0, 0), ["small_change"]), "small_change"), null, "4 cells no")
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"plus5"), Vector2i(0, 0), ["heavy_hand"]), "heavy_hand"), 100, "5 cells")
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"bar4"), Vector2i(0, 0), ["heavy_hand"]), "heavy_hand"), null, "4 cells no")


func test_first_strike_only_first_clear() -> void:
	eq(_joker_value(_place(ONE_ROW, shape(&"single"), Vector2i(7, 0), ["first_strike"]), "first_strike"), 150, "first clear")
	var second := _place(ONE_ROW, shape(&"single"), Vector2i(7, 0), ["first_strike"], func(run: BMRun) -> void: run.round_state.clearing_placements = 1)
	eq(_joker_value(second, "first_strike"), null, "second clear")


func test_neat_freak_diagonal() -> void:
	var diag := ["1.......", "........", "........", "........", "........", "........", "........", "........"]
	eq(_joker_value(_place(diag, shape(&"single"), Vector2i(1, 1), ["neat_freak"]), "neat_freak"), null, "diagonal touch")
	eq(_joker_value(_place(diag, shape(&"single"), Vector2i(1, 0), ["neat_freak"]), "neat_freak"), 40, "orthogonal only")


func test_corner_office() -> void:
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"single"), Vector2i(7, 7), ["corner_office"]), "corner_office"), 60, "corner")
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"single"), Vector2i(3, 0), ["corner_office"]), "corner_office"), null, "edge only")


func test_blue_mood_and_color_blind() -> void:
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"single", 0, BMShapes.COLOR_BLUE), Vector2i(0, 0), ["blue_mood"]), "blue_mood"), 2.0, "blue")
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"single", 0, BMShapes.COLOR_RED), Vector2i(0, 0), ["blue_mood"]), "blue_mood"), null, "red")
	var blind := _place(EMPTY_ROWS, shape(&"single", 0, BMShapes.COLOR_BLUE), Vector2i(0, 0), ["blue_mood"], func(run: BMRun) -> void:
		run.round_number = 4
		run.bosses[0] = "color_blind")
	eq(_joker_value(blind, "blue_mood"), null, "disabled by The Color Blind")


func test_chain_link_uses_combo() -> void:
	var r := _place(ONE_ROW, shape(&"single"), Vector2i(7, 0), ["chain_link"], func(run: BMRun) -> void: run.round_state.combo = 3)
	eq(_joker_value(r, "chain_link"), 3.0, "1 x combo 3")


func test_wide_awake_hollow_point_pressure_cooker() -> void:
	var two := [".......1", ".......1", ".......1", ".......1", ".......1", ".......1", ".......1", "1111111."]
	eq(_joker_value(_place(two, shape(&"single"), Vector2i(7, 7), ["wide_awake"]), "wide_awake"), 3.0, "2 lines")
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"single"), Vector2i(0, 0), ["hollow_point"]), "hollow_point"), 0.5, "empty board")
	var busy := ["1111111.", "1111111.", "1111111.", "1111111.", "1111111.", "........", "........", "........"]
	# 35 occupied -> 29 empty: no Hollow Point; Pressure Cooker floor(35/6)=5 -> +2.5
	eq(_joker_value(_place(busy, shape(&"single"), Vector2i(0, 7), ["hollow_point"]), "hollow_point"), null, "busy board")
	eq(_joker_value(_place(ONE_ROW, shape(&"single"), Vector2i(0, 7), ["hollow_point"]), "hollow_point"), 0.5, "57 empty")
	eq(_joker_value(_place(busy, shape(&"single"), Vector2i(0, 7), ["pressure_cooker"]), "pressure_cooker"), 2.0, "35 occupied -> 4 x 0.5 = +2")
	eq(_joker_value(_place(ONE_ROW, shape(&"single"), Vector2i(0, 7), ["pressure_cooker"]), "pressure_cooker"), null, "7 occupied -> below 8")


func test_golden_ratio_every_third() -> void:
	var run := run_with(EMPTY_ROWS, [shape(&"single"), shape(&"single"), shape(&"single")], ["golden_ratio"])
	check(_joker_value(run.place(0, Vector2i(0, 0)), "golden_ratio") == null, "1st")
	check(_joker_value(run.place(1, Vector2i(2, 2)), "golden_ratio") == null, "2nd")
	eq(_joker_value(run.place(2, Vector2i(4, 4)), "golden_ratio"), 1.5, "3rd")


func test_color_cycle_three_distinct() -> void:
	var run := run_with(EMPTY_ROWS, [shape(&"single", 0, 0), shape(&"single", 0, 1), shape(&"single", 0, 2)], ["color_cycle"])
	run.place(0, Vector2i(0, 0))
	run.place(1, Vector2i(2, 2))
	eq(_joker_value(run.place(2, Vector2i(4, 4)), "color_cycle"), 1.75, "three distinct colors")
	var run2 := run_with(EMPTY_ROWS, [shape(&"single", 0, 0), shape(&"single", 0, 1), shape(&"single", 0, 0)], ["color_cycle"])
	run2.place(0, Vector2i(0, 0))
	run2.place(1, Vector2i(2, 2))
	eq(_joker_value(run2.place(2, Vector2i(4, 4)), "color_cycle"), null, "repeat color")


func test_jackpot_window_exactly_three() -> void:
	var three := [
		"...1....",
		"...1....",
		"...1....",
		"111.1111",
		"111.1111",
		"...1....",
		"...1....",
		"...1....",
	]
	var r := _place(three, shape(&"bar2", 1), Vector2i(3, 3), ["jackpot_window"])
	eq(r.lines, 3, "two rows + one column")
	eq(_joker_value(r, "jackpot_window"), 4.0, "x4")


func test_compound_interest_every_second_clear() -> void:
	var r := _place(ONE_ROW, shape(&"single"), Vector2i(7, 0), ["compound_interest"], func(run: BMRun) -> void: run.round_state.clearing_placements = 1)
	eq(_joker_value(r, "compound_interest"), 1.75, "second clearing placement")
	eq(_joker_value(_place(ONE_ROW, shape(&"single"), Vector2i(7, 0), ["compound_interest"]), "compound_interest"), null, "first")


func test_last_stand() -> void:
	var r := _place(EMPTY_ROWS, shape(&"single"), Vector2i(0, 0), ["last_stand"], func(run: BMRun) -> void:
		run.round_state.refreshes_left = 0
		run.round_state.placements_left = 3)
	eq(_joker_value(r, "last_stand"), 2.0, "no refresh, 3 left")
	var r2 := _place(EMPTY_ROWS, shape(&"single"), Vector2i(0, 0), ["last_stand"], func(run: BMRun) -> void: run.round_state.placements_left = 3)
	eq(_joker_value(r2, "last_stand"), null, "refresh still available")


func test_long_game() -> void:
	var run := BMRun.new_run(5)
	run.jokers.assign(["long_game"])
	run._start_round()
	eq(run.round_state.placements_left, int(run.kit().placements) + 1, "+1 placement")
	eq(run.round_state.placement_cap, int(run.kit().placements) + 1, "refill cap includes it")
	run.tray = [shape(&"bar3"), {}, {}]
	var r := run.place(0, Vector2i(0, 0))
	eq(r.chips, 0, "no cell chips for the first placement")


func test_fire_sale_counts_sold_jokers() -> void:
	var r := _place(EMPTY_ROWS, shape(&"single"), Vector2i(0, 0), ["fire_sale"], func(run: BMRun) -> void: run.jokers_sold = 3)
	eq(_joker_value(r, "fire_sale"), 0.75, "3 sold")
	var r2 := _place(EMPTY_ROWS, shape(&"single"), Vector2i(0, 0), ["fire_sale"], func(run: BMRun) -> void: run.jokers_sold = 20)
	eq(_joker_value(r2, "fire_sale"), 2.0, "capped")


func test_mirror_maze() -> void:
	var rows := ["1111111.", "........", "........", "........", "........", "........", "........", "22......"]
	var run := run_with(rows, [shape(&"single"), shape(&"single")], ["mirror_maze"])
	var r := run.place(0, Vector2i(7, 0))
	eq(_joker_value(r, "mirror_maze"), 50, "+50")
	eq(r.mirror_cleared.size(), 2, "mirrored row cells removed")
	eq(run.board.occupied_count(), 0, "board empty")
	check(run.round_state.mirror_used, "used this round")


func test_second_look_and_spare_parts() -> void:
	var run := BMRun.new_run(8)
	run.jokers.assign(["second_look", "spare_parts"])
	var before := run.round_state.placements_left
	check(run.refresh().ok, "refresh")
	eq(run.round_state.placements_left, before + 1, "Second Look +1")
	run.round_state.score = run.round_state.target - 10
	run.board = board_from(ONE_ROW)
	run.tray = [shape(&"single"), {}, {}]
	var credits := run.credits
	run.place(0, Vector2i(7, 0))
	eq(run.phase, BMRun.Phase.ROUND_RESULT, "round won")
	# 3 base + min(3, 12/2) + 1 Spare Parts
	eq(run.credits - credits, 3 + 3 + 2, "credits")


func test_tiny_insurance_rescues_once() -> void:
	# Empty cells only on the diagonal: no two are adjacent, so only a Single fits.
	var run := run_with(EMPTY_ROWS, [shape(&"bar2", 0), {}, {}], ["tiny_insurance"])
	run.board.cells.fill(1)
	for i in 8:
		run.board.set_cell(Vector2i(i, i), BMBoard.EMPTY)
	run.round_state.refreshes_left = 0
	run._after_round_action()
	eq(run.round_state.status, BMRun.PLAYING, "rescued")
	eq(run.tray[0].family, &"single", "replaced with a Single")
	check(run.round_state.tiny_insurance_used, "marked used")
	run.tray[0] = shape(&"bar2", 0)
	run._after_round_action()
	eq(run.phase, BMRun.Phase.RUN_LOST, "second time: defeat")


func test_stuck_with_refresh_prompts_instead_of_losing() -> void:
	var run := run_with(EMPTY_ROWS, [shape(&"bar2", 0), {}, {}])
	run.board.cells.fill(1)
	for i in 8:
		run.board.set_cell(Vector2i(i, i), BMBoard.EMPTY)
	run._after_round_action()
	eq(run.round_state.status, BMRun.STUCK, "stuck, Refresh offered")
	eq(run.phase, BMRun.Phase.ROUND, "not lost")
	check(run.refresh().ok, "refresh works while stuck")
	check(BMBag.any_fits(run.board, run.tray), "refreshed tray has a legal shape")
	eq(run.round_state.status, BMRun.PLAYING, "playing again")


# --- Bag-era Jokers --------------------------------------------------------------------------

func test_hoarder_and_lean_bag() -> void:
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"single"), Vector2i(0, 0), ["hoarder"]), "hoarder"), 24, "24 pieces x 1")
	var lean := _place(EMPTY_ROWS, shape(&"single"), Vector2i(0, 0), ["lean_bag"], func(run: BMRun) -> void: run.bag = run.bag.slice(0, 20))
	eq(_joker_value(lean, "lean_bag"), 1.0, "4 below 24 -> +1")
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"single"), Vector2i(0, 0), ["lean_bag"]), "lean_bag"), null, "full starter bag")


func test_family_jokers() -> void:
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"l4"), Vector2i(0, 0), ["architect"]), "architect"), 60, "L 4")
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"t4"), Vector2i(0, 0), ["architect"]), "architect"), null, "T 4")
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"bar4"), Vector2i(0, 0), ["straight_edge"]), "straight_edge"), 60, "4 cells x 15")
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"square2"), Vector2i(0, 0), ["square_deal"]), "square_deal"), 2.0, "square")
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"l3"), Vector2i(0, 0), ["square_deal"]), "square_deal"), null, "not square")


func test_last_piece_postmaster_foundry() -> void:
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"single"), Vector2i(0, 0), ["last_piece"]), "last_piece"), 80, "only piece in tray")
	var run := run_with(EMPTY_ROWS, [shape(&"single"), shape(&"single")], ["last_piece"])
	eq(_joker_value(run.place(0, Vector2i(0, 0)), "last_piece"), null, "another piece remains")
	var stamped := shape(&"single")
	stamped.stamp = "tip"
	eq(_joker_value(_place(EMPTY_ROWS, stamped, Vector2i(0, 0), ["postmaster"]), "postmaster"), 40, "stamped")
	var foundry := _place(EMPTY_ROWS, shape(&"single"), Vector2i(0, 0), ["foundry"], func(r: BMRun) -> void:
		r.bag[0].material = "chrome"
		r.bag[1].stamp = "tip")
	eq(_joker_value(foundry, "foundry"), 16, "2 upgraded x 8")


func test_neon_sign_glass_cannon_specialist_recycler() -> void:
	var neon_row := _place(ONE_ROW, shape(&"single"), Vector2i(7, 0), ["neon_sign"], func(r: BMRun) -> void:
		for x in 7:
			r.board.mats[x] = BMPieces.material_index("neon"))
	eq(_joker_value(neon_row, "neon_sign"), 3.5, "7 Neon cells x 0.5")
	var glass := _place(ONE_ROW, shape(&"single"), Vector2i(7, 0), ["glass_cannon"], func(r: BMRun) -> void: r.board.mats[0] = BMPieces.material_index("glass"))
	eq(_joker_value(glass, "glass_cannon"), 1.5, "Glass cleared")
	eq(_joker_value(_place(ONE_ROW, shape(&"single"), Vector2i(7, 0), ["glass_cannon"]), "glass_cannon"), null, "no Glass")
	var spec := _place(EMPTY_ROWS, shape(&"bar3"), Vector2i(0, 0), ["specialist"], func(r: BMRun) -> void: r.family_levels["bar3"] = 3)
	eq(_joker_value(spec, "specialist"), 1.5, "Lv 3 x 0.5")
	var rec := _place(EMPTY_ROWS, shape(&"single"), Vector2i(0, 0), ["recycler"], func(r: BMRun) -> void: r.discard_pile = [0, 1, 2, 3, 4, 5])
	eq(_joker_value(rec, "recycler"), 0.6, "6 discarded x 0.1")


func test_collector() -> void:
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"single"), Vector2i(0, 0), ["collector"]), "collector"), 1.4, "10 families")
	var few := _place(EMPTY_ROWS, shape(&"single"), Vector2i(0, 0), ["collector"], func(r: BMRun) -> void: r.bag = r.bag.slice(0, 9))
	eq(_joker_value(few, "collector"), null, "3 families: no bonus")


func test_mimic_copies_joker_below() -> void:
	var r := _place(ONE_ROW, shape(&"single"), Vector2i(7, 0), ["mimic", "clean_sweep"])
	var count := 0
	for it in r.items:
		if it.get("joker", "") in ["mimic", "clean_sweep"]:
			count += 1
	eq(count, 2, "Mimic and Clean Sweep both add")
	eq(r.chips, 10 + 100 + 50 + 50, "+50 twice")
	var order := _place(ONE_ROW, shape(&"single"), Vector2i(7, 0), ["clean_sweep", "mimic"])
	eq(order.chips, 10 + 100 + 50, "Mimic at the bottom copies nothing")
	var rule := _place(EMPTY_ROWS, shape(&"single"), Vector2i(0, 0), ["mimic", "spare_parts"])
	eq(rule.points, 10, "rule-only Jokers are not copied")
	var double := _place(EMPTY_ROWS, shape(&"single"), Vector2i(0, 0), ["mimic", "mimic", "hollow_point"])
	eq(double.mult, 2.0, "second Mimic copies Hollow Point, first copies nothing (1 + 0.5 + 0.5)")


# --- Round-play update Jokers and Feats (docs/design/round_play_update.md §5-6) ---

const CROSS := [".......1", ".......1", ".......1", ".......1", ".......1", ".......1", ".......1", "1111111."]
## A one-block hole at (7, 0): closed by the board edge on two sides and blocks on the others.
const HOLE := ["1111111.", ".......1", "........", "........", "........", "........", "........", "........"]


func test_feats_are_detected_and_reported() -> void:
	var r := _place(CROSS, shape(&"single"), Vector2i(7, 7), [])
	check(r.feats.has("crossfire"), "crossfire: %s" % str(r.feats))
	check(r.feats.has("needle_threader"), "the single filled a closed hole")
	check(r.feats.has("clean_board"), "board ends empty")
	var quiet := _place(EMPTY_ROWS, shape(&"single"), Vector2i(3, 3), [])
	eq(quiet.feats.size(), 0, "no clear, no feats")
	var last := _place(ONE_ROW, shape(&"single"), Vector2i(7, 0), [], func(run: BMRun) -> void: run.round_state.placements_left = 1)
	check(last.feats.has("last_breath"), "last placement clear")


func test_showboat_pays_only_for_new_feats() -> void:
	var run := run_with(CROSS, [shape(&"single"), shape(&"single")], ["showboat"])
	run.round_state.target = 999999
	var r := run.place(0, Vector2i(7, 7))
	eq(_joker_value(r, "showboat"), 2.0 * r.feats.size(), "+2 per new feat")
	run.board = board_from(ONE_ROW)
	r = run.place(1, Vector2i(7, 0))
	check(_joker_value(r, "showboat") == null or float(_joker_value(r, "showboat")) < 2.0 * r.feats.size(), "repeats pay nothing")


func test_patience_stores_and_releases() -> void:
	var run := run_with(EMPTY_ROWS, [shape(&"single"), shape(&"single"), shape(&"single")], ["patience"])
	eq(_joker_value(run.place(0, Vector2i(0, 5)), "patience"), null, "quiet turn scores nothing")
	run.place(1, Vector2i(2, 5))
	eq(run.round_state.patience_store, 80, "two quiet turns stored")
	run.board = board_from(ONE_ROW)
	eq(_joker_value(run.place(2, Vector2i(7, 0)), "patience"), 80, "released on a clear")
	eq(run.round_state.patience_store, 0, "reset")


func test_locksmith() -> void:
	var r := _place(HOLE, shape(&"single"), Vector2i(7, 0), ["locksmith"])
	var mult := 0.0
	var chips := 0
	for it in r.items:
		if it.get("joker", "") == "locksmith":
			if it.kind == "mult":
				mult = it.value
			elif it.kind == "chips":
				chips = it.value
	eq(mult, 1.0, "hole filled: +1 Mult")
	eq(chips, 75, "and cleared a line: +75 Chips")
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"single"), Vector2i(3, 3), ["locksmith"]), "locksmith"), null, "open cell: nothing")


func test_countdown_needs_three_shrinking_pieces() -> void:
	var run := run_with(EMPTY_ROWS, [shape(&"square2"), shape(&"bar3"), shape(&"bar2")], ["countdown"])
	run.place(0, Vector2i(0, 0))
	run.place(1, Vector2i(0, 3))
	eq(_joker_value(run.place(2, Vector2i(0, 5)), "countdown"), 1.5, "4, 3, 2")
	var flat := run_with(EMPTY_ROWS, [shape(&"bar2"), shape(&"bar2"), shape(&"bar2")], ["countdown"])
	flat.place(0, Vector2i(0, 0))
	flat.place(1, Vector2i(0, 3))
	eq(_joker_value(flat.place(2, Vector2i(0, 5)), "countdown"), null, "equal sizes: no")


func test_full_tank() -> void:
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"single"), Vector2i(0, 0), ["full_tank"], func(run: BMRun) -> void:
		run.round_state.placement_cap = 15
		run.round_state.placements_left = 15), "full_tank"), 2.0, "at cap")
	eq(_joker_value(_place(EMPTY_ROWS, shape(&"single"), Vector2i(0, 0), ["full_tank"], func(run: BMRun) -> void:
		run.round_state.placement_cap = 15
		run.round_state.placements_left = 12), "full_tank"), null, "below cap")


func test_keystone() -> void:
	eq(_joker_value(_place(CROSS, shape(&"single"), Vector2i(7, 7), ["keystone"]), "keystone"), 2.0, "a single clears two lines")
	eq(_joker_value(_place(ONE_ROW, shape(&"single"), Vector2i(7, 0), ["keystone"]), "keystone"), null, "one line: no")


func test_overflow_pays_for_wasted_refills() -> void:
	var run := run_with(CROSS, [shape(&"single")], ["overflow"])
	run.round_state.placement_cap = 15
	run.round_state.placements_left = 15
	var before := run.credits
	run.place(0, Vector2i(7, 7))
	eq(run.credits - before, 1, "refill 2 from 14: one wasted -> 1 Credit")


func test_draftsman_gives_an_eraser_on_row_and_column() -> void:
	var run := run_with(CROSS, [shape(&"single")], ["draftsman"])
	run.place(0, Vector2i(7, 7))
	check(run.consumables.has("eraser"), "eraser gained")
	var no := run_with(ONE_ROW, [shape(&"single")], ["draftsman"])
	no.place(0, Vector2i(7, 0))
	check(not no.consumables.has("eraser"), "row only: nothing")


func test_loan_shark_pays_now_and_repays_later() -> void:
	var run := BMRun.new_run(3)
	run.round_state.score = run.round_state.target
	run._after_round_action()
	run.continue_after_round()
	run.shop.jokers[0] = "loan_shark"
	var before := run.credits
	check(run.buy_joker(0).ok, "bought for 0")
	eq(run.credits, before + BMJokers.LOAN_CREDITS, "+6 now")
	eq(run.loan_debt, BMJokers.LOAN_TOTAL, "owes 8")
	check(not run.sell_joker(run.jokers.find("loan_shark")).ok, "cannot sell while owing")
	run.leave_shop()
	run.round_state.score = run.round_state.target
	run._after_round_action()
	eq(run.loan_debt, BMJokers.LOAN_TOTAL - BMJokers.LOAN_INSTALLMENT, "repaid 2 from the payout")


func test_insurance_policy_replays_a_lost_round_once() -> void:
	var run := BMRun.new_run(11)
	run.jokers.assign(["insurance_policy"])
	run.round_state.placements_left = 0
	var r := run._after_round_action()
	check(bool(r.get("insurance", false)), "claim reported")
	eq(run.phase, BMRun.Phase.ROUND, "still playing")
	eq(run.round_state.score, 0, "round restarted")
	eq(run.round_state.refreshes_left, 0, "no free refresh")
	check(not run.jokers.has("insurance_policy"), "card destroyed")
	run.round_state.placements_left = 0
	run._after_round_action()
	eq(run.phase, BMRun.Phase.RUN_LOST, "second loss is final")


func test_breakage_bonus_on_shatter() -> void:
	var run := run_with(ONE_ROW, [shape(&"single")], ["breakage_bonus"])
	var glass := BMBag.add_piece(run, BMPieces.make(-1, &"single", 0, 0, "glass"))
	run.tray[0] = glass.duplicate(true)
	run.board = BMBoard.new()
	var one_row: Array[Vector2i] = []
	for x in 7:
		run.board.place([Vector2i.ZERO] as Array[Vector2i], Vector2i(x, 0), 0, int(glass.uid), BMPieces.material_index("glass"))
	var credits := run.credits
	var shattered := false
	for attempt in 40:
		var trial := run.clone()
		var r := trial.place(0, Vector2i(7, 0))
		if not r.shattered.is_empty():
			eq(trial.credits - credits, 2, "+2 credits on shatter")
			shattered = true
			break
		run.rng_shapes.randi_range(0, 1)
	check(shattered, "a shatter happened within 40 seeds")
