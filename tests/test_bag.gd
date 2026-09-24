extends BMTestCase
## The Bag: dealing, piles, legality guarantee, piece upgrades, Workshop tools, piece offers.

const EMPTY_ROWS := ["........", "........", "........", "........", "........", "........", "........", "........"]
const ONE_ROW := ["1111111.", "........", "........", "........", "........", "........", "........", "........"]


func _piece(family: StringName, rot: int = 0, color: int = 0, material: String = "", stamp: String = "", uid: int = 900) -> Dictionary:
	return BMPieces.make(uid, family, rot, color, material, stamp)


## Round-1 run whose tray holds `pieces`; each piece is also registered in the bag so it can be
## discarded and upgraded like a real bag piece.
func _run_with_pieces(board_rows: Array, pieces: Array, jokers: Array = []) -> BMRun:
	var run := run_with(board_rows, pieces, jokers)
	for p in pieces:
		if not p.is_empty() and int(p.uid) >= 0 and BMBag.piece_by_uid(run, int(p.uid)).is_empty():
			run.bag.append(p.duplicate(true))
	return run


func _item(r: Dictionary, label_prefix: String) -> Variant:
	for it in r.items:
		if String(it.label).begins_with(label_prefix):
			return it.value
	return null


func test_placement_discards_and_refresh_discards() -> void:
	var run := BMRun.new_run(6)
	var uid := int(run.tray[0].uid)
	var anchor: Vector2i = run.board.legal_anchors(run.tray[0].cells)[0]
	check(run.place(0, anchor).ok, "placed")
	check(run.discard_pile.has(uid), "placed piece in discard pile")
	var unplaced: Array = []
	for p in run.tray:
		if not p.is_empty():
			unplaced.append(int(p.uid))
	check(run.refresh().ok, "refresh")
	for u in unplaced:
		check(run.discard_pile.has(u), "refreshed piece discarded")
	eq(run.draw_pile.size() + run.discard_pile.size() + 2, run.bag.size(), "every piece accounted for")


func test_reshuffle_when_draw_pile_empty() -> void:
	var run := BMRun.new_run(8)
	run.discard_pile = run.draw_pile.duplicate()
	run.draw_pile = []
	var p := BMBag.draw_one(run)
	check(not p.is_empty(), "drew after reshuffle")
	eq(run.round_state.reshuffles, 1, "reshuffle counted")


func test_legality_guarantee_swaps_in_a_fitting_piece() -> void:
	var run := BMRun.new_run(9)
	run.board.cells.fill(1)
	for i in 8:
		run.board.set_cell(Vector2i(i, i), BMBoard.EMPTY)
	# Force the draw pile to hold only big pieces first, then one Single deep in the pile.
	run.tray = [{}, {}, {}]
	var singles: Array = []
	var others: Array = []
	for p in run.bag:
		if p.family == &"single":
			singles.append(int(p.uid))
		else:
			others.append(int(p.uid))
	run.draw_pile = others + singles
	run.discard_pile = []
	var r := BMBag.deal(run, [0, 1, 2])
	check(r.rescued, "a swap happened")
	check(BMBag.any_fits(run.board, run.tray), "dealt tray has a legal piece")
	eq(run.tray[2].family, &"single", "the swapped-in piece is the Single")
	eq(run.draw_pile.size() + 3, run.bag.size(), "no piece lost or duplicated")


func test_temporary_single_when_nothing_in_bag_fits() -> void:
	var run := BMRun.new_run(10)
	var keep: Array = []
	for p in run.bag:
		if p.family != &"single":
			keep.append(p)
	run.bag = keep
	BMBag.start_round(run)
	run.board.cells.fill(1)
	for i in 8:
		run.board.set_cell(Vector2i(i, i), BMBoard.EMPTY)
	run.tray = [{}, {}, {}]
	var r := BMBag.deal(run, [0, 1, 2])
	check(r.temporary, "temporary Single dealt")
	check(bool(run.tray[2].get("temporary", false)), "flagged temporary")
	eq(int(run.tray[2].uid), -1, "temporary uid")
	eq(run.draw_pile.size() + 2, run.bag.size(), "replaced piece went back to the draw pile")
	run.board.cells.fill(BMBoard.EMPTY)
	run.board.cells.fill(1)
	run.board.set_cell(Vector2i(0, 0), BMBoard.EMPTY)
	run.round_state.status = BMRun.PLAYING
	var discard_before := run.discard_pile.size()
	run.place(2, Vector2i(0, 0))
	eq(run.discard_pile.size(), discard_before, "temporary piece never enters the discard pile")


# --- Materials -----------------------------------------------------------------------------

func test_chrome_adds_chips_per_cell() -> void:
	var run := _run_with_pieces(EMPTY_ROWS, [_piece(&"bar3", 0, 0, "chrome")])
	var r := run.place(0, Vector2i(0, 0))
	eq(_item(r, "Chrome"), 60, "3 cells x 20")
	eq(r.chips, 90, "30 + 60")


