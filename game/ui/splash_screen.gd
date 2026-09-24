class_name BMSplash
extends Control
## Studio splash shown once at launch, over the title (replaces Godot's boot image, which is
## turned off in the project settings). The Buru Arcade logo builds itself: "BURU" drops in as
## toy block letters, the ARCADE marquee pops up under it with chasing bulbs, POPS rises from
## behind the sign and points at the logo, and the last U's corner block pops off in a starburst
## (POPS cheers). "made with Godot" slides in, then every block and POPS burst apart while the
## ink curtain fades to reveal the title. Same art as tools/art/gen_studio_logo.py.
## About 2.4 s. Any click, key or pad button skips straight to the burst; a second one ends it.
## Reduced motion: the logo fades in and out, with no drops, pops, bursting or particles.

signal revealing ## the burst starts and the curtain begins to fade
signal finished

## Same strokes as BMTitleScreen.LETTERS and gen_studio_logo.py.
const LETTERS := {
	"B": ["#####.", "##..##", "##..##", "#####.", "##..##", "##..##", "#####."],
	"U": ["##..##", "##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
	"R": ["#####.", "##..##", "##..##", "#####.", "####..", "##.##.", "##..##"],
}
const WORD := "BURU"
const COLOR_IDS := [0, 2, 3, 4] ## red, yellow, green, blue (BMFinishes.HUES order)
const POPPED := Vector3i(3, 5, 0) ## letter, column, row of the block that pops off
const CELL := 30.0
const LABEL := "ARCADE"
const MADE := "made with "
const ENGINE := "Godot"
const DROP_IN := 0.1 ## first letter starts its drop
const DROP_STEP := 0.11
const DROP_TIME := 0.4
const PLATE_AT := 0.72
const PLATE_TIME := 0.22
const LABEL_STEP := 0.04
const POP_AT := 1.2 ## the corner block pops off
const POPS_AT := 0.8 ## POPS rises from behind the marquee
const POPS_RISE := 0.28
const POPS_FRAME := Vector2(56, 62) ## one frame of assets/ui/helper.png (tools/art/gen_helper.py)
const POPS_SCALE := 4.0
const MADE_AT := 1.05
const BURST_AT := 2.0
const FADE_TIME := 0.55
const GRAVITY := 1500.0

var main: Node
var _t := 0.0
var _burst := false
var _done := false
var _popped := false
var _blocks: Array = [] ## {base: Vector2 top-left, color, letter, row, [pos, vel, rot, spin]}
var _label: Array = [] ## ARCADE letters {ch, base (center), adv, appear_at}
var _made: Array = [] ## "made with Godot" letters, same shape as _label
var _plate := Rect2()
var _pop_block := {} ## the popped block {base, color} and, once popped, {pos, vel}
var _bits: Array = [] ## burst particles {pos, vel, color, size, life}
var _motes: Array = [] ## slow background blocks
var _landed := 0
var _pops_tex: Texture2D
var _pops_rect := Rect2() ## where POPS stands once risen (screen px)
var _pops_hi := false
var _pops_fly := {} ## on the burst: {pos (center), vel, rot, spin}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_pops_tex = load("res://assets/ui/helper.png")
	_layout()
	resized.connect(_layout)
	for i in 22:
		_motes.append({"pos": Vector2(randf(), randf()), "speed": randf_range(0.02, 0.06),
			"size": randf_range(10.0, 26.0), "color": BMFinishes.HUES[i % 6]})


func _reduced() -> bool:
	return main != null and main.settings.reduced_motion


## Block, marquee and text positions for the lockup, centered on the screen.
func _layout() -> void:
	if _burst or _popped:
		return
	_blocks.clear()
	var cols := 0
	for ch in WORD:
		cols += String(LETTERS[ch][0]).length() + 1
	cols -= 1
	var word_w := cols * CELL
	var pops_w := POPS_FRAME.x * POPS_SCALE
	var c := size / 2.0
	# POPS stands left of the word; the pair is centered together.
	var top := c + Vector2(-(word_w + pops_w + 12.0) / 2.0 + pops_w + 12.0, -190.0)
	var x := 0
	for li in WORD.length():
		var rows: Array = LETTERS[WORD[li]]
		for ry in rows.size():
			var row: String = rows[ry]
			for rx in row.length():
				if row[rx] != "#":
					continue
				var b := {"base": (top + Vector2(x + rx, ry) * CELL).round(), "color": COLOR_IDS[li], "letter": li, "row": ry}
				if Vector3i(li, rx, ry) == POPPED:
					_pop_block = b
				else:
					_blocks.append(b)
		x += String(rows[0]).length() + 1
	var plate_x := top.x - pops_w - 12.0 + 36.0
	_plate = Rect2(Vector2(plate_x, top.y + 7 * CELL - 14.0), Vector2(top.x + word_w - 40.0 - plate_x, 104.0))
	_pops_rect = Rect2(Vector2(top.x - pops_w - 12.0, _plate.position.y + 12.0 - POPS_FRAME.y * POPS_SCALE),
		POPS_FRAME * POPS_SCALE)
	_label = _text_line(LABEL, 80, _plate.get_center() + Vector2(0, 2), PLATE_AT + PLATE_TIME * 0.5, LABEL_STEP)
	_made = _text_line(MADE + ENGINE, 30, c + Vector2(0, 170), MADE_AT, 0.012)


func _text_line(text: String, font_size: int, center: Vector2, start: float, step: float) -> Array:
	var out: Array = []
	var f := BMStyle.font_bold
	var width := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := center.x - width / 2.0
	var k := 0
	for i in text.length():
		var ch := text[i]
		var adv := f.get_char_size(ch.unicode_at(0), font_size).x
		if ch != " ":
			out.append({"ch": ch, "base": Vector2(x + adv / 2.0, center.y), "adv": adv, "size": font_size,
				"appear_at": start + k * step, "index": i})
			k += 1
		x += adv
	return out


func _input(event: InputEvent) -> void:
	if _done:
		return
	var pressed := (event is InputEventMouseButton or event is InputEventKey or event is InputEventJoypadButton) \
		and event.is_pressed() and not event.is_echo()
	if pressed:
		if _burst:
			_finish()
		else:
			_t = maxf(_t, BURST_AT)
	# Nothing reaches the title underneath while the splash is up.
	if not event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var rm := _reduced()
	# Landing ticks as each letter hits its line: a quick rising run.
	while _landed < WORD.length() and _t >= _letter_t0(_landed) + DROP_TIME and not _burst:
		if not rm:
			BMAudio.sfx("letter", BMAudio.scale_pitch(_landed * 2), -5.0)
		_landed += 1
	if not _pops_hi and _t >= POPS_AT and not _burst:
		_pops_hi = true
		if not rm:
			BMAudio.sfx("pops_hi", 1.0, -4.0)
	if not _popped and _t >= POP_AT and not _burst:
		_pop_corner(rm)
	if not _burst and _t >= BURST_AT:
		_start_burst()
	if not rm:
		if _popped:
			_pop_block.vel.y += GRAVITY * (0.25 if not _burst else 1.0) * delta
			_pop_block.pos += _pop_block.vel * delta
			if not _burst:
				_pop_block.vel *= pow(0.02, delta) # it hangs in the air, the logo's "pop" pose
			_pop_block.rot += _pop_block.spin * delta
		if _burst:
			if not _pops_fly.is_empty():
				_pops_fly.vel.y += GRAVITY * delta
				_pops_fly.pos += _pops_fly.vel * delta
				_pops_fly.rot += _pops_fly.spin * delta
			for b in _blocks:
				b.vel.y += GRAVITY * delta
				b.pos += b.vel * delta
				b.rot += b.spin * delta
		for i in range(_bits.size() - 1, -1, -1):
			var p: Dictionary = _bits[i]
			p.vel.y += GRAVITY * 0.6 * delta
			p.pos += p.vel * delta
			p.life -= delta
			if p.life <= 0.0:
				_bits.remove_at(i)
		for m in _motes:
			m.pos.y = fposmod(m.pos.y - m.speed * delta, 1.0)
	if _t >= BURST_AT + FADE_TIME:
		_finish()
	queue_redraw()


func _letter_t0(li: int) -> float:
	return DROP_IN + li * DROP_STEP


## The last U's corner block pops up and out with a starburst, then hangs there.
func _pop_corner(rm: bool) -> void:
	_popped = true
	var center: Vector2 = _pop_block.base + Vector2(CELL, CELL) / 2.0
	_pop_block.pos = center
	_pop_block.vel = Vector2(380.0, -420.0)
	_pop_block.rot = 0.0
	_pop_block.spin = 3.0
	if rm:
		_pop_block.pos = center + Vector2(CELL * 1.3, -CELL * 1.2)
		_pop_block.vel = Vector2.ZERO
		_pop_block.spin = 0.0
		return
	BMAudio.sfx("letter_pop", 1.35, -2.0)
	_chips(center, BMFinishes.HUES[int(_pop_block.color)], 9)


func _chips(at: Vector2, color: Color, n: int) -> void:
	for j in n:
		var a := randf() * TAU
		_bits.append({"pos": at, "vel": Vector2(cos(a), sin(a)) * randf_range(200.0, 650.0) + Vector2(0, -200),
			"color": [color, color.lightened(0.4), BMStyle.CREAM][j % 3], "size": randf_range(6.0, 12.0),
			"life": randf_range(0.35, 0.7)})


## Every block flies away from the middle with a spin: the title's letter pop, for the whole logo.
func _start_burst() -> void:
	_burst = true
	_t = BURST_AT
	revealing.emit()
	if _reduced():
		return
	if not _popped:
		_popped = true
		_pop_block.pos = _pop_block.base + Vector2(CELL, CELL) / 2.0
		_pop_block.vel = Vector2.ZERO
		_pop_block.rot = 0.0
		_pop_block.spin = 0.0
	BMAudio.sfx("letter_pop", 1.0)
	BMAudio.sfx_later("letter_pop", 0.06, 1.25, -4.0)
	var c := size / 2.0 + Vector2(0, -60)
	for b in _blocks:
		var p: Vector2 = b.base + Vector2(CELL, CELL) / 2.0 + Vector2(0, _bob(int(b.letter)))
		var out := (p - c).normalized() if p != c else Vector2.UP
		b.pos = p
		b.vel = out * randf_range(420.0, 900.0) + Vector2(randf_range(-120.0, 120.0), -randf_range(300.0, 700.0))
		b.rot = 0.0
		b.spin = randf_range(-12.0, 12.0)
		if randf() < 0.25:
			_chips(p, BMFinishes.HUES[int(b.color)], 2)
	_pop_block.vel += Vector2(300.0, -300.0)
	_pop_block.spin = 10.0
	# POPS hops up and tumbles off with his blocks.
	if _t >= POPS_AT:
		_pops_fly = {"pos": _pops_rect.get_center(), "vel": Vector2(-260.0, -820.0), "rot": 0.0, "spin": -4.0}


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()


func _appear(start: float, length: float) -> float:
	return clampf((_t - start) / length, 0.0, 1.0)


func _bob(li: int) -> float:
	if _reduced():
		return 0.0
	return sin(_t * 8.0 + li * 0.9) * 5.0 * _appear(_letter_t0(li) + DROP_TIME, 0.2)


func _draw() -> void:
	var rm := _reduced()
	var fade := clampf((_t - BURST_AT) / FADE_TIME, 0.0, 1.0) if _burst else 0.0
	var gone := 1.0 - clampf((_t - BURST_AT) / (FADE_TIME * 0.9), 0.0, 1.0) if _burst else 1.0
	# Ink curtain; it fades to reveal the title once the logo bursts.
	draw_rect(Rect2(Vector2.ZERO, size), Color(BMStyle.INK, 1.0 - fade))
	var c := size / 2.0
	var glow := clampf(_t / 0.5, 0.0, 1.0) * (1.0 - fade)
	for i in 5:
		var w := 1500.0 - i * 220.0
		var h := 520.0 - i * 80.0
		draw_rect(Rect2(c - Vector2(w, h) / 2.0 + Vector2(0, -60), Vector2(w, h)), Color(BMStyle.PLUM, 0.10 * glow))
	if not rm:
		for m in _motes:
			var mp := Vector2(m.pos.x * size.x, m.pos.y * size.y).round()
			draw_rect(Rect2(mp, Vector2(m.size, m.size)), Color(m.color, 0.12 * (1.0 - fade)))
	_draw_pops(rm, gone, fade)
	_draw_plate(rm, gone, fade)
	_draw_blocks(rm, gone, fade)
	_draw_pop(rm, gone, fade)
	_draw_text(_made, rm, gone, fade, 4.0)
	for b in _bits:
		draw_rect(Rect2(b.pos - Vector2(b.size, b.size) / 2.0, Vector2(b.size, b.size)), Color(b.color, clampf(b.life / 0.3, 0.0, 1.0)))
	# White flash on the burst.
	if _burst and not rm:
		var flash := 1.0 - clampf((_t - BURST_AT) / 0.18, 0.0, 1.0)
		if flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.35 * flash))


