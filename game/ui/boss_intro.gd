class_name BMBossIntro
extends Control
## Boss round cinematic (GDD §22.11), played before the round intro: letterbox bars slide in
## with scrolling WARNING tape, an alarm, the boss name slams onto the screen (shake, red
## flash), the rule types in, and a Mk II boss gets a stamped plate with sparks. About 2.6 s;
## any click or key skips it. Reduced Motion shows the same card as a fade, with no shake or
## flash. Emits `finished` once. Presentation only.

signal finished

var boss := ""
var mk2 := false
var reduced_motion := false
var _t := 0.0
var _done := false
var _slammed := false
var _stamped := false
var _rule_chars := 0.0
const LENGTH := 2.8


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	grab_focus()
	BMAudio.sfx("boss_alarm")
	if reduced_motion:
		_slam()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
		_finish()
		accept_event()


func _process(delta: float) -> void:
	_t += delta
	if not _slammed and _t >= 0.55:
		_slam()
	if mk2 and not _stamped and _t >= 1.25:
		_stamp()
	if _t >= 0.8:
		_rule_chars += delta * 70.0
	if _t >= LENGTH:
		_finish()
	queue_redraw()


func _slam() -> void:
	_slammed = true
	BMAudio.sfx("boss_slam")
	if reduced_motion:
		return
	if BMFx.instance:
		BMFx.instance.shake(14.0)
		BMFx.instance.burst(size / 2.0, [BMStyle.PINK, BMStyle.PINK_L, BMStyle.CREAM], 40, 700.0, 10.0)
	if BMMoodLayer.instance:
		BMMoodLayer.instance.flash(BMStyle.PINK, 0.9)
	if BMCrtLayer.instance:
		BMCrtLayer.instance.shock(0.9)
	if BMSwirlBackground.instance:
		BMSwirlBackground.instance.pulse(1.0)


func _stamp() -> void:
	_stamped = true
	BMAudio.sfx("mk2_stamp")
	if reduced_motion or BMFx.instance == null:
		return
	var at := size / 2.0 + Vector2(300, -70)
	BMFx.instance.sparks(at, BMStyle.SUN_L, 30)
	BMFx.instance.shake(8.0)


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var k := 1.0 if reduced_motion else clampf(_t / 0.35, 0.0, 1.0)
	var out := 0.0 if reduced_motion else clampf((_t - (LENGTH - 0.3)) / 0.3, 0.0, 1.0)
	var ease_in := 1.0 - pow(1.0 - k, 3.0)
	# Darken the whole screen; letterbox bars with hazard tape slide in.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.04, 0.55 * (1.0 - out)))
	var bar := 150.0 * ease_in * (1.0 - out)
	draw_rect(Rect2(0, 0, w, bar), Color(0.04, 0.01, 0.06))
	draw_rect(Rect2(0, h - bar, w, bar), Color(0.04, 0.01, 0.06))
	var scroll := 0.0 if reduced_motion else fmod(_t * 220.0, 72.0)
	for y0 in [bar - 34.0, h - bar + 6.0]:
		if bar < 40.0:
			continue
		var x := -72.0 - scroll
		while x < w + 72.0:
			var pts := PackedVector2Array([Vector2(x, y0), Vector2(x + 36, y0), Vector2(x + 64, y0 + 28), Vector2(x + 28, y0 + 28)])
			draw_colored_polygon(pts, BMStyle.PINK if not mk2 else BMStyle.SUN)
			x += 72.0
	# WARNING text marching across both bars.
	if bar > 90.0:
		var warn := BMLoc.t("WARNING")
		var what := BMLoc.t("BOSS ROUND") if not mk2 else "MK II"
		var words := "%s   %s   %s   %s   " % [warn, what, warn, what]
		var tile := BMStyle.font_bold.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		var off := 0.0 if reduced_motion else fmod(_t * 160.0, tile)
		for row in [[46.0, 1.0], [h - 88.0, -1.0]]:
			var x0: float = -off * float(row[1]) - tile
			var i := 0
			while x0 + i * tile < w + tile:
				draw_string(BMStyle.font_bold, Vector2(x0 + i * tile, row[0] + 40.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(BMStyle.PINK_L, 0.85 * (1.0 - out)))
				i += 1
	if not _slammed:
		return
	# The boss name: slams from 2.4x down to 1x with a bounce and a hot shadow.
	var ts := _t - 0.55
	var s := 1.0 if reduced_motion else (1.0 + 1.4 * exp(-ts * 9.0) * absf(cos(ts * 10.0)))
	var name := BMBosses.title(boss, false).to_upper()
	var fs := BMUI.fit_size(name, BMStyle.font_bold, 80, w - 120)
	var tw := BMStyle.font_bold.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var jitter := Vector2.ZERO if reduced_motion or ts > 0.4 else Vector2(randf_range(-6, 6), randf_range(-4, 4))
	var c := size / 2.0 + Vector2(0, -40) + jitter
	# A dark band keeps the name and rule readable over any board.
	draw_rect(Rect2(0, size.y / 2.0 - 170, w, 300), Color(0.03, 0.0, 0.05, 0.6 * (1.0 - out)))
	draw_set_transform(c, 0.0, Vector2(s, s))
	draw_string(BMStyle.font_bold, Vector2(-tw / 2.0, 30) + Vector2(0, 10), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(BMStyle.PINK_D, 0.9 * (1.0 - out)))
	draw_string(BMStyle.font_bold, Vector2(-tw / 2.0 - 4, 30), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.9, 1.0, 0.5 * (1.0 - out)))
	draw_string(BMStyle.font_bold, Vector2(-tw / 2.0, 30), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(BMStyle.CREAM, 1.0 - out))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Rule text types in under the name.
	var rule := BMBosses.rule_text(boss, mk2)
	var shown := rule.substr(0, int(_rule_chars)) if not reduced_motion else rule
	var rw := 1100.0
	var rs := 30 if BMUI.wrap_lines(rule, BMStyle.font, 30, rw).size() <= 3 else 20
	if BMUI.wrap_lines(rule, BMStyle.font, rs, rw).size() > 4:
		BMUI.fit_size(rule, BMStyle.font, 20, rw * 4.0) # logged: too long for the band
	draw_multiline_string(BMStyle.font, Vector2(c.x - rw / 2.0, c.y + 90), shown, HORIZONTAL_ALIGNMENT_CENTER, rw, rs, 4, Color(BMStyle.CREAM, 0.95 * (1.0 - out)))
	# Mk II: a riveted metal plate stamped at an angle.
	if mk2 and (_stamped or reduced_motion):
		var st := 1.0 if reduced_motion else maxf(1.0, 3.0 - (_t - 1.25) * 14.0)
		var at := c + Vector2(tw / 2.0 + 60, -120)
		draw_set_transform(at, -0.18, Vector2(st, st))
		var plate := Rect2(-110, -44, 220, 88)
		draw_rect(plate.grow(6), BMStyle.INK)
		draw_rect(plate, BMStyle.SUN_D)
		draw_rect(plate.grow(-6), BMStyle.SUN)
		for p in [Vector2(-96, -30), Vector2(96, -30), Vector2(-96, 30), Vector2(96, 30)]:
			draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), BMStyle.SUN_DD)
		draw_string(BMStyle.font_bold, Vector2(-90, 22), "MK II", HORIZONTAL_ALIGNMENT_CENTER, 180, 60, BMStyle.INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	BMUI.draw_fit(self, BMStyle.font_bold, Vector2(0, h - 20), BMLoc.t("CLICK OR PRESS ANY KEY"), HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color(BMStyle.TEXT_DIM, 0.7 * (1.0 - out)))
