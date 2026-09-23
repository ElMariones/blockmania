class_name BMHud
extends RefCounted
## Custom-drawn HUD widgets for the round screen. All values shown are already-resolved state;
## animations only interpolate the display.


## Marquee sign with chasing bulbs around the edge. Boss mode turns it red and faster.
class Marquee extends Control:
	var text := ""
	var sub := ""
	var icon: Texture2D
	var boss := false
	var reduced_motion := false
	var message := ""
	var message_color := Color.WHITE
	var _msg_t := 0.0
	var _t := 0.0

	## Temporarily replaces the sign text with a message (0 = until cleared).
	func flash(msg: String, color: Color, duration: float = 2.6) -> void:
		message = msg
		message_color = color
		_msg_t = duration if duration > 0.0 else INF

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta * (2.0 if boss else 1.0)
		if message != "":
			_msg_t -= delta
			if _msg_t <= 0.0:
				message = ""
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(BMStyle.box("panel_boss" if boss else "panel_plate_plain", Vector4.ZERO), r)
		var inner := r.grow(-10)
		inner.size.y -= 6
		draw_rect(inner, Color(BMStyle.INK, 0.55))
		var n := int(inner.size.x / 24)
		var chase := int(_t * 8.0) if not reduced_motion else 0
		for i in n:
			var on := (i + chase) % 3 == 0
			var x := inner.position.x + 12 + i * (inner.size.x - 24) / maxf(1, n - 1)
			for y in [inner.position.y + 5, inner.end.y - 5]:
				var c := (BMStyle.PINK_L if boss else BMStyle.SUN_L) if on else Color(BMStyle.PLUM_L, 0.8)
				draw_rect(Rect2(Vector2(x - 3, y - 3), Vector2(6, 6)), c)
		var f := BMStyle.font_bold
		if message != "":
			# Message mode: fit the text, blink the frame bulbs faster.
			var ms := 30
			var mw := f.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, ms).x
			if mw > inner.size.x - 40:
				ms = 20
				mw = f.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, ms).x
			var my := inner.get_center().y + (11 if ms == 30 else 7)
			draw_string_outline(f, Vector2((size.x - mw) / 2.0, my), message, HORIZONTAL_ALIGNMENT_LEFT, -1, ms, 8, BMStyle.INK)
			draw_string(f, Vector2((size.x - mw) / 2.0, my), message, HORIZONTAL_ALIGNMENT_LEFT, -1, ms, message_color)
			return
		var size_px := 40
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		var sw := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x if sub != "" else 0.0
		var icon_width := 68.0 if icon != null else 0.0
		var total := tw + (sw + 24 if sub != "" else 0.0) + (icon_width + 12 if icon != null else 0.0)
		var x0 := (size.x - total) / 2.0
		var base_y := inner.get_center().y + 14
		if icon != null:
			draw_texture_rect(icon, Rect2(Vector2(x0, base_y - 36), Vector2(68, 36)), false)
			x0 += icon_width + 12
		draw_string_outline(f, Vector2(x0, base_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 10, BMStyle.INK)
		draw_string(f, Vector2(x0, base_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, BMStyle.PINK_L if boss else BMStyle.SUN)
		if sub != "":
			draw_string(f, Vector2(x0 + tw + 24, base_y - 4), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BMStyle.CREAM)


## Glass tube that fills with glowing liquid toward the target; bubbles rise inside.
class Tube extends Control:
	var value := 0.0 ## displayed fraction (animated)
	var target := 0.0
	var reduced_motion := false
	var _t := 0.0
	var _bubbles: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_fraction(f: float) -> void:
		target = clampf(f, 0.0, 1.0)
		if reduced_motion:
			value = target

	func _process(delta: float) -> void:
		_t += delta
		value = move_toward(value, target, delta * maxf(0.25, absf(target - value) * 3.0))
		if not reduced_motion and value > 0.02 and randf() < delta * 6.0:
			_bubbles.append({"x": randf(), "y": 1.0, "s": randf_range(4, 8)})
		for b in _bubbles:
			b.y -= delta * 0.9
		_bubbles = _bubbles.filter(func(b: Dictionary) -> bool: return b.y > 0.0)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, BMStyle.INK)
		var inner := r.grow(-4)
		draw_rect(inner, Color("#160e22"))
		var full := value >= 0.999
		var liquid := BMStyle.MINT if full else BMStyle.SUN
		var w := inner.size.x * value
		if w > 0.0:
			var lr := Rect2(inner.position, Vector2(w, inner.size.y))
			draw_rect(lr, liquid.darkened(0.25))
			draw_rect(Rect2(lr.position, Vector2(lr.size.x, lr.size.y * 0.55)), liquid)
			draw_rect(Rect2(lr.position + Vector2(0, 4), Vector2(lr.size.x, 4)), Color(1, 1, 1, 0.35))
			# Wobbling meniscus.
			var wob := 0.0 if reduced_motion else sin(_t * 5.0) * 3.0
			draw_rect(Rect2(Vector2(lr.end.x - 4, lr.position.y + 4 + wob), Vector2(4, lr.size.y - 8)), liquid.lightened(0.4))
			for b in _bubbles:
				var bx: float = inner.position.x + b.x * w
				var by: float = inner.position.y + b.y * inner.size.y
				var s: float = b.s
				draw_rect(Rect2(Vector2(bx, by), Vector2(s, s)).intersection(lr), Color(1, 1, 1, 0.5))
		# Glass glare and ticks.
		draw_rect(Rect2(inner.position + Vector2(6, 3), Vector2(inner.size.x - 12, 3)), Color(1, 1, 1, 0.18))
		for i in range(1, 4):
			var x := inner.position.x + inner.size.x * i / 4.0
			draw_rect(Rect2(Vector2(x - 2, inner.end.y - 10), Vector2(4, 10)), Color(BMStyle.INK, 0.6))


## A row of bulbs: lit = placements left, out of the round's refill cap (up to 16 bulbs; the
## moves label beside it always shows the exact count). Spent bulbs flash white, refilled mint.
class Lamps extends Control:
	var lit := 0
	var total := 15
	var _flash := {}
	var _refill := {}

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_counts(new_lit: int, new_total: int) -> void:
		if new_lit < lit:
			for i in range(new_lit, lit):
				_flash[i] = 0.35
		elif new_lit > lit and lit > 0:
			for i in range(lit, new_lit):
				_refill[i] = 0.6
		lit = new_lit
		total = maxi(new_total, new_lit)
		queue_redraw()

	func _process(delta: float) -> void:
		if _flash.is_empty() and _refill.is_empty():
			return
		for d in [_flash, _refill]:
			for k in d.keys():
				d[k] -= delta
				if d[k] <= 0.0:
					d.erase(k)
		queue_redraw()

	func _draw() -> void:
		var on := BMStyle.tex("icon_bulb_on")
		var off := BMStyle.tex("icon_bulb_off")
		var bw := 30.0
		var n := mini(total, 16)
		var gap := minf(bw + 4.0, (size.x - bw) / maxf(1, n - 1))
		for i in n:
			var t := on if i < lit else off
			var pos := Vector2(i * gap, (size.y - 36) / 2.0)
			if _flash.has(i):
				draw_rect(Rect2(pos - Vector2(2, 2), Vector2(bw + 4, 40)), Color(1, 1, 1, _flash[i] * 1.5))
			elif _refill.has(i):
				draw_rect(Rect2(pos - Vector2(2, 2), Vector2(bw + 4, 40)), Color(BMStyle.MINT_L, _refill[i]))
			draw_texture_rect(t, Rect2(pos, Vector2(bw, 36)), false)


## Label that rolls its number toward a target (odometer feel).
class Counter extends Label:
	var shown := 0.0
	var target := 0
	var reduced_motion := false
	var prefix := ""

	func set_target(v: int, instant: bool = false) -> void:
		target = v
		if instant or reduced_motion:
			shown = v
			text = prefix + BMUI.fmt_int(v)

	func _process(delta: float) -> void:
		if int(shown) == target:
			return
		shown = move_toward(shown, target, maxf(30.0, absf(target - shown) * 6.0) * delta)
		text = prefix + BMUI.fmt_int(int(shown))


## Full-width dashed tear line for paper panels.
class Dashes extends Control:
	var color := Color(0.1, 0.06, 0.15, 0.35)

	func _init() -> void:
		custom_minimum_size = Vector2(0, 12)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var x := 0.0
		while x < size.x:
			draw_rect(Rect2(Vector2(x, size.y / 2.0 - 1.0), Vector2(minf(8.0, size.x - x), 3)), color)
			x += 16.0


## Cream receipt tape. New placements print line by line.
class Receipt extends PanelContainer:
	var reduced_motion := false
	var _lines: VBoxContainer
	var _queue: Array = []
	var _timer := 0.0

	func _ready() -> void:
		add_theme_stylebox_override("panel", BMStyle.box("panel_paper", Vector4(10, 6, 10, 10)))
		var v := BMStyle.vbox(2)
		add_child(v)
		var head := BMStyle.label("RECEIPT", 20, Color(BMStyle.INK, 0.55), true)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(head)
		_lines = BMStyle.vbox(2)
		v.add_child(_lines)

	## rows: [{text, color, bold, align}] printed top to bottom.
	func print_rows(rows: Array) -> void:
		BMUI.clear_children(_lines)
		_queue = rows.duplicate()
		_timer = 0.0
		if reduced_motion:
			while not _queue.is_empty():
				_emit(_queue.pop_front())

	func _process(delta: float) -> void:
		if _queue.is_empty():
			return
		_timer -= delta
		if _timer <= 0.0:
			_emit(_queue.pop_front())
			_timer = 0.045

	func _emit(row: Dictionary) -> void:
		if not reduced_motion:
			BMAudio.sfx("print")
		if row.get("dashes", false):
			_lines.add_child(Dashes.new())
			return
		var h := BMStyle.hbox(4)
		var l := BMStyle.label(String(row.get("text", "")), 20, row.get("color", BMStyle.INK), bool(row.get("bold", false)))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		h.add_child(l)
		if row.has("value"):
			var vl := BMStyle.label(String(row.value), 20, row.get("value_color", BMStyle.INK), true)
			h.add_child(vl)
		_lines.add_child(h)
		if not reduced_motion:
			h.modulate.a = 0.0
			h.create_tween().tween_property(h, "modulate:a", 1.0, 0.08)
