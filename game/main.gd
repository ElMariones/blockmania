class_name BMMain
extends Control
## App root: owns the current BMRun, routes between title / round / shop screens, persists
## after every successful action, and hosts the pause menu. Screens call `act()`; nothing
## else mutates the run. Presentation layers: swirl backdrop (bottom), screens, FX particles,
## pause menu, and the CRT post-process (a CanvasLayer on top). BMAudio plays effects and music.

## Screen-edge atmosphere over every screen (boss tape, danger vignette, heat, flashes).
var mood: BMMoodLayer
var run: BMRun
var settings := {}

var backdrop: BMSwirlBackground
var title_screen: BMTitleScreen
var game_screen: BMGameScreen
var shop_screen: BMShopScreen
var endless_screen: BMEndlessScreen
var fx: BMFx
var toasts: BMAchievementToasts
## News from the run that just ended (Kits unlocked, records beaten), read once by the run-end
## screen: {"kits": [...], "records": [...]}.
var run_end_news := {}
var crt: BMCrtLayer
var cursor: BMCursor
var audio: BMAudio
var _pause: Control
## Contextual tips (BMTips) sit on their own 1920x1080 stage, above the screens and under the menu.
var _tips: Control
## First-session tutorial with POPS (GDD §23); above the screens and tips, under the menu.
var tutorial: BMTutorial
var _tip_stage: Control
var _tip_poll := 0.0
var _fps_layer: CanvasLayer
var _fps_label: Label
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
	mood = BMMoodLayer.new()
	add_child(mood)
	fx = BMFx.new()
	add_child(fx)
	_tips = Control.new()
	_tips.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tips)
	_tip_stage = Control.new()
	_tip_stage.size = Vector2(1920, 1080)
	_tip_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tips.add_child(_tip_stage)
	_tips.resized.connect(func() -> void: _tip_stage.position = ((_tips.size - _tip_stage.size) / 2.0).round())
	tutorial = BMTutorial.new()
	tutorial.main = self
	add_child(tutorial)
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pause)
	toasts = BMAchievementToasts.new()
	add_child(toasts)
	crt = BMCrtLayer.new()
	crt.mode = String(settings.get("crt", "soft"))
	add_child(crt)
	# Custom cursor + click effects. Before the CRT in the tree, so it reads remapped positions.
	cursor = BMCursor.new()
	cursor.main = self
	cursor.enabled = String(settings.get("cursor", "custom")) == "custom"
	add_child(cursor)
	move_child(cursor, crt.get_index())
	# FPS counter: its own layer above the CRT so the digits stay crisp.
	_fps_layer = CanvasLayer.new()
	_fps_layer.layer = 120
	add_child(_fps_layer)
	_fps_label = BMStyle.label("", 20, BMStyle.MINT_L, true, 6)
	_fps_label.position = Vector2(12, 8)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_layer.add_child(_fps_label)
	_apply_motion_setting()
	_apply_display_settings()
	show_title()
	# Studio splash over the title; the title's logo intro replays once it is gone.
	# `-- --no-splash` skips it (tools/shoot.py passes this for screenshot fixtures).
	if "--no-splash" in OS.get_cmdline_user_args():
		return
	var splash := BMSplash.new()
	splash.main = self
	title_screen.hold_intro()
	splash.revealing.connect(func() -> void: title_screen.refresh())
	add_child(splash)
	move_child(splash, crt.get_index())


# --- Run lifecycle -------------------------------------------------------------------------

## A new campaign run. `daily` ("YYYY-MM-DD") makes it the Daily: fixed seed, standard Kit,
## Heat 0, nothing locked, so everyone plays the same game that day.
## `custom_seed`: the player chose the seed (typed, PLAY THIS SEED, SAME SEED); such a run
## never counts toward achievements, records or unlocks.
func start_new_run(seed_value: int, kit_id: String = "", heat: int = 0, daily: String = "", custom_seed := false) -> void:
	if kit_id == "":
		kit_id = run.kit_id if run != null else "standard"
	var locked: Array = [] if daily != "" else BMJokers.locked_for(BMAchievementStore.data().unlocked)
	run = BMRun.new_run(seed_value, kit_id, heat, locked)
	run.daily = daily
	run.custom_seed = custom_seed and daily == ""
	BMSaveStore.save_run(run)
	_route(true)


func continue_run() -> void:
	run = BMSaveStore.load_run()
	if run == null:
		show_title()
		return
	_route(true)


func show_title() -> void:
	if mood:
		mood.clear()
	if _tip_stage:
		clear_tips()
	_flush_endless_time()
	close_pause()
	BMAudio.set_endless_combo(0)
	_show(title_screen)
	title_screen.refresh()
	backdrop.set_mood("title")
	BMAudio.music("title")


