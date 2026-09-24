class_name BMBoard
extends RefCounted
## 8x8 occupancy grid. Pure data: no nodes, no rendering.
## Cell value EMPTY (-1) means free; any other value is the block color id
## (see BMShapes.COLOR_*). Coordinates: x = column (A..H), y = row (1..8), origin top-left.
## Parallel layers remember where each occupied cell came from, so effects can trigger when
## the cell is cleared later: `owners` = bag piece uid (-1 for none/temporary/boss cells),
## `mats` = material index into BMPieces.MATERIALS (0 = plain).

const SIZE := 8
const EMPTY := -1

var cells := PackedInt32Array()
var owners := PackedInt32Array()
var mats := PackedInt32Array()


func _init() -> void:
	cells.resize(SIZE * SIZE)
	cells.fill(EMPTY)
	owners.resize(SIZE * SIZE)
	owners.fill(-1)
	mats.resize(SIZE * SIZE)
	mats.fill(0)


func duplicate_board() -> BMBoard:
	var b := BMBoard.new()
	b.cells = cells.duplicate()
	b.owners = owners.duplicate()
	b.mats = mats.duplicate()
	return b


func get_owner(p: Vector2i) -> int:
	return owners[p.y * SIZE + p.x]


func get_mat(p: Vector2i) -> int:
	return mats[p.y * SIZE + p.x]


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
func place(footprint: Array[Vector2i], anchor: Vector2i, color: int, owner: int = -1, mat: int = 0) -> Array[Vector2i]:
	var placed: Array[Vector2i] = []
	for c in footprint:
		var p := c + anchor
		var i := p.y * SIZE + p.x
		cells[i] = color
		owners[i] = owner
		mats[i] = mat
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


## Clears the cells and returns [{cell, color, owner, mat}] for scoring and presentation.
func clear_cells(targets: Array[Vector2i]) -> Array[Dictionary]:
	var removed: Array[Dictionary] = []
	for p in targets:
		var i := p.y * SIZE + p.x
		if cells[i] != EMPTY:
			removed.append({"cell": p, "color": cells[i], "owner": owners[i], "mat": mats[i]})
			cells[i] = EMPTY
			owners[i] = -1
			mats[i] = 0
	return removed


## Gravity (The Avalanche): every block falls straight down its column until it rests on a
## block or the bottom edge. Returns [[from, to], ...] for presentation.
func settle() -> Array:
	var moves: Array = []
	for x in SIZE:
		var write := SIZE - 1
		for y in range(SIZE - 1, -1, -1):
			var i := y * SIZE + x
			if cells[i] == EMPTY:
				continue
			if y != write:
				var j := write * SIZE + x
				cells[j] = cells[i]
				owners[j] = owners[i]
				mats[j] = mats[i]
				cells[i] = EMPTY
				owners[i] = -1
				mats[i] = 0
				moves.append([Vector2i(x, y), Vector2i(x, write)])
			write -= 1
	return moves


func to_dict() -> Dictionary:
	return {"cells": Array(cells), "owners": Array(owners), "mats": Array(mats)}


static func from_dict(d: Dictionary) -> BMBoard:
	var b := BMBoard.new()
	for i in SIZE * SIZE:
		b.cells[i] = int(d.cells[i])
		b.owners[i] = int(d.owners[i])
		b.mats[i] = int(d.mats[i])
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
