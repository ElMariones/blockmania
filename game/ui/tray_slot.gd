class_name BMTraySlot
extends Control
## One of the three tray offers: a recessed well with a key tag. The piece floats gently,
## lifts with a shadow on hover, and shows text states ("HOLDING", "NO ROOM") so nothing
## depends on color alone.

signal pressed(slot: int)

var slot := 0
var shape: Dictionary = {}
var held := false
var fits := true
var hovered := false
var focused_by_key := false
var reduced_motion := false
var block_skin := "classic"
var _t := 0.0
var _lift := 0.0

const MINI_CELL := 44.0


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: hovered = true)
	mouse_exited.connect(func() -> void: hovered = false)
	focus_entered.connect(func() -> void: focused_by_key = BMStyle.is_keyboard_focus_visible())
	focus_exited.connect(func() -> void: focused_by_key = false)


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
	elif event is InputEventKey and event.pressed and event.is_action("ui_accept"):
		if not shape.is_empty():
			pressed.emit(slot)
			accept_event()


func _process(delta: float) -> void:
	_t += delta
	var target := 1.0 if (hovered or (focused_by_key and BMStyle.is_keyboard_focus_visible())) and not held and not shape.is_empty() else 0.0
	_lift = move_toward(_lift, target, delta * 8.0)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(BMStyle.box("panel_inset", Vector4.ZERO), r)
	if (hovered or (focused_by_key and BMStyle.is_keyboard_focus_visible())) and not shape.is_empty() and not held:
		draw_rect(r.grow(-6), Color(BMStyle.SUN, 0.10))
	# Key tag.
	var tag := Rect2(Vector2(10, 10), Vector2(28, 28))
	draw_style_box(BMStyle.box("pill_plum", Vector4.ZERO), tag)
	draw_string(BMStyle.font_bold, tag.position + Vector2(8, 22), str(slot + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BMStyle.CREAM)
	if shape.is_empty():
		draw_string(BMStyle.font, Vector2(0, size.y / 2.0 + 8), "placed", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(BMStyle.TEXT_DIM, 0.5))
		return
	var dims := Vector2(BMShapes.shape_size(shape))
	var cell := floorf(minf(MINI_CELL, minf((size.x - 36) / dims.x, (size.y - 56) / dims.y)))
	var bob := 0.0 if reduced_motion else roundf(sin(_t * 2.2 + slot * 1.7) * 2.0)
	var lift := -8.0 * _lift
	var origin := ((size - dims * cell) / 2.0 + Vector2(0, bob + lift - 4)).round()
	var alpha := 0.25 if held else (1.0 if fits else 0.5)
	# Soft drop shadow grows with lift.
	if not held:
		for c: Vector2i in shape.cells:
			draw_rect(Rect2(origin + Vector2(c) * cell + Vector2(4, 6 + 6 * _lift), Vector2(cell, cell)), Color(BMStyle.INK, 0.45))
	BMBlockPainter.draw_shape(self, shape, origin, cell, alpha, Color.WHITE, block_skin)
	if held:
		_caption("HOLDING", BMStyle.SUN)
	elif not fits:
		_caption("NO ROOM", BMStyle.PINK)
	elif bool(shape.get("temporary", false)):
		_caption("TEMPORARY", BMStyle.SKY)


func _caption(text: String, color: Color) -> void:
	var w := BMStyle.font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 24
	var rr := Rect2(Vector2((size.x - w) / 2.0, size.y - 40), Vector2(w, 32))
	draw_style_box(BMStyle.box("pill_plum", Vector4.ZERO), rr)
	draw_string(BMStyle.font_bold, rr.position + Vector2(12, 23), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
