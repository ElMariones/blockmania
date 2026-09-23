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
var _marquee: BMHud.Marquee
var _best: Label
var _combo: Label
var _ladder: Label
var _status: Label
var _mode: Label
var _detail: Label
var _hold_well: HoldWell
var _hold_hint: Label
var _overlay: Control
var _drag: Control
var _mouse := Vector2.ZERO
var _press_pos := Vector2.ZERO
var _held := -1
var _hold_mode := ""
var _anchor := Vector2i(3, 3)
var _mood := ""
var _trail: Array[Vector2] = []
var _board_pulse: Tween


class HoldWell extends Control:
	var shape: Dictionary = {}
	var locked := false
	var drop_highlight := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		draw_style_box(BMStyle.box("panel_inset", Vector4.ZERO), Rect2(Vector2.ZERO, size))
		if drop_highlight and not locked:
			draw_rect(Rect2(Vector2(5, 5), size - Vector2(10, 10)), BMStyle.MINT_L, false, 5.0)
		var title := "HOLD"
		draw_string(BMStyle.font_bold, Vector2(24, 42), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, BMStyle.MINT_L if drop_highlight else BMStyle.SUN)
		if shape.is_empty():
			draw_string(BMStyle.font, Vector2(0, size.y / 2.0 + 20), "EMPTY", HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, BMStyle.TEXT_DIM)
		else:
			var dims := Vector2(BMShapes.shape_size(shape))
			var cell := floorf(minf(54.0, minf((size.x - 80) / dims.x, (size.y - 110) / dims.y)))
			var at := ((size - dims * cell) / 2.0 + Vector2(0, 22)).round()
			BMBlockPainter.draw_shape(self, shape, at, cell, 1.0)
		if locked:
			draw_string(BMStyle.font_bold, Vector2(0, size.y - 20), "USED THIS TURN", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, BMStyle.PINK_L)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage = Control.new()
	stage.size = STAGE
	add_child(stage)
	resized.connect(func() -> void: stage.position = ((size - STAGE) / 2.0).round())
	stage.position = ((size - STAGE) / 2.0).round()
	_marquee = BMHud.Marquee.new()
	_at(_marquee, Vector2(568, 6), Vector2(784, 72))
	_marquee.icon = BMStyle.infinity_icon()
	_marquee.text = "ENDLESS"
	_marquee.sub = "ONE MORE CLEAR"
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
	_ladder = BMStyle.label("x1  x2  x3  x5  x8  x10", 20, BMStyle.SUN_L, true)
	stats.add_child(_ladder)
	_status = BMStyle.label("", 20, BMStyle.CREAM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.add_child(_status)
	var right := BMStyle.panel("panel_plate", Vector4(8, 4, 8, 8))
	_at(right, Vector2(1380, 98), Vector2(485, 650))
	var tips := BMStyle.vbox(16)
	right.add_child(tips)
	tips.add_child(BMStyle.pill("HOLD  •  ONCE PER PLACEMENT", "mint", 20))
	_hold_well = HoldWell.new()
	_hold_well.custom_minimum_size = Vector2(0, 278)
	_hold_well.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tips.add_child(_hold_well)
	_hold_hint = BMStyle.label("Select a piece, then drop it here or press H.", 20, BMStyle.CREAM)
	_hold_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tips.add_child(_hold_hint)
	_mode = BMStyle.label("", 30, BMStyle.MINT_L, true)
	tips.add_child(_mode)
	_detail = BMStyle.label("", 20, BMStyle.CREAM)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tips.add_child(_detail)
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
	_marquee.reduced_motion = main.settings.reduced_motion
	_score.reduced_motion = main.settings.reduced_motion
	for slot in slots:
		slot.reduced_motion = main.settings.reduced_motion


func refresh_all() -> void:
	if game == null:
		return
	_score.set_target(game.score)
	var score_digits := BMUI.fmt_int(game.score).length()
	_score.add_theme_font_size_override("font_size", 80 if score_digits <= 7 else (60 if score_digits <= 10 else 40))
	var scores := BMEndlessStore.high_scores()
	var best := game.score
	if not scores.is_empty():
		best = maxi(best, int(scores[0].score))
	_best.text = "BEST  %s" % BMUI.fmt_int(best)
	_combo.text = "COMBO x%d" % game.combo
	_combo.add_theme_color_override("font_color", BMStyle.SUN if game.combo >= 8 else BMStyle.PINK_L)
	_status.text = "Placements %d   •   Lines %d\n%s" % [game.placements, game.lines,
		"%d more misses before combo resets" % (3 - game.misses) if game.misses > 0 else "Clear lines to climb the combo ladder"]
	_hold_well.shape = game.held
	_hold_well.locked = game.hold_used
	_hold_well.queue_redraw()
	_hold_hint.text = "HOLD USED — place a piece to recharge" if game.hold_used else "Select a piece, then drop it here or press H"
	for i in 3:
		slots[i].setup(game.tray[i], i == _held, game.fits(i))
		slots[i].tooltip_text = "No board fit. Select this piece to use Hold." if not game.tray[i].is_empty() and not game.fits(i) and not game.hold_used else ""
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
	BMAudio.set_endless_combo(game.combo)
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
	if game == null or game.over or main.is_paused() or game.tray[index].is_empty():
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
		var highlight := _over_hold() and not game.hold_used
		if _hold_well.drop_highlight != highlight:
			_hold_well.drop_highlight = highlight
			_hold_well.queue_redraw()
		if game.combo >= 5 and not main.settings.reduced_motion:
			_trail.append(_mouse)
			if _trail.size() > 6:
				_trail.pop_front()
		_drag.queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and _hold_mode == "drag":
			if _over_hold():
				_hold_selected()
			elif _over_board() and board_view.ghost_valid:
				_place(board_view.ghost_anchor)
			elif _mouse.distance_to(_press_pos) > 12:
				_cancel()
			else:
				_hold_mode = "sticky"
		elif event.pressed and _hold_mode == "sticky":
			if _over_hold():
				_hold_selected()
			elif _over_board():
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
		if event.is_action("bm_slot_%d" % (i + 1)) and not game.tray[i].is_empty():
			_held = i
			_hold_mode = "key"
			board_view.keyboard_focus = true
			_show_ghost(_anchor)
			refresh_all()
			get_viewport().set_input_as_handled()
			return
	if _held < 0:
		return
	if event.is_action("bm_hold"):
		_hold_selected()
		get_viewport().set_input_as_handled()
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


func _over_hold() -> bool:
	return _hold_well.get_global_rect().has_point(_mouse)


func _hold_selected() -> void:
	var result := main.endless_act({"a": "hold", "i": _held})
	if not result.ok:
		BMAudio.sfx("deny")
		_marquee.flash(String(result.error).to_upper(), BMStyle.PINK_L, 1.8)
		return
	BMAudio.sfx("putback")
	_cancel()
	refresh_all()
	_marquee.flash("PIECE HELD  •  PLACE TO RECHARGE", BMStyle.MINT_L, 1.4)


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
		var line_count: int = result.rows.size() + result.cols.size()
		BMAudio.sfx("clear_3" if line_count >= 3 else ("clear_2" if line_count == 2 else "clear_1"))
		BMAudio.sfx("combo_3" if game.combo >= 8 else ("combo_2" if game.combo >= 5 else "combo_1"))
		if BMSwirlBackground.instance:
			BMSwirlBackground.instance.pulse(0.85 if game.combo >= 8 else 0.45)
		if BMFx.instance:
			var center := board_view.get_global_rect().get_center()
			BMFx.instance.pop_text(center, "+%d  x%d" % [result.points, game.combo], BMStyle.SUN, 80 if game.combo >= 8 else (60 if game.combo >= 5 else 40))
			BMFx.instance.stream(center, _score.get_global_rect().get_center(), BMStyle.SUN, mini(24, 6 + game.combo * 2))
			if game.combo >= 5:
				BMFx.instance.confetti(board_view.get_global_rect(), 32 if game.combo < 8 else 64)
			if game.combo >= 8:
				BMFx.instance.shake(5.0)
		if game.combo >= 5:
			_pulse_board(1.025 if game.combo < 8 else 1.04)
		if not result.callouts.is_empty():
			var primary: String = "CLEAN BOARD" if result.clean_board else ("BLOCKSTORM" if result.callouts.has("BLOCKSTORM") else result.callouts[0])
			_marquee.flash(primary, BMStyle.SUN_L, 2.2)
			if BMFx.instance:
				var index := 0
				for callout: String in result.callouts:
					BMFx.instance.pop_text(board_view.get_global_rect().get_center() + Vector2(0, -130 - 62 * index), callout, BMStyle.MINT_L if callout in ["CLEAN BOARD", "PERFECT"] else BMStyle.PINK_L, 60 if callout == primary else 40, 40.0, 1.35)
					index += 1
		if result.clean_board:
			BMAudio.sfx("jingle_win")
			if BMFx.instance:
				BMFx.instance.confetti(board_view.get_global_rect(), 150)
				BMFx.instance.shake(9.0)
	refresh_all()
	if result.over:
		BMAudio.sfx("jingle_lose")
		_show_over()


func _cancel() -> void:
	_held = -1
	_hold_mode = ""
	_hold_well.drop_highlight = false
	_hold_well.queue_redraw()
	_trail.clear()
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
	if game.combo >= 5 and not main.settings.reduced_motion:
		for n in _trail.size():
			var trail_at := _trail[n] - Vector2(BMShapes.shape_size(shape)) * cell / 2.0
			BMBlockPainter.draw_shape(_drag, shape, trail_at, cell, 0.05 + float(n) / maxf(1.0, _trail.size()) * 0.18)
	var pos := _mouse - Vector2(BMShapes.shape_size(shape)) * cell / 2.0
	BMBlockPainter.draw_shape(_drag, shape, pos, cell, 0.85)


func _pulse_board(amount: float) -> void:
	if main.settings.reduced_motion:
		return
	if _board_pulse != null and _board_pulse.is_running():
		_board_pulse.kill()
	board_view.pivot_offset = board_view.size / 2.0
	board_view.scale = Vector2.ONE
	_board_pulse = create_tween()
	_board_pulse.tween_property(board_view, "scale", Vector2.ONE * amount, 0.12).set_trans(Tween.TRANS_BACK)
	_board_pulse.tween_property(board_view, "scale", Vector2.ONE, 0.22)


func focus_default() -> void:
	for slot in slots:
		if game.fits(slot.slot):
			BMStyle.focus_later(slot)
			return
	for slot in slots:
		if not game.tray[slot.slot].is_empty():
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
