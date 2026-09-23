class_name BMBlockPainter
extends RefCounted
## Draws toy blocks: the Classic plastic kit (block_*.png) or an animated finish sheet
## (finish_<id>.png, see BMFinishes). A campaign material draws its finish face in place of the
## plastic; an Endless block style applies the same faces to every block. Glowing finishes get a
## stepped pixel halo in a separate pass under the blocks. Stamps are animated badges.
## The optional accessibility patterns add a per-color mark without changing game rules.
##
## Animation reads `clock`, advanced by BMMain; with `reduced_motion` every face shows its calm
## rest frame, so no information depends on motion.

static var show_patterns := false
static var reduced_motion := false
static var clock := 0.0


## The finish that styles a cell: its material wins, then the Endless style, else none.
static func finish_for(material: String, skin: String) -> String:
	if BMFinishes.has_sheet(material):
		return material
	return skin if BMFinishes.has_sheet(skin) else ""


static func _time() -> float:
	return 0.0 if reduced_motion else clock + 0.001


## True when blocks in this finish change over time (callers redraw every frame).
static func is_animated(finish: String) -> bool:
	return not reduced_motion and BMFinishes.has_sheet(finish) and finish != "wood"


static func draw_block(ci: CanvasItem, rect: Rect2, color_id: int, alpha: float = 1.0, material: String = "", tint: Color = Color.WHITE, skin: String = "classic", cell := Vector2i.ZERO) -> void:
	var finish := finish_for(material, skin)
	var modulate := Color(tint.r, tint.g, tint.b, tint.a * alpha)
	if finish == "" or color_id < 0 or color_id >= BMShapes.OFFER_COLOR_COUNT:
		ci.draw_texture_rect(BMStyle.block_tex(color_id), rect, false, modulate)
	else:
		ci.draw_texture_rect_region(BMStyle.tex("finish_" + finish), rect, BMFinishes.region(finish, color_id, cell, _time()), modulate)
	if show_patterns and color_id < BMShapes.OFFER_COLOR_COUNT:
		_draw_pattern(ci, rect, color_id, alpha)


## Halo for glowing finishes. Draw it for every cell before the blocks themselves, so light
## spills into the gaps and onto empty neighbours without covering other blocks.
static func draw_glow(ci: CanvasItem, rect: Rect2, color_id: int, alpha: float = 1.0, material: String = "", skin: String = "classic", cell := Vector2i.ZERO) -> void:
	var finish := finish_for(material, skin)
	if finish == "" or color_id < 0 or color_id >= BMShapes.OFFER_COLOR_COUNT:
		return
	var strength := float(BMFinishes.def(finish).glow)
	if strength <= 0.0:
		return
	if not reduced_motion:
		strength *= 0.82 + 0.18 * sin(clock * 2.6 + (cell.x + cell.y) * 0.8)
	var reach := rect.size.x * 7.0 / 22.0
	var c := BMFinishes.glow_color(finish, color_id)
	ci.draw_texture_rect(BMStyle.tex("block_glow"), rect.grow(reach), false, Color(c, strength * alpha))


## A stamp badge overhanging the top-right corner of a cell.
static func draw_stamp(ci: CanvasItem, cell_rect: Rect2, stamp: String, alpha: float = 1.0, phase: int = 0) -> void:
	if stamp == "":
		return
	var s := roundf(cell_rect.size.x * 12.0 / 22.0)
	var r := Rect2(cell_rect.position + Vector2(cell_rect.size.x - s * 0.8, -s * 0.2), Vector2(s, s))
	draw_stamp_icon(ci, r, stamp, alpha, phase)


## A stamp badge filling `rect` (cards, tooltips).
static func draw_stamp_icon(ci: CanvasItem, rect: Rect2, stamp: String, alpha: float = 1.0, phase: int = 0) -> void:
	if stamp == "":
		return
	ci.draw_texture_rect_region(BMStyle.tex("stamp_" + stamp), rect, BMFinishes.stamp_region(_time(), phase), Color(1, 1, 1, alpha))


static func _draw_pattern(ci: CanvasItem, rect: Rect2, color_id: int, alpha: float) -> void:
	var c := Color(BMStyle.INK, 0.55 * alpha)
	var center := rect.get_center()
	var s := rect.size.x * 0.16
	match color_id:
		0: ci.draw_circle(center, s, c)
		1: ci.draw_rect(Rect2(center - Vector2(s, s), Vector2(s, s) * 2.0), c)
		2: ci.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -s * 1.2), center + Vector2(s * 1.2, s), center + Vector2(-s * 1.2, s)]), c)
		3: ci.draw_rect(Rect2(center - Vector2(s * 1.4, s * 0.4), Vector2(s * 2.8, s * 0.8)), c)
		4: ci.draw_arc(center, s, 0, TAU, 16, c, maxf(2.0, s * 0.45))
		5: ci.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -s * 1.3), center + Vector2(s * 1.3, 0), center + Vector2(0, s * 1.3), center + Vector2(-s * 1.3, 0)]), c)


## Draws a whole piece with its top-left at `origin`: glow pass, blocks, then the stamp badge.
static func draw_shape(ci: CanvasItem, shape: Dictionary, origin: Vector2, cell: float, alpha: float = 1.0, tint: Color = Color.WHITE, skin: String = "classic") -> void:
	var material := String(shape.get("material", ""))
	var color := int(shape.color)
	for c: Vector2i in shape.cells:
		draw_glow(ci, Rect2(origin + Vector2(c) * cell, Vector2(cell, cell)), color, alpha, material, skin, c)
	for c: Vector2i in shape.cells:
		draw_block(ci, Rect2(origin + Vector2(c) * cell, Vector2(cell, cell)), color, alpha, material, tint, skin, c)
	var stamp := String(shape.get("stamp", ""))
	if stamp != "" and not shape.cells.is_empty():
		var first: Vector2i = shape.cells[0]
		draw_stamp(ci, Rect2(origin + Vector2(first) * cell, Vector2(cell, cell)), stamp, alpha, int(shape.get("uid", 0)))
