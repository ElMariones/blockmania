class_name BMSettingsMenu
extends Control
## Pause and Options screen (GDD §22.10). One fixed 1920x1080 stage, centered for any aspect:
## a header with the run's context, a rail of tabs on the left (RUN in a campaign, then GAME,
## AUDIO, DISPLAY, ACCESSIBILITY, CONTROLS) with RESUME / SAVE & QUIT / ABANDON under them, and
## the selected page on the right. Every choice is a segmented control that shows all its
## values at once (the selected one lit and marked), with a one-line explanation, and applies
## immediately. Q / E or Page Up / Down switch tabs; Esc closes (handled by BMMain).
## Settings never touch run state: the menu calls BMMain.set_setting, which saves and applies.

const STAGE := Vector2(1920, 1080)
const PANEL := Rect2(170, 60, 1580, 960)
const TABS := ["run", "game", "audio", "display", "access", "controls"]
const TAB_NAMES := {"run": "RUN", "game": "GAME", "audio": "AUDIO", "display": "DISPLAY", # i18n
	"access": "ACCESSIBILITY", "controls": "CONTROLS"}
## The last page opened, so the menu reopens where the player left it.
static var last_tab := "game"

var main: Node
var in_run := false
## "campaign", "shop" or "endless" when paused; "" from the title.
var context := ""
var stage: Control
var _tab := "game"
var _tab_buttons := {}
var _page: VBoxContainer
var _scroll: ScrollContainer
var _refreshers: Array[Callable] = []
var _resume: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(BMStyle.INK, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage = Control.new()
	stage.size = STAGE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	resized.connect(_center)
	_center()
	_build()
	var first := last_tab
	if context == "campaign" or context == "shop":
		first = "run"
	elif first == "run":
		first = "game"
	show_tab(first)
	BMStyle.focus_later(_resume)
	if not bool(main.settings.reduced_motion):
		stage.modulate.a = 0.0
		stage.scale = Vector2(0.96, 0.96)
		stage.pivot_offset = STAGE / 2.0
		var tw := create_tween().set_parallel()
		tw.tween_property(stage, "modulate:a", 1.0, 0.14)
		tw.tween_property(stage, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _center() -> void:
	stage.position = ((size - STAGE) / 2.0).round()


func _place(parent: Control, c: Control, r: Rect2) -> Control:
	c.position = r.position
	c.size = r.size
	parent.add_child(c)
	return c


func _build() -> void:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", BMStyle.box("panel_plate", Vector4.ZERO))
	_place(stage, panel, PANEL)
	var title := BMStyle.label(BMLoc.t("PAUSED") if in_run else BMLoc.t("OPTIONS"), 60, BMStyle.SUN, true, 14)
	_place(panel, title, Rect2(40, 14, 520, 90))
	_build_context(panel)
	var rule := ColorRect.new()
	rule.color = Color(BMStyle.INK, 0.6)
	_place(panel, rule, Rect2(32, 112, PANEL.size.x - 64, 4))
	# Tab rail.
	var y := 136.0
	for id in TABS:
		if id == "run" and context != "campaign" and context != "shop":
			continue
		var b := BMStyle.button(BMLoc.t(TAB_NAMES[id]), show_tab.bind(id), "plum", 30)
		b.name = "Tab_" + id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_place(panel, b, Rect2(32, y, 330, 68))
		_tab_buttons[id] = b
		y += 78.0
	# Run buttons at the bottom of the rail.
	if in_run:
		_resume = BMStyle.button(BMLoc.t("RESUME"), func() -> void: main.close_pause(), "sun", 30)
		_place(panel, _resume, Rect2(32, 692, 330, 80))
		var save := BMStyle.button(BMLoc.t("SAVE & QUIT"), func() -> void: main.save_and_quit(), "plum", 20)
		save.tooltip_text = BMLoc.t("Save and go back to the main menu. CONTINUE picks it up exactly here.") if context != "endless" \
			else BMLoc.t("Save and go back to the main menu. ENDLESS offers to continue this game.")
		_place(panel, save, Rect2(32, 782, 330, 60))
		if context != "endless":
			var abandon := BMStyle.button(BMLoc.t("ABANDON RUN..."), func() -> void: pass, "pink", 20)
			abandon.name = "Abandon"
			abandon.tooltip_text = BMLoc.t("End this run now. It counts as a loss and cannot be continued.")
			abandon.pressed.connect(func() -> void:
				if abandon.text == BMLoc.t("ABANDON RUN..."):
					abandon.text = BMLoc.t("CLICK AGAIN TO ABANDON")
					BMStyle.button_boxes(abandon, "pink")
				else:
					main.abandon_run())
			abandon.focus_exited.connect(func() -> void: abandon.text = BMLoc.t("ABANDON RUN..."))
			_place(panel, abandon, Rect2(32, 852, 330, 60))
	else:
		_resume = BMStyle.button(BMLoc.t("BACK"), func() -> void: main.close_pause(), "sun", 30)
		_place(panel, _resume, Rect2(32, 832, 330, 80))
	# Page area.
	var inset := BMStyle.panel("panel_inset", Vector4(0, 0, 0, 0))
	_place(panel, inset, Rect2(392, 136, 1156, 700))
	var body := Control.new()
	body.clip_contents = true
	inset.add_child(body)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(body, _scroll, Rect2(16, 16, 1124, 668))
	_page = BMStyle.vbox(6)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_page)
	var hint := BMStyle.label(BMLoc.t("Q / E  switch page    ESC  %s") % (BMLoc.t("resume") if in_run else BMLoc.t("back")), 20, BMStyle.TEXT_DIM, false, 4)
	_place(panel, hint, Rect2(400, 858, 700, 40))
	var reset := BMStyle.button(BMLoc.t("RESET PAGE"), _reset_page, "plum", 20)
	reset.name = "ResetPage"
	reset.tooltip_text = BMLoc.t("Put this page's settings back to their defaults.")
	_place(panel, reset, Rect2(1308, 850, 240, 60))
	# A longer translation widens the button leftward (measured once it has the theme's font).
	var reset_w := maxf(240.0, reset.get_combined_minimum_size().x + 24.0)
	reset.position.x = 1548 - reset_w
	reset.size.x = reset_w


## Header context: where the player is and the seed, with a copy button.
func _build_context(panel: Control) -> void:
	var run: BMRun = main.run
	var line1 := ""
	var line2 := ""
	match context:
		"campaign", "shop":
			var where := BMLoc.t("OVERTIME ROUND %d") % run.round_number if run.round_number > BMRunConfig.ROUND_COUNT \
				else BMLoc.t("ROUND %d OF %d  -  ACT %d") % [run.round_number, BMRunConfig.ROUND_COUNT, run.act()]
			if context == "shop":
				where = BMLoc.t("THE TOYBOX, AFTER ROUND %d") % run.round_number
			line1 = where
			var kit := BMLoc.t(run.kit().name).to_upper()
			line2 = (BMLoc.t("DAILY %s") % run.daily) if run.daily != "" else BMLoc.t("%s  -  HEAT %d") % [kit, run.heat]
			if run.custom_seed:
				line2 += BMLoc.t("  -  PRACTICE SEED")
			line2 += BMLoc.t("  -  SEED %d") % run.run_seed
		"endless":
			line1 = BMLoc.t("ENDLESS  -  %s POINTS") % BMUI.fmt_int(main.endless_screen.game.score)
			line2 = BMLoc.t("SEED %d") % main.endless_screen.game.seed
		_:
			line1 = BMLoc.t("SETTINGS ARE SAVED AS YOU CHANGE THEM")
			line2 = ""
	var l1 := BMStyle.label(line1, 30 if context != "" else 20, BMStyle.CREAM if context != "" else BMStyle.TEXT_DIM, true, 6)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var right_edge := PANEL.size.x - 40.0
	var copy_w := 0.0
	if context != "":
		var seed_value: int = run.run_seed if context != "endless" else int(main.endless_screen.game.seed)
		var copy := BMStyle.button(BMLoc.t("COPIED!"), func() -> void: pass, "sky", 20)
		panel.add_child(copy) # in the tree, so the size below uses the theme's font
		copy_w = copy.get_combined_minimum_size().x
		copy.text = BMLoc.t("COPY SEED")
		copy_w = maxf(190.0, maxf(copy_w, copy.get_combined_minimum_size().x) + 24.0)
		panel.remove_child(copy)
		copy.tooltip_text = BMLoc.t("Copy the seed to the clipboard. Type it on the Kit screen to replay this run's draws.")
		copy.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(str(seed_value))
			copy.text = BMLoc.t("COPIED!"))
		_place(panel, copy, Rect2(right_edge - copy_w, 30, copy_w, 60))
		copy_w += 20.0
	_place(panel, l1, Rect2(560, 18, right_edge - copy_w - 560, 44))
	var l2 := BMStyle.label(line2, 20, BMStyle.TEXT_DIM, true, 4)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(panel, l2, Rect2(560, 62, right_edge - copy_w - 560, 34))


