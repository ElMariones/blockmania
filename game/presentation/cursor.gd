class_name BMCursor
extends CanvasLayer
## The custom mouse cursor (setting "cursor": "custom" | "system"). Presentation only.
## The pointer itself is a hardware cursor (Input.set_custom_mouse_cursor), so it never lags
## behind the mouse: a cream arrow, POPS's white glove over anything clickable (its fingers
## wiggle while hovering), a pressed frame while a button is held, and a fist for dragging.
## Art: tools/art/gen_cursor.py, scaled by a whole number for the window size.
## On top, drawn under the CRT so it curves with the picture: a stepped ring and a few pixel
## sparks on every click, a tiny twinkle when the glove lands on a new button, and a short
## pixel trail on fast flicks. Reduced motion keeps the cursor and drops every effect.

const HOTSPOTS := {"arrow": Vector2(0, 0), "arrow_press": Vector2(0, 0), "hand": Vector2(5, 0),
	"hand_b": Vector2(5, 1), "hand_press": Vector2(5, 2), "grab": Vector2(8, 5)} ## art px, gen_cursor.py
const WIGGLE := 0.28 ## seconds per glove frame while hovering
const TRAIL_SPEED := 1400.0 ## px/s before the trail shows
const MAX_FX := 80

var main: Node
var enabled := true
var _scale := 0
var _tex := {} ## frame name -> scaled ImageTexture
var _pressed := false
var _t := 0.0
var _frame_set := {} ## shape -> frame name currently given to the OS
var _pos := Vector2.ZERO ## pointer position in game space (after the CRT remap)
var _last_pos := Vector2.ZERO
var _hovered: Control
var _fx: Array = [] ## {kind, pos, age, life, vel, color, size}
var _canvas: Control


func _init() -> void:
	layer = 99 # just under the CRT layer (100), over every screen and modal


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_fx)
	add_child(_canvas)
	get_viewport().size_changed.connect(_rescale)
	_rescale()


## Hands the OS its own cursors back before the textures go away (no leaks at quit).
func _exit_tree() -> void:
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_MOVE, Input.CURSOR_DRAG, Input.CURSOR_CAN_DROP]:
		Input.set_custom_mouse_cursor(null, shape)
	_tex.clear()
	_frame_set.clear()


func set_enabled(on: bool) -> void:
	enabled = on
	_frame_set.clear()
	_fx.clear()
	if not on:
		for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_MOVE, Input.CURSOR_DRAG, Input.CURSOR_CAN_DROP]:
			Input.set_custom_mouse_cursor(null, shape)
	else:
		_apply(true)
	_canvas.queue_redraw()


func _reduced() -> bool:
	return main != null and bool(main.settings.get("reduced_motion", false))


## One art pixel = `_scale` screen pixels: 2 at 1080p, 3 at 1440p/4K-ish, 1 at tiny windows.
func _rescale() -> void:
	var h := float(DisplayServer.window_get_size().y)
	var k := clampi(roundi(h / 540.0), 1, 4)
	if k == _scale and not _tex.is_empty():
		return
	_scale = k
	_tex.clear()
	for name in HOTSPOTS:
		var src := load("res://assets/ui/cursor_%s.png" % name) as Texture2D
		if src == null:
			continue
		var img := src.get_image()
		if img.is_compressed():
			img.decompress()
		img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
		_tex[name] = ImageTexture.create_from_image(img)
	_frame_set.clear()
	if enabled:
		_apply(true)


func _set_shape(shape: Input.CursorShape, frame: String, force: bool) -> void:
	if not force and _frame_set.get(shape, "") == frame:
		return
	if not _tex.has(frame):
		return
	_frame_set[shape] = frame
	Input.set_custom_mouse_cursor(_tex[frame], shape, HOTSPOTS[frame] * _scale)


## Gives the OS the frame for each shape: pressed frames while the button is held, the glove's
## wiggle frame while hovering.
func _apply(force := false) -> void:
	var wig := "hand_b" if (not _reduced() and int(_t / WIGGLE) % 2 == 1) else "hand"
	_set_shape(Input.CURSOR_ARROW, "arrow_press" if _pressed else "arrow", force)
	_set_shape(Input.CURSOR_POINTING_HAND, "hand_press" if _pressed else wig, force)
	_set_shape(Input.CURSOR_MOVE, "grab", force)
	_set_shape(Input.CURSOR_DRAG, "grab", force)
	_set_shape(Input.CURSOR_CAN_DROP, "grab", force)


