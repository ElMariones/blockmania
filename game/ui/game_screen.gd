class_name BMGameScreen
extends Control
## Round screen ("the cabinet"): marquee on top, board center, score machine + receipt left,
## Joker rack + items right, tray and the Refresh button below. Layout is a fixed 1920x1080
## stage centered in any aspect ratio. Input: drag-and-release, click-to-hold then click board,
## or keyboard (1-3, arrows/WASD, Enter/Space, R, B, Esc). All actions go through main.act().

const STAGE := Vector2(1920, 1080)

var main: Node ## BMMain
var run: BMRun

var stage: Control
var board_view: BMBoardView
var slots: Array[BMTraySlot] = []
var refresh_button: Button
var drag_layer: Control
var overlay: Control

var _marquee: BMHud.Marquee
var _score: BMHud.Counter
var _target_label: Label
var _tube: BMHud.Tube
var _preview_box: HBoxContainer
var _preview_hint: Label
var _lamps: BMHud.Lamps
var _moves_label: Label
var _refresh_count: Label
var _combo_label: Label
var _combo_icon: TextureRect
var _credits: BMHud.Counter
var _boss_panel: PanelContainer
var _boss_box: VBoxContainer
var _receipt: BMHud.Receipt
## Stuck with no Refresh: the Refresh button becomes Concede.
var _concede_mode := false
var _last_status := ""
var _jokers_header: Label
var _jokers_box: VBoxContainer
var _items_header: Label
var _items_box: HBoxContainer
var _bag_button: Button
var _joker_cards: Array[BMCard] = []

# Held-shape state.
var held_slot := -1
var held_mode := "" ## "drag", "sticky", or "key"
var key_anchor := Vector2i(3, 3)
var _press_pos := Vector2.ZERO
## Pointer position in canvas coordinates, tracked from input events (works for real and
## simulated input alike, and after the CRT remap).
var _mouse := Vector2.ZERO
var _preview_cache_key := ""
var _intro_shown_for := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	resized.connect(_center_stage)
	_center_stage()


func _center_stage() -> void:
	if stage:
		stage.position = ((size - STAGE) / 2.0).round()


func _at(c: Control, pos: Vector2, sz: Vector2) -> Control:
	c.position = pos
	c.size = sz
	c.custom_minimum_size = Vector2.ZERO
	stage.add_child(c)
	return c


