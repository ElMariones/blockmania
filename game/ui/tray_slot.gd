class_name BMTraySlot
extends Control
## One of the three tray offers. Draws its shape centered; shows held / no-fit / empty states
## with text and outline cues as well as color.

signal pressed(slot: int)

var slot := 0
var shape: Dictionary = {}
var held := false
var fits := true
var hovered := false
var focused_by_key := false

const MINI_CELL := 38.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: hovered = false; queue_redraw())


func setup(new_shape: Dictionary, is_held: bool, shape_fits: bool) -> void:
	shape = new_shape
	held = is_held
	fits = shape_fits
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not shape.is_empty():
			pressed.emit(slot)
			accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BMPalette.PANEL
	sb.set_corner_radius_all(12)
	sb.border_color = BMPalette.PANEL_EDGE
	sb.set_border_width_all(2)
	if (hovered or focused_by_key) and not shape.is_empty() and not held:
		sb.border_color = BMPalette.CYAN
		sb.set_border_width_all(3)
	if held:
		sb.border_color = BMPalette.BRASS
		sb.set_border_width_all(3)
	draw_style_box(sb, r)
	var font := get_theme_default_font()
	draw_string(font, Vector2(12, 24), str(slot + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, BMPalette.TEXT_DIM)
	if shape.is_empty():
		draw_string(font, Vector2(0, size.y / 2.0 + 6), "placed", HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(BMPalette.TEXT_DIM, 0.5))
		return
	var dims := Vector2(BMShapes.shape_size(shape))
	var cell := minf(MINI_CELL, minf((size.x - 30) / dims.x, (size.y - 40) / dims.y))
	var lift := -6.0 if hovered and not held else 0.0
	var origin := (size - dims * cell) / 2.0 + Vector2(0, lift + 6)
	var alpha := 0.3 if held else (1.0 if fits else 0.45)
	BMBlockPainter.draw_shape(self, shape, origin, cell, alpha)
	if held:
		draw_string(font, Vector2(0, size.y - 12), "holding", HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, BMPalette.BRASS)
	elif not fits:
		draw_string(font, Vector2(0, size.y - 12), "no space", HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, BMPalette.INVALID)
