class_name BMGameScreen
extends Control
## Round screen: board center, score/target left, Jokers and items right, tray below.
## Input: drag-and-release, click-to-hold then click board, or keyboard (1-3, arrows/WASD,
## Enter/Space, R, Esc). All actions go through `main.act()`; this screen only presents.

var main: Node ## BMMain
var run: BMRun

var board_view: BMBoardView
var slots: Array[BMTraySlot] = []
var refresh_button: Button
var drag_layer: Control
var overlay: Control

var _round_label: Label
var _target_label: Label
var _score_label: Label
var _score_bar: ProgressBar
var _placements_label: Label
var _refresh_label: Label
var _combo_label: Label
var _credits_label: Label
var _boss_box: VBoxContainer
var _receipt: RichTextLabel
var _preview_label: Label
var _message_label: Label
var _action_row: HBoxContainer
var _jokers_box: VBoxContainer
var _jokers_header: Label
var _items_box: VBoxContainer
var _items_header: Label
var _seed_label: Label

# Held-shape state.
var held_slot := -1
var held_mode := "" ## "drag", "sticky", or "key"
var key_anchor := Vector2i(3, 3)
var _press_pos := Vector2.ZERO
## Pointer position in canvas coordinates, tracked from input events (works for real and
## simulated input alike).
var _mouse := Vector2.ZERO
var _preview_cache_key := ""
var _intro_shown_for := -1
var _last_result: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	add_child(margin)
	var cols := BMUI.hbox(36)
	margin.add_child(cols)

	# Left column: round status, boss, receipt.
	var left := BMUI.vbox(14)
	left.custom_minimum_size.x = 390
	cols.add_child(left)
	var status := BMUI.panel()
	left.add_child(status)
	var sv := BMUI.vbox(6)
	status.add_child(sv)
	_round_label = BMUI.label("", 18, BMPalette.TEXT_DIM)
	sv.add_child(_round_label)
	_target_label = BMUI.label("", 22, BMPalette.BRASS)
	sv.add_child(_target_label)
	_score_label = BMUI.label("0", 64, BMPalette.TEXT)
	sv.add_child(_score_label)
	_score_bar = ProgressBar.new()
	_score_bar.custom_minimum_size.y = 16
	_score_bar.show_percentage = false
	sv.add_child(_score_bar)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	sv.add_child(grid)
	_placements_label = BMUI.label("", 21)
	_refresh_label = BMUI.label("", 21)
	_combo_label = BMUI.label("", 21)
	_credits_label = BMUI.label("", 21, BMPalette.BRASS)
	for l in [_placements_label, _refresh_label, _combo_label, _credits_label]:
		grid.add_child(l)

	var boss_panel := BMUI.panel(BMPalette.BG_DEEP, BMPalette.CORAL)
	left.add_child(boss_panel)
	_boss_box = BMUI.vbox(4)
	boss_panel.add_child(_boss_box)

	var receipt_panel := BMUI.panel()
	receipt_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(receipt_panel)
	var rv := BMUI.vbox(6)
	receipt_panel.add_child(rv)
	rv.add_child(BMUI.label("LAST PLACEMENT", 16, BMPalette.TEXT_DIM))
	_receipt = RichTextLabel.new()
	_receipt.bbcode_enabled = true
	_receipt.fit_content = false
	_receipt.scroll_active = true
	_receipt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_receipt.add_theme_font_size_override("normal_font_size", 18)
	_receipt.add_theme_font_size_override("bold_font_size", 20)
	rv.add_child(_receipt)

	# Center column: board, messages, tray.
	var center := BMUI.vbox(10)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(center)
	board_view = BMBoardView.new()
	board_view.custom_minimum_size = Vector2(720, 720)
	board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(board_view)
	_preview_label = BMUI.label("", 22, BMPalette.BRASS)
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_preview_label)
	_message_label = BMUI.label("", 20, BMPalette.TEXT)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(_message_label)
	_action_row = BMUI.hbox(12)
	_action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(_action_row)
	var tray := BMUI.hbox(18)
	tray.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(tray)
	for i in 3:
		var s := BMTraySlot.new()
		s.slot = i
		s.custom_minimum_size = Vector2(230, 180)
		s.pressed.connect(_on_slot_pressed)
		tray.add_child(s)
		slots.append(s)
	refresh_button = BMUI.button("Refresh", func() -> void: _do_action({"a": "refresh"}), 20)
	refresh_button.custom_minimum_size = Vector2(150, 180)
	refresh_button.tooltip_text = "Replace every unplaced shape in the tray. Costs no placement. (R)"
	tray.add_child(refresh_button)
	var hint := BMUI.label("Drag or click a shape, then place it  |  Right-click / Esc cancels  |  1-3 select, arrows move, Enter places, R refresh", 15, BMPalette.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(hint)

	# Right column: Jokers, items, pause.
	var right := BMUI.vbox(10)
	right.custom_minimum_size.x = 420
	cols.add_child(right)
	_jokers_header = BMUI.label("", 18, BMPalette.TEXT_DIM)
	right.add_child(_jokers_header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_jokers_box = BMUI.vbox(8)
	_jokers_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_jokers_box)
	_items_header = BMUI.label("", 18, BMPalette.TEXT_DIM)
	right.add_child(_items_header)
	_items_box = BMUI.vbox(8)
	right.add_child(_items_box)
	var bottom := BMUI.hbox(10)
	right.add_child(bottom)
	_seed_label = BMUI.label("", 15, BMPalette.TEXT_DIM)
	_seed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_seed_label)
	bottom.add_child(BMUI.button("Pause (Esc)", func() -> void: main.show_pause(), 18))

	drag_layer = Control.new()
	drag_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_layer.draw.connect(_draw_drag_layer)
	add_child(drag_layer)

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)


