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
var refresh_button: BMRefreshLever
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
## Hold (GDD §22.1): the stored-piece box under the receipt.
var _hold_box: HoldBox
var held_mode := "" ## "drag", "sticky", or "key"
var key_anchor := Vector2i(3, 3)
var _press_pos := Vector2.ZERO
## Pointer position in canvas coordinates, tracked from input events (works for real and
## simulated input alike, and after the CRT remap).
var _mouse := Vector2.ZERO
var _preview_cache_key := ""
var _intro_shown_for := -1
## Item targeting (Eraser, Punch, Color Purge, Lucky Paint, Blueprint, Emergency Brick, Patch
## Panel). Empty when idle; otherwise {id, i (item index or -1 for Patch), kind, cells}.
var _tool := {}
var _brick: BMBrickThrow
var _tool_layer: Control


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
	refresh_button = BMRefreshLever.new()
	refresh_button.pressed.connect(_on_refresh_button)
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
	_receipt.clip_contents = true
	_at(_receipt, Vector2(52, 562), Vector2(476, 304))
	_hold_box = HoldBox.new()
	_hold_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hold_box.gui_input.connect(_on_hold_box_input)
	_at(_hold_box, Vector2(36, 878), Vector2(508, 176))

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

	_tool_layer = Control.new()
	_tool_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tool_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tool_layer)

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
		BMSwirlBackground.instance.set_mood(swirl_mood())
	_maybe_show_phase_overlay()