func _build() -> void:
	stage = Control.new()
	stage.size = STAGE
	stage.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(stage)

	# --- Marquee and board ---
	_marquee = BMHud.Marquee.new()
	_at(_marquee, Vector2(576, 6), Vector2(768, 72))
	board_view = BMBoardView.new()
	_at(board_view, Vector2(568, 82), Vector2(784, 784))

	# --- Tray ---
	for i in 3:
		var s := BMTraySlot.new()
		s.slot = i
		s.pressed.connect(_on_slot_pressed)
		_at(s, Vector2(560 + i * 212, 878), Vector2(200, 176))
		slots.append(s)
	refresh_button = BMStyle.button("", _on_refresh_button, "mint", 20)
	refresh_button.icon = BMStyle.tex("icon_refresh")
	refresh_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	refresh_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	refresh_button.tooltip_text = "Refresh (R): replace every unplaced piece in the tray. Costs no placement."
	_at(refresh_button, Vector2(1196, 878), Vector2(164, 176))

	# --- Left: score machine ---
	var score_panel := BMStyle.panel("panel_plate", Vector4(-6, -8, -6, -12))
	_at(score_panel, Vector2(36, 12), Vector2(508, 380))
	var sv := BMStyle.vbox(4)
	score_panel.add_child(sv)
	var srow := BMStyle.hbox(10)
	sv.add_child(srow)
	srow.add_child(BMStyle.pill("SCORE", "sun", 20))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(sp)
	srow.add_child(BMStyle.icon_rect("icon_target", 0.75))
	_target_label = BMStyle.label("", 30, BMStyle.PINK_L, true, 8)
	srow.add_child(_target_label)
	_score = BMHud.Counter.new()
	_score.add_theme_font_override("font", BMStyle.font_bold)
	_score.add_theme_font_size_override("font_size", 80)
	_score.add_theme_color_override("font_color", BMStyle.CREAM)
	_score.add_theme_color_override("font_outline_color", BMStyle.INK)
	_score.add_theme_constant_override("outline_size", 14)
	_score.add_theme_color_override("font_shadow_color", Color(BMStyle.PINK, 0.6))
	_score.add_theme_constant_override("shadow_offset_x", 0)
	_score.add_theme_constant_override("shadow_offset_y", 6)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score.text = "0"
	sv.add_child(_score)
	_tube = BMHud.Tube.new()
	_tube.custom_minimum_size = Vector2(0, 36)
	sv.add_child(_tube)
	var prev_panel := BMStyle.panel("panel_inset", Vector4(4, 0, 4, 0))
	prev_panel.custom_minimum_size = Vector2(0, 76)
	sv.add_child(prev_panel)
	var pc := CenterContainer.new()
	prev_panel.add_child(pc)
	var pstack := BMStyle.vbox(0)
	pc.add_child(pstack)
	_preview_box = BMStyle.hbox(8)
	_preview_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pstack.add_child(_preview_box)
	_preview_hint = BMStyle.label("Pick up a piece to preview its score", 20, BMStyle.TEXT_DIM)
	_preview_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pstack.add_child(_preview_hint)
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 12)
	stats.add_theme_constant_override("v_separation", 2)
	sv.add_child(stats)
	var moves_row := BMStyle.hbox(6)
	moves_row.add_child(BMStyle.icon_rect("icon_hand", 0.75))
	_moves_label = BMStyle.label("", 30, BMStyle.CREAM, true, 8)
	moves_row.add_child(_moves_label)
	moves_row.tooltip_text = "Placements left this round"
	stats.add_child(moves_row)
	_lamps = BMHud.Lamps.new()
	_lamps.custom_minimum_size = Vector2(360, 40)
	_lamps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(_lamps)
	var misc := BMStyle.hbox(18)
	sv.add_child(misc)
	var ref_row := BMStyle.hbox(6)
	ref_row.add_child(BMStyle.icon_rect("icon_refresh", 0.75))
	_refresh_count = BMStyle.label("", 30, BMStyle.MINT_L, true, 8)
	ref_row.add_child(_refresh_count)
	misc.add_child(ref_row)
	var combo_row := BMStyle.hbox(6)
	_combo_icon = BMStyle.icon_rect("icon_flame", 0.75)
	combo_row.add_child(_combo_icon)
	_combo_label = BMStyle.label("", 30, BMStyle.PINK_L, true, 8)
	combo_row.add_child(_combo_label)
	misc.add_child(combo_row)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	misc.add_child(sp2)
	var cred_row := BMStyle.hbox(6)
	cred_row.add_child(BMStyle.icon_rect("icon_coin", 0.75))
	_credits = BMHud.Counter.new()
	_credits.add_theme_font_override("font", BMStyle.font_bold)
	_credits.add_theme_font_size_override("font_size", 30)
	_credits.add_theme_color_override("font_color", BMStyle.SUN)
	_credits.add_theme_color_override("font_outline_color", BMStyle.INK)
	_credits.add_theme_constant_override("outline_size", 8)
	cred_row.add_child(_credits)
	misc.add_child(cred_row)

	# --- Left: boss + receipt ---
	_boss_panel = BMStyle.panel("panel_plate", Vector4(8, 2, 8, 2))
	_at(_boss_panel, Vector2(36, 400), Vector2(508, 152))
	_boss_box = BMStyle.vbox(2)
	_boss_panel.add_child(_boss_box)
	_receipt = BMHud.Receipt.new()
	_at(_receipt, Vector2(52, 562), Vector2(476, 480))

	# --- Right: Jokers, items, buttons ---
	var jh := BMStyle.hbox(8)
	_at(jh, Vector2(1376, 16), Vector2(508, 40))
	_jokers_header = BMStyle.header("JOKERS", 30)
	jh.add_child(_jokers_header)
	var hint := BMStyle.label("drag to reorder  |  top first", 20, BMStyle.TEXT_DIM, false, 6)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	jh.add_child(hint)
	_jokers_box = BMStyle.vbox(8)
	_at(_jokers_box, Vector2(1376, 64), Vector2(508, 652))
	_items_header = BMStyle.header("ITEMS", 30)
	_at(_items_header, Vector2(1376, 728), Vector2(508, 40))
	_items_box = BMStyle.hbox(12)
	_at(_items_box, Vector2(1376, 772), Vector2(508, 184))
	_bag_button = BMStyle.button("BAG", _show_bag, "sky", 30)
	_bag_button.icon = BMStyle.tex("icon_bag")
	_bag_button.tooltip_text = "See every piece in your bag: draw pile, tray, and discard pile. (B)"
	_at(_bag_button, Vector2(1376, 966), Vector2(300, 80))
	var pause := BMStyle.button("MENU", func() -> void: main.show_pause(), "plum", 20)
	pause.icon = BMStyle.tex("icon_gear")
	pause.tooltip_text = "Pause, settings and controls (Esc)"
	_at(pause, Vector2(1690, 966), Vector2(190, 80))

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
	_apply_motion()
	_cancel_hold()
	_score.set_target(run.round_state.score, true)
	_credits.set_target(run.credits, true)
	_tube.value = 0.0
	refresh_all()
	_receipt.print_rows([{"text": "Round %d. Good luck!" % run.round_number, "color": Color(BMStyle.INK, 0.6)}])
	if BMSwirlBackground.instance:
		BMSwirlBackground.instance.set_mood("boss" if run.current_boss() != "" else "round")
	_maybe_show_phase_overlay()


func _apply_motion() -> void:
	var rm: bool = main.settings.reduced_motion
	board_view.reduced_motion = rm
	_marquee.reduced_motion = rm
	_tube.reduced_motion = rm
	_score.reduced_motion = rm
	_credits.reduced_motion = rm
	_receipt.reduced_motion = rm
	for s in slots:
		s.reduced_motion = rm


