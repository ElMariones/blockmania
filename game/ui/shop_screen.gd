class_name BMShopScreen
extends Control
## "The Toybox" shop between rounds: a striped awning with credits and reroll, two shelves of
## offer cards (Jokers + items, Workshop + pieces), your Joker rack and items on the right, the
## next boss ticker and the Next Round button. Workshop cards open a bag picker; nothing is
## charged until the choice is confirmed.

const STAGE := Vector2(1920, 1080)

var main: Node
var run: BMRun
var stage: Control

var _credits: BMHud.Counter
var _reroll_button: Button
var _jokers_row: HBoxContainer
var _items_row: HBoxContainer
var _tools_row: HBoxContainer
var _pieces_row: HBoxContainer
var _owned_header: Label
var _owned_box: VBoxContainer
var _owned_items: HBoxContainer
var _bag_button: Button
var _next_label: Label
var _boss_label: Label
var _boss_name: Label
var _target_label: Label
var _ticker: PanelContainer
var _boss_pill: Control
var _message: Label
var _overlay: Control
var _awning: Control
var _crate_button: Button
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage = Control.new()
	stage.size = STAGE
	add_child(stage)
	resized.connect(_center_stage)
	_center_stage()

	# Awning with sign.
	_awning = Control.new()
	_awning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_awning.draw.connect(_draw_awning)
	_put(_awning, Vector2(28, 8), Vector2(1412, 104))
	var sign := BMStyle.label("THE TOYBOX", 60, BMStyle.SUN, true, 14)
	sign.add_theme_color_override("font_shadow_color", Color(BMStyle.PINK, 0.8))
	sign.add_theme_constant_override("shadow_offset_y", 6)
	sign.add_theme_constant_override("shadow_offset_x", 0)
	_put(sign, Vector2(60, 18), Vector2(600, 70))
	var cred := BMStyle.panel("panel_inset", Vector4(10, 0, 12, 0))
	var ch := BMStyle.hbox(8)
	cred.add_child(ch)
	ch.add_child(BMStyle.icon_rect("icon_coin", 1.0))
	_credits = BMHud.Counter.new()
	_credits.add_theme_font_override("font", BMStyle.font_bold)
	_credits.add_theme_font_size_override("font_size", 40)
	_credits.add_theme_color_override("font_color", BMStyle.SUN)
	_credits.add_theme_color_override("font_outline_color", BMStyle.INK)
	_credits.add_theme_constant_override("outline_size", 10)
	_credits.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ch.add_child(_credits)
	_put(cred, Vector2(820, 22), Vector2(250, 68))
	_reroll_button = BMStyle.button("REROLL", func() -> void: _act({"a": "reroll"}), "sky", 30)
	_reroll_button.icon = BMStyle.tex("icon_refresh")
	_reroll_button.tooltip_text = "Replace every offer in the shop. The price rises by 1 each reroll."
	_put(_reroll_button, Vector2(1090, 20), Vector2(330, 72))

	# Shelves.
	# Shelf labels sit above each row with a clear gap (cards grow on hover).
	var card_h := BMCard.OFFER_SIZE.y
	_put(BMStyle.pill("JOKERS", "sun", 20), Vector2(40, 118), Vector2(0, 0))
	_jokers_row = BMStyle.hbox(16)
	_put(_jokers_row, Vector2(40, 166), Vector2(812, card_h))
	_put(BMStyle.pill("ITEMS", "pink", 20), Vector2(892, 118), Vector2(0, 0))
	_items_row = BMStyle.hbox(16)
	_put(_items_row, Vector2(892, 166), Vector2(536, card_h))
	_put(BMStyle.pill("WORKSHOP  -  edit your bag", "mint", 20), Vector2(40, 578), Vector2(0, 0))
	_tools_row = BMStyle.hbox(16)
	_put(_tools_row, Vector2(40, 626), Vector2(536, card_h))
	_put(BMStyle.pill("PIECES FOR YOUR BAG", "sky", 20), Vector2(600, 578), Vector2(0, 0))
	_pieces_row = BMStyle.hbox(16)
	_put(_pieces_row, Vector2(600, 626), Vector2(536, card_h))

	# Next-round ticker, message line, and the Next Round button.
	var ticker := BMStyle.panel("panel_boss", Vector4(-8, -10, -8, -14))
	var tv := BMStyle.vbox(4)
	ticker.add_child(tv)
	var nrow := BMStyle.hbox(8)
	tv.add_child(nrow)
	_next_label = BMStyle.label("", 30, BMStyle.SUN, true, 8)
	_next_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nrow.add_child(_next_label)
	_boss_pill = BMStyle.pill("BOSS", "pink", 20)
	nrow.add_child(_boss_pill)
	var trow := BMStyle.hbox(6)
	trow.add_child(BMStyle.icon_rect("icon_target", 0.75))
	_target_label = BMStyle.label("", 30, BMStyle.CREAM, true, 8)
	trow.add_child(_target_label)
	tv.add_child(trow)
	var brow := BMStyle.hbox(6)
	brow.add_child(BMStyle.icon_rect("icon_skull", 0.75))
	_boss_name = BMStyle.label("", 20, BMStyle.PINK_L, true, 6)
	_boss_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boss_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(_boss_name)
	tv.add_child(brow)
	_boss_label = BMStyle.label("", 20, BMStyle.CREAM)
	_boss_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boss_label.max_lines_visible = 5
	_boss_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(_boss_label)
	_ticker = ticker
	_put(ticker, Vector2(1156, 578), Vector2(284, 292))
	_message = BMStyle.label("", 20, BMStyle.PINK_L, true, 6)
	_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_put(_message, Vector2(40, 1030), Vector2(1096, 36))
	var leave := BMStyle.button("NEXT ROUND  >", func() -> void: _act({"a": "leave_shop"}), "sun", 40)
	leave.name = "LeaveButton"
	_put(leave, Vector2(1156, 882), Vector2(284, 170))
	_crate_button = BMStyle.button("BOSS CRATE", func() -> void: _show_crate(), "mint", 30)
	_crate_button.icon = BMStyle.tex("icon_crate")
	_crate_button.tooltip_text = "Your free Boss Crate is still closed. Open it before you leave."
	_crate_button.visible = false
	_put(_crate_button, Vector2(1156, 770), Vector2(284, 100))
	leave.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Right column: your build.
	_owned_header = BMStyle.header("YOUR JOKERS", 30)
	_put(_owned_header, Vector2(1464, 16), Vector2(420, 40))
	_owned_box = BMStyle.vbox(8)
	_put(_owned_box, Vector2(1464, 64), Vector2(420, 652))
	_put(BMStyle.header("YOUR ITEMS", 30), Vector2(1464, 728), Vector2(420, 40))
	_owned_items = BMStyle.hbox(12)
	_put(_owned_items, Vector2(1464, 772), Vector2(420, 160))
	_bag_button = BMStyle.button("VIEW BAG", _show_bag, "sky", 30)
	_bag_button.icon = BMStyle.tex("icon_bag")
	_bag_button.tooltip_text = "Every piece in your bag (B)"
	_put(_bag_button, Vector2(1464, 966), Vector2(420, 80))

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