func start_endless() -> void:
	mood.clear()
	clear_tips()
	_endless_pending_ms = 0.0
	endless_screen.bind(BMEndless.new_game(BMRun.random_seed()))
	BMEndlessStore.record(endless_screen.game)
	_show(endless_screen)
	backdrop.set_mood("endless_calm")
	BMAudio.music("endless_calm")


func continue_endless() -> void:
	mood.clear()
	clear_tips()
	var game := BMEndlessStore.load_game()
	if game == null:
		show_title()
		return
	if game.over:
		BMEndlessStore.record(game)
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
		BMAchievementStore.note_endless(endless_screen.game)
		grant(BMAchievements.check_endless(endless_screen.game, result, _local_hour()))
	return result


func _process(delta: float) -> void:
	var speed := 1.0 if is_paused() else _game_speed()
	if Engine.time_scale != speed:
		Engine.time_scale = speed
	BMBlockPainter.clock += delta
	if endless_screen != null and endless_screen.visible and endless_screen.game != null \
			and not endless_screen.game.over and not is_paused() and not endless_screen.is_style_picker_open() and _window_focused:
		_endless_pending_ms += delta * 1000.0
	_tip_poll += delta
	if _tip_poll >= 0.4:
		_tip_poll = 0.0
		_poll_tips()
	if _fps_label != null and _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


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
		if before != run.phase:
			# A custom-seed run is practice: history only, no profile, Kit/Heat unlocks or records.
			r.kits_unlocked = [] if run.custom_seed else BMSaveStore.record_run(run)
			BMSaveStore.append_history(run)
			r.records = [] if run.custom_seed else BMAchievementStore.record_run(run)
			run_end_news = {"kits": r.kits_unlocked, "records": r.records, "custom_seed": run.custom_seed}
	else:
		BMSaveStore.save_run(run)
	# Achievements read the state and the result; they never change the run.
	if not run.custom_seed:
		BMAchievementStore.note_campaign(run)
		grant(BMAchievements.check_campaign(run, a, r, BMAchievementStore.life(), _local_hour()))
	if String(a.get("a", "")) == "overtime":
		BMAudio.sfx("overtime")
	_route(before != run.phase and run.phase in [BMRun.Phase.SHOP, BMRun.Phase.RUN_WON])
	return r


## Unlocks achievements (the store ignores ones already earned) and announces the new ones.
func grant(ids: Array) -> Array[String]:
	var fresh := BMAchievementStore.unlock(ids)
	if not fresh.is_empty():
		var news: Array = fresh.duplicate()
		for id in fresh:
			for j in BMJokers.unlocked_by(id):
				news.append("joker:" + j)
		toasts.announce(news)
	return fresh


## Presentation-side achievement events (the title logo easter egg).
func achievement_event(id: String) -> void:
	grant([id])


## Run-end news for the result screen, handed over once.
func take_run_end_news() -> Dictionary:
	var n := run_end_news
	run_end_news = {}
	return n


func _local_hour() -> int:
	return int(Time.get_datetime_dict_from_system().get("hour", -1))


func _route(rebind: bool) -> void:
	BMAudio.set_endless_combo(0)
	if mood and run and run.phase != BMRun.Phase.ROUND:
		mood.clear()
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
				BMAudio.music(music_context())


## Soundtrack for the current round: Mk II bosses and Overtime have their own music, act 3 and
## Heat 3+ rounds the harder playlist.
func music_context() -> String:
	if run.current_boss() != "":
		return "boss_mk2" if run.boss_is_mk2() else "boss"
	if run.overtime:
		return "overtime"
	if run.act() >= 3 or run.heat >= 3:
		return "round_hard"
	return "round"


func _show(screen: Control) -> void:
	if _tip_stage and not screen.visible:
		clear_tips()
	for s in [title_screen, game_screen, shop_screen, endless_screen]:
		s.visible = s == screen
		s.process_mode = Node.PROCESS_MODE_INHERIT if s == screen else Node.PROCESS_MODE_DISABLED
	var st: Variant = screen.get("stage")
	fx.shake_target = st if st is Control else null
	if not settings.reduced_motion and screen != title_screen:
		screen.modulate.a = 0.0
		screen.create_tween().tween_property(screen, "modulate:a", 1.0, 0.25)


# --- Contextual tips ------------------------------------------------------------------------

## Checks the current screen for a tip to show (BMTips conditions only read state).
func _poll_tips() -> void:
	if not bool(settings.get("tips", true)) or is_paused() or _tip_stage.get_child_count() > 0 or run == null:
		return
	# POPS is talking: no tips on top of the tutorial.
	if tutorial != null and tutorial.active:
		return
	var seen: Array = settings.get("tips_seen", [])
	if game_screen.visible and game_screen.overlay.get_child_count() == 0:
		show_tip(BMTips.for_round(run, seen), Rect2(50, 560, 484, 0))
	elif shop_screen.visible:
		if shop_screen._picker_open():
			show_tip("round_cards" if not seen.has("round_cards") else "", Rect2(718, 846, 484, 0))
		elif shop_screen._overlay.get_child_count() == 0:
			show_tip(BMTips.for_shop(run, seen), Rect2(1386, 60, 484, 0))


