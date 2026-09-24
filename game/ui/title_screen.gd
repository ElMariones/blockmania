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
const DROP_TIME := 0.45 ## a logo letter's drop-in
const POP_AWAY := 2.8 ## seconds a clicked (exploded) letter stays away before it drops back in
const POP_GRAVITY := 2200.0

var main: Node
var stage: Control
var _logo: Control
var _drift: Control
var _seed_edit: LineEdit
var _daily: Button
var _heat := 0
var _continue: Button
var _new: Button
var _trophies: Button
var _highscore_overlay: Control
var _score_rows: Array[Button] = []
var _t := 0.0
var _intro_t := 0.0
var _landed := 0 ## logo letters that have played their landing sound
## Easter egg: click a logo letter and it bursts into its blocks, then drops back in.
var _letter_t0: Array[float] = [] ## _intro_t at which each letter starts its drop
var _pops := {} ## letter index -> {"at": _intro_t of the pop, "pieces": [{pos, vel, rot, spin}]}
var _lands: Array = [] ## [[_intro_t, letter index]] landing sounds still to play after a respawn
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
	_logo.mouse_filter = Control.MOUSE_FILTER_PASS
	_logo.draw.connect(_draw_logo)
	_logo.gui_input.connect(_logo_input)
	stage.add_child(_logo)

	var tag := BMStyle.label("a toy-block roguelike of tricks, jokers and one very full board", 30, BMStyle.CREAM, true, 10)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.position = Vector2(0, 372)
	tag.size = Vector2(STAGE.x, 40)
	stage.add_child(tag)

	# Main menu (GDD §22.10): the campaign first, then the two other ways to play, then the
	# collection, then settings. Seed and Heat live on the Kit screen, where they matter.
	var menu := BMStyle.vbox(16)
	menu.position = Vector2((STAGE.x - 640) / 2.0, 424)
	menu.size = Vector2(640, 560)
	stage.add_child(menu)
	_continue = _menu_button("CONTINUE RUN", func() -> void: main.continue_run(), "mint", 40, BMStyle.tex("icon_play"))
	_continue.custom_minimum_size.y = 92
	menu.add_child(_continue)
	_new = _menu_button("NEW RUN", _new_run, "sun", 40, BMStyle.tex("icon_piece"))
	_new.custom_minimum_size.y = 92
	_new.tooltip_text = "Pick a Kit and a Heat level, then twelve rounds and three bosses."
	menu.add_child(_new)
	var modes := BMStyle.hbox(16)
	menu.add_child(modes)
	_daily = _menu_button("DAILY", _show_daily, "pink", 30, BMStyle.tex("icon_star"), 0.75, 18.0)
	_daily.custom_minimum_size.y = 76
	_daily.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_daily.tooltip_text = "Today's run: the same seed for everyone, Standard Kit, Heat 0."
	modes.add_child(_daily)
	var endless := _menu_button("ENDLESS", _endless_pressed, "sky", 30, BMStyle.infinity_icon(), 0.75, 18.0)
	endless.custom_minimum_size.y = 76
	endless.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	endless.tooltip_text = "Relaxed block placement. Clear rows and columns, build a combo, and chase your best score."
	modes.add_child(endless)
	var boards := BMStyle.hbox(16)
	menu.add_child(boards)
	_trophies = _menu_button("TROPHIES", _show_trophies, "plum", 20, BMStyle.tex("icon_medal"), 0.5, 14.0)
	_trophies.custom_minimum_size.y = 64
	_trophies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boards.add_child(_trophies)
	var history := _menu_button("HISTORY", _show_history, "plum", 20, BMStyle.tex("icon_blueprint"), 0.5, 14.0)
	history.custom_minimum_size.y = 64
	history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history.tooltip_text = "Your last %d campaign runs: Kit, Heat, seed, how far you got and your Jokers." % BMSaveStore.HISTORY_MAX
	boards.add_child(history)
	var scores := _menu_button("SCORES", _show_high_scores, "plum", 20, BMStyle.tex("icon_trophy"), 0.5, 14.0)
	scores.custom_minimum_size.y = 64
	scores.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scores.tooltip_text = "Endless high scores"
	boards.add_child(scores)
	var low := BMStyle.hbox(16)
	menu.add_child(low)
	var options := _menu_button("OPTIONS", func() -> void: main.show_options(), "sky", 30, BMStyle.tex("icon_gear"), 0.75, 18.0)
	options.custom_minimum_size.y = 72
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	low.add_child(options)
	var quit := _menu_button("QUIT", func() -> void: get_tree().quit(), "plum", 30, BMStyle.tex("icon_power"), 0.75, 18.0)
	quit.custom_minimum_size.y = 72
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	low.add_child(quit)

	var foot := BMStyle.label("prototype build", 20, BMStyle.TEXT_DIM, false, 6)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.position = Vector2(0, 1020)
	foot.size = Vector2(STAGE.x, 30)
	stage.add_child(foot)
	_seed_drifters()
	_reset_letters()