func refresh_all() -> void:
	if run == null:
		return
	var rs := run.round_state
	var boss := run.current_boss()
	_marquee.boss = boss != ""
	_marquee.text = "ROUND %d" % run.round_number
	_marquee.sub = ("BOSS: " + BMBosses.get_def(boss).name.to_upper()) if boss != "" else "ACT %d OF 3" % run.act()
	_target_label.text = "/ " + BMUI.fmt_int(rs.target)
	_score.set_target(rs.score)
	_tube.set_fraction(float(rs.score) / maxf(1.0, rs.target))
	_moves_label.text = str(rs.placements_left)
	_moves_label.add_theme_color_override("font_color", BMStyle.PINK_L if rs.placements_left <= 3 else BMStyle.CREAM)
	_lamps.set_counts(rs.placements_left, maxi(rs.placements_left + rs.placements_made, int(run.kit().placements)))
	if boss == "lockdown":
		_refresh_count.text = "LOCKED"
	else:
		_refresh_count.text = "x%d" % rs.refreshes_left
	_combo_label.text = "x%d" % rs.combo
	_combo_icon.modulate = Color.WHITE if rs.combo > 0 else Color(1, 1, 1, 0.35)
	_combo_label.modulate = Color.WHITE if rs.combo > 0 else Color(1, 1, 1, 0.5)
	_credits.set_target(run.credits)

	BMUI.clear_children(_boss_box)
	_boss_panel.add_theme_stylebox_override("panel", BMStyle.box("panel_boss" if boss != "" else "panel_plate", Vector4(8, 2, 8, 2)))
	var head := BMStyle.hbox(8)
	_boss_box.add_child(head)
	head.add_child(BMStyle.icon_rect("icon_skull", 0.75))
	if boss != "":
		var d := BMBosses.get_def(boss)
		head.add_child(BMStyle.label("BOSS: " + d.name.to_upper(), 20, BMStyle.PINK_L, true, 6))
		var rule := BMStyle.label(d.rule, 20, BMStyle.CREAM)
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_boss_box.add_child(rule)
	else:
		var d := BMBosses.get_def(run.act_boss())
		head.add_child(BMStyle.label("ROUND %d BOSS: %s" % [run.act() * 4, d.name.to_upper()], 20, BMStyle.PINK_L, true, 6))
		var rule := BMStyle.label(d.rule, 20, BMStyle.TEXT_DIM)
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_boss_box.add_child(rule)

	for i in 3:
		slots[i].setup(run.tray[i], held_slot == i, run.slot_fits(i))
		slots[i].focused_by_key = held_mode == "key" and held_slot == i
		slots[i].tooltip_text = BMPieces.describe(run.tray[i]) if not run.tray[i].is_empty() else ""
	_concede_mode = run.phase == BMRun.Phase.ROUND and (rs.status == BMRun.OUT_OF_PLACEMENTS or (rs.status == BMRun.STUCK and run.refreshes_available() <= 0))
	if _concede_mode:
		BMStyle.button_boxes(refresh_button, "pink")
		refresh_button.icon = BMStyle.tex("icon_skull")
		refresh_button.text = "CONCEDE\nROUND"
		refresh_button.disabled = false
		refresh_button.tooltip_text = "No legal move is left. Use an item that can help, or concede to end the run."
	else:
		BMStyle.button_boxes(refresh_button, "mint")
		refresh_button.icon = BMStyle.tex("icon_refresh")
		refresh_button.text = "REFRESH\n" + ("LOCKED" if boss == "lockdown" else "x%d" % rs.refreshes_left)
		refresh_button.disabled = run.refreshes_available() <= 0 or not run.can_act_in_round() or rs.status == BMRun.OUT_OF_PLACEMENTS
		refresh_button.tooltip_text = "Refresh (R): replace every unplaced piece in the tray. Costs no placement."

	_refresh_jokers()
	_refresh_items()
	_bag_button.text = "BAG  %d" % run.draw_pile.size()
	_bag_button.tooltip_text = "Your bag: %d pieces. Draw pile %d, discard pile %d. (B)" % [run.bag.size(), run.draw_pile.size(), run.discard_pile.size()]
	_refresh_status_banner()
	board_view.queue_redraw()


func _refresh_jokers() -> void:
	BMUI.clear_children(_jokers_box)
	_joker_cards.clear()
	_jokers_header.text = "JOKERS %d/%d" % [run.jokers.size(), run.joker_slots()]
	var can_edit := run.can_act_in_round()
	for i in run.jokers.size():
		var id := run.jokers[i]
		var card := BMCard.joker_rack(run, id)
		card.reduced_motion = main.settings.reduced_motion
		card.drag_index = i
		card.drag_enabled = can_edit
		card.drag_receiver = func(from: int, to: int) -> void:
			if to >= 0 and to < run.jokers.size():
				_do_action({"a": "move", "from": from, "to": to})
				if to < _joker_cards.size():
					BMStyle.focus_later(_joker_cards[to])
		card.tooltip_body += "\nDrag onto another Joker to reorder. Alt+Up/Down while focused also moves it."
		var ctrl := _joker_controls(i, id, can_edit)
		card.hover_controls = ctrl
		ctrl.visible = false
		card.add_child(ctrl)
		_jokers_box.add_child(card)
		_joker_cards.append(card)
	for i in range(run.jokers.size(), run.joker_slots()):
		var empty := BMStyle.panel("panel_inset", Vector4.ZERO)
		empty.custom_minimum_size = Vector2(0, 124)
		var l := BMStyle.label("empty slot", 20, Color(BMStyle.TEXT_DIM, 0.5))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_child(l)
		_jokers_box.add_child(empty)


## Floating toolbar shown while hovering a Joker: selling stays a button; drag to reorder.
func _joker_controls(i: int, id: String, can_edit: bool) -> Control:
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bar := BMStyle.hbox(4)
	wrap.add_child(bar)
	var sell := BMStyle.button("SELL +%d" % BMJokers.sell_value(id), func() -> void: _confirm_sell(i), "pink", 20)
	sell.disabled = not can_edit
	bar.add_child(sell)
	wrap.resized.connect(func() -> void:
		bar.reset_size()
		bar.position = Vector2(wrap.size.x - bar.size.x - 10, wrap.size.y - bar.size.y - 8))
	return wrap


