extends BMTestCase


func test_rotation_counts() -> void:
	var expected := {"single": 1, "bar2": 2, "bar3": 2, "l3": 4, "square2": 1, "bar4": 2, "l4": 4,
		"t4": 4, "zigzag4": 2, "plus5": 1, "bar5": 2, "square3": 1}
	for id in expected:
		eq(BMShapes.rotations(StringName(id)).size(), expected[id], "rotations of %s" % id)


func test_cells_normalized() -> void:
	for f in BMShapes.FAMILIES:
		for rot in BMShapes.rotations(f.id):
			var min_x := 99
			var min_y := 99
			for c: Vector2i in rot:
				min_x = mini(min_x, c.x)
				min_y = mini(min_y, c.y)
			check(min_x == 0 and min_y == 0, "%s normalized" % f.id)
			eq(rot.size(), f.cells.size(), "%s cell count preserved" % f.id)


func test_weights_sum_to_100() -> void:
	var total := 0
	for f in BMShapes.FAMILIES:
		total += int(f.weight)
	eq(total, 100, "weights")


func test_large_shapes_gated_before_round_3() -> void:
	var rng := BMRngStream.new(7, "shapes")
	var board := BMBoard.new()
	var prev := ""
	for i in 300:
		var dealt := BMTrayGenerator.deal(rng, board, 1, 3, prev)
		prev = BMTrayGenerator.signature_of(dealt.shapes)
		for s in dealt.shapes:
			check(s.family != &"bar5" and s.family != &"square3", "no %s in round 1" % s.family)


func test_color_limit_and_legal_guarantee() -> void:
	var rng := BMRngStream.new(99, "shapes")
	# Only a single free cell: every dealt tray must still contain a fitting shape.
	var board := BMBoard.new()
	board.cells.fill(1)
	board.set_cell(Vector2i(7, 0), BMBoard.EMPTY)
	eq(board.empty_count(), 1, "one empty cell")
	var prev := ""
	for i in 50:
		var dealt := BMTrayGenerator.deal(rng, board, 5, 3, prev)
		prev = BMTrayGenerator.signature_of(dealt.shapes)
		check(BMTrayGenerator.any_fits(board, dealt.shapes), "tray %d has a legal shape" % i)
		check(not dealt.forced, "no forced fallback")
		var counts := {}
		for s in dealt.shapes:
			counts[s.color] = int(counts.get(s.color, 0)) + 1
		for c in counts:
			check(counts[c] <= 2, "at most two of a color")


func test_no_identical_consecutive_trays() -> void:
	var rng := BMRngStream.new(3, "shapes")
	var board := BMBoard.new()
	var prev := ""
	for i in 500:
		var dealt := BMTrayGenerator.deal(rng, board, 4, 3, prev)
		var sig := BMTrayGenerator.signature_of(dealt.shapes)
		check(sig != prev, "tray repeated at %d" % i)
		prev = sig


func test_seeded_streams_are_reproducible() -> void:
	var a := BMRngStream.new(42, "shapes")
	var b := BMRngStream.new(42, "shapes")
	var c := BMRngStream.new(42, "shop")
	var same := true
	var differs := false
	for i in 20:
		var va := a.randi_range(0, 1000)
		same = same and va == b.randi_range(0, 1000)
		differs = differs or va != c.randi_range(0, 1000)
	check(same, "same seed and name reproduce")
	check(differs, "different stream names diverge")
