class_name BMBoard
extends RefCounted
## 8x8 occupancy grid. Pure data: no nodes, no rendering.
## Cell value EMPTY (-1) means free; any other value is the block color id
## (see BMShapes.COLOR_*). Coordinates: x = column (A..H), y = row (1..8), origin top-left.

const SIZE := 8
const EMPTY := -1

var cells := PackedInt32Array()


func _init() -> void:
	cells.resize(SIZE * SIZE)
	cells.fill(EMPTY)


func duplicate_board() -> BMBoard:
	var b := BMBoard.new()
	b.cells = cells.duplicate()
	return b


static func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < SIZE and p.y < SIZE


func get_cell(p: Vector2i) -> int:
	return cells[p.y * SIZE + p.x]


func set_cell(p: Vector2i, value: int) -> void:
	cells[p.y * SIZE + p.x] = value


func is_empty(p: Vector2i) -> bool:
	return in_bounds(p) and get_cell(p) == EMPTY


func occupied_count() -> int:
	var n := 0
	for v in cells:
		if v != EMPTY:
			n += 1
	return n


func empty_count() -> int:
	return SIZE * SIZE - occupied_count()


## True if every footprint cell offset by anchor lands on an empty in-bounds cell.
func can_place(footprint: Array[Vector2i], anchor: Vector2i) -> bool:
	for c in footprint:
		if not is_empty(c + anchor):
			return false
	return true


## Returns every anchor where the footprint fits, scanning rows then columns.
func legal_anchors(footprint: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in SIZE:
		for x in SIZE:
			var a := Vector2i(x, y)
			if can_place(footprint, a):
				out.append(a)
	return out


func fits_anywhere(footprint: Array[Vector2i]) -> bool:
	for y in SIZE:
		for x in SIZE:
			if can_place(footprint, Vector2i(x, y)):
				return true
	return false


## Writes the footprint; caller must have validated with can_place.
func place(footprint: Array[Vector2i], anchor: Vector2i, color: int) -> Array[Vector2i]:
	var placed: Array[Vector2i] = []
	for c in footprint:
		var p := c + anchor
		set_cell(p, color)
		placed.append(p)
	return placed


func full_rows() -> Array[int]:
	var out: Array[int] = []
	for y in SIZE:
		var full := true
		for x in SIZE:
			if get_cell(Vector2i(x, y)) == EMPTY:
				full = false
				break
		if full:
			out.append(y)
	return out


func full_cols() -> Array[int]:
	var out: Array[int] = []
	for x in SIZE:
		var full := true
		for y in SIZE:
			if get_cell(Vector2i(x, y)) == EMPTY:
				full = false
				break
		if full:
			out.append(x)
	return out


## Union of the cells in the given rows and columns, each cell listed once.
static func line_union(rows: Array[int], cols: Array[int]) -> Array[Vector2i]:
	var seen := {}
	var out: Array[Vector2i] = []
	for y in rows:
		for x in SIZE:
			var p := Vector2i(x, y)
			if not seen.has(p):
				seen[p] = true
				out.append(p)
	for x in cols:
		for y in SIZE:
			var p := Vector2i(x, y)
			if not seen.has(p):
				seen[p] = true
				out.append(p)
	return out


## Clears the cells and returns [{cell, color}] for presentation.
func clear_cells(targets: Array[Vector2i]) -> Array[Dictionary]:
	var removed: Array[Dictionary] = []
	for p in targets:
		var v := get_cell(p)
		if v != EMPTY:
			removed.append({"cell": p, "color": v})
			set_cell(p, EMPTY)
	return removed


func to_array() -> Array:
	return Array(cells)


static func from_array(data: Array) -> BMBoard:
	var b := BMBoard.new()
	for i in mini(data.size(), SIZE * SIZE):
		b.cells[i] = int(data[i])
	return b


## Human-readable dump for tests and debug logs. '.' = empty, digit = color id.
func debug_string() -> String:
	var lines := PackedStringArray()
	for y in SIZE:
		var s := ""
		for x in SIZE:
			var v := get_cell(Vector2i(x, y))
			s += "." if v == EMPTY else str(v)
		lines.append(s)
	return "\n".join(lines)
