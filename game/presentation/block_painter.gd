class_name BMBlockPainter
extends RefCounted
## Procedural beveled "toy block" drawing used by the board, tray, and drag layer.
## Placeholder for the future block material set (ASSET_PLAN §4 `block_materials`).
## Accessibility patterns: each color can draw a distinct inner mark (settings toggle).
## Materials (GDD §16.3) draw a finish with a shape cue as well as color: Chrome diagonal
## streaks, Neon double outline, Gold coin, Glass see-through face with a glare streak, Prism
## banded foot. Stamps draw a lettered badge on the piece's first cell.

static var show_patterns := false


static func draw_block(ci: CanvasItem, rect: Rect2, color_id: int, alpha: float = 1.0, material: String = "") -> void:
	var base := BMPalette.block(color_id)
	if material == "glass":
		alpha *= 0.62
	base.a = alpha
	var bevel := rect.size.x * 0.13
	var r := rect.grow(-rect.size.x * 0.03)
	var tl := r.position
	var tr := Vector2(r.end.x, r.position.y)
	var br := r.end
	var bl := Vector2(r.position.x, r.end.y)
	var itl := tl + Vector2(bevel, bevel)
	var itr := tr + Vector2(-bevel, bevel)
	var ibr := br - Vector2(bevel, bevel)
	var ibl := bl + Vector2(bevel, -bevel)
	ci.draw_rect(r, base.darkened(0.15))
	ci.draw_colored_polygon(PackedVector2Array([tl, tr, itr, itl]), _a(base.lightened(0.35), alpha))
	ci.draw_colored_polygon(PackedVector2Array([tl, itl, ibl, bl]), _a(base.lightened(0.18), alpha))
	ci.draw_colored_polygon(PackedVector2Array([tr, br, ibr, itr]), _a(base.darkened(0.25), alpha))
	ci.draw_colored_polygon(PackedVector2Array([bl, ibl, ibr, br]), _a(base.darkened(0.4), alpha))
	var face := Rect2(itl, ibr - itl)
	ci.draw_rect(face, base)
	ci.draw_rect(Rect2(face.position, Vector2(face.size.x, face.size.y * 0.45)), _a(base.lightened(0.08), alpha))
	var glint := Rect2(face.position + face.size * Vector2(0.1, 0.12), face.size * Vector2(0.28, 0.12))
	ci.draw_rect(glint, Color(1, 1, 1, 0.45 * alpha))
	if color_id == BMShapes.COLOR_STONE:
		var m := face.grow(-face.size.x * 0.2)
		ci.draw_line(m.position, m.end, Color(0, 0, 0, 0.45 * alpha), 3.0)
		ci.draw_line(Vector2(m.end.x, m.position.y), Vector2(m.position.x, m.end.y), Color(0, 0, 0, 0.45 * alpha), 3.0)
	elif show_patterns:
		_draw_pattern(ci, face, color_id, alpha)
	if material != "":
		_draw_material(ci, r, face, material, alpha)


