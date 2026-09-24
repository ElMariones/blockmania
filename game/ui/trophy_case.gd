class_name BMTrophyCase
extends Control
## The Trophy Case (GDD §20): four pages of twelve achievement badges on lit glass shelves,
## a completion meter with per-tier counts, page tabs and arrows, the personal records plaque
## and hover cards with the rule, flavor text, progress and unlock date. Unlocked badges glint
## (legendary rims shimmer); locked ones are dark with a padlock; secret ones show "?" and a
## cryptic hint until earned. Badges unlocked since the last visit wear a blinking NEW tag.
## Keys: arrows move between badges, Q/E or PageUp/PageDown turn the page, Esc closes.

signal closed

const STAGE := Vector2(1920, 1080)
const CAB := Rect2(170, 236, 1580, 668)
const COLS := 4
const ROWS := 3
const TIER_COLORS := {"bronze": Color("#e08a4a"), "silver": Color("#c8cce4"), "gold": Color("#ffcc3d"), "legend": Color("#d678ff")}

var main: Node
var page := 0
var _cabinet: Cabinet
var _slots_root: Control
var _tabs: Array[Button] = []
var _slots: Array[Slot] = []
var _turning := false


func _ready() -> void:
	size = STAGE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(BMStyle.INK, 0.86)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.size = STAGE
	add_child(shade)
	_build_header()
	_cabinet = Cabinet.new()
	_cabinet.position = CAB.position
	_cabinet.size = CAB.size
	add_child(_cabinet)
	_slots_root = Control.new()
	_slots_root.position = CAB.position
	_slots_root.size = CAB.size
	_slots_root.clip_contents = true
	_slots_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slots_root)
	var prev := BMStyle.button("<", func() -> void: turn(-1), "plum", 40)
	prev.tooltip_text = "Previous page (Q)"
	prev.position = Vector2(40, CAB.position.y + CAB.size.y / 2.0 - 70)
	prev.size = Vector2(100, 140)
	add_child(prev)
	var next := BMStyle.button(">", func() -> void: turn(1), "plum", 40)
	next.tooltip_text = "Next page (E)"
	next.position = Vector2(STAGE.x - 140, CAB.position.y + CAB.size.y / 2.0 - 70)
	next.size = Vector2(100, 140)
	add_child(next)
	_build_records()
	var back := BMStyle.button("BACK", close, "sky", 30)
	back.name = "BackButton"
	back.position = Vector2(1470, 930)
	back.size = Vector2(280, 90)
	add_child(back)
	_show_page(page, 0)
	BMAudio.sfx("trophy_open")
	if not _rm():
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func _rm() -> bool:
	return main != null and bool(main.settings.reduced_motion)


func close() -> void:
	BMAudio.sfx("back")
	closed.emit()
	queue_free()


