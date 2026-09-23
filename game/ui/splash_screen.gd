class_name BMSplash
extends Control
## Studio splash shown once at launch, over the title (replaces Godot's boot image, which is
## turned off in the project settings). "by Mario Landáburu" pops in letter by letter in the
## Blockhead font and dances, "made with Godot" slides up under it, then every letter bursts
## into flying, spinning pieces while the ink curtain fades to reveal the title.
## About 2.3 s. Any click, key or pad button skips straight to the burst; a second one ends it.
## Reduced motion: the text fades in and out, with no dancing, bursting or particles.

signal revealing ## the burst starts and the curtain begins to fade
signal finished

const NAME := "Mario Landáburu"
const BY := "by"
const MADE := "made with "
const ENGINE := "Godot"
const LETTER_IN := 0.15 ## first name letter appears
const LETTER_STEP := 0.045
const POP_TIME := 0.25
const MADE_AT := 0.85
const BURST_AT := 1.75
const FADE_TIME := 0.55
const GRAVITY := 1500.0

var main: Node
var _t := 0.0
var _burst := false
var _done := false
var _letters: Array = [] ## {ch, base (Vector2 center), size, color, line, appear_at, [pos, vel, rot, spin]}
var _bits: Array = [] ## burst particles {pos, vel, color, size, life}
var _motes: Array = [] ## slow background blocks
var _landed := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layout()
	resized.connect(_layout)
	for i in 22:
		_motes.append({"pos": Vector2(randf(), randf()), "speed": randf_range(0.02, 0.06),
			"size": randf_range(10.0, 26.0), "color": BMFinishes.HUES[i % 6]})


func _reduced() -> bool:
	return main != null and main.settings.reduced_motion


## Letter centers for the three pieces of text, centered on the screen.
func _layout() -> void:
	if _burst:
		return
	_letters.clear()
	var c := size / 2.0
	_add_line(BY, 40, c + Vector2(0, -120), BMStyle.LILAC, 0, LETTER_IN - 0.08, 0.0)
	_add_line(NAME, 80, c + Vector2(0, -20), Color.WHITE, 1, LETTER_IN, LETTER_STEP)
	_add_line(MADE + ENGINE, 30, c + Vector2(0, 110), BMStyle.CREAM, 2, MADE_AT, 0.012)


func _add_line(text: String, font_size: int, center: Vector2, color: Color, line: int, start: float, step: float) -> void:
	var f := BMStyle.font_bold
	var width := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := center.x - width / 2.0
	var k := 0
	for i in text.length():
		var ch := text[i]
		var adv := f.get_char_size(ch.unicode_at(0), font_size).x
		if ch != " ":
			var col := color
			if line == 1:
				col = BMFinishes.HUES[k % 6].lightened(0.15) # candy colors along the name
			elif line == 2 and i >= MADE.length():
				col = BMStyle.SKY_L # "Godot"
			_letters.append({"ch": ch, "base": Vector2(x + adv / 2.0, center.y), "size": font_size,
				"color": col, "line": line, "appear_at": start + k * step, "adv": adv})
			k += 1
		x += adv


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
	# Landing ticks for the name letters (a quick rising run).
	while _landed < _letters.size() and _t >= float(_letters[_landed].appear_at) + POP_TIME * 0.6 and not _burst:
		if int(_letters[_landed].line) == 1 and not rm:
			BMAudio.sfx("letter", BMAudio.scale_pitch(_landed % 8), -8.0)
		_landed += 1
	if not _burst and _t >= BURST_AT:
		_start_burst()
	if _burst and not rm:
		for l in _letters:
			l.vel.y += GRAVITY * delta
			l.pos += l.vel * delta
			l.rot += l.spin * delta
		for i in range(_bits.size() - 1, -1, -1):
			var b: Dictionary = _bits[i]
			b.vel.y += GRAVITY * 0.6 * delta
			b.pos += b.vel * delta
			b.life -= delta
			if b.life <= 0.0:
				_bits.remove_at(i)
	if not rm:
		for m in _motes:
			m.pos.y = fposmod(m.pos.y - m.speed * delta, 1.0)
	if _t >= BURST_AT + FADE_TIME:
		_finish()
	queue_redraw()


