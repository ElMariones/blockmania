class_name BMTraySlot
extends Control
## One of the three tray offers: a recessed well with a key tag. The piece floats gently,
## lifts with a shadow on hover, and shows text states ("HOLDING", "NO ROOM") so nothing
## depends on color alone. A new deal spins the well like a slot reel (cosmetic shapes, then
## the real piece drops in with a bounce). Pieces that belong to a Tray Hand wear a ribbon
## with the Hand's name and chasing marquee lights around the well.

signal pressed(slot: int)
signal reel_stopped(slot: int)

## Presentation colors per Tray Hand (names are always printed, so color is never the only cue).
const HAND_COLORS := {"twins": BMStyle.SKY, "staircase": BMStyle.MINT, "monochrome": BMStyle.PINK,
	"triplets": BMStyle.SUN, "grand_slam": BMStyle.LILAC}

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
var locked := false ## The Warden's bars (presentation of a rules flag).
var _spin := 0.0 ## seconds of reel spin left
var _reel: Array = [] ## cosmetic shapes cycling through the reel window
var _land := 1.0 ## 0 -> 1 after the reel stops (drop and bounce)
var _flare := 0.0 ## Hand formation flash

const MINI_CELL := 44.0


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true # the reel scrolls behind the well's window
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


## Spins the reel for `duration` seconds through `reel` (cosmetic shapes), then lands the
## real piece. Reduced motion skips straight to the landed state.
func spin(duration: float, reel: Array) -> void:
	if reduced_motion or reel.is_empty():
		_spin = 0.0
		_land = 1.0
		return
	_reel = reel
	_spin = duration
	_land = 0.0
	queue_redraw()


func is_spinning() -> bool:
	return _spin > 0.0


## A bright flash on the well when its Hand is revealed.
func flare() -> void:
	_flare = 1.0


func _process(delta: float) -> void:
	if _spin > 0.0:
		_spin -= delta
		if _spin <= 0.0:
			_spin = 0.0
			_land = 0.0
			reel_stopped.emit(slot)
	elif _land < 1.0:
		_land = minf(1.0, _land + delta * 3.2)
	_flare = maxf(0.0, _flare - delta * 1.5)
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
	if _spin > 0.0:
		_draw_reel()
		return
	var hand := String(shape.get("hand", "")) if not shape.is_empty() else ""
	if hand != "":
		_draw_hand_lights(HAND_COLORS.get(hand, BMStyle.SUN))
	if _flare > 0.0:
		draw_rect(r.grow(-4), Color(1, 1, 1, 0.5 * _flare))
	if shape.is_empty():
		draw_string(BMStyle.font, Vector2(0, size.y / 2.0 + 8), "placed", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(BMStyle.TEXT_DIM, 0.5))
		return
	var dims := Vector2(BMShapes.shape_size(shape))
	var cell := floorf(minf(MINI_CELL, minf((size.x - 36) / dims.x, (size.y - 56) / dims.y)))
	var bob := 0.0 if reduced_motion else roundf(sin(_t * 2.2 + slot * 1.7) * 2.0)
	var lift := -8.0 * _lift
	# Landing after a reel stop: drop from above, overshoot, settle.
	var land := 0.0
	if _land < 1.0:
		var k := _land
		land = -40.0 * (1.0 - k) * (1.0 - k) + 10.0 * sin(k * PI) * (1.0 - k)
	var origin := ((size - dims * cell) / 2.0 + Vector2(0, bob + lift - 4 + land)).round()
	var alpha := 0.25 if held else (1.0 if fits else 0.5)
	# Soft drop shadow grows with lift.
	if not held:
		for c: Vector2i in shape.cells:
			draw_rect(Rect2(origin + Vector2(c) * cell + Vector2(4, 6 + 6 * _lift), Vector2(cell, cell)), Color(BMStyle.INK, 0.45))
	BMBlockPainter.draw_shape(self, shape, origin, cell, alpha, Color.WHITE, block_skin)
	if hand != "":
		_ribbon(BMHands.get_def(hand).badge, HAND_COLORS.get(hand, BMStyle.SUN))
	if locked:
		_draw_bars()
		_caption("LOCKED", BMStyle.PINK_L)
	elif held:
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


