class_name BMTestCase
extends RefCounted
## Minimal assertion base for headless rule tests. Every `test_*` method is run by
## tests/run_tests.gd on a fresh instance.

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) and not (_is_number(actual) and _is_number(expected)):
		failures.append("%s expected %s (%s), got %s (%s)" % [message, expected, type_string(typeof(expected)), actual, type_string(typeof(actual))])
	elif (typeof(actual) == TYPE_FLOAT or typeof(expected) == TYPE_FLOAT) and _is_number(actual) and _is_number(expected):
		if not is_equal_approx(float(actual), float(expected)):
			failures.append("%s expected %s, got %s" % [message, expected, actual])
	elif actual != expected:
		failures.append("%s expected %s, got %s" % [message, expected, actual])


func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


## Builds a board from 8 strings: '.' empty, digit = color id, '#' stone.
func board_from(rows: Array) -> BMBoard:
	var b := BMBoard.new()
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			var ch := line[x]
			if ch == "#":
				b.set_cell(Vector2i(x, y), BMShapes.COLOR_STONE)
			elif ch != ".":
				b.set_cell(Vector2i(x, y), int(ch))
	return b


## A run positioned in round 1 with a controlled board and tray, for scoring tests.
func run_with(board_rows: Array, tray_shapes: Array, jokers: Array = []) -> BMRun:
	var run := BMRun.new_run(12345)
	run.board = board_from(board_rows)
	run.tray = tray_shapes.duplicate()
	while run.tray.size() < 3:
		run.tray.append({})
	run.jokers.assign(jokers)
	return run


## A tray piece that is not part of the bag (uid -1), for scoring tests.
func shape(family: StringName, rot: int = 0, color: int = BMShapes.COLOR_RED) -> Dictionary:
	return BMPieces.make(-1, family, rot, color)