## Menu button with its icon pinned to the left edge, so every label is centered on the button
## itself (a Button's own icon would push the text off center). The icon follows the face down
## when the button is pressed.
func _menu_button(text: String, cb: Callable, kind: String, font_size: int, icon_tex: Texture2D, icon_scale := 1.0, margin := 28.0) -> Button:
	var b := BMStyle.button(text, cb, kind, font_size)
	var ic := TextureRect.new()
	ic.texture = icon_tex
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.size = icon_tex.get_size() * icon_scale
	b.add_child(ic)
	var place := func(down: bool) -> void:
		# Vertically centered on the face (4 px above the button's center: the 9-slice has a
		# bottom lip); the pressed face sits 4 px lower.
		ic.position = Vector2(margin, (b.size.y - ic.size.y) / 2.0 - 4.0 + (4.0 if down else 0.0)).round()
	b.button_down.connect(place.bind(true))
	b.button_up.connect(place.bind(false))
	b.resized.connect(place.bind(false))
	return b


func refresh() -> void:
	stage.position = ((size - STAGE) / 2.0).round()
	_continue.visible = BMSaveStore.has_run()
	var profile := BMSaveStore.load_profile()
	var today := Time.get_date_string_from_system()
	var played := String(profile.get("daily_date", "")) == today
	_daily.text = "DAILY  *" if played and int(profile.get("daily_won", 0)) > 0 else "DAILY"
	_daily.tooltip_text = "Today's run: the same seed for everyone, Standard Kit, Heat 0." + \
		("\nToday: %s" % ("won!" if int(profile.get("daily_won", 0)) > 0 else "reached round %d" % int(profile.get("daily_round", 0))) if played else "")
	refresh_trophy_button()
	_intro_t = 0.0
	_landed = 0
	_reset_letters()
	focus_default()


## Keeps the logo hidden and silent (the launch splash is on top); refresh() starts the drop-in.
func hold_intro() -> void:
	_intro_t = -1.0e6


func focus_default() -> void:
	BMStyle.focus_later((_continue if _continue.visible else _new))


## ENDLESS: with a game in progress, a small popup offers Continue or a New Game; otherwise the
## game starts straight away. (A finished game still on disk goes to its game-over screen.)
func _endless_pressed() -> void:
	var saved := BMEndlessStore.load_game()
	if saved == null:
		main.start_endless()
	elif saved.over:
		main.continue_endless()
	else:
		_show_endless_choice(saved)


func _show_endless_choice(saved: BMEndless) -> void:
	if is_instance_valid(_highscore_overlay):
		_highscore_overlay.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(BMStyle.INK, 0.8)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_highscore_overlay = shade
	# Clicking the dimmed area outside the popup closes it, like Esc.
	shade.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_high_scores())
	var panel := BMStyle.panel("panel_plate", Vector4(28, 20, 28, 26))
	shade.add_child(panel)
	var v := BMStyle.vbox(14)
	panel.add_child(v)
	var head := BMStyle.hbox(14)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	var inf := TextureRect.new()
	inf.texture = BMStyle.infinity_icon()
	inf.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	inf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(inf)
	head.add_child(BMStyle.label("ENDLESS", 40, BMStyle.SUN, true, 8))
	v.add_child(head)
	var info := BMStyle.label("You have a game in progress:  %s points." % BMUI.fmt_int(saved.score), 20, BMStyle.CREAM, true, 6)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var cont := _menu_button("CONTINUE", func() -> void:
		_close_high_scores()
		main.continue_endless(), "mint", 30, BMStyle.tex("icon_play"))
	cont.custom_minimum_size = Vector2(460, 72)
	v.add_child(cont)
	var fresh := _menu_button("NEW GAME", func() -> void:
		_close_high_scores()
		main.start_endless(), "sky", 30, BMStyle.tex("icon_piece"))
	fresh.custom_minimum_size = Vector2(460, 72)
	fresh.tooltip_text = "Start over. The game in progress is discarded (it was not finished, so it is not a high score)."
	v.add_child(fresh)
	var note := BMStyle.label("A new game replaces the one in progress.", 20, BMStyle.TEXT_DIM, false, 4)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	var back := BMStyle.button("BACK", func() -> void: _close_high_scores(), "plum", 20)
	back.custom_minimum_size = Vector2(160, 52)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	panel.reset_size()
	panel.position = ((STAGE - panel.size) / 2.0).round()
	BMStyle.focus_later(cont)


## The Trophy Case sits over the title like the other title popups; Esc or BACK closes it.
func _show_trophies() -> void:
	if is_instance_valid(_highscore_overlay):
		_highscore_overlay.queue_free()
	var tc := BMTrophyCase.new()
	tc.main = main
	stage.add_child(tc)
	_highscore_overlay = tc
	tc.closed.connect(func() -> void:
		_highscore_overlay = null
		if main != null:
			main.backdrop.set_mood("title")
		refresh_trophy_button()
		BMStyle.focus_later(_trophies))
	if main != null:
		main.backdrop.set_mood("trophy")


