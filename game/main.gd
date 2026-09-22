class_name BMMain
extends Control
## App root: owns the current BMRun, routes between title / round / shop screens, persists
## after every successful action, and hosts the pause menu. Screens call `act()`; nothing
## else mutates the run. Presentation layers: swirl backdrop (bottom), screens, FX particles,
## pause menu, and the CRT post-process (a CanvasLayer on top).

var run: BMRun
var settings := {}

var backdrop: BMSwirlBackground
var title_screen: BMTitleScreen
var game_screen: BMGameScreen
var shop_screen: BMShopScreen
var fx: BMFx
var crt: BMCrtLayer
var _pause: Control


func _ready() -> void:
	_register_input_actions()
	settings = BMSaveStore.load_settings()
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
	close_pause()
	_show(title_screen)
	title_screen.refresh()
	backdrop.set_mood("title")


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
	match run.phase:
		BMRun.Phase.SHOP:
			if not shop_screen.visible or rebind:
				_show(shop_screen)
				shop_screen.bind(run)
				backdrop.set_mood("shop")
		_:
			if not game_screen.visible or rebind:
				_show(game_screen)
				game_screen.bind(run)


func _show(screen: Control) -> void:
	for s in [title_screen, game_screen, shop_screen]:
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
	if run == null:
		return
	_open_menu(true)


## Settings and controls from the title screen (no run to resume or abandon).
func show_options() -> void:
	_open_menu(false)


func _open_menu(in_run: bool) -> void:
	if is_paused():
		return
	var dim := ColorRect.new()
	dim.color = Color(BMStyle.INK, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var p := BMStyle.panel("panel_plate", Vector4(28, 18, 28, 22))
	p.custom_minimum_size.x = 680
	center.add_child(p)
	var v := BMStyle.vbox(12)
	p.add_child(v)
	var title := BMStyle.label("PAUSED" if in_run else "OPTIONS", 60, BMStyle.SUN, true, 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	if in_run:
		var info := BMStyle.label("Round %d  -  Seed %d" % [run.round_number, run.run_seed], 20, BMStyle.TEXT_DIM, false, 6)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(info)
	v.add_child(_controls_table())
	var resume := BMStyle.button("RESUME" if in_run else "BACK", close_pause, "sun", 30)
	resume.custom_minimum_size.y = 72
	v.add_child(resume)
	v.add_child(_setting_button("CRT SCREEN", "crt", ["soft", "full", "off"]))
	v.add_child(_setting_button("MOTION", "reduced_motion", [false, true], {false: "FULL", true: "REDUCED"}))
	v.add_child(_setting_button("BLOCK PATTERNS", "block_patterns", [false, true], {false: "OFF", true: "ON"}))
	if not in_run:
		BMStyle.focus_later(resume)
		_pop_in(p)
		return
	var save := BMStyle.button("SAVE & QUIT TO TITLE", func() -> void:
		BMSaveStore.save_run(run)
		show_title(), "plum", 20)
	save.custom_minimum_size.y = 60
	v.add_child(save)
	var abandon := BMStyle.button("ABANDON RUN...", func() -> void: pass, "pink", 20)
	abandon.custom_minimum_size.y = 60
	abandon.pressed.connect(func() -> void:
		if abandon.text == "ABANDON RUN...":
			abandon.text = "CLICK AGAIN TO ABANDON"
		else:
			close_pause()
			act({"a": "abandon"})
			game_screen.close_overlay()
			game_screen.bind(run))
	v.add_child(abandon)
	BMStyle.focus_later(resume)
	_pop_in(p)


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
		["ESC", "Pause"],
	]
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
	BMBlockPainter.show_patterns = settings.block_patterns
	crt.set_mode(String(settings.crt))
	_apply_motion_setting()
	if game_screen.run != null:
		game_screen._apply_motion()
		game_screen.refresh_all()


func close_pause() -> void:
	var was_open := is_paused()
	BMUI.clear_children(_pause)
	if was_open and title_screen.visible:
		title_screen.focus_default()


func _apply_motion_setting() -> void:
	backdrop.set_motion(not settings.reduced_motion)
	fx.reduced_motion = settings.reduced_motion


func _unhandled_input(event: InputEvent) -> void:
	if is_paused() and event.is_action_pressed("bm_cancel"):
		close_pause()
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
	}
	for action in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in map[action]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(action, e)
