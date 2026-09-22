class_name BMMain
extends Control
## App root: owns the current BMRun, routes between title / round / shop screens, persists
## after every successful action, and hosts the pause menu. Screens call `act()`; nothing
## else mutates the run.

var run: BMRun
var settings := {}

var backdrop: BMBackdrop
var title_screen: BMTitleScreen
var game_screen: BMGameScreen
var shop_screen: BMShopScreen
var _pause: Control


func _ready() -> void:
	_register_input_actions()
	settings = BMSaveStore.load_settings()
	BMBlockPainter.show_patterns = settings.block_patterns
	theme = BMUI.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop = BMBackdrop.new()
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
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pause)
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
		_:
			if not game_screen.visible or rebind:
				_show(game_screen)
				game_screen.bind(run)


func _show(screen: Control) -> void:
	for s in [title_screen, game_screen, shop_screen]:
		s.visible = s == screen
		s.process_mode = Node.PROCESS_MODE_INHERIT if s == screen else Node.PROCESS_MODE_DISABLED


# --- Pause and settings --------------------------------------------------------------------

func is_paused() -> bool:
	return _pause.get_child_count() > 0


func show_pause() -> void:
	if is_paused() or run == null:
		return
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var p := BMUI.panel(BMPalette.PANEL, BMPalette.CYAN)
	p.custom_minimum_size.x = 520
	center.add_child(p)
	var v := BMUI.vbox(12)
	p.add_child(v)
	v.add_child(BMUI.label("PAUSED", 40, BMPalette.CYAN))
	v.add_child(BMUI.label("Seed %d   Round %d" % [run.run_seed, run.round_number], 18, BMPalette.TEXT_DIM))
	var resume := BMUI.button("Resume", close_pause, 22)
	v.add_child(resume)
	v.add_child(_toggle("Reduced motion", "reduced_motion"))
	v.add_child(_toggle("Block patterns (color-independent marks)", "block_patterns"))
	v.add_child(BMUI.button("Save and Quit to Title", func() -> void:
		BMSaveStore.save_run(run)
		show_title(), 20))
	var abandon := BMUI.button("Abandon Run...", func() -> void: pass, 20)
	abandon.pressed.connect(func() -> void:
		if abandon.text == "Abandon Run...":
			abandon.text = "Click again to abandon this run"
			abandon.add_theme_color_override("font_color", BMPalette.CORAL)
		else:
			close_pause()
			act({"a": "abandon"})
			game_screen.close_overlay()
			game_screen.bind(run))
	v.add_child(abandon)
	resume.grab_focus.call_deferred()


func _toggle(text: String, key: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = bool(settings[key])
	c.add_theme_font_size_override("font_size", 19)
	c.toggled.connect(func(on: bool) -> void:
		settings[key] = on
		BMSaveStore.save_settings(settings)
		BMBlockPainter.show_patterns = settings.block_patterns
		_apply_motion_setting()
		queue_redraw_all())
	return c


func queue_redraw_all() -> void:
	if game_screen.run != null:
		game_screen.refresh_all()
		for s in game_screen.slots:
			s.queue_redraw()


func close_pause() -> void:
	BMUI.clear_children(_pause)


func _apply_motion_setting() -> void:
	backdrop.animate = not settings.reduced_motion
	backdrop.queue_redraw()


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
