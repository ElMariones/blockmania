class_name BMMain
extends Control
## App root: owns the current BMRun, routes between title / round / shop screens, persists
## after every successful action, and hosts the pause menu. Screens call `act()`; nothing
## else mutates the run. Presentation layers: swirl backdrop (bottom), screens, FX particles,
## pause menu, and the CRT post-process (a CanvasLayer on top). BMAudio plays effects and music.

var run: BMRun
var settings := {}

var backdrop: BMSwirlBackground
var title_screen: BMTitleScreen
var game_screen: BMGameScreen
var shop_screen: BMShopScreen
var endless_screen: BMEndlessScreen
var fx: BMFx
var crt: BMCrtLayer
var audio: BMAudio
var _pause: Control
var _endless_pending_ms := 0.0
var _window_focused := true


func _ready() -> void:
	_register_input_actions()
	settings = BMSaveStore.load_settings()
	audio = BMAudio.new()
	add_child(audio)
	audio.apply_settings(settings)
	BMBlockPainter.show_patterns = settings.block_patterns
	BMStyle.load_fonts()
	theme = BMStyle.make_theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop = BMSwirlBackground.new()
	add_child(backdrop)
	title_screen = BMTitleScreen.new()
	title_screen.main = self
	add_child(title_screen)
	game_screen = BMGameScreen.new()
	game_screen.main = self
	add_child(game_screen)
	shop_screen = BMShopScreen.new()
	shop_screen.main = self
	add_child(shop_screen)
	endless_screen = BMEndlessScreen.new()
	endless_screen.main = self
	add_child(endless_screen)
	fx = BMFx.new()
	add_child(fx)
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pause)
	crt = BMCrtLayer.new()
	crt.mode = String(settings.get("crt", "soft"))
	add_child(crt)
	_apply_motion_setting()
	show_title()


# --- Run lifecycle -------------------------------------------------------------------------

func start_new_run(seed_value: int) -> void:
	run = BMRun.new_run(seed_value)
	BMSaveStore.save_run(run)
	_route(true)


func continue_run() -> void:
	run = BMSaveStore.load_run()
	if run == null:
		show_title()
		return
	_route(true)


func show_title() -> void:
	_flush_endless_time()
	close_pause()
	BMAudio.set_endless_combo(0)
	_show(title_screen)
	title_screen.refresh()
	backdrop.set_mood("title")
	BMAudio.music("title")


func start_endless() -> void:
	_endless_pending_ms = 0.0
	endless_screen.bind(BMEndless.new_game(BMRun.random_seed()))
	BMEndlessStore.record(endless_screen.game)
	_show(endless_screen)
	backdrop.set_mood("endless_calm")
	BMAudio.music("endless_calm")


func continue_endless() -> void:
	var game := BMEndlessStore.load_game()
	if game == null:
		show_title()
		return
	_endless_pending_ms = 0.0
	endless_screen.bind(game)
	_show(endless_screen)
	endless_screen.update_mood()


func endless_act(action: Dictionary) -> Dictionary:
	var command := action.duplicate()
	command["ms"] = int(command.get("ms", 0)) + roundi(_endless_pending_ms)
	var result := endless_screen.game.apply_action(command)
	if result.ok:
		_endless_pending_ms = 0.0
		BMEndlessStore.record(endless_screen.game)
	return result


func _process(delta: float) -> void:
	if endless_screen != null and endless_screen.visible and endless_screen.game != null \
			and not endless_screen.game.over and not is_paused() and not endless_screen.is_style_picker_open() and _window_focused:
		_endless_pending_ms += delta * 1000.0


func _flush_endless_time() -> void:
	if _endless_pending_ms > 0 and endless_screen != null and endless_screen.game != null and not endless_screen.game.over:
		endless_act({"a": "clock"})


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_flush_endless_time()
		_window_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_window_focused = true
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_flush_endless_time()


