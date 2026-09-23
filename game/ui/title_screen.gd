class_name BMTitleScreen
extends Control
## Title: the BLOCKMANIA logo built from toy blocks that drop in letter by letter and bob,
## drifting pieces behind the menu, and arcade buttons (Continue, New Run with seed, Quit).

const STAGE := Vector2(1920, 1080)
const StatsPanel := preload("res://game/ui/endless_stats_panel.gd")
## Chunky block letters for the logo (original, two-block strokes).
const LETTERS := {
	"B": ["#####.", "##..##", "##..##", "#####.", "##..##", "##..##", "#####."],
	"L": ["##....", "##....", "##....", "##....", "##....", "##....", "######"],
	"O": [".####.", "##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
	"C": [".#####", "##....", "##....", "##....", "##....", "##....", ".#####"],
	"K": ["##..##", "##.##.", "####..", "###...", "####..", "##.##.", "##..##"],
	"M": ["##...##", "###.###", "#######", "##.#.##", "##...##", "##...##", "##...##"],
	"A": [".####.", "##..##", "##..##", "######", "##..##", "##..##", "##..##"],
	"N": ["##..##", "###.##", "######", "##.###", "##..##", "##..##", "##..##"],
	"I": ["######", "..##..", "..##..", "..##..", "..##..", "..##..", "######"],
}
const WORD := "BLOCKMANIA"
const CELL := 22.0

var main: Node
var stage: Control
var _logo: Control
var _drift: Control
var _seed_edit: LineEdit
var _continue: Button
var _new: Button
var _endless_continue: Button
var _highscore_overlay: Control
var _score_rows: Array[Button] = []
var _t := 0.0
var _intro_t := 0.0
var _landed := 0 ## logo letters that have played their landing sound
var _drifters: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage = Control.new()
	stage.size = STAGE
	add_child(stage)
	resized.connect(func() -> void: stage.position = ((size - STAGE) / 2.0).round())

	_drift = Control.new()
	_drift.size = STAGE
	_drift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drift.draw.connect(_draw_drift)
	stage.add_child(_drift)

	_logo = Control.new()
	_logo.position = Vector2(0, 120)
	_logo.size = Vector2(STAGE.x, 260)
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.draw.connect(_draw_logo)
	stage.add_child(_logo)

	var tag := BMStyle.label("a toy-block roguelike of tricks, jokers and one very full board", 30, BMStyle.CREAM, true, 10)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.position = Vector2(0, 372)
	tag.size = Vector2(STAGE.x, 40)
	stage.add_child(tag)

	var menu := BMStyle.vbox(16)
	menu.position = Vector2((STAGE.x - 600) / 2.0, 414)
	menu.size = Vector2(600, 560)
	stage.add_child(menu)
	_continue = BMStyle.button("CONTINUE RUN", func() -> void: main.continue_run(), "mint", 40)
	_continue.custom_minimum_size.y = 92
	menu.add_child(_continue)
	_new = BMStyle.button("NEW RUN", _new_run, "sun", 40)
	_new.custom_minimum_size.y = 92
	menu.add_child(_new)
	var endless := BMStyle.button("ENDLESS", func() -> void: main.start_endless(), "sky", 40)
	endless.icon = BMStyle.infinity_icon()
	endless.add_theme_constant_override("icon_max_width", 68)
	endless.custom_minimum_size.y = 80
	endless.tooltip_text = "Relaxed block placement. Clear rows and columns, build a combo, and chase your best score."
	menu.add_child(endless)
	_endless_continue = BMStyle.button("CONTINUE ENDLESS", func() -> void: main.continue_endless(), "mint", 30)
	_endless_continue.custom_minimum_size.y = 64
	menu.add_child(_endless_continue)
	var scores := BMStyle.button("HIGH SCORES", _show_high_scores, "plum", 30)
	scores.custom_minimum_size.y = 64
	menu.add_child(scores)
	var seed_row := BMStyle.hbox(10)
	menu.add_child(seed_row)
	seed_row.add_child(BMStyle.label("SEED", 30, BMStyle.TEXT_DIM, true, 8))
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "random"
	_seed_edit.custom_minimum_size = Vector2(0, 60)
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_edit.text_submitted.connect(func(_s: String) -> void: _new_run())
	seed_row.add_child(_seed_edit)
	var low := BMStyle.hbox(16)
	menu.add_child(low)
	var options := BMStyle.button("OPTIONS", func() -> void: main.show_options(), "sky", 30)
	options.icon = BMStyle.tex("icon_gear")
	options.alignment = HORIZONTAL_ALIGNMENT_CENTER
	options.add_theme_constant_override("icon_max_width", 32)
	options.custom_minimum_size.y = 72
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	low.add_child(options)
	var quit := BMStyle.button("QUIT", func() -> void: get_tree().quit(), "plum", 30)
	quit.custom_minimum_size.y = 72
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	low.add_child(quit)

	var foot := BMStyle.label("prototype build", 20, BMStyle.TEXT_DIM, false, 6)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.position = Vector2(0, 1020)
	foot.size = Vector2(STAGE.x, 30)
	stage.add_child(foot)
	_seed_drifters()


func refresh() -> void:
	stage.position = ((size - STAGE) / 2.0).round()
	_continue.visible = BMSaveStore.has_run()
	_endless_continue.visible = BMEndlessStore.load_game() != null
	_intro_t = 0.0
	_landed = 0
	focus_default()


func focus_default() -> void:
	BMStyle.focus_later((_continue if _continue.visible else _new))


func _show_high_scores(featured: Dictionary = {}) -> void:
	if is_instance_valid(_highscore_overlay):
		_highscore_overlay.queue_free()
	_score_rows.clear()
	var shade := ColorRect.new()
	shade.color = Color(BMStyle.INK, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_highscore_overlay = shade
	var panel := BMStyle.panel("panel_plate", Vector4(20, 14, 20, 20))
	panel.position = Vector2(190, 100)
	panel.size = Vector2(1540, 880)
	shade.add_child(panel)
	# PanelContainer owns exactly one layout child. All visible widgets live inside it,
	# so the pixel emblem cannot expand across the panel and steal button clicks.
	var body := Control.new()
	panel.add_child(body)
	var emblem := TextureRect.new()
	emblem.texture = BMStyle.infinity_icon()
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_score_widget(body, emblem, Vector2(12, 12), Vector2(68, 36))
	var heading := BMStyle.label("ENDLESS HIGH SCORES", 40, BMStyle.SUN, true, 8)
	_place_score_widget(body, heading, Vector2(92, 4), Vector2(900, 56))
	var entries := BMEndlessStore.high_scores()
	var detail := StatsPanel.new()
	_place_score_widget(body, detail, Vector2(550, 86), Vector2(875, 690))
	if entries.is_empty():
		var empty := BMStyle.label("NO SAVED SCORES YET" if not featured.is_empty() else "NO SCORES YET\nFINISH A GAME TO START", 20, BMStyle.CREAM, true)
		_place_score_widget(body, empty, Vector2(20, 160), Vector2(500, 90))
	else:
		for i in entries.size():
			var item: Dictionary = entries[i]
			var row := BMStyle.button("%02d   %s" % [i + 1, BMUI.fmt_int(int(item.score))],
				func() -> void: _select_score_row(detail, item, i), "plum", 20)
			row.tooltip_text = "%d lines  •  x%d combo  •  %s" % [int(item.get("lines", 0)), int(item.get("combo", 1)), String(item.get("date", ""))]
			_place_score_widget(body, row, Vector2(12, 108 + i * 57), Vector2(505, 52))
			_score_rows.append(row)
	if not featured.is_empty():
		detail.set_entry(featured)
	elif not entries.is_empty():
		_select_score_row(detail, entries[0], 0)
	var back := BMStyle.button("BACK", func() -> void: _close_high_scores(), "sky", 30)
	_place_score_widget(body, back, Vector2(12, 714), Vector2(505, 72))
	BMStyle.focus_later(back)


func _place_score_widget(parent: Control, child: Control, at: Vector2, dimensions: Vector2) -> void:
	child.position = at
	child.size = dimensions
	parent.add_child(child)


func _close_high_scores() -> void:
	if is_instance_valid(_highscore_overlay):
		_highscore_overlay.queue_free()
	_highscore_overlay = null
	_score_rows.clear()
	focus_default()


func _select_score_row(detail: Control, entry: Dictionary, selected: int) -> void:
	for i in _score_rows.size():
		BMStyle.button_boxes(_score_rows[i], "mint" if i == selected else "plum")
	detail.call("set_entry", entry)


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_highscore_overlay) and event.is_action_pressed("bm_cancel"):
		_close_high_scores()
		get_viewport().set_input_as_handled()


func _new_run() -> void:
	var text := _seed_edit.text.strip_edges()
	var seed_value := BMRun.random_seed()
	if text != "":
		seed_value = int(text) if text.is_valid_int() else absi(text.hash())
	_show_kit_picker(seed_value)


## Kit picker: one card per Kit with its rules, a drawing of its starter bag, and (when locked)
## the unlock requirement with progress. Locked Kits say how to earn them; nothing is hidden.
func _show_kit_picker(seed_value: int) -> void:
	if is_instance_valid(_highscore_overlay):
		_highscore_overlay.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(BMStyle.INK, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_highscore_overlay = shade
	var heading := BMStyle.label("CHOOSE YOUR KIT", 60, BMStyle.SUN, true, 14)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.position = Vector2(0, 60)
	heading.size = Vector2(STAGE.x, 90)
	shade.add_child(heading)
	var profile := BMSaveStore.load_profile()
	var first: Button
	var w := 344.0
	var gap := 20.0
	var x0 := (STAGE.x - (w * 5 + gap * 4)) / 2.0
	for i in BMRunConfig.KITS.size():
		var k: Dictionary = BMRunConfig.KITS[i]
		var open := BMRunConfig.kit_unlocked(k.id, profile)
		var card := KitCard.new()
		card.kit = k
		card.unlocked = open
		card.profile = profile
		card.position = Vector2(x0 + i * (w + gap), 180)
		card.size = Vector2(w, 700)
		shade.add_child(card)
		var pick := BMStyle.button("PLAY" if open else "LOCKED", func() -> void:
			if is_instance_valid(_highscore_overlay):
				_highscore_overlay.queue_free()
			_highscore_overlay = null
			main.start_new_run(seed_value, String(k.id)), "sun" if open else "plum", 30)
		pick.disabled = not open
		pick.tooltip_text = String(k.text) if open else "Locked: " + String(k.unlock)
		pick.position = Vector2(x0 + i * (w + gap), 896)
		pick.size = Vector2(w, 80)
		shade.add_child(pick)
		if open and first == null:
			first = pick
	var back := BMStyle.button("BACK", func() -> void: _close_high_scores(), "sky", 30)
	back.position = Vector2((STAGE.x - 300) / 2.0, 990)
	back.size = Vector2(300, 64)
	shade.add_child(back)
	BMStyle.focus_later(first)
	BMAudio.sfx("modal")


## One Kit: name plate, numbers, starter-bag drawing, and lock progress.
class KitCard extends Control:
	var kit: Dictionary
	var unlocked := true
	var profile: Dictionary
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		tooltip_text = String(kit.text)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(BMStyle.box("panel_plate" if unlocked else "panel_inset", Vector4.ZERO), r)
		var f := BMStyle.font_bold
		draw_string(f, Vector2(0, 58), String(kit.name).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, BMStyle.SUN if unlocked else BMStyle.TEXT_DIM)
		var facts := "%d JOKERS  -  %d REFRESH%s" % [int(kit.joker_slots), int(kit.refreshes), "ES" if int(kit.refreshes) != 1 else ""]
		draw_string(f, Vector2(0, 96), facts, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, BMStyle.CREAM)
		var moves := "%d PLACEMENTS" % int(kit.placements)
		if int(kit.credits) > 0:
			moves += "  -  +%d CREDITS" % int(kit.credits)
		draw_string(f, Vector2(0, 124), moves, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, BMStyle.SUN_L if int(kit.credits) > 0 else BMStyle.CREAM)
		# The starter bag, as a little pile of pieces.
		var bag := BMPieces.starter_bag(String(kit.get("bag", "standard")))
		var cell := 12.0
		var x := 24.0
		var y := 150.0
		var row_h := 0.0
		for p in bag:
			var dims := Vector2(BMShapes.shape_size(p))
			if x + dims.x * cell > size.x - 24:
				x = 24.0
				y += row_h + 10.0
				row_h = 0.0
			var bob := 0.0 if not unlocked else roundf(sin(_t * 2.0 + x * 0.05) * 2.0)
			BMBlockPainter.draw_shape(self, p, Vector2(x, y + bob), cell, 1.0 if unlocked else 0.35)
			x += dims.x * cell + 10.0
			row_h = maxf(row_h, dims.y * cell)
		draw_string(f, Vector2(0, y + row_h + 34), "%d PIECES" % bag.size(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, BMStyle.TEXT_DIM)
		# Description, wrapped.
		var lines := _wrap(String(kit.text), size.x - 40)
		var ty := y + row_h + 70
		for l in lines:
			draw_string(BMStyle.font, Vector2(20, ty), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BMStyle.CREAM if unlocked else BMStyle.TEXT_DIM)
			ty += 26
		if not unlocked:
			var lock := BMStyle.tex("icon_lock")
			var ls := lock.get_size() * 2.0
			draw_texture_rect(lock, Rect2(Vector2((size.x - ls.x) / 2.0, size.y - 200), ls), false)
			var ul := _wrap(String(kit.unlock), size.x - 40)
			for i in ul.size():
				draw_string(f, Vector2(0, size.y - 104 + i * 26), ul[i], HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, BMStyle.PINK_L)
			var need: Dictionary = kit.get("need", {})
			for key in need:
				var have := mini(int(profile.get(key, 0)), int(need[key]))
				var bar := Rect2(Vector2(30, size.y - 26), Vector2(size.x - 60, 12))
				draw_rect(bar, BMStyle.INK)
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * have / float(need[key]), bar.size.y)), BMStyle.MINT)
				draw_string(f, Vector2(0, size.y - 36), "%d / %d" % [have, int(need[key])], HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, BMStyle.MINT_L)

	func _wrap(text: String, width: float) -> PackedStringArray:
		var out := PackedStringArray()
		var line := ""
		for word in text.split(" "):
			var trial := word if line == "" else line + " " + word
			if BMStyle.font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > width and line != "":
				out.append(line)
				line = word
			else:
				line = trial
		if line != "":
			out.append(line)
		return out