func _refresh_items() -> void:
	BMUI.clear_children(_items_box)
	_items_header.text = "ITEMS %d/%d" % [run.consumables.size(), BMRunConfig.CONSUMABLE_SLOTS]
	for i in run.consumables.size():
		var reason := run.consumable_usable(i)
		var card := BMCard.item_rack(run.consumables[i])
		card.custom_minimum_size = Vector2(248, 180)
		var box := card.get_child(0) as VBoxContainer
		var body := BMStyle.label(BMConsumables.get_def(run.consumables[i]).text, 20, Color(BMStyle.INK, 0.75))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.max_lines_visible = 2
		body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(body)
		var use := BMStyle.button("USE", func() -> void: _do_action({"a": "use", "i": i}), "mint", 20)
		use.disabled = reason != ""
		use.tooltip_text = reason if reason != "" else "Use this item now."
		box.add_child(use)
		_items_box.add_child(card)
	for i in range(run.consumables.size(), BMRunConfig.CONSUMABLE_SLOTS):
		var empty := BMStyle.panel("panel_inset", Vector4.ZERO)
		empty.custom_minimum_size = Vector2(248, 180)
		var l := BMStyle.label("empty", 20, Color(BMStyle.TEXT_DIM, 0.5))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_child(l)
		_items_box.add_child(empty)


func _refresh_status_banner() -> void:
	var rs := run.round_state
	if run.phase != BMRun.Phase.ROUND:
		_last_status = ""
		return
	if rs.status != _last_status and rs.status in [BMRun.STUCK, BMRun.OUT_OF_PLACEMENTS]:
		BMAudio.sfx("alert")
	_last_status = rs.status
	match rs.status:
		BMRun.STUCK:
			if run.refreshes_available() > 0:
				_set_message("NOTHING FITS!  HIT REFRESH", BMStyle.SUN, 0.0)
			else:
				_set_message("NOTHING FITS!  USE AN ITEM OR CONCEDE", BMStyle.PINK_L, 0.0)
		BMRun.OUT_OF_PLACEMENTS:
			_set_message("OUT OF PLACEMENTS!  EXTRA TURN OR CONCEDE", BMStyle.PINK_L, 0.0)
		_:
			if _marquee.message.begins_with("NOTHING FITS") or _marquee.message.begins_with("OUT OF"):
				_marquee.message = ""


## Messages flash on the marquee sign so they never cover board cells.
## duration 0 = stays until replaced.
func _set_message(text: String, color: Color = BMStyle.CREAM, duration: float = 2.6) -> void:
	if text == "":
		return
	_marquee.flash(text.to_upper(), color, duration)


func _on_refresh_button() -> void:
	if _concede_mode:
		_confirm_concede()
	else:
		_do_action({"a": "refresh"})


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
	BMAudio.sfx("pickup")
	_press_pos = _mouse
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
				_cancel_hold("That piece doesn't fit there, so it went back to the tray.")
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
			_set_message("That piece doesn't fit there.", BMStyle.PINK_L)
			BMAudio.sfx("deny")
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
		if event.is_action("bm_cancel") and _bag_open():
			close_overlay()
			get_viewport().set_input_as_handled()
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
	if event.is_action("bm_bag"):
		_cancel_hold()
		_show_bag()
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
		BMAudio.sfx("key_move", 1.0 if board_view.ghost_valid else 0.8)
		get_viewport().set_input_as_handled()
	elif event.is_action("bm_place"):
		if board_view.ghost_valid:
			_place_held(board_view.ghost_anchor)
		else:
			_set_message("That piece doesn't fit there.", BMStyle.PINK_L)
			BMAudio.sfx("deny")
		get_viewport().set_input_as_handled()


func _select_by_key(slot: int) -> void:
	if not _input_enabled() or run.tray[slot].is_empty():
		return
	held_slot = slot
	held_mode = "key"
	BMAudio.sfx("pickup")
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
		_preview_cache_key = ""
		_show_preview({})
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
		_show_preview(run.preview_place(held_slot, anchor))
	else:
		_show_preview({"invalid": true})


## Score preview: [chip] chips x [mult] mult = points (+ lines tag).
func _show_preview(p: Dictionary) -> void:
	BMUI.clear_children(_preview_box)
	if p.get("invalid", false):
		_preview_hint.text = "Doesn't fit here"
		_preview_hint.add_theme_color_override("font_color", BMStyle.PINK_L)
		_preview_hint.visible = true
		return
	if p.is_empty() or not p.get("ok", false):
		_preview_hint.text = "Pick up a piece to preview its score" if held_slot < 0 else "Move over the board"
		_preview_hint.add_theme_color_override("font_color", BMStyle.TEXT_DIM)
		_preview_hint.visible = true
		return
	_preview_hint.visible = false
	_preview_box.add_child(BMStyle.icon_rect("icon_chip", 0.75))
	_preview_box.add_child(BMStyle.label(BMUI.fmt_int(p.chips), 30, BMStyle.CHIPS, true, 8))
	_preview_box.add_child(BMStyle.label("x", 30, BMStyle.CREAM, true, 8))
	_preview_box.add_child(BMStyle.icon_rect("icon_mult", 0.75))
	_preview_box.add_child(BMStyle.label(BMUI.fmt_mult(p.mult), 30, BMStyle.MULT, true, 8))
	_preview_box.add_child(BMStyle.label("=", 30, BMStyle.CREAM, true, 8))
	_preview_box.add_child(BMStyle.label(BMUI.fmt_int(p.points), 30, BMStyle.SUN, true, 8))
	if p.lines > 0:
		_preview_box.add_child(BMStyle.pill("%d LINE%s" % [p.lines, "S" if p.lines > 1 else ""], "mint", 20))


