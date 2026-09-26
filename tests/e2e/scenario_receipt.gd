extends BME2ECase
## The score receipt keeps its place (owner report, 2026-09-26: "when it has too many lines it
## just keeps writing behind the other cards and is illegible").
##
## Ways this could fail (written down before this scenario):
##  R1  A long receipt grows the tape past its rect, under the Hold box and the cards.
##  R2  After printing, the newest line (the total) is out of view.
##  R3  The player cannot scroll back up to the first lines of a long receipt.
##  R4  Scrolling up is undone by the next line while the player reads (it should stay put),
##      or the next placement's receipt does not follow its newest line again.
## Setup: a rack of Hoarders under Hall of Mirrors (every Joker line printed twice) is written
## into the run; the placements go through the round screen's own action function.

const SEED := 88123
const TAPE := Vector2(476, 292)


func run() -> void:
	main.start_new_run(SEED, "standard", 0)
	await frames(3)
	main.game_screen.close_overlay()
	var r: BMRun = main.run
	r.extra_slots = 2 # setup
	r.jokers.assign(["hall_of_mirrors", "hoarder", "hoarder", "hoarder", "hoarder", "hoarder", "hoarder"]) # setup
	BMSaveStore.save_run(r)
	main.continue_run()
	await frames(3)
	main.game_screen.close_overlay()
	var receipt: BMHud.Receipt = main.game_screen._receipt
	var rect0 := receipt.get_global_rect()
	eq(rect0.size, TAPE, "the tape starts at its rect")
	await _place_one()
	await wait(2.0)
	var lines := receipt.line_count()
	check(lines >= 14, "setup: a long receipt (%d lines)" % lines)
	eq(receipt.get_global_rect(), rect0, "R1: the tape keeps its rect with %d lines" % lines)
	check(receipt.at_bottom(), "R2: the newest line is in view")
	var scroll: ScrollContainer = receipt._scroll
	check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "R3: the tape can scroll")
	scroll.scroll_vertical = 0
	await frames(2)
	eq(scroll.scroll_vertical, 0, "R3: scrolled back to the first line")
	check(not receipt.at_bottom(), "R3: reading the top, not the bottom")
	await frames(10)
	eq(scroll.scroll_vertical, 0, "R4: the view stays where the player put it")
	await _place_one()
	await wait(2.0)
	check(receipt.at_bottom(), "R4: the next receipt follows its newest line again")
	eq(receipt.get_global_rect(), rect0, "R1: still at its rect after the second receipt")
	await screenshot("receipt_long")
	facts["receipt"] = {"lines": lines, "jokers": Array(main.run.jokers)}
	checkpoint("receipt", facts["receipt"])
	main.abandon_run()
	await frames(2)


func _place_one() -> void:
	var r: BMRun = main.run
	for s in r.tray.size():
		if r.tray[s].is_empty() or r.slot_locked(s):
			continue
		var anchors := r.board.legal_anchors(r.tray[s].cells)
		if anchors.is_empty():
			continue
		main.game_screen._do_action({"a": "place", "slot": s, "x": anchors[0].x, "y": anchors[0].y})
		await frames(2)
		return
