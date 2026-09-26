extends BME2ECase
## First-session tutorial with the POPS helper (GDD §23), end to end.
##
## Written before the tutorial code, from this list of ways it could fail:
##  F1  It does not appear on a fresh profile's first run.
##  F2  It appears again after being finished or skipped (next run, next launch).
##  F3  SKIP leaves pieces behind (helper, dim, pointer) or is not saved.
##  F4  A step waits for an action the helper blocks: the dim or the dialog eats the clicks
##      the player needs on the board, the tray or the shop.
##  F5  The helper or its dialog covers the thing it points at.
##  F6  Steps run out of order, or the "place a piece" step advances without a placement.
##  F7  A step points at a control from the other screen (round vs shop), or at a freed node.
##  F8  The tutorial changes the run: extra history entries, different score or RNG.
##  F9  Pausing mid-tutorial draws the helper over the pause menu or loses the step.
##  F10 Contextual tips pop up on top of the tutorial and repeat what POPS says.
##  F11 The gibberish voice plays once per character with no limit, or keeps talking after
##      SKIP.
##  F12 Reduced Motion still slides and bobs the helper.
##  F13 REPLAY TUTORIAL in Options does not bring it back.
## Added with the owner's tutorial feedback (2026-09-24), before the changes:
##  F14 The pointing glove is hidden under POPS or his dialog (tray and clear steps).
##  F15 During the "clear a line" task, which can take several turns, the dialog and the dim
##      stay over the board instead of POPS ducking down to a reminder.
##  F16 After "see you in the shop" POPS stays on screen for the rest of the round.
##  F17 In the shop POPS forces NEXT ROUND and sits over the Joker cards: after his last shop
##      line he must leave, and buying must still work.

const SEED := 90210


func run() -> void:
	var tut = main.get("tutorial")
	if not check(tut != null, "BMMain has a tutorial node"):
		return
	main.set_setting("tips", true)
	# F1: a fresh profile starts the tutorial on the first run, once the round intro is gone.
	main.title_screen._show_kit_picker(str(SEED))
	await frames(2)
	main.title_screen._start_campaign("standard")
	await frames(3)
	main.game_screen.close_overlay()
	await frames(3)
	check(tut.active, "F1: the tutorial starts on the first run")
	eq(tut.step_id, "hello", "F6: it opens with the greeting")
	check(tut.has_skip(), "F3: SKIP is offered from the first line")
	await screenshot("tut_hello")
	var seen: Array[String] = []
	var voice_before: int = tut.voice_count
	# Walk the round steps. NEXT only where the step allows it; actions go through the UI.
	var guard := 0
	while tut.active and main.run.phase == BMRun.Phase.ROUND and guard < 40:
		guard += 1
		await _settle(tut)
		await _check_step(tut, seen)
		match tut.step_id:
			"place":
				check(not tut.can_next(), "F6: the place step has no NEXT")
				var before: int = main.run.round_state.placements_made
				await _place_via_ui()
				check(main.run.round_state.placements_made == before + 1, "a placement went through while POPS was up")
			"clear":
				# Keep placing until a clear (or a handful of placements): the step must follow.
				var n := 0
				var ducked := false
				while tut.step_id == "clear" and n < 12 and main.run.phase == BMRun.Phase.ROUND:
					await _place_via_ui()
					# POPS ducks once his line is typed out: give it up to 2 s rather than one
					# sample (a slow machine may still be typing 0.3 s after the placement).
					for t in 20:
						await wait(0.1)
						if tut.step_id != "clear":
							break
						ducked = ducked or (tut.minimized() and not tut._dialog.visible and tut.target_rect().size == Vector2.ZERO)
						if ducked:
							break
					n += 1
				if n > 1:
					check(ducked, "F15: POPS ducks down while the clear takes several turns")
			"play":
				await wait(4.5)
				check(tut.step_id == "away_round" and not tut.visible, "F16: POPS leaves after 'see you in the shop'")
				continue
			"away_round":
				# Last round step: finish the round (bot moves through the UI).
				var n := 0
				while main.run.phase == BMRun.Phase.ROUND and n < 60:
					var a := bot_action(main.run)
					if a.is_empty():
						break
					main.game_screen.close_overlay()
					main.game_screen._do_action(a)
					await frames(1)
					n += 1
			_:
				check(tut.can_next(), "step %s can be advanced with NEXT" % tut.step_id)
				if tut.step_id == "receipt":
					# F10: no tip while POPS is talking.
					check(main._tip_stage.get_child_count() == 0, "F10: no tip on top of the tutorial")
					# F9: pause keeps the step and sits on top.
					var step: String = tut.step_id
					main.show_pause()
					await frames(2)
					check(not tut.visible or tut.get_index() < main._pause.get_index(), "F9: the pause menu is above POPS")
					main.close_pause()
					await frames(2)
					eq(tut.step_id, step, "F9: the step survives a pause")
				tut.press_next()
		await frames(2)
	# Round won or lost: the round result screen, then the shop steps.
	if main.run.phase == BMRun.Phase.ROUND_RESULT:
		main.game_screen._do_action({"a": "continue"})
		await frames(3)
	if main.run.phase == BMRun.Phase.SHOP:
		guard = 0
		while tut.active and guard < 20:
			guard += 1
			await _settle(tut)
			await _check_step(tut, seen)
			if tut.step_id == "next_round":
				check(tut.can_next(), "F17: the NEXT ROUND hint can be dismissed")
				if tut.typing():
					tut.press_next() # the first press only finishes the line
				tut.press_next()
				await frames(3)
				check(tut.away() and not tut.visible, "F17: POPS leaves the shop after his last line (step %s, visible %s)" % [tut.step_id, tut.visible])
				check(tut.active, "F17: the tour waits for the next round")
				main.shop_screen._on_leave()
				await frames(2)
				if main.shop_screen._picker_open():
					main.shop_screen._pick_round_and_go(0)
				await frames(3)
				# POPS waits for the round intro to close before saying goodbye.
				check(not tut.visible, "POPS stays hidden behind the round intro")
				main.game_screen.close_overlay()
				await frames(2)
			elif tut.can_next():
				tut.press_next()
			await frames(2)
		await _settle(tut)
		if tut.active and tut.step_id == "bye":
			await _check_step(tut, seen)
			tut.press_next()
			await frames(3)
	check(not tut.active, "the tutorial ends after the shop")
	check(bool(BMSaveStore.load_settings().get("tutorial_done", false)), "F2: finishing is saved")
	check(seen.has("place") and seen.has("shop") and seen.has("bye"), "F6: saw the round, shop and goodbye steps: %s" % str(seen))
	# F6: order follows the catalog.
	var order: Array = BMTutorialSteps.ids()
	var last := -1
	var ordered := true
	for s in seen:
		var i := order.find(s)
		if i < last:
			ordered = false
		last = maxi(last, i)
	check(ordered, "F6: steps shown in catalog order: %s" % str(seen))
	# F11: the voice is rate-limited and quiet after the tutorial.
	var voiced: int = tut.voice_count - voice_before
	check(voiced > 0, "F11: POPS spoke")
	check(voiced <= tut.letters_spoken / 2 + seen.size(), "F11: at most one voice blip per two letters (%d for %d letters)" % [voiced, tut.letters_spoken])
	# F8: the run only holds player actions and replays identically.
	var r: BMRun = main.run
	var replayed := BMRun.replay(r.run_seed, r.kit_id, r.history, r.heat, r.locked_jokers)
	eq(run_digest(replayed), run_digest(r), "F8: the tutorial did not change the run")
	facts["steps"] = seen
	checkpoint("tutorial finished", {"steps": seen, "voice": voiced})
	# F2: a new run does not show it again.
	main.start_new_run(SEED + 1, "standard", 0)
	await frames(3)
	main.game_screen.close_overlay()
	await frames(3)
	check(not tut.active, "F2: no tutorial on the second run")
	# F13 + F3: REPLAY TUTORIAL brings it back; SKIP removes everything and is saved.
	main.show_options()
	await frames(2)
	var menu := main._pause.get_child(0) as BMSettingsMenu
	menu.show_tab("game")
	await frames(1)
	var replay := menu.find_child("ReplayTutorial", true, false) as Button
	if check(replay != null, "F13: Options has REPLAY TUTORIAL"):
		replay.pressed.emit()
		await frames(1)
	main.close_pause()
	main.start_new_run(SEED + 2, "standard", 0)
	await frames(3)
	main.game_screen.close_overlay()
	await frames(3)
	check(tut.active, "F13: the tutorial is back after REPLAY TUTORIAL")
	# F12: Reduced Motion keeps POPS still.
	main.set_setting("reduced_motion", true)
	await frames(2)
	var p0: Vector2 = tut.helper_rect().position
	await wait(0.4)
	eq(tut.helper_rect().position, p0, "F12: no bobbing under Reduced Motion")
	main.set_setting("reduced_motion", false)
	var voice_at_skip: int = tut.voice_count
	tut.skip()
	await frames(3)
	check(not tut.active and not tut.visible, "F3: SKIP hides POPS, the dim and the pointer")
	check(bool(BMSaveStore.load_settings().get("tutorial_done", false)), "F3: SKIP is saved")
	await wait(0.6)
	eq(tut.voice_count, voice_at_skip, "F11: POPS stops talking on SKIP")
	facts["skip"] = true
	main.show_title()
	await frames(2)