func _input(event: InputEvent) -> void:
	# This node sits before the CRT layer in the tree, so it sees events after the CRT remap:
	# effects drawn at this position line up with the pointer once the picture is curved.
	if event is InputEventMouse:
		_pos = event.position
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		_pressed = event.pressed
		if enabled:
			_apply()
			if event.pressed and not _reduced():
				_click_fx(event.position, event.button_index == MOUSE_BUTTON_RIGHT)


func _process(delta: float) -> void:
	_t += delta
	if not enabled:
		return
	_apply()
	var rm := _reduced()
	# A twinkle when the pointer lands on a new clickable control.
	var hov := get_viewport().gui_get_hovered_control()
	if hov != _hovered:
		_hovered = hov
		if hov != null and not rm and hov.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND \
				and not (hov is BaseButton and (hov as BaseButton).disabled):
			_add({"kind": "twinkle", "pos": _pos + Vector2(4, 2) * _scale, "life": 0.3, "color": BMStyle.SUN_L})
	# A short pixel trail on fast flicks.
	if not rm and delta > 0.0:
		var speed := _pos.distance_to(_last_pos) / delta
		if speed > TRAIL_SPEED:
			var steps := mini(4, int(_pos.distance_to(_last_pos) / 18.0))
			for i in steps:
				var p := _last_pos.lerp(_pos, float(i) / maxf(1.0, steps))
				_add({"kind": "dot", "pos": p, "life": 0.22, "color": BMFinishes.HUES[randi() % 6], "size": 2.0 * _scale})
	_last_pos = _pos
	var had := not _fx.is_empty()
	for i in range(_fx.size() - 1, -1, -1):
		var f: Dictionary = _fx[i]
		f.age += delta
		if f.has("vel"):
			f.vel.y += 900.0 * delta
			f.pos += f.vel * delta
		if f.age >= f.life:
			_fx.remove_at(i)
	if had:
		_canvas.queue_redraw() # one more redraw after the last effect ends clears it


func _click_fx(at: Vector2, right: bool) -> void:
	var col: Color = BMStyle.PINK_L if right else BMStyle.SUN_L
	_add({"kind": "ring", "pos": at, "life": 0.28, "color": col})
	for i in 5:
		var a := -PI / 2.0 + randf_range(-1.2, 1.2)
		_add({"kind": "spark", "pos": at, "life": randf_range(0.25, 0.4), "vel": Vector2(cos(a), sin(a)) * randf_range(160.0, 320.0),
			"color": BMFinishes.HUES[randi() % 6], "size": float(_scale) * 2.0})


func _add(f: Dictionary) -> void:
	if _fx.size() >= MAX_FX:
		_fx.pop_front()
	f.age = 0.0
	_fx.append(f)


func _draw_fx() -> void:
	var px := float(maxi(1, _scale))
	for f in _fx:
		var k: float = f.age / f.life
		var a := 1.0 - k
		match String(f.kind):
			"ring":
				# A stepped square ring (pixel look), growing and fading.
				var r := roundf((6.0 + 22.0 * k) / px) * px
				var c := Color(f.color, a)
				var p: Vector2 = f.pos
				_canvas.draw_rect(Rect2(p + Vector2(-r, -r), Vector2(r * 2.0, px)), c)
				_canvas.draw_rect(Rect2(p + Vector2(-r, r - px), Vector2(r * 2.0, px)), c)
				_canvas.draw_rect(Rect2(p + Vector2(-r, -r), Vector2(px, r * 2.0)), c)
				_canvas.draw_rect(Rect2(p + Vector2(r - px, -r), Vector2(px, r * 2.0)), c)
			"spark", "dot":
				var s: float = f.size
				_canvas.draw_rect(Rect2((f.pos - Vector2(s, s) / 2.0).round(), Vector2(s, s)), Color(f.color, a))
			"twinkle":
				var s := px * (1.0 + roundf(sin(k * PI) * 2.0))
				var c := Color(f.color, a)
				var p: Vector2 = f.pos
				_canvas.draw_rect(Rect2(p - Vector2(px / 2.0, s * 2.0), Vector2(px, s * 4.0)), c)
				_canvas.draw_rect(Rect2(p - Vector2(s * 2.0, px / 2.0), Vector2(s * 4.0, px)), c)