## The TROPHIES button turns mint while badges wait to be seen in the case.
func refresh_trophy_button() -> void:
	var fresh := 0
	for id in BMAchievements.ids():
		if BMAchievementStore.is_new(id):
			fresh += 1
	_trophies.tooltip_text = "Trophy Case: %d of %d achievements, and your personal records.%s" % [
		BMAchievementStore.unlocked_count(), BMAchievements.CATALOG.size(), "\n%d new since your last visit!" % fresh if fresh > 0 else ""]
	BMStyle.button_boxes(_trophies, "mint" if fresh > 0 else "plum")


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
	if _highscore_overlay is BMTrophyCase:
		return
	if is_instance_valid(_highscore_overlay) and event.is_action_pressed("bm_cancel"):
		_close_high_scores()
		get_viewport().set_input_as_handled()


func _new_run() -> void:
	_show_kit_picker()


## The seed typed on the Kit screen, or a random one.
func _picked_seed() -> int:
	var text := _seed_edit.text.strip_edges() if is_instance_valid(_seed_edit) else ""
	if text == "":
		return BMRun.random_seed()
	return int(text) if text.is_valid_int() else absi(text.hash())


## True when the player typed a seed: that run is practice (no achievements or unlocks).
func _seed_is_custom() -> bool:
	return is_instance_valid(_seed_edit) and _seed_edit.text.strip_edges() != ""


func _start_campaign(kit_id: String) -> void:
	var seed_value := _picked_seed()
	var heat := _heat
	if main != null:
		main.settings["last_heat"] = heat
		BMSaveStore.save_settings(main.settings)
	if is_instance_valid(_highscore_overlay):
		_highscore_overlay.queue_free()
	_highscore_overlay = null
	main.start_new_run(seed_value, kit_id, heat, "", _seed_is_custom())


## A warning line when starting would replace the saved campaign run.
func _replace_warning() -> String:
	if not BMSaveStore.has_run():
		return ""
	var saved := BMSaveStore.load_run()
	if saved == null or saved.phase in [BMRun.Phase.RUN_WON, BMRun.Phase.RUN_LOST, BMRun.Phase.ABANDONED]:
		return ""
	return "Starting replaces your saved run (round %d, %s)." % [saved.round_number, String(saved.kit().name)]


## Kit picker: one card per Kit with its rules, perk, and a drawing of its starter bag. A locked
## Kit shows only its name, the unlock requirement and progress: its contents stay a surprise.
## Under the cards: the Heat selector (GDD §22.5) and an optional seed.
func _show_kit_picker(seed_text: String = "") -> void:
	if is_instance_valid(_highscore_overlay):
		_highscore_overlay.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(BMStyle.INK, 0.97)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_highscore_overlay = shade
	var heading := BMStyle.label("CHOOSE YOUR KIT", 60, BMStyle.SUN, true, 14)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.position = Vector2(0, 22)
	heading.size = Vector2(STAGE.x, 84)
	shade.add_child(heading)
	var warn := _replace_warning()
	if warn != "":
		var wl := BMStyle.label(warn, 20, BMStyle.PINK_L, true, 4)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wl.position = Vector2(0, 98)
		wl.size = Vector2(STAGE.x, 30)
		shade.add_child(wl)
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
		card.position = Vector2(x0 + i * (w + gap), 134)
		card.size = Vector2(w, 616)
		shade.add_child(card)
		var pick := BMStyle.button("PLAY" if open else "LOCKED", _start_campaign.bind(String(k.id)), "sun" if open else "plum", 30)
		pick.disabled = not open
		if not open:
			pick.icon = BMStyle.tex("icon_lock")
			pick.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.55))
		pick.tooltip_text = String(k.text) if open else "Locked: " + String(k.unlock)
		pick.position = Vector2(x0 + i * (w + gap), 762)
		pick.size = Vector2(w, 76)
		shade.add_child(pick)
		if open and first == null:
			first = pick
	# Heat and seed bar.
	var body := Panel.new()
	body.add_theme_stylebox_override("panel", BMStyle.box("panel_plate", Vector4.ZERO))
	body.position = Vector2(x0, 852)
	body.size = Vector2(w * 5 + gap * 4, 140)
	shade.add_child(body)
	var avail := BMSaveStore.heat_available()
	_heat = clampi(int(main.settings.get("last_heat", 0)) if main != null else 0, 0, avail)
	var hl := BMStyle.label("HEAT", 30, BMStyle.PINK_L, true, 6)
	hl.position = Vector2(24, 14)
	hl.size = Vector2(120, 50)
	body.add_child(hl)
	var desc := BMStyle.label("", 20, BMStyle.CREAM, false, 4)
	desc.position = Vector2(24, 80)
	desc.size = Vector2(1000, 34)
	desc.clip_text = true
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(desc)
	var heat_buttons: Array[Button] = []
	var sync := func() -> void:
		for h in heat_buttons.size():
			var hb := heat_buttons[h]
			var locked := h > avail
			hb.disabled = locked
			hb.text = "" if locked else str(h)
			hb.icon = BMStyle.tex("icon_lock") if locked else (BMStyle.tex("icon_flame") if h > 0 else null)
			BMStyle.button_boxes(hb, "pink" if h == _heat else "plum")
			hb.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.45))
		var rules := BMRunConfig.heat_rules(_heat)
		desc.text = "Standard rules. Win a run to unlock Heat 1." if _heat == 0 and avail == 0 else 			("Heat 0: standard rules." if _heat == 0 else "Heat %d:  %s" % [_heat, "  -  ".join(rules)])
	for h in BMRunConfig.MAX_HEAT + 1:
		var hb := BMStyle.button(str(h), func() -> void: pass, "plum", 30)
		hb.position = Vector2(150 + h * 104, 10)
		hb.size = Vector2(92, 60)
		hb.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hb.add_theme_constant_override("h_separation", 6)
		hb.tooltip_text = ("Heat %d:  %s" % [h, "  ".join(BMRunConfig.heat_rules(h))]) if h > 0 else "Heat 0: standard rules."
		if h > avail:
			hb.tooltip_text += "\nLocked: win a run at Heat %d first." % (h - 1)
		hb.pressed.connect(func() -> void:
			_heat = h
			sync.call())
		body.add_child(hb)
		heat_buttons.append(hb)
	sync.call()
	var sl := BMStyle.label("SEED", 30, BMStyle.TEXT_DIM, true, 6)
	sl.position = Vector2(1080, 14)
	sl.size = Vector2(110, 50)
	body.add_child(sl)
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "random"
	_seed_edit.text = seed_text
	_seed_edit.position = Vector2(1190, 10)
	_seed_edit.size = Vector2(560, 60)
	_seed_edit.tooltip_text = "Leave empty for a random run. The same seed deals the same pieces, shops and bosses.\nA run on a seed you choose is practice: it earns no achievements, records or unlocks."
	body.add_child(_seed_edit)
	var sd := BMStyle.label("Chosen seeds are practice: no achievements or unlocks.", 20, BMStyle.TEXT_DIM, false, 4)
	sd.position = Vector2(1080, 80)
	sd.size = Vector2(680, 34)
	body.add_child(sd)
	var back := BMStyle.button("BACK", func() -> void: _close_high_scores(), "sky", 20)
	back.position = Vector2((STAGE.x - 260) / 2.0, 1004)
	back.size = Vector2(260, 60)
	shade.add_child(back)
	BMStyle.focus_later(first)
	BMAudio.sfx("modal")


