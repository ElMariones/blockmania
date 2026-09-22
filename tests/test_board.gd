extends BMTestCase


func test_empty_board_accepts_any_shape_at_origin() -> void:
	var b := BMBoard.new()
	check(b.can_place(shape(&"square3").cells, Vector2i(0, 0)), "3x3 fits at origin")
	eq(b.empty_count(), 64, "empty count")


func test_edge_bounds() -> void:
	var b := BMBoard.new()
	var bar4: Array[Vector2i] = shape(&"bar4", 0).cells # horizontal
	check(b.can_place(bar4, Vector2i(4, 7)), "bar4 fits at right edge")
	check(not b.can_place(bar4, Vector2i(5, 7)), "bar4 overflows right edge")
	check(not b.can_place(bar4, Vector2i(0, 8)), "below board is illegal")
	check(not b.can_place(bar4, Vector2i(-1, 0)), "negative anchor is illegal")


func test_overlap_is_illegal() -> void:
	var b := board_from(["...1....", "........", "........", "........", "........", "........", "........", "........"])
	check(not b.can_place(shape(&"bar4").cells, Vector2i(0, 0)), "overlap rejected")
	check(b.can_place(shape(&"bar3").cells, Vector2i(0, 0)), "adjacent fits")


func test_row_and_column_detection_and_crossing_union() -> void:
	var b := board_from([
		"...1....",
		"...1....",
		"...1....",
		"11111111",
		"...1....",
		"...1....",
		"...1....",
		"...1....",
	])
	eq(b.full_rows(), [3] as Array[int], "full rows")
	eq(b.full_cols(), [3] as Array[int], "full cols")
	var u := BMBoard.line_union(b.full_rows(), b.full_cols())
	eq(u.size(), 15, "crossing cell counted once")
	b.clear_cells(u)
	eq(b.occupied_count(), 0, "all cleared")


func test_no_gravity_after_clear() -> void:
	var b := board_from([
		"2.......",
		"11111111",
		"........",
		"........",
		"........",
		"........",
		"........",
		".......3",
	])
	b.clear_cells(BMBoard.line_union(b.full_rows(), b.full_cols()))
	eq(b.get_cell(Vector2i(0, 0)), 2, "cell above stays put")
	eq(b.get_cell(Vector2i(7, 7)), 3, "other cell stays put")
	eq(b.occupied_count(), 2, "only the line was removed")


func test_legal_anchor_enumeration() -> void:
	var b := BMBoard.new()
	eq(b.legal_anchors(shape(&"single").cells).size(), 64, "single fits everywhere")
	eq(b.legal_anchors(shape(&"bar5", 0).cells).size(), 4 * 8, "horizontal bar5 anchors")
	eq(b.legal_anchors(shape(&"square3").cells).size(), 36, "3x3 anchors")
