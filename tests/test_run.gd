extends BMTestCase
## Run flow, economy, shop, bosses, determinism, and save round-trips.


func test_new_run_initial_state() -> void:
	var run := BMRun.new_run(1234)
	eq(run.round_number, 1, "round")
	eq(run.round_state.target, BMRunConfig.TARGETS[0], "target")
	eq(run.round_state.placement_cap, 15, "placements")
	eq(run.refreshes_available(), 1, "one refresh")
	eq(run.credits, 0, "credits")
	eq(run.bosses.size(), 3, "three bosses")
	eq(run.bosses[2], "last_call", "final boss")
	check(run.bosses[0] != run.bosses[1], "bosses do not repeat")
	check(BMBag.any_fits(run.board, run.tray), "opening tray is legal")


func test_high_roller_kit() -> void:
	var run := BMRun.new_run(1, "high_roller")
	eq(run.credits, 4, "starting credits")
	eq(run.round_state.placement_cap, 14, "placements")


func test_line_clear_refills_one_placement_per_line() -> void:
	var run := run_with(["1111111.", "........", "........", "........", "........", "........", "........", "........"], [shape(&"single")])
	run.round_state.placement_cap = 15
	run.round_state.placements_left = 10
	var r := run.place(0, Vector2i(7, 0))
	eq(r.lines, 1, "one line")
	eq(r.placements_refilled, 1, "one placement back")
	eq(run.round_state.placements_left, 10, "spent one, got one back")


func test_double_clear_refills_two_but_never_above_cap() -> void:
	var rows := [".......1", ".......1", ".......1", ".......1", ".......1", ".......1", "........", "111111.."]
	var run := run_with(rows, [shape(&"square2"), shape(&"single")])
	run.round_state.target = 99999
	run.round_state.placement_cap = 15
	run.round_state.placements_left = 10
	var r := run.place(0, Vector2i(6, 6))
	eq(r.lines, 2, "row and column")
	eq(r.placements_refilled, 2, "two lines refill two")
	eq(run.round_state.placements_left, 11, "10 - 1 + 2")
	run.board = board_from(["1111111.", "........", "........", "........", "........", "........", "........", "........"])
	run.round_state.placements_left = 15
	r = run.place(1, Vector2i(7, 0))
	eq(r.placements_refilled, 1, "refills only up to the cap")
	eq(run.round_state.placements_left, 15, "capped at the starting count")


func test_clear_on_last_placement_keeps_round_alive() -> void:
	var run := run_with(["1111111.", "........", "........", "........", "........", "........", "........", "........"], [shape(&"single"), shape(&"single")])
	run.round_state.placement_cap = 15
	run.round_state.placements_left = 1
	run.place(0, Vector2i(7, 0))
	eq(run.phase, BMRun.Phase.ROUND, "still playing")
	eq(run.round_state.placements_left, 1, "the clear refilled the last placement")


func test_round_start_sets_refill_cap_and_saves_it() -> void:
	var run := BMRun.new_run(5)
	eq(run.round_state.placement_cap, 15, "cap is the starting count")
	var copy := BMRun.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	eq(copy.round_state.placement_cap, 15, "cap survives save/load")


func test_out_of_placements_loses() -> void:
	var run := BMRun.new_run(77)
	run.round_state.placements_left = 1
	run.tray = [shape(&"single"), {}, {}]
	run.place(0, Vector2i(0, 0))
	eq(run.phase, BMRun.Phase.RUN_LOST, "lost")
	check(run.end_reason.begins_with("Out of placements"), "reason: %s" % run.end_reason)


func test_extra_turn_offered_when_out_of_placements() -> void:
	var run := BMRun.new_run(77)
	run.consumables.assign(["extra_turn"])
	run.round_state.placements_left = 1
	run.tray = [shape(&"single"), {}, {}]
	run.place(0, Vector2i(0, 0))
	eq(run.phase, BMRun.Phase.ROUND, "not lost yet")
	eq(run.round_state.status, BMRun.OUT_OF_PLACEMENTS, "waiting for decision")
	check(run.use_consumable(0).ok, "use extra turn")
	eq(run.round_state.placements_left, 2, "+2")
	eq(run.round_state.status, BMRun.PLAYING, "playing")