func show_tab(id: String) -> void:
	if not _tab_buttons.has(id):
		id = "game"
	var changed := id != _tab
	_tab = id
	if id != "run":
		last_tab = id
	for t in _tab_buttons:
		var b: Button = _tab_buttons[t]
		BMStyle.button_boxes(b, "mint" if t == id else "plum")
		b.text = ("> " if t == id else "") + BMLoc.t(TAB_NAMES[t])
	BMUI.clear_children(_page)
	_refreshers.clear()
	_scroll.scroll_vertical = 0
	match id:
		"run":
			_page_run()
		"game":
			_page_game()
		"audio":
			_page_audio()
		"display":
			_page_display()
		"access":
			_page_access()
		"controls":
			_page_controls()
	var reset := find_child("ResetPage", true, false) as Control
	if reset:
		reset.visible = id in ["game", "audio", "display", "access"]
	if changed and is_inside_tree():
		BMAudio.sfx("tick", 1.1)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.keycode
	var step := 0
	if k == KEY_Q or k == KEY_PAGEUP:
		step = -1
	elif k == KEY_E or k == KEY_PAGEDOWN:
		step = 1
	if step == 0:
		return
	var ids: Array = _tab_buttons.keys()
	var i := ids.find(_tab)
	show_tab(ids[(i + step + ids.size()) % ids.size()])
	BMStyle.focus_later(_tab_buttons[_tab])
	get_viewport().set_input_as_handled()