## Waits for the typewriter to finish the current line (or 3 s).
func _settle(tut) -> void:
	var t := 0
	while tut.active and tut.typing() and t < 180:
		await frames(1)
		t += 1


## F4, F5, F7 for the current step.
func _check_step(tut, seen: Array[String]) -> void:
	var id: String = tut.step_id
	if seen.is_empty() or seen.back() != id:
		seen.append(id)
		await screenshot("tut_" + id)
	check(tut.blocks_only_dialog(), "F4: step %s: only the dialog takes clicks" % id)
	var target: Rect2 = tut.target_rect()
	if target.size != Vector2.ZERO:
		var glove := Rect2(tut._glove.position, tut._glove.size)
		check(not glove.intersects(tut.dialog_rect()) and not glove.intersects(tut.helper_rect()), "F14: step %s: the glove is not under POPS or his dialog" % id)
		check(not tut.helper_rect().intersects(target), "F5: step %s: POPS does not cover the target" % id)
		check(not tut.dialog_rect().intersects(target), "F5: step %s: the dialog does not cover the target" % id)
		check(tut.target_on_screen(), "F7: step %s points at a visible control" % id)


func _place_via_ui() -> void:
	var r: BMRun = main.run
	for s in r.tray.size():
		if r.tray[s].is_empty() or r.slot_locked(s):
			continue
		var anchors := r.board.legal_anchors(r.tray[s].cells)
		if anchors.is_empty():
			continue
		# Prefer a placement that clears, else the lowest anchor.
		var pick: Vector2i = anchors[anchors.size() - 1]
		for a in anchors:
			var c := r.clone()
			if int(c.place(s, a).get("lines", 0)) > 0:
				pick = a
				break
		main.game_screen._do_action({"a": "place", "slot": s, "x": pick.x, "y": pick.y})
		await frames(2)
		return
	if r.refreshes_available() > 0:
		main.game_screen._do_action({"a": "refresh"})
		await frames(2)
