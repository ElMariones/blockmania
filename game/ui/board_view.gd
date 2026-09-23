class_name BMBoardView
extends Control
## The 8x8 board inside a brass cabinet frame. Draws cells, blocks (with material finishes),
## the placement ghost, lines that would clear, and short placement/clear effects. Reads BMRun
## state only; legality comes from BMBoard.can_place so the ghost always matches the rules.

const FRAME := 40.0

var run: BMRun
var ghost_shape: Dictionary = {}
var ghost_anchor := Vector2i(-99, -99)
var ghost_valid := false
var ghost_rows: Array[int] = []
var ghost_cols: Array[int] = []
var keyboard_focus := false
var reduced_motion := false
var block_skin := "classic"
var clean_glow := false

var _fx_clears: Array[Dictionary] = [] ## {cell, color, mat, finish, t, delay}
var _pop_step := 0 ## position in the pop cascade of the current resolution
var _fx_places: Array[Dictionary] = [] ## {cell, t, delay}
var _fx_sweeps: Array[Dictionary] = [] ## {row|col, index, t}
var _time := 0.0

const CLEAR_TIME := 0.34
const PLACE_TIME := 0.22
const SWEEP_TIME := 0.28


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func cell_size() -> float:
	return floorf((minf(size.x, size.y) - FRAME * 2.0) / BMBoard.SIZE)


func grid_origin() -> Vector2:
	var side := cell_size() * BMBoard.SIZE
	return ((size - Vector2(side, side)) / 2.0).round()


func cell_rect(p: Vector2i) -> Rect2:
	var c := cell_size()
	return Rect2(grid_origin() + Vector2(p) * c, Vector2(c, c))


func cell_global_center(p: Vector2i) -> Vector2:
	return get_global_transform() * cell_rect(p).get_center()


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
func play_resolution(r: Dictionary) -> void:
	var fx := BMFx.instance
	_pop_step = 0
	var i := 0
	for p: Vector2i in r.placed:
		_fx_places.append({"cell": p, "t": 0.0, "delay": i * 0.018})
		i += 1
	if fx:
		var min_y := 999.0
		var xs := 0.0
		for p: Vector2i in r.placed:
			var c := cell_global_center(p)
			min_y = minf(min_y, c.y)
			xs += c.x
		var bottom := 0.0
		for p: Vector2i in r.placed:
			bottom = maxf(bottom, cell_global_center(p).y + cell_size() / 2.0)
		fx.dust(Vector2(xs / maxf(1, r.placed.size()), bottom), cell_size() * 1.5, 6 + r.placed.size() * 2)
		# Finish flourish on landing (material faces in the campaign, the block style in Endless).
		var shape: Dictionary = r.get("shape", {})
		var finish := BMBlockPainter.finish_for(String(shape.get("material", "")), block_skin)
		if finish != "":
			var style := String(BMFinishes.def(finish).place)
			for p: Vector2i in r.placed:
				BMFinishes.emit(style, cell_global_center(p), int(shape.get("color", 0)), cell_size(), 0.8)
	for y in r.rows:
		_fx_sweeps.append({"axis": "row", "index": y, "t": 0.0})
	for x in r.cols:
		_fx_sweeps.append({"axis": "col", "index": x, "t": 0.0})
	var cleared: Array = r.cleared.duplicate()
	cleared.append_array(r.mirror_cleared)
	for e in cleared:
		var cell: Vector2i = e.cell
		# Cells clear in a wave outward from the placed piece.
		var d := 99.0
		for p: Vector2i in r.placed:
			d = minf(d, Vector2(p - cell).length())
		var mat: String = BMPieces.MATERIALS[int(e.get("mat", 0))]
		_fx_clears.append({"cell": cell, "color": e.color, "mat": mat, "finish": BMBlockPainter.finish_for(mat, block_skin),
			"t": 0.0, "delay": 0.03 * d, "burst": false})
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	var busy := not _fx_clears.is_empty() or not _fx_places.is_empty() or not _fx_sweeps.is_empty()
	for fx in _fx_places:
		fx.t += delta
	for fx in _fx_sweeps:
		fx.t += delta
	for fx in _fx_clears:
		fx.t += delta
		if not fx.burst and fx.t >= fx.delay + CLEAR_TIME * 0.5:
			fx.burst = true
			BMAudio.sfx("pop", BMAudio.scale_pitch(_pop_step), -2.0)
			_pop_step += 1
			var style := String(BMFinishes.def(fx.finish).clear) if fx.finish != "" else "pop"
			BMFinishes.emit(style, cell_global_center(fx.cell), int(fx.color), cell_size())
	_fx_places = _fx_places.filter(func(f: Dictionary) -> bool: return f.t < f.delay + PLACE_TIME)
	_fx_sweeps = _fx_sweeps.filter(func(f: Dictionary) -> bool: return f.t < SWEEP_TIME)
	_fx_clears = _fx_clears.filter(func(f: Dictionary) -> bool: return f.t < f.delay + CLEAR_TIME)
	if busy or ghost_valid or not ghost_shape.is_empty() or clean_glow or _animated_blocks():
		queue_redraw()