# --- Refresh from state --------------------------------------------------------------------

func bind(new_run: BMRun) -> void:
	run = new_run
	board_view.run = run
	_cancel_hold()
	refresh_all()
	_maybe_show_phase_overlay()


func refresh_all() -> void:
	if run == null:
		return
	var rs := run.round_state
	var boss := run.current_boss()
	_round_label.text = "ROUND %d / %d   ACT %d%s" % [run.round_number, BMRunConfig.ROUND_COUNT, run.act(), "   BOSS" if boss != "" else ""]
	_target_label.text = "TARGET  %s" % BMUI.fmt_int(rs.target)
	_score_label.text = BMUI.fmt_int(rs.score)
	_score_bar.max_value = rs.target
	_score_bar.value = mini(rs.score, rs.target)
	_placements_label.text = "Placements  %d" % rs.placements_left
	_placements_label.add_theme_color_override("font_color", BMPalette.CORAL if rs.placements_left <= 3 else BMPalette.TEXT)
	if boss == "lockdown":
		_refresh_label.text = "Refresh  LOCKED"
	else:
		_refresh_label.text = "Refresh  %d" % rs.refreshes_left
	_combo_label.text = "Combo  x%d" % rs.combo
	_credits_label.text = "Credits  %d" % run.credits
	var extras: Array[String] = []
	if rs.pending_chips > 0:
		extras.append("+%d Chips next" % rs.pending_chips)
	if rs.pending_mult > 0:
		extras.append("+%s Mult next" % BMUI.fmt_mult(rs.pending_mult))
	if rs.cash_out > 0:
		extras.append("Cash Out x%d" % rs.cash_out)
	if not extras.is_empty():
		_combo_label.text += "   (" + ", ".join(extras) + ")"

	BMUI.clear_children(_boss_box)
	if boss != "":
		var d := BMBosses.get_def(boss)
		_boss_box.add_child(BMUI.label("BOSS ROUND: " + d.name.to_upper(), 19, BMPalette.CORAL))
		var rule := BMUI.label(d.rule, 17)
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_boss_box.add_child(rule)
	else:
		var d := BMBosses.get_def(run.act_boss())
		_boss_box.add_child(BMUI.label("ACT %d BOSS (ROUND %d)" % [run.act(), run.act() * 4], 16, BMPalette.TEXT_DIM))
		_boss_box.add_child(BMUI.label(d.name, 19, BMPalette.CORAL))
		var rule := BMUI.label(d.rule, 16, BMPalette.TEXT_DIM)
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_boss_box.add_child(rule)

	for i in 3:
		slots[i].setup(run.tray[i], held_slot == i, run.slot_fits(i))
		slots[i].focused_by_key = held_mode == "key" and held_slot == i
	refresh_button.text = "Refresh\n%s" % ("locked" if boss == "lockdown" else "%d left" % rs.refreshes_left)
	refresh_button.disabled = run.refreshes_available() <= 0 or not run.can_act_in_round() or rs.status == BMRun.OUT_OF_PLACEMENTS

	_refresh_jokers()
	_refresh_items()
	_seed_label.text = "Seed %d" % run.run_seed
	_refresh_status_banner()
	board_view.queue_redraw()


