extends BMTestCase

const EMPTY_ROWS := ["........", "........", "........", "........", "........", "........", "........", "........"]


func _double_clear_board() -> Array:
	return [
		".......1",
		".......1",
		".......1",
		".......1",
		".......1",
		".......1",
		"........",
		"111111..",
	]


func test_gdd_example_305_chips_and_915_points() -> void:
	var run := run_with(_double_clear_board(), [shape(&"square2")])
	run.round_state.combo = 1
	run.round_state.pending_mult = 1.0 # Spark: Mult 1 + 1 (second line) + 1 (Spark) = 3
	var r := run.place(0, Vector2i(6, 6))
	check(r.ok, "placed")
	eq(r.lines, 2, "row and column")
	eq(r.chips, 305, "chips")
	eq(r.mult, 3.0, "mult")
	eq(r.points, 915, "points")
	eq(r.cleared.size(), 15, "crossing cell removed once")
	eq(run.round_state.combo, 2, "combo advanced")


func test_combo_caps_at_4() -> void:
	var run := run_with(EMPTY_ROWS, [shape(&"single")])
	run.round_state.combo = 4
	run.board = board_from(["1111111.", "........", "........", "........", "........", "........", "........", "........"])
	var r := run.place(0, Vector2i(7, 0))
	eq(r.chips, 10 + 100 + 100, "cells + line + combo 4")
	eq(run.round_state.combo, 4, "combo capped")


func test_invalid_drop_consumes_nothing() -> void:
	var run := run_with(["1.......", "........", "........", "........", "........", "........", "........", "........"], [shape(&"square2")])
	var before := run.round_state.placements_left
	var r := run.place(0, Vector2i(0, 0))
	check(not r.ok, "overlap rejected")
	eq(run.round_state.placements_left, before, "placement not consumed")
	check(not run.tray[0].is_empty(), "shape stays in tray")
	r = run.place(0, Vector2i(7, 7))
	check(not r.ok, "out of bounds rejected")
	eq(run.history.size(), 0, "rejected actions are not recorded")


func test_joker_chips_add_mult_then_x_mult_order() -> void:
	# Two lines: Wide Awake (+2 Mult) and Jackpot-style xMult must apply after additive Mult
	# regardless of equipped order.
	var run := run_with(_double_clear_board(), [shape(&"square2")], ["golden_ratio", "wide_awake"])
	run.round_state.placements_made = 2 # this is the 3rd placement -> Golden Ratio x1.5
	var r := run.place(0, Vector2i(6, 6))
	# chips: 40 cells + 200 lines + 40 multi = 280; mult (1 + 1 multi-line + 5) * 1.5 = 10.5
	eq(r.chips, 280, "chips")
	eq(r.mult, 10.5, "mult")
	eq(r.points, 2940, "points")
	var kinds: Array = []
	for it in r.items:
		kinds.append(it.kind)
	check(kinds.find("mult") < kinds.find("xmult"), "additive Mult listed before xMult")


func test_taxman_first_line_60() -> void:
	var run := run_with(["1111111.", "........", "........", "........", "........", "........", "........", "........"], [shape(&"single")])
	run.round_number = 4
	run.bosses[0] = "taxman"
	var r := run.place(0, Vector2i(7, 0))
	eq(r.chips, 10 + 60, "taxman reduces first line")


func test_taxman_keeps_later_lines() -> void:
	var run := run_with(_double_clear_board(), [shape(&"square2")])
	run.round_number = 4
	run.bosses[0] = "taxman"
	var r := run.place(0, Vector2i(6, 6))
	eq(r.chips, 40 + 60 + 100 + 40, "second line keeps 100")


func test_last_call_multi_line_bonus() -> void:
	var run := run_with(_double_clear_board(), [shape(&"square2")])
	run.round_number = 12
	run.bosses[2] = "last_call"
	var r := run.place(0, Vector2i(6, 6))
	eq(r.chips, 280 + 50, "last call +50 on multi-line")


func test_points_floor_once() -> void:
	var run := run_with(EMPTY_ROWS, [shape(&"single")], ["hollow_point"])
	var r := run.place(0, Vector2i(3, 3))
	# 10 chips x 1.5 mult = 15 exactly; now a fractional case with Spark 0.25
	eq(r.points, 15, "10 x 1.5")
	var run2 := run_with(EMPTY_ROWS, [shape(&"bar3")], ["hollow_point"])
	run2.round_state.pending_mult = 0.25
	var r2 := run2.place(0, Vector2i(0, 0))
	eq(r2.points, 52, "30 x 1.75 = 52.5 floors to 52")