## Re-reads every visible control from the settings (after the M key, for example).
func refresh_values() -> void:
	for f in _refreshers:
		f.call()


# --- Pages ---------------------------------------------------------------------------------

func _page_game() -> void:
	_language_row()
	_choice(BMLoc.t("Game speed"), BMLoc.t("Speeds up scoring, clears and round animations. Results are identical at every speed."),
		"game_speed", ["normal", "fast", "turbo"], {"normal": BMLoc.t("NORMAL"), "fast": BMLoc.t("FAST"), "turbo": BMLoc.t("TURBO")})
	_choice(BMLoc.t("Tips"), BMLoc.t("A short hint the first time something new shows up: Hold, bosses, round cards, Heat..."),
		"tips", [true, false], {true: BMLoc.t("ON"), false: BMLoc.t("OFF")})
	_action(BMLoc.t("Replay tips"), BMLoc.t("Show every tip again, as if this were your first run."), BMLoc.t("RESET TIPS"), func(b: Button) -> void:
		main.settings.tips_seen = []
		main.settings.tips = true
		BMSaveStore.save_settings(main.settings)
		refresh_values()
		b.text = BMLoc.t("DONE!"))
	_choice(BMLoc.t("Boss intros"), BMLoc.t("CINEMATIC plays the warning, the name slam and the rule. QUICK goes straight to the rule card."),
		"boss_intro", ["cinematic", "quick"], {"cinematic": BMLoc.t("CINEMATIC"), "quick": BMLoc.t("QUICK")})
	_action(BMLoc.t("Tutorial"), BMLoc.t("POPS shows you around again the next time a run starts."), BMLoc.t("REPLAY TUTORIAL"), func(b: Button) -> void:
		if main.tutorial:
			main.tutorial.reset()
		b.text = BMLoc.t("READY!"))
	for btn in _page.get_children().back().find_children("*", "Button", true, false):
		btn.name = "ReplayTutorial"