## The ARCADE marquee: brass rim, plum face, chaser bulbs. It pops up, then shrinks away on the burst.
func _draw_plate(rm: bool, gone: float, fade: float) -> void:
	var a := _appear(PLATE_AT, PLATE_TIME)
	if a <= 0.0:
		return
	var alpha := a * (gone * gone if not rm else 1.0 - fade)
	var sc := 1.0
	if not rm:
		sc = (0.3 + 0.7 * a + sin(a * PI) * 0.12) if not _burst else 1.0 - (1.0 - gone) * 0.4
	var r := _plate
	draw_set_transform(r.get_center(), 0.0, Vector2(sc, sc))
	r.position = -r.size / 2.0
	draw_rect(Rect2(r.position + Vector2(8, 10), r.size), Color(BMStyle.INK, alpha))
	draw_rect(r, Color(BMStyle.INK, alpha))
	draw_rect(r.grow(-4), Color(BMStyle.SUN_D, alpha))
	draw_rect(r.grow(-4).grow_side(SIDE_BOTTOM, -4), Color(BMStyle.SUN, alpha))
	draw_rect(Rect2(r.position + Vector2(12, 4), Vector2(r.size.x - 24, 4)), Color(BMStyle.SUN_L, alpha))
	draw_rect(r.grow(-20), Color(BMStyle.INK, alpha))
	draw_rect(r.grow(-24), Color(BMStyle.PLUM_D, alpha))
	draw_rect(Rect2(r.position + Vector2(28, 24), Vector2(r.size.x - 56, 4)), Color(BMStyle.PLUM, alpha))
	# Chaser bulbs along the rim; the lit ones step along with time (held still in reduced motion).
	var step := int(_t * 12.0) if not rm else 0
	var i := 0
	var bx := r.position.x + 16.0
	while bx <= r.end.x - 24.0:
		var lit := (i + step) % 3 == 0
		for by in [r.position.y + 6.0, r.end.y - 14.0]:
			draw_rect(Rect2(Vector2(bx, by), Vector2(8, 8)), Color(Color.WHITE if lit else BMStyle.CREAM_D, alpha))
			draw_rect(Rect2(Vector2(bx + 4, by + 4), Vector2(4, 4)), Color(BMStyle.SUN_L if lit else BMStyle.SUN, alpha))
		bx += 24.0
		i += 1
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_text(_label, rm, gone, fade, 0.0)