## Shows one tip once (marks it seen). Returns false when tips are off, it was seen, or
## another tip is up. `rect` is a stage position; the height follows the text.
func show_tip(id: String, rect: Rect2) -> bool:
	if id == "" or not bool(settings.get("tips", true)) or _tip_stage.get_child_count() > 0:
		return false
	var seen: Array = settings.get("tips_seen", [])
	if seen.has(id):
		return false
	seen.append(id)
	settings.tips_seen = seen
	BMSaveStore.save_settings(settings)
	var plate := BMTipPlate.new()
	plate.tip_id = id
	plate.reduced_motion = settings.reduced_motion
	plate.position = rect.position
	plate.size = Vector2(rect.size.x, 0)
	plate.custom_minimum_size.x = rect.size.x
	_tip_stage.add_child(plate)
	return true


func clear_tips() -> void:
	BMUI.clear_children(_tip_stage)


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
	var menu := BMSettingsMenu.new()
	menu.main = self
	menu.in_run = in_run
	if in_run:
		menu.context = "endless" if endless_screen.visible else ("shop" if shop_screen.visible else "campaign")
	_pause.add_child(menu)


## One setting changed from the menu: store it, save, apply everything. An empty key only
## saves and applies (RESET PAGE writes several keys first).
func set_setting(key: String, value: Variant) -> void:
	if key != "":
		settings[key] = value
	BMSaveStore.save_settings(settings)
	_apply_settings()


func save_and_quit() -> void:
	if endless_screen.visible:
		BMEndlessStore.record(endless_screen.game)
	elif run != null:
		BMSaveStore.save_run(run)
	show_title()


func abandon_run() -> void:
	close_pause()
	act({"a": "abandon"})
	game_screen.close_overlay()
	game_screen.bind(run)


func _apply_settings() -> void:
	audio.apply_settings(settings)
	_apply_display_settings()
	BMBlockPainter.show_patterns = settings.block_patterns
	crt.set_mode(String(settings.crt))
	cursor.set_enabled(String(settings.cursor) == "custom")
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


## Window mode and FPS counter. Leaving fullscreen restores a centered 1600x900 window.
func _apply_display_settings() -> void:
	var want_full := bool(settings.get("fullscreen", false))
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if want_full and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not want_full and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var screen := DisplayServer.window_get_current_screen()
		var area := DisplayServer.screen_get_usable_rect(screen)
		var sz := Vector2i(mini(1600, area.size.x), mini(900, area.size.y))
		DisplayServer.window_set_size(sz)
		DisplayServer.window_set_position(area.position + (area.size - sz) / 2)
	_fps_label.visible = bool(settings.get("show_fps", false))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(settings.get("vsync", true)) else DisplayServer.VSYNC_DISABLED)


func _apply_motion_setting() -> void:
	backdrop.set_motion(not settings.reduced_motion)
	mood.reduced_motion = settings.reduced_motion
	mood.strength = {"full": 1.0, "soft": 0.5, "off": 0.0}.get(String(settings.get("screen_fx", "full")), 1.0)
	fx.reduced_motion = settings.reduced_motion
	toasts.reduced_motion = settings.reduced_motion
	BMBlockPainter.reduced_motion = settings.reduced_motion
	# Accessibility: shake and flash strength (flashes also cover CRT jolts and background pulses).
	fx.shake_scale = {"off": 0.0, "low": 0.45, "full": 1.0}.get(String(settings.get("shake", "full")), 1.0)
	var flash_k: float = {"off": 0.0, "soft": 0.45, "full": 1.0}.get(String(settings.get("flashes", "full")), 1.0)
	mood.flash_scale = flash_k
	crt.shock_scale = flash_k
	backdrop.pulse_scale = flash_k
	mood.heartbeat_sound = bool(settings.get("heartbeat", true))


## Game speed (Settings > Game) scales time on the campaign screens only: scoring and round
## animations play faster; rules never read time, so results are identical. Endless keeps
## real time because its statistics count active seconds.
func _game_speed() -> float:
	if not (game_screen.visible or shop_screen.visible):
		return 1.0
	return {"normal": 1.0, "fast": 1.4, "turbo": 1.9}.get(String(settings.get("game_speed", "normal")), 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if is_paused() and event.is_action_pressed("bm_cancel"):
		close_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("bm_mute"):
		settings.muted = not bool(settings.muted)
		BMSaveStore.save_settings(settings)
		audio.apply_settings(settings)
		for m in _pause.get_children():
			if m is BMSettingsMenu:
				m.refresh_values()
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
