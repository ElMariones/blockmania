extends BME2ECase
## Practice seeds, the Veteran Joker and the Kit perks (owner requests, 2026-09-24).
##
## Ways these could fail (written down before this scenario):
##  P1  A run on a typed seed still counts: the lifetime profile (runs, lines), Kit or Heat
##      progress, records or achievements change when it ends.
##  P2  The practice mark is lost on SAVE & QUIT + CONTINUE, so the rest of the run counts.
##  P3  A normal (random seed) run stops counting after the change.
##  V1  Placing a piece with Veteran does not train that exact bag piece, or trains others of
##      the same shape too.
##  V2  Trained Chips do not score: the receipt has no "Veteran training" line of the right size.
##  V3  Copier does not copy the trained Chips, or the copy stays linked to the original.
##  V4  Selling Veteran wipes the trained Chips or stops them scoring.
##  V5  A shop-bought piece of the same shape starts trained.
##  V6  Trained Chips are lost on save and load.
##  K1  Chunky's Heavy Lifting does not give 2 placements back per cleared line.
##  K2  Compact's Thrift does not pay for Refreshes left unused at a round win.
##  K3  Tetromino's Full House does not pay a Credit when a Tray Hand forms.
## Setup that the shop's seeded offers would not reliably give (Veteran in the rack, a Copier
## offer) is written into the run directly and marked as setup; every player step goes
## through the screens' own action functions.

const PRACTICE_SEED := 55501
const SEED := 55502


func run() -> void:
	await _practice_does_not_count()
	await _veteran()
	await _kits()


func _practice_does_not_count() -> void:
	var prof0 := BMSaveStore.load_profile()
	var ach0: int = BMAchievementStore.data().unlocked.size()
	main.title_screen._show_kit_picker(str(PRACTICE_SEED))
	await frames(2)
	main.title_screen._start_campaign("standard")
	await frames(3)
	main.game_screen.close_overlay()
	check(main.run.custom_seed, "P1: a typed seed starts a practice run")
	for i in 6:
		var a := bot_action(main.run)
		if a.is_empty() or main.run.phase != BMRun.Phase.ROUND:
			break
		main.game_screen._do_action(a)
		await frames(1)
	# P2: SAVE & QUIT, CONTINUE: still practice.
	main.show_pause()
	await frames(2)
	main.save_and_quit()
	await frames(2)
	main.continue_run()
	await frames(3)
	check(main.run.custom_seed, "P2: the practice mark survives SAVE & QUIT + CONTINUE")
	main.abandon_run()
	await frames(2)
	var prof1 := BMSaveStore.load_profile()
	eq(int(prof1.runs), int(prof0.runs), "P1: a practice run adds no run to the profile")
	eq(int(prof1.lines), int(prof0.lines), "P1: a practice run adds no lines to the profile")
	eq(BMAchievementStore.data().unlocked.size(), ach0, "P1: a practice run unlocks no achievement")
	# P3: a random-seed run still counts.
	main.start_new_run(SEED, "standard", 0)
	await frames(3)
	main.game_screen.close_overlay()
	check(not main.run.custom_seed, "P3: a normal run is not practice")
	main.abandon_run()
	await frames(2)
	eq(int(BMSaveStore.load_profile().runs), int(prof0.runs) + 1, "P3: a normal run is recorded")
	checkpoint("practice", {"runs": int(prof0.runs)})


func _place_first_fitting() -> Dictionary:
	var r: BMRun = main.run
	for s in r.tray.size():
		if r.tray[s].is_empty() or r.slot_locked(s) or bool(r.tray[s].get("temporary", false)):
			continue
		var anchors := r.board.legal_anchors(r.tray[s].cells)
		if anchors.is_empty():
			continue
		var uid := int(r.tray[s].uid)
		var res: Dictionary = main.game_screen._do_action({"a": "place", "slot": s, "x": anchors[0].x, "y": anchors[0].y})
		await frames(1)
		res["uid"] = uid
		return res
	return {}


