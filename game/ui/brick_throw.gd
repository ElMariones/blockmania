class_name BMBrickThrow
extends Control
## The Emergency Brick as a physical toy (presentation only). It pops out of its item card and
## bobs; the player grabs it and flings it (release velocity comes from the pointer), or clicks a
## tray well (or presses 1-3) to lob it there. In flight it spins, bounces off the screen edges
## and the floor with dust, and leaves a motion trail. When it enters a tray well it emits
## `hit(slot)`; the game screen then commits the "use" action with that slot, so the rules only
## ever see the chosen slot, never the physics. Uses real delta and the global RNG only.

signal hit(slot: int)
signal cancelled

const HALF := Vector2(56, 28)
const GRAVITY := 2300.0
const RESTITUTION := 0.5
const MAX_SPEED := 3200.0

## Global rects of the three tray wells, and where the brick waits (its item card).
var slot_rects: Array[Rect2] = []
var home := Vector2.ZERO

var state := "hover" ## hover, held, flying, homing, resting, done
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var rot := 0.0
var spin := 0.0
var _t := 0.0
var _pop := 0.0
var _mouse := Vector2.ZERO
var _grab_off := Vector2.ZERO
var _samples: Array = [] ## [time, position] while held, for the release velocity
var _trail: Array[Vector2] = []
var _rest_t := 0.0
var _home_from := Vector2.ZERO
var _home_slot := -1
var _home_t := 0.0
var _floor_bounces := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func start(from: Vector2) -> void:
	home = from
	pos = from
	state = "hover"
	_pop = 0.0
	BMAudio.sfx("brick_grab", 0.9)


## Lob the brick along an arc into a well (click on a well, or keys 1-3).
func throw_to(slot: int) -> void:
	if state in ["done", "homing"] or slot < 0 or slot >= slot_rects.size():
		return
	_home_from = pos
	_home_slot = slot
	_home_t = 0.0
	state = "homing"
	spin = 11.0 if randf() < 0.5 else -11.0
	BMAudio.sfx("brick_whoosh", 1.0)


func cancel() -> void:
	if state == "done":
		return
	state = "done"
	BMAudio.sfx("tool_cancel")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)
	cancelled.emit()


func _input(event: InputEvent) -> void:
	if state == "done":
		return
	if event is InputEventMouse:
		_mouse = event.position
	if event is InputEventMouseMotion:
		if state == "held":
			_samples.append([Time.get_ticks_msec() / 1000.0, _mouse])
			if _samples.size() > 12:
				_samples.pop_front()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if state in ["hover", "resting", "flying"] and _mouse.distance_to(pos) < 80.0:
			state = "held"
			_grab_off = pos - _mouse
			_samples = [[Time.get_ticks_msec() / 1000.0, _mouse]]
			BMAudio.sfx("brick_grab")
			get_viewport().set_input_as_handled()
		elif state in ["hover", "resting"]:
			for i in slot_rects.size():
				if slot_rects[i].has_point(_mouse):
					throw_to(i)
					get_viewport().set_input_as_handled()
					return
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and state == "held":
		_release()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
		get_viewport().set_input_as_handled()


func _release() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var v := Vector2.ZERO
	var oldest: Array = _samples[0]
	for s in _samples:
		if now - float(s[0]) <= 0.1:
			oldest = s
			break
	var dt := maxf(0.016, now - float(oldest[0]))
	v = (_mouse - (oldest[1] as Vector2)) / dt
	vel = v.limit_length(MAX_SPEED)
	spin = clampf(vel.x * 0.012, -18.0, 18.0) + randf_range(-2.0, 2.0)
	state = "flying"
	_floor_bounces = 0
	if vel.length() > 400.0:
		BMAudio.sfx("brick_whoosh", clampf(0.8 + vel.length() / 3000.0, 0.8, 1.3))