func _seed_drifters() -> void:
	var fams := [&"l4", &"t4", &"bar3", &"square2", &"zigzag4", &"plus5", &"l3", &"bar4"]
	for i in 14:
		_drifters.append({"shape": BMShapes.make_shape(fams[i % fams.size()], i % 4, i % 6),
			"pos": Vector2(randf_range(0, STAGE.x), randf_range(-200, STAGE.y)),
			"speed": randf_range(18, 46), "cell": randf_range(18, 34), "alpha": randf_range(0.10, 0.22)})


func _process(delta: float) -> void:
	var rm: bool = main != null and main.settings.reduced_motion
	_t += delta if not rm else 0.0
	_intro_t += delta
	# Letters land at the end of their drop (see _draw_logo): li * 0.07 + 0.45 s.
	while _landed < WORD.length() and _intro_t >= _landed * 0.07 + 0.45:
		BMAudio.sfx("letter", BMAudio.scale_pitch(_landed), -3.0)
		_landed += 1
	if not rm:
		for d in _drifters:
			d.pos.y += d.speed * delta
			if d.pos.y > STAGE.y + 120:
				d.pos = Vector2(randf_range(0, STAGE.x), -160)
	_logo.queue_redraw()
	_drift.queue_redraw()


func _draw_drift() -> void:
	for d in _drifters:
		BMBlockPainter.draw_shape(_drift, d.shape, d.pos.round(), d.cell, d.alpha)


