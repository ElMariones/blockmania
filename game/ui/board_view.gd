class_name BMBoardView
extends Control
## Draws the 8x8 board, the placement ghost, the lines a placement would clear, and short
## placement/clear effects. Reads BMRun state; never mutates it.
## Ghost legality comes from the rules layer (BMBoard.can_place) so it always matches.

const FRAME := 14.0
const LABEL_GUTTER := 0.0

var run: BMRun
## Ghost state set by the game screen.
var ghost_shape: Dictionary = {}
var ghost_anchor := Vector2i(-99, -99)
var ghost_valid := false
var ghost_rows: Array[int] = []
var ghost_cols: Array[int] = []
var keyboard_focus := false

var _fx_clears: Array[Dictionary] = [] ## {cell, color, t}
var _fx_places: Array[Dictionary] = [] ## {cell, t}
var _time := 0.0

const CLEAR_TIME := 0.42
const PLACE_TIME := 0.2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process(true)


func cell_size() -> float:
	return (minf(size.x, size.y) - FRAME * 2.0) / BMBoard.SIZE


func grid_origin() -> Vector2:
	var side := cell_size() * BMBoard.SIZE
	return (size - Vector2(side, side)) / 2.0


func cell_rect(p: Vector2i) -> Rect2:
	var c := cell_size()
	return Rect2(grid_origin() + Vector2(p) * c, Vector2(c, c))


## Anchor for a shape whose top-left corner is at `local_top_left` (board-local pixels).
func anchor_from_top_left(local_top_left: Vector2) -> Vector2i:
	var rel := (local_top_left - grid_origin()) / cell_size()
	return Vector2i(roundi(rel.x), roundi(rel.y))


func set_ghost(shape: Dictionary, anchor: Vector2i) -> void:
	if shape == ghost_shape and anchor == ghost_anchor:
		return
	ghost_shape = shape
	ghost_anchor = anchor
	ghost_rows.clear()
	ghost_cols.clear()
	ghost_valid = not shape.is_empty() and run != null and run.board.can_place(shape.cells, anchor)
	if ghost_valid:
		var b := run.board.duplicate_board()
		b.place(shape.cells, anchor, int(shape.color))
		ghost_rows = b.full_rows()
		ghost_cols = b.full_cols()
	queue_redraw()


func clear_ghost() -> void:
	set_ghost({}, Vector2i(-99, -99))


## Starts presentation effects for a resolution record (already applied to state).
func play_resolution(r: Dictionary, reduced_motion: bool) -> void:
	if reduced_motion:
		queue_redraw()
		return
	for p: Vector2i in r.placed:
		_fx_places.append({"cell": p, "t": 0.0})
	var cleared: Array = r.cleared.duplicate()
	cleared.append_array(r.mirror_cleared)
	for e in cleared:
		_fx_clears.append({"cell": e.cell, "color": e.color, "t": 0.0})
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	var busy := false
	for fx in _fx_clears:
		fx.t += delta
	for fx in _fx_places:
		fx.t += delta
	_fx_clears = _fx_clears.filter(func(f: Dictionary) -> bool: return f.t < CLEAR_TIME)
	_fx_places = _fx_places.filter(func(f: Dictionary) -> bool: return f.t < PLACE_TIME)
	busy = not _fx_clears.is_empty() or not _fx_places.is_empty() or ghost_valid and (ghost_rows.size() + ghost_cols.size()) > 0
	if busy:
		queue_redraw()