func _process(delta: float) -> void:
	_t += delta
	_pop = minf(1.0, _pop + delta * 5.0)
	match state:
		"hover":
			pos = pos.lerp(home + Vector2(0, -210 + sin(_t * 3.0) * 8.0), 1.0 - exp(-delta * 9.0))
			rot = sin(_t * 2.2) * 0.1
		"held":
			var target := _mouse + _grab_off
			var prev := pos
			pos = pos.lerp(target, 1.0 - exp(-delta * 28.0))
			rot = lerpf(rot, clampf((pos.x - prev.x) * 0.02, -0.7, 0.7), 1.0 - exp(-delta * 12.0))
		"flying":
			_fly(delta)
		"homing":
			_home_t = minf(1.0, _home_t + delta / 0.42)
			var to := slot_rects[_home_slot].get_center()
			var k := _home_t
			pos = _home_from.lerp(to, k) + Vector2(0, -260.0 * 4.0 * k * (1.0 - k))
			rot += spin * delta
			if _home_t >= 1.0:
				_impact(_home_slot)
		"resting":
			_rest_t += delta
			rot = lerpf(rot, roundf(rot / PI) * PI, 1.0 - exp(-delta * 8.0))
	if state in ["flying", "homing"]:
		_trail.append(pos)
		if _trail.size() > 7:
			_trail.pop_front()
	elif not _trail.is_empty():
		_trail.pop_front()
	queue_redraw()


func _fly(delta: float) -> void:
	vel.y += GRAVITY * delta
	vel *= 1.0 - 0.12 * delta
	pos += vel * delta
	rot += spin * delta
	var w := size.x
	var floor_y := size.y - HALF.y - 6.0
	if pos.x < HALF.x:
		pos.x = HALF.x
		_bounce_wall(Vector2.RIGHT)
	elif pos.x > w - HALF.x:
		pos.x = w - HALF.x
		_bounce_wall(Vector2.LEFT)
	if pos.y < HALF.y:
		pos.y = HALF.y
		vel.y = absf(vel.y) * RESTITUTION
		_bounce_fx(Vector2(pos.x, 0), absf(vel.y))
	if pos.y > floor_y:
		pos.y = floor_y
		if vel.y > 260.0 and _floor_bounces < 4:
			_floor_bounces += 1
			_bounce_fx(Vector2(pos.x, size.y), vel.y)
			vel.y = -vel.y * RESTITUTION
			vel.x *= 0.75
			spin *= -0.6
		else:
			vel.y = 0.0
			vel.x *= 1.0 - minf(1.0, 6.0 * delta)
			spin *= 1.0 - minf(1.0, 8.0 * delta)
			if absf(vel.x) < 40.0:
				state = "resting"
				_rest_t = 0.0
	for i in slot_rects.size():
		if slot_rects[i].grow(6).has_point(pos):
			_impact(i)
			return


func _bounce_wall(normal: Vector2) -> void:
	var speed := absf(vel.x)
	vel.x = normal.x * speed * RESTITUTION
	spin = -spin * 0.7
	_bounce_fx(pos - normal * HALF.x, speed)


func _bounce_fx(at: Vector2, speed: float) -> void:
	if speed < 120.0:
		return
	BMAudio.sfx("brick_bounce", randf_range(0.9, 1.1), clampf(-14.0 + speed / 120.0, -14.0, 0.0))
	if BMFx.instance:
		BMFx.instance.dust(at, 60.0, 8)
		BMFx.instance.chips(at, [Color("#b5472f"), Color("#7d2a1c"), Color("#d9c7a8")], 3)
		BMFx.instance.shake(minf(8.0, speed / 300.0))


func _impact(slot: int) -> void:
	state = "done"
	visible = false
	hit.emit(slot)
	queue_free()