func _draw_logo() -> void:
	var rm: bool = main != null and main.settings.reduced_motion
	var widths: Array = []
	var total := 0.0
	for ch in WORD:
		var w: int = LETTERS[ch][0].length()
		widths.append(w)
		total += (w + 1) * CELL
	total -= CELL
	var x := (STAGE.x - total) / 2.0
	var shine := fmod(_t * 0.35, 1.6) - 0.3
	for li in WORD.length():
		var ch := WORD[li]
		var rows: Array = LETTERS[ch]
		var color := li % BMShapes.OFFER_COLOR_COUNT
		var appear := clampf((_intro_t - li * 0.07) / 0.45, 0.0, 1.0)
		var bounce := 0.0
		if appear < 1.0 and not rm:
			bounce = -(1.0 - appear) * 220.0 + sin(appear * PI) * 30.0
		var bob := 0.0 if rm else sin(_t * 2.0 + li * 0.55) * 6.0
		var ox := x
		var oy := 20.0 + bounce + bob
		for ry in rows.size():
			var row: String = rows[ry]
			for rx in row.length():
				if row[rx] != "#":
					continue
				var r := Rect2(Vector2(ox + rx * CELL, oy + ry * CELL).round(), Vector2(CELL, CELL))
				# Chunky ink shadow under the letters.
				_logo.draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(BMStyle.INK, 0.55 * appear))
				BMBlockPainter.draw_block(_logo, r, color, appear)
				var k := (r.position.x / STAGE.x) - shine
				if absf(k) < 0.05 and not rm:
					_logo.draw_rect(r.grow(-4), Color(1, 1, 1, 0.55 * (1.0 - absf(k) / 0.05)))
		x += (widths[li] + 1) * CELL