## Background palette: bosses (Mk II hotter), Overtime embers, and a shift per act.
func swirl_mood() -> String:
	if run.current_boss() != "":
		return "boss_mk2" if run.boss_is_mk2() else "boss"
	if run.overtime:
		return "overtime"
	return ["round", "round", "act2", "act3"][clampi(run.act(), 1, 3)]


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
	_marquee.sub = ("BOSS: " + BMBosses.title(boss, run.boss_is_mk2()).to_upper()) if boss != "" else "ACT %d OF 3" % run.act()
	if boss == "" and run.round_card != "standard":
		_marquee.sub = String(BMRoundCards.get_def(run.round_card).name).to_upper()
	if run.overtime and boss == "":
		_marquee.sub = "OVERTIME  -  ACT %d" % run.act()
	_target_label.text = "/ " + BMUI.fmt_score(rs.target)
	_target_label.tooltip_text = "Target: %s points" % BMUI.fmt_int(rs.target)
	_score.set_target(rs.score)
	_tube.set_fraction(float(rs.score) / maxf(1.0, rs.target))
	_moves_label.text = str(rs.placements_left)
	_moves_label.add_theme_color_override("font_color", BMStyle.PINK_L if rs.placements_left <= 3 else BMStyle.CREAM)
	_lamps.set_counts(rs.placements_left, maxi(rs.placement_cap, rs.placements_left))
	_moves_label.get_parent().tooltip_text = "Placements left this round.\nEach line you clear gives one back, up to %d." % rs.placement_cap
	if boss == "lockdown":
		_refresh_count.text = "LOCKED"
	else:
		_refresh_count.text = "x%d" % rs.refreshes_left
	var hanging := rs.combo > 0 and rs.combo_misses > 0
	_combo_label.text = ("x%d!" if hanging else "x%d") % rs.combo
	_combo_label.get_parent().tooltip_text = "Combo: each clearing placement adds 1 (max %d). It survives %d placement without a clear, then resets.%s" % [BMRunConfig.COMBO_CAP, BMRunConfig.COMBO_GRACE, "
HANGING ON: clear on your next placement to keep it." if hanging else ""]
	_combo_icon.modulate = Color.WHITE if rs.combo > 0 else Color(1, 1, 1, 0.35)
	_combo_label.modulate = Color.WHITE if rs.combo > 0 else Color(1, 1, 1, 0.5)
	_credits.set_target(run.credits)
	board_view.boss_lights = boss != ""
	board_view.lights_color = BMStyle.SUN if boss != "" and run.boss_is_mk2() else BMStyle.PINK
	if BMMoodLayer.instance and visible:
		var danger := run.phase == BMRun.Phase.ROUND and rs.placements_left <= 3 and rs.score < rs.target
		var heat := 0.0
		if run.heat >= 3 or run.overtime:
			heat = 0.7
		elif run.act() >= 3:
			heat = 0.3
		BMMoodLayer.instance.set_round(boss != "", danger, heat)
	_hold_box.shape = rs.held
	_hold_box.used = rs.hold_used
	_hold_box.blocked = run.hold_blocked()
	_hold_box.drop_ready = held_slot >= 0 and not rs.hold_used and not run.hold_blocked()
	_hold_box.queue_redraw()

	BMUI.clear_children(_boss_box)
	_boss_panel.add_theme_stylebox_override("panel", BMStyle.box("panel_boss" if boss != "" else "panel_plate", Vector4(8, 2, 8, 2)))
	var head := BMStyle.hbox(8)
	_boss_box.add_child(head)
	head.add_child(BMStyle.icon_rect("icon_skull", 0.75))
	# The panel has a fixed rect beside the board: long boss names clip with an ellipsis and the
	# rule wraps to at most four lines, so the panel can never grow into the board or receipt.
	# The full text is always in the tooltip.
	var shown_boss := boss if boss != "" else run.act_boss()
	var mk2 := run.boss_is_mk2()
	var boss_name := BMBosses.title(shown_boss, mk2).to_upper()
	var short := boss_name.trim_prefix("THE ")
	var r := run.act() * 4
	var options := ["BOSS: " + boss_name, "BOSS: " + short] if boss != "" else \
		["ROUND %d BOSS: %s" % [r, boss_name], "R%d BOSS: %s" % [r, boss_name], "R%d BOSS: %s" % [r, short], "R%d: %s" % [r, short]]
	var head_text: String = options.back()
	var room := _boss_panel.size.x - 110.0 # panel margins, the skull and the gap
	for o in options:
		if BMStyle.font_bold.get_string_size(o, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x <= room:
			head_text = o
			break
	var hl := BMStyle.label(head_text, 20, BMStyle.PINK_L, true, 6)
	hl.clip_text = true
	hl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.custom_minimum_size.x = 1
	head.add_child(hl)
	var rule := BMStyle.label(BMBosses.rule_text(shown_boss, mk2), 20, BMStyle.CREAM if boss != "" else BMStyle.TEXT_DIM)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.max_lines_visible = 4
	rule.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rule.custom_minimum_size.x = 1
	_boss_box.add_child(rule)
	_boss_panel.tooltip_text = "%s\n%s" % [BMBosses.title(shown_boss, mk2), BMBosses.rule_text(shown_boss, mk2)]
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	for i in 3:
		slots[i].locked = run.slot_locked(i)
		slots[i].setup(run.tray[i], held_slot == i, run.slot_fits(i))
		slots[i].focused_by_key = held_mode == "key" and held_slot == i
		slots[i].tooltip_text = BMPieces.describe(run.tray[i]) if not run.tray[i].is_empty() else ""
	_concede_mode = run.phase == BMRun.Phase.ROUND and (rs.status == BMRun.OUT_OF_PLACEMENTS or (rs.status == BMRun.STUCK and run.refreshes_available() <= 0))
	var rm := bool(main.settings.get("reduced_motion", false))
	if _concede_mode:
		refresh_button.set_state(BMRefreshLever.Look.CONCEDE, 0, rm)
		refresh_button.disabled = false
		refresh_button.tooltip_text = "No legal move is left. Use an item that can help, or pull to concede the round and end the run."
	else:
		var look := BMRefreshLever.Look.READY
		if boss == "lockdown":
			look = BMRefreshLever.Look.LOCKED
		elif rs.refreshes_left <= 0:
			look = BMRefreshLever.Look.EMPTY
		var start_refreshes := maxi(0, int(run.kit().refreshes) - (1 if run.heat >= 5 else 0))
		refresh_button.set_state(look, rs.refreshes_left, rm, start_refreshes)
		refresh_button.disabled = run.refreshes_available() <= 0 or not run.can_act_in_round() or rs.status == BMRun.OUT_OF_PLACEMENTS
		var left := "Locked by The Lockdown this round." if boss == "lockdown" else \
			"%d Refresh%s left this round." % [rs.refreshes_left, "es" if rs.refreshes_left != 1 else ""]
		refresh_button.tooltip_text = "Refresh (R): pull the lever to replace every unplaced piece in the tray. Costs no placement.\n" + left

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
		var card := BMCard.joker_rack(run, id, BMCard.rack_height(run.joker_slots()))
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
		empty.custom_minimum_size = Vector2(0, BMCard.rack_height(run.joker_slots()))
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
		var id := run.consumables[i]
		if not _tool.is_empty() and int(_tool.i) == i:
			box.add_child(_tool_buttons())
		else:
			var targeted := BMConsumables.target_kind(id) != ""
			var use := BMStyle.button("USE", func() -> void:
				if targeted:
					_begin_tool(id, i)
				else:
					_do_action({"a": "use", "i": i}), "mint", 20)
			use.disabled = reason != "" or not _tool.is_empty()
			use.tooltip_text = reason if reason != "" else ("Use this item now: you choose where next." if targeted else "Use this item now.")
			box.add_child(use)
		_items_box.add_child(card)
	var patch_shown := run.phase == BMRun.Phase.ROUND and run.round_state.patch_ready and run.consumables.size() < BMRunConfig.CONSUMABLE_SLOTS
	if patch_shown:
		_items_box.add_child(_patch_card())
	for i in range(run.consumables.size() + (1 if patch_shown else 0), BMRunConfig.CONSUMABLE_SLOTS):
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
	if run.tray[slot].is_empty() or slots[slot].is_spinning():
		return
	held_slot = slot
	held_mode = "drag"
	BMAudio.sfx("pickup")
	_press_pos = _mouse
	_update_ghost_from_mouse()
	refresh_all()


func _input_enabled() -> bool:
	return run != null and run.can_place() and overlay.get_child_count() == 0 and not main.is_paused() and _tool.is_empty()


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse = event.position
	if not _tool.is_empty() and run != null and overlay.get_child_count() == 0:
		_tool_input(event)
		return
	if run == null or held_slot < 0:
		return
	if event is InputEventMouseMotion:
		if held_mode == "key":
			held_mode = "sticky"
		_update_ghost_from_mouse()
		drag_layer.queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and held_mode == "drag":
		var moved := _mouse.distance_to(_press_pos) > 12.0
		if moved and _hold_box.get_global_rect().has_point(_mouse):
			_hold_piece(held_slot)
			get_viewport().set_input_as_handled()
			return
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
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and held_mode == "sticky" and _hold_box.get_global_rect().has_point(_mouse):
		_hold_piece(held_slot)
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
	if not _tool.is_empty():
		_tool_key(event)
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
	if event.is_action("bm_hold"):
		_hold_piece(held_slot)
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


## Where the tutorial (BMTutorial) points, in global coordinates; Rect2() when unknown.
func tutorial_rect(id: String) -> Rect2:
	match id:
		"board":
			return board_view.get_global_rect()
		"tray":
			var r := slots[0].get_global_rect()
			for s in slots:
				r = r.merge(s.get_global_rect())
			return r
		"receipt":
			return _receipt.get_global_rect()
		"score":
			return (_score.get_parent().get_parent() as Control).get_global_rect()
		"refresh":
			return refresh_button.get_global_rect()
		"hold":
			return _hold_box.get_global_rect()
		"jokers":
			return _jokers_box.get_global_rect()
	return Rect2()


## Hold the picked-up piece (swap with the stored one), or, with nothing picked up, take the
## stored piece back into an empty tray slot.
func _hold_piece(slot: int) -> void:
	if run == null or not run.can_act_in_round():
		return
	var rs := run.round_state
	if run.hold_blocked():
		_deny("The Lockdown Mk II disables Hold this round.")
		return
	if rs.hold_used:
		_deny("Hold is used. Place a piece to recharge it.")
		return
	if slot < 0:
		if rs.held.is_empty():
			_deny("Pick up a tray piece first, then drop it on HOLD (or press H).")
			return
		for i in run.tray.size():
			if run.tray[i].is_empty() and not run.slot_locked(i):
				slot = i
				break
		if slot < 0:
			_deny("Pick up a tray piece to swap with the stored one.")
			return
	_cancel_hold("", false)
	var r := _do_action({"a": "hold", "slot": slot})
	if r.get("ok", false):
		BMAudio.sfx("hold_store")
		slots[slot].land()
		if BMFx.instance:
			BMFx.instance.ring(_hold_box.get_global_rect().get_center(), BMStyle.MINT_L, 120.0)
			BMFx.instance.stars(_hold_box.get_global_rect().get_center(), 5, 60.0, BMStyle.MINT_L)


func _on_hold_box_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and held_slot < 0:
		_hold_piece(-1)
		get_viewport().set_input_as_handled()


func _select_by_key(slot: int) -> void:
	if not _input_enabled() or run.tray[slot].is_empty() or slots[slot].is_spinning():
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
	_preview_box.add_child(BMStyle.label(BMUI.fmt_score(p.points), 30, BMStyle.SUN, true, 8))
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


func _do_action(a: Dictionary) -> Dictionary:
	if run == null:
		return {}
	var r: Dictionary = main.act(a)
	if not r.ok:
		_set_message(r.error, BMStyle.PINK_L)
		BMAudio.sfx("deny")
		return r
	_new_kits = r.get("kits_unlocked", [])
	match r.get("type", ""):
		"place":
			_present_placement(r)
			if not r.events.is_empty():
				_set_message("  ".join(PackedStringArray(r.events)), BMStyle.SUN)
		"hold":
			_set_message(", ".join(PackedStringArray(r.get("events", []))).to_upper(), BMStyle.MINT_L)
			if Array(r.get("tray_events", [])).has("New tray"):
				pass
		"refresh":
			_end_tool(false)
			_set_message(", ".join(PackedStringArray(r.get("events", []))), BMStyle.MINT_L)
			# The lever's one-armed-bandit pull; the tray reels start spinning when it slams down.
			refresh_button.pull(run.round_state.refreshes_left)
			_spin_tray(0.1 if main.settings.reduced_motion else BMRefreshLever.PULL_DOWN, String(r.get("hand", "")))
			if BMFx.instance:
				for s in slots:
					BMFx.instance.stars(s.get_global_rect().get_center(), 3, 60.0)
		"patch":
			_present_tool(r)
		"use":
			if BMConsumables.target_kind(r.item) != "":
				_present_tool(r)
			else:
				var msg := "Used %s." % BMConsumables.get_def(r.item).name
				match String(r.item):
					"overclock":
						msg = "TURBO: NEXT PLACEMENT x2 MULT"
					"coffee_break":
						msg = "COFFEE BREAK: +1 REFRESH"
					"coin_roll":
						msg = "COIN ROLL: +%d CREDITS" % int(r.get("credits", 0))
						if BMFx.instance:
							BMFx.instance.coins(_items_box.get_global_rect().get_center(), _credits.get_global_rect().get_center(), mini(10, int(r.get("credits", 0))))
				_set_message(msg, BMStyle.MINT_L)
				BMAudio.sfx("item")
			if r.item == "second_tray":
				_spin_tray(0.1, String(r.get("hand", "")))
		"sell":
			_set_message("Sold %s for %d Credits." % [BMJokers.get_def(r.item).name, r.value], BMStyle.SUN)
			BMAudio.sfx("sell")
	var tray_events: Array = r.get("tray_events", [])
	if tray_events.has("New tray"):
		_spin_tray(0.3, String(r.get("tray_hand", "")))
	for e in tray_events:
		if String(e).begins_with("Tiny Insurance") or String(e).begins_with("No piece"):
			_set_message(e, BMStyle.SUN)
	refresh_all()
	if bool(r.get("insurance", false)):
		_show_insurance_claim()
	if r.get("type", "") == "place":
		_animate_jokers(r)
	_maybe_show_phase_overlay(0.0 if main.settings.reduced_motion else 0.9)
	return r


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
		fx.pop_text(center + Vector2(0, -30), "+" + BMUI.fmt_score(r.points), BMStyle.SUN if r.lines > 0 else BMStyle.CREAM, size_px, 90.0, 1.0)
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
	var feats: Array = r.get("feats", [])
	var shown := 0
	for f in BMFeats.ORDER:
		if feats.has(f) and shown < 2:
			_feat_banner(f, 0.25 + shown * 0.45, shown)
			shown += 1
	if r.lines == 0 and run.has_active_joker("patience"):
		var pi := run.jokers.find("patience")
		if pi >= 0 and pi < _joker_cards.size():
			var ref: WeakRef = weakref(_joker_cards[pi])
			BMAudio.sfx_later("patience_tick", 0.2)
			get_tree().create_timer(0.2).timeout.connect(func() -> void:
				var c := ref.get_ref() as BMCard
				if c != null:
					c.pulse("+%d STORED" % BMJokers.PATIENCE_STEP, BMStyle.SKY_L))
	var waves: Array = r.get("waves", [])
	for w in range(1, waves.size()):
		var at := board_view.get_global_rect().get_center()
		var wave: Dictionary = waves[w]
		var label := "AVALANCHE x%d!" % int(pow(2.0, w))
		var pts := "+" + BMUI.fmt_score(int(wave.points))
		BMAudio.sfx_later("clear_%d" % mini(3, w + 1), 0.55 * w, 1.0 + 0.1 * w)
		get_tree().create_timer(0.55 * w).timeout.connect(func() -> void:
			var f := BMFx.instance
			if f == null:
				return
			f.pop_text(at + Vector2(0, -60), label, BMStyle.LILAC, 80, 60.0, 1.2)
			f.pop_text(at + Vector2(0, 30), pts, BMStyle.SUN, 60, 70.0, 1.0)
			f.shake(6.0 + 4.0 * w)
			f.confetti(board_view.get_global_rect(), 30 + 20 * w))
	if int(r.get("milestone", 0)) > 0:
		_milestone_banner(int(r.milestone), int(r.points))
	if String(r.get("transmuted", "")) != "" and fx:
		var m := String(r.transmuted)
		fx.pop_text(center + Vector2(0, 50), "TRANSMUTED: " + String(BMPieces.MATERIAL_DEFS[m].name).to_upper(), BMStyle.SUN_L, 30, 50.0, 1.2)
		fx.sparks(center, BMStyle.SUN_L, 18)
	if int(r.get("unlocked", -1)) >= 0:
		_warden_unlock(int(r.unlocked))
	if r.has("tomb"):
		var tomb: Vector2i = r.tomb
		get_tree().create_timer(0.35).timeout.connect(func() -> void:
			board_view.play_tomb(tomb)
			BMAudio.sfx("tomb_rise")
			if BMFx.instance:
				BMFx.instance.shake(6.0))
	if r.lines == 0 and run.round_state.combo > 0 and run.round_state.combo_misses > 0 and fx:
		fx.pop_text(_combo_label.get_global_rect().get_center() + Vector2(0, -36), "HANG ON!", BMStyle.PINK_L, 20, 36.0, 1.0)
	var refilled := int(r.get("placements_refilled", 0))
	if refilled > 0 and fx:
		var moves_at := _moves_label.get_global_rect().get_center()
		fx.pop_text(moves_at + Vector2(0, -36), "+%d" % refilled, BMStyle.MINT_L, 30, 40.0, 0.9)
		fx.stars(moves_at, 2 + refilled, 50.0)


## A single placement crossed 1M / 1B / 1T for the first time this run: a stadium moment.
func _milestone_banner(tier: int, points: int) -> void:
	var names: Array = BMResolver.MILESTONE_NAMES
	var colors := [BMStyle.SUN, BMStyle.SUN_L, BMStyle.LILAC, BMStyle.PINK_L]
	var col: Color = colors[clampi(tier, 0, 3)]
	BMAudio.sfx_later("record_new", 0.2)
	BMAudio.sfx_later("ach_gold" if tier < 3 else "ach_legend", 0.5)
	var at := board_view.get_global_rect().get_center()
	get_tree().create_timer(0.35).timeout.connect(func() -> void:
		var f := BMFx.instance
		if f == null:
			return
		f.pop_text(at + Vector2(0, -150), "MILESTONE!", BMStyle.CREAM, 40, 60.0, 2.0)
		f.pop_text(at + Vector2(0, -80), String(names[clampi(tier, 0, 3)]), col, 80, 70.0, 2.2)
		f.pop_text(at + Vector2(0, 10), BMUI.fmt_int(points), BMStyle.SUN, 60, 60.0, 2.2)
		f.confetti(Rect2(Vector2.ZERO, size), 160 + 60 * tier)
		f.shake(8.0 + 4.0 * tier)
		if BMCrtLayer.instance:
			BMCrtLayer.instance.shock(0.5 + 0.2 * tier)
		if BMSwirlBackground.instance:
			BMSwirlBackground.instance.pulse(1.0))
	_set_message("MILESTONE: %s IN ONE PLACEMENT" % String(names[clampi(tier, 0, 3)]), col, 4.0)


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
	# Material faces and stamps have their own voices (presentation of the record only).
	var shape: Dictionary = r.get("shape", {})
	BMAudio.finish_sfx(String(shape.get("material", "")), false, -5.0)
	var cleared_mats := {}
	for e in r.cleared:
		var m := int(e.get("mat", 0))
		if m != 0:
			cleared_mats[BMPieces.MATERIALS[m]] = true
	var voiced := 0
	for m: String in cleared_mats:
		if voiced < 2:
			BMAudio.finish_sfx(m, true, -6.0, 0.1 + voiced * 0.08)
			voiced += 1
	var stamp := String(shape.get("stamp", ""))
	if stamp != "" and (stamp != "encore" or r.lines > 0):
		BMAudio.stamp_sfx(stamp, 0.14)
	BMAudio.sfx_later("score", 0.35, 1.0 + minf(0.3, r.lines * 0.1))
	for i in mini(4, int(r.credits_gained)):
		BMAudio.sfx_later("coin", 0.4 + i * 0.09, 1.0 + i * 0.06)


## A new deal spins the tray like three slot reels that stop left to right, then reveals the
## Tray Hand if the deal formed one. Presentation only: the tray is already dealt.
func _spin_tray(delay: float, hand: String) -> void:
	var rm: bool = main.settings.reduced_motion
	var reel: Array = []
	for i in 12:
		if not run.bag.is_empty():
			reel.append(run.bag.pick_random()) # cosmetic: global RNG, never the run's streams
	var stop_at := 0.0
	var any := false
	for i in 3:
		if run.tray[i].is_empty():
			continue
		any = true
		stop_at = delay + 0.42 + i * 0.17
		slots[i].spin(stop_at, reel)
		if rm:
			BMAudio.sfx_later("deal", delay + i * 0.08, 1.0 + i * 0.05)
		else:
			BMAudio.sfx_later("reel_stop_%d" % (i + 1), stop_at)
	if any and not rm:
		BMAudio.sfx_later("reel_spin", delay * 0.5)
	if hand != "":
		get_tree().create_timer(0.05 if rm else stop_at + 0.08).timeout.connect(_reveal_hand.bind(hand))


## The Hand's fanfare: well flash, big name callout, reward line, themed particles.
func _reveal_hand(hand: String) -> void:
	if run == null:
		return
	var d := BMHands.get_def(hand)
	var color: Color = BMTraySlot.HAND_COLORS.get(hand, BMStyle.SUN)
	BMAudio.sfx("hand_" + hand)
	_set_message("%s!  %s" % [String(d.name).to_upper(), d.short], color, 3.2)
	var tray_rect := Rect2(slots[0].global_position, slots[2].get_global_rect().end - slots[0].global_position)
	var top := Vector2(tray_rect.get_center().x, tray_rect.position.y - 90)
	for i in 3:
		if String(run.tray[i].get("hand", "")) == hand:
			slots[i].flare()
	var fx := BMFx.instance
	if fx == null:
		return
	fx.pop_text(top + Vector2(0, -40), String(d.name).to_upper() + "!", color, 60, 70.0, 1.3)
	fx.pop_text(top + Vector2(0, 16), d.short, BMStyle.CREAM, 20, 50.0, 1.6)
	for i in 3:
		var c := slots[i].get_global_rect().get_center()
		fx.stars(c, 5, 70.0, color)
		fx.ring(c, color, 110.0)
	match hand:
		BMHands.STAIRCASE:
			for i in 5:
				fx.burst(tray_rect.position + Vector2(tray_rect.size.x * (0.1 + i * 0.2), tray_rect.size.y - i * 30), [BMStyle.MINT, BMStyle.MINT_L], 8, 240.0, 8.0)
			fx.pop_text(_moves_label.get_global_rect().get_center() + Vector2(0, -36), "+1", BMStyle.MINT_L, 30, 40.0, 0.9)
		BMHands.MONOCHROME:
			var bc: Color = BMFinishes.hue(int(run.tray[0].color)) if run.tray[0].has("color") else color
			for i in 3:
				fx.burst(slots[i].get_global_rect().get_center(), [bc, bc.lightened(0.3), BMStyle.CREAM], 22, 460.0, 10.0)
		BMHands.TRIPLETS:
			fx.confetti(Rect2(tray_rect.position - Vector2(0, 300), Vector2(tray_rect.size.x, 10)), 70)
			fx.shake(6.0)
		BMHands.GRAND_SLAM:
			fx.confetti(Rect2(Vector2.ZERO, size), 220)
			for i in 3:
				fx.coins(slots[i].get_global_rect().get_center(), _credits.get_global_rect().get_center(), 6)
			fx.shake(12.0)
			if BMCrtLayer.instance:
				BMCrtLayer.instance.shock(0.8)
			if BMSwirlBackground.instance:
				BMSwirlBackground.instance.pulse(1.0)
		_:
			for i in 3:
				fx.sparks(slots[i].get_global_rect().get_center(), color, 10)


func _tray_hand() -> String:
	for p in run.tray:
		if not p.is_empty() and String(p.get("hand", "")) != "":
			return String(p.hand)
	return ""


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
	var waves: Array = r.get("waves", [])
	if waves.size() > 1:
		var first: Dictionary = waves[0]
		rows.append({"text": "%s x %s" % [BMUI.fmt_int(first.chips), BMUI.fmt_mult(first.mult)], "value": "= %s" % BMUI.fmt_score(int(first.points)), "value_color": Color("#c42848")})
		for w in range(1, waves.size()):
			var wave: Dictionary = waves[w]
			rows.append({"text": "Avalanche wave %d  (x%d chain)" % [w + 1, int(pow(2.0, w))], "value": "+%s" % BMUI.fmt_score(int(wave.points)), "value_color": Color("#7a3fd0")})
		rows.append({"text": "Total", "value": "= %s" % BMUI.fmt_score(r.points), "bold": true, "value_color": Color("#c42848")})
	else:
		rows.append({"text": "%s x %s" % [BMUI.fmt_int(r.chips), BMUI.fmt_mult(r.mult)], "value": "= %s" % BMUI.fmt_score(r.points), "bold": true, "value_color": Color("#c42848")})
	if r.combo_after > 0:
		rows.append({"text": "Combo now x%d" % r.combo_after, "color": Color(BMStyle.INK, 0.6)})
	for f in r.get("feats", []):
		rows.append({"text": "Feat: %s" % BMFeats.get_def(f).name, "color": Color("#a86a00"), "bold": true})
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
				if run.current_boss() != "" and String(main.settings.get("boss_intro", "cinematic")) == "cinematic":
					_play_boss_intro()
				else:
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


## Boss rounds open with the cinematic (BMBossIntro), then the usual round intro.
func _play_boss_intro() -> void:
	var intro := BMBossIntro.new()
	intro.boss = run.current_boss()
	intro.mk2 = run.boss_is_mk2()
	intro.reduced_motion = main.settings.reduced_motion
	overlay.add_child(intro)
	intro.finished.connect(func() -> void:
		if run != null and run.phase == BMRun.Phase.ROUND:
			_show_round_intro.call_deferred())


func _show_round_intro() -> void:
	var boss := run.current_boss()
	if boss == "" and run.round_number % BMRunConfig.ROUNDS_PER_ACT == 1 and run.round_number > 1:
		BMAudio.sfx_later("act_start", 0.15)
	var v := _modal("panel_boss" if boss != "" else "panel_plate", 680)
	BMAudio.sfx("sting_boss" if boss != "" else "sting_round")
	var pill_text := "ROUND %d  -  ACT %d" % [run.round_number, run.act()]
	if run.overtime:
		pill_text = "ROUND %d  -  OVERTIME" % run.round_number
	v.add_child(_centered(BMStyle.pill(pill_text, "pink" if boss != "" or run.overtime else "sun", 30)))
	var tl := BMStyle.label("TARGET", 30, BMStyle.TEXT_DIM, true, 8)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tl)
	var big := BMStyle.label(BMUI.fmt_score(run.round_state.target), 80, BMStyle.SUN, true, 16)
	big.tooltip_text = "%s points" % BMUI.fmt_int(run.round_state.target)
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
	f1.add_child(BMStyle.label("%d placement%s, +1 per line" % [pl, "" if pl == 1 else "s"], 20, BMStyle.CREAM, true))
	f1.tooltip_text = "Each line you clear gives one placement back, up to %d." % run.round_state.placement_cap
	var f2 := BMStyle.hbox(6)
	f2.add_child(BMStyle.icon_rect("icon_refresh", 0.75))
	var rf := run.refreshes_available()
	f2.add_child(BMStyle.label("%d refresh%s" % [rf, "" if rf == 1 else "es"], 20, BMStyle.CREAM, true))
	facts.add_child(f1)
	facts.add_child(f2)
	v.add_child(facts)
	if boss == "" and run.round_card != "standard":
		var cd := BMRoundCards.get_def(run.round_card)
		var cp := BMStyle.panel("panel_inset", Vector4(10, 6, 10, 8))
		var cv := BMStyle.vbox(2)
		cp.add_child(cv)
		cv.add_child(BMStyle.label("TWIST: " + String(cd.name).to_upper(), 20, BMStyle.SUN_L, true, 6))
		var ct := BMStyle.label(String(cd.text), 20, BMStyle.CREAM)
		ct.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(ct)
		v.add_child(cp)
	if boss != "":
		var d := BMBosses.get_def(boss)
		var mk2 := run.boss_is_mk2()
		var bp := BMStyle.panel("panel_inset", Vector4(10, 8, 10, 8))
		var bv := BMStyle.vbox(4)
		bp.add_child(bv)
		var bh := BMStyle.hbox(8)
		bh.add_child(BMStyle.icon_rect("icon_skull", 1.0))
		bh.add_child(BMStyle.label("BOSS: " + BMBosses.title(boss, mk2).to_upper(), 30, BMStyle.PINK_L, true, 8))
		bv.add_child(bh)
		var rule := BMStyle.label(BMBosses.rule_text(boss, mk2), 20, BMStyle.CREAM)
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
		if run.overtime and run.round_number == BMRunConfig.ROUND_COUNT + 1:
			var ot := BMStyle.label("OVERTIME: the targets climb faster every round. How far can you go?", 20, BMStyle.SUN_L, true, 6)
			ot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(ot)
		# First round of an act: preview the act's boss so it never arrives as a surprise.
		var mk2 := run.boss_is_mk2()
		var np := BMStyle.panel("panel_inset", Vector4(10, 6, 10, 8))
		var nv := BMStyle.vbox(4)
		np.add_child(nv)
		var nh := BMStyle.hbox(8)
		nh.add_child(BMStyle.icon_rect("icon_skull", 0.75))
		nh.add_child(BMStyle.label("ACT BOSS, ROUND %d:  %s" % [run.act() * BMRunConfig.ROUNDS_PER_ACT, BMBosses.title(run.act_boss(), mk2).to_upper()], 20, BMStyle.PINK_L, true, 6))
		nv.add_child(nh)
		var note := BMStyle.label(BMBosses.rule_text(run.act_boss(), mk2), 20, BMStyle.CREAM)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nv.add_child(note)
		v.add_child(np)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	v.add_child(gap)
	var b := BMStyle.button("START ROUND", func() -> void:
		close_overlay()
		_spin_tray(0.05, _tray_hand())
		if run.round_state.locked_slot >= 0:
			BMAudio.sfx_later("warden_lock", 0.75)
			_set_message("THE WARDEN BARRED SLOT %d: CLEAR A LINE TO FREE IT" % (run.round_state.locked_slot + 1), BMStyle.PINK_L, 3.5), "sun", 40)
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
	var sc := BMStyle.label("%s / %s points   -   %d placements unused" % [BMUI.fmt_score(res.score), BMUI.fmt_score(res.target), res.unused], 20, BMStyle.CREAM, true)
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
		row.add_child(BMStyle.label("%+d" % line.value, 20, Color("#8a5a00") if int(line.value) >= 0 else Color("#c42848"), true))
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
	for e in res.get("events", []):
		var el := BMStyle.label(String(e), 20, BMStyle.MINT_L, true)
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(el)
	var total := BMStyle.hbox(8)
	total.alignment = BoxContainer.ALIGNMENT_CENTER
	total.add_child(BMStyle.label("YOU HAVE", 30, BMStyle.CREAM, true, 8))
	total.add_child(BMStyle.icon_rect("icon_coin", 1.0))
	total.add_child(BMStyle.label("%d" % run.credits, 40, BMStyle.SUN, true, 10))
	v.add_child(total)
	var last: bool = res.round >= BMRunConfig.ROUND_COUNT and not run.overtime
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
	var broken := run.machine_broken
	var ended_overtime := run.overtime and not won
	var can_overtime := won and not broken and not run.overtime
	var news: Dictionary = main.take_run_end_news()
	var v := _modal("panel_plate" if won or ended_overtime else "panel_boss", 760)
	if broken:
		BMAudio.sfx("machine_break")
		BMAudio.sfx_later("jingle_run_win", 1.4)
	else:
		BMAudio.sfx("jingle_run_win" if won else "jingle_lose")
	var title := "YOU WIN!" if won else ("RUN ABANDONED" if run.phase == BMRun.Phase.ABANDONED else "GAME OVER")
	if broken:
		title = "MACHINE BROKEN!"
	elif ended_overtime:
		title = "OVERTIME OVER"
	var t := BMStyle.label(title, 80, BMStyle.SUN if won or ended_overtime else BMStyle.PINK_L, true, 16)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if broken:
		t.add_theme_color_override("font_shadow_color", Color(BMStyle.PINK, 0.8))
		t.add_theme_constant_override("shadow_offset_x", 6)
		t.add_theme_constant_override("shadow_offset_y", 0)
	v.add_child(t)
	var reason_text := run.end_reason
	if ended_overtime:
		reason_text = "Your run was already a win. Overtime ended in round %d.\n%s" % [run.round_number, run.end_reason]
	var reason := BMStyle.label(reason_text, 20, BMStyle.CREAM, true)
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
	var round_text := "%d / %d" % [run.round_number, BMRunConfig.ROUND_COUNT]
	if run.overtime:
		round_text = "%d  (OVERTIME +%d)" % [run.round_number, run.round_number - BMRunConfig.ROUND_COUNT]
	var pairs := [["Round", round_text], ["Lines cleared", BMUI.fmt_int(s.lines_cleared)],
			["Last score", "%s / %s" % [BMUI.fmt_score(rs.score), BMUI.fmt_score(rs.target)]], ["Best placement", BMUI.fmt_score(s.best_placement)],
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
	var seed_l := BMStyle.label("Seed %d  -  %s%s" % [run.run_seed, BMRunConfig.kit(run.kit_id).name,
		"  -  practice seed: no achievements, records or unlocks" if run.custom_seed else ""], 20, BMStyle.TEXT_DIM)
	seed_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(seed_l)
	v.add_child(sp)
	var records: Array = news.get("records", [])
	if not records.is_empty():
		var rp := BMStyle.panel("panel_paper", Vector4(14, 6, 14, 8))
		var rv := BMStyle.vbox(2)
		rp.add_child(rv)
		for rec in records:
			var line := "NEW RECORD!  %s: %s" % [String(rec.label).to_upper(), _record_value(String(rec.key), int(rec.value))]
			if int(rec.before) > 0:
				line += "  (was %s)" % _record_value(String(rec.key), int(rec.before))
			var rl := BMStyle.label(line, 20, Color("#c42848"), true)
			rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rv.add_child(rl)
		v.add_child(rp)
		BMAudio.sfx_later("record_new", 0.9 if not broken else 2.2)
	for k in news.get("kits", []):
		var kp := BMStyle.panel("panel_sun", Vector4(14, 6, 14, 8))
		var kl := BMStyle.label("NEW KIT UNLOCKED: %s!" % String(BMRunConfig.kit(k).name).to_upper(), 30, BMStyle.INK, true)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kp.add_child(kl)
		v.add_child(kp)
		BMAudio.sfx_later("hand_triplets", 0.8)
	_new_kits = []
	var first: Button
	if can_overtime:
		# Overtime offer: keep the same build and push on into ever-bigger targets.
		var op := BMStyle.panel("panel_boss", Vector4(14, 8, 14, 10))
		var ov := BMStyle.vbox(6)
		op.add_child(ov)
		var oh := BMStyle.label("THE ARCADE STAYS OPEN...", 30, BMStyle.SUN, true, 8)
		oh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ov.add_child(oh)
		var ot := BMStyle.label("Keep this build and play on: round 13 needs %s, and every target after climbs faster. A boss every fourth round. Your win is already saved." % BMUI.fmt_int(BMRunConfig.target(BMRunConfig.ROUND_COUNT + 1)), 20, BMStyle.CREAM)
		ot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ov.add_child(ot)
		var go := BMStyle.button("KEEP PLAYING: OVERTIME  >", func() -> void:
			close_overlay()
			main.act({"a": "overtime"}), "sun", 30)
		go.custom_minimum_size = Vector2(0, 72)
		go.tooltip_text = "Rounds 13 and beyond. How far can your build go before the machine gives up?"
		ov.add_child(go)
		v.add_child(op)
		first = go
	var row := BMStyle.hbox(12)
	v.add_child(row)
	var again := BMStyle.button("NEW RUN", func() -> void:
		close_overlay()
		main.start_new_run(BMRun.random_seed()), "sun" if not can_overtime else "plum", 30)
	var same := BMStyle.button("SAME SEED", func() -> void:
		close_overlay()
		main.start_new_run(run.run_seed, run.kit_id, run.heat, "", true), "sky", 30)
	var title_b := BMStyle.button("TITLE", func() -> void:
		close_overlay()
		main.show_title(), "plum", 30)
	for b in [again, same, title_b]:
		b.custom_minimum_size = Vector2(0, 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	BMStyle.focus_later(first if first != null else again)
	if BMFx.instance and (won or ended_overtime):
		BMFx.instance.confetti(Rect2(Vector2.ZERO, size), 260)
	if broken and BMFx.instance:
		var c := size / 2.0
		BMFx.instance.shake(18.0)
		BMFx.instance.burst(c, [BMStyle.PINK, BMStyle.SUN, BMStyle.SKY, BMStyle.MINT, BMStyle.CREAM], 60, 900.0, 10.0)
		BMFx.instance.sparks(c, BMStyle.SUN_L, 30, 900.0)
		BMFx.instance.ring(c, BMStyle.PINK_L, 600.0)
		if BMSwirlBackground.instance:
			BMSwirlBackground.instance.pulse(1.0)
		if not main.settings.reduced_motion:
			var tw := t.create_tween().set_loops(6)
			tw.tween_property(t, "position:x", t.position.x + 8, 0.05)
			tw.tween_property(t, "position:x", t.position.x - 8, 0.05)
			tw.tween_property(t, "position:x", t.position.x, 0.05)


func _record_value(key: String, value: int) -> String:
	return str(value) if key in ["furthest_round", "machine_broken"] else BMUI.fmt_score(value)


# --- Item targeting --------------------------------------------------------------------------

const TOOL_PROMPTS := {
	"eraser": "ERASER: click up to 2 blocks to rub out",
	"punch": "PUNCH: click where to smash (plus shape)",
	"color_purge": "COLOR PURGE: click a block to remove its whole color",
	"lucky_paint": "LUCKY PAINT: click a tray piece to repaint",
	"blueprint": "BLUEPRINT: click a tray piece to swap",
	"emergency_brick": "BRICK: throw it at a tray slot, or click one",
	"patch_panel": "PATCH PANEL: click one block to remove",
	"tune_up": "TUNE-UP: click a tray piece to level up its family",
}


func _begin_tool(id: String, index: int) -> void:
	if not _input_enabled() and not (run.can_act_in_round() and _tool.is_empty()):
		return
	_cancel_hold("", false)
	var kind := "patch" if id == "patch_panel" else BMConsumables.target_kind(id)
	_tool = {"id": id, "i": index, "kind": kind, "cells": []}
	board_view.tool_kind = kind if kind in ["cells", "cell", "color", "patch"] else ""
	board_view.tool_marked.clear()
	BMAudio.sfx("tool_arm")
	_set_message(TOOL_PROMPTS.get(id, "CHOOSE A TARGET"), BMStyle.SUN_L, 0.0)
	_preview_hint.text = "Right-click or Esc to cancel"
	if id == "emergency_brick" and not main.settings.reduced_motion:
		_brick = BMBrickThrow.new()
		_tool_layer.add_child(_brick)
		var rects: Array[Rect2] = []
		for s in slots:
			rects.append(s.get_global_rect())
		_brick.slot_rects = rects
		var from := _items_box.get_global_rect().get_center()
		if index < _items_box.get_child_count():
			from = (_items_box.get_child(index) as Control).get_global_rect().get_center()
		_brick.start(from)
		_brick.hit.connect(func(slot: int) -> void:
			_brick = null
			_commit_tool({"slot": slot}))
		_brick.cancelled.connect(func() -> void:
			_brick = null
			_end_tool())
	refresh_all()


## Leaves targeting. `sound` plays the cancel whoosh.
func _end_tool(sound: bool = true) -> void:
	if _tool.is_empty():
		return
	_tool = {}
	board_view.tool_kind = ""
	board_view.tool_marked.clear()
	board_view.tool_hover = Vector2i(-1, -1)
	if _brick != null and is_instance_valid(_brick):
		_brick.queue_free()
	_brick = null
	if sound:
		BMAudio.sfx("tool_cancel")
	_marquee.message = ""
	_show_preview({})
	refresh_all()


func _tool_buttons() -> HBoxContainer:
	var row := BMStyle.hbox(6)
	if _tool.kind == "cells" and not _tool.cells.is_empty():
		var ok := BMStyle.button("ERASE %d" % _tool.cells.size(), func() -> void: _commit_tool({"cells": _cells_arg(_tool.cells)}), "mint", 20)
		ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(ok)
	var cancel := BMStyle.button("CANCEL", func() -> void: _end_tool(), "pink", 20)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.tooltip_text = "Put the item away (right-click or Esc)."
	row.add_child(cancel)
	return row


func _patch_card() -> BMCard:
	var card := BMCard.item_rack("eraser")
	card.custom_minimum_size = Vector2(248, 180)
	card.tooltip_body = "Patch Panel (Joker)\n" + BMJokers.get_def("patch_panel").text
	var box := card.get_child(0) as VBoxContainer
	((box.get_child(0) as HBoxContainer).get_child(1) as Label).text = "Patch Panel"
	var body := BMStyle.label("Remove one block of your choice.", 20, Color(BMStyle.INK, 0.75))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	if not _tool.is_empty() and _tool.id == "patch_panel":
		box.add_child(_tool_buttons())
	else:
		var use := BMStyle.button("PATCH", func() -> void: _begin_tool("patch_panel", -1), "mint", 20)
		use.disabled = not _tool.is_empty() or not run.can_act_in_round()
		box.add_child(use)
	return card


func _tool_input(event: InputEvent) -> void:
	if _brick != null:
		return # the brick handles its own pointer input
	if event is InputEventMouseMotion:
		var cell := board_view.cell_at_global(_mouse)
		if cell != board_view.tool_hover:
			board_view.tool_hover = cell
			if cell.x >= 0 and board_view.tool_kind != "":
				BMAudio.sfx("key_move", 1.1, -6.0)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_end_tool()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if board_view.tool_kind != "":
				var cell := board_view.cell_at_global(_mouse)
				if cell.x >= 0:
					_tool_pick_cell(cell)
					get_viewport().set_input_as_handled()
			else:
				for k in slots.size():
					if slots[k].get_global_rect().has_point(_mouse):
						_tool_pick_slot(k)
						get_viewport().set_input_as_handled()
						return


func _tool_key(event: InputEvent) -> void:
	if event.is_action("bm_cancel"):
		if _brick != null:
			_brick.cancel()
		else:
			_end_tool()
		return
	for k in 3:
		if event.is_action("bm_slot_%d" % (k + 1)) and board_view.tool_kind == "":
			if _brick != null:
				_brick.throw_to(k)
			else:
				_tool_pick_slot(k)
			return
	if board_view.tool_kind == "":
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
		var h := board_view.tool_hover if board_view.tool_hover.x >= 0 else Vector2i(3, 3)
		board_view.tool_hover = (h + move).clamp(Vector2i.ZERO, Vector2i(BMBoard.SIZE - 1, BMBoard.SIZE - 1))
		BMAudio.sfx("key_move")
	elif event.is_action("bm_place"):
		if _tool.kind == "cells" and not _tool.cells.is_empty() and board_view.tool_hover.x >= 0 and _tool.cells.has(board_view.tool_hover):
			_commit_tool({"cells": _cells_arg(_tool.cells)})
		elif board_view.tool_hover.x >= 0:
			_tool_pick_cell(board_view.tool_hover)


func _tool_pick_cell(cell: Vector2i) -> void:
	var empty := run.board.is_empty(cell)
	match String(_tool.kind):
		"cells":
			if empty:
				_deny("Pick a block, not an empty cell.")
				return
			var cells: Array = _tool.cells
			if cells.has(cell):
				cells.erase(cell)
			else:
				cells.append(cell)
			board_view.tool_marked.assign(cells)
			BMAudio.sfx("tool_mark", 1.0 + 0.1 * cells.size())
			if cells.size() >= BMConsumables.ERASER_CELLS:
				_commit_tool({"cells": _cells_arg(cells)})
			else:
				_set_message("%d OF 2 CHOSEN: PICK ANOTHER, OR PRESS ERASE" % cells.size(), BMStyle.SUN_L, 0.0)
				_refresh_items()
		"cell":
			var any := false
			for p: Vector2i in BMConsumables.punch_cells(cell):
				if not run.board.is_empty(p):
					any = true
			if not any:
				_deny("Nothing to hit there.")
				return
			_commit_tool({"cells": [[cell.x, cell.y]]})
		"color":
			if empty or run.board.get_cell(cell) == BMShapes.COLOR_STONE:
				_deny("Pick a colored block (stone is immune).")
				return
			_tool["center"] = cell
			_commit_tool({"color": run.board.get_cell(cell)})
		"patch":
			if empty:
				_deny("Pick a block, not an empty cell.")
				return
			_commit_tool({"x": cell.x, "y": cell.y})


func _tool_pick_slot(k: int) -> void:
	match String(_tool.kind):
		"slot":
			_commit_tool({"slot": k})
		"slot_color":
			if run.tray[k].is_empty():
				_deny("That slot is empty.")
				return
			_show_color_picker(k)
		"slot_shape":
			if run.tray[k].is_empty():
				_deny("That slot is empty.")
				return
			_show_shape_picker(k)


func _deny(text: String) -> void:
	BMAudio.sfx("deny")
	_set_message(text, BMStyle.PINK_L, 1.6)


static func _cells_arg(cells: Array) -> Array:
	var out: Array = []
	for c: Vector2i in cells:
		out.append([c.x, c.y])
	return out


func _commit_tool(target: Dictionary) -> void:
	if _tool.is_empty():
		return
	var tool := _tool.duplicate()
	var a := {"a": "patch"} if tool.id == "patch_panel" else {"a": "use", "i": int(tool.i)}
	a.merge(target, true)
	var hover := board_view.tool_hover
	_tool = {}
	board_view.tool_kind = ""
	board_view.tool_marked.clear()
	board_view.tool_hover = Vector2i(-1, -1)
	_marquee.message = ""
	_last_tool = tool
	_last_tool["hover"] = hover
	_do_action(a)
	if not _tool.is_empty():
		return
	refresh_all()


var _last_tool := {}
## Kits unlocked by the run that just ended (shown on the run-end screen).
var _new_kits: Array = []


## Presentation for a committed item: the tool arrives, then the cells go (state has already
## changed; the board keeps drawing removed cells until their delay passes).
func _present_tool(r: Dictionary) -> void:
	var fx := BMFx.instance
	var id: String = "patch_panel" if r.type == "patch" else String(r.item)
	var removed: Array = r.get("removed", [])
	match id:
		"eraser", "patch_panel":
			BMAudio.sfx("tool_erase")
			var d := 0.0
			for e in removed:
				_eraser_rub(board_view.cell_global_center(e.cell), d)
				board_view.play_removal([e], "erase", d + 0.22)
				d += 0.3
			_set_message("RUBBED OUT %d BLOCK%s" % [removed.size(), "" if removed.size() == 1 else "S"], BMStyle.PINK_L)
		"punch":
			var center: Vector2i = _last_tool.get("hover", Vector2i(-1, -1))
			if center.x < 0 and not removed.is_empty():
				center = removed[0].cell
			var at := board_view.cell_global_center(center)
			_hammer(at)
			board_view.play_removal(removed, "punch", 0.17, center)
			get_tree().create_timer(0.17).timeout.connect(func() -> void:
				BMAudio.sfx("tool_punch")
				if fx:
					fx.shake(16.0)
					fx.ring(at, BMStyle.SUN, 200.0)
					fx.pop_text(at + Vector2(0, -40), "SMASH!", BMStyle.SUN, 60, 60.0, 0.9)
				if BMCrtLayer.instance:
					BMCrtLayer.instance.shock(0.6))
			_set_message("PUNCHED OUT %d BLOCKS" % removed.size(), BMStyle.SUN)
		"color_purge":
			BMAudio.sfx("tool_purge")
			var col := int(r.get("color", _last_tool.get("color", 0)))
			if not removed.is_empty():
				col = int(removed[0].color)
			var origin: Vector2 = board_view.get_global_rect().get_center() + Vector2(0, -board_view.size.y * 0.45)
			_bucket_pour(origin, BMFinishes.hue(col))
			var center := board_view.cell_at_global(board_view.get_global_rect().get_center())
			board_view.play_removal(removed, "purge", 0.3, center)
			if fx:
				for e in removed:
					fx.stream(origin, board_view.cell_global_center(e.cell), BMFinishes.hue(col), 2)
			if BMSwirlBackground.instance:
				BMSwirlBackground.instance.pulse(0.8)
			_set_message("PURGED %d %s BLOCKS" % [removed.size(), BMShapes.COLOR_NAMES[col].to_upper()], BMStyle.MINT_L)
		"lucky_paint":
			BMAudio.sfx("tool_paint")
			var sl: BMTraySlot = slots[int(r.slot)]
			sl.flare()
			sl.land()
			var c := BMFinishes.hue(int(r.color))
			if fx:
				fx.burst(sl.get_global_rect().get_center(), [c, c.lightened(0.3), BMStyle.CREAM], 30, 520.0, 10.0)
				fx.pop_text(sl.get_global_rect().get_center() + Vector2(0, -80), "SPLASH!", c, 40, 50.0, 0.9)
			_set_message("REPAINTED %s" % BMShapes.COLOR_NAMES[int(r.color)].to_upper(), c)
		"blueprint":
			BMAudio.sfx("tool_blueprint")
			var sl: BMTraySlot = slots[int(r.slot)]
			sl.land()
			sl.flare()
			if fx:
				fx.bits(sl.get_global_rect().get_center(), [BMStyle.SKY, BMStyle.SKY_L, BMStyle.CREAM], 16)
				fx.ring(sl.get_global_rect().get_center(), BMStyle.SKY_L, 130.0)
			_set_message("BLUEPRINT: A FRESH PIECE, DRAFTED", BMStyle.SKY_L)
		"emergency_brick":
			_brick_impact(r)
		"tune_up":
			BMAudio.sfx("tool_blueprint")
			var sl: BMTraySlot = slots[int(r.slot)]
			sl.land()
			sl.flare()
			if fx:
				fx.stars(sl.get_global_rect().get_center(), 8, 90.0, BMStyle.SUN_L)
				fx.pop_text(sl.get_global_rect().get_center() + Vector2(0, -80), "LV %d!" % int(r.level), BMStyle.SUN_L, 40, 50.0, 1.0)
			_set_message("TUNE-UP: %s IS NOW LEVEL %d" % [BMShapes.family(StringName(r.family)).name.to_upper(), int(r.level)], BMStyle.SUN_L)


func _brick_impact(r: Dictionary) -> void:
	var sl: BMTraySlot = slots[int(r.slot)]
	var at := sl.get_global_rect().get_center()
	sl.land()
	sl.flare()
	BMAudio.sfx("brick_impact")
	var smashed: Dictionary = r.get("smashed", {})
	var fx := BMFx.instance
	if fx:
		fx.shake(22.0)
		fx.dust(at + Vector2(0, 50), 180.0, 22)
		fx.chips(at, [Color("#b5472f"), Color("#7d2a1c"), Color("#d9c7a8"), Color("#e0704f")], 18)
		fx.ring(at, BMStyle.CREAM, 180.0)
		if not smashed.is_empty():
			var c := BMFinishes.hue(int(smashed.color))
			fx.shards(at, 26, c)
			fx.burst(at, [c, c.lightened(0.3)], 20, 560.0, 10.0)
			fx.pop_text(at + Vector2(0, -90), "SMASH!", BMStyle.PINK_L, 80, 70.0, 1.1)
		else:
			fx.pop_text(at + Vector2(0, -90), "BRICK!", BMStyle.SUN, 60, 60.0, 1.0)
	if BMCrtLayer.instance:
		BMCrtLayer.instance.shock(0.9)
	if BMSwirlBackground.instance:
		BMSwirlBackground.instance.pulse(0.6)
	_set_message("SMASHED %s!" % BMPieces.describe(smashed).get_slice("\n", 0).to_upper() if not smashed.is_empty() else "BRICK IN THE TRAY", BMStyle.SUN)


## A sprite from the UI kit that lives on the effects layer for a short tween.
func _tool_sprite(icon: String, at: Vector2, px_scale: float) -> TextureRect:
	var fx := BMFx.instance
	if fx == null or main.settings.reduced_motion:
		return null
	var t := TextureRect.new()
	t.texture = BMStyle.tex(icon)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sz: Vector2 = t.texture.get_size() * px_scale
	t.size = sz
	t.pivot_offset = sz / 2.0
	t.position = at - sz / 2.0
	fx.add_child(t)
	return t


func _eraser_rub(at: Vector2, delay: float) -> void:
	var t := _tool_sprite("icon_eraser", at + Vector2(0, -10), 2.0)
	if t == null:
		return
	t.modulate.a = 0.0
	var base := t.position
	var tw := t.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(t, "modulate:a", 1.0, 0.05)
	for i in 3:
		tw.tween_property(t, "position", base + Vector2(-18, 4), 0.05)
		tw.tween_property(t, "position", base + Vector2(18, -4), 0.05)
	tw.tween_property(t, "modulate:a", 0.0, 0.15)
	tw.tween_callback(t.queue_free)


func _hammer(at: Vector2) -> void:
	var t := _tool_sprite("icon_hammer", at + Vector2(70, -150), 3.0)
	if t == null:
		return
	t.rotation = -1.1
	var tw := t.create_tween()
	tw.tween_property(t, "position", at - t.size / 2.0 + Vector2(26, -36), 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(t, "rotation", 0.45, 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(t, "rotation", 0.2, 0.08)
	tw.tween_property(t, "position", t.position + Vector2(40, -60), 0.25).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(t, "modulate:a", 0.0, 0.25)
	tw.tween_callback(t.queue_free)


func _bucket_pour(at: Vector2, color: Color) -> void:
	var t := _tool_sprite("icon_bucket", at, 3.0)
	if t == null:
		return
	t.modulate = Color(1, 1, 1, 0)
	var tw := t.create_tween()
	tw.tween_property(t, "modulate:a", 1.0, 0.1)
	tw.tween_property(t, "rotation", 2.2, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.4)
	tw.tween_property(t, "modulate:a", 0.0, 0.2)
	tw.tween_callback(t.queue_free)
	if BMFx.instance:
		BMFx.instance.burst(at + Vector2(0, 30), [color, color.lightened(0.4)], 24, 300.0, 8.0)


## Lucky Paint: pick one of the six colors (named swatches).
func _show_color_picker(k: int) -> void:
	var v := _modal("panel_plate", 760)
	BMAudio.sfx("modal")
	var t := BMStyle.label("PAINT IT WHICH COLOR?", 30, BMStyle.SUN, true, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var first: Button
	for c in BMShapes.OFFER_COLOR_COUNT:
		var name: String = BMShapes.COLOR_NAMES[c]
		var b := BMStyle.button(name.to_upper(), func() -> void:
			close_overlay()
			_commit_tool({"slot": k, "color": c}), "plum", 20)
		b.icon = BMStyle.block_tex(c)
		b.expand_icon = false
		b.custom_minimum_size = Vector2(220, 72)
		b.disabled = c == int(run.tray[k].color)
		if b.disabled:
			b.tooltip_text = "Already this color."
		grid.add_child(b)
		if first == null and not b.disabled:
			first = b
	var back := BMStyle.button("BACK", func() -> void:
		close_overlay()
		_end_tool(), "pink", 20)
	back.custom_minimum_size = Vector2(0, 60)
	v.add_child(back)
	BMStyle.focus_later(first)


## Blueprint: pick one of the small shapes.
func _show_shape_picker(k: int) -> void:
	var v := _modal("panel_plate", 860)
	BMAudio.sfx("modal")
	var t := BMStyle.label("DRAFT A NEW PIECE", 30, BMStyle.SKY_L, true, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var color := int(run.tray[k].color)
	var first: Button
	for c in BMConsumables.BLUEPRINT_CHOICES.size():
		var pick: Array = BMConsumables.BLUEPRINT_CHOICES[c]
		var sh := BMShapes.make_shape(StringName(pick[0]), int(pick[1]), color)
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 120)
		b.focus_mode = Control.FOCUS_ALL
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, BMStyle.box("panel_inset" if st == "normal" else "panel_sun", Vector4.ZERO))
		b.tooltip_text = BMShapes.family(sh.family).name
		var draw := Control.new()
		draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		draw.draw.connect(func() -> void:
			var dims := Vector2(BMShapes.shape_size(sh))
			var cell := 28.0
			BMBlockPainter.draw_shape(draw, sh, ((draw.size - dims * cell) / 2.0).round(), cell))
		b.add_child(draw)
		b.pressed.connect(func() -> void:
			close_overlay()
			_commit_tool({"slot": k, "choice": c}))
		grid.add_child(b)
		if first == null:
			first = b
	var back := BMStyle.button("BACK", func() -> void:
		close_overlay()
		_end_tool(), "pink", 20)
	back.custom_minimum_size = Vector2(0, 60)
	v.add_child(back)
	BMStyle.focus_later(first)


# --- Feats and Insurance -----------------------------------------------------------------------

## A gold medal plate that slams in over the board and floats away. Text states the Feat, so it
## never depends on color or motion (reduced motion shows it still, then removes it).
func _feat_banner(feat: String, delay: float, row: int) -> void:
	var fx := BMFx.instance
	if fx == null:
		return
	var d := BMFeats.get_def(feat)
	var plate := BMStyle.panel("panel_sun", Vector4(14, 6, 18, 8))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := BMStyle.hbox(10)
	plate.add_child(h)
	var medal := TextureRect.new()
	medal.texture = BMStyle.tex("icon_medal")
	medal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	medal.custom_minimum_size = medal.texture.get_size() * 1.5
	medal.stretch_mode = TextureRect.STRETCH_SCALE
	h.add_child(medal)
	var v := BMStyle.vbox(0)
	h.add_child(v)
	v.add_child(BMStyle.label(String(d.name).to_upper() + "!", 30, BMStyle.INK, true))
	var desc := BMStyle.label(String(d.text), 20, Color(BMStyle.INK, 0.75))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(440, 0)
	v.add_child(desc)
	plate.visible = false
	fx.add_child(plate)
	var ref: WeakRef = weakref(plate)
	var board := board_view.get_global_rect()
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		var p := ref.get_ref() as PanelContainer
		if p == null:
			return
		p.reset_size()
		p.pivot_offset = p.size / 2.0
		p.position = Vector2(board.get_center().x - p.size.x / 2.0, board.position.y + 110 + row * 96).round()
		p.visible = true
		BMAudio.sfx("feat", 1.0 + 0.12 * row)
		if BMFx.instance:
			BMFx.instance.stars(p.get_global_rect().get_center(), 8, p.size.x * 0.5, BMStyle.SUN_L)
		var tw := p.create_tween()
		if not main.settings.reduced_motion:
			p.scale = Vector2(0.3, 0.3)
			p.rotation = -0.12
			tw.tween_property(p, "scale", Vector2(1.12, 1.12), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(p, "rotation", 0.03, 0.14)
			tw.tween_property(p, "scale", Vector2.ONE, 0.08)
			tw.parallel().tween_property(p, "rotation", 0.0, 0.08)
			tw.tween_interval(1.0)
			tw.tween_property(p, "position:y", p.position.y - 60, 0.35).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(p, "modulate:a", 0.0, 0.35)
		else:
			tw.tween_interval(1.6)
		tw.tween_callback(p.queue_free))


## Insurance Policy paid out: a stamp slams onto the screen, then a dialog explains the replay.
func _show_insurance_claim() -> void:
	BMAudio.sfx("insurance")
	var fx := BMFx.instance
	if fx:
		fx.shake(12.0)
		fx.confetti(Rect2(Vector2.ZERO, size), 80)
		var t := _tool_sprite("icon_shield", board_view.get_global_rect().get_center(), 8.0)
		if t != null:
			t.scale = Vector2(2.2, 2.2)
			t.rotation = -0.4
			var tw := t.create_tween()
			tw.tween_property(t, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(t, "rotation", 0.08, 0.18)
			tw.tween_interval(0.5)
			tw.tween_property(t, "modulate:a", 0.0, 0.3)
			tw.tween_callback(t.queue_free)
	_intro_shown_for = run.round_number
	get_tree().create_timer(0.0 if main.settings.reduced_motion else 0.9).timeout.connect(func() -> void:
		if overlay.get_child_count() > 0:
			return
		var v := _modal("panel_plate", 680)
		var title := BMStyle.label("INSURANCE CLAIMED!", 60, BMStyle.MINT_L, true, 14)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(title)
		var body := BMStyle.label("Your policy paid out. Round %d starts over from an empty board, without the free Refresh. The Insurance Policy card is used up." % run.round_number, 20, BMStyle.CREAM)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(body)
		var b := BMStyle.button("TRY AGAIN", func() -> void:
			close_overlay()
			_spin_tray(0.05, _tray_hand()), "mint", 40)
		b.custom_minimum_size = Vector2(0, 88)
		v.add_child(b)
		BMStyle.focus_later(b))



## The Warden's bars shatter off a tray well.
func _warden_unlock(slot: int) -> void:
	var at := slots[slot].get_global_rect().get_center()
	BMAudio.sfx_later("warden_unlock", 0.1)
	var fx := BMFx.instance
	if fx:
		fx.shards(at, 24, BMStyle.PLUM_LL)
		fx.sparks(at, BMStyle.SUN_L, 14)
		fx.pop_text(at + Vector2(0, -90), "FREE!", BMStyle.MINT_L, 60, 60.0, 1.0)
	slots[slot].flare()


## The Hold box: the stored piece on the right, the rule on the left. Presentation of
## round_state.held / hold_used only.
class HoldBox extends Control:
	var shape: Dictionary = {}
	var used := false
	var blocked := false
	var drop_ready := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = "HOLD (H): store a tray piece; its slot draws a new one. Later, swap it back in or click here to return it to an empty slot. Once between placements."

	func _draw() -> void:
		draw_style_box(BMStyle.box("panel_plate", Vector4.ZERO), Rect2(Vector2.ZERO, size))
		var well := Rect2(Vector2(size.x - 196, 12), Vector2(184, size.y - 24))
		draw_style_box(BMStyle.box("panel_inset", Vector4.ZERO), well)
		if drop_ready:
			draw_rect(well.grow(-5), BMStyle.MINT_L, false, 4.0)
		draw_string(BMStyle.font_bold, Vector2(26, 50), "HOLD", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, BMStyle.MINT_L if drop_ready else BMStyle.SUN)
		var line1 := "LOCKED BY BOSS" if blocked else ("USED THIS TURN" if used else ("DROP IT HERE" if drop_ready else "PRESS H OR DROP"))
		var col := BMStyle.PINK_L if blocked or used else BMStyle.CREAM
		draw_string(BMStyle.font_bold, Vector2(26, 92), line1, HORIZONTAL_ALIGNMENT_LEFT, size.x - 240, 20, col)
		draw_string(BMStyle.font, Vector2(26, 124), "Store a piece, swap later.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 240, 20, BMStyle.TEXT_DIM)
		draw_string(BMStyle.font, Vector2(26, 150), "Once per placement.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 240, 20, BMStyle.TEXT_DIM)
		if shape.is_empty():
			draw_string(BMStyle.font, Vector2(well.position.x, well.get_center().y + 10), "EMPTY", HORIZONTAL_ALIGNMENT_CENTER, well.size.x, 20, BMStyle.TEXT_DIM)
		else:
			var dims := Vector2(BMShapes.shape_size(shape))
			var cell := minf(30.0, floorf(minf((well.size.x - 24) / dims.x, (well.size.y - 24) / dims.y)))
			var at := (well.position + (well.size - dims * cell) / 2.0).round()
			BMBlockPainter.draw_shape(self, shape, at, cell, 0.55 if used else 1.0, Color.WHITE, "classic")