func _refresh_jokers(pulse: Array = []) -> void:
	BMUI.clear_children(_jokers_box)
	_jokers_header.text = "JOKERS  %d / %d   (resolve top to bottom)" % [run.jokers.size(), run.joker_slots()]
	var can_edit := run.can_act_in_round()
	for i in run.jokers.size():
		var id := run.jokers[i]
		var row := BMUI.hbox(6)
		var up := BMUI.button("Up", func() -> void: _do_action({"a": "move", "from": i, "to": i - 1}), 14)
		up.disabled = i == 0 or not can_edit
		var down := BMUI.button("Down", func() -> void: _do_action({"a": "move", "from": i, "to": i + 1}), 14)
		down.disabled = i == run.jokers.size() - 1 or not can_edit
		var sell := BMUI.button("Sell +%d" % BMJokers.sell_value(id), func() -> void: _confirm_sell(i), 14)
		sell.disabled = not can_edit
		row.add_child(up)
		row.add_child(down)
		row.add_child(sell)
		var card := BMUI.joker_card(run, id, row)
		_jokers_box.add_child(card)
		if pulse.has(id) and not main.settings.reduced_motion:
			card.pivot_offset = Vector2(200, 50)
			var tw := card.create_tween()
			card.modulate = Color(1.6, 1.5, 1.0)
			tw.tween_property(card, "modulate", Color.WHITE, 0.35)
	if run.jokers.is_empty():
		var l := BMUI.label("No Jokers yet. Buy them in the shop after a round.", 16, BMPalette.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_jokers_box.add_child(l)


func _refresh_items() -> void:
	BMUI.clear_children(_items_box)
	_items_header.text = "ITEMS  %d / %d" % [run.consumables.size(), BMRunConfig.CONSUMABLE_SLOTS]
	for i in run.consumables.size():
		var reason := run.consumable_usable(i)
		var use := BMUI.button("Use", func() -> void: _do_action({"a": "use", "i": i}), 16)
		use.disabled = reason != ""
		use.tooltip_text = reason if reason != "" else "Use this item now."
		_items_box.add_child(BMUI.item_card(run.consumables[i], use))


func _refresh_status_banner() -> void:
	BMUI.clear_children(_action_row)
	var rs := run.round_state
	if run.phase != BMRun.Phase.ROUND:
		return
	match rs.status:
		BMRun.STUCK:
			if run.refreshes_available() > 0:
				_set_message("No offered shape fits. Use Refresh to get a new tray.", BMPalette.BRASS)
			else:
				_set_message("No offered shape fits. Use an item that can help, or concede the round.", BMPalette.CORAL)
				_action_row.add_child(BMUI.button("Concede Round", _confirm_concede, 18))
		BMRun.OUT_OF_PLACEMENTS:
			_set_message("Out of placements. Use Extra Turn to continue, or concede.", BMPalette.CORAL)
			_action_row.add_child(BMUI.button("Concede Round", _confirm_concede, 18))


func _set_message(text: String, color: Color = BMPalette.TEXT) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)


# --- Input ---------------------------------------------------------------------------------

func _on_slot_pressed(slot: int) -> void:
	if not _input_enabled():
		return
	if held_slot == slot:
		_cancel_hold()
		return
	if run.tray[slot].is_empty():
		return
	held_slot = slot
	held_mode = "drag"
	_press_pos = _mouse
	_set_message("")
	_update_ghost_from_mouse()
	refresh_all()