## DAILY: one seed per local date. Standard Kit, Heat 0 and every Joker in the pool, so the
## run is the same for every player that day. Shows today's best result.
func _show_daily() -> void:
	if is_instance_valid(_highscore_overlay):
		_highscore_overlay.queue_free()
	var date := Time.get_date_string_from_system()
	var seed_value := BMRunConfig.daily_seed(date)
	var profile := BMSaveStore.load_profile()
	var shade := _popup_shade()
	var panel := BMStyle.panel("panel_plate", Vector4(32, 20, 32, 26))
	shade.add_child(panel)
	var v := BMStyle.vbox(12)
	panel.add_child(v)
	var head := BMStyle.label("DAILY RUN", 60, BMStyle.PINK_L, true, 12)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var dl := BMStyle.label("%s   -   SEED %d" % [date, seed_value], 30, BMStyle.SUN, true, 6)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(dl)
	for line in ["Standard Kit, Heat 0, every Joker in the pool.",
			"Everyone gets the same pieces, shops and bosses today.",
			"A new Daily starts at midnight."]:
		var l := BMStyle.label(line, 20, BMStyle.CREAM, false, 4)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var best := "Not played yet today."
	if String(profile.get("daily_date", "")) == date:
		best = "Today's best:  WON!" if int(profile.get("daily_won", 0)) > 0 else "Today's best:  reached round %d." % int(profile.get("daily_round", 0))
	var bl := BMStyle.label(best, 30, BMStyle.MINT_L, true, 6)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(bl)
	var warn := _replace_warning()
	if warn != "":
		var wl := BMStyle.label(warn, 20, BMStyle.PINK_L, true, 4)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(wl)
	var play := _menu_button("PLAY TODAY'S RUN", func() -> void:
		_close_high_scores()
		main.start_new_run(seed_value, "standard", 0, date), "pink", 30, BMStyle.tex("icon_play"))
	play.custom_minimum_size = Vector2(620, 80)
	v.add_child(play)
	var back := BMStyle.button("BACK", func() -> void: _close_high_scores(), "plum", 20)
	back.custom_minimum_size = Vector2(200, 56)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	panel.reset_size()
	panel.position = ((STAGE - panel.size) / 2.0).round()
	BMStyle.focus_later(play)
	BMAudio.sfx("modal")


## A dimmed full-stage layer for a title popup; clicking outside the popup closes it.
func _popup_shade() -> ColorRect:
	var shade := ColorRect.new()
	shade.color = Color(BMStyle.INK, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_highscore_overlay = shade
	shade.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_high_scores())
	return shade