func _draw() -> void:
	if run == null:
		return
	var c := cell_size()
	var origin := grid_origin()
	var side := c * BMBoard.SIZE
	var frame_rect := Rect2(origin - Vector2(FRAME, FRAME), Vector2(side, side) + Vector2(FRAME, FRAME) * 2.0)
	# Cabinet frame: dark rim, cyan inner edge.
	var sb := StyleBoxFlat.new()
	sb.bg_color = BMPalette.BG_DEEP
	sb.set_corner_radius_all(14)
	sb.border_color = BMPalette.PANEL_EDGE
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	draw_style_box(sb, frame_rect)
	draw_rect(Rect2(origin - Vector2(2, 2), Vector2(side, side) + Vector2(4, 4)), Color(BMPalette.CYAN, 0.35), false, 2.0)

	var pending := {}
	if ghost_valid:
		for p in BMBoard.line_union(ghost_rows, ghost_cols):
			pending[p] = true

	for y in BMBoard.SIZE:
		for x in BMBoard.SIZE:
			var p := Vector2i(x, y)
			var r := cell_rect(p)
			draw_rect(r.grow(-1.5), BMPalette.CELL_EMPTY)
			draw_rect(r.grow(-1.5), BMPalette.CELL_EDGE, false, 1.0)
			var v := run.board.get_cell(p)
			if v != BMBoard.EMPTY:
				var place_fx := _place_fx_scale(p)
				var rr := r
				if place_fx != 1.0:
					rr = Rect2(r.get_center() - r.size * place_fx / 2.0, r.size * place_fx)
				BMBlockPainter.draw_block(self, rr, v)

	# Ghost footprint.
	if not ghost_shape.is_empty():
		for cell: Vector2i in ghost_shape.cells:
			var p: Vector2i = cell + ghost_anchor
			if not BMBoard.in_bounds(p):
				continue
			var r := cell_rect(p)
			if ghost_valid:
				BMBlockPainter.draw_block(self, r, int(ghost_shape.color), 0.45)
				draw_rect(r.grow(-2), Color(1, 1, 1, 0.8), false, 2.0)
			else:
				# Invalid: coral outline plus diagonal hatch, so it never depends on color alone.
				draw_rect(r.grow(-2), BMPalette.INVALID, false, 3.0)
				var a := r.grow(-8)
				draw_line(a.position, a.end, Color(BMPalette.INVALID, 0.8), 2.0)
				draw_line(Vector2(a.end.x, a.position.y), Vector2(a.position.x, a.end.y), Color(BMPalette.INVALID, 0.8), 2.0)

	# Lines that would clear: pulsing brass outline around each pending line.
	if ghost_valid:
		var pulse := 0.55 + 0.45 * sin(_time * 8.0)
		for y in ghost_rows:
			var r := Rect2(origin + Vector2(0, y * c), Vector2(side, c))
			draw_rect(r, Color(BMPalette.BRASS, 0.18 * pulse))
			draw_rect(r.grow(-1), Color(BMPalette.BRASS, 0.9), false, 3.0)
		for x in ghost_cols:
			var r := Rect2(origin + Vector2(x * c, 0), Vector2(c, side))
			draw_rect(r, Color(BMPalette.BRASS, 0.18 * pulse))
			draw_rect(r.grow(-1), Color(BMPalette.BRASS, 0.9), false, 3.0)

	# Clear effect: cells flash white, shrink, and fade.
	for fx in _fx_clears:
		var k: float = fx.t / CLEAR_TIME
		var r := cell_rect(fx.cell)
		var s := 1.0 - 0.6 * k
		var rr := Rect2(r.get_center() - r.size * s / 2.0, r.size * s)
		BMBlockPainter.draw_block(self, rr, fx.color, 1.0 - k)
		draw_rect(rr, Color(1, 1, 1, (1.0 - k) * 0.7))

	if keyboard_focus and not ghost_shape.is_empty():
		var r0 := cell_rect(ghost_anchor)
		draw_rect(r0.grow(3), BMPalette.CYAN, false, 2.0)

	# Column/row coordinates (A-H, 1-8) for readability and keyboard play.
	var font := get_theme_default_font()
	for i in BMBoard.SIZE:
		var col := "ABCDEFGH"[i]
		draw_string(font, origin + Vector2(i * c + c / 2.0 - 5, -FRAME + 11), col, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(BMPalette.TEXT_DIM, 0.7))
		draw_string(font, origin + Vector2(-FRAME + 2, i * c + c / 2.0 + 4), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(BMPalette.TEXT_DIM, 0.7))


func _place_fx_scale(p: Vector2i) -> float:
	for fx in _fx_places:
		if fx.cell == p:
			var k: float = fx.t / PLACE_TIME
			return 1.0 + 0.18 * sin(k * PI)
	return 1.0