## Language: every choice shown in its own language (and script), plus SYSTEM, which follows
## the OS. Changing it rebuilds every screen, then this menu reopens on the same page.
func _language_row() -> void:
	var caption := BMLoc.t("Language")
	if BMLoc.current != "en":
		caption += "  (Language)"
	var row := _row(caption, BMLoc.t("Menus, cards and tips. Names like BLOCKMANIA and POPS stay the same."))
	# Twelve buttons with native names: the grid goes under the description, full page width.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	row.desc.get_parent().add_child(gap)
	row.desc.get_parent().add_child(grid)
	var values: Array = ["auto"]
	for entry in BMLoc.LANGUAGES:
		values.append(entry[0])
	var buttons: Array[Button] = []
	for v in values:
		var b := BMStyle.button("", func() -> void: pass, "plum", 20)
		b.name = "Setting_language_%s" % v
		b.custom_minimum_size = Vector2(260, 56)
		b.clip_text = true
		if v != "auto":
			b.add_theme_font_override("font", BMStyle.font_for_language(v, true))
		b.pressed.connect(func() -> void:
			if String(main.settings.get("language", "auto")) != v:
				main.set_language(v))
		grid.add_child(b)
		buttons.append(b)
	# SYSTEM follows the language chosen for the game in Steam, or the computer's without Steam.
	var system_tip := BMLoc.t("Follow the language chosen for BLOCKMANIA in Steam (%s).") if BMSteam.game_language() != "" \
		else BMLoc.t("Follow the computer's language (%s).")
	var sync := func() -> void:
		for i in values.size():
			var on: bool = String(main.settings.get("language", "auto")) == values[i]
			BMStyle.button_boxes(buttons[i], "sun" if on else "plum")
			var n := BMLoc.t("SYSTEM") if values[i] == "auto" else BMLoc.native_name(values[i])
			buttons[i].text = ("* " + n) if on else n
			buttons[i].tooltip_text = (system_tip % BMLoc.native_name(BMLoc.resolve("auto"))) \
				if values[i] == "auto" else BMLoc.native_name(values[i])
	sync.call()
	_refreshers.append(sync)


func _page_audio() -> void:
	_volume(BMLoc.t("Master volume"), BMLoc.t("Everything at once."), "master_volume")
	_volume(BMLoc.t("Music volume"), BMLoc.t("The soundtrack. Each part of the game has its own songs."), "music_volume")
	_volume(BMLoc.t("Effects volume"), BMLoc.t("Clicks, clears, Jokers and fanfares."), "sfx_volume")
	_choice(BMLoc.t("Sound"), BMLoc.t("Turns every sound on or off. M toggles it anywhere."), "muted", [false, true], {false: BMLoc.t("ON"), true: BMLoc.t("OFF")})
	_choice(BMLoc.t("Soundtrack"), BMLoc.t("Keep the effects but switch the songs off."), "music_on", [true, false], {true: BMLoc.t("ON"), false: BMLoc.t("OFF")})
	_choice(BMLoc.t("Danger heartbeat"), BMLoc.t("A soft heartbeat when three or fewer placements are left and the target is not met."),
		"heartbeat", [true, false], {true: BMLoc.t("ON"), false: BMLoc.t("OFF")})
	_choice(BMLoc.t("Mute in background"), BMLoc.t("Silence the game while its window is not focused."), "mute_unfocused", [false, true], {false: BMLoc.t("OFF"), true: BMLoc.t("ON")})
	var row := _row(BMLoc.t("Now playing"), "")
	var now := NowPlaying.new()
	now.custom_minimum_size = Vector2(340, 40)
	row.desc.add_sibling(now)
	row.desc.queue_free()
	var skip := BMStyle.button(BMLoc.t("NEXT SONG  >"), func() -> void: main.audio.skip_track(), "sky", 20)
	skip.tooltip_text = BMLoc.t("Play another song from this part of the game.")
	skip.custom_minimum_size = Vector2(240, 56)
	row.controls.add_child(skip)