## Fixed 1920x1080 stage, centered for any aspect ratio (the canvas expands, it never stretches).
func _center_stage() -> void:
	stage.position = ((size - STAGE) / 2.0).round()


func _put(c: Control, pos: Vector2, sz: Vector2) -> void:
	c.position = pos
	if sz != Vector2.ZERO:
		c.size = sz
	stage.add_child(c)


func _process(delta: float) -> void:
	_t += delta
	_awning.queue_redraw()


func _draw_awning() -> void:
	var w := _awning.size.x
	var stripe := 44.0
	var n := int(ceil(w / stripe))
	var sway := 0.0 if (main and main.settings.reduced_motion) else sin(_t * 1.4) * 2.0
	_awning.draw_rect(Rect2(0, 0, w, 76), BMStyle.INK)
	for i in n:
		var c := BMStyle.PINK if i % 2 == 0 else BMStyle.CREAM
		var x := i * stripe
		var sw := minf(stripe, w - x)
		_awning.draw_rect(Rect2(x + 2, 2, sw - 2, 72), c)
		_awning.draw_rect(Rect2(x + 2, 2, sw - 2, 8), c.lightened(0.25))
		# Scalloped hem.
		var cx := x + sw / 2.0
		for k in 5:
			var hw := (sw / 2.0) * (1.0 - k * 0.18)
			_awning.draw_rect(Rect2(cx - hw, 74 + k * 4 + sway, hw * 2.0, 4), BMStyle.INK if k == 4 else c.darkened(0.12 * k))
	_awning.draw_rect(Rect2(0, 72, w, 4), Color(BMStyle.INK, 0.5))