func _draw_blocks(rm: bool, gone: float, fade: float) -> void:
	var placed: Array = [] ## [center, rot, alpha, color]
	for b in _blocks:
		var li := int(b.letter)
		var a := _appear(_letter_t0(li), DROP_TIME)
		if a <= 0.0:
			continue
		var center: Vector2 = b.base + Vector2(CELL, CELL) / 2.0
		var alpha := a
		var rot := 0.0
		if _burst and not rm:
			center = b.pos
			rot = b.rot
			alpha = gone
		elif _burst:
			alpha = a * (1.0 - fade)
		elif not rm:
			# Drop from above and squash on landing, the title logo's drop-in.
			center.y += -(1.0 - a) * 260.0 + sin(a * PI) * 24.0 + _bob(li)
		if alpha > 0.0:
			placed.append([center, rot, alpha, int(b.color)])
	# Three passes so the blocks of a letter share one ink outline and drop shadow.
	for pass_i in 3:
		for p in placed:
			_draw_one(p[0], p[1], p[2], p[3], pass_i)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## pass 0: drop shadow, 1: ink outline, 2: the block.
func _draw_one(center: Vector2, rot: float, alpha: float, color: int, pass_i: int) -> void:
	draw_set_transform(center, rot, Vector2.ONE)
	var local := Rect2(-Vector2(CELL, CELL) / 2.0, Vector2(CELL, CELL))
	match pass_i:
		0:
			draw_rect(Rect2(local.position + Vector2(0, 8), local.size + Vector2(8, 0)), Color(BMStyle.INK, alpha))
		1:
			draw_rect(local.grow(4), Color(BMStyle.INK, alpha))
		2:
			BMBlockPainter.draw_block(self, local, color, alpha)