static func _draw_material(ci: CanvasItem, r: Rect2, face: Rect2, material: String, alpha: float) -> void:
	var w := face.size.x
	match material:
		"chrome":
			for k in 3:
				var off := w * (0.15 + 0.3 * k)
				ci.draw_line(face.position + Vector2(off, face.size.y), face.position + Vector2(minf(w, off + w * 0.35), maxf(0.0, face.size.y - w * 0.35 - off * 0.2)), Color(1, 1, 1, 0.55 * alpha), maxf(1.5, w * 0.06))
			ci.draw_rect(r, Color(0.85, 0.9, 0.95, 0.9 * alpha), false, maxf(1.5, w * 0.05))
		"neon":
			ci.draw_rect(r.grow(-1), Color("#ff5bd8", 0.95 * alpha), false, maxf(2.0, w * 0.07))
			ci.draw_rect(face.grow(-w * 0.12), Color("#7ff9ff", 0.95 * alpha), false, maxf(1.5, w * 0.05))
		"gold":
			ci.draw_rect(r, Color(BMPalette.BRASS, 0.95 * alpha), false, maxf(2.0, w * 0.08))
			ci.draw_circle(face.get_center(), w * 0.2, Color(BMPalette.BRASS, 0.95 * alpha))
			ci.draw_circle(face.get_center(), w * 0.11, Color(1, 0.95, 0.7, 0.9 * alpha))
		"glass":
			ci.draw_line(face.position + Vector2(w * 0.15, face.size.y * 0.85), face.position + Vector2(w * 0.85, face.size.y * 0.15), Color(1, 1, 1, 0.8), maxf(1.5, w * 0.07))
			ci.draw_line(face.position + Vector2(w * 0.45, face.size.y * 0.9), face.position + Vector2(w * 0.9, face.size.y * 0.45), Color(1, 1, 1, 0.5), maxf(1.0, w * 0.04))
			ci.draw_rect(r, Color(0.85, 0.97, 1.0, 0.85), false, maxf(1.5, w * 0.05))
		"prism":
			var band := face.size.y * 0.1
			for k in BMShapes.OFFER_COLOR_COUNT:
				var c := BMPalette.block(k).lightened(0.2)
				c.a = 0.9 * alpha
				ci.draw_rect(Rect2(face.position.x + w * k / 6.0, face.end.y - band * 2.2, w / 6.0 + 0.5, band * 2.2), c)
			ci.draw_rect(r, Color(1, 1, 1, 0.7 * alpha), false, maxf(1.5, w * 0.04))


static func draw_stamp(ci: CanvasItem, cell_rect: Rect2, stamp: String, alpha: float = 1.0) -> void:
	if stamp == "":
		return
	var rad := cell_rect.size.x * 0.24
	var center := cell_rect.position + Vector2(cell_rect.size.x - rad * 0.9, rad * 0.9)
	var col: Color = {"encore": BMPalette.CORAL, "refund": BMPalette.CYAN, "tip": BMPalette.BRASS, "memory": Color("#b46cf2")}.get(stamp, Color.WHITE)
	col.a = alpha
	ci.draw_circle(center, rad, Color(0, 0, 0, 0.7 * alpha))
	ci.draw_circle(center, rad * 0.82, col)
	var font := ThemeDB.fallback_font
	var fs := int(maxf(9.0, rad * 1.3))
	ci.draw_string(font, center + Vector2(-rad, fs * 0.36), BMPieces.STAMP_DEFS[stamp].short, HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, fs, Color(0, 0, 0, alpha))


static func _a(c: Color, alpha: float) -> Color:
	c.a = alpha
	return c


static func _draw_pattern(ci: CanvasItem, face: Rect2, color_id: int, alpha: float) -> void:
	var c := Color(0, 0, 0, 0.35 * alpha)
	var center := face.get_center()
	var s := face.size.x * 0.22
	match color_id:
		0: ci.draw_circle(center, s * 0.7, c)
		1: ci.draw_rect(Rect2(center - Vector2(s, s) * 0.6, Vector2(s, s) * 1.2), c)
		2: ci.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -s), center + Vector2(s, s * 0.8), center + Vector2(-s, s * 0.8)]), c)
		3: ci.draw_line(center - Vector2(s, 0), center + Vector2(s, 0), c, 4.0)
		4: ci.draw_arc(center, s * 0.8, 0, TAU, 20, c, 3.0)
		5: ci.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -s), center + Vector2(s, 0), center + Vector2(0, s), center + Vector2(-s, 0)]), c)


## Draws a whole piece with its top-left at `origin`, including material and stamp badge.
static func draw_shape(ci: CanvasItem, shape: Dictionary, origin: Vector2, cell: float, alpha: float = 1.0) -> void:
	var material := String(shape.get("material", ""))
	for c: Vector2i in shape.cells:
		draw_block(ci, Rect2(origin + Vector2(c) * cell, Vector2(cell, cell)), int(shape.color), alpha, material)
	var stamp := String(shape.get("stamp", ""))
	if stamp != "" and not shape.cells.is_empty():
		var first: Vector2i = shape.cells[0]
		draw_stamp(ci, Rect2(origin + Vector2(first) * cell, Vector2(cell, cell)), stamp, alpha)