## Drops the held piece back into the tray. `sound` is false when the piece is being placed.
func _cancel_hold(message: String = "", sound: bool = true) -> void:
	if held_slot >= 0 and sound:
		BMAudio.sfx("deny" if message != "" else "putback")
	held_slot = -1
	held_mode = ""
	_preview_cache_key = ""
	if board_view:
		board_view.keyboard_focus = false
		board_view.clear_ghost()
	if _preview_box:
		_show_preview({})
	if message != "":
		_set_message(message, BMStyle.PINK_L)
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
	var local_mouse := drag_layer.get_global_transform().affine_inverse() * _mouse
	var shape: Dictionary = run.tray[held_slot]
	if board_view.ghost_valid:
		# The snapped ghost is the real preview; the hand only carries a small token beside
		# the cursor so the two never overlap into a double image.
		var tcell := floorf(cell * 0.4)
		BMBlockPainter.draw_shape(drag_layer, shape, (local_mouse + Vector2(18, 18)).round(), tcell, 0.9)
		return
	var top_left := local_mouse - _held_top_left_offset()
	var alpha := 0.95
	for c: Vector2i in shape.cells:
		drag_layer.draw_rect(Rect2(top_left + Vector2(c) * cell + Vector2(10, 14), Vector2(cell, cell)), Color(BMStyle.INK, 0.4 * alpha))
	BMBlockPainter.draw_shape(drag_layer, shape, top_left, cell, alpha)


# --- Actions -------------------------------------------------------------------------------

func _place_held(anchor: Vector2i) -> void:
	var slot := held_slot
	_cancel_hold("", false)
	_do_action({"a": "place", "slot": slot, "x": anchor.x, "y": anchor.y})


func _do_action(a: Dictionary) -> void:
	if run == null:
		return
	var r: Dictionary = main.act(a)
	if not r.ok:
		_set_message(r.error, BMStyle.PINK_L)
		BMAudio.sfx("deny")
		return
	match r.get("type", ""):
		"place":
			_present_placement(r)
			if not r.events.is_empty():
				_set_message("  ".join(PackedStringArray(r.events)), BMStyle.SUN)
		"refresh":
			_set_message(", ".join(PackedStringArray(r.get("events", []))), BMStyle.MINT_L)
			BMAudio.sfx("refresh")
			_play_deal(0.2)
			if BMFx.instance:
				for s in slots:
					BMFx.instance.stars(s.get_global_rect().get_center(), 3, 60.0)
		"use":
			_set_message("Used %s." % BMConsumables.get_def(r.item).name, BMStyle.MINT_L)
			BMAudio.sfx("item")
		"sell":
			_set_message("Sold %s for %d Credits." % [BMJokers.get_def(r.item).name, r.value], BMStyle.SUN)
			BMAudio.sfx("sell")
	var tray_events: Array = r.get("tray_events", [])
	if tray_events.has("New tray"):
		_play_deal(0.45)
	for e in tray_events:
		if String(e).begins_with("Tiny Insurance") or String(e).begins_with("No piece"):
			_set_message(e, BMStyle.SUN)
	refresh_all()
	if r.get("type", "") == "place":
		_animate_jokers(r)
	_maybe_show_phase_overlay(0.0 if main.settings.reduced_motion else 0.9)


func _present_placement(r: Dictionary) -> void:
	board_view.play_resolution(r)
	_write_receipt(r)
	_play_placement_sounds(r)
	var fx := BMFx.instance
	var center := Vector2.ZERO
	for p: Vector2i in r.placed:
		center += board_view.cell_global_center(p)
	center /= maxf(1.0, r.placed.size())
	if fx:
		var size_px := 40 if r.points < 300 else (60 if r.points < 1200 else 80)
		fx.pop_text(center + Vector2(0, -30), "+" + BMUI.fmt_int(r.points), BMStyle.SUN if r.lines > 0 else BMStyle.CREAM, size_px, 90.0, 1.0)
		fx.stream(center, _score.get_global_rect().get_center(), BMStyle.SUN, mini(18, 4 + r.lines * 5))
		if r.credits_gained > 0:
			fx.coins(center, _credits.get_global_rect().get_center(), mini(8, r.credits_gained * 2))
		if r.lines >= 2:
			var words := ["", "", "DOUBLE!", "TRIPLE!", "QUAD!", "MEGA!"]
			fx.pop_text(board_view.get_global_rect().get_center(), words[mini(r.lines, 5)], BMStyle.PINK_L, 80, 40.0, 1.2)
			fx.confetti(board_view.get_global_rect(), 30 + r.lines * 15)
		elif r.combo_after >= 2 and r.lines > 0:
			fx.pop_text(center + Vector2(0, 40), "COMBO x%d" % r.combo_after, BMStyle.SKY_L, 30, 50.0, 0.9)
		fx.shake(2.0 + 5.0 * r.lines)
	if r.lines > 0:
		if BMCrtLayer.instance:
			BMCrtLayer.instance.shock(0.25 * r.lines)
		if BMSwirlBackground.instance:
			BMSwirlBackground.instance.pulse(0.3 * r.lines)
	for uid in r.get("shattered", []):
		if fx:
			fx.shards(center, 18)


