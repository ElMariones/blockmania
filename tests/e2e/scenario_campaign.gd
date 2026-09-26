extends BME2ECase
## Campaign runs played end to end through the real UI entry points (game screen and shop
## actions, the round-card picker, pause menu SAVE & QUIT, title CONTINUE), with the bot
## deciding each move on a copy of the run. Three seeds cover three Kits and Heat 0 / 2 / 4
## (Mk II bosses). A won run plays on into Overtime.
##
## Checked after every action: the action succeeded; during rounds every bag piece is in
## exactly one place; score and Credits stay within their caps; the screen matches the run
## phase; a placement scores exactly what its preview promised and the preview leaves the run
## untouched. Checked per run: save & quit + continue restores the identical run; replaying
## the seed and the action history reproduces it; the run ends in a terminal phase and lands
## in the run history.

const RUNS := [[17, "standard", 0], [2024, "chunky", 2], [4242, "tetromino", 4]]
const MAX_ACTIONS := 2500
const OVERTIME_ROUNDS := 2


func run() -> void:
	for spec in RUNS:
		await _play(int(spec[0]), String(spec[1]), int(spec[2]))
	var history := BMSaveStore.load_history()
	eq(history.size(), RUNS.size(), "every finished run is in the run history")


func _play(seed_value: int, kit: String, heat: int) -> void:
	var tag := "%s/%d/h%d" % [kit, seed_value, heat]
	# Same starting profile for every run: achievements from an earlier run would unlock
	# Jokers and change this run's shop pool (and so its fingerprint).
	if FileAccess.file_exists(BMAchievementStore.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BMAchievementStore.path))
	BMAchievementStore.forget_cache()
	main.start_new_run(seed_value, kit, heat)
	await frames(3)
	main.game_screen.close_overlay()
	var r: BMRun = main.run
	check(r != null and r.run_seed == seed_value, tag + ": run started")
	var saved_resume := false
	var shot_round := false
	var shot_shop := false
	var picks := 0
	var actions := 0
	var overtime_left := OVERTIME_ROUNDS
	while actions < MAX_ACTIONS:
		r = main.run
		if r.phase == BMRun.Phase.RUN_WON and not r.overtime:
			var ot: Dictionary = main.game_screen._do_action({"a": "overtime"})
			if not check(ot.get("ok", false), tag + ": KEEP PLAYING starts Overtime"):
				break
			checkpoint(tag + " overtime", {"round": main.run.round_number})
			await frames(2)
			continue
		if r.phase in [BMRun.Phase.RUN_WON, BMRun.Phase.RUN_LOST, BMRun.Phase.ABANDONED]:
			break
		if r.overtime and r.round_number > BMRunConfig.ROUND_COUNT + overtime_left:
			main.abandon_run()
			await frames(2)
			break
		# Save & quit from the pause menu, then CONTINUE from the title: same run, same screen.
		if not saved_resume and r.phase == BMRun.Phase.SHOP and r.round_number >= 3:
			saved_resume = true
			var before := run_digest(r)
			main.show_pause()
			await frames(2)
			main.save_and_quit()
			await frames(2)
			check(main.title_screen.visible, tag + ": SAVE & QUIT returns to the title")
			check(main.title_screen._continue.visible, tag + ": CONTINUE RUN is offered")
			main.continue_run()
			await frames(3)
			eq(run_digest(main.run), before, tag + ": continued run is identical")
			check(main.shop_screen.visible, tag + ": continues in the shop")
			r = main.run
		if r.phase == BMRun.Phase.ROUND and not shot_round and r.round_state.placements_made >= 4:
			shot_round = true
			await screenshot("%s_round" % kit)
		if r.phase == BMRun.Phase.SHOP and not shot_shop:
			shot_shop = true
			await screenshot("%s_shop" % kit)
		var a := bot_action(r)
		if a.is_empty():
			check(false, tag + ": bot had no action in phase %d" % r.phase)
			break
		var res: Dictionary
		if r.phase == BMRun.Phase.SHOP:
			if a.a == "leave_shop" and not Array(r.shop.get("round_cards", [])).is_empty():
				# Take a different round card each time, through the picker overlay.
				main.shop_screen._show_round_picker()
				await frames(1)
				main.shop_screen._pick_round_and_go(picks % 3)
				picks += 1
				res = {"ok": main.run.phase == BMRun.Phase.ROUND}
			else:
				res = main.shop_screen._act(a)
		else:
			if r.phase == BMRun.Phase.ROUND and main.game_screen.overlay.get_child_count() > 0 and a.a != "continue":
				main.game_screen.close_overlay()
			# The score preview shown while carrying a piece must equal the real result and
			# must not touch the run.
			var preview := {}
			if a.a == "place":
				var before_preview := run_digest(r)
				preview = r.preview_place(int(a.slot), Vector2i(int(a.x), int(a.y)))
				eq(run_digest(r), before_preview, tag + ": the preview leaves the run untouched")
			res = main.game_screen._do_action(a)
			if a.a == "place" and res.get("ok", false):
				eq(int(res.get("points", -1)), int(preview.get("points", -2)), tag + ": preview equals the placed result")
		actions += 1
		if not check(res.get("ok", false), "%s: action %s failed: %s" % [tag, str(a), str(res.get("error", ""))]):
			break
		r = main.run
		# Piles are rebuilt when a round starts; the invariant holds throughout rounds.
		if r.phase == BMRun.Phase.ROUND and not check(bag_accounted(r), "%s: bag accounting after %s" % [tag, str(a)]):
			break
		# Never a soft-lock: a round that is still PLAYING always has a legal move.
		if r.phase == BMRun.Phase.ROUND and r.round_state.status == BMRun.PLAYING:
			check(has_legal_move(r), "%s: PLAYING with a legal move after %s" % [tag, str(a)])
		check(r.round_state.score <= BMRunConfig.SCORE_CAP, tag + ": score within the machine's limit")
		check(r.credits >= 0 and r.credits <= BMRunConfig.CREDIT_CAP, tag + ": credits within 0..cap")
		if r.phase == BMRun.Phase.SHOP:
			check(main.shop_screen.visible, tag + ": shop phase shows the shop")
		elif r.phase == BMRun.Phase.ROUND:
			check(main.game_screen.visible, tag + ": round phase shows the board")
		if res.get("type", "") == "continue" or a.a == "continue":
			checkpoint(tag + " round %d" % r.round_number, {"credits": r.credits, "jokers": r.jokers.size()})
		await frames(1)
	r = main.run
	check(actions < MAX_ACTIONS, tag + ": run finished within %d actions" % MAX_ACTIONS)
	check(r.phase in [BMRun.Phase.RUN_WON, BMRun.Phase.RUN_LOST, BMRun.Phase.ABANDONED], tag + ": run ended (phase %d)" % r.phase)
	check(saved_resume or r.round_number < 3, tag + ": save/resume was exercised")
	await screenshot("%s_end" % kit)
	# The seed plus the recorded history replays to the identical run.
	var replayed := BMRun.replay(r.run_seed, r.kit_id, r.history, r.heat, r.locked_jokers)
	eq(run_digest(replayed), run_digest(r), tag + ": replay reproduces the run")
	facts[tag] = {"round": r.round_number, "phase": r.phase, "overtime": r.overtime, "actions": r.history.size(),
		"credits": r.credits, "jokers": Array(r.jokers), "locked": Array(r.locked_jokers), "digest": run_digest(r)}
	checkpoint(tag + " end", facts[tag])
	main.show_title()
	await frames(2)
