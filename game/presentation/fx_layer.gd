class_name BMFx
extends Control
## Presentation-only effects drawn above the UI and below the CRT pass: pixel particles
## (bursts, sparks, confetti, coins, glass shards, dust), pop-up text, and screen shake.
## Never touches game state. Particle count is capped; reduced motion skips particles and
## shake but keeps text pops (information stays visible).

static var instance: BMFx

const MAX_PARTICLES := 900
const GRAVITY := 900.0

var reduced_motion := false
var shake_target: Control
var _parts: Array = [] ## {pos, vel, life, max, size, color, kind, rot, spin}
var _shake := 0.0
var _shake_base := Vector2.ZERO


func _init() -> void:
	instance = self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- Emitters ------------------------------------------------------------------------------

func burst(at: Vector2, colors: Array, count: int = 16, speed: float = 380.0, size: float = 8.0, gravity := true) -> void:
	if reduced_motion:
		return
	for i in count:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * speed * randf_range(0.35, 1.0) + Vector2(0, -speed * 0.35)
		_add({"pos": at, "vel": v, "life": randf_range(0.45, 0.9), "size": size * randf_range(0.6, 1.2),
			"color": colors[randi() % colors.size()], "kind": "px", "grav": 1.0 if gravity else 0.0})


func sparks(at: Vector2, color: Color, count: int = 10, speed: float = 520.0) -> void:
	if reduced_motion:
		return
	for i in count:
		var a := randf() * TAU
		_add({"pos": at, "vel": Vector2(cos(a), sin(a)) * speed * randf_range(0.5, 1.0), "life": randf_range(0.2, 0.45),
			"size": 4.0, "color": color, "kind": "spark", "grav": 0.2})


func stars(at: Vector2, count: int = 6, radius: float = 60.0) -> void:
	if reduced_motion:
		return
	for i in count:
		var off := Vector2(randf_range(-radius, radius), randf_range(-radius * 0.6, radius * 0.6))
		_add({"pos": at + off, "vel": Vector2(0, -40), "life": randf_range(0.4, 0.8), "size": 4.0,
			"color": BMStyle.SUN_L, "kind": "star", "grav": 0.0})


func dust(at: Vector2, width: float, count: int = 10) -> void:
	if reduced_motion:
		return
	for i in count:
		var p := at + Vector2(randf_range(-width / 2, width / 2), 0)
		_add({"pos": p, "vel": Vector2(randf_range(-80, 80), randf_range(-120, -40)), "life": randf_range(0.3, 0.55),
			"size": randf_range(4, 8), "color": Color(BMStyle.CREAM, 0.7), "kind": "px", "grav": 0.3})


func confetti(rect: Rect2, count: int = 120) -> void:
	if reduced_motion:
		return
	var cols := [BMStyle.SUN, BMStyle.PINK, BMStyle.SKY, BMStyle.MINT, BMStyle.LILAC, BMStyle.CREAM]
	for i in count:
		var p := Vector2(randf_range(rect.position.x, rect.end.x), rect.position.y - randf_range(0, 200))
		_add({"pos": p, "vel": Vector2(randf_range(-80, 80), randf_range(40, 260)), "life": randf_range(1.6, 2.8),
			"size": randf_range(6, 10), "color": cols[randi() % cols.size()], "kind": "confetti", "grav": 0.25,
			"rot": randf() * TAU, "spin": randf_range(-8, 8)})


func coins(from: Vector2, to: Vector2, count: int = 6) -> void:
	if reduced_motion:
		return
	for i in count:
		var mid := from.lerp(to, 0.5) + Vector2(randf_range(-120, 120), randf_range(-220, -80))
		_add({"pos": from, "from": from, "mid": mid, "to": to, "life": 0.7 + i * 0.06, "size": 8.0,
			"color": BMStyle.SUN, "kind": "coin", "grav": 0.0, "vel": Vector2.ZERO})


func shards(at: Vector2, count: int = 14) -> void:
	if reduced_motion:
		return
	for i in count:
		var a := randf() * TAU
		_add({"pos": at, "vel": Vector2(cos(a), sin(a)) * randf_range(150, 480), "life": randf_range(0.5, 0.9),
			"size": randf_range(6, 12), "color": Color(0.85, 0.97, 1.0, 0.9), "kind": "shard", "grav": 1.0,
			"rot": randf() * TAU, "spin": randf_range(-12, 12)})


## Chips flying from the board to a HUD target (score counter).
func stream(from: Vector2, to: Vector2, color: Color, count: int = 8) -> void:
	if reduced_motion:
		return
	for i in count:
		var mid := from.lerp(to, 0.5) + Vector2(randf_range(-160, 160), randf_range(-160, 60))
		_add({"pos": from, "from": from + Vector2(randf_range(-30, 30), randf_range(-30, 30)), "mid": mid, "to": to,
			"life": 0.45 + i * 0.035, "size": 6.0, "color": color, "kind": "homing", "grav": 0.0, "vel": Vector2.ZERO})