## Boss Crate: a wooden crate rattles on screen; opening it bursts it apart and fans out three
## free offers. The rules only see which offer was taken.
func _show_crate() -> void:
	BMUI.clear_children(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(BMStyle.INK, 0.8)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center := size / 2.0
	var title := BMStyle.label("BOSS CRATE!", 80, BMStyle.SUN, true, 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(size.x, 110)
	title.position = Vector2(0, center.y - 400)
	dim.add_child(title)
	var sub := BMStyle.label("You beat the boss. Open it and take one thing for free.", 30, BMStyle.CREAM, true, 8)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(size.x, 44)
	sub.position = Vector2(0, center.y - 290)
	dim.add_child(sub)
	var crate := TextureButton.new()
	crate.texture_normal = BMStyle.tex("icon_crate")
	crate.ignore_texture_size = true
	crate.stretch_mode = TextureButton.STRETCH_SCALE
	crate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crate.size = Vector2(264, 264)
	crate.pivot_offset = crate.size / 2.0
	crate.position = center - crate.size / 2.0 + Vector2(0, 40)
	crate.tooltip_text = "Open the crate"
	crate.focus_mode = Control.FOCUS_ALL
	dim.add_child(crate)
	var hint := BMStyle.label("CLICK TO OPEN", 30, BMStyle.SUN_L, true, 8)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(size.x, 44)
	hint.position = Vector2(0, center.y + 210)
	dim.add_child(hint)
	if not main.settings.reduced_motion:
		var tw := crate.create_tween().set_loops()
		tw.tween_property(crate, "rotation", 0.08, 0.08)
		tw.tween_property(crate, "rotation", -0.08, 0.08)
		tw.tween_property(crate, "rotation", 0.0, 0.08)
		tw.tween_interval(0.5)
	crate.pressed.connect(func() -> void:
		BMAudio.sfx("crate_open")
		if BMFx.instance:
			var at := crate.get_global_rect().get_center()
			BMFx.instance.chips(at, [BMStyle.SUN, BMStyle.SUN_D, Color("#9e6016")], 24)
			BMFx.instance.confetti(Rect2(Vector2(0, 0), size), 120)
			BMFx.instance.shake(10.0)
			BMFx.instance.ring(at, BMStyle.SUN_L, 260.0)
		crate.queue_free()
		hint.queue_free()
		_crate_offers(dim))
	BMStyle.focus_later(crate)


func _crate_offers(dim: Control) -> void:
	var row := BMStyle.hbox(30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	dim.add_child(row)
	var cards: Array = []
	for i in run.shop.crate.size():
		var o: Dictionary = run.shop.crate[i]
		var take := BMStyle.button("TAKE IT", func() -> void:
			var r := _act({"a": "crate", "i": i})
			if r.ok:
				BMUI.clear_children(_overlay)
				BMAudio.sfx("buy")
				_message.add_theme_color_override("font_color", BMStyle.MINT_L)
				_message.text = "From the crate: %s." % _crate_name(o), "mint", 30)
		var card: BMCard
		match String(o.kind):
			"joker":
				card = BMCard.offer(run, "joker", String(o.id), take)
			"item":
				card = BMCard.offer(run, "item", String(o.id), take)
			_:
				card = BMCard.offer(run, "item", "cash_out", take)
				_retitle_credits(card, int(o.value))
		row.add_child(card)
		cards.append(card)
	row.reset_size()
	row.position = (size - row.size) / 2.0 + Vector2(0, 60)
	if not main.settings.reduced_motion:
		for i in cards.size():
			var c: Control = cards[i]
			c.modulate.a = 0.0
			var tw := c.create_tween()
			tw.tween_interval(0.08 * i)
			tw.tween_property(c, "modulate:a", 1.0, 0.18)
	var skip := BMStyle.button("LATER", func() -> void: BMUI.clear_children(_overlay), "plum", 20)
	skip.tooltip_text = "Close the crate for now: the BOSS CRATE button reopens it until you leave the shop."
	skip.size = Vector2(200, 56)
	skip.position = Vector2((size.x - 200) / 2.0, row.position.y + row.size.y + 24)
	dim.add_child(skip)
	if not cards.is_empty():
		BMStyle.focus_later(cards[0])


func _crate_name(o: Dictionary) -> String:
	match String(o.kind):
		"joker":
			return BMJokers.get_def(o.id).name
		"item":
			return BMConsumables.get_def(o.id).name
	return "%d Credits" % int(o.value)


## The Credits offer reuses an item card; its words and emblem are replaced.
func _retitle_credits(card: BMCard, value: int) -> void:
	card.tooltip_body = "%d Credits, straight into your wallet." % value
	for l in card.find_children("*", "Label", true, false):
		var lab := l as Label
		if lab.text == BMConsumables.get_def("cash_out").name:
			lab.text = "%d CREDITS" % value
		elif lab.text == BMConsumables.get_def("cash_out").text:
			lab.text = "Straight into your wallet."
		elif lab.text == "ITEM":
			lab.text = "CREDITS"


func bind(new_run: BMRun) -> void:
	run = new_run
	_center_stage()
	_message.text = ""
	BMUI.clear_children(_overlay)
	_credits.set_target(run.credits, true)
	refresh_all()
	var leave := find_child("LeaveButton", true, false) as Button
	if leave:
		BMStyle.focus_later(leave)
	if run.has_crate():
		_show_crate()


func _act(a: Dictionary) -> Dictionary:
	var before := run.credits
	var r: Dictionary = main.act(a)
	_play_result_sound(a, r)
	if r.ok and a.a in ["buy_tool", "buy_piece", "buy_joker", "buy_consumable"]:
		_message.add_theme_color_override("font_color", BMStyle.MINT_L)
		_message.text = _purchase_text(r)
		if BMFx.instance:
			BMFx.instance.stars(_credits.get_global_rect().get_center(), 6, 60)
			BMFx.instance.pop_text(_credits.get_global_rect().get_center() + Vector2(0, 50), "-%d" % (before - run.credits), BMStyle.PINK_L, 30)
	elif r.ok and a.a == "sell":
		_message.add_theme_color_override("font_color", BMStyle.SUN)
		_message.text = "Sold for %d Credits." % r.value
		if BMFx.instance:
			BMFx.instance.pop_text(_credits.get_global_rect().get_center() + Vector2(0, 50), "+%d" % r.value, BMStyle.SUN, 30)
	elif not r.ok:
		_message.add_theme_color_override("font_color", BMStyle.PINK_L)
		_message.text = r.error
	else:
		_message.text = ""
	if run.phase == BMRun.Phase.SHOP:
		refresh_all()
	return r


func _play_result_sound(a: Dictionary, r: Dictionary) -> void:
	if not r.ok:
		BMAudio.sfx("deny")
		return
	match String(a.a):
		"buy_tool":
			BMAudio.sfx("workshop")
		"buy_joker", "buy_consumable", "buy_piece":
			BMAudio.sfx("buy")
			if r.get("item", "") == "loan_shark":
				BMAudio.sfx_later("loan_cash", 0.15)
				if BMFx.instance:
					BMFx.instance.coins(get_global_rect().get_center(), Vector2(160, 60), 10)
		"sell":
			BMAudio.sfx("sell")
		"reroll":
			BMAudio.sfx("reroll")
		"move":
			BMAudio.sfx("tick")


func _purchase_text(r: Dictionary) -> String:
	match r.type:
		"buy_piece":
			return "Added %s to your bag (%d pieces)." % [BMPieces.describe(r.piece).get_slice("\n", 0), run.bag.size()]
		"buy_tool":
			return "Used %s." % BMTools.get_def(r.item).name
		"buy_joker":
			if r.item == "loan_shark":
				return "Loan Shark lent you %d Credits. It takes %d back after each won round." % [BMJokers.LOAN_CREDITS, BMJokers.LOAN_INSTALLMENT]
			return "%s joined your rack!" % BMJokers.get_def(r.item).name
		"buy_consumable":
			return "Bought %s." % BMConsumables.get_def(r.item).name
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if _overlay.get_child_count() > 0 and event.is_action_pressed("bm_cancel"):
		BMUI.clear_children(_overlay)
		get_viewport().set_input_as_handled()
	elif _overlay.get_child_count() == 0 and event.is_action_pressed("bm_bag"):
		_show_bag()
		get_viewport().set_input_as_handled()


func refresh_all() -> void:
	if _crate_button:
		_crate_button.visible = run != null and run.has_crate()
	if run == null or run.phase != BMRun.Phase.SHOP:
		return
	_credits.set_target(run.credits)
	_reroll_button.text = "REROLL  %d" % int(run.shop.reroll_cost)
	_reroll_button.disabled = run.credits < int(run.shop.reroll_cost)
	_bag_button.text = "VIEW BAG  (%d)" % run.bag.size()
	var next := run.round_number + 1
	var boss_next := BMRunConfig.is_boss_round(next)
	_next_label.text = "ROUND %d" % next
	_boss_pill.visible = boss_next
	_target_label.text = BMUI.fmt_int(BMRunConfig.target(next))
	_target_label.tooltip_text = "Score target for round %d" % next
	var boss_id: String = run.bosses[BMRunConfig.act_of(next) - 1]
	var bd := BMBosses.get_def(boss_id)
	var boss_round := BMRunConfig.act_of(next) * 4
	_boss_name.text = String(bd.name).to_upper() if boss_next else "%s  (ROUND %d)" % [String(bd.name).to_upper(), boss_round]
	_boss_label.text = bd.rule
	_ticker.tooltip_text = "Round %d boss: %s\n%s" % [boss_round, bd.name, bd.rule]

	BMUI.clear_children(_jokers_row)
	for i in run.shop.jokers.size():
		var id: String = run.shop.jokers[i]
		if id == "":
			_jokers_row.add_child(_sold_out())
			continue
		var buy := _price_button(BMJokers.cost(id), func() -> void: _act({"a": "buy_joker", "i": i}))
		if run.jokers.size() >= run.joker_slots():
			buy.disabled = true
			buy.tooltip_text = "Joker slots are full. Sell one first."
		_jokers_row.add_child(_card(BMCard.offer(run, "joker", id, buy)))

	BMUI.clear_children(_items_row)
	for i in run.shop.consumables.size():
		var id: String = run.shop.consumables[i]
		if id == "":
			_items_row.add_child(_sold_out())
			continue
		var buy := _price_button(BMConsumables.cost(id), func() -> void: _act({"a": "buy_consumable", "i": i}))
		if run.consumables.size() >= BMRunConfig.CONSUMABLE_SLOTS:
			buy.disabled = true
			buy.tooltip_text = "Item slots are full. Use an item first."
		_items_row.add_child(_card(BMCard.offer(run, "item", id, buy)))

	BMUI.clear_children(_tools_row)
	for i in run.shop.tools.size():
		var o: Dictionary = run.shop.tools[i]
		if o.is_empty():
			_tools_row.add_child(_sold_out())
			continue
		var def := BMTools.get_def(o.id)
		var buy := _price_button(int(def.cost), func() -> void: _begin_tool(i))
		if int(def.max_targets) > 0:
			buy.text = "PICK %d" % int(def.cost)
		_tools_row.add_child(_card(BMCard.offer(run, "tool", o, buy)))

	BMUI.clear_children(_pieces_row)
	for i in run.shop.pieces.size():
		var d: Dictionary = run.shop.pieces[i]
		if d.is_empty():
			_pieces_row.add_child(_sold_out())
			continue
		var buy := _price_button(int(d.cost), func() -> void: _act({"a": "buy_piece", "i": i}))
		if run.bag.size() >= BMPieces.MAX_BAG:
			buy.disabled = true
			buy.tooltip_text = "Your bag is full."
		_pieces_row.add_child(_card(BMCard.offer(run, "piece", BMPieces.from_dict(d), buy)))

	BMUI.clear_children(_owned_box)
	_owned_header.text = "YOUR JOKERS %d/%d" % [run.jokers.size(), run.joker_slots()]
	for i in run.jokers.size():
		var id := run.jokers[i]
		var card := BMCard.joker_rack(run, id)
		card.reduced_motion = main.settings.reduced_motion
		card.drag_index = i
		card.drag_enabled = true
		card.drag_receiver = func(from: int, to: int) -> void:
			if to >= 0 and to < run.jokers.size():
				_act({"a": "move", "from": from, "to": to})
				if to < _owned_box.get_child_count():
					BMStyle.focus_later(_owned_box.get_child(to) as Control)
		card.tooltip_body += "\nDrag onto another Joker to reorder. Alt+Up/Down while focused also moves it."
		var wrap := Control.new()
		wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bar := BMStyle.hbox(4)
		wrap.add_child(bar)
		var sell := BMStyle.button("SELL +%d" % BMJokers.sell_value(id), func() -> void: _act({"a": "sell", "i": i}), "pink", 20)
		bar.add_child(sell)
		wrap.resized.connect(func() -> void:
			bar.reset_size()
			bar.position = Vector2(wrap.size.x - bar.size.x - 10, wrap.size.y - bar.size.y - 8))
		wrap.visible = false
		card.hover_controls = wrap
		card.add_child(wrap)
		_owned_box.add_child(card)
	for i in range(run.jokers.size(), run.joker_slots()):
		var empty := BMStyle.panel("panel_inset", Vector4.ZERO)
		empty.custom_minimum_size = Vector2(0, 124)
		var l := BMStyle.label("empty slot", 20, Color(BMStyle.TEXT_DIM, 0.5))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_child(l)
		_owned_box.add_child(empty)
	BMUI.clear_children(_owned_items)
	for id in run.consumables:
		var c := BMCard.item_rack(id)
		c.custom_minimum_size = Vector2(204, 132)
		var body := BMStyle.label(BMConsumables.get_def(id).text, 20, Color(BMStyle.INK, 0.75))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.max_lines_visible = 2
		body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		(c.get_child(0) as VBoxContainer).add_child(body)
		_owned_items.add_child(c)
	for i in range(run.consumables.size(), BMRunConfig.CONSUMABLE_SLOTS):
		var empty := BMStyle.panel("panel_inset", Vector4.ZERO)
		empty.custom_minimum_size = Vector2(204, 132)
		var el := BMStyle.label("empty", 20, Color(BMStyle.TEXT_DIM, 0.5))
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		el.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_child(el)
		_owned_items.add_child(empty)


func _card(c: BMCard) -> BMCard:
	c.reduced_motion = main.settings.reduced_motion
	return c


func _price_button(cost: int, cb: Callable) -> Button:
	var b := BMStyle.button("BUY %d" % cost, cb, "sun", 30)
	b.icon = BMStyle.tex("icon_coin")
	b.add_theme_constant_override("icon_max_width", 32)
	b.custom_minimum_size.y = 64
	if run.credits < cost:
		b.disabled = true
		b.tooltip_text = "Not enough Credits."
	return b


func _sold_out() -> Control:
	var p := BMStyle.panel("panel_inset", Vector4.ZERO)
	p.custom_minimum_size = BMCard.OFFER_SIZE
	var l := BMStyle.label("SOLD OUT", 30, Color(BMStyle.TEXT_DIM, 0.6), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


# --- Bag viewer and Workshop picker ------------------------------------------------------------

func _overlay_panel(min_width: float, frame: String = "panel_plate") -> VBoxContainer:
	BMUI.clear_children(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(BMStyle.INK, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var p := BMStyle.panel(frame, Vector4(24, 14, 24, 18))
	p.custom_minimum_size.x = min_width
	center.add_child(p)
	var v := BMStyle.vbox(12)
	p.add_child(v)
	if not main.settings.reduced_motion:
		p.scale = Vector2(0.9, 0.9)
		p.resized.connect(func() -> void: p.pivot_offset = p.size / 2.0)
		p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return v


func _show_bag() -> void:
	var v := _overlay_panel(1240)
	BMAudio.sfx("bag_open")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(BMBagView.WIDTH + 24, 720)
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var bv := BMBagView.new()
	scroll.add_child(bv)
	bv.setup(run)
	var close := BMStyle.button("CLOSE  (ESC)", func() -> void: BMUI.clear_children(_overlay), "sun", 30)
	close.custom_minimum_size.y = 72
	v.add_child(close)
	BMStyle.focus_later(close)


func _begin_tool(index: int) -> void:
	var o: Dictionary = run.shop.tools[index]
	var def := BMTools.get_def(o.id)
	var max_t := int(def.max_targets)
	if max_t == 0:
		_act({"a": "buy_tool", "i": index, "targets": [], "color": -1})
		return
	var v := _overlay_panel(1240)
	BMAudio.sfx("modal")
	var head := BMStyle.hbox(16)
	v.add_child(head)
	head.add_child(BMCard.Emblem.for_tool(o, Vector2(88, 88)))
	var hv := BMStyle.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	hv.add_child(BMStyle.label("%s  -  %d CREDITS" % [BMTools.offer_name(o).to_upper(), int(def.cost)], 40, BMStyle.SUN, true, 10))
	var t := BMStyle.label(BMTools.offer_text(o, run), 20, BMStyle.CREAM)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(t)
	var status := BMStyle.label("Choose up to %d piece%s." % [max_t, "s" if max_t > 1 else ""], 30, BMStyle.MINT_L, true, 8)
	v.add_child(status)
	var state := {"targets": [], "color": -1}
	var confirm := BMStyle.button("CONFIRM PURCHASE", func() -> void: pass, "sun", 30)
	confirm.custom_minimum_size = Vector2(420, 72)
	var color_buttons: Array = []
	var update := func() -> void:
		var ok: bool = not state.targets.is_empty() and (def.kind != "repaint" or state.color >= 0)
		confirm.disabled = not ok
		var picked := "%d of %d chosen" % [state.targets.size(), max_t]
		if def.kind == "repaint":
			picked += "   -   color: %s" % (BMShapes.COLOR_NAMES[state.color].to_upper() if state.color >= 0 else "pick one")
		status.text = picked
		for i in color_buttons.size():
			var cb: Button = color_buttons[i]
			cb.text = ("> %s <" if i == state.color else "%s") % BMShapes.COLOR_NAMES[i].to_upper()
	if def.kind == "repaint":
		var colors := BMStyle.hbox(8)
		v.add_child(colors)
		for c in BMShapes.OFFER_COLOR_COUNT:
			var cb := BMStyle.button(BMShapes.COLOR_NAMES[c].to_upper(), func() -> void:
				state.color = c
				update.call(), "plum", 20)
			cb.icon = BMStyle.block_tex(c)
			cb.expand_icon = false
			cb.add_theme_constant_override("icon_max_width", 28)
			colors.add_child(cb)
			color_buttons.append(cb)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(BMBagView.WIDTH + 24, 520)
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var bv := BMBagView.new()
	scroll.add_child(bv)
	bv.setup(run, max_t)
	bv.selection_changed.connect(func(uids: Array) -> void:
		state.targets = uids
		update.call())
	var row := BMStyle.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	confirm.pressed.connect(func() -> void:
		var r := _act({"a": "buy_tool", "i": index, "targets": state.targets, "color": state.color})
		if r.ok:
			BMUI.clear_children(_overlay)
			if BMFx.instance:
				BMFx.instance.confetti(Rect2(Vector2(size.x * 0.3, 0), Vector2(size.x * 0.4, 10)), 40)
		else:
			status.text = r.error
			status.add_theme_color_override("font_color", BMStyle.PINK_L))
	row.add_child(confirm)
	var cancel := BMStyle.button("CANCEL  (ESC)", func() -> void: BMUI.clear_children(_overlay), "plum", 30)
	cancel.custom_minimum_size = Vector2(300, 72)
	row.add_child(cancel)
	update.call()