## RUN HISTORY: the last campaign runs, newest first. Selecting one shows its Jokers and
## lets the player replay the seed.
func _show_history() -> void:
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
	panel.position = Vector2(150, 90)
	panel.size = Vector2(1620, 900)
	shade.add_child(panel)
	var body := Control.new()
	panel.add_child(body)
	var heading := BMStyle.label("RUN HISTORY", 40, BMStyle.SUN, true, 8)
	_place_score_widget(body, heading, Vector2(12, 4), Vector2(700, 56))
	var list := BMSaveStore.load_history()
	var sub := BMStyle.label("%d runs  -  %d won" % [list.size(), list.filter(func(e: Dictionary) -> bool: return bool(e.get("won", false))).size()], 20, BMStyle.TEXT_DIM, true, 4)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place_score_widget(body, sub, Vector2(700, 16), Vector2(840, 40))
	var detail := HistoryDetail.new()
	detail.title = self
	_place_score_widget(body, detail, Vector2(760, 76), Vector2(790, 730))
	var back := BMStyle.button("BACK", func() -> void: _close_high_scores(), "sky", 30)
	_place_score_widget(body, back, Vector2(12, 790), Vector2(720, 72))
	if list.is_empty():
		var empty := BMStyle.label("NO RUNS YET\nFINISH A CAMPAIGN RUN TO START YOUR HISTORY", 20, BMStyle.CREAM, true)
		_place_score_widget(body, empty, Vector2(20, 120), Vector2(700, 90))
		BMStyle.focus_later(back)
		return
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place_score_widget(body, scroll, Vector2(12, 76), Vector2(730, 700))
	var rows := BMStyle.vbox(6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for i in list.size():
		var e: Dictionary = list[i]
		var row := BMStyle.button("", func() -> void: pass, "plum", 20)
		row.custom_minimum_size = Vector2(700, 52)
		_history_cells(row, e)
		row.pressed.connect(func() -> void:
			for j in _score_rows.size():
				BMStyle.button_boxes(_score_rows[j], "sky" if j == i else "plum")
			detail.set_entry(e))
		rows.add_child(row)
		_score_rows.append(row)
	BMStyle.button_boxes(_score_rows[0], "sky")
	detail.set_entry(list[0])
	BMStyle.focus_later(_score_rows[0])


static func history_result(e: Dictionary) -> String:
	if bool(e.get("broken", false)):
		return "BROKE THE MACHINE"
	if bool(e.get("won", false)):
		var past := int(e.get("round", 12)) - BMRunConfig.ROUND_COUNT
		return "WON  +%d OVERTIME" % past if past > 0 else "WON"
	if String(e.get("reason", "")) == "Run abandoned.":
		return "ABANDONED  R%d" % int(e.get("round", 1))
	return "LOST  ROUND %d" % int(e.get("round", 1))


## A history row's columns: date, Kit, Heat (or DAILY) and the result, at fixed x.
func _history_cells(row: Button, e: Dictionary) -> void:
	var date := Time.get_date_string_from_unix_time(int(e.get("time", 0))).substr(5)
	var kit := String(BMRunConfig.kit(String(e.get("kit", "standard"))).name).replace(" Kit", "").to_upper()
	var tag := "DAILY" if String(e.get("daily", "")) != "" else "HEAT %d" % int(e.get("heat", 0))
	var won := bool(e.get("won", false))
	row.tooltip_text = "%s  -  %s  -  %s  -  seed %d" % [kit, tag, history_result(e), int(e.get("seed", 0))]
	for c in [[date, 18.0, 80.0, BMStyle.TEXT_DIM], [kit, 110.0, 190.0, BMStyle.CREAM], [tag, 310.0, 110.0, BMStyle.PINK_L],
			[history_result(e), 430.0, 260.0, BMStyle.MINT_L if won else BMStyle.CREAM]]:
		var l := BMStyle.label(c[0], 20, c[3], true, 4)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.position = Vector2(c[1], 8)
		l.size = Vector2(c[2], 32)
		l.clip_text = true
		row.add_child(l)


## Replay a history entry's seed: the Kit screen opens with the seed filled in.
func replay_seed(seed_value: int) -> void:
	_show_kit_picker(str(seed_value))


## Right side of RUN HISTORY: the selected run's facts, its Jokers as portraits, and a
## PLAY THIS SEED button.
class HistoryDetail extends Control:
	var title: Node
	var _v: VBoxContainer

	func _ready() -> void:
		var p := BMStyle.panel("panel_inset", Vector4(20, 14, 20, 16))
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(p)
		_v = BMStyle.vbox(10)
		p.add_child(_v)

	func set_entry(e: Dictionary) -> void:
		if _v == null:
			return
		BMUI.clear_children(_v)
		var won := bool(e.get("won", false))
		var res := BMStyle.label(BMTitleScreen.history_result(e), 40, BMStyle.MINT_L if won else BMStyle.PINK_L, true, 8)
		_v.add_child(res)
		var kit := String(BMRunConfig.kit(String(e.get("kit", "standard"))).name)
		var when := Time.get_datetime_string_from_unix_time(int(e.get("time", 0)), true)
		var daily := String(e.get("daily", ""))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 20)
		grid.add_theme_constant_override("v_separation", 6)
		_v.add_child(grid)
		var facts := [["PLAYED", when], ["MODE", ("Daily " + daily) if daily != "" else "%s  -  Heat %d" % [kit, int(e.get("heat", 0))]],
			["SEED", str(int(e.get("seed", 0)))], ["ROUND REACHED", str(int(e.get("round", 1)))],
			["BEST PLACEMENT", BMUI.fmt_score(int(e.get("best", 0)))], ["TOTAL SCORE", BMUI.fmt_score(int(e.get("total", 0)))]]
		for f in facts:
			grid.add_child(BMStyle.label(f[0], 20, BMStyle.TEXT_DIM, true, 4))
			grid.add_child(BMStyle.label(f[1], 20, BMStyle.CREAM, true, 4))
		var jokers: Array = e.get("jokers", [])
		_v.add_child(BMStyle.label("JOKERS  (%d)" % jokers.size(), 20, BMStyle.SUN, true, 4))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		_v.add_child(flow)
		for id in jokers:
			if BMJokers.get_def(String(id)).is_empty():
				continue
			var em := BMCard.Emblem.for_joker(String(id), Vector2(96, 96))
			em.custom_minimum_size = Vector2(96, 96)
			em.tooltip_text = String(BMJokers.get_def(String(id)).name)
			em.mouse_filter = Control.MOUSE_FILTER_PASS
			flow.add_child(em)
		if jokers.is_empty():
			_v.add_child(BMStyle.label("No Jokers at the end of this run.", 20, BMStyle.TEXT_DIM))
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_v.add_child(spacer)
		if daily == "":
			var seed_value := int(e.get("seed", 0))
			var again := BMStyle.button("PLAY THIS SEED", func() -> void: title.replay_seed(seed_value), "sun", 30)
			again.tooltip_text = "Open the Kit screen with this seed filled in."
			again.custom_minimum_size.y = 72
			_v.add_child(again)