## Sound for one placement. Timings follow BMBoardView (sweep starts at once; cells pop in a
## wave that BMBoardView voices itself) and the FX streams (coins and score arrive ~0.4 s).
func _play_placement_sounds(r: Dictionary) -> void:
	var n: int = r.placed.size()
	BMAudio.sfx("place_s" if n <= 2 else ("place_m" if n <= 4 else "place_l"))
	if r.lines > 0:
		BMAudio.sfx_later("clear_%d" % mini(r.lines, 3), 0.05)
		if r.combo_after >= 2:
			BMAudio.sfx_later("combo_%d" % clampi(r.combo_after - 1, 1, 3), 0.45)
	if not r.get("shattered", []).is_empty():
		BMAudio.sfx_later("glass", 0.2)
	for e in r.get("events", []):
		if String(e).contains("Stamp"):
			BMAudio.sfx_later("stamp", 0.12)
			break
	BMAudio.sfx_later("score", 0.35, 1.0 + minf(0.3, r.lines * 0.1))
	for i in mini(4, int(r.credits_gained)):
		BMAudio.sfx_later("coin", 0.4 + i * 0.09, 1.0 + i * 0.06)


## Three soft card flicks as a new tray slides in.
func _play_deal(delay: float) -> void:
	for i in 3:
		BMAudio.sfx_later("deal", delay + i * 0.08, 1.0 + i * 0.05)


## Joker cards bounce in resolution order, each showing its contribution.
func _animate_jokers(r: Dictionary) -> void:
	var delay := 0.15
	var shown := 0
	for it in r.items:
		if it.source != "joker" or not it.has("slot") or shown >= 6:
			continue
		var slot: int = it.slot
		if slot >= _joker_cards.size():
			continue
		var card := _joker_cards[slot]
		var txt := ""
		var col := BMStyle.SUN
		match it.kind:
			"chips":
				txt = "+%s" % BMUI.fmt_int(it.value)
				col = BMStyle.SKY_L
			"mult":
				txt = "+%s MULT" % BMUI.fmt_mult(it.value)
				col = BMStyle.PINK_L
			"xmult":
				txt = "x%s MULT" % BMUI.fmt_mult(it.value)
				col = BMStyle.SUN
		# Each trigger rings a little higher than the one before.
		BMAudio.sfx_later("joker_" + String(it.kind), delay, 1.0 + 0.07 * shown)
		# Weak reference: a refresh may free the card before the timer fires.
		var card_ref: WeakRef = weakref(card)
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			var c := card_ref.get_ref() as BMCard
			if c != null:
				c.pulse(txt, col))
		delay += 0.12
		shown += 1


func _write_receipt(r: Dictionary) -> void:
	var rows: Array = []
	var fam_name: String = BMShapes.family(r.shape.family).name
	rows.append({"text": "%s  (%d cells)" % [fam_name, r.placed.size()], "bold": true})
	if BMPieces.is_upgraded(r.shape):
		rows.append({"text": BMPieceTile.short_label(r.shape), "color": Color("#1f63b8")})
	for it in r.items:
		match it.kind:
			"chips":
				rows.append({"text": it.label, "value": "+%s" % BMUI.fmt_int(it.value), "value_color": Color("#1f63b8")})
			"mult":
				rows.append({"text": it.label, "value": "+%s mult" % BMUI.fmt_mult(it.value), "value_color": Color("#c42848")})
			"xmult":
				rows.append({"text": it.label, "value": "x%s mult" % BMUI.fmt_mult(it.value), "value_color": Color("#c42848")})
	if not r.mirror_cleared.is_empty():
		rows.append({"text": "Mirror Maze removed %d cells" % r.mirror_cleared.size(), "color": Color(BMStyle.INK, 0.7)})
	for e in r.get("events", []):
		rows.append({"text": e, "color": Color("#8a5a00")})
	rows.append({"dashes": true})
	rows.append({"text": "%s x %s" % [BMUI.fmt_int(r.chips), BMUI.fmt_mult(r.mult)], "value": "= %s" % BMUI.fmt_int(r.points), "bold": true, "value_color": Color("#c42848")})
	if r.combo_after > 0:
		rows.append({"text": "Combo now x%d" % r.combo_after, "color": Color(BMStyle.INK, 0.6)})
	_receipt.print_rows(rows)


func _confirm_sell(index: int) -> void:
	var id := run.jokers[index]
	_show_dialog("Sell %s for %d Credits?" % [BMJokers.get_def(id).name, BMJokers.sell_value(id)],
		[["SELL", "pink", func() -> void: _do_action({"a": "sell", "i": index})], ["KEEP", "plum", func() -> void: pass]])


func _confirm_concede() -> void:
	_show_dialog("Concede this round? The run will end.",
		[["CONCEDE", "pink", func() -> void: _do_action({"a": "concede"})], ["BACK", "plum", func() -> void: pass]])


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


func _modal(frame: String = "panel_plate", width: float = 680.0) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(BMStyle.INK, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var p := BMStyle.panel(frame, Vector4(24, 16, 24, 20))
	p.custom_minimum_size = Vector2(width, 0)
	center.add_child(p)
	var v := BMStyle.vbox(12)
	p.add_child(v)
	if not main.settings.reduced_motion:
		dim.modulate.a = 0.0
		dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.15)
		p.scale = Vector2(0.8, 0.8)
		p.resized.connect(func() -> void: p.pivot_offset = p.size / 2.0)
		var tw := p.create_tween()
		tw.tween_property(p, "scale", Vector2(1.04, 1.04), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "scale", Vector2.ONE, 0.08)
	return v


func close_overlay() -> void:
	if _bag_open():
		BMAudio.sfx("bag_close")
	BMUI.clear_children(overlay)