func test_target_crossing_wins_immediately_even_on_last_placement() -> void:
	var run := BMRun.new_run(77)
	run.round_state.placements_left = 1
	run.round_state.score = 595
	run.tray = [shape(&"single"), {}, {}]
	run.place(0, Vector2i(0, 0))
	eq(run.phase, BMRun.Phase.ROUND_RESULT, "won")
	eq(run.last_round_result.credits_gained, 3, "3 credits, no unused bonus")


func test_credit_payout_boss_and_unused() -> void:
	var run := BMRun.new_run(77)
	run.round_number = 4
	run._start_round()
	run.round_state.score = run.round_state.target
	run.round_state.placements_left = 7
	run._after_round_action()
	# 3 base + min(3, 7/2=3) + 2 boss
	eq(run.last_round_result.credits_gained, 8, "boss payout")


func test_credits_cap_99() -> void:
	var run := BMRun.new_run(77)
	run.credits = 98
	run.round_state.score = run.round_state.target
	run._after_round_action()
	eq(run.credits, 99, "capped")


func test_refresh_replaces_only_unplaced_shapes() -> void:
	var run := BMRun.new_run(31)
	run.tray[1] = {}
	var r := run.refresh()
	check(r.ok, "refresh ok")
	check(run.tray[1].is_empty(), "empty slot stays empty")
	check(not run.tray[0].is_empty() and not run.tray[2].is_empty(), "others replaced")
	eq(run.round_state.refreshes_left, 0, "spent")
	check(not run.refresh().ok, "second refresh refused")


func test_lockdown_disables_refresh_and_second_tray() -> void:
	var run := BMRun.new_run(31)
	run.round_number = 4
	run.bosses[0] = "lockdown"
	run._start_round()
	run.consumables.assign(["second_tray"])
	eq(run.refreshes_available(), 0, "no refresh")
	check(not run.refresh().ok, "refresh blocked")
	check(run.consumable_usable(0) != "", "second tray blocked")


func test_last_call_and_cramped_cabinet_setup() -> void:
	var run := BMRun.new_run(31)
	run.round_number = 12
	run._start_round()
	eq(run.round_state.placements_left, BMBosses.LAST_CALL_PLACEMENTS, "last call placements")
	eq(run.round_state.target, BMRunConfig.TARGETS[11], "final target")
	var run2 := BMRun.new_run(31)
	run2.round_number = 4
	run2.bosses[0] = "cramped_cabinet"
	run2._start_round()
	eq(run2.board.occupied_count(), 4, "four fixed cells")
	eq(run2.round_state.fixed_cells.size(), 4, "recorded")


func test_shop_flow_buy_sell_reroll_capacity() -> void:
	var run := BMRun.new_run(55)
	run.round_state.score = run.round_state.target
	run._after_round_action()
	check(run.continue_after_round().ok, "to shop")
	eq(run.phase, BMRun.Phase.SHOP, "shop open")
	eq(run.shop.jokers.size(), 3, "3 joker offers")
	eq(run.shop.consumables.size(), 2, "2 consumable offers")
	run.credits = 50
	var id: String = run.shop.jokers[0]
	var cost := BMJokers.cost(id)
	check(run.buy_joker(0).ok, "buy")
	eq(run.credits, 50 - cost, "paid")
	check(not run.buy_joker(0).ok, "offer gone")
	check(run.reroll_shop().ok, "reroll")
	eq(run.shop.reroll_cost, 3, "reroll price rises")
	eq(run.credits, 50 - cost - 2, "reroll paid")
	run.jokers.assign(["clean_sweep", "crossbar", "small_change", "heavy_hand", "first_strike"])
	check(not run.buy_joker(1).ok, "full slots refuse purchase")
	var credits := run.credits
	check(run.sell_joker(0).ok, "sell")
	eq(run.credits, credits + 2, "half of 3 rounded up")
	eq(run.jokers_sold, 1, "sold counter")
	check(run.move_joker(0, 3).ok, "reorder")
	eq(run.jokers[3], "crossbar", "moved")
	check(run.leave_shop().ok, "leave")
	eq(run.round_number, 2, "next round")
	eq(run.round_state.target, BMRunConfig.TARGETS[1], "next target")