## One Kit: name plate, numbers, its signature perk, starter-bag drawing and description.
## A locked Kit keeps its secrets: only its name, a big padlock that wobbles when pointed at,
## a row of mystery pieces, the unlock requirement and its progress.
class KitCard extends Control:
	var kit: Dictionary
	var unlocked := true
	var profile: Dictionary
	var _t := 0.0
	var _hover := false
	var _wobble := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		var perk := String(kit.get("perk", ""))
		tooltip_text = (String(kit.text) + ("\n%s: %s" % [perk, kit.perk_text] if perk != "" else "")) \
			if unlocked else "Locked. " + String(kit.unlock)
		mouse_entered.connect(func() -> void:
			_hover = true
			if not unlocked:
				_wobble = 1.0
				BMAudio.sfx("warden_lock", 1.4, -10.0))
		mouse_exited.connect(func() -> void: _hover = false)

	func _process(delta: float) -> void:
		_t += delta
		_wobble = maxf(0.0, _wobble - delta * 1.6)
		queue_redraw()

	func _reduced() -> bool:
		var m = get_tree().current_scene if is_inside_tree() else null
		return m != null and "settings" in m and bool(m.settings.get("reduced_motion", false))

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(BMStyle.box("panel_plate" if unlocked else "panel_inset", Vector4.ZERO), r)
		var f := BMStyle.font_bold
		draw_string(f, Vector2(0, 58), String(kit.name).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, BMStyle.SUN if unlocked else BMStyle.TEXT_DIM)
		if unlocked:
			_draw_open(f)
		else:
			_draw_locked(f)

	func _draw_open(f: Font) -> void:
		var facts := "%d JOKERS  -  %d REFRESH%s" % [int(kit.joker_slots), int(kit.refreshes), "ES" if int(kit.refreshes) != 1 else ""]
		draw_string(f, Vector2(0, 96), facts, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, BMStyle.CREAM)
		draw_string(f, Vector2(0, 124), "%d PLACEMENTS" % int(kit.placements), HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, BMStyle.CREAM)
		var y := 142.0
		if int(kit.credits) > 0:
			draw_string(f, Vector2(0, 152), "+%d STARTING CREDITS" % int(kit.credits), HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, BMStyle.SUN_L)
			y += 26.0
		# Signature perk on a sun plate.
		if String(kit.get("perk", "")) != "":
			var lines := _wrap(String(kit.perk_text), size.x - 64, BMStyle.font)
			var ph := 84.0 + (lines.size() - 1) * 24.0
			var pr := Rect2(Vector2(16, y), Vector2(size.x - 32, ph))
			draw_style_box(BMStyle.box("panel_sun", Vector4.ZERO), pr)
			draw_string(f, Vector2(pr.position.x, y + 28), String(kit.perk), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 20, BMStyle.INK)
			for i in lines.size():
				draw_string(BMStyle.font, Vector2(pr.position.x, y + 52 + i * 24), lines[i], HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 20, BMStyle.PLUM_D)
			y += ph + 12.0
		else:
			y += 8.0
		# The starter bag, as a little pile of pieces.
		var bag := BMPieces.starter_bag(String(kit.get("bag", "standard")))
		var cell := 11.0
		var x := 24.0
		var row_h := 0.0
		for p in bag:
			var dims := Vector2(BMShapes.shape_size(p))
			if x + dims.x * cell > size.x - 24:
				x = 24.0
				y += row_h + 8.0
				row_h = 0.0
			var bob := 0.0 if _reduced() else roundf(sin(_t * 2.0 + x * 0.05) * 2.0)
			BMBlockPainter.draw_shape(self, p, Vector2(x, y + bob), cell, 1.0)
			x += dims.x * cell + 9.0
			row_h = maxf(row_h, dims.y * cell)
		draw_string(f, Vector2(0, y + row_h + 30), "%d PIECES" % bag.size(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, BMStyle.TEXT_DIM)
		var ty := y + row_h + 64
		for l in _wrap(String(kit.text), size.x - 40, BMStyle.font):
			if ty > size.y - 14:
				break
			draw_string(BMStyle.font, Vector2(20, ty), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BMStyle.CREAM)
			ty += 26

	func _draw_locked(f: Font) -> void:
		draw_string(f, Vector2(0, 96), "? JOKERS  -  ? REFRESHES", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(BMStyle.TEXT_DIM, 0.6))
		draw_string(f, Vector2(0, 124), "? PLACEMENTS", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(BMStyle.TEXT_DIM, 0.6))
		# Mystery pieces: stone blocks with question marks.
		var n := 5
		var cs := 40.0
		var gx := (size.x - (n * cs + (n - 1) * 12.0)) / 2.0
		for i in n:
			var br := Rect2(Vector2(gx + i * (cs + 12.0), 150), Vector2(cs, cs))
			BMBlockPainter.draw_block(self, br, BMShapes.COLOR_STONE, 0.45)
			draw_string(f, br.position + Vector2(0, 30), "?", HORIZONTAL_ALIGNMENT_CENTER, cs, 30, Color(BMStyle.INK, 0.8))
		# The padlock: bobs gently, wobbles when pointed at.
		var lock := BMStyle.tex("icon_padlock")
		var ls := lock.get_size() * 1.5
		var c := Vector2(size.x / 2.0, 314)
		var rm := _reduced()
		var rot := 0.0 if rm else sin(_t * 30.0) * 0.18 * _wobble
		var bob := 0.0 if rm else roundf(sin(_t * 1.8) * 4.0)
		draw_rect(Rect2(c + Vector2(-ls.x * 0.4, ls.y * 0.5 + 6), Vector2(ls.x * 0.8, 10)), Color(BMStyle.INK, 0.5))
		draw_set_transform(c + Vector2(0, bob), rot, Vector2.ONE)
		draw_texture_rect(lock, Rect2(-ls / 2.0, ls), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Requirement, wrapped inside the card with the font it is drawn in.
		var ul := _wrap(String(kit.unlock), size.x - 48, f)
		var ty := 430.0
		draw_string(f, Vector2(0, ty), "TO UNLOCK", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, BMStyle.TEXT_DIM)
		ty += 32
		for l in ul:
			draw_string(f, Vector2(0, ty), l, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, BMStyle.PINK_L)
			ty += 26
		var need: Dictionary = kit.get("need", {})
		for key in need:
			var goal := int(need[key])
			var have := mini(int(profile.get(key, 0)), goal)
			var bar := Rect2(Vector2(24, size.y - 62), Vector2(size.x - 48, 16))
			draw_rect(bar.grow(3), BMStyle.INK)
			draw_rect(bar, BMStyle.PLUM_D)
			draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * have / float(goal)), bar.size.y)), BMStyle.MINT)
			draw_string(f, Vector2(0, size.y - 22), "%d / %d" % [have, goal], HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, BMStyle.MINT_L)

	func _wrap(text: String, width: float, font: Font) -> PackedStringArray:
		var out := PackedStringArray()
		var line := ""
		for word in text.split(" "):
			var trial := word if line == "" else line + " " + word
			if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > width and line != "":
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
	_update_pops(delta, rm)
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


