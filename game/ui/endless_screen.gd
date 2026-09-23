class_name BMEndlessScreen
extends Control
## A one-screen arcade cabinet. The rules and save are separate from campaign runs.

const STAGE := Vector2(1920, 1080)
var main: BMMain
var game: BMEndless
var stage: Control
var board_view: BMBoardView
var slots: Array[BMTraySlot] = []
var _score: BMHud.Counter
var _best: Label
var _combo: Label
var _status: Label
var _mode: Label
var _detail: Label
var _overlay: Control
var _drag: Control
var _mouse := Vector2.ZERO
var _press_pos := Vector2.ZERO
var _held := -1
var _hold_mode := ""
var _anchor := Vector2i(3, 3)
var _mood := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage = Control.new()
	stage.size = STAGE
	add_child(stage)
	resized.connect(func() -> void: stage.position = ((size - STAGE) / 2.0).round())
	stage.position = ((size - STAGE) / 2.0).round()
	var marquee := BMHud.Marquee.new()
	_at(marquee, Vector2(568, 6), Vector2(784, 72))
	marquee.text = "∞  ENDLESS"
	marquee.sub = "ONE MORE CLEAR"
	board_view = BMBoardView.new()
	_at(board_view, Vector2(568, 82), Vector2(784, 784))
	for i in 3:
		var slot := BMTraySlot.new()
		slot.slot = i
		slot.pressed.connect(_on_slot)
		_at(slot, Vector2(640 + i * 212, 878), Vector2(200, 176))
		slots.append(slot)
	var left := BMStyle.panel("panel_plate", Vector4(8, 4, 8, 8))
	_at(left, Vector2(48, 98), Vector2(485, 650))
	var stats := BMStyle.vbox(20)
	left.add_child(stats)
	stats.add_child(BMStyle.pill("ARCADE SCORE", "sun", 20))
	_score = BMHud.Counter.new()
	_score.add_theme_font_override("font", BMStyle.font_bold)
	_score.add_theme_font_size_override("font_size", 80)
	_score.add_theme_color_override("font_color", BMStyle.CREAM)
	_score.text = "0"
	stats.add_child(_score)
	_best = BMStyle.label("", 30, BMStyle.SUN, true)
	stats.add_child(_best)
	_combo = BMStyle.label("", 40, BMStyle.PINK_L, true)
	stats.add_child(_combo)
	_status = BMStyle.label("", 20, BMStyle.CREAM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.add_child(_status)
	var right := BMStyle.panel("panel_plate", Vector4(8, 4, 8, 8))
	_at(right, Vector2(1380, 98), Vector2(485, 650))
	var tips := BMStyle.vbox(16)
	right.add_child(tips)
	tips.add_child(BMStyle.pill("KEEP IT GOING", "mint", 20))
	_mode = BMStyle.label("", 30, BMStyle.MINT_L, true)
	tips.add_child(_mode)
	_detail = BMStyle.label("", 20, BMStyle.CREAM)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tips.add_child(_detail)
	var help := BMStyle.label("Drag a piece to the board, or click it and then a cell.\n\nKeys: 1-3 select, arrows move, Enter places, Esc opens menu.\n\nPlace blocks for 10 points each. Every cleared line adds 100 x combo. Two placements without a clear reset the combo.", 20, BMStyle.TEXT_DIM)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tips.add_child(help)
	var menu := BMStyle.button("MENU", func() -> void: main.show_pause(), "plum", 30)
	_at(menu, Vector2(1430, 878), Vector2(350, 80))
	_drag = Control.new()
	_drag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag.draw.connect(_draw_drag)
	add_child(_drag)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


func _at(control: Control, pos: Vector2, dimensions: Vector2) -> void:
	control.position = pos
	control.size = dimensions
	stage.add_child(control)


func bind(new_game: BMEndless) -> void:
	game = new_game
	BMUI.clear_children(_overlay)
	var display := BMRun.new()
	display.board = game.board
	board_view.run = display
	apply_settings()
	_cancel()
	refresh_all()
	_mood = ""
	update_mood()
	if game.over:
		_show_over()


func apply_settings() -> void:
	board_view.reduced_motion = main.settings.reduced_motion
	_score.reduced_motion = main.settings.reduced_motion
	for slot in slots:
		slot.reduced_motion = main.settings.reduced_motion


func refresh_all() -> void:
	if game == null:
		return
	_score.set_target(game.score)
	var scores := BMEndlessStore.high_scores()
	var best := game.score
	if not scores.is_empty():
		best = maxi(best, int(scores[0].score))
	_best.text = "BEST  %s" % BMUI.fmt_int(best)
	_combo.text = "COMBO x%d" % game.combo
	_status.text = "Placements %d   •   Lines %d\n%s" % [game.placements, game.lines,
		"ONE MISS: clear next to keep the chain" if game.misses == 1 else "Clear lines on consecutive placements to grow your combo"]
	for i in 3:
		slots[i].setup(game.tray[i], i == _held, game.fits(i))
	board_view.queue_redraw()
	update_mood()


func update_mood() -> void:
	if game == null:
		return
	var fill := float(game.board.occupied_count()) / 64.0
	var wanted := "endless_party" if game.combo >= 4 else ("endless_tense" if fill >= 0.68 or (game.score >= 5000 and fill >= 0.48) else "endless_calm")
	if wanted != _mood:
		_mood = wanted
		if BMSwirlBackground.instance:
			BMSwirlBackground.instance.set_mood(wanted)
		BMAudio.music(wanted)
	match wanted:
		"endless_party":
			_mode.text = "COLOR PARADE"
			_mode.add_theme_color_override("font_color", BMStyle.PINK_L)
			_detail.text = "Your x%d chain is alive. Keep clearing!" % game.combo
		"endless_tense":
			_mode.text = "THE BOARD IS HEATING UP"
			_mode.add_theme_color_override("font_color", BMStyle.PINK_L)
			_detail.text = "The spaces are shrinking. Find the next opening."
		_:
			_mode.text = "EASY DOES IT"
			_mode.add_theme_color_override("font_color", BMStyle.MINT_L)
			_detail.text = "Find a rhythm. There is no timer and no target."


func _on_slot(index: int) -> void:
	if game == null or game.over or main.is_paused() or not game.fits(index):
		return
	if _held == index:
		_cancel()
		return
	_held = index
	_hold_mode = "drag"
	_press_pos = _mouse
	BMAudio.sfx("pickup")
	_update_ghost()
	refresh_all()


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse = event.position
	if game == null or game.over or main.is_paused() or _held < 0:
		return
	if event is InputEventMouseMotion:
		if _hold_mode == "key":
			_hold_mode = "sticky"
		_update_ghost()
		_drag.queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and _hold_mode == "drag":
			if _over_board() and board_view.ghost_valid:
				_place(board_view.ghost_anchor)
			elif _mouse.distance_to(_press_pos) > 12:
				_cancel()
			else:
				_hold_mode = "sticky"
		elif event.pressed and _hold_mode == "sticky" and _over_board():
			if board_view.ghost_valid:
				_place(board_view.ghost_anchor)
			else:
				BMAudio.sfx("deny")
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if game == null or game.over or main.is_paused() or not event is InputEventKey or not event.pressed:
		return
	if event.is_action("bm_cancel"):
		if _held >= 0:
			_cancel()
		else:
			main.show_pause()
		get_viewport().set_input_as_handled()
		return
	for i in 3:
		if event.is_action("bm_slot_%d" % (i + 1)) and game.fits(i):
			_held = i
			_hold_mode = "key"
			board_view.keyboard_focus = true
			_show_ghost(_anchor)
			refresh_all()
			get_viewport().set_input_as_handled()
			return
	if _held < 0:
		return
	var delta := Vector2i.ZERO
	if event.is_action("bm_left"):
		delta = Vector2i.LEFT
	elif event.is_action("bm_right"):
		delta = Vector2i.RIGHT
	elif event.is_action("bm_up"):
		delta = Vector2i.UP
	elif event.is_action("bm_down"):
		delta = Vector2i.DOWN
	if delta != Vector2i.ZERO:
		_hold_mode = "key"
		_anchor = (_anchor + delta).clamp(Vector2i.ZERO, Vector2i(8, 8) - BMShapes.shape_size(game.tray[_held]))
		board_view.keyboard_focus = true
		_show_ghost(_anchor)
		BMAudio.sfx("key_move")
		get_viewport().set_input_as_handled()
	elif event.is_action("bm_place"):
		if board_view.ghost_valid:
			_place(board_view.ghost_anchor)
		else:
			BMAudio.sfx("deny")
		get_viewport().set_input_as_handled()


func _over_board() -> bool:
	var local := board_view.get_global_transform().affine_inverse() * _mouse
	var side := board_view.cell_size() * 8
	return Rect2(board_view.grid_origin(), Vector2(side, side)).grow(board_view.cell_size() * 0.6).has_point(local)


func _update_ghost() -> void:
	if _held < 0:
		return
	board_view.keyboard_focus = false
	if not _over_board():
		board_view.clear_ghost()
		return
	var local := board_view.get_global_transform().affine_inverse() * _mouse
	var half_shape := Vector2(BMShapes.shape_size(game.tray[_held])) * board_view.cell_size() / 2.0
	_anchor = board_view.anchor_from_top_left(local - half_shape)
	_show_ghost(_anchor)


func _show_ghost(anchor: Vector2i) -> void:
	board_view.set_ghost(game.tray[_held], anchor)


func _place(anchor: Vector2i) -> void:
	var result := main.endless_act({"a": "place", "i": _held, "x": anchor.x, "y": anchor.y})
	if not result.ok:
		BMAudio.sfx("deny")
		return
	_cancel()
	board_view.play_resolution(result)
	BMAudio.sfx("place_m")
	if result.rows.size() + result.cols.size() > 0:
		BMAudio.sfx("clear_2" if result.rows.size() + result.cols.size() >= 2 else "clear_1")
		if BMSwirlBackground.instance:
			BMSwirlBackground.instance.pulse(0.7 if game.combo >= 4 else 0.35)
		if BMFx.instance:
			BMFx.instance.pop_text(board_view.global_position + board_view.size / 2, "+%d  x%d COMBO" % [result.points, game.combo], BMStyle.SUN, 40)
			if game.combo >= 4:
				BMFx.instance.confetti(board_view.get_global_rect(), 30 if game.combo < 8 else 55)
	refresh_all()
	if result.over:
		BMAudio.sfx("jingle_lose")
		_show_over()


func _cancel() -> void:
	_held = -1
	_hold_mode = ""
	board_view.keyboard_focus = false
	board_view.clear_ghost()
	_drag.queue_redraw()
	if game != null:
		for i in 3:
			slots[i].setup(game.tray[i], false, game.fits(i))


func _draw_drag() -> void:
	if game == null or _held < 0 or _hold_mode == "key":
		return
	var shape: Dictionary = game.tray[_held]
	if shape.is_empty():
		return
	var cell := board_view.cell_size()
	var pos := _mouse - Vector2(BMShapes.shape_size(shape)) * cell / 2.0
	BMBlockPainter.draw_shape(_drag, shape, pos, cell, 0.85)


func focus_default() -> void:
	for slot in slots:
		if game.fits(slot.slot):
			BMStyle.focus_later(slot)
			return


func _show_over() -> void:
	BMUI.clear_children(_overlay)
	var shade := ColorRect.new()
	shade.color = Color(BMStyle.INK, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(shade)
	var panel := BMStyle.panel("panel_plate", Vector4(24, 18, 24, 18))
	panel.position = (size - Vector2(760, 520)) / 2.0
	panel.size = Vector2(760, 520)
	shade.add_child(panel)
	var content := BMStyle.vbox(20)
	panel.add_child(content)
	for words in ["NO ROOM LEFT", "SCORE  %s" % BMUI.fmt_int(game.score), "%d lines  •  Best combo x%d" % [game.lines, game.best_combo], "Your score has been saved to the local high scores."]:
		var label := BMStyle.label(words, 40 if words.begins_with("NO ROOM") else 30, BMStyle.SUN if words.begins_with("SCORE") else BMStyle.CREAM, true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(label)
	var again := BMStyle.button("PLAY AGAIN", func() -> void:
		BMUI.clear_children(_overlay)
		main.start_endless(), "sun", 30)
	again.custom_minimum_size.y = 70
	content.add_child(again)
	var scores := BMStyle.button("HIGH SCORES", func() -> void: main.show_title(); main.title_screen._show_high_scores(), "sky", 30)
	scores.custom_minimum_size.y = 70
	content.add_child(scores)
	var title := BMStyle.button("TITLE", func() -> void: main.show_title(), "plum", 30)
	title.custom_minimum_size.y = 70
	content.add_child(title)
	BMStyle.focus_later(again)