func _page_display() -> void:
	_choice(BMLoc.t("Window"), BMLoc.t("Fullscreen uses your desktop resolution. The board always stays square."),
		"fullscreen", [false, true], {false: BMLoc.t("WINDOWED"), true: BMLoc.t("FULLSCREEN")})
	_choice(BMLoc.t("V-Sync"), BMLoc.t("Locks the frame rate to your screen and removes tearing."), "vsync", [true, false], {true: BMLoc.t("ON"), false: BMLoc.t("OFF")})
	_choice(BMLoc.t("CRT filter"), BMLoc.t("Scanlines and a curved-glass glow. SOFT keeps text sharpest."),
		"crt", ["off", "soft", "full"], {"off": BMLoc.t("OFF"), "soft": BMLoc.t("SOFT"), "full": BMLoc.t("FULL")})
	_choice(BMLoc.t("Screen effects"), BMLoc.t("Hazard frame on boss rounds, the danger vignette and heat haze at the screen's edges."),
		"screen_fx", ["off", "soft", "full"], {"off": BMLoc.t("OFF"), "soft": BMLoc.t("SOFT"), "full": BMLoc.t("FULL")})
	_choice(BMLoc.t("FPS counter"), BMLoc.t("Frames per second in the top-left corner."), "show_fps", [false, true], {false: BMLoc.t("OFF"), true: BMLoc.t("ON")})
	_choice(BMLoc.t("Mouse cursor"), BMLoc.t("CUSTOM: a pixel arrow, POPS's glove over buttons and little click sparks. SYSTEM: your normal pointer."),
		"cursor", ["custom", "system"], {"custom": BMLoc.t("CUSTOM"), "system": BMLoc.t("SYSTEM")})


func _page_access() -> void:
	_choice(BMLoc.t("Motion"), BMLoc.t("REDUCED stops background motion, bobbing and fly-ins. Every number and effect is still shown."),
		"reduced_motion", [false, true], {false: BMLoc.t("FULL"), true: BMLoc.t("REDUCED")})
	_choice(BMLoc.t("Screen shake"), BMLoc.t("How hard big clears, slams and bosses shake the screen."),
		"shake", ["off", "low", "full"], {"off": BMLoc.t("OFF"), "low": BMLoc.t("LOW"), "full": BMLoc.t("FULL")})
	_choice(BMLoc.t("Flashes"), BMLoc.t("Bright full-screen flashes and CRT jolts on slams and bosses. OFF removes them all."),
		"flashes", ["off", "soft", "full"], {"off": BMLoc.t("OFF"), "soft": BMLoc.t("SOFT"), "full": BMLoc.t("FULL")})
	_choice(BMLoc.t("Block patterns"), BMLoc.t("Every block color also gets its own pattern, so colors never have to be told apart by hue."),
		"block_patterns", [false, true], {false: BMLoc.t("OFF"), true: BMLoc.t("ON")})
	_choice(BMLoc.t("Boss intros"), BMLoc.t("QUICK skips the flashing warning cinematic before boss rounds."),
		"boss_intro", ["cinematic", "quick"], {"cinematic": BMLoc.t("CINEMATIC"), "quick": BMLoc.t("QUICK")})