func _input_enabled() -> bool:
	return run != null and run.can_place() and overlay.get_child_count() == 0 and not main.is_paused()


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse = event.position
	if run == null or held_slot < 0:
		return
	if event is InputEventMouseMotion:
		if held_mode == "key":
			held_mode = "sticky"
		_update_ghost_from_mouse()
		drag_layer.queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and held_mode == "drag":
		var moved := _mouse.distance_to(_press_pos) > 12.0
		if _mouse_over_board():
			if board_view.ghost_valid:
				_place_held(board_view.ghost_anchor)
			elif moved:
				_cancel_hold("That shape does not fit there. It went back to the tray.")
			else:
				held_mode = "sticky"
		elif moved:
			_cancel_hold()
		else:
			held_mode = "sticky"
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_hold()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and held_mode == "sticky" and _mouse_over_board():
		if board_view.ghost_valid:
			_place_held(board_view.ghost_anchor)
		else:
			_set_message("That shape does not fit there.", BMPalette.CORAL)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if run == null or main.is_paused():
		return
	if event is InputEventMouseButton and event.pressed:
		# Clicking empty space while holding a shape returns it to the tray.
		if event.button_index == MOUSE_BUTTON_LEFT and held_slot >= 0 and held_mode == "sticky":
			_cancel_hold()
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed:
		return
	if overlay.get_child_count() > 0:
		return
	if event.is_action("bm_cancel"):
		if held_slot >= 0:
			_cancel_hold()
		else:
			main.show_pause()
		get_viewport().set_input_as_handled()
		return
	for i in 3:
		if event.is_action("bm_slot_%d" % (i + 1)):
			_select_by_key(i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action("bm_refresh"):
		_do_action({"a": "refresh"})
		get_viewport().set_input_as_handled()
		return
	if held_slot < 0:
		return
	var move := Vector2i.ZERO
	if event.is_action("bm_left"):
		move = Vector2i.LEFT
	elif event.is_action("bm_right"):
		move = Vector2i.RIGHT
	elif event.is_action("bm_up"):
		move = Vector2i.UP
	elif event.is_action("bm_down"):
		move = Vector2i.DOWN
	if move != Vector2i.ZERO:
		held_mode = "key"
		var dims := BMShapes.shape_size(run.tray[held_slot])
		key_anchor = (key_anchor + move).clamp(Vector2i.ZERO, Vector2i(BMBoard.SIZE, BMBoard.SIZE) - dims)
		_show_ghost(key_anchor)
		get_viewport().set_input_as_handled()
	elif event.is_action("bm_place"):
		if board_view.ghost_valid:
			_place_held(board_view.ghost_anchor)
		else:
			_set_message("That shape does not fit there.", BMPalette.CORAL)
		get_viewport().set_input_as_handled()


func _select_by_key(slot: int) -> void:
	if not _input_enabled() or run.tray[slot].is_empty():
		return
	held_slot = slot
	held_mode = "key"
	var dims := BMShapes.shape_size(run.tray[slot])
	key_anchor = key_anchor.clamp(Vector2i.ZERO, Vector2i(BMBoard.SIZE, BMBoard.SIZE) - dims)
	board_view.keyboard_focus = true
	_show_ghost(key_anchor)
	refresh_all()


func _board_local_mouse() -> Vector2:
	return board_view.get_global_transform().affine_inverse() * _mouse


func _mouse_over_board() -> bool:
	var local := _board_local_mouse()
	var side := board_view.cell_size() * BMBoard.SIZE
	return Rect2(board_view.grid_origin(), Vector2(side, side)).grow(board_view.cell_size() * 0.6).has_point(local)


func _held_top_left_offset() -> Vector2:
	var dims := Vector2(BMShapes.shape_size(run.tray[held_slot]))
	return dims * board_view.cell_size() / 2.0


func _update_ghost_from_mouse() -> void:
	if held_slot < 0:
		return
	board_view.keyboard_focus = false
	if not _mouse_over_board():
		board_view.clear_ghost()
		_preview_label.text = ""
		return
	var top_left := _board_local_mouse() - _held_top_left_offset()
	var anchor := board_view.anchor_from_top_left(top_left)
	key_anchor = anchor
	_show_ghost(anchor)


func _show_ghost(anchor: Vector2i) -> void:
	board_view.set_ghost(run.tray[held_slot], anchor)
	var key := "%d:%s" % [held_slot, anchor]
	if key == _preview_cache_key:
		return
	_preview_cache_key = key
	if board_view.ghost_valid:
		var p := run.preview_place(held_slot, anchor)
		if p.ok:
			var lines_text := "" if p.lines == 0 else "   %d line%s" % [p.lines, "s" if p.lines > 1 else ""]
			_preview_label.text = "%s Chips x %s Mult = %s%s" % [BMUI.fmt_int(p.chips), BMUI.fmt_mult(p.mult), BMUI.fmt_int(p.points), lines_text]
	else:
		_preview_label.text = ""


func _cancel_hold(message: String = "") -> void:
	held_slot = -1
	held_mode = ""
	_preview_cache_key = ""
	if board_view:
		board_view.keyboard_focus = false
		board_view.clear_ghost()
	if _preview_label:
		_preview_label.text = ""
	if message != "":
		_set_message(message, BMPalette.CORAL)
	if drag_layer:
		drag_layer.queue_redraw()
	if run != null and slots.size() == 3:
		for i in 3:
			slots[i].setup(run.tray[i], false, run.slot_fits(i))
			slots[i].focused_by_key = false


func _draw_drag_layer() -> void:
	if held_slot < 0 or held_mode == "key" or run == null or run.tray[held_slot].is_empty():
		return
	var cell := board_view.cell_size()
	var top_left := drag_layer.get_global_transform().affine_inverse() * _mouse - _held_top_left_offset()
	var shape: Dictionary = run.tray[held_slot]
	var alpha := 0.35 if board_view.ghost_valid else 0.85
	for c: Vector2i in shape.cells:
		drag_layer.draw_rect(Rect2(top_left + Vector2(c) * cell + Vector2(8, 10), Vector2(cell, cell)), Color(0, 0, 0, 0.25 * alpha))
	BMBlockPainter.draw_shape(drag_layer, shape, top_left, cell, alpha)


# --- Actions -------------------------------------------------------------------------------

func _place_held(anchor: Vector2i) -> void:
	var slot := held_slot
	_cancel_hold()
	_do_action({"a": "place", "slot": slot, "x": anchor.x, "y": anchor.y})


func _do_action(a: Dictionary) -> void:
	if run == null:
		return
	var r: Dictionary = main.act(a)
	if not r.ok:
		_set_message(r.error, BMPalette.CORAL)
		return
	_set_message("")
	match r.get("type", ""):
		"place":
			_present_placement(r)
		"refresh":
			_set_message(", ".join(PackedStringArray(r.get("events", []))), BMPalette.CYAN)
		"use":
			_set_message("Used %s." % BMConsumables.get_def(r.item).name, BMPalette.CYAN)
		"sell":
			_set_message("Sold %s for %d Credits." % [BMJokers.get_def(r.item).name, r.value], BMPalette.BRASS)
	var tray_events: Array = r.get("tray_events", [])
	for e in tray_events:
		if String(e).begins_with("Tiny Insurance"):
			_set_message(e, BMPalette.BRASS)
	refresh_all()
	if r.get("type", "") == "place":
		_refresh_jokers(r.triggered_jokers)
	_maybe_show_phase_overlay(0.0 if main.settings.reduced_motion else 0.6)


func _present_placement(r: Dictionary) -> void:
	_last_result = r
	board_view.play_resolution(r, main.settings.reduced_motion)
	_write_receipt(r)
	_score_popup(r)
	if r.lines >= 2 and not main.settings.reduced_motion:
		_shake(4.0 + 2.0 * r.lines)


func _write_receipt(r: Dictionary) -> void:
	var t := ""
	t += "[b]%s[/b]  (%d cell%s, %s)\n" % [BMShapes.family(r.shape.family).name, r.placed.size(), "s" if r.placed.size() != 1 else "", BMShapes.COLOR_NAMES[r.shape.color]]
	var chips_hex := BMPalette.CHIPS.to_html(false)
	var mult_hex := BMPalette.MULT.to_html(false)
	for it in r.items:
		match it.kind:
			"chips":
				t += "%s  [color=#%s]+%s Chips[/color]\n" % [it.label, chips_hex, BMUI.fmt_int(it.value)]
			"mult":
				t += "%s  [color=#%s]+%s Mult[/color]\n" % [it.label, mult_hex, BMUI.fmt_mult(it.value)]
			"xmult":
				t += "%s  [color=#%s]x%s Mult[/color]\n" % [it.label, mult_hex, BMUI.fmt_mult(it.value)]
	if not r.mirror_cleared.is_empty():
		t += "Mirror Maze removed %d cell(s)\n" % r.mirror_cleared.size()
	t += "\n[b][color=#%s]%s Chips[/color] x [color=#%s]%s Mult[/color] = %s[/b]" % [chips_hex, BMUI.fmt_int(r.chips), mult_hex, BMUI.fmt_mult(r.mult), BMUI.fmt_int(r.points)]
	if r.combo_after > 0:
		t += "\nCombo now x%d" % r.combo_after
	_receipt.text = t


func _score_popup(r: Dictionary) -> void:
	var center := Vector2.ZERO
	for p: Vector2i in r.placed:
		center += board_view.cell_rect(p).get_center()
	center /= maxf(1.0, r.placed.size())
	var l := BMUI.label("+%s" % BMUI.fmt_int(r.points), 34 + mini(30, r.lines * 8), BMPalette.BRASS if r.lines > 0 else BMPalette.TEXT)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.global_position = board_view.global_position + center - Vector2(40, 30)
	if main.settings.reduced_motion:
		var tw0 := l.create_tween()
		tw0.tween_interval(0.6)
		tw0.tween_callback(l.queue_free)
		return
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y - 70, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


func _shake(strength: float) -> void:
	var tw := board_view.create_tween()
	var base := board_view.position
	for i in 5:
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * (1.0 - i / 5.0)
		tw.tween_property(board_view, "position", base + off, 0.03)
	tw.tween_property(board_view, "position", base, 0.03)


func _confirm_sell(index: int) -> void:
	var id := run.jokers[index]
	_show_dialog("Sell %s for %d Credits?" % [BMJokers.get_def(id).name, BMJokers.sell_value(id)],
		[["Sell", func() -> void: _do_action({"a": "sell", "i": index})], ["Keep", func() -> void: pass]])


func _confirm_concede() -> void:
	_show_dialog("Concede this round? The run will end.",
		[["Concede", func() -> void: _do_action({"a": "concede"})], ["Back", func() -> void: pass]])


# --- Overlays ------------------------------------------------------------------------------

func _maybe_show_phase_overlay(delay: float = 0.0) -> void:
	if run == null:
		return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if overlay.get_child_count() > 0:
		return
	match run.phase:
		BMRun.Phase.ROUND:
			if _intro_shown_for != run.round_number and run.round_state.placements_made == 0:
				_intro_shown_for = run.round_number
				_show_round_intro()
		BMRun.Phase.ROUND_RESULT:
			_show_round_result()
		BMRun.Phase.RUN_WON, BMRun.Phase.RUN_LOST, BMRun.Phase.ABANDONED:
			_show_run_end()


func _overlay_panel(edge: Color = BMPalette.CYAN) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var p := BMUI.panel(BMPalette.PANEL, edge)
	p.custom_minimum_size = Vector2(620, 0)
	center.add_child(p)
	var v := BMUI.vbox(12)
	p.add_child(v)
	if not main.settings.reduced_motion:
		p.modulate.a = 0.0
		p.create_tween().tween_property(p, "modulate:a", 1.0, 0.18)
	return v


func close_overlay() -> void:
	BMUI.clear_children(overlay)


func _show_dialog(text: String, buttons: Array) -> void:
	var v := _overlay_panel(BMPalette.BRASS)
	var l := BMUI.label(text, 24)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var row := BMUI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var first: Button
	for b in buttons:
		var cb: Callable = b[1]
		var btn := BMUI.button(b[0], func() -> void:
			close_overlay()
			cb.call())
		row.add_child(btn)
		if first == null:
			first = btn
	first.grab_focus.call_deferred()


func _show_round_intro() -> void:
	var boss := run.current_boss()
	var v := _overlay_panel(BMPalette.CORAL if boss != "" else BMPalette.CYAN)
	v.add_child(BMUI.label("ROUND %d  /  ACT %d" % [run.round_number, run.act()], 20, BMPalette.TEXT_DIM))
	v.add_child(BMUI.label("TARGET  %s" % BMUI.fmt_int(run.round_state.target), 44, BMPalette.BRASS))
	v.add_child(BMUI.label("%d placements   %d Refresh" % [run.round_state.placements_left, run.refreshes_available()], 22))
	if boss != "":
		var d := BMBosses.get_def(boss)
		v.add_child(BMUI.label("BOSS: " + d.name, 28, BMPalette.CORAL))
		var rule := BMUI.label(d.rule, 20)
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(rule)
		var tip := BMUI.label("Counterplay: " + d.counter, 17, BMPalette.TEXT_DIM)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(tip)
		var disabled: Array[String] = []
		for id in run.jokers:
			if not run.is_joker_active(id):
				disabled.append(BMJokers.get_def(id).name)
		if not disabled.is_empty():
			v.add_child(BMUI.label("Disabled this round: " + ", ".join(disabled), 17, BMPalette.CORAL))
	elif run.round_number % BMRunConfig.ROUNDS_PER_ACT == 1:
		var d := BMBosses.get_def(run.act_boss())
		v.add_child(BMUI.label("This act's boss (round %d): %s" % [run.act() * 4, d.name], 20, BMPalette.CORAL))
		var rule := BMUI.label(d.rule, 17, BMPalette.TEXT_DIM)
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(rule)
	var b := BMUI.button("Start Round", close_overlay, 24)
	v.add_child(b)
	b.grab_focus.call_deferred()


func _show_round_result() -> void:
	var res := run.last_round_result
	var v := _overlay_panel(BMPalette.BRASS)
	v.add_child(BMUI.label("ROUND %d CLEARED" % res.round, 40, BMPalette.BRASS))
	v.add_child(BMUI.label("%s / %s points   %d placement(s) unused" % [BMUI.fmt_int(res.score), BMUI.fmt_int(res.target), res.unused], 22))
	for line in res.credit_lines:
		v.add_child(BMUI.label("%s   +%d Credits" % [line.label, line.value], 20, BMPalette.TEXT_DIM))
	v.add_child(BMUI.label("Credits now: %d" % run.credits, 24, BMPalette.BRASS))
	var last: bool = res.round >= BMRunConfig.ROUND_COUNT
	var b := BMUI.button("Finish Run" if last else "Continue to Shop", func() -> void:
		close_overlay()
		main.act({"a": "continue"}), 24)
	v.add_child(b)
	b.grab_focus.call_deferred()


func _show_run_end() -> void:
	var won := run.phase == BMRun.Phase.RUN_WON
	var v := _overlay_panel(BMPalette.BRASS if won else BMPalette.CORAL)
	v.add_child(BMUI.label("RUN COMPLETE" if won else ("RUN ABANDONED" if run.phase == BMRun.Phase.ABANDONED else "RUN OVER"), 44, BMPalette.BRASS if won else BMPalette.CORAL))
	var reason := BMUI.label(run.end_reason, 22)
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(reason)
	var s := run.stats
	v.add_child(BMUI.label("Reached round %d   Seed %d" % [run.round_number, run.run_seed], 20, BMPalette.TEXT_DIM))
	v.add_child(BMUI.label("Lines %d   Best placement %s   Highest combo x%d" % [s.lines_cleared, BMUI.fmt_int(s.best_placement), s.highest_combo], 20, BMPalette.TEXT_DIM))
	var names := PackedStringArray()
	for id in run.jokers:
		names.append(BMJokers.get_def(id).name)
	if names.size() > 0:
		var build := BMUI.label("Build: " + ", ".join(names), 18, BMPalette.TEXT_DIM)
		build.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(build)
	var row := BMUI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var again := BMUI.button("New Run", func() -> void:
		close_overlay()
		main.start_new_run(BMRun.random_seed()), 22)
	row.add_child(again)
	row.add_child(BMUI.button("Same Seed", func() -> void:
		close_overlay()
		main.start_new_run(run.run_seed), 22))
	row.add_child(BMUI.button("Title", func() -> void:
		close_overlay()
		main.show_title(), 22))
	again.grab_focus.call_deferred()
