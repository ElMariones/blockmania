class_name BMShopScreen
extends Control
## Between-round shop: Jokers, items, Workshop cards (bag edits), and pieces for sale; reroll,
## owned Jokers (sell and reorder), the bag, and the upcoming boss. Prices and full rules text
## are visible before buying. Workshop cards open a bag picker to choose their targets; the
## purchase happens only when the choice is confirmed.

var main: Node
var run: BMRun

var _credits_label: Label
var _jokers_row: HBoxContainer
var _items_row: HBoxContainer
var _tools_row: HBoxContainer
var _pieces_row: HBoxContainer
var _reroll_button: Button
var _bag_button: Button
var _owned_box: VBoxContainer
var _owned_header: Label
var _owned_items: VBoxContainer
var _next_label: Label
var _boss_label: Label
var _message: Label
var _overlay: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var cols := BMUI.hbox(36)
	margin.add_child(cols)

	var left := BMUI.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var head := BMUI.hbox(20)
	left.add_child(head)
	head.add_child(BMUI.label("SHOP", 52, BMPalette.CYAN))
	_credits_label = BMUI.label("", 32, BMPalette.BRASS)
	_credits_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_credits_label)
	_bag_button = BMUI.button("View Bag", _show_bag, 20)
	head.add_child(_bag_button)
	_reroll_button = BMUI.button("Reroll", func() -> void: _act({"a": "reroll"}), 20)
	_reroll_button.tooltip_text = "Replace every offer in the shop. The price rises by 1 each reroll."
	head.add_child(_reroll_button)
	_next_label = BMUI.label("", 19, BMPalette.TEXT_DIM)
	left.add_child(_next_label)

	var row1 := BMUI.hbox(28)
	left.add_child(row1)
	var jcol := BMUI.vbox(6)
	row1.add_child(jcol)
	jcol.add_child(BMUI.label("JOKERS", 18, BMPalette.TEXT_DIM))
	_jokers_row = BMUI.hbox(14)
	jcol.add_child(_jokers_row)
	var icol := BMUI.vbox(6)
	row1.add_child(icol)
	icol.add_child(BMUI.label("ITEMS", 18, BMPalette.TEXT_DIM))
	_items_row = BMUI.hbox(14)
	icol.add_child(_items_row)

	var row2 := BMUI.hbox(28)
	left.add_child(row2)
	var tcol := BMUI.vbox(6)
	row2.add_child(tcol)
	tcol.add_child(BMUI.label("WORKSHOP  (edit your bag)", 18, BMPalette.TEXT_DIM))
	_tools_row = BMUI.hbox(14)
	tcol.add_child(_tools_row)
	var pcol := BMUI.vbox(6)
	row2.add_child(pcol)
	pcol.add_child(BMUI.label("PIECES FOR YOUR BAG", 18, BMPalette.TEXT_DIM))
	_pieces_row = BMUI.hbox(14)
	pcol.add_child(_pieces_row)

	_message = BMUI.label("", 20, BMPalette.CORAL)
	left.add_child(_message)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	var boss_panel := BMUI.panel(BMPalette.BG_DEEP, BMPalette.CORAL)
	left.add_child(boss_panel)
	_boss_label = BMUI.label("", 18)
	_boss_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_panel.add_child(_boss_label)
	var leave := BMUI.button("Next Round  >", func() -> void: _act({"a": "leave_shop"}), 26)
	leave.name = "LeaveButton"
	left.add_child(leave)

	var right := BMUI.vbox(10)
	right.custom_minimum_size.x = 420
	cols.add_child(right)
	_owned_header = BMUI.label("", 18, BMPalette.TEXT_DIM)
	right.add_child(_owned_header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_owned_box = BMUI.vbox(8)
	_owned_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_owned_box)
	right.add_child(BMUI.label("YOUR ITEMS", 18, BMPalette.TEXT_DIM))
	_owned_items = BMUI.vbox(8)
	right.add_child(_owned_items)

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


func bind(new_run: BMRun) -> void:
	run = new_run
	_message.text = ""
	BMUI.clear_children(_overlay)
	refresh_all()
	var leave := find_child("LeaveButton", true, false) as Button
	if leave:
		leave.grab_focus.call_deferred()


func _act(a: Dictionary) -> Dictionary:
	var r: Dictionary = main.act(a)
	_message.text = "" if r.ok else r.error
	if r.ok and a.a in ["buy_tool", "buy_piece"]:
		_message.add_theme_color_override("font_color", BMPalette.CYAN)
		_message.text = _purchase_text(r)
	else:
		_message.add_theme_color_override("font_color", BMPalette.CORAL)
	if run.phase == BMRun.Phase.SHOP:
		refresh_all()
	return r


func _purchase_text(r: Dictionary) -> String:
	if r.type == "buy_piece":
		return "Added %s to your bag (%d pieces)." % [BMPieces.describe(r.piece).get_slice("\n", 0), run.bag.size()]
	return "Used %s." % BMTools.get_def(r.item).name