## Every letter flies away from the middle with a spin; each sheds a few colored chips.
func _start_burst() -> void:
	_burst = true
	_t = BURST_AT
	revealing.emit()
	if _reduced():
		return
	BMAudio.sfx("letter_pop", 1.0)
	BMAudio.sfx_later("letter_pop", 0.06, 1.25, -4.0)
	var c := size / 2.0
	for l in _letters:
		var p: Vector2 = l.base + Vector2(0, _dance_y(l))
		var out := (p - c).normalized() if p != c else Vector2.UP
		l.pos = p
		l.vel = out * randf_range(380.0, 820.0) + Vector2(randf_range(-120.0, 120.0), -randf_range(300.0, 650.0))
		l.rot = _dance_rot(l)
		l.spin = randf_range(-10.0, 10.0)
		for j in 5:
			var a := randf() * TAU
			_bits.append({"pos": p, "vel": Vector2(cos(a), sin(a)) * randf_range(200.0, 700.0) + Vector2(0, -200),
				"color": l.color, "size": randf_range(6.0, 12.0), "life": randf_range(0.35, 0.7)})


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()


func _appear(l: Dictionary) -> float:
	return clampf((_t - float(l.appear_at)) / POP_TIME, 0.0, 1.0)


func _dance_y(l: Dictionary) -> float:
	if _reduced():
		return 0.0
	var k := float(l.base.x) * 0.012
	var amp := 9.0 if int(l.line) == 1 else 4.0
	return sin(_t * 9.0 + k) * amp * _appear(l)


func _dance_rot(l: Dictionary) -> float:
	if _reduced() or int(l.line) != 1:
		return 0.0
	return sin(_t * 7.0 + float(l.base.x) * 0.02) * 0.09 * _appear(l)


func _draw() -> void:
	var rm := _reduced()
	var fade := clampf((_t - BURST_AT) / FADE_TIME, 0.0, 1.0) if _burst else 0.0
	# Ink curtain; it fades to reveal the title once the letters burst.
	draw_rect(Rect2(Vector2.ZERO, size), Color(BMStyle.INK, 1.0 - fade))
	var c := size / 2.0
	# Soft stepped glow behind the name (pixel bands, no blur).
	var glow := clampf(_t / 0.5, 0.0, 1.0) * (1.0 - fade)
	for i in 5:
		var w := 1500.0 - i * 220.0
		var h := 420.0 - i * 70.0
		draw_rect(Rect2(c - Vector2(w, h) / 2.0 + Vector2(0, -10), Vector2(w, h)), Color(BMStyle.PLUM, 0.10 * glow))
	if not rm:
		for m in _motes:
			var mp := Vector2(m.pos.x * size.x, m.pos.y * size.y).round()
			draw_rect(Rect2(mp, Vector2(m.size, m.size)), Color(m.color, 0.12 * (1.0 - fade)))
	var f := BMStyle.font_bold
	for l in _letters:
		var a := _appear(l)
		if a <= 0.0:
			continue
		var alpha := a
		var pos: Vector2
		var rot := 0.0
		var sc := 1.0
		if _burst and not rm:
			pos = l.pos
			rot = l.rot
			alpha = 1.0 - clampf((_t - BURST_AT) / (FADE_TIME * 0.9), 0.0, 1.0)
		elif _burst:
			pos = l.base
			alpha = a * (1.0 - fade)
		else:
			pos = l.base + Vector2(0, _dance_y(l))
			rot = _dance_rot(l)
			if not rm:
				# Pop in: drop from above with an overshooting scale.
				pos.y -= (1.0 - a) * 60.0
				sc = 0.2 + 0.8 * a + sin(a * PI) * 0.35
		if alpha <= 0.0:
			continue
		var fs: int = l.size
		var asc := f.get_ascent(fs)
		var origin := Vector2(-float(l.adv) / 2.0, asc / 2.0 - fs * 0.1)
		draw_set_transform(pos, rot, Vector2(sc, sc))
		var outline := 10 if fs >= 60 else 6
		draw_char_outline(f, origin + Vector2(0, fs * 0.08), l.ch, fs, outline, Color(BMStyle.INK, alpha))
		draw_char_outline(f, origin, l.ch, fs, outline, Color(BMStyle.INK, alpha))
		draw_char(f, origin, l.ch, fs, Color(l.color, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for b in _bits:
		draw_rect(Rect2(b.pos - Vector2(b.size, b.size) / 2.0, Vector2(b.size, b.size)), Color(b.color, clampf(b.life / 0.3, 0.0, 1.0)))
	# White flash on the burst.
	if _burst and not rm:
		var flash := 1.0 - clampf((_t - BURST_AT) / 0.18, 0.0, 1.0)
		if flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.35 * flash))