func test_neon_cells_cleared_later_add_mult() -> void:
	var run := _run_with_pieces(EMPTY_ROWS, [_piece(&"bar4", 0, 1, "neon", "", 901), _piece(&"bar4", 0, 2, "", "", 902)])
	run.place(0, Vector2i(0, 0))
	check(run.board.get_mat(Vector2i(0, 0)) == BMPieces.material_index("neon"), "board remembers Neon")
	var r := run.place(1, Vector2i(4, 0))
	eq(r.lines, 1, "row cleared")
	eq(_item(r, "Neon"), 2.0, "4 Neon cells x 0.5")
	eq(r.mult, 3.0, "1 + 2")


func test_gold_cells_pay_credits_on_clear() -> void:
	var run := _run_with_pieces(ONE_ROW, [_piece(&"single", 0, 0, "gold")])
	var credits := run.credits
	var r := run.place(0, Vector2i(7, 0))
	eq(run.credits - credits, 1, "+1 Credit for one Gold cell")
	eq(r.credits_gained, 1, "recorded")


func test_glass_x_mult_and_deterministic_shatter() -> void:
	var outcomes := {}
	for s in 12:
		var run := _run_with_pieces(ONE_ROW, [_piece(&"single", 0, 0, "glass", "", 950)])
		run.rng_shapes = BMRngStream.new(s, "shapes")
		var r := run.place(0, Vector2i(7, 0))
		eq(_item(r, "Glass cleared"), 1.5, "x1.5")
		outcomes[r.shattered.size()] = true
		var again := _run_with_pieces(ONE_ROW, [_piece(&"single", 0, 0, "glass", "", 950)])
		again.rng_shapes = BMRngStream.new(s, "shapes")
		eq(again.place(0, Vector2i(7, 0)).shattered, r.shattered, "same seed, same shatter")
		if r.shattered.size() > 0:
			check(BMBag.piece_by_uid(run, 950).is_empty(), "shattered piece left the bag")
	check(outcomes.has(0) and outcomes.has(1), "both outcomes occur across seeds")


func test_glass_never_shrinks_bag_below_minimum() -> void:
	var run := _run_with_pieces(ONE_ROW, [_piece(&"single", 0, 0, "glass", "", 950)])
	run.bag = run.bag.slice(run.bag.size() - BMPieces.MIN_BAG)
	for s in 20:
		var copy := run.clone()
		copy.rng_shapes = BMRngStream.new(s, "shapes")
		copy.place(0, Vector2i(7, 0))
		eq(copy.bag.size(), BMPieces.MIN_BAG, "bag kept at minimum")


func test_prism_counts_as_blue_and_as_distinct_color() -> void:
	var run := _run_with_pieces(EMPTY_ROWS, [_piece(&"single", 0, 0, "prism")], ["blue_mood"])
	var r := run.place(0, Vector2i(0, 0))
	eq(r.mult, 3.0, "Prism triggers Blue Mood")
	var run2 := _run_with_pieces(EMPTY_ROWS, [_piece(&"single", 0, 0, "", "", 901), _piece(&"single", 0, 0, "prism", "", 902), _piece(&"single", 0, 1, "", "", 903)], ["color_cycle"])
	run2.place(0, Vector2i(0, 0))
	run2.place(1, Vector2i(2, 2))
	var r2 := run2.place(2, Vector2i(4, 4))
	eq(r2.mult, 1.75, "red, prism, orange count as three different colors")


# --- Stamps and levels ---------------------------------------------------------------------

func test_encore_doubles_mult_on_clear() -> void:
	var run := _run_with_pieces(ONE_ROW, [_piece(&"single", 0, 0, "", "encore")])
	var r := run.place(0, Vector2i(7, 0))
	eq(r.mult, 2.0, "x2 on clear")
	var run2 := _run_with_pieces(EMPTY_ROWS, [_piece(&"single", 0, 0, "", "encore")])
	eq(run2.place(0, Vector2i(0, 0)).mult, 1.0, "no clear, no Encore")


func test_refund_tip_memory() -> void:
	var run := _run_with_pieces(EMPTY_ROWS, [_piece(&"single", 0, 0, "", "refund")])
	var before := run.round_state.placements_left
	run.place(0, Vector2i(0, 0))
	eq(run.round_state.placements_left, before, "placing a Refund piece is free")
	var run2 := _run_with_pieces(EMPTY_ROWS, [_piece(&"single", 0, 0, "", "tip")])
	var c := run2.credits
	run2.place(0, Vector2i(0, 0))
	eq(run2.credits - c, 2, "Tip pays on placement")
	var run3 := _run_with_pieces(EMPTY_ROWS, [_piece(&"single", 0, 0, "", "memory")])
	run3.place(0, Vector2i(0, 0))
	eq(run3.consumables, ["spark"] as Array[String], "Memory gives a Spark")