func _page_controls() -> void:
	var cols := BMStyle.hbox(24)
	_page.add_child(cols)
	var campaign := [
		[BMLoc.t("MOUSE"), BMLoc.t("Drag a piece, or click it, then a cell")],
		[BMLoc.t("RIGHT CLICK"), BMLoc.t("Put the carried piece back")],
		[BMLoc.t("1  2  3"), BMLoc.t("Pick up a tray piece")],
		[BMLoc.t("ARROWS / WASD"), BMLoc.t("Move the carried piece")],
		[BMLoc.t("ENTER / SPACE"), BMLoc.t("Place it")],
		["H", BMLoc.t("Hold or swap a piece")],
		["R", BMLoc.t("Refresh the tray")],
		["B", BMLoc.t("Open your bag")],
		[BMLoc.t("ALT + UP / DOWN"), BMLoc.t("Move a focused Joker")],
		["M", BMLoc.t("Sound on / off")],
		[BMLoc.t("ESC"), BMLoc.t("Pause, or put a piece back")],
	]
	var endless := [
		[BMLoc.t("MOUSE"), BMLoc.t("Drag a piece, or click it, then a cell")],
		[BMLoc.t("1  2  3"), BMLoc.t("Pick up a tray piece")],
		[BMLoc.t("ARROWS / WASD"), BMLoc.t("Move the carried piece")],
		[BMLoc.t("ENTER / SPACE"), BMLoc.t("Place it")],
		["H", BMLoc.t("Hold or swap the piece")],
		["M", BMLoc.t("Sound on / off")],
		[BMLoc.t("ESC"), BMLoc.t("Pause, or put a piece back")],
	]
	var menus := [[BMLoc.t("TAB / ARROWS"), BMLoc.t("Move between buttons")], [BMLoc.t("ENTER"), BMLoc.t("Press the focused button")],
		[BMLoc.t("Q  E"), BMLoc.t("Switch pages in this menu")], [BMLoc.t("ESC"), BMLoc.t("Close a window")]]
	var left := BMStyle.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	left.add_child(BMStyle.pill(BMLoc.t("CAMPAIGN"), "sun", 20))
	left.add_child(_keys(campaign))
	var right := BMStyle.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(BMStyle.pill(BMLoc.t("ENDLESS"), "sky", 20))
	right.add_child(_keys(endless))
	right.add_child(BMStyle.pill(BMLoc.t("MENUS"), "mint", 20))
	right.add_child(_keys(menus))


