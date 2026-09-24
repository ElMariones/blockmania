extends BMTestCase
## GDD §22.9-22.10: settings defaults, contextual tips, run history and Heat availability.


func test_every_menu_setting_has_a_default() -> void:
	var d := BMSaveStore.default_settings()
	for k in ["game_speed", "tips", "tips_seen", "boss_intro", "heartbeat", "vsync", "screen_fx", "shake", "flashes",
			"master_volume", "music_volume", "sfx_volume", "muted", "music_on", "mute_unfocused",
			"fullscreen", "crt", "show_fps", "reduced_motion", "block_patterns", "last_heat"]:
		check(d.has(k), "default for %s" % k)
	eq(d.game_speed, "normal", "normal speed by default")
	eq(d.tips, true, "tips on by default")


func test_tip_ids_are_unique_and_written() -> void:
	var seen := {}
	for d in BMTips.CATALOG:
		check(not seen.has(d.id), "unique %s" % d.id)
		seen[d.id] = true
		check(String(d.title) != "" and String(d.text) != "", "text for %s" % d.id)


func test_round_tips_follow_the_run() -> void:
	var run := BMRun.new_run(301)
	eq(BMTips.for_round(run, []), "welcome", "first round, nothing placed: welcome")
	eq(BMTips.for_round(run, ["welcome"]), "", "nothing else yet")
	var a: Vector2i = run.board.legal_anchors(run.tray[0].cells)[0]
	run.round_state.target = 999999
	run.place(0, a)
	eq(BMTips.for_round(run, ["welcome"]), "score", "after the first placement: scoring")
	var heat := BMRun.new_run(302, "standard", 2)
	eq(BMTips.for_round(heat, []), "heat", "a Heat run explains Heat first")
	var boss := BMRun.new_run(303)
	boss.round_number = BMRunConfig.ROUNDS_PER_ACT
	boss._start_round()
	eq(BMTips.for_round(boss, []), "boss", "a boss round explains bosses")


func test_shop_tips_follow_the_run() -> void:
	var run := BMRun.new_run(304)
	eq(BMTips.for_shop(run, []), "", "not in the shop")
	run.round_state.score = run.round_state.target
	run._after_round_action()
	run.continue_after_round()
	eq(BMTips.for_shop(run, []), "shop", "first visit")
	run.credits = BMRunConfig.INTEREST_STEP
	eq(BMTips.for_shop(run, ["shop"]), "interest", "Credits saved: interest")


func test_history_keeps_the_newest_runs_first() -> void:
	BMSaveStore.has_run() # static init first (see test_achievements._store)
	BMSaveStore.history_path = "user://test_history.json"
	if FileAccess.file_exists(BMSaveStore.history_path):
		DirAccess.remove_absolute(BMSaveStore.history_path)
	var lost := BMRun.new_run(310)
	lost.phase = BMRun.Phase.RUN_LOST
	lost.round_number = 6
	BMSaveStore.append_history(lost)
	var won := BMRun.new_run(311, "standard", 1)
	won.phase = BMRun.Phase.RUN_WON
	won.round_number = 12
	BMSaveStore.append_history(won)
	var list := BMSaveStore.load_history()
	eq(list.size(), 2, "two runs")
	eq(int(list[0].seed), 311, "newest first")
	eq(BMTitleScreen.history_result(list[0]), "WON", "won")
	eq(BMTitleScreen.history_result(list[1]), "LOST  ROUND 6", "lost")
	# The same won run going on into Overtime updates its entry instead of adding one.
	won.overtime = true
	won.round_number = 14
	won.phase = BMRun.Phase.RUN_LOST
	BMSaveStore.append_history(won)
	list = BMSaveStore.load_history()
	eq(list.size(), 2, "still two")
	eq(BMTitleScreen.history_result(list[0]), "WON  +2 OVERTIME", "overtime shown")
	for i in BMSaveStore.HISTORY_MAX + 5:
		var r := BMRun.new_run(400 + i)
		r.phase = BMRun.Phase.RUN_LOST
		BMSaveStore.append_history(r)
	eq(BMSaveStore.load_history().size(), BMSaveStore.HISTORY_MAX, "capped")
	DirAccess.remove_absolute(BMSaveStore.history_path)
	BMSaveStore.history_path = BMSaveStore.HISTORY_PATH


func test_heat_unlocks_one_level_at_a_time() -> void:
	BMSaveStore.has_run()
	BMSaveStore.profile_path = "user://test_profile_heat.cfg"
	if FileAccess.file_exists(BMSaveStore.profile_path):
		DirAccess.remove_absolute(BMSaveStore.profile_path)
	eq(BMSaveStore.heat_available(), 0, "fresh profile: Heat 0 only")
	var run := BMRun.new_run(320, "standard", 0)
	run.phase = BMRun.Phase.RUN_WON
	BMSaveStore.record_run(run)
	eq(BMSaveStore.heat_available(), 1, "a win unlocks Heat 1")
	var hot := BMRun.new_run(321, "standard", 3)
	hot.phase = BMRun.Phase.RUN_LOST
	BMSaveStore.record_run(hot)
	eq(BMSaveStore.heat_available(), 1, "a loss unlocks nothing")
	DirAccess.remove_absolute(BMSaveStore.profile_path)
	BMSaveStore.profile_path = "user://profile.cfg"