## Whether any block on the board shows an animated finish (so the board redraws each frame).
func _animated_blocks() -> bool:
	if run == null or BMBlockPainter.reduced_motion:
		return false
	if BMBlockPainter.is_animated(block_skin) and run.board.occupied_count() > 0:
		return true
	for y in BMBoard.SIZE:
		for x in BMBoard.SIZE:
			var p := Vector2i(x, y)
			if run.board.get_mat(p) != 0 and run.board.get_cell(p) != BMBoard.EMPTY:
				return true
	return false


func _draw() -> void:
	if run == null:
		return
	var c := cell_size()
	var origin := grid_origin()
	var side := c * BMBoard.SIZE
	var frame_rect := Rect2(origin - Vector2(FRAME, FRAME), Vector2(side, side) + Vector2(FRAME, FRAME) * 2.0 + Vector2(0, 8))
	draw_style_box(BMStyle.box("board_frame", Vector4.ZERO), frame_rect)
	if clean_glow:
		draw_rect(frame_rect.grow(-8), Color(BMStyle.MINT_L, 0.7 + 0.2 * sin(_time * 4.0)), false, 5.0)

	# Coordinates stamped into the brass rim (ink on sun), for keyboard play and callouts.
	var font := BMStyle.font_bold
	for i in BMBoard.SIZE:
		var col_x := origin.x + i * c + c / 2.0
		draw_string(font, Vector2(col_x - 6, origin.y - 15), "ABCDEFGH"[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(BMStyle.INK, 0.8))
		draw_string(font, Vector2(origin.x - 28, origin.y + i * c + c / 2.0 + 7), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(BMStyle.INK, 0.8))

	var cell_tex := BMStyle.tex("cell_empty")
	var pending := {}
	if ghost_valid:
		for p in BMBoard.line_union(ghost_rows, ghost_cols):
			pending[p] = true
	var pulse := 0.5 + 0.5 * sin(_time * 7.0)

	for y in BMBoard.SIZE:
		for x in BMBoard.SIZE:
			var r := cell_rect(Vector2i(x, y))
			draw_texture_rect(cell_tex, r, false)
			if clean_glow and (x + y * 3) % 7 == 0:
				draw_rect(Rect2(r.get_center() - Vector2(2, 2), Vector2(4, 4)), Color(BMStyle.SUN_L, 0.42))
	# Glow pass: halos spill into gaps and empty neighbours, under every block.
	for y in BMBoard.SIZE:
		for x in BMBoard.SIZE:
			var p := Vector2i(x, y)
			var v := run.board.get_cell(p)
			if v != BMBoard.EMPTY:
				BMBlockPainter.draw_glow(self, cell_rect(p), v, 1.0, BMPieces.MATERIALS[run.board.get_mat(p)], block_skin, p)
	if ghost_valid:
		for cell: Vector2i in ghost_shape.cells:
			var gp: Vector2i = cell + ghost_anchor
			BMBlockPainter.draw_glow(self, cell_rect(gp), int(ghost_shape.color), 0.5, String(ghost_shape.get("material", "")), block_skin, gp)
	for y in BMBoard.SIZE:
		for x in BMBoard.SIZE:
			var p := Vector2i(x, y)
			var r := cell_rect(p)
			var v := run.board.get_cell(p)
			if v == BMBoard.EMPTY:
				continue
			var rr := r
			var pf := _place_fx(p)
			if pf >= 0.0:
				# Drop in from above with a squash on landing.
				var k := pf
				var drop := (1.0 - minf(1.0, k * 1.6)) * -c * 0.35
				var squash := 1.0 + 0.12 * sin(clampf((k - 0.55) / 0.45, 0.0, 1.0) * PI)
				rr = Rect2(r.position + Vector2((r.size.x - r.size.x * squash) / 2.0, drop + r.size.y * (1.0 - 1.0 / squash)), Vector2(r.size.x * squash, r.size.y / squash))
			BMBlockPainter.draw_block(self, rr, v, 1.0, BMPieces.MATERIALS[run.board.get_mat(p)], Color.WHITE, block_skin, p)
			if pending.has(p):
				draw_rect(r.grow(-4), Color(1, 1, 1, 0.12 + 0.18 * pulse))

	# Ghost footprint.
	if not ghost_shape.is_empty():
		for cell: Vector2i in ghost_shape.cells:
			var p: Vector2i = cell + ghost_anchor
			if not BMBoard.in_bounds(p):
				continue
			var r := cell_rect(p)
			if ghost_valid:
				BMBlockPainter.draw_block(self, r, int(ghost_shape.color), 0.55, String(ghost_shape.get("material", "")), Color.WHITE, block_skin, p)
				draw_rect(r.grow(-3), Color(BMStyle.CREAM, 0.55 + 0.45 * pulse), false, 4.0)
			else:
				draw_rect(r.grow(-4), Color(BMStyle.PINK, 0.28))
				draw_rect(r.grow(-4), BMStyle.PINK, false, 4.0)
				var a := r.grow(-22)
				_pixel_x(a, BMStyle.PINK)

	# Lines that would clear: sun chevrons at both ends plus a bright rim.
	if ghost_valid:
		for y in ghost_rows:
			var rr := Rect2(origin + Vector2(0, y * c), Vector2(side, c))
			draw_rect(rr.grow(2), Color(BMStyle.SUN, 0.6 + 0.4 * pulse), false, 4.0)
			_chevron(Vector2(origin.x - 6, rr.get_center().y), Vector2.RIGHT, pulse)
			_chevron(Vector2(origin.x + side + 6, rr.get_center().y), Vector2.LEFT, pulse)
		for x in ghost_cols:
			var rr := Rect2(origin + Vector2(x * c, 0), Vector2(c, side))
			draw_rect(rr.grow(2), Color(BMStyle.SUN, 0.6 + 0.4 * pulse), false, 4.0)
			_chevron(Vector2(rr.get_center().x, origin.y - 6), Vector2.DOWN, pulse)
			_chevron(Vector2(rr.get_center().x, origin.y + side + 6), Vector2.UP, pulse)

	# Sweep light along cleared lines.
	for sw in _fx_sweeps:
		var k: float = sw.t / SWEEP_TIME
		var head := k * side * 1.3
		var band := c * 1.4
		var a := 1.0 - k
		if sw.axis == "row":
			var y0: float = origin.y + sw.index * c
			draw_rect(Rect2(Vector2(origin.x, y0), Vector2(minf(side, head), c)), Color(1, 1, 1, 0.35 * a))
			draw_rect(Rect2(Vector2(origin.x + clampf(head - band, 0, side), y0), Vector2(clampf(band, 0, side - clampf(head - band, 0, side)), c)), Color(BMStyle.SUN_L, 0.7 * a))
		else:
			var x0: float = origin.x + sw.index * c
			draw_rect(Rect2(Vector2(x0, origin.y), Vector2(c, minf(side, head))), Color(1, 1, 1, 0.35 * a))
			draw_rect(Rect2(Vector2(x0, origin.y + clampf(head - band, 0, side)), Vector2(c, clampf(band, 0, side - clampf(head - band, 0, side)))), Color(BMStyle.SUN_L, 0.7 * a))

	# Clearing cells: flash white, then pop smaller before bursting into particles.
	for fx in _fx_clears:
		var t: float = fx.t - fx.delay
		var r := cell_rect(fx.cell)
		if t < 0.0:
			BMBlockPainter.draw_block(self, r, fx.color, 1.0, fx.mat, Color.WHITE, block_skin, fx.cell)
			continue
		var k := t / CLEAR_TIME
		if k < 0.45:
			var grow := 1.0 + 0.12 * (k / 0.45)
			var rr := Rect2(r.get_center() - r.size * grow / 2.0, r.size * grow)
			BMBlockPainter.draw_block(self, rr, fx.color, 1.0, fx.mat, Color.WHITE, block_skin, fx.cell)
			draw_rect(rr.grow(-3), Color(1, 1, 1, 0.85 * (k / 0.45)))
		else:
			var s := 1.0 - (k - 0.45) / 0.55
			var rr2 := Rect2(r.get_center() - r.size * s * 0.5, r.size * s)
			draw_rect(rr2, Color(1, 1, 1, s))

	if keyboard_focus and not ghost_shape.is_empty():
		var r0 := cell_rect(ghost_anchor)
		draw_rect(r0.grow(4), BMStyle.SKY, false, 4.0)


func _place_fx(p: Vector2i) -> float:
	for fx in _fx_places:
		if fx.cell == p:
			if fx.t < fx.delay:
				return 0.0
			return clampf((fx.t - fx.delay) / PLACE_TIME, 0.0, 1.0)
	return -1.0


func _pixel_x(r: Rect2, c: Color) -> void:
	var n := 6
	var step := r.size.x / n
	for i in n:
		draw_rect(Rect2(r.position + Vector2(i * step, i * step), Vector2(step, step)), c)
		draw_rect(Rect2(r.position + Vector2((n - 1 - i) * step, i * step), Vector2(step, step)), c)


func _chevron(tip: Vector2, dir: Vector2, pulse: float) -> void:
	var back := -dir * 14.0
	var perp := Vector2(-dir.y, dir.x) * 10.0
	var off := dir * 4.0 * pulse
	var pts := PackedVector2Array([tip + off, tip + back + perp + off, tip + back - perp + off])
	draw_colored_polygon(pts, BMStyle.SUN)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), BMStyle.INK, 2.0)