func _centered(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.add_child(c)
	return cc


func _show_dialog(text: String, buttons: Array) -> void:
	var v := _modal("panel_plate", 620)
	BMAudio.sfx("modal")
	var l := BMStyle.label(text, 30, BMStyle.CREAM, true, 8)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var row := BMStyle.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var first: Button
	for b in buttons:
		var cb: Callable = b[2]
		var btn := BMStyle.button(b[0], func() -> void:
			close_overlay()
			cb.call(), b[1], 30)
		btn.custom_minimum_size = Vector2(200, 72)
		row.add_child(btn)
		if first == null:
			first = btn
	BMStyle.focus_later(first)


func _show_bag() -> void:
	if run == null or overlay.get_child_count() > 0:
		return
	var v := _modal("panel_plate", 1240)
	BMAudio.sfx("bag_open")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(BMBagView.WIDTH + 24, 700)
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var bag_view := BMBagView.new()
	scroll.add_child(bag_view)
	bag_view.setup(run)
	var close := BMStyle.button("CLOSE  (ESC)", close_overlay, "sun", 30)
	close.custom_minimum_size = Vector2(0, 72)
	v.add_child(close)
	BMStyle.focus_later(close)


func _bag_open() -> bool:
	return overlay.find_children("*", "BMBagView", true, false).size() > 0


func _show_round_intro() -> void:
	var boss := run.current_boss()
	var v := _modal("panel_boss" if boss != "" else "panel_plate", 680)
	BMAudio.sfx("sting_boss" if boss != "" else "sting_round")
	v.add_child(_centered(BMStyle.pill("ROUND %d  -  ACT %d" % [run.round_number, run.act()], "pink" if boss != "" else "sun", 30)))
	var tl := BMStyle.label("TARGET", 30, BMStyle.TEXT_DIM, true, 8)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tl)
	var big := BMStyle.label(BMUI.fmt_int(run.round_state.target), 80, BMStyle.SUN, true, 16)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_color_override("font_shadow_color", Color(BMStyle.PINK, 0.7))
	big.add_theme_constant_override("shadow_offset_y", 8)
	big.add_theme_constant_override("shadow_offset_x", 0)
	v.add_child(big)
	var facts := BMStyle.hbox(28)
	facts.alignment = BoxContainer.ALIGNMENT_CENTER
	var f1 := BMStyle.hbox(6)
	f1.add_child(BMStyle.icon_rect("icon_hand", 0.75))
	var pl: int = run.round_state.placements_left
	f1.add_child(BMStyle.label("%d placement%s" % [pl, "" if pl == 1 else "s"], 20, BMStyle.CREAM, true))
	var f2 := BMStyle.hbox(6)
	f2.add_child(BMStyle.icon_rect("icon_refresh", 0.75))
	var rf := run.refreshes_available()
	f2.add_child(BMStyle.label("%d refresh%s" % [rf, "" if rf == 1 else "es"], 20, BMStyle.CREAM, true))
	facts.add_child(f1)
	facts.add_child(f2)
	v.add_child(facts)
	if boss != "":
		var d := BMBosses.get_def(boss)
		var bp := BMStyle.panel("panel_inset", Vector4(10, 8, 10, 8))
		var bv := BMStyle.vbox(4)
		bp.add_child(bv)
		var bh := BMStyle.hbox(8)
		bh.add_child(BMStyle.icon_rect("icon_skull", 1.0))
		bh.add_child(BMStyle.label("BOSS: " + d.name.to_upper(), 30, BMStyle.PINK_L, true, 8))
		bv.add_child(bh)
		var rule := BMStyle.label(d.rule, 20, BMStyle.CREAM)
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bv.add_child(rule)
		var tip := BMStyle.label("Tip: " + d.counter, 20, BMStyle.TEXT_DIM)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bv.add_child(tip)
		var disabled: Array[String] = []
		for id in run.jokers:
			if not run.is_joker_active(id):
				disabled.append(BMJokers.get_def(id).name)
		if not disabled.is_empty():
			bv.add_child(BMStyle.label("Disabled this round: " + ", ".join(disabled), 20, BMStyle.PINK_L))
		v.add_child(bp)
	elif run.round_number % BMRunConfig.ROUNDS_PER_ACT == 1:
		# First round of an act: preview the act's boss so it never arrives as a surprise.
		var d := BMBosses.get_def(run.act_boss())
		var np := BMStyle.panel("panel_inset", Vector4(10, 6, 10, 8))
		var nv := BMStyle.vbox(4)
		np.add_child(nv)
		var nh := BMStyle.hbox(8)
		nh.add_child(BMStyle.icon_rect("icon_skull", 0.75))
		nh.add_child(BMStyle.label("ACT BOSS, ROUND %d:  %s" % [run.act() * BMRunConfig.ROUNDS_PER_ACT, String(d.name).to_upper()], 20, BMStyle.PINK_L, true, 6))
		nv.add_child(nh)
		var note := BMStyle.label(d.rule, 20, BMStyle.CREAM)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nv.add_child(note)
		v.add_child(np)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	v.add_child(gap)
	var b := BMStyle.button("START ROUND", close_overlay, "sun", 40)
	b.custom_minimum_size = Vector2(0, 88)
	v.add_child(b)
	BMStyle.focus_later(b)