## Left x of each logo letter (stage coordinates) and the total width.
func _letter_xs() -> Array:
	var xs: Array = []
	var total := 0.0
	for ch in WORD:
		total += (String(LETTERS[ch][0]).length() + 1) * CELL
	total -= CELL
	var x := (STAGE.x - total) / 2.0
	for ch in WORD:
		xs.append(x)
		x += (String(LETTERS[ch][0]).length() + 1) * CELL
	return xs


func _letter_bob(li: int) -> float:
	var rm: bool = main != null and main.settings.reduced_motion
	return 0.0 if rm else sin(_t * 2.0 + li * 0.55) * 6.0


func _draw_logo() -> void:
	var rm: bool = main != null and main.settings.reduced_motion
	var xs := _letter_xs()
	var shine := fmod(_t * 0.35, 1.6) - 0.3
	for li in WORD.length():
		var color := li % BMShapes.OFFER_COLOR_COUNT
		if _pops.has(li):
			_draw_pop(li, color)
			continue
		var rows: Array = LETTERS[WORD[li]]
		var appear := clampf((_intro_t - _letter_t0[li]) / DROP_TIME, 0.0, 1.0)
		var bounce := 0.0
		if appear < 1.0 and not rm:
			bounce = -(1.0 - appear) * 220.0 + sin(appear * PI) * 30.0
		var ox: float = xs[li]
		var oy := 20.0 + bounce + _letter_bob(li)
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


