class_name BMBlockPainter
extends RefCounted
## Draws toy blocks from the pixel-art kit (Classic block_*.png or Endless skin_*.png,
## all 22x22 art px) with material overlays and stamp badges. The optional
## accessibility patterns add a per-color mark without changing game rules.

static var show_patterns := false
const ENDLESS_SKINS := ["classic", "glass", "crystal", "neon", "gold", "marble", "cyberpunk",
	"wood", "candy", "lava", "ice", "chrome", "aurora", "starfall"]
const RARE_SKINS := ["aurora", "starfall"]


static func draw_block(ci: CanvasItem, rect: Rect2, color_id: int, alpha: float = 1.0, material: String = "", tint: Color = Color.WHITE, skin: String = "classic", time: float = 0.0) -> void:
	var sprite: Texture2D = BMStyle.block_tex(color_id)
	if skin != "classic" and color_id >= 0 and color_id < BMShapes.OFFER_COLOR_COUNT and ENDLESS_SKINS.has(skin):
		sprite = BMStyle.tex("skin_%s_%s" % [skin, BMStyle.BLOCK_NAMES[color_id]])
	var a := alpha * (0.62 if material == "glass" else 1.0)
	ci.draw_texture_rect(sprite, rect, false, Color(tint.r, tint.g, tint.b, a))
	if material != "":
		ci.draw_texture_rect(BMStyle.tex("mat_" + material), rect, false, Color(1, 1, 1, alpha))
	if skin in RARE_SKINS:
		_draw_rare_shimmer(ci, rect, skin, alpha, time)
	if show_patterns and color_id < BMShapes.OFFER_COLOR_COUNT:
		_draw_pattern(ci, rect, color_id, alpha)


static func _draw_rare_shimmer(ci: CanvasItem, rect: Rect2, skin: String, alpha: float, time: float) -> void:
	var u := rect.size.x / 22.0
	var p := rect.position
	if skin == "aurora":
		var shift := 0.4 + 0.3 * sin(time * 3.5 + p.x * 0.03)
		ci.draw_line(p + Vector2(4, 16) * u, p + Vector2(17, 5) * u, Color(BMStyle.MINT_L, shift * alpha), 2 * u)
	else:
		var star := Vector2(6 + fposmod(time * 6.0 + p.x * 0.05, 10.0), 10)
		var bright := Color(BMStyle.SUN_L, 0.7 * alpha)
		ci.draw_line(p + (star + Vector2(-2, 0)) * u, p + (star + Vector2(2, 0)) * u, bright, maxf(2.0, u))
		ci.draw_line(p + (star + Vector2(0, -2)) * u, p + (star + Vector2(0, 2)) * u, bright, maxf(2.0, u))


static func draw_stamp(ci: CanvasItem, cell_rect: Rect2, stamp: String, alpha: float = 1.0) -> void:
	if stamp == "":
		return
	var s := cell_rect.size.x * 0.5
	var r := Rect2(cell_rect.position + Vector2(cell_rect.size.x - s * 0.8, -s * 0.2), Vector2(s, s))
	ci.draw_texture_rect(BMStyle.tex("stamp_" + stamp), r, false, Color(1, 1, 1, alpha))


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


## Draws a whole piece with its top-left at `origin`, including material and stamp badge.
static func draw_shape(ci: CanvasItem, shape: Dictionary, origin: Vector2, cell: float, alpha: float = 1.0, tint: Color = Color.WHITE, skin: String = "classic", time: float = 0.0) -> void:
	var material := String(shape.get("material", ""))
	for c: Vector2i in shape.cells:
		draw_block(ci, Rect2(origin + Vector2(c) * cell, Vector2(cell, cell)), int(shape.color), alpha, material, tint, skin, time)
	var stamp := String(shape.get("stamp", ""))
	if stamp != "" and not shape.cells.is_empty():
		var first: Vector2i = shape.cells[0]
		draw_stamp(ci, Rect2(origin + Vector2(first) * cell, Vector2(cell, cell)), stamp, alpha)