## A slot-machine reel: cosmetic shapes scroll down behind a curved-glass window.
func _draw_reel() -> void:
	var speed := 1400.0 * clampf(_spin / 0.4, 0.35, 1.0)
	var pitch := size.y * 0.9
	var scroll := fmod(_t * speed, pitch)
	var idx := int(_t * speed / pitch)
	var cell := 30.0
	for k in [-1, 0, 1]:
		var sh: Dictionary = _reel[posmod(idx - k, _reel.size())]
		var dims := Vector2(BMShapes.shape_size(sh))
		var o := ((size - dims * cell) / 2.0 + Vector2(0, scroll + k * pitch - pitch * 0.5 + 10)).round()
		BMBlockPainter.draw_shape(self, sh, o, cell, 0.75)
	# Motion streaks and drum shading.
	for i in 6:
		var y := fmod(_t * speed * 1.7 + i * 37.0, size.y)
		draw_rect(Rect2(Vector2(14, y), Vector2(size.x - 28, 4)), Color(1, 1, 1, 0.08))
	for i in 5:
		var a := 0.5 * (1.0 - i / 5.0)
		draw_rect(Rect2(Vector2(4, 4 + i * 8), Vector2(size.x - 8, 8)), Color(BMStyle.INK, a))
		draw_rect(Rect2(Vector2(4, size.y - 12 - i * 8), Vector2(size.x - 8, 8)), Color(BMStyle.INK, a))
	# Center payline.
	draw_rect(Rect2(Vector2(6, size.y / 2.0 - 2), Vector2(8, 4)), BMStyle.SUN)
	draw_rect(Rect2(Vector2(size.x - 14, size.y / 2.0 - 2), Vector2(8, 4)), BMStyle.SUN)


## Marquee bulbs chasing around the well's rim.
func _draw_hand_lights(color: Color) -> void:
	var per_side := 7
	var pts: Array[Vector2] = []
	var inset := 6.0
	var w := size.x - inset * 2
	var h := size.y - inset * 2
	for i in per_side:
		pts.append(Vector2(inset + w * i / per_side, inset))
	for i in per_side:
		pts.append(Vector2(inset + w, inset + h * i / per_side))
	for i in per_side:
		pts.append(Vector2(inset + w - w * i / per_side, inset + h))
	for i in per_side:
		pts.append(Vector2(inset, inset + h - h * i / per_side))
	var head := int(_t * 14.0) if not reduced_motion else -1
	for i in pts.size():
		var lit := reduced_motion or (posmod(i - head, 4) == 0)
		var c := color.lightened(0.35) if lit else Color(color, 0.45)
		var q := pts[i].round()
		draw_rect(Rect2(q - Vector2(5, 5), Vector2(10, 10)), BMStyle.INK)
		draw_rect(Rect2(q - Vector2(3, 3), Vector2(6, 6)), c)
		if lit:
			draw_rect(Rect2(q - Vector2(3, 3), Vector2(2, 2)), Color(1, 1, 1, 0.8))


## Hand name ribbon across the top-right of the well.
func _ribbon(text: String, color: Color) -> void:
	var w := BMStyle.font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 20
	var rr := Rect2(Vector2(size.x - w - 8, 10), Vector2(w, 28))
	draw_rect(rr.grow(2), BMStyle.INK)
	draw_rect(rr, color)
	draw_rect(Rect2(rr.position, Vector2(rr.size.x, 4)), Color(1, 1, 1, 0.35))
	draw_string(BMStyle.font_bold, rr.position + Vector2(10, 21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BMStyle.INK)


## Iron bars over a locked well (The Warden).
func _draw_bars() -> void:
	draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), Color(BMStyle.INK, 0.45))
	var n := 5
	for i in n:
		var x := roundf(18 + (size.x - 36) * i / (n - 1)) - 4
		draw_rect(Rect2(Vector2(x, 8), Vector2(8, size.y - 16)), BMStyle.PLUM_LL)
		draw_rect(Rect2(Vector2(x, 8), Vector2(3, size.y - 16)), Color(1, 1, 1, 0.3))
		draw_rect(Rect2(Vector2(x + 6, 8), Vector2(2, size.y - 16)), BMStyle.INK)
	draw_rect(Rect2(Vector2(10, 24), Vector2(size.x - 20, 8)), BMStyle.PLUM_L)
	draw_rect(Rect2(Vector2(10, size.y - 32), Vector2(size.x - 20, 8)), BMStyle.PLUM_L)
	var lock := BMStyle.tex("icon_lock")
	var ls := lock.get_size()
	draw_texture_rect(lock, Rect2((size - ls) / 2.0 - Vector2(0, 8), ls), false)