func _build_header() -> void:
	var title := BMStyle.label("TROPHY CASE", 80, BMStyle.SUN, true, 16)
	title.add_theme_color_override("font_shadow_color", Color(BMStyle.PINK, 0.7))
	title.add_theme_constant_override("shadow_offset_y", 8)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 8)
	title.size = Vector2(STAGE.x, 110)
	add_child(title)
	var total := BMAchievements.CATALOG.size()
	var have := 0
	var per_tier := {}
	for d in BMAchievements.CATALOG:
		var t := String(d.tier)
		if not per_tier.has(t):
			per_tier[t] = [0, 0]
		per_tier[t][1] += 1
		if BMAchievementStore.is_unlocked(d.id):
			have += 1
			per_tier[t][0] += 1
	var meter := Meter.new()
	meter.fraction = float(have) / float(total)
	meter.text = "%d / %d UNLOCKED  -  %d%%" % [have, total, roundi(100.0 * have / total)]
	meter.reduced_motion = _rm()
	meter.position = Vector2(470, 118)
	meter.size = Vector2(620, 40)
	add_child(meter)
	var tiers := BMStyle.hbox(18)
	tiers.position = Vector2(1110, 118)
	tiers.size = Vector2(640, 40)
	add_child(tiers)
	for t in BMAchievements.TIERS:
		var n: Array = per_tier.get(t, [0, 0])
		var l := BMStyle.label("%s %d/%d" % [String(BMAchievements.TIER_NAMES[t]).to_upper(), n[0], n[1]], 20, TIER_COLORS[t], true, 6)
		l.tooltip_text = "%s badges unlocked" % BMAchievements.TIER_NAMES[t]
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		tiers.add_child(l)
	var tabs := BMStyle.hbox(12)
	tabs.position = Vector2(CAB.position.x, 170)
	tabs.size = Vector2(CAB.size.x, 56)
	add_child(tabs)
	for i in BMAchievements.page_count():
		var got := 0
		for id in BMAchievements.page_ids(i):
			if BMAchievementStore.is_unlocked(id):
				got += 1
		var b := BMStyle.button("%s  %d/%d" % [BMAchievements.PAGE_TITLES[i], got, BMAchievements.PER_PAGE], func() -> void:
			if i != page:
				turn(i - page), "plum", 20)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		tabs.add_child(b)
		_tabs.append(b)


func _build_records() -> void:
	var plaque := BMStyle.panel("panel_paper", Vector4(18, 8, 18, 12))
	plaque.position = Vector2(170, 922)
	plaque.size = Vector2(1270, 110)
	add_child(plaque)
	var v := BMStyle.vbox(4)
	plaque.add_child(v)
	var head := BMStyle.label("PERSONAL RECORDS", 20, Color(BMStyle.INK, 0.6), true)
	v.add_child(head)
	var row := BMStyle.hbox(26)
	v.add_child(row)
	var rec := BMAchievementStore.records()
	var broken := int(rec.get("machine_broken", 0))
	var entries := [
		["FURTHEST ROUND", str(int(rec.get("furthest_round", 0))) if int(rec.get("furthest_round", 0)) > 0 else "-"],
		["BEST PLACEMENT", BMUI.fmt_score(int(rec.get("best_placement", 0))) if int(rec.get("best_placement", 0)) > 0 else "-"],
		["BEST ROUND", BMUI.fmt_score(int(rec.get("best_round_score", 0))) if int(rec.get("best_round_score", 0)) > 0 else "-"],
		["THE MACHINE", "BROKEN IN ROUND %d" % broken if broken > 0 else "STILL IN ONE PIECE"],
	]
	for e in entries:
		var col := BMStyle.vbox(0)
		col.add_child(BMStyle.label(e[0], 20, Color(BMStyle.INK, 0.55)))
		var val := BMStyle.label(e[1], 30, Color("#c42848") if e[0] == "THE MACHINE" and broken > 0 else BMStyle.INK, true)
		col.add_child(val)
		row.add_child(col)


# --- Pages -------------------------------------------------------------------------------------

func turn(step: int) -> void:
	if _turning:
		return
	var n := BMAchievements.page_count()
	var to := posmod(page + step, n)
	if to == page:
		return
	BMAudio.sfx("page_flip")
	_show_page(to, signi(step))