## The popped corner block, over a starburst while it hangs in the air.
func _draw_pop(rm: bool, gone: float, fade: float) -> void:
	var li := POPPED.x
	var a := _appear(_letter_t0(li), DROP_TIME)
	if a <= 0.0:
		return
	var center: Vector2
	var rot := 0.0
	var alpha := a
	if _popped:
		center = _pop_block.pos
		rot = _pop_block.rot
		alpha = gone if not rm else 1.0 - fade
		var star := _appear(POP_AT, 0.12) * (1.0 - _appear(POP_AT + 0.5, 0.3)) if not rm else 0.0
		if not _burst and star > 0.0:
			_draw_star(center, CELL * (1.1 + 0.8 * star), star)
	else:
		center = _pop_block.base + Vector2(CELL, CELL) / 2.0
		if not rm:
			center.y += -(1.0 - a) * 260.0 + sin(a * PI) * 24.0 + _bob(li)
	if alpha <= 0.0:
		return
	for pass_i in 3:
		_draw_one(center, rot, alpha, int(_pop_block.color), pass_i)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## POPS: rises from behind the marquee (clipped at the sign), points at BURU while he talks, and
## cheers once the corner block pops. On the burst he tumbles away.
func _draw_pops(rm: bool, gone: float, fade: float) -> void:
	if _pops_tex == null or _t < POPS_AT:
		return
	var a := _appear(POPS_AT, POPS_RISE)
	var talk := int(_t * 10.0) % 2 == 0 and _t < POP_AT + 0.45
	var frame := (5 if talk else 4) if _t < POP_AT else (7 if talk else 6)
	if rm:
		frame = 6
	var src := Rect2(Vector2(frame * POPS_FRAME.x, 0), POPS_FRAME)
	if _burst and not rm and not _pops_fly.is_empty():
		draw_set_transform(_pops_fly.pos, _pops_fly.rot, Vector2.ONE)
		draw_texture_rect_region(_pops_tex, Rect2(-_pops_rect.size / 2.0, _pops_rect.size), src, Color(1, 1, 1, gone))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var alpha := a if not _burst else (a * (1.0 - fade) if rm else gone)
	if rm:
		draw_texture_rect_region(_pops_tex, _pops_rect, src, Color(1, 1, 1, alpha))
		return
	# Rise with an overshoot; only the part above the sign's bottom edge shows.
	var k := 1.0 - pow(1.0 - a, 3.0) + sin(a * PI) * 0.12
	var dst := _pops_rect
	dst.position.y += (1.0 - k) * _pops_rect.size.y
	var limit := _plate.end.y
	var shown := clampf((limit - dst.position.y) / POPS_SCALE, 0.0, POPS_FRAME.y)
	if shown <= 0.0:
		return
	src.size.y = shown
	dst.size.y = shown * POPS_SCALE
	draw_texture_rect_region(_pops_tex, dst, src, Color(1, 1, 1, alpha))


