extends BME2ECase
## The Warden and the no-fit rescues (release study 2026-09-26, bugs 1 and 2).
##
## Ways this could fail (written down before this scenario):
##  W1  Tiny Insurance drops its rescue Single into the Warden's barred slot: the round stays
##      PLAYING with no legal move, and Concede is refused (soft-lock; study participant 201,
##      seed 53417, round 8).
##  W2  Any state where the round is PLAYING but no tray piece (nor a stored Hold piece) can be
##      placed. The UI only offers Concede when the round is STUCK or out of placements.
##  W3  The Warden Mk II bars two distinct slots at the round start (not one, not the same one).
##  W4  The Mk II's second barred slot is never freed during the round.
##  W5  One clear frees both Mk II slots at once (the rule: each clearing placement frees one).
##  W6  The tray view disagrees with the rules about which slots are barred.
##  W7  SAVE & QUIT + CONTINUE loses or moves the bars.
## Board and tray layouts the seeded game would not reliably reach are written into the run
## and loaded through the real CONTINUE path (marked as setup). Every player step goes through
## the round screen's own action function.

const SEED := 70831


func run() -> void:
	await _tiny_insurance_never_bars_its_single()
	await _mk2_frees_one_slot_per_clear()


func _load(r: BMRun) -> BMRun:
	BMSaveStore.save_run(r)
	main.continue_run()
	await frames(3)
	main.game_screen.close_overlay()
	await frames(1)
	return main.run


func _bars_shown(r: BMRun) -> Array:
	var out: Array = []
	var slots: Array = main.game_screen.slots
	for i in slots.size():
		if slots[i].locked:
			out.append(i)
	return out


func _tiny_insurance_never_bars_its_single() -> void:
	main.start_new_run(SEED, "standard", 0)
	await frames(3)
	main.game_screen.close_overlay()
	var r: BMRun = main.run
	# Setup: a Warden round (normal) with slot 0 barred, Tiny Insurance, no Refresh left, and
	# a board whose holes are single isolated cells (two per row and per column, so no line
	# can be completed and only a Single fits anywhere).
	r.bosses[0] = "warden"
	r.round_number = 4
	r.round_card = "standard"
	r._start_round()
	r.jokers.append("tiny_insurance")
	var rs := r.round_state
	rs.locked_slot = 0
	rs.locked_slot2 = -1
	rs.refreshes_left = 0
	for y in BMBoard.SIZE:
		for x in BMBoard.SIZE:
			var hole := x == (3 * y) % 8 or x == (3 * y + 4) % 8
			r.board.set_cell(Vector2i(x, y), BMBoard.EMPTY if hole else (x + y) % BMShapes.OFFER_COLOR_COUNT)
	check(deal_family(r, 0, "bar3"), "setup: a Bar 3 for the barred slot")
	check(deal_family(r, 1, "single"), "setup: a Single for slot 2")
	check(deal_family(r, 2, "bar3"), "setup: a Bar 3 for slot 3")
	check(bag_accounted(r), "setup keeps every bag piece in one place")
	r = await _load(r)
	eq(_bars_shown(r), [0], "W6: the tray shows the Warden's bars on slot 1 only")
	# Place the Single: the last open piece (a Bar 3) no longer fits anywhere, so Tiny
	# Insurance must swap it for a Single (never the barred Bar 3).
	var anchors := r.board.legal_anchors(r.tray[1].cells)
	var res: Dictionary = main.game_screen._do_action({"a": "place", "slot": 1, "x": anchors[0].x, "y": anchors[0].y})
	await frames(2)
	r = main.run
	check(res.get("ok", false), "the Single is placed")
	check(r.round_state.tiny_insurance_used, "W1: Tiny Insurance fired")
	check(not bool(r.tray[0].get("temporary", false)), "W1: the barred slot keeps its own piece")
	check(bool(r.tray[2].get("temporary", false)), "W1: the rescue Single went to the open slot")
	eq(r.round_state.status, BMRun.PLAYING, "W1: the round goes on")
	check(has_legal_move(r), "W1/W2: PLAYING with a legal move")
	check(bag_accounted(r), "W1: the swapped Bar 3 went to the discard pile")
	# The rescue Single can be placed.
	anchors = r.board.legal_anchors(r.tray[2].cells)
	res = main.game_screen._do_action({"a": "place", "slot": 2, "x": anchors[0].x, "y": anchors[0].y})
	await frames(2)
	check(res.get("ok", false), "W1: the rescue Single can be played")
	r = main.run
	check(r.phase != BMRun.Phase.ROUND or r.round_state.status != BMRun.PLAYING or has_legal_move(r), "W2: never PLAYING without a legal move")
	facts["insurance"] = {"status": r.round_state.status, "phase": r.phase, "tray": [String(r.tray[0].get("family", "")), String(r.tray[1].get("family", "")), String(r.tray[2].get("family", ""))]}
	checkpoint("tiny insurance", facts["insurance"])
	main.abandon_run()
	await frames(2)