func _keys(rows: Array) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	for row in rows:
		var k := BMStyle.label(row[0], 20, BMStyle.SUN, true, 6)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		k.custom_minimum_size.x = 190
		grid.add_child(k)
		var l := BMStyle.label(row[1], 20, BMStyle.CREAM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(l)
	return grid


## RUN: progress through the twelve rounds, the numbers that matter, the act's boss and the
## round card in play. Read-only; everything here is also on the game screen.
func _page_run() -> void:
	var run: BMRun = main.run
	var track := RoundTrack.new()
	track.run = run
	track.custom_minimum_size = Vector2(1080, 128)
	_page.add_child(track)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	_page.add_child(grid)
	var s: Dictionary = run.stats
	var facts := [
		[BMLoc.t("KIT"), BMLoc.t(run.kit().name)],
		[BMLoc.t("HEAT"), "%d  %s" % [run.heat, BMLoc.t("(standard)") if run.heat == 0 else ""]],
		[BMLoc.t("CREDITS"), str(run.credits)],
		[BMLoc.t("JOKERS"), "%d / %d" % [run.jokers.size(), run.joker_slots()]],
		[BMLoc.t("BAG"), BMLoc.tn("%d piece", "%d pieces", run.bag.size()) % run.bag.size()],
		[BMLoc.t("LINES"), BMUI.fmt_int(int(s.get("lines_cleared", 0)))],
		[BMLoc.t("BEST PLACEMENT"), BMUI.fmt_score(int(s.get("best_placement", 0)))],
		[BMLoc.t("BOSSES BEATEN"), str(int(s.get("bosses_beaten", 0)))],
	]
	for f in facts:
		var k := BMStyle.label(f[0], 20, BMStyle.TEXT_DIM, true, 4)
		k.custom_minimum_size.x = 200
		grid.add_child(k)
		var v := BMStyle.label(f[1], 20, BMStyle.CREAM, true, 4)
		v.custom_minimum_size.x = 300
		grid.add_child(v)
	if run.heat > 0:
		_note(BMLoc.t("HEAT %d RULES") % run.heat, "  -  ".join(BMRunConfig.heat_rules(run.heat)), BMStyle.PINK_L)
	var boss_act := clampi(run.act(), 1, run.bosses.size())
	if run.shop != null and run.phase == BMRun.Phase.SHOP and run.round_number % BMRunConfig.ROUNDS_PER_ACT == 0:
		boss_act = clampi(run.act() + 1, 1, run.bosses.size())
	var boss_id: String = run.bosses[boss_act - 1] if boss_act - 1 < run.bosses.size() else ""
	if boss_id != "":
		var mk2 := run.boss_is_mk2(boss_act)
		var at := BMLoc.t("NOW") if run.current_boss() == boss_id else BMLoc.t("ROUND %d") % (boss_act * BMRunConfig.ROUNDS_PER_ACT)
		_note(BMLoc.t("ACT %d BOSS  -  %s  (%s)") % [boss_act, BMBosses.title(boss_id, mk2).to_upper(), at], BMBosses.rule_text(boss_id, mk2), BMStyle.SUN_L)
	if run.round_card != "" and run.round_card != "standard" and run.phase == BMRun.Phase.ROUND:
		var card := BMRoundCards.get_def(run.round_card)
		_note(BMLoc.t("THIS ROUND  -  %s") % BMLoc.t(card.name).to_upper(), BMLoc.t(card.text), BMStyle.MINT_L)


func _note(head: String, text: String, color: Color) -> void:
	var box := BMStyle.panel("panel_plate", Vector4(14, 6, 14, 10))
	_page.add_child(box)
	var v := BMStyle.vbox(2)
	box.add_child(v)
	v.add_child(BMStyle.label(head, 20, color, true, 4))
	var l := BMStyle.label(text, 20, BMStyle.CREAM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)


# --- Rows ----------------------------------------------------------------------------------

## One setting row: name and explanation on the left, controls on the right.
class Row extends PanelContainer:
	var desc: Label
	var controls: HBoxContainer


func _row(caption: String, description: String) -> Row:
	var row := Row.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BMStyle.INK, 0.28 if _page.get_child_count() % 2 == 0 else 0.12)
	sb.content_margin_left = 16
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", sb)
	_page.add_child(row)
	var h := BMStyle.hbox(16)
	row.add_child(h)
	var left := BMStyle.vbox(0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(left)
	left.add_child(BMStyle.label(caption.to_upper(), 30, BMStyle.CREAM, true, 6))
	row.desc = BMStyle.label(description, 20, BMStyle.TEXT_DIM)
	row.desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.desc.custom_minimum_size.x = 420
	left.add_child(row.desc)
	row.controls = BMStyle.hbox(6)
	row.controls.alignment = BoxContainer.ALIGNMENT_END
	row.controls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(row.controls)
	return row


## Segmented control: every value is a button; the current one is lit sun and marked with a
## dot, so the selection never depends on color alone.
func _choice(caption: String, description: String, key: String, values: Array, names: Dictionary) -> void:
	var row := _row(caption, description)
	var buttons: Array[Button] = []
	for v in values:
		var b := BMStyle.button("", func() -> void: pass, "plum", 20)
		b.name = "Setting_%s_%s" % [key, str(v)]
		b.custom_minimum_size = Vector2(maxf(128.0, BMStyle.font_bold.get_string_size(String(names.get(v, str(v))), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 64.0), 56)
		b.pressed.connect(func() -> void: main.set_setting(key, v); refresh_values())
		row.controls.add_child(b)
		buttons.append(b)
	var sync := func() -> void:
		for i in values.size():
			var on: bool = main.settings.get(key) == values[i]
			BMStyle.button_boxes(buttons[i], "sun" if on else "plum")
			var n := String(names.get(values[i], str(values[i])))
			buttons[i].text = ("* " + n) if on else n
	sync.call()
	_refreshers.append(sync)


func _volume(caption: String, description: String, key: String) -> void:
	var row := _row(caption, description)
	var vb := BMVolumeBlocks.new()
	vb.name = "Volume_" + key
	vb.set_value_silently(float(main.settings.get(key, 0.8)))
	vb.changed.connect(func(value: float) -> void:
		main.settings[key] = value
		BMSaveStore.save_settings(main.settings)
		main.audio.apply_settings(main.settings)
		if key != "music_volume":
			BMAudio.sfx("tick", 0.8 + value * 0.6))
	row.controls.add_child(vb)
	_refreshers.append(func() -> void: vb.set_value_silently(float(main.settings.get(key, 0.8))))


func _action(caption: String, description: String, text: String, cb: Callable) -> void:
	var row := _row(caption, description)
	var b := BMStyle.button(text, func() -> void: pass, "sky", 20)
	b.custom_minimum_size = Vector2(240, 56)
	b.pressed.connect(func() -> void: cb.call(b))
	row.controls.add_child(b)


func _reset_page() -> void:
	var d := BMSaveStore.default_settings()
	var keys: Array = {
		"game": ["game_speed", "tips", "boss_intro"],
		"audio": ["master_volume", "music_volume", "sfx_volume", "muted", "music_on", "heartbeat", "mute_unfocused"],
		"display": ["fullscreen", "vsync", "crt", "screen_fx", "show_fps", "cursor"],
		"access": ["reduced_motion", "shake", "flashes", "block_patterns", "boss_intro"],
	}.get(_tab, [])
	for k in keys:
		main.settings[k] = d[k]
	main.set_setting("", null)
	refresh_values()


## "NOW PLAYING  <title>" line; polls the audio node so it never holds a stale signal.
class NowPlaying extends Label:
	func _ready() -> void:
		add_theme_font_override("font", BMStyle.font)
		add_theme_font_size_override("font_size", 20)
		add_theme_color_override("font_color", BMStyle.SUN_L)
		text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		clip_text = true

	func _process(_delta: float) -> void:
		var t := BMAudio.instance.now_playing() if BMAudio.instance else ""
		text = t if t != "" else BMLoc.t("(silence between songs)")


## Twelve round pips; boss rounds are bigger and marked B, the current round is lit and
## labelled NOW. Overtime shows its own count.
class RoundTrack extends Control:
	var run: BMRun

	func _draw() -> void:
		var n := BMRunConfig.ROUND_COUNT
		var f := BMStyle.font_bold
		var x0 := 70.0
		var w := size.x - 2.0 * x0
		var step := w / float(n - 1)
		var y := 58.0
		draw_rect(Rect2(x0, y - 3, w, 6), BMStyle.INK)
		var cur := run.round_number
		var done := cur - 1 if run.phase != BMRun.Phase.SHOP else cur
		draw_rect(Rect2(x0, y - 3, step * clampf(done - 1.0, 0.0, n - 1.0), 6), BMStyle.MINT)
		for i in n:
			var r := i + 1
			var at := Vector2(x0 + i * step, y)
			var boss := BMRunConfig.is_boss_round(r)
			var rad := 22.0 if boss else 15.0
			var col := BMStyle.PLUM_L
			if r <= done:
				col = BMStyle.MINT
			if r == cur and run.phase != BMRun.Phase.SHOP or (run.phase == BMRun.Phase.SHOP and r == cur + 1):
				col = BMStyle.SUN
			var rect := Rect2(at - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
			draw_rect(rect.grow(4), BMStyle.INK)
			draw_rect(rect, BMStyle.PINK if boss and col == BMStyle.PLUM_L else col)
			var label := "B" if boss else str(r)
			var tc := BMStyle.INK if col != BMStyle.PLUM_L or boss else BMStyle.CREAM
			draw_string(f, Vector2(at.x - 30, at.y + 8), label, HORIZONTAL_ALIGNMENT_CENTER, 60, 20, tc)
			# Captions get 200 px centered on their node: nothing else is drawn beside them.
			if col == BMStyle.SUN:
				var now := BMLoc.t("NEXT") if run.phase == BMRun.Phase.SHOP else BMLoc.t("NOW")
				BMUI.draw_fit(self, f, Vector2(at.x - 100, y + 58), now, HORIZONTAL_ALIGNMENT_CENTER, 200, 20, BMStyle.SUN, 200)
			if boss:
				var act := BMLoc.t("ACT %d") % (r / BMRunConfig.ROUNDS_PER_ACT)
				BMUI.draw_fit(self, f, Vector2(at.x - 100, y - 34), act, HORIZONTAL_ALIGNMENT_CENTER, 200, 20, BMStyle.TEXT_DIM, 200)
		if cur > n:
			var ot := BMLoc.t("OVERTIME  -  ROUND %d  (%d PAST THE FINAL BOSS)") % [cur, cur - n]
			BMUI.draw_fit(self, f, Vector2(0, y + 58), ot, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, BMStyle.PINK_L)