func test_shop_offers_deterministic() -> void:
	var a := BMRun.new_run(9001)
	var b := BMRun.new_run(9001)
	for run in [a, b]:
		run.round_state.score = run.round_state.target
		run._after_round_action()
		run.continue_after_round()
	eq(a.shop, b.shop, "same shop from same seed")


func test_full_run_is_deterministic_and_replayable() -> void:
	var a := BMAutoplayer.play(BMRun.new_run(424242))
	var b := BMAutoplayer.play(BMRun.new_run(424242))
	check(a.phase in [BMRun.Phase.RUN_WON, BMRun.Phase.RUN_LOST], "run finished")
	eq(a.to_dict(), b.to_dict(), "identical seeds and actions give identical runs")
	var c := BMRun.replay(a.run_seed, a.kit_id, a.history)
	eq(c.to_dict(), a.to_dict(), "replay from history matches")


func test_save_resume_mid_round_matches_uninterrupted() -> void:
	var a := BMRun.new_run(2024)
	for i in 5:
		BMAutoplayer.step(a)
	# Round-trip through JSON text exactly as a save file would.
	var text := JSON.stringify(a.to_dict())
	var resumed := BMRun.from_dict(JSON.parse_string(text))
	eq(resumed.to_dict(), a.to_dict(), "resumed state equals original")
	BMAutoplayer.play(a)
	BMAutoplayer.play(resumed)
	eq(resumed.to_dict(), a.to_dict(), "continuing after resume gives the same run")


func test_save_resume_from_shop() -> void:
	var a := BMRun.new_run(777)
	a.round_state.score = a.round_state.target
	a._after_round_action()
	a.continue_after_round()
	var resumed := BMRun.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	eq(resumed.phase, BMRun.Phase.SHOP, "still in shop")
	BMAutoplayer.play(a)
	BMAutoplayer.play(resumed)
	eq(resumed.to_dict(), a.to_dict(), "same outcome")


func test_many_seeds_finish_without_errors() -> void:
	var rounds_reached := 0
	for s in 10:
		var run := BMAutoplayer.play(BMRun.new_run(1000 + s))
		check(run.phase in [BMRun.Phase.RUN_WON, BMRun.Phase.RUN_LOST], "seed %d finished" % s)
		rounds_reached += run.round_number
	check(rounds_reached >= 10, "bot reaches at least round 1 each run")


func test_save_store_round_trip_and_end_clears() -> void:
	BMSaveStore.run_path = "user://test_run_save.json"
	var run := BMRun.new_run(31337)
	BMAutoplayer.step(run)
	check(BMSaveStore.save_run(run), "saved")
	var loaded := BMSaveStore.load_run()
	check(loaded != null, "loaded")
	if loaded != null:
		eq(loaded.to_dict(), run.to_dict(), "file round-trip")
	run.abandon()
	BMSaveStore.save_run(run)
	check(BMSaveStore.load_run() == null, "finished runs are not offered for Continue")
	BMSaveStore.clear_run()
	check(not BMSaveStore.has_run(), "cleared")
	BMSaveStore.run_path = BMSaveStore.RUN_PATH


func test_boss_pool_excludes_withheld_bosses() -> void:
	for s in 50:
		var run := BMRun.new_run(s)
		check(not run.bosses.has("echo_chamber"), "Echo Chamber withheld (seed %d)" % s)