func _veteran_line(res: Dictionary) -> int:
	for it in res.get("items", []):
		if String(it.get("label", "")) == "Veteran training":
			return int(it.value)
	return 0


func _veteran() -> void:
	main.start_new_run(SEED, "standard", 0)
	await frames(3)
	main.game_screen.close_overlay()
	var r: BMRun = main.run
	r.jokers.append("veteran") # setup
	var res := await _place_first_fitting()
	var uid := int(res.get("uid", -1))
	var bp := BMBag.piece_by_uid(r, uid)
	eq(int(bp.get("veteran", 0)), BMJokers.VETERAN_STEP, "V1: the placed piece trained +5")
	var trained := 0
	for p in r.bag:
		if int(p.get("veteran", 0)) > 0:
			trained += 1
	eq(trained, 1, "V1: only that exact piece trained")
	eq(_veteran_line(res), 0, "V2: the first placement had nothing trained yet")
	# Play until the trained piece comes back, then check it scores its Chips.
	var scored := -1
	var guard := 0
	while scored < 0 and guard < 400 and r.phase in [BMRun.Phase.ROUND, BMRun.Phase.ROUND_RESULT, BMRun.Phase.SHOP]:
		guard += 1
		if r.phase == BMRun.Phase.ROUND_RESULT:
			main.game_screen._do_action({"a": "continue"})
			await frames(1)
			continue
		if r.phase == BMRun.Phase.SHOP:
			main.shop_screen._on_leave()
			await frames(1)
			if main.shop_screen._picker_open():
				main.shop_screen._pick_round_and_go(0)
			await frames(2)
			main.game_screen.close_overlay()
			continue
		var slot := -1
		for s in r.tray.size():
			if not r.tray[s].is_empty() and int(r.tray[s].get("uid", -1)) == uid and not r.board.legal_anchors(r.tray[s].cells).is_empty():
				slot = s
		if slot >= 0:
			var an := r.board.legal_anchors(r.tray[slot].cells)
			var before := int(BMBag.piece_by_uid(r, uid).veteran)
			var rr: Dictionary = main.game_screen._do_action({"a": "place", "slot": slot, "x": an[0].x, "y": an[0].y})
			await frames(1)
			scored = _veteran_line(rr)
			eq(scored, before, "V2: the receipt shows the trained Chips")
			eq(int(BMBag.piece_by_uid(r, uid).veteran), before + BMJokers.VETERAN_STEP, "V1: it trained again")
		else:
			var a := bot_action(r)
			if a.is_empty():
				break
			main.game_screen._do_action(a)
			await frames(1)
	check(scored > 0, "V2: the trained piece was played again")
	# V6: save and load keep it.
	var loaded := BMRun.from_dict(r.to_dict(true))
	eq(int(BMBag.piece_by_uid(loaded, uid).get("veteran", 0)), int(BMBag.piece_by_uid(r, uid).veteran), "V6: trained Chips survive save and load")
	# Finish the round (or lose it) and go to the shop.
	guard = 0
	while r.phase == BMRun.Phase.ROUND and guard < 80:
		guard += 1
		var a := bot_action(r)
		if a.is_empty():
			break
		main.game_screen._do_action(a)
		await frames(1)
	if r.phase == BMRun.Phase.ROUND_RESULT:
		main.game_screen._do_action({"a": "continue"})
		await frames(2)
	if not check(r.phase == BMRun.Phase.SHOP, "reached the shop to test Copier"):
		return
	# V3: Copier copies the trained Chips; the copy then trains on its own.
	r.shop.tools[0] = {"id": "copier"} # setup
	r.credits = 30 # setup
	var trained_now := int(BMBag.piece_by_uid(r, uid).veteran)
	var n := r.bag.size()
	var cr: Dictionary = main.shop_screen._act({"a": "buy_tool", "i": 0, "targets": [uid]})
	check(cr.get("ok", false), "V3: Copier bought")
	var copy: Dictionary = r.bag[r.bag.size() - 1]
	eq(r.bag.size(), n + 1, "V3: one piece added")
	eq(int(copy.get("veteran", 0)), trained_now, "V3: the copy carries the trained Chips")
	# V5: a shop piece of any shape starts untrained.
	var bought := -1
	for i in r.shop.pieces.size():
		if not r.shop.pieces[i].is_empty():
			var pr: Dictionary = main.shop_screen._act({"a": "buy_piece", "i": i})
			if pr.get("ok", false):
				bought = i
				break
	if bought >= 0:
		eq(int(r.bag[r.bag.size() - 1].get("veteran", 0)), 0, "V5: a bought piece starts untrained")
	# V4: sell Veteran; trained Chips stay.
	var vi := r.jokers.find("veteran")
	main.shop_screen._act({"a": "sell", "i": vi})
	check(not r.jokers.has("veteran"), "V4: Veteran sold")
	eq(int(BMBag.piece_by_uid(r, uid).veteran), trained_now, "V4: trained Chips stay after selling Veteran")
	facts["veteran"] = {"trained": trained_now, "copy": int(copy.get("veteran", 0))}
	checkpoint("veteran", facts.veteran)
	main.abandon_run()
	await frames(2)


