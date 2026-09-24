class_name BMVolumeBlocks
extends Control
## Volume control drawn as a row of toy blocks (0..STEPS lit). Mouse: click or drag. Keyboard:
## left/right while focused. The value is also shown as a percentage next to the blocks, so
## the level never depends on color alone.

signal changed(value: float)

const STEPS := 10
const BLOCK := 34.0
const GAP := 4.0
const LABEL_W := 70.0

var value := 0.8 ## 0..1
var _hover := -1
var _dragging := false


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(STEPS * (BLOCK + GAP) - GAP + 12 + LABEL_W, BLOCK + 8)


func set_value_silently(v: float) -> void:
	value = clampf(v, 0.0, 1.0)
	queue_redraw()


func _level() -> int:
	return int(roundf(value * STEPS))


func _set_level(level: int) -> void:
	level = clampi(level, 0, STEPS)
	if level == _level():
		return
	value = float(level) / STEPS
	queue_redraw()
	changed.emit(value)


func _index_at(x: float) -> int:
	return clampi(int(floorf((x - 2.0) / (BLOCK + GAP))), 0, STEPS - 1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
			_dragging = true
			var i := _index_at(event.position.x)
			# Clicking the lowest lit block when it is the only one turns the level off.
			_set_level(0 if (i == 0 and _level() == 1) else i + 1)
		else:
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion:
		var i := _index_at(event.position.x)
		if event.position.x > STEPS * (BLOCK + GAP):
			i = -1
		if i != _hover:
			_hover = i
			queue_redraw()
		if _dragging:
			var x: float = event.position.x
			_set_level(0 if x < 4.0 else _index_at(x) + 1)
		accept_event()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("bm_left"):
		_set_level(_level() - 1)
		accept_event()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("bm_right"):
		_set_level(_level() + 1)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = -1
		queue_redraw()
	elif what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()


func _draw() -> void:
	var lit := _level()
	var y := (size.y - BLOCK) / 2.0
	var empty := BMStyle.tex("cell_empty")
	# Green -> yellow -> orange -> red as the level rises (text shows the exact value too).
	var ramp := [3, 3, 3, 3, 2, 2, 2, 1, 1, 0]
	for i in STEPS:
		var r := Rect2(Vector2(2.0 + i * (BLOCK + GAP), y), Vector2(BLOCK, BLOCK))
		if i < lit:
			BMBlockPainter.draw_block(self, r, ramp[i], 1.0)
		else:
			draw_texture_rect(empty, r, false)
		if i == _hover:
			draw_rect(r.grow(2), BMStyle.SKY_L, false, 3.0)
	if has_focus() and BMStyle.is_keyboard_focus_visible():
		var w := STEPS * (BLOCK + GAP) - GAP + 4.0
		draw_rect(Rect2(Vector2(0, y - 3), Vector2(w, BLOCK + 6)), BMStyle.CREAM, false, 3.0)
	var txt := "%d%%" % int(roundf(value * 100)) if lit > 0 else BMLoc.t("OFF")
	var f := BMStyle.font_bold
	var tx := STEPS * (BLOCK + GAP) + 10.0
	draw_string_outline(f, Vector2(tx, size.y / 2.0 + 10), txt, HORIZONTAL_ALIGNMENT_LEFT, LABEL_W, 30, 8, BMStyle.INK)
	draw_string(f, Vector2(tx, size.y / 2.0 + 10), txt, HORIZONTAL_ALIGNMENT_LEFT, LABEL_W, 30, BMStyle.CREAM if lit > 0 else BMStyle.TEXT_DIM)