# --- Easter egg: exploding logo letters ---------------------------------------------------

func _reset_letters() -> void:
	_letter_t0.clear()
	for li in WORD.length():
		_letter_t0.append(li * 0.07)
	_pops.clear()
	_lands.clear()


## Index of the landed, unexploded letter under a point in logo coordinates, or -1.
func _letter_at(p: Vector2) -> int:
	var xs := _letter_xs()
	for li in WORD.length():
		if _pops.has(li) or _intro_t - _letter_t0[li] < DROP_TIME:
			continue
		var w := String(LETTERS[WORD[li]][0]).length() * CELL
		if Rect2(xs[li] - 4.0, 20.0 + _letter_bob(li) - 4.0, w + 8.0, 7 * CELL + 8.0).has_point(p):
			return li
	return -1


func _logo_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var over := _letter_at(event.position) >= 0
		_logo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var li := _letter_at(event.position)
		if li >= 0:
			_pop_letter(li)
			_logo.accept_event()


## The letter bursts into its blocks, each flying off with a spin and falling under gravity.
## Purely cosmetic: it touches nothing but this screen's drawing.
func _pop_letter(li: int) -> void:
	var rows: Array = LETTERS[WORD[li]]
	var ox: float = _letter_xs()[li]
	var oy := 20.0 + _letter_bob(li)
	var center := Vector2(ox + String(rows[0]).length() * CELL / 2.0, oy + rows.size() * CELL / 2.0)
	var pieces: Array = []
	for ry in rows.size():
		var row: String = rows[ry]
		for rx in row.length():
			if row[rx] != "#":
				continue
			var at := Vector2(ox + (rx + 0.5) * CELL, oy + (ry + 0.5) * CELL)
			var out := (at - center).normalized() if at != center else Vector2.UP
			pieces.append({"pos": at, "rot": 0.0, "spin": randf_range(-9.0, 9.0),
				"vel": out * randf_range(280.0, 620.0) + Vector2(randf_range(-90.0, 90.0), -randf_range(380.0, 720.0))})
	_pops[li] = {"at": _intro_t, "pieces": pieces}
	BMAudio.sfx("letter_pop", BMAudio.scale_pitch(li))
	if _pops.size() == WORD.length() and main != null:
		main.achievement_event("vandal")
	if BMFx.instance:
		var g := _logo.get_global_transform() * center
		var hue: Color = BMFinishes.HUES[li % BMShapes.OFFER_COLOR_COUNT]
		BMFx.instance.burst(g, [hue, hue.lightened(0.35), BMStyle.CREAM], 22, 520.0)
		BMFx.instance.ring(g, hue.lightened(0.3), 110.0)
		BMFx.instance.shake(4.0)


func _update_pops(delta: float, rm: bool) -> void:
	for li in _pops.keys():
		var pop: Dictionary = _pops[li]
		if not rm:
			for pc in pop.pieces:
				pc.vel.y += POP_GRAVITY * delta
				pc.pos += pc.vel * delta
				pc.rot += pc.spin * delta
		if _intro_t - float(pop.at) >= POP_AWAY:
			# Drop the letter back in, with the usual landing click once it lands.
			_pops.erase(li)
			_letter_t0[li] = _intro_t
			_lands.append([_intro_t + DROP_TIME, li])
			BMAudio.sfx("letter_back", BMAudio.scale_pitch(li))
	for i in range(_lands.size() - 1, -1, -1):
		if _intro_t >= float(_lands[i][0]):
			BMAudio.sfx("letter", BMAudio.scale_pitch(int(_lands[i][1])), -3.0)
			_lands.remove_at(i)


func _draw_pop(li: int, color: int) -> void:
	var rm: bool = main != null and main.settings.reduced_motion
	var age := _intro_t - float(_pops[li].at)
	# Reduced motion: the blocks stay put and fade; otherwise they fly and fade late.
	var alpha := clampf(1.0 - age / 0.4, 0.0, 1.0) if rm else clampf((1.4 - age) / 0.5, 0.0, 1.0)
	if alpha <= 0.0:
		return
	for pc in _pops[li].pieces:
		_logo.draw_set_transform(pc.pos, pc.rot, Vector2.ONE)
		BMBlockPainter.draw_block(_logo, Rect2(Vector2(-CELL, -CELL) / 2.0, Vector2(CELL, CELL)), color, alpha)
	_logo.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