## The single entry point for player actions. Returns the rules result.
func act(a: Dictionary) -> Dictionary:
	if run == null:
		return {"ok": false, "error": "No run."}
	var before := run.phase
	var r := run.apply_action(a)
	if not r.ok:
		return r
	if run.phase in [BMRun.Phase.RUN_WON, BMRun.Phase.RUN_LOST, BMRun.Phase.ABANDONED]:
		BMSaveStore.clear_run()
	else:
		BMSaveStore.save_run(run)
	_route(before != run.phase and run.phase in [BMRun.Phase.SHOP, BMRun.Phase.RUN_WON])
	return r


func _route(rebind: bool) -> void:
	BMAudio.set_endless_combo(0)
	match run.phase:
		BMRun.Phase.SHOP:
			if not shop_screen.visible or rebind:
				_show(shop_screen)
				shop_screen.bind(run)
				backdrop.set_mood("shop")
			BMAudio.music("shop")
		_:
			if not game_screen.visible or rebind:
				_show(game_screen)
				game_screen.bind(run)
			if run.phase == BMRun.Phase.ROUND:
				BMAudio.music("boss" if run.current_boss() != "" else "round")


func _show(screen: Control) -> void:
	for s in [title_screen, game_screen, shop_screen, endless_screen]:
		s.visible = s == screen
		s.process_mode = Node.PROCESS_MODE_INHERIT if s == screen else Node.PROCESS_MODE_DISABLED
	var st: Variant = screen.get("stage")
	fx.shake_target = st if st is Control else null
	if not settings.reduced_motion and screen != title_screen:
		screen.modulate.a = 0.0
		screen.create_tween().tween_property(screen, "modulate:a", 1.0, 0.25)


# --- Pause and settings --------------------------------------------------------------------

func is_paused() -> bool:
	return _pause.get_child_count() > 0


func show_pause() -> void:
	if run == null and not endless_screen.visible:
		return
	if endless_screen.visible:
		_flush_endless_time()
	_open_menu(true)


## Settings and controls from the title screen (no run to resume or abandon).
func show_options() -> void:
	_open_menu(false)


