extends BMTestCase
## Kit starter bags and unlocks, the Boss Crate, and combo grace (round_play_update.md §4).


func test_each_kit_starts_with_its_own_bag() -> void:
	eq(BMRun.new_run(1, "standard").bag.size(), 24, "standard 24")
	var compact := BMRun.new_run(1, "compact")
	eq(compact.bag.size(), 18, "compact 18")
	for p in compact.bag:
		check(p.family != &"single", "compact has no Singles")
	var tetro := BMRun.new_run(1, "tetromino")
	for p in tetro.bag:
		eq(p.cells.size(), 4, "tetromino: four blocks each")
	var chunky := BMRun.new_run(1, "chunky")
	eq(chunky.bag.size(), 19, "chunky 19")
	var uids := {}
	for p in chunky.bag:
		uids[int(p.uid)] = true
	eq(uids.size(), chunky.bag.size(), "unique uids")


func test_kit_unlocks_follow_the_profile() -> void:
	check(BMRunConfig.kit_unlocked("standard", {}), "standard always")
	check(not BMRunConfig.kit_unlocked("compact", {"lines": 99}), "compact needs 100 lines")
	check(BMRunConfig.kit_unlocked("compact", {"lines": 100}), "unlocked at 100")
	check(BMRunConfig.kit_unlocked("tetromino", {"hands": 25}), "tetromino at 25 hands")


func test_record_run_accumulates_and_reports_unlocks() -> void:
	BMSaveStore.has_run() # static init first (see test_achievements._store)
	BMSaveStore.profile_path = "user://test_profile.cfg"
	if FileAccess.file_exists(BMSaveStore.profile_path):
		DirAccess.remove_absolute(BMSaveStore.profile_path)
	var run := BMRun.new_run(5)
	run.stats.lines_cleared = 120
	run.stats.bosses_beaten = 1
	run.phase = BMRun.Phase.RUN_LOST
	var unlocked := BMSaveStore.record_run(run)
	check(unlocked.has("compact"), "100 lines unlocks Compact")
	var p := BMSaveStore.load_profile()
	eq(p.lines, 120, "lines saved")
	eq(p.runs, 1, "run counted")
	eq(BMSaveStore.record_run(run).size(), 0, "no repeat unlock")
	DirAccess.remove_absolute(BMSaveStore.profile_path)
	BMSaveStore.profile_path = "user://profile.cfg"


func _after_boss() -> BMRun:
	var run := BMRun.new_run(17)
	run.round_number = 4
	run._start_round()
	run.round_state.score = run.round_state.target
	run._after_round_action()
	run.continue_after_round()
	return run


func test_boss_crate_appears_after_a_boss_only() -> void:
	var run := _after_boss()
	check(run.has_crate(), "crate after a boss")
	eq(run.shop.crate.size(), 3, "three offers")
	var plain := BMRun.new_run(17)
	plain.round_state.score = plain.round_state.target
	plain._after_round_action()
	plain.continue_after_round()
	check(not plain.has_crate(), "no crate after a normal round")


func test_crate_gives_one_offer_for_free() -> void:
	var run := _after_boss()
	var credits := run.credits
	var r := run.open_crate(2)
	check(r.ok, "opened")
	eq(run.credits, credits + BMRunConfig.CRATE_CREDITS, "credits taken")
	check(not run.has_crate(), "crate emptied")
	check(not run.open_crate(0).ok, "only one pick")


func test_crate_joker_respects_slots_and_saves() -> void:
	var run := _after_boss()
	run.jokers.assign(["clean_sweep", "crossbar", "small_change", "heavy_hand", "first_strike"])
	check(not run.open_crate(0).ok, "slots full")
	run.jokers.assign([])
	check(run.open_crate(0).ok, "joker added")
	eq(run.jokers.size(), 1, "one joker")
	var saved := BMRun.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	eq(saved.jokers, run.jokers, "crate result survives save")


func test_combo_survives_one_miss_then_resets() -> void:
	var run := run_with(["........", "........", "........", "........", "........", "........", "........", "........"], [shape(&"single"), shape(&"single")])
	run.round_state.combo = 3
	run.place(0, Vector2i(0, 0))
	eq(run.round_state.combo, 3, "one miss: combo holds")
	run.place(1, Vector2i(2, 2))
	eq(run.round_state.combo, 0, "second miss: reset")
