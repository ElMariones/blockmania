class_name BMPieceTile
extends Control
## One bag piece as a small selectable tile: the shape with its material and stamp, a short
## text line (never color-only), and a full description tooltip. Used by the bag view, the
## Workshop target picker, and shop piece offers.

signal toggled_piece(uid: int)

var piece: Dictionary = {}
var selectable := false
var selected := false
var dimmed := false
var hovered := false

const TILE := Vector2(118, 112)


func _init(p: Dictionary = {}) -> void:
	piece = p
	custom_minimum_size = TILE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = BMPieces.describe(p) if not p.is_empty() else ""


func _ready() -> void:
	mouse_entered.connect(func() -> void: hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: hovered = false; queue_redraw())


func _gui_input(event: InputEvent) -> void:
	if selectable and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		toggled_piece.emit(int(piece.uid))
		accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BMPalette.BG_DEEP
	sb.set_corner_radius_all(8)
	sb.border_color = BMPalette.PANEL_EDGE
	sb.set_border_width_all(2)
	if selected:
		sb.border_color = BMPalette.BRASS
		sb.set_border_width_all(4)
	elif hovered and selectable:
		sb.border_color = BMPalette.CYAN
	draw_style_box(sb, r)
	if piece.is_empty():
		return
	var dims := Vector2(BMShapes.shape_size(piece))
	var cell := minf(22.0, minf((size.x - 16) / dims.x, (size.y - 34) / dims.y))
	var origin := Vector2((size.x - dims.x * cell) / 2.0, 8 + (size.y - 34 - dims.y * cell) / 2.0)
	BMBlockPainter.draw_shape(self, piece, origin, cell, 0.4 if dimmed else 1.0)
	var font := get_theme_default_font()
	draw_string(font, Vector2(0, size.y - 8), short_label(piece), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, BMPalette.TEXT if not dimmed else BMPalette.TEXT_DIM)
	if selected:
		draw_string(font, Vector2(6, 16), "SELECTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, BMPalette.BRASS)


static func short_label(p: Dictionary) -> String:
	var parts := PackedStringArray()
	var m := String(p.get("material", ""))
	if m != "":
		parts.append(BMPieces.MATERIAL_DEFS[m].name)
	var s := String(p.get("stamp", ""))
	if s != "":
		parts.append(BMPieces.STAMP_DEFS[s].name.replace(" Stamp", ""))
	if parts.is_empty():
		return BMShapes.family(p.family).name
	return " + ".join(parts)