func _draw() -> void:
	if state == "done":
		return
	# Target wells: pulsing frames with their key numbers.
	for i in slot_rects.size():
		var r := slot_rects[i]
		var near := state == "held" and r.get_center().distance_to(pos) < 260.0
		var a := 0.55 + 0.35 * sin(_t * 6.0 + i)
		draw_rect(r.grow(6), Color(BMStyle.INK, 0.6), false, 10.0)
		draw_rect(r.grow(6), Color(BMStyle.SUN, a if near else a * 0.75), false, 6.0 if near else 4.0)
		# Bouncing target arrow over each well.
		var tip := Vector2(r.get_center().x, r.position.y - 10 - absf(sin(_t * 5.0 + i * 0.7)) * 14.0).round()
		var pts := PackedVector2Array([tip, tip + Vector2(-16, -20), tip + Vector2(16, -20)])
		draw_colored_polygon(pts, BMStyle.SUN)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), BMStyle.INK, 3.0)
	for i in _trail.size():
		var k := float(i + 1) / (_trail.size() + 1)
		draw_rect(Rect2(_trail[i] - HALF * 0.7 * k, HALF * 1.4 * k), Color("#b5472f", 0.18 * k))
	var s := 0.6 + 0.4 * _pop if _pop < 1.0 else 1.0
	# Drop shadow (not rotated so it reads as light from above).
	draw_rect(Rect2(pos + Vector2(-HALF.x * s + 10, -HALF.y * s + 14), HALF * 2.0 * s), Color(BMStyle.INK, 0.35))
	draw_set_transform(pos, rot, Vector2(s, s))
	draw_brick(self, HALF)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if state == "hover":
		_hint("GRAB & THROW IT!", pos + Vector2(0, -62))
		_hint("or click a tray slot  |  right-click to cancel", pos + Vector2(0, 58), 20, BMStyle.TEXT_DIM)
	elif state == "resting":
		_hint("GRAB IT AGAIN, OR CLICK A SLOT", pos + Vector2(0, -58))


## Chunky pixel brick centered on the canvas origin: ink outline, bevel, staggered mortar
## joints, speckles (art pixel = 4 px). Also used by the tray well for a brick piece.
static func draw_brick(ci: CanvasItem, half: Vector2, alpha: float = 1.0) -> void:
	var r := Rect2(-half, half * 2.0)
	ci.draw_rect(r.grow(4), Color(BMStyle.INK, alpha))
	ci.draw_rect(r, Color("#b5472f", alpha))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 8)), Color("#e0704f", alpha))
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 8), Vector2(r.size.x, 8)), Color("#7d2a1c", alpha))
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 8, 0), Vector2(8, r.size.y)), Color("#8e3322", alpha))
	var mortar := Color("#d9c7a8", alpha)
	ci.draw_rect(Rect2(Vector2(-half.x, -2), Vector2(half.x * 2.0, 4)), mortar)
	for f in [-0.2, 0.5]:
		ci.draw_rect(Rect2(Vector2(roundf(half.x * f), -half.y), Vector2(4, half.y - 2)), mortar)
	for f in [-0.6, 0.15]:
		ci.draw_rect(Rect2(Vector2(roundf(half.x * f), 2), Vector2(4, half.y - 2)), mortar)
	for f in [Vector2(-0.8, -0.6), Vector2(-0.4, -0.45), Vector2(0.2, -0.7), Vector2(0.7, -0.4), Vector2(-0.3, 0.35), Vector2(0.4, 0.5), Vector2(-0.85, 0.4)]:
		ci.draw_rect(Rect2((half * f).round(), Vector2(4, 4)), Color("#7d2a1c", alpha))
	ci.draw_rect(Rect2(Vector2(-half.x + 4, -half.y + 4), Vector2(12, 4)), Color(1, 1, 1, 0.55 * alpha))


func _hint(text: String, at: Vector2, px: int = 20, color: Color = BMStyle.SUN_L) -> void:
	var font := BMStyle.font_bold
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var p := (at - Vector2(w / 2.0, 0)).round()
	for o in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3)]:
		draw_string(font, p + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, BMStyle.INK)
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
