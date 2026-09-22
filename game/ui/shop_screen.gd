class_name BMShopScreen
extends Control
## Between-round shop: three Joker offers, two item offers, reroll, owned Jokers (sell and
## reorder), items, and the upcoming boss. Prices and full rules text are visible before buying.

var main: Node
var run: BMRun

var _credits_label: Label
var _offers_row: HBoxContainer
var _items_row: HBoxContainer
var _reroll_button: Button
var _owned_box: VBoxContainer
var _owned_header: Label
var _owned_items: VBoxContainer
var _next_label: Label
var _boss_label: Label
var _message: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var cols := BMUI.hbox(40)
	margin.add_child(cols)

	var left := BMUI.vbox(16)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var head := BMUI.hbox(24)
	left.add_child(head)
	head.add_child(BMUI.label("SHOP", 56, BMPalette.CYAN))
	_credits_label = BMUI.label("", 34, BMPalette.BRASS)
	_credits_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_credits_label)
	_reroll_button = BMUI.button("Reroll", func() -> void: _act({"a": "reroll"}), 22)
	head.add_child(_reroll_button)
	_next_label = BMUI.label("", 20, BMPalette.TEXT_DIM)
	left.add_child(_next_label)
	left.add_child(BMUI.label("JOKERS", 20, BMPalette.TEXT_DIM))
	_offers_row = BMUI.hbox(20)
	left.add_child(_offers_row)
	left.add_child(BMUI.label("ITEMS", 20, BMPalette.TEXT_DIM))
	_items_row = BMUI.hbox(20)
	left.add_child(_items_row)
	_message = BMUI.label("", 20, BMPalette.CORAL)
	left.add_child(_message)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	var boss_panel := BMUI.panel(BMPalette.BG_DEEP, BMPalette.CORAL)
	left.add_child(boss_panel)
	_boss_label = BMUI.label("", 19)
	_boss_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_panel.add_child(_boss_label)
	var leave := BMUI.button("Next Round  >", func() -> void: _act({"a": "leave_shop"}), 28)
	leave.name = "LeaveButton"
	left.add_child(leave)

	var right := BMUI.vbox(10)
	right.custom_minimum_size.x = 460
	cols.add_child(right)
	_owned_header = BMUI.label("", 20, BMPalette.TEXT_DIM)
	right.add_child(_owned_header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_owned_box = BMUI.vbox(8)
	_owned_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_owned_box)
	right.add_child(BMUI.label("YOUR ITEMS", 20, BMPalette.TEXT_DIM))
	_owned_items = BMUI.vbox(8)
	right.add_child(_owned_items)


func bind(new_run: BMRun) -> void:
	run = new_run
	_message.text = ""
	refresh_all()
	var leave := find_child("LeaveButton", true, false) as Button
	if leave:
		leave.grab_focus.call_deferred()


func _act(a: Dictionary) -> void:
	var r: Dictionary = main.act(a)
	_message.text = "" if r.ok else r.error
	if run.phase == BMRun.Phase.SHOP:
		refresh_all()


func refresh_all() -> void:
	if run == null or run.phase != BMRun.Phase.SHOP:
		return
	_credits_label.text = "Credits  %d" % run.credits
	_reroll_button.text = "Reroll  (%d)" % run.shop.reroll_cost
	_reroll_button.disabled = run.credits < int(run.shop.reroll_cost)
	var next := run.round_number + 1
	_next_label.text = "Next: round %d of %d, target %s%s" % [next, BMRunConfig.ROUND_COUNT, BMUI.fmt_int(BMRunConfig.target(next)), "   (BOSS ROUND)" if BMRunConfig.is_boss_round(next) else ""]
	var boss_id: String = run.bosses[BMRunConfig.act_of(next) - 1]
	var bd := BMBosses.get_def(boss_id)
	_boss_label.text = "Upcoming boss (round %d): %s\n%s" % [BMRunConfig.act_of(next) * 4, bd.name, bd.rule]

	BMUI.clear_children(_offers_row)
	for i in run.shop.jokers.size():
		var id: String = run.shop.jokers[i]
		if id == "":
			var sold := BMUI.label("Sold out", 20, BMPalette.TEXT_DIM)
			sold.custom_minimum_size = Vector2(300, 120)
			_offers_row.add_child(sold)
			continue
		var cost := BMJokers.cost(id)
		var buy := BMUI.button("Buy  %d" % cost, func() -> void: _act({"a": "buy_joker", "i": i}), 20)
		if run.credits < cost:
			buy.disabled = true
			buy.tooltip_text = "Not enough Credits."
		elif run.jokers.size() >= run.joker_slots():
			buy.disabled = true
			buy.tooltip_text = "Joker slots are full. Sell one first."
		_offers_row.add_child(BMUI.joker_card(null, id, buy, 300))

	BMUI.clear_children(_items_row)
	for i in run.shop.consumables.size():
		var id: String = run.shop.consumables[i]
		if id == "":
			var sold := BMUI.label("Sold out", 20, BMPalette.TEXT_DIM)
			sold.custom_minimum_size = Vector2(300, 100)
			_items_row.add_child(sold)
			continue
		var cost := BMConsumables.cost(id)
		var buy := BMUI.button("Buy  %d" % cost, func() -> void: _act({"a": "buy_consumable", "i": i}), 20)
		if run.credits < cost:
			buy.disabled = true
			buy.tooltip_text = "Not enough Credits."
		elif run.consumables.size() >= BMRunConfig.CONSUMABLE_SLOTS:
			buy.disabled = true
			buy.tooltip_text = "Item slots are full. Use an item first."
		_items_row.add_child(BMUI.item_card(id, buy, 300))

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