func _unhandled_input(event: InputEvent) -> void:
	if _overlay.get_child_count() > 0 and event.is_action_pressed("bm_cancel"):
		BMUI.clear_children(_overlay)
		get_viewport().set_input_as_handled()
	elif _overlay.get_child_count() == 0 and event.is_action_pressed("bm_bag"):
		_show_bag()
		get_viewport().set_input_as_handled()


func refresh_all() -> void:
	if run == null or run.phase != BMRun.Phase.SHOP:
		return
	_credits_label.text = "Credits  %d" % run.credits
	_reroll_button.text = "Reroll  (%d)" % run.shop.reroll_cost
	_reroll_button.disabled = run.credits < int(run.shop.reroll_cost)
	_bag_button.text = "View Bag  (%d)" % run.bag.size()
	var next := run.round_number + 1
	_next_label.text = "Next: round %d of %d, target %s%s" % [next, BMRunConfig.ROUND_COUNT, BMUI.fmt_int(BMRunConfig.target(next)), "   (BOSS ROUND)" if BMRunConfig.is_boss_round(next) else ""]
	var boss_id: String = run.bosses[BMRunConfig.act_of(next) - 1]
	var bd := BMBosses.get_def(boss_id)
	_boss_label.text = "Upcoming boss (round %d): %s. %s" % [BMRunConfig.act_of(next) * 4, bd.name, bd.rule]

	BMUI.clear_children(_jokers_row)
	for i in run.shop.jokers.size():
		var id: String = run.shop.jokers[i]
		if id == "":
			_jokers_row.add_child(_sold_out(250))
			continue
		var cost := BMJokers.cost(id)
		var buy := _buy_button(cost, func() -> void: _act({"a": "buy_joker", "i": i}))
		if run.jokers.size() >= run.joker_slots():
			buy.disabled = true
			buy.tooltip_text = "Joker slots are full. Sell one first."
		_jokers_row.add_child(BMUI.joker_card(null, id, buy, 250))

	BMUI.clear_children(_items_row)
	for i in run.shop.consumables.size():
		var id: String = run.shop.consumables[i]
		if id == "":
			_items_row.add_child(_sold_out(230))
			continue
		var buy := _buy_button(BMConsumables.cost(id), func() -> void: _act({"a": "buy_consumable", "i": i}))
		if run.consumables.size() >= BMRunConfig.CONSUMABLE_SLOTS:
			buy.disabled = true
			buy.tooltip_text = "Item slots are full. Use an item first."
		_items_row.add_child(BMUI.item_card(id, buy, 230))

	BMUI.clear_children(_tools_row)
	for i in run.shop.tools.size():
		var o: Dictionary = run.shop.tools[i]
		if o.is_empty():
			_tools_row.add_child(_sold_out(290))
			continue
		var def := BMTools.get_def(o.id)
		var buy := _buy_button(int(def.cost), func() -> void: _begin_tool(i))
		if int(def.max_targets) > 0:
			buy.text = "Choose pieces  %d" % int(def.cost)
		_tools_row.add_child(_tool_card(o, buy))

	BMUI.clear_children(_pieces_row)
	for i in run.shop.pieces.size():
		var d: Dictionary = run.shop.pieces[i]
		if d.is_empty():
			_pieces_row.add_child(_sold_out(250))
			continue
		var buy := _buy_button(int(d.cost), func() -> void: _act({"a": "buy_piece", "i": i}))
		if run.bag.size() >= BMPieces.MAX_BAG:
			buy.disabled = true
			buy.tooltip_text = "Your bag is full."
		_pieces_row.add_child(_piece_card(BMPieces.from_dict(d), buy))

	BMUI.clear_children(_owned_box)
	_owned_header.text = "YOUR JOKERS  %d / %d   (resolve top to bottom)" % [run.jokers.size(), run.joker_slots()]
	for i in run.jokers.size():
		var id := run.jokers[i]
		var row := BMUI.hbox(6)
		var up := BMUI.button("Up", func() -> void: _act({"a": "move", "from": i, "to": i - 1}), 14)
		up.disabled = i == 0
		var down := BMUI.button("Down", func() -> void: _act({"a": "move", "from": i, "to": i + 1}), 14)
		down.disabled = i == run.jokers.size() - 1
		var sell := BMUI.button("Sell +%d" % BMJokers.sell_value(id), func() -> void: _act({"a": "sell", "i": i}), 14)
		row.add_child(up)
		row.add_child(down)
		row.add_child(sell)
		_owned_box.add_child(BMUI.joker_card(run, id, row))
	if run.jokers.is_empty():
		_owned_box.add_child(BMUI.label("None yet.", 18, BMPalette.TEXT_DIM))
	BMUI.clear_children(_owned_items)
	for id in run.consumables:
		_owned_items.add_child(BMUI.item_card(id))
	if run.consumables.is_empty():
		_owned_items.add_child(BMUI.label("None.", 18, BMPalette.TEXT_DIM))


func _buy_button(cost: int, cb: Callable) -> Button:
	var b := BMUI.button("Buy  %d" % cost, cb, 18)
	if run.credits < cost:
		b.disabled = true
		b.tooltip_text = "Not enough Credits."
	return b