# --- Text and camera -----------------------------------------------------------------------

## Floating pop-up text with an ink outline. Scales in, drifts up, fades.
func pop_text(at: Vector2, text: String, color: Color, size: int = 40, rise: float = 70.0, duration: float = 0.9) -> Label:
	var l := BMStyle.label(text, size, color, true, 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.reset_size()
	l.pivot_offset = l.size / 2.0
	l.position = at - l.size / 2.0
	if reduced_motion:
		var tw0 := l.create_tween()
		tw0.tween_interval(duration)
		tw0.tween_callback(l.queue_free)
		return l
	l.scale = Vector2(0.4, 0.4)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.08)
	tw.parallel().tween_property(l, "position:y", l.position.y - rise, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tw.tween_callback(l.queue_free)
	return l


func shake(amount: float) -> void:
	if reduced_motion or shake_target == null:
		return
	if _shake <= 0.0:
		_shake_base = shake_target.position
	_shake = minf(28.0, maxf(_shake, amount))


func _add(p: Dictionary) -> void:
	if _parts.size() >= MAX_PARTICLES:
		return
	p["max"] = p.life
	if not p.has("rot"):
		p["rot"] = 0.0
		p["spin"] = 0.0
	_parts.append(p)


func _process(delta: float) -> void:
	if _shake > 0.0 and shake_target:
		_shake = maxf(0.0, _shake - delta * 60.0)
		shake_target.position = _shake_base + Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * _shake
		if _shake <= 0.0:
			shake_target.position = _shake_base
	if _parts.is_empty():
		return
	var alive: Array = []
	for p in _parts:
		p.life -= delta
		if p.life <= 0.0:
			continue
		match p.kind:
			"coin", "homing":
				var t: float = 1.0 - p.life / p.max
				t = t * t * (3.0 - 2.0 * t)
				var a: Vector2 = p.from.lerp(p.mid, t)
				var b: Vector2 = p.mid.lerp(p.to, t)
				p.pos = a.lerp(b, t)
			_:
				p.vel.y += GRAVITY * p.grav * delta
				if p.kind == "confetti":
					p.vel.x += sin(p.life * 6.0) * 30.0 * delta
					p.vel = p.vel.limit_length(320.0)
				p.pos += p.vel * delta
				p.rot += p.spin * delta
		alive.append(p)
	_parts = alive
	queue_redraw()


func _draw() -> void:
	for p in _parts:
		var k: float = clampf(p.life / p.max, 0.0, 1.0)
		var c: Color = p.color
		var s: float = p.size
		match p.kind:
			"px":
				c.a *= minf(1.0, k * 2.0)
				var q: float = roundf(s * (0.4 + 0.6 * k) / 2.0) * 2.0
				draw_rect(Rect2((p.pos - Vector2(q, q) / 2.0).round(), Vector2(q, q)), c)
			"spark":
				c.a *= k
				var tail: Vector2 = p.vel * 0.03
				draw_line(p.pos, p.pos - tail, c, 4.0)
			"star":
				c.a *= sin(k * PI)
				var r: float = 4.0 + 8.0 * sin(k * PI)
				draw_rect(Rect2(p.pos - Vector2(2, r), Vector2(4, r * 2)), c)
				draw_rect(Rect2(p.pos - Vector2(r, 2), Vector2(r * 2, 4)), c)
			"confetti":
				c.a *= minf(1.0, k * 3.0)
				var w: float = s * absf(cos(p.rot))
				draw_rect(Rect2(p.pos - Vector2(w / 2, s / 4), Vector2(maxf(2.0, w), s / 2)), c)
			"coin":
				var tx := BMStyle.tex("icon_coin")
				var sz := tx.get_size() * 0.75
				draw_texture_rect(tx, Rect2(p.pos - sz / 2.0, sz), false)
			"homing":
				c.a *= 0.4 + 0.6 * k
				draw_rect(Rect2(p.pos - Vector2(4, 4), Vector2(8, 8)), c)
				draw_rect(Rect2(p.pos - Vector2(2, 2), Vector2(4, 4)), Color(1, 1, 1, c.a))
			"shard":
				c.a *= k
				var dir := Vector2(cos(p.rot), sin(p.rot)) * s
				var perp := Vector2(-dir.y, dir.x) * 0.4
				draw_colored_polygon(PackedVector2Array([p.pos + dir, p.pos + perp, p.pos - dir * 0.5]), c)