func _draw_star(center: Vector2, radius: float, alpha: float) -> void:
	for layer in [[1.08, BMStyle.INK], [1.0, BMStyle.SUN], [0.66, BMStyle.SUN_L]]:
		var pts := PackedVector2Array()
		for i in 20:
			var r: float = radius * float(layer[0]) * (1.0 if i % 2 == 0 else 0.55)
			var ang := i * PI / 10.0 - PI / 2.0 + 0.12 + _t * 0.6
			pts.append(center + Vector2(cos(ang), sin(ang)) * r)
		draw_colored_polygon(pts, Color(layer[1], alpha))


func _draw_text(line: Array, rm: bool, gone: float, fade: float, dance: float) -> void:
	var f := BMStyle.font_bold
	for l in line:
		var a := _appear(float(l.appear_at), 0.22)
		if a <= 0.0:
			continue
		var pos: Vector2 = l.base
		var sc := 1.0
		var alpha := a * ((gone * gone if line == _label else gone) if not rm else 1.0 - fade)
		if not rm and not _burst:
			pos.y += -(1.0 - a) * 40.0 + sin(_t * 9.0 + pos.x * 0.012) * dance * a
			sc = 0.2 + 0.8 * a + sin(a * PI) * 0.35
		if alpha <= 0.0:
			continue
		var fs: int = l.size
		var col := BMStyle.CREAM
		if line == _made:
			col = BMStyle.SKY_L if int(l.index) >= MADE.length() else BMStyle.CREAM
		var origin := Vector2(-float(l.adv) / 2.0, f.get_ascent(fs) / 2.0 - fs * 0.1)
		var outline := 10 if fs >= 60 else 6
		draw_set_transform(pos, 0.0, Vector2(sc, sc))
		if line == _label:
			draw_char(f, origin + Vector2(0, fs * 0.1), l.ch, fs, Color(BMStyle.PINK, alpha * 0.9))
		else:
			draw_char_outline(f, origin + Vector2(0, fs * 0.08), l.ch, fs, outline, Color(BMStyle.INK, alpha))
			draw_char_outline(f, origin, l.ch, fs, outline, Color(BMStyle.INK, alpha))
		draw_char(f, origin, l.ch, fs, Color(col, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