func _kits() -> void:
	# K1: Chunky gives 2 placements back per cleared line (up to its cap).
	main.start_new_run(SEED, "chunky", 0)
	await frames(3)
	main.game_screen.close_overlay()
	var r: BMRun = main.run
	var refill_seen := 0
	var guard := 0
	while r.phase == BMRun.Phase.ROUND and guard < 60 and refill_seen == 0:
		guard += 1
		var before_left := r.round_state.placements_left
		var cap := r.round_state.placement_cap
		var a := bot_action(r)
		if a.is_empty():
			break
		var res: Dictionary = main.game_screen._do_action(a)
		await frames(1)
		if String(a.get("a", "")) == "place" and int(res.get("lines", 0)) > 0 and not res.has("stamp_refund"):
			var room := cap - (before_left - 1)
			var expect := mini(int(res.lines) * 2, room)
			if expect > 0 and String(res.get("stamp", "")) != "refund":
				eq(int(res.get("placements_refilled", -1)), expect, "K1: Chunky refills 2 per line up to the cap")
				refill_seen = expect
	check(refill_seen > 0, "K1: saw a Chunky refill")
	main.abandon_run()
	await frames(2)
	# K2 + K3 through a played round: Thrift on the win line, Full House on every Hand.
	for kit in ["compact", "tetromino"]:
		main.start_new_run(SEED, kit, 0)
		await frames(3)
		main.game_screen.close_overlay()
		r = main.run
		var hands_paid := true
		guard = 0
		while r.phase == BMRun.Phase.ROUND and guard < 80:
			guard += 1
			var hands_before := int(r.round_state.hands_formed)
			var credits_before := r.credits
			var a := bot_action(r)
			if a.is_empty():
				break
			main.game_screen._do_action(a)
			await frames(1)
			if kit == "tetromino" and r.phase == BMRun.Phase.ROUND and String(a.get("a", "")) == "place":
				var formed := int(r.round_state.hands_formed) - hands_before
				var gained := r.credits - credits_before
				if formed > 0 and gained < formed:
					hands_paid = false
		if kit == "tetromino":
			check(hands_paid, "K3: Full House pays a Credit per Hand")
		if kit == "compact" and r.phase in [BMRun.Phase.ROUND_RESULT, BMRun.Phase.SHOP]:
			var lines: Array = r.last_round_result.get("credit_lines", r.last_round_result.get("lines", []))
			var thrift := 0
			for l in lines:
				if String(l.get("label", "")).begins_with("Thrift"):
					thrift = int(l.value)
			var left := int(r.round_state.refreshes_left)
			eq(thrift, left, "K2: Thrift pays 1 Credit per unused Refresh")
			facts["thrift"] = thrift
		main.abandon_run()
		await frames(2)
	checkpoint("kits")
