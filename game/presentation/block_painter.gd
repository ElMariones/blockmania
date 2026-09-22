class_name BMBlockPainter
extends RefCounted
## Procedural beveled "toy block" drawing used by the board, tray, and drag layer.
## Placeholder for the future block material set (ASSET_PLAN §4 `block_materials`).
## Accessibility patterns: each color can draw a distinct inner mark (settings toggle).

static var show_patterns := false


static func draw_block(ci: CanvasItem, rect: Rect2, color_id: int, alpha: float = 1.0) -> void:
	var base := BMPalette.block(color_id)
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


## Draws a whole shape with its top-left at `origin`.
static func draw_shape(ci: CanvasItem, shape: Dictionary, origin: Vector2, cell: float, alpha: float = 1.0) -> void:
	for c: Vector2i in shape.cells:
		draw_block(ci, Rect2(origin + Vector2(c) * cell, Vector2(cell, cell)), int(shape.color), alpha)