func _show_round_result() -> void:
	var res := run.last_round_result
	var v := _modal("panel_plate", 660)
	BMAudio.sfx("jingle_win")
	for i in mini(5, int(res.get("credits_gained", 0))):
		BMAudio.sfx_later("coin", 0.9 + i * 0.1, 1.0 + i * 0.05)
	var t := BMStyle.label("ROUND %d CLEARED!" % res.round, 60, BMStyle.SUN, true, 14)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_shadow_color", Color(BMStyle.PINK, 0.7))
	t.add_theme_constant_override("shadow_offset_y", 6)
	t.add_theme_constant_override("shadow_offset_x", 0)
	v.add_child(t)
	var sc := BMStyle.label("%s / %s points   -   %d placements unused" % [BMUI.fmt_int(res.score), BMUI.fmt_int(res.target), res.unused], 20, BMStyle.CREAM, true)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sc)
	var paper := BMStyle.panel("panel_paper", Vector4(16, 8, 16, 14))
	var pv := BMStyle.vbox(4)
	paper.add_child(pv)
	for line in res.credit_lines:
		var row := BMStyle.hbox(8)
		var l := BMStyle.label(line.label, 20, BMStyle.INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(BMStyle.label("+%d" % line.value, 20, Color("#8a5a00"), true))
		row.add_child(BMStyle.icon_rect("icon_coin", 0.5))
		pv.add_child(row)
	# Total earned (after the Credit cap), then the wallet balance, so the two never get confused.
	pv.add_child(BMHud.Dashes.new())
	var trow := BMStyle.hbox(8)
	var tl := BMStyle.label("Earned", 20, BMStyle.INK, true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(tl)
	trow.add_child(BMStyle.label("+%d" % int(res.credits_gained), 20, Color("#8a5a00"), true))
	trow.add_child(BMStyle.icon_rect("icon_coin", 0.5))
	pv.add_child(trow)
	v.add_child(paper)
	var total := BMStyle.hbox(8)
	total.alignment = BoxContainer.ALIGNMENT_CENTER
	total.add_child(BMStyle.label("YOU HAVE", 30, BMStyle.CREAM, true, 8))
	total.add_child(BMStyle.icon_rect("icon_coin", 1.0))
	total.add_child(BMStyle.label("%d" % run.credits, 40, BMStyle.SUN, true, 10))
	v.add_child(total)
	var last: bool = res.round >= BMRunConfig.ROUND_COUNT
	var b := BMStyle.button("FINISH RUN" if last else "TO THE SHOP", func() -> void:
		close_overlay()
		main.act({"a": "continue"}), "mint", 40)
	b.custom_minimum_size = Vector2(0, 88)
	v.add_child(b)
	BMStyle.focus_later(b)
	if BMFx.instance:
		BMFx.instance.confetti(Rect2(Vector2(0, 0), size), 160)
		BMFx.instance.coins(board_view.get_global_rect().get_center(), _credits.get_global_rect().get_center(), 8)


func _show_run_end() -> void:
	var won := run.phase == BMRun.Phase.RUN_WON
	var v := _modal("panel_plate" if won else "panel_boss", 720)
	BMAudio.sfx("jingle_run_win" if won else "jingle_lose")
	var title := "YOU WIN!" if won else ("RUN ABANDONED" if run.phase == BMRun.Phase.ABANDONED else "GAME OVER")
	var t := BMStyle.label(title, 80, BMStyle.SUN if won else BMStyle.PINK_L, true, 16)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var reason := BMStyle.label(run.end_reason, 20, BMStyle.CREAM, true)
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(reason)
	# Run summary: two stat columns in an inset, then the Joker build.
	var s := run.stats
	var sp := BMStyle.panel("panel_inset", Vector4(12, 6, 12, 8))
	var sv := BMStyle.vbox(8)
	sp.add_child(sv)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	var rs := run.round_state
	var pairs := [["Round", "%d / %d" % [run.round_number, BMRunConfig.ROUND_COUNT]], ["Lines cleared", BMUI.fmt_int(s.lines_cleared)],
			["Last score", "%s / %s" % [BMUI.fmt_int(rs.score), BMUI.fmt_int(rs.target)]], ["Best placement", BMUI.fmt_int(s.best_placement)],
			["Bag size", str(run.bag.size())], ["Highest combo", "x%d" % s.highest_combo]]
	for pair in pairs:
		var k := BMStyle.label(pair[0], 20, BMStyle.TEXT_DIM)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(k)
		grid.add_child(BMStyle.label(pair[1], 20, BMStyle.CREAM, true))
	sv.add_child(grid)
	var names := PackedStringArray()
	for id in run.jokers:
		names.append(BMJokers.get_def(id).name)
	var build := BMStyle.label("Jokers: " + (", ".join(names) if names.size() > 0 else "none"), 20, BMStyle.SUN_L)
	build.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(build)
	var seed_l := BMStyle.label("Seed %d" % run.run_seed, 20, BMStyle.TEXT_DIM)
	sv.add_child(seed_l)
	v.add_child(sp)
	var row := BMStyle.hbox(12)
	v.add_child(row)
	var again := BMStyle.button("NEW RUN", func() -> void:
		close_overlay()
		main.start_new_run(BMRun.random_seed()), "sun", 30)
	var same := BMStyle.button("SAME SEED", func() -> void:
		close_overlay()
		main.start_new_run(run.run_seed), "sky", 30)
	var title_b := BMStyle.button("TITLE", func() -> void:
		close_overlay()
		main.show_title(), "plum", 30)
	for b in [again, same, title_b]:
		b.custom_minimum_size = Vector2(0, 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	BMStyle.focus_later(again)
	if won and BMFx.instance:
		BMFx.instance.confetti(Rect2(Vector2.ZERO, size), 260)
