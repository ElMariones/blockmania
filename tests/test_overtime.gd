extends BMTestCase
## Overtime (GDD §19): playing on after the round-12 win, escalating targets, overtime bosses,
## the machine's score limit, and profile counting of a run that ends twice.

const EMPTY := ["........", "........", "........", "........", "........", "........", "........", "........"]


## A run that has just won round 12 (phase RUN_WON).
func _won_run(seed_value: int = 99) -> BMRun:
	var run := BMRun.new_run(seed_value)
	run.round_number = BMRunConfig.ROUND_COUNT
	run._start_round()
	run.round_state.score = run.round_state.target
	run._after_round_action()
	run.continue_after_round()
	return run


func test_overtime_targets_escalate_past_the_final_round() -> void:
	eq(BMRunConfig.target(12), BMRunConfig.TARGETS[11], "round 12 unchanged")
	eq(BMRunConfig.target(13), 22000, "round 13 = 12,500 x 1.6 x 1.08, two digits")
	var last := BMRunConfig.target(12)
	for r in range(13, 60):
		var t := BMRunConfig.target(r)
		check(t > last or t == BMRunConfig.SCORE_CAP, "round %d target rises (%d after %d)" % [r, t, last])
		check(t <= BMRunConfig.SCORE_CAP, "never above the machine's limit")
		last = t
	eq(BMRunConfig.target(80), BMRunConfig.SCORE_CAP, "far rounds sit at the limit")
	check(BMRunConfig.is_overtime(13) and not BMRunConfig.is_overtime(12), "overtime flag")


func test_winning_round_twelve_offers_overtime() -> void:
	var run := _won_run()
	eq(run.phase, BMRun.Phase.RUN_WON, "run is won")
	var r := run.apply_action({"a": "overtime"})
	check(r.ok, "overtime starts")
	eq(run.phase, BMRun.Phase.SHOP, "the shop opens")
	check(run.overtime, "flag set")
	check(not run.apply_action({"a": "overtime"}).ok, "only once")
	check(run.bosses.size() >= 4, "act 4 boss chosen for the shop ticker")
	run.apply_action({"a": "leave_shop"})
	eq(run.round_number, 13, "round 13")
	eq(run.round_state.target, BMRunConfig.target(13), "overtime target")
	eq(run.phase, BMRun.Phase.ROUND, "playing")


func test_overtime_is_not_available_before_the_win() -> void:
	var run := BMRun.new_run(3)
	check(not run.apply_action({"a": "overtime"}).ok, "not during round 1")
	run.phase = BMRun.Phase.RUN_LOST
	check(not run.apply_action({"a": "overtime"}).ok, "not after a loss")


func test_overtime_rounds_keep_going_and_bosses_never_repeat_back_to_back() -> void:
	var run := _won_run(4)
	run.apply_action({"a": "overtime"})
	for i in 12:
		run.apply_action({"a": "leave_shop"})
		if BMRunConfig.is_boss_round(run.round_number):
			check(run.current_boss() != "", "boss round %d has a boss" % run.round_number)
		run.round_state.score = run.round_state.target
		run._after_round_action()
		eq(run.phase, BMRun.Phase.ROUND_RESULT, "round %d won" % run.round_number)
		run.continue_after_round()
		eq(run.phase, BMRun.Phase.SHOP, "overtime never ends on a win")
	for a in range(3, run.bosses.size()):
		check(run.bosses[a] != run.bosses[a - 1], "act %d boss differs from the previous act" % (a + 1))
	check(run.shop.jokers.size() == BMRunConfig.JOKER_OFFERS, "shop still stocked in act 7")


func test_overtime_survives_save_and_stays_deterministic() -> void:
	var run := _won_run(8)
	run.apply_action({"a": "overtime"})
	run.apply_action({"a": "reroll"})
	run.apply_action({"a": "leave_shop"})
	var copy := BMRun.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	check(copy.overtime, "overtime saved")
	eq(copy.round_number, 13, "round saved")
	eq(copy.bosses, run.bosses, "overtime bosses saved")
	eq(copy.round_state.target, run.round_state.target, "target saved")
	var next := copy.clone()
	next.round_state.score = next.round_state.target
	next._after_round_action()
	next.continue_after_round()
	run.round_state.score = run.round_state.target
	run._after_round_action()
	run.continue_after_round()
	eq(next.shop.jokers, run.shop.jokers, "resumed run stocks the same shop")


func test_a_placement_past_the_limit_breaks_the_machine() -> void:
	var run := run_with(EMPTY, [shape(&"single")])
	run.round_state.pending_mult = 1.0e17
	var r := run.apply_action({"a": "place", "slot": 0, "x": 0, "y": 0})
	check(r.ok, "placed")
	check(r.broken, "flagged broken")
	eq(r.points, BMRunConfig.SCORE_CAP, "scores exactly the cap")
	eq(run.phase, BMRun.Phase.RUN_WON, "the run ends as a win")
	check(run.machine_broken, "machine broken")
	check(not run.apply_action({"a": "overtime"}).ok, "no overtime after breaking the machine")
	var copy := BMRun.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	check(copy.machine_broken, "saved")


func test_a_normal_placement_does_not_break() -> void:
	var run := run_with(EMPTY, [shape(&"single")])
	var r := run.apply_action({"a": "place", "slot": 0, "x": 0, "y": 0})
	check(not r.broken, "not broken")
	check(not run.machine_broken, "machine fine")


func test_score_never_exceeds_the_limit() -> void:
	var run := run_with(EMPTY, [shape(&"single"), shape(&"single")])
	run.round_state.score = BMRunConfig.SCORE_CAP - 5
	run.round_state.target = BMRunConfig.SCORE_CAP
	run.apply_action({"a": "place", "slot": 0, "x": 0, "y": 0})
	check(run.round_state.score <= BMRunConfig.SCORE_CAP, "clamped")


func test_a_run_won_then_lost_in_overtime_counts_once() -> void:
	BMSaveStore.profile_path = "user://test_profile_ot.cfg"
	if FileAccess.file_exists(BMSaveStore.profile_path):
		DirAccess.remove_absolute(BMSaveStore.profile_path)
	var run := _won_run(11)
	run.stats.lines_cleared = 50
	BMSaveStore.record_run(run)
	var p := BMSaveStore.load_profile()
	eq(p.wins, 1, "win counted")
	eq(p.runs, 1, "run counted")
	eq(p.lines, 50, "lines counted")
	run.apply_action({"a": "overtime"})
	run.stats.lines_cleared = 80
	run.phase = BMRun.Phase.RUN_LOST
	BMSaveStore.record_run(run)
	p = BMSaveStore.load_profile()
	eq(p.wins, 1, "win still counted once")
	eq(p.runs, 1, "run still counted once")
	eq(p.lines, 80, "only the new lines were added")
	DirAccess.remove_absolute(BMSaveStore.profile_path)
	BMSaveStore.profile_path = "user://profile.cfg"