func _mk2_frees_one_slot_per_clear() -> void:
	main.start_new_run(SEED + 1, "standard", 4)
	await frames(3)
	main.game_screen.close_overlay()
	var r: BMRun = main.run
	# Setup: make the act-1 boss the Warden (Heat 4: every boss is Mk II) and start its round.
	r.bosses[0] = "warden"
	r.round_number = 4
	r.round_card = "standard"
	r._start_round()
	var rs := r.round_state
	check(r.boss_is_mk2(), "setup: Heat 4 makes the Warden Mk II")
	check(rs.locked_slot >= 0 and rs.locked_slot2 >= 0 and rs.locked_slot != rs.locked_slot2, "W3: Mk II bars two different slots")
	var barred := [mini(rs.locked_slot, rs.locked_slot2), maxi(rs.locked_slot, rs.locked_slot2)]
	var open_slot: int = 3 - int(barred[0]) - int(barred[1])
	r = await _load(r)
	eq(_bars_shown(r), barred, "W6/W7: after CONTINUE the tray shows both bars")
	# First clear: row 0 needs one more block.
	for x in BMBoard.SIZE - 1:
		r.board.set_cell(Vector2i(x, 0), x % BMShapes.OFFER_COLOR_COUNT)
	check(deal_family(r, open_slot, "single"), "setup: a Single in the open slot")
	r = await _load(r)
	var first_barred := r.round_state.locked_slot
	var res: Dictionary = main.game_screen._do_action({"a": "place", "slot": open_slot, "x": BMBoard.SIZE - 1, "y": 0})
	await frames(2)
	r = main.run
	check(res.get("ok", false) and int(res.get("lines", 0)) == 1, "the first placement clears a line")
	eq(int(res.get("unlocked", -1)), first_barred, "W5: the first clear frees the first barred slot")
	var still := [r.round_state.locked_slot, r.round_state.locked_slot2]
	still.erase(-1)
	eq(still.size(), 1, "W5: one slot stays barred after one clear")
	eq(_bars_shown(r), still, "W6: the tray shows the remaining bars")
	# W7: the remaining bar survives SAVE & QUIT + CONTINUE.
	main.show_pause()
	await frames(2)
	main.save_and_quit()
	await frames(2)
	main.continue_run()
	await frames(3)
	main.game_screen.close_overlay()
	r = main.run
	eq(_bars_shown(r), still, "W7: the remaining bar survives SAVE & QUIT + CONTINUE")
	# Second clear frees the other one.
	var free_slot := -1
	for i in 3:
		if not r.slot_locked(i):
			free_slot = i
			break
	r.board = BMBoard.new()
	for x in BMBoard.SIZE - 1:
		r.board.set_cell(Vector2i(x, 1), (x + 2) % BMShapes.OFFER_COLOR_COUNT)
	check(deal_family(r, free_slot, "single") or deal_family(r, free_slot, "bar2"), "setup: a small piece in an open slot")
	var cells: Array = r.tray[free_slot].cells
	r = await _load(r)
	var anchor := Vector2i(BMBoard.SIZE - 1, 1) if cells.size() == 1 else Vector2i(-1, -1)
	if anchor.x < 0:
		for a in r.board.legal_anchors(r.tray[free_slot].cells):
			var copy := r.clone()
			if int(BMResolver.resolve_placement(copy, free_slot, a).lines) > 0:
				anchor = a
				break
	res = main.game_screen._do_action({"a": "place", "slot": free_slot, "x": anchor.x, "y": anchor.y})
	await frames(2)
	r = main.run
	check(res.get("ok", false) and int(res.get("lines", 0)) >= 1, "the second placement clears a line")
	eq(int(res.get("unlocked", -1)), int(still[0]), "W4: the second clear frees the second barred slot")
	check(r.round_state.locked_slot < 0 and r.round_state.locked_slot2 < 0, "W4: no slot is barred after two clears")
	eq(_bars_shown(r), [], "W6: the tray shows no bars")
	facts["mk2"] = {"barred": barred, "first": first_barred, "second": int(still[0])}
	checkpoint("warden mk2", facts["mk2"])
	main.abandon_run()
	await frames(2)