func _open_menu(in_run: bool) -> void:
	if is_paused():
		return
	BMAudio.sfx("pause_in")
	audio.set_muffled(true)
	var dim := ColorRect.new()
	dim.color = Color(BMStyle.INK, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var p := BMStyle.panel("panel_plate", Vector4(24, 12, 24, 16))
	p.custom_minimum_size.x = 1260
	center.add_child(p)
	var v := BMStyle.vbox(10)
	p.add_child(v)
	var title := BMStyle.label("PAUSED" if in_run else "OPTIONS", 60, BMStyle.SUN, true, 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	if in_run:
		var info_text := "ENDLESS  -  Seed %d" % endless_screen.game.seed if endless_screen.visible else "Round %d  -  Seed %d" % [run.round_number, run.run_seed]
		var info := BMStyle.label(info_text, 20, BMStyle.TEXT_DIM, false, 6)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(info)
	var cols := BMStyle.hbox(28)
	v.add_child(cols)
	# Left: controls and the run buttons.
	var left := BMStyle.vbox(10)
	left.custom_minimum_size.x = 560
	cols.add_child(left)
	left.add_child(BMStyle.pill("CONTROLS", "plum", 20))
	left.add_child(_controls_table())
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	var resume := BMStyle.button("RESUME" if in_run else "BACK", close_pause, "sun", 30)
	resume.custom_minimum_size.y = 72
	left.add_child(resume)
	if in_run:
		var row := BMStyle.hbox(10)
		left.add_child(row)
		var save := BMStyle.button("SAVE & QUIT", func() -> void:
			if endless_screen.visible:
				BMEndlessStore.record(endless_screen.game)
			else:
				BMSaveStore.save_run(run)
			show_title(), "plum", 20)
		save.custom_minimum_size.y = 60
		save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(save)
		var abandon := BMStyle.button("ABANDON RUN...", func() -> void: pass, "pink", 20)
		abandon.visible = not endless_screen.visible
		abandon.custom_minimum_size.y = 60
		abandon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		abandon.pressed.connect(func() -> void:
			if abandon.text == "ABANDON RUN...":
				abandon.text = "CLICK AGAIN"
			else:
				close_pause()
				act({"a": "abandon"})
				game_screen.close_overlay()
				game_screen.bind(run))
		row.add_child(abandon)
	# Right: sound and display settings.
	var right := BMStyle.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(BMStyle.pill("SOUND", "mint", 20))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	right.add_child(grid)
	for row in [["MASTER", "master_volume"], ["MUSIC", "music_volume"], ["EFFECTS", "sfx_volume"]]:
		var l := BMStyle.label(row[0], 20, BMStyle.CREAM, true, 6)
		l.custom_minimum_size.x = 120
		grid.add_child(l)
		grid.add_child(_volume_row(row[1]))
	var toggles := BMStyle.hbox(10)
	right.add_child(toggles)
	for b in [_setting_button("SOUND", "muted", [false, true], {false: "ON", true: "OFF"}),
			_setting_button("MUSIC", "music_on", [true, false], {true: "ON", false: "OFF"})]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggles.add_child(b)
	right.add_child(_setting_button("MUTE IN BACKGROUND", "mute_unfocused", [false, true], {false: "OFF", true: "ON"}))
	var np := BMStyle.hbox(10)
	right.add_child(np)
	var now := NowPlaying.new()
	now.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	np.add_child(now)
	var skip := BMStyle.button("NEXT SONG  >", func() -> void: audio.skip_track(), "plum", 20)
	skip.custom_minimum_size = Vector2(210, 52)
	skip.tooltip_text = "Play another song from this part of the game."
	np.add_child(skip)
	right.add_child(BMStyle.pill("DISPLAY", "sky", 20))
	right.add_child(_setting_button("CRT SCREEN", "crt", ["soft", "full", "off"]))
	var disp := BMStyle.hbox(10)
	right.add_child(disp)
	for b in [_setting_button("MOTION", "reduced_motion", [false, true], {false: "FULL", true: "REDUCED"}),
			_setting_button("PATTERNS", "block_patterns", [false, true], {false: "OFF", true: "ON"})]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		disp.add_child(b)
	BMStyle.focus_later(resume)
	_pop_in(p)


## "NOW PLAYING  <title>" line; polls the audio node so it never holds a stale signal.
class NowPlaying extends Label:
	func _ready() -> void:
		add_theme_font_override("font", BMStyle.font)
		add_theme_font_size_override("font_size", 20)
		add_theme_color_override("font_color", BMStyle.TEXT_DIM)
		text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		clip_text = true

	func _process(_delta: float) -> void:
		var t := BMAudio.instance.now_playing() if BMAudio.instance else ""
		text = "NOW PLAYING  %s" % t if t != "" else "NOW PLAYING  (silence between songs)"


## One volume row: toy-block meter bound to a 0..1 setting, saved on change.
func _volume_row(key: String) -> BMVolumeBlocks:
	var vb := BMVolumeBlocks.new()
	vb.set_value_silently(float(settings.get(key, 0.8)))
	vb.changed.connect(func(value: float) -> void:
		settings[key] = value
		BMSaveStore.save_settings(settings)
		audio.apply_settings(settings)
		# Audible preview of the new level (effects and master only; music is already playing).
		if key != "music_volume":
			BMAudio.sfx("tick", 0.8 + value * 0.6))
	return vb


func _pop_in(p: Control) -> void:
	if not settings.reduced_motion:
		p.scale = Vector2(0.85, 0.85)
		p.resized.connect(func() -> void: p.pivot_offset = p.size / 2.0)
		p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Key / action table for the pause menu. Keys in bold sun, actions in cream.
func _controls_table() -> Control:
	var help := BMStyle.panel("panel_inset", Vector4(8, 2, 8, 4))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	help.add_child(grid)
	var rows := [
		["MOUSE", "Drag a piece, or click it then a cell"],
		["RIGHT / ESC", "Put the held piece back"],
		["1  2  3", "Pick up a piece"],
		["ARROWS", "Move the held piece"],
		["ENTER", "Place it"],
		["R", "Refresh the tray"],
		["B", "Open your bag"],
		["M", "Sound on / off"],
		["ESC", "Pause"],
	]
	if endless_screen.visible:
		rows = [["MOUSE", "Drag a piece, or click it then a cell"],
			["1  2  3", "Pick up a piece"], ["ARROWS", "Move the held piece"],
			["ENTER", "Place it"], ["H", "Hold or swap selected piece"],
			["ESC", "Pause or return a piece"],
			["ALT+UP/DOWN", "Move a focused Joker (campaign only)"], ["M", "Sound on / off"]]
	for row in rows:
		var k := BMStyle.label(row[0], 20, BMStyle.SUN, true, 6)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(k)
		var l := BMStyle.label(row[1], 20, BMStyle.CREAM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(l)
	return help


## A button that cycles a setting through `values`, labelled "NAME: VALUE".
func _setting_button(caption: String, key: String, values: Array, names: Dictionary = {}) -> Button:
	var b := BMStyle.button("", func() -> void: pass, "sky", 20)
	b.name = "Setting_%s" % key
	b.custom_minimum_size.y = 60
	var show_value := func() -> void:
		var v: Variant = settings[key]
		b.text = "%s:  %s" % [caption, String(names.get(v, str(v))).to_upper()]
	show_value.call()
	b.pressed.connect(func() -> void:
		var i := values.find(settings[key])
		settings[key] = values[(i + 1) % values.size()]
		BMSaveStore.save_settings(settings)
		_apply_settings()
		show_value.call())
	return b


func _apply_settings() -> void:
	audio.apply_settings(settings)
	BMBlockPainter.show_patterns = settings.block_patterns
	crt.set_mode(String(settings.crt))
	_apply_motion_setting()
	if game_screen.run != null:
		game_screen._apply_motion()
		game_screen.refresh_all()
	if endless_screen.game != null:
		endless_screen.apply_settings()


func close_pause() -> void:
	var was_open := is_paused()
	BMUI.clear_children(_pause)
	if was_open:
		BMAudio.sfx("pause_out")
		audio.set_muffled(false)
	if was_open and title_screen.visible:
		title_screen.focus_default()
	elif was_open and endless_screen.visible:
		endless_screen.focus_default()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		BMStyle.set_keyboard_focus_visible(true)
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		BMStyle.set_keyboard_focus_visible(false)


func _apply_motion_setting() -> void:
	backdrop.set_motion(not settings.reduced_motion)
	fx.reduced_motion = settings.reduced_motion


func _unhandled_input(event: InputEvent) -> void:
	if is_paused() and event.is_action_pressed("bm_cancel"):
		close_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("bm_mute"):
		settings.muted = not bool(settings.muted)
		BMSaveStore.save_settings(settings)
		audio.apply_settings(settings)
		var sound_button := _pause.find_child("Setting_muted", true, false) as Button
		if sound_button:
			sound_button.text = "SOUND:  OFF" if settings.muted else "SOUND:  ON"
		fx.pop_text(Vector2(size.x / 2.0, 90), "SOUND OFF  (M)" if settings.muted else "SOUND ON  (M)", BMStyle.CREAM, 30, 30.0, 1.2)
		get_viewport().set_input_as_handled()


# --- Input map -----------------------------------------------------------------------------

## Semantic actions registered at startup so they can be remapped later from settings.
func _register_input_actions() -> void:
	var map := {
		"bm_slot_1": [KEY_1, KEY_KP_1],
		"bm_slot_2": [KEY_2, KEY_KP_2],
		"bm_slot_3": [KEY_3, KEY_KP_3],
		"bm_left": [KEY_LEFT, KEY_A],
		"bm_right": [KEY_RIGHT, KEY_D],
		"bm_up": [KEY_UP, KEY_W],
		"bm_down": [KEY_DOWN, KEY_S],
		"bm_place": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE],
		"bm_refresh": [KEY_R],
		"bm_cancel": [KEY_ESCAPE],
		"bm_bag": [KEY_B],
		"bm_hold": [KEY_H],
		"bm_mute": [KEY_M],
	}
	for action in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in map[action]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(action, e)