func test_schematic_level_bonus() -> void:
	var run := _run_with_pieces(EMPTY_ROWS, [_piece(&"bar3")])
	run.family_levels["bar3"] = 2
	var r := run.place(0, Vector2i(0, 0))
	eq(r.chips, 30 + 50, "+25 Chips per level")
	eq(r.mult, 1.5, "+0.25 Mult per level")


# --- Workshop tools and piece offers ---------------------------------------------------------

func _shop_run(seed_value: int = 55) -> BMRun:
	var run := BMRun.new_run(seed_value)
	run.round_state.score = run.round_state.target
	run._after_round_action()
	run.continue_after_round()
	run.credits = 60
	return run


func _offer(run: BMRun, id: String, family: String = "") -> int:
	run.shop.tools[0] = {"id": id, "family": family}
	return 0


func test_tool_material_and_stamp() -> void:
	var run := _shop_run()
	var a := int(run.bag[0].uid)
	var b := int(run.bag[1].uid)
	check(not run.buy_tool(_offer(run, "chrome_plating"), [a, b, int(run.bag[2].uid)]).ok, "max 2 targets")
	check(run.buy_tool(_offer(run, "chrome_plating"), [a, b]).ok, "applied")
	eq(BMBag.piece_by_uid(run, a).material, "chrome", "piece a is Chrome")
	check(not run.buy_tool(_offer(run, "chrome_plating"), [a]).ok, "already Chrome")
	check(run.buy_tool(_offer(run, "neon_tubing"), [a]).ok, "material replaced")
	eq(BMBag.piece_by_uid(run, a).material, "neon", "now Neon")
	check(run.buy_tool(_offer(run, "encore_stamp"), [a]).ok, "stamped")
	eq(BMBag.piece_by_uid(run, a).stamp, "encore", "Encore")


func test_tool_copy_remove_rotate_repaint_schematic() -> void:
	var run := _shop_run()
	var p: Dictionary = run.bag[9] # l3 rot 0
	p.material = "gold"
	var size := run.bag.size()
	check(run.buy_tool(_offer(run, "copier"), [int(p.uid)]).ok, "copy")
	eq(run.bag.size(), size + 1, "bag grew")
	var copy: Dictionary = run.bag[run.bag.size() - 1]
	eq(copy.material, "gold", "copy keeps material")
	check(int(copy.uid) != int(p.uid), "copy has a new uid")
	check(run.buy_tool(_offer(run, "turntable"), [int(p.uid)]).ok, "rotate")
	eq(int(p.rot), 1, "rotated once")
	eq(p.cells, BMShapes.make_shape(&"l3", 1, 0).cells, "cells follow rotation")
	check(not run.buy_tool(_offer(run, "turntable"), [int(run.bag[13].uid)]).ok, "square has one orientation")
	check(not run.buy_tool(_offer(run, "repaint"), [int(p.uid)]).ok, "needs a color")
	check(run.buy_tool(_offer(run, "repaint"), [int(p.uid)], BMShapes.COLOR_BLUE).ok, "repaint")
	eq(int(p.color), BMShapes.COLOR_BLUE, "blue now")
	check(run.buy_tool(_offer(run, "shredder"), [int(run.bag[0].uid), int(run.bag[1].uid)]).ok, "shred 2")
	eq(run.bag.size(), size - 1, "bag shrank by 2")
	check(run.buy_tool(_offer(run, "schematic", "bar3"), []).ok, "schematic")
	eq(run.family_level(&"bar3"), 1, "level 1")


func test_shredder_respects_minimum_bag() -> void:
	var run := _shop_run()
	run.bag = run.bag.slice(0, BMPieces.MIN_BAG + 1)
	check(not run.buy_tool(_offer(run, "shredder"), [int(run.bag[0].uid), int(run.bag[1].uid)]).ok, "would go below 12")
	check(run.buy_tool(_offer(run, "shredder"), [int(run.bag[0].uid)]).ok, "down to exactly 12")


func test_failed_tool_changes_nothing() -> void:
	var run := _shop_run()
	var before := run.to_dict()
	check(not run.buy_tool(_offer(run, "copier"), [99999]).ok, "unknown piece")
	run.shop.tools[0] = before.shop.tools[0]
	eq(run.to_dict(), before, "state unchanged")


func test_buy_piece_offer() -> void:
	var run := _shop_run()
	var offer: Dictionary = run.shop.pieces[0]
	var size := run.bag.size()
	var r := run.buy_piece(0)
	check(r.ok, "bought")
	eq(run.bag.size(), size + 1, "added to bag")
	eq(r.piece.family, StringName(offer.family), "same family")
	check(run.shop.pieces[0].is_empty(), "offer gone")
