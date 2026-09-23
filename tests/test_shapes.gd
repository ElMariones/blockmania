extends BMTestCase


func test_rotation_counts() -> void:
	var expected := {"single": 1, "bar2": 2, "bar3": 2, "l3": 4, "square2": 1, "bar4": 2, "l4": 4,
		"t4": 4, "zigzag4": 2, "plus5": 1, "bar5": 2, "square3": 1, "rect2x3": 2}
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