func _show_page(to: int, dir: int) -> void:
	page = to
	for i in _tabs.size():
		BMStyle.button_boxes(_tabs[i], "sun" if i == page else "plum")
	var old := _slots_root.get_children()
	var layer := Control.new()
	layer.size = CAB.size
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slots_root.add_child(layer)
	_slots.clear()
	var ids := BMAchievements.page_ids(page)
	var cell := Vector2((CAB.size.x - 60) / COLS, (CAB.size.y - 36) / ROWS)
	for i in ids.size():
		var s := Slot.new()
		s.id = ids[i]
		s.reduced_motion = _rm()
		s.position = Vector2(30 + (i % COLS) * cell.x, 18 + (i / COLS) * cell.y)
		s.size = cell
		layer.add_child(s)
		_slots.append(s)
	_cabinet.lit = []
	for s in _slots:
		_cabinet.lit.append(BMAchievementStore.is_unlocked(s.id))
	_cabinet.queue_redraw()
	BMAchievementStore.mark_seen(ids)
	if dir == 0 or _rm():
		for o in old:
			o.queue_free()
		_focus_first()
		return
	_turning = true
	layer.position.x = CAB.size.x * dir
	var tw := create_tween().set_parallel()
	tw.tween_property(layer, "position:x", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for o in old:
		tw.tween_property(o, "position:x", -CAB.size.x * dir, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void:
		for o in old:
			if is_instance_valid(o):
				o.queue_free()
		_turning = false
		_focus_first())


func _focus_first() -> void:
	if not _slots.is_empty():
		BMStyle.focus_later(_slots[0])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.is_action_pressed("bm_cancel"):
		close()
	elif event.keycode in [KEY_Q, KEY_PAGEUP]:
		turn(-1)
	elif event.keycode in [KEY_E, KEY_PAGEDOWN]:
		turn(1)
	else:
		return
	get_viewport().set_input_as_handled()


# --- Widgets -----------------------------------------------------------------------------------

## The glass cabinet: plum frame, dark glass with slanted reflections, three wooden shelves and a
## warm spotlight behind every unlocked badge.
class Cabinet extends Control:
	var lit: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(BMStyle.box("panel_plate", Vector4.ZERO), r)
		var glass := r.grow(-14)
		draw_rect(glass, Color("#1c1230"))
		# Reflections: two slanted bands of light across the glass.
		for k in [0.18, 0.62]:
			var x0: float = glass.position.x + glass.size.x * k
			for i in 6:
				var pts := PackedVector2Array([Vector2(x0 + i * 10, glass.position.y), Vector2(x0 + i * 10 + 40, glass.position.y),
					Vector2(x0 + i * 10 - 120, glass.end.y), Vector2(x0 + i * 10 - 160, glass.end.y)])
				draw_colored_polygon(pts, Color(1, 1, 1, 0.012))
		var cell := Vector2((size.x - 60) / BMTrophyCase.COLS, (size.y - 36) / BMTrophyCase.ROWS)
		for row in BMTrophyCase.ROWS:
			var y := 18 + (row + 1) * cell.y - 26
			# Spotlights behind the lit badges on this shelf.
			for col in BMTrophyCase.COLS:
				var i := row * BMTrophyCase.COLS + col
				if i < lit.size() and lit[i]:
					var cx := 30 + col * cell.x + cell.x / 2.0
					for ring in 5:
						var rad := 96.0 - ring * 16.0
						draw_circle(Vector2(cx, 18 + row * cell.y + 70), rad, Color(1.0, 0.85, 0.5, 0.025 + ring * 0.012))
			# The shelf: a wooden plank with a lip and a shadow on the glass.
			draw_rect(Rect2(glass.position.x, y + 14, glass.size.x, 10), Color(BMStyle.INK, 0.5))
			draw_rect(Rect2(glass.position.x, y, glass.size.x, 14), Color("#ce7c40"))
			draw_rect(Rect2(glass.position.x, y, glass.size.x, 4), Color("#eea65c"))
			draw_rect(Rect2(glass.position.x, y + 12, glass.size.x, 2), Color("#6c3428"))


## One badge on a shelf: medal, name, and tier or progress. Focusable; hover lifts the medal.
class Slot extends Control:
	var id := ""
	var reduced_motion := false
	var _badge: BMBadge
	var _hover := false
	var _new := false
	var _t := 0.0

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = " "
		var unlocked := BMAchievementStore.is_unlocked(id)
		var secret := BMAchievements.is_secret(id) and not unlocked
		_new = BMAchievementStore.is_new(id)
		var d := BMAchievements.get_def(id)
		_badge = BMBadge.new().setup(id, unlocked, 4.0)
		_badge.position = Vector2((size.x - 96) / 2.0, 4).round()
		_badge.size = Vector2(96, 108)
		add_child(_badge)
		var name_l := BMStyle.label("? ? ?" if secret else String(d.name), 20,
			BMStyle.CREAM if unlocked else BMStyle.TEXT_DIM, true, 6)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_l.position = Vector2(4, 116)
		name_l.size = Vector2(size.x - 8, 28)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(name_l)
		var sub := ""
		var sub_color: Color = BMTrophyCase.TIER_COLORS.get(String(d.tier), BMStyle.CREAM)
		var prog := BMAchievements.progress(id, BMAchievementStore.life(), BMAchievementStore.records(), BMAchievementStore.unlocked_count())
		if unlocked:
			sub = String(BMAchievements.TIER_NAMES[d.tier]).to_upper()
		elif secret:
			sub = "SECRET"
			sub_color = BMStyle.LILAC
		elif not prog.is_empty():
			sub = "%s / %s" % [BMUI.fmt_int(prog[0]), BMUI.fmt_int(prog[1])]
			sub_color = BMStyle.MINT_L
		else:
			sub = "LOCKED  -  %s" % String(BMAchievements.TIER_NAMES[d.tier]).to_upper()
			sub_color = Color(BMStyle.TEXT_DIM, 0.8)
		var sub_l := BMStyle.label(sub, 20, sub_color, true, 6)
		sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_l.position = Vector2(4, 142)
		sub_l.size = Vector2(size.x - 8, 26)
		sub_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sub_l)
		mouse_entered.connect(_set_hover.bind(true))
		mouse_exited.connect(_set_hover.bind(false))
		focus_entered.connect(_set_hover.bind(true))
		focus_exited.connect(_set_hover.bind(false))

	func _set_hover(on: bool) -> void:
		if on == _hover:
			return
		_hover = on
		if on:
			BMAudio.sfx("badge_hover", 1.0 + 0.1 * float(BMAchievements.TIERS.find(_badge.tier())))
		if reduced_motion:
			_badge.lift = 2.0 if on else 0.0
			_badge.queue_redraw()
		else:
			create_tween().tween_property(_badge, "lift", 2.0 if on else 0.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		if _hover and not reduced_motion:
			_badge.queue_redraw()
		if _new:
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventKey and event.pressed and not event.echo and event.is_action("bm_place"))
		if not pressed:
			return
		accept_event()
		if not _badge.unlocked:
			BMAudio.sfx("badge_locked")
			if not reduced_motion:
				var tw := create_tween()
				for k in [6.0, -6.0, 3.0, 0.0]:
					tw.tween_property(_badge, "position:x", (size.x - 96) / 2.0 + k, 0.04)
			return
		# A little celebration when you tap a badge you own: it spins and sparkles.
		BMAudio.sfx("coin", 1.2)
		if BMFx.instance:
			var at := _badge.get_global_rect().get_center()
			BMFx.instance.stars(at, 6, 70, BMTrophyCase.TIER_COLORS.get(_badge.tier(), BMStyle.SUN_L))
		if not reduced_motion:
			var tw := create_tween()
			tw.tween_property(_badge, "spin", 0.05, 0.1)
			tw.tween_property(_badge, "spin", 1.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		if _hover:
			var r := Rect2(Vector2(8, 0), size - Vector2(16, 30))
			draw_rect(r, Color(1, 1, 1, 0.05))
			if has_focus() and BMStyle.is_keyboard_focus_visible():
				draw_rect(r, BMStyle.CREAM, false, 4.0)
		if _new:
			var blink := reduced_motion or fmod(_t, 1.0) < 0.7
			var tag := "NEW!"
			var f := BMStyle.font_bold
			var w := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 16
			var r := Rect2(Vector2(size.x / 2.0 + 30, 2), Vector2(w, 30))
			draw_style_box(BMStyle.box("pill_pink", Vector4.ZERO), r)
			if blink:
				draw_string(f, r.position + Vector2(8, 22), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BMStyle.CREAM)

	func _make_custom_tooltip(_for_text: String) -> Object:
		return BMTrophyCase.hover_card(id)


## Hover card: name, tier, the rule (or the hint for a hidden secret), flavor, progress and date.
static func hover_card(achievement_id: String) -> Control:
	var d := BMAchievements.get_def(achievement_id)
	var unlocked := BMAchievementStore.is_unlocked(achievement_id)
	var secret := bool(d.get("secret", false)) and not unlocked
	var v := BMStyle.vbox(6)
	v.custom_minimum_size = Vector2(460, 0)
	var head := BMStyle.label("? ? ?" if secret else String(d.name), 30, BMStyle.SUN, true, 8)
	v.add_child(head)
	var tier_text := "%s%s" % [String(BMAchievements.TIER_NAMES[d.tier]).to_upper(), "  -  SECRET" if bool(d.get("secret", false)) else ""]
	v.add_child(BMStyle.label(tier_text, 20, TIER_COLORS[d.tier], true, 6))
	var rule := BMStyle.label(("Hint: " + String(d.hint)) if secret else String(d.text), 20, BMStyle.CREAM)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.custom_minimum_size.x = 460
	v.add_child(rule)
	# Joker unlocks (GDD §22.6): the badge says which Jokers it adds to the shop pool.
	var jokers := BMJokers.unlocked_by(achievement_id)
	if not jokers.is_empty() and not secret:
		var names := PackedStringArray()
		for j in jokers:
			names.append(String(BMJokers.get_def(j).name))
		var ul := BMStyle.label("%s Joker%s: %s" % ["Unlocked" if unlocked else "Unlocks", "s" if names.size() > 1 else "", ", ".join(names)], 20, BMStyle.LILAC, true, 4)
		ul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ul.custom_minimum_size.x = 460
		v.add_child(ul)
	if unlocked:
		var flavor := BMStyle.label("\"%s\"" % d.flavor, 20, BMStyle.TEXT_DIM)
		flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		flavor.custom_minimum_size.x = 460
		v.add_child(flavor)
		var when := Time.get_datetime_string_from_unix_time(BMAchievementStore.unlock_time(achievement_id), true)
		v.add_child(BMStyle.label("Unlocked %s" % when.substr(0, 16), 20, BMStyle.MINT_L))
	else:
		var prog := BMAchievements.progress(achievement_id, BMAchievementStore.life(), BMAchievementStore.records(), BMAchievementStore.unlocked_count())
		if not prog.is_empty() and not secret:
			v.add_child(BMStyle.label("Progress: %s / %s" % [BMUI.fmt_int(prog[0]), BMUI.fmt_int(prog[1])], 20, BMStyle.MINT_L))
		v.add_child(BMStyle.label("Locked", 20, BMStyle.PINK_L, true))
	return v


## Completion meter: a toy-block bar that fills on open, with the count printed over it.
class Meter extends Control:
	var fraction := 0.0
	var text := ""
	var reduced_motion := false
	var _shown := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shown = fraction if reduced_motion else 0.0

	func _process(delta: float) -> void:
		if _shown < fraction:
			_shown = minf(fraction, _shown + delta * 0.8)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(BMStyle.box("panel_inset", Vector4.ZERO), r)
		var inner := r.grow(-6)
		var n := 24
		var w := inner.size.x / n
		for i in n:
			if (i + 0.5) / n > _shown:
				break
			var c := BMStyle.MINT if i < n * 0.5 else (BMStyle.SUN if i < n * 0.85 else BMStyle.PINK)
			var b := Rect2(inner.position + Vector2(i * w + 1, 0), Vector2(w - 2, inner.size.y))
			draw_rect(b, c)
			draw_rect(Rect2(b.position, Vector2(b.size.x, 4)), c.lightened(0.35))
		var f := BMStyle.font_bold
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var at := Vector2((size.x - tw) / 2.0, size.y / 2.0 + 8)
		draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 8, BMStyle.INK)
		draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BMStyle.CREAM)