func _sold_out(width: float) -> Control:
	var l := BMUI.label("Sold out", 18, BMPalette.TEXT_DIM)
	l.custom_minimum_size = Vector2(width, 100)
	return l


func _tool_card(o: Dictionary, buy: Button) -> PanelContainer:
	var p := BMUI.panel(BMPalette.PANEL, BMPalette.BRASS)
	p.custom_minimum_size.x = 290
	var v := BMUI.vbox(4)
	p.add_child(v)
	var head := BMUI.hbox(6)
	v.add_child(head)
	var n := BMUI.label(BMTools.offer_name(o), 19)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	head.add_child(BMUI.label("WORKSHOP", 13, BMPalette.BRASS))
	var t := BMUI.label(BMTools.offer_text(o, run), 15, BMPalette.TEXT_DIM)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	v.add_child(buy)
	p.tooltip_text = "%s\n%s" % [BMTools.offer_name(o), BMTools.offer_text(o, run)]
	return p


func _piece_card(piece: Dictionary, buy: Button) -> PanelContainer:
	var p := BMUI.panel(BMPalette.BG_DEEP, BMPalette.CYAN)
	p.custom_minimum_size.x = 250
	var v := BMUI.vbox(4)
	p.add_child(v)
	var head := BMUI.hbox(6)
	v.add_child(head)
	var n := BMUI.label("%s %s" % [BMShapes.COLOR_NAMES[int(piece.color)], BMShapes.family(piece.family).name], 18)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	head.add_child(BMUI.label("PIECE", 13, BMPalette.CYAN))
	var holder := CenterContainer.new()
	var tile := BMPieceTile.new(piece)
	holder.add_child(tile)
	v.add_child(holder)
	var desc := BMPieces.describe(piece)
	var t := BMUI.label(BMPieces.brief(piece), 14, BMPalette.TEXT_DIM)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	v.add_child(buy)
	p.tooltip_text = desc
	return p


# --- Bag viewer and Workshop picker ------------------------------------------------------------

func _overlay_panel(min_width: float) -> VBoxContainer:
	BMUI.clear_children(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var p := BMUI.panel(BMPalette.PANEL, BMPalette.CYAN)
	p.custom_minimum_size.x = min_width
	center.add_child(p)
	var v := BMUI.vbox(12)
	p.add_child(v)
	return v


func _show_bag() -> void:
	var v := _overlay_panel(1180)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1140, 680)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var bv := BMBagView.new()
	bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(bv)
	bv.setup(run)
	var close := BMUI.button("Close (Esc)", func() -> void: BMUI.clear_children(_overlay), 20)
	v.add_child(close)
	close.grab_focus.call_deferred()


func _begin_tool(index: int) -> void:
	var o: Dictionary = run.shop.tools[index]
	var def := BMTools.get_def(o.id)
	var max_t := int(def.max_targets)
	if max_t == 0:
		_act({"a": "buy_tool", "i": index, "targets": [], "color": -1})
		return
	var v := _overlay_panel(1180)
	v.add_child(BMUI.label("%s  (%d Credits)" % [BMTools.offer_name(o), int(def.cost)], 30, BMPalette.BRASS))
	var t := BMUI.label(BMTools.offer_text(o, run), 18, BMPalette.TEXT_DIM)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var status := BMUI.label("Choose up to %d piece%s." % [max_t, "s" if max_t > 1 else ""], 18)
	v.add_child(status)
	var state := {"targets": [], "color": -1}
	var confirm := BMUI.button("Confirm purchase", func() -> void: pass, 22)
	var update := func() -> void:
		var ok: bool = not state.targets.is_empty() and (def.kind != "repaint" or state.color >= 0)
		confirm.disabled = not ok
		var picked := "%d of %d chosen" % [state.targets.size(), max_t]
		if def.kind == "repaint":
			picked += ", color: %s" % (BMShapes.COLOR_NAMES[state.color] if state.color >= 0 else "none")
		status.text = picked
	if def.kind == "repaint":
		var colors := BMUI.hbox(8)
		v.add_child(colors)
		for c in BMShapes.OFFER_COLOR_COUNT:
			var cb := BMUI.button(BMShapes.COLOR_NAMES[c], func() -> void:
				state.color = c
				update.call(), 18)
			cb.add_theme_color_override("font_color", BMPalette.block(c))
			colors.add_child(cb)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1140, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var bv := BMBagView.new()
	bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(bv)
	bv.setup(run, max_t)
	bv.selection_changed.connect(func(uids: Array) -> void:
		state.targets = uids
		update.call())
	var row := BMUI.hbox(12)
	v.add_child(row)
	confirm.pressed.connect(func() -> void:
		var r := _act({"a": "buy_tool", "i": index, "targets": state.targets, "color": state.color})
		if r.ok:
			BMUI.clear_children(_overlay)
		else:
			status.text = r.error
			status.add_theme_color_override("font_color", BMPalette.CORAL))
	row.add_child(confirm)
	row.add_child(BMUI.button("Cancel (Esc)", func() -> void: BMUI.clear_children(_overlay), 20))
	update.call()
