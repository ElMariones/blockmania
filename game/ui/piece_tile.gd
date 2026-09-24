class_name BMPieceTile
extends Control
## One bag piece as a small selectable tile: the piece with its material and stamp, a short
## text line (never color-only), and a full-description tooltip. Selected tiles get a sun rim,
## a lift, and a BMLoc.t("PICKED") tag.

signal toggled_piece(uid: int)

var piece: Dictionary = {}
var selectable := false
var selected := false
var dimmed := false
var hovered := false

const TILE := Vector2(132, 124)


func _init(p: Dictionary = {}) -> void:
	piece = p
	custom_minimum_size = TILE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = BMPieces.describe(p) if not p.is_empty() else ""


func _ready() -> void:
	mouse_entered.connect(func() -> void: hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: hovered = false; queue_redraw())
	if selectable:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _make_custom_tooltip(for_text: String) -> Object:
	var l := BMStyle.label(for_text, 20, BMStyle.CREAM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(400, 0)
	return l


func _gui_input(event: InputEvent) -> void:
	if selectable and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		toggled_piece.emit(int(piece.uid))
		accept_event()


func _draw() -> void:
	var lift := -6.0 if selected else 0.0
	var r := Rect2(Vector2(0, lift + 6), size - Vector2(0, 6))
	draw_style_box(BMStyle.box("panel_inset", Vector4.ZERO), r)
	if selected:
		draw_rect(r.grow(-2), BMStyle.SUN, false, 6.0)
	elif hovered and selectable:
		draw_rect(r.grow(-2), BMStyle.SKY, false, 4.0)
	if piece.is_empty():
		return
	var dims := Vector2(BMShapes.shape_size(piece))
	var cell := floorf(minf(24.0, minf((size.x - 24) / dims.x, (size.y - 52) / dims.y)))
	var origin := (Vector2((size.x - dims.x * cell) / 2.0, r.position.y + 10 + (size.y - 56 - dims.y * cell) / 2.0)).round()
	BMBlockPainter.draw_shape(self, piece, origin, cell, 0.4 if dimmed else 1.0)
	var f := BMStyle.font
	var text := short_label(piece)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var col := BMStyle.CREAM if BMPieces.is_upgraded(piece) else BMStyle.TEXT_DIM
	draw_string(f, Vector2((size.x - minf(w, size.x - 8)) / 2.0, r.end.y - 12), text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 8, 20, col)
	if selected:
		# Tag sized to its text, centered on the top edge and inside the tile (scroll areas clip).
		var tw := BMStyle.font_bold.get_string_size(BMLoc.t("PICKED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var tag := Rect2(Vector2((size.x - tw - 20) / 2.0, r.position.y - 2), Vector2(tw + 20, 30))
		draw_style_box(BMStyle.box("pill_sun", Vector4.ZERO), tag)
		draw_string(BMStyle.font_bold, tag.position + Vector2(10, 22), BMLoc.t("PICKED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BMStyle.INK)


static func short_label(p: Dictionary) -> String:
	var parts := PackedStringArray()
	var m := String(p.get("material", ""))
	if m != "":
		parts.append(BMLoc.t(BMPieces.MATERIAL_DEFS[m].name))
	var s := String(p.get("stamp", ""))
	if s != "":
		parts.append(BMLoc.t(BMPieces.STAMP_DEFS[s].short_name))
	if parts.is_empty():
		return BMShapes.family_name(p.family)
	return "+".join(parts)
