class_name BMShopScreen
extends Control
## "The Toybox" shop between rounds: a striped awning with credits and reroll, two shelves of
## offer cards (Jokers + items, Workshop + pieces), your Joker rack and items on the right, the
## next boss ticker and the Next Round button. Workshop cards open a bag picker; nothing is
## charged until the choice is confirmed.

const STAGE := Vector2(1920, 1080)
const TICKER_BOTTOM := 870.0 ## the round ticker spans 578..870 on the stage
const CRATE_BUTTON_Y := 766.0 ## while the BOSS CRATE button shows, it takes the ticker's bottom
const TICKER_RULE_LINES := 5

## Shop visit and id of the last Legendary offer announced (its reveal sting plays once).
var _legend_seen := ""
var main: Node
var run: BMRun
var stage: Control

var _wallet: BMWallet
var _reroll_button: Button
var _jokers_row: HBoxContainer
var _items_row: HBoxContainer
var _tools_row: HBoxContainer
var _pieces_row: HBoxContainer
var _pieces_pill: Control
var _holo_pill: Control
var _owned_header: Label
var _owned_box: VBoxContainer
var _owned_items: HBoxContainer
var _owned_grid: GridContainer
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
var _overtime_pill: Control
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
	# A longer name steps down to 40, still clear of the Overtime pill and the credits.
	var sign_size := BMUI.fit_size(BMLoc.t("THE TOYBOX"), BMStyle.font_bold, 60, 572)
	var sign := BMStyle.label(BMLoc.t("THE TOYBOX"), sign_size, BMStyle.SUN, true, 14)
	sign.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if sign_size < 60 else VERTICAL_ALIGNMENT_TOP
	sign.add_theme_color_override("font_shadow_color", Color(BMStyle.PINK, 0.8))
	sign.add_theme_constant_override("shadow_offset_y", 6)
	sign.add_theme_constant_override("shadow_offset_x", 0)
	_put(sign, Vector2(60, 18), Vector2(600, 70))
	_overtime_pill = BMStyle.pill(BMLoc.t("OVERTIME"), "pink", 20)
	_overtime_pill.tooltip_text = BMLoc.t("You beat the game and kept playing. Targets climb faster every round.")
	_put(_overtime_pill, Vector2(652, 34), Vector2(0, 0))
	var cred := BMStyle.panel("panel_inset", Vector4(10, 0, 12, 0))
	_wallet = BMWallet.new()
	_wallet.font_size = 40
	_wallet.icon_scale = 1.0
	_wallet.outline = 10
	cred.add_child(_wallet)
	_put(cred, Vector2(820, 22), Vector2(250, 68))
	_reroll_button = BMStyle.button("REROLL", func() -> void: _act({"a": "reroll"}), "sky", 30)
	_reroll_button.icon = BMStyle.tex("icon_refresh")
	_reroll_button.tooltip_text = BMLoc.t("Replace every offer in the shop. The price rises by 1 each reroll.")
	_put(_reroll_button, Vector2(1090, 20), Vector2(330, 72))

	# Shelves.
	# Shelf labels sit above each row with a clear gap (cards grow on hover).
	var card_h := BMCard.OFFER_SIZE.y
	_put(BMStyle.pill(BMLoc.t("JOKERS"), "sun", 20), Vector2(40, 118), Vector2(0, 0))
	_jokers_row = BMStyle.hbox(16)
	_put(_jokers_row, Vector2(40, 166), Vector2(812, card_h))
	_put(BMStyle.pill(BMLoc.t("ITEMS"), "pink", 20), Vector2(892, 118), Vector2(0, 0))
	_items_row = BMStyle.hbox(16)
	_put(_items_row, Vector2(892, 166), Vector2(536, card_h))
	_put(BMStyle.pill(BMLoc.t("WORKSHOP  -  edit your bag"), "mint", 20), Vector2(40, 578), Vector2(0, 0))
	_tools_row = BMStyle.hbox(16)
	_put(_tools_row, Vector2(40, 626), Vector2(536, card_h))
	_pieces_pill = BMStyle.pill(BMLoc.t("PIECES FOR YOUR BAG"), "sky", 20)
	_put(_pieces_pill, Vector2(600, 578), Vector2(0, 0))
	# From the shop after round 8 this shelf holds the Holo cards instead of pieces.
	_holo_pill = BMStyle.pill(BMLoc.t("HOLO SHELF"), "holo", 20)
	_holo_pill.visible = false
	_put(_holo_pill, Vector2(600, 578), Vector2(0, 0))
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
	_boss_pill = BMStyle.pill(BMLoc.t("BOSS"), "pink", 20)
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
	_boss_label.max_lines_visible = TICKER_RULE_LINES
	_boss_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(_boss_label)
	_ticker = ticker
	_put(ticker, Vector2(1156, 578), Vector2(284, TICKER_BOTTOM - 578))
	_message = BMStyle.label("", 20, BMStyle.PINK_L, true, 6)
	_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_put(_message, Vector2(40, 1030), Vector2(1096, 36))
	var leave := BMStyle.button(BMLoc.t("NEXT ROUND  >"), _on_leave, "sun", 40)
	leave.name = "LeaveButton"
	_put(leave, Vector2(1156, 882), Vector2(284, 170))
	# Two lines of text beside the full-size icon keep the button inside the ticker's width.
	_crate_button = BMStyle.button(BMLoc.t("BOSS\nCRATE"), func() -> void: _show_crate(), "mint", 30)
	_crate_button.icon = BMStyle.tex("icon_crate")
	_crate_button.tooltip_text = BMLoc.t("Your free Boss Crate is still closed. Open it before you leave.")
	_crate_button.visible = false
	_put(_crate_button, Vector2(1156, CRATE_BUTTON_Y), Vector2(284, TICKER_BOTTOM - CRATE_BUTTON_Y))
	leave.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Right column: your build.
	_owned_header = BMStyle.header(BMLoc.t("YOUR JOKERS"), 30)
	_put(_owned_header, Vector2(1464, 16), Vector2(420, 40))
	_owned_box = BMStyle.vbox(8)
	_put(_owned_box, Vector2(1464, 64), Vector2(420, 652))
	_put(BMStyle.header(BMLoc.t("YOUR ITEMS"), 30), Vector2(1464, 728), Vector2(420, 40))
	_owned_items = BMStyle.hbox(12)
	_put(_owned_items, Vector2(1464, 772), Vector2(420, 160))
	_owned_grid = GridContainer.new()
	_owned_grid.columns = 2
	_owned_grid.add_theme_constant_override("h_separation", 12)
	_owned_grid.add_theme_constant_override("v_separation", 8)
	_put(_owned_grid, Vector2(1464, 772), Vector2(420, 160))
	_bag_button = BMStyle.button(BMLoc.t("BAG"), _show_bag, "sky", 30)
	_bag_button.icon = BMStyle.tex("icon_bag")
	_bag_button.tooltip_text = BMLoc.t("Every piece in your bag (B)")
	_put(_bag_button, Vector2(1464, 966), Vector2(236, 80))
	# Pause menu from the shop (Esc): settings, Save & Quit to the title, or abandon the run.
	var menu := BMStyle.button(BMLoc.t("MENU"), func() -> void: main.show_pause(), "plum", 20)
	menu.name = "MenuButton"
	menu.icon = BMStyle.tex("icon_gear")
	menu.tooltip_text = BMLoc.t("Pause, settings, Save & Quit to the main menu (Esc)")
	_put(menu, Vector2(1712, 966), Vector2(172, 80))

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
	var title := BMStyle.label(BMLoc.t("BOSS CRATE!"), 80, BMStyle.SUN, true, 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(size.x, 110)
	title.position = Vector2(0, center.y - 400)
	dim.add_child(title)
	var sub := BMStyle.label(BMLoc.t("You beat the boss. Open it and take one thing for free."), 30, BMStyle.CREAM, true, 8)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(size.x, 44)
	sub.position = Vector2(0, center.y - 290)
	dim.add_child(sub)
	var crate := TextureButton.new()
	# Hover lifts the lid a crack, with light spilling out. Not on focus: the crate is focused
	# as soon as it appears, which would spoil the reveal.
	crate.texture_normal = BMStyle.tex("crate_big")
	crate.texture_hover = BMStyle.tex("crate_big_open")
	crate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crate.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	crate.size = crate.texture_normal.get_size()
	crate.pivot_offset = crate.size / 2.0
	crate.position = center - crate.size / 2.0 + Vector2(0, 40)
	crate.tooltip_text = BMLoc.t("Open the crate")
	crate.focus_mode = Control.FOCUS_ALL
	dim.add_child(crate)
	var hint := BMStyle.label(BMLoc.t("CLICK TO OPEN"), 30, BMStyle.SUN_L, true, 8)
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
			BMFx.instance.chips(at, [Color("#eea65c"), Color("#ce7c40"), Color("#6c3428"), BMStyle.SUN], 28)
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
	var first_take: Button = null
	var locked: Array[String] = []
	for i in run.shop.crate.size():
		var o: Dictionary = run.shop.crate[i]
		var take := BMStyle.button(BMLoc.t("TAKE IT"), func() -> void:
			var r := _act({"a": "crate", "i": i})
			if r.ok:
				BMUI.clear_children(_overlay)
				BMAudio.sfx("buy")
				if String(o.kind) == "joker" and BMJokers.is_legendary(String(o.id)):
					_legendary_fanfare(String(o.id))
				_message.add_theme_color_override("font_color", BMStyle.MINT_L)
				_message.text = BMLoc.t("From the crate: %s.") % _crate_name(o), "mint",
			BMUI.fit_size(BMLoc.t("TAKE IT"), BMStyle.font_bold, 30, 190))
		var card: BMCard
		match String(o.kind):
			"joker":
				card = BMCard.offer(run, "joker", String(o.id), take)
			"item":
				card = BMCard.offer(run, "item", String(o.id), take)
			_:
				card = BMCard.offer(run, "item", "cash_out", take)
				_retitle_credits(card, int(o.value))
		var why := _crate_block_reason(o)
		if why != "":
			_lock_offer(card, take, why, String(o.kind) == "joker")
			locked.append(BMLoc.t("sell a Joker") if String(o.kind) == "joker" else BMLoc.t("use an item"))
		elif first_take == null:
			first_take = take
		card.set_meta("crate_index", i)
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
	var skip := BMStyle.button(BMLoc.t("LATER"), func() -> void: BMUI.clear_children(_overlay), "plum", 20)
	skip.tooltip_text = BMLoc.t("Close the crate for now: the BOSS CRATE button reopens it until you leave the shop.")
	skip.size = Vector2(200, 56)
	var below := row.position.y + row.size.y + 24
	if not locked.is_empty():
		var note := BMStyle.label(BMLoc.t("Slots full? Press LATER, %s, then reopen the crate.") % BMLoc.t(" or ").join(locked),
			20, BMStyle.PINK_L, true, 6)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.size = Vector2(size.x, 32)
		note.position = Vector2(0, below)
		dim.add_child(note)
		below += 44
	skip.position = Vector2((size.x - 200) / 2.0, below)
	dim.add_child(skip)
	BMStyle.focus_later(first_take if first_take != null else skip)


## Why a crate offer cannot be taken right now ("" when it can). Mirrors BMRun.open_crate.
func _crate_block_reason(o: Dictionary) -> String:
	match String(o.kind):
		"joker":
			if run.rack_full():
				return BMLoc.t("Joker slots are full")
		"item":
			if run.items_full():
				return BMLoc.t("Item slots are full")
	return ""


## Locked crate offer: the button is disabled and says LOCKED; a padlock and the reason sit over
## the dimmed card (text and icon, not color alone). The tooltip says how to unlock it.
func _lock_offer(card: BMCard, take: Button, why: String, joker: bool) -> void:
	var fix := BMLoc.t("sell a Joker") if joker else BMLoc.t("use an item")
	take.disabled = true
	take.text = BMLoc.t("LOCKED")
	take.icon = BMStyle.tex("icon_lock")
	# With the padlock beside it, a longer word steps down to 20 to stay inside the card.
	take.add_theme_font_size_override("font_size", BMUI.fit_size(take.text, BMStyle.font_bold, 30, 150))
	take.tooltip_text = BMLoc.t("%s. Press LATER, %s, then reopen the crate with the BOSS CRATE button.") % [why, fix]
	card.tooltip_body += "\n\n" + BMLoc.t("LOCKED: %s. Press LATER, %s, then reopen the crate.") % [why, fix]
	# A light veil keeps the card readable; the padlock covers the emblem and SLOTS FULL
	# covers the rarity tag (same vertical rhythm as BMCard.offer: 80-px emblem, 6-px gap).
	var veil := ColorRect.new()
	veil.color = Color(BMStyle.INK, 0.35)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(veil)
	var v := BMStyle.vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var lock_row := CenterContainer.new()
	lock_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_row.custom_minimum_size.y = 80
	lock_row.add_child(BMStyle.icon_rect("icon_lock", 1.5))
	v.add_child(lock_row)
	var pill_row := CenterContainer.new()
	pill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_row.add_child(BMStyle.pill(BMLoc.t("SLOTS FULL"), "pink", 20))
	v.add_child(pill_row)


func _crate_name(o: Dictionary) -> String:
	match String(o.kind):
		"joker":
			return BMJokers.display_name(o.id)
		"item":
			return BMConsumables.display_name(o.id)
	return BMLoc.tn("%d Credit", "%d Credits", int(o.value)) % int(o.value)


## The Credits offer reuses an item card; its words and emblem are replaced.
func _retitle_credits(card: BMCard, value: int) -> void:
	card.tooltip_body = BMLoc.tn("%d Credit, straight into your wallet.", "%d Credits, straight into your wallet.", value) % value
	for l in card.find_children("*", "Label", true, false):
		var lab := l as Label
		if lab.text == BMConsumables.display_name("cash_out"):
			lab.text = BMLoc.tn("%d CREDIT", "%d CREDITS", value) % value
		elif lab.text == BMConsumables.display_text("cash_out"):
			lab.text = BMLoc.t("Straight into your wallet.")
		elif lab.text == BMLoc.t("ITEM"):
			lab.text = BMLoc.t("CREDITS")


func bind(new_run: BMRun) -> void:
	run = new_run
	_center_stage()
	_message.text = ""
	BMUI.clear_children(_overlay)
	_wallet.reduced_motion = main.settings.reduced_motion
	_wallet.set_amount(run.credits)
	refresh_all()
	var leave := find_child("LeaveButton", true, false) as Button
	if leave:
		BMStyle.focus_later(leave)
	if run.has_crate():
		_show_crate()


func _act(a: Dictionary) -> Dictionary:
	var before := run.credits
	var src := _source_of(a)
	var r: Dictionary = main.act(a)
	_play_result_sound(a, r)
	var flying: Control = null
	if r.ok:
		flying = _animate_money(a, r, before, src)
	if r.ok and a.a in ["buy_tool", "buy_piece", "buy_joker", "buy_consumable", "buy_holo"]:
		_message.add_theme_color_override("font_color", BMStyle.MINT_L)
		_message.text = _purchase_text(r)
	elif r.ok and a.a in ["sell", "sell_item"]:
		_message.add_theme_color_override("font_color", BMStyle.SUN)
		_message.text = BMLoc.t("Sold for %d Credits.") % r.value
	elif not r.ok:
		_message.add_theme_color_override("font_color", BMStyle.PINK_L)
		_message.text = BMLoc.tf(r.error)
	else:
		_message.text = ""
	if run.phase == BMRun.Phase.SHOP:
		refresh_all()
		if r.ok and String(a.a) == "reroll":
			_deal_in([_jokers_row, _items_row, _tools_row, _pieces_row])
		if flying != null:
			var kind := String(a.a)
			if kind == "crate":
				kind = "crate_" + String(Dictionary(r.get("offer", {})).get("kind", ""))
			_land_bought(flying, kind)
	elif flying != null:
		flying.queue_free()
	return r


# --- Money and cards in motion (presentation only) ---------------------------------------------

## The card (or button) an action starts from, found before the action rebuilds the shelves.
func _source_of(a: Dictionary) -> Control:
	var i := int(a.get("i", -1))
	var row: Container = null
	match String(a.get("a", "")):
		"buy_joker":
			row = _jokers_row
		"buy_consumable":
			row = _items_row
		"buy_tool":
			row = _tools_row
		"buy_holo":
			row = _pieces_row
		"buy_piece":
			row = _pieces_row
			i += Array(run.shop.get("holo", [])).size()
		"sell":
			row = _owned_box
		"sell_item":
			row = _owned_grid if _owned_grid.visible else _owned_items
		"reroll":
			return _reroll_button
		"crate":
			for c in _overlay.find_children("*", "", true, false):
				if c is BMCard and int(c.get_meta("crate_index", -1)) == i:
					return c as Control
			return null
	if row == null or i < 0 or i >= row.get_child_count():
		return null
	return row.get_child(i) as Control


## Coins between the wallet and the card; a sold card spins away, a bought one is lifted off
## its shelf. Returns the bought card on its way to the rack (it lands after the rebuild).
func _animate_money(a: Dictionary, r: Dictionary, before: int, src: Control) -> Control:
	var at := src.get_global_rect().get_center() if src else get_global_rect().get_center()
	match String(a.a):
		"sell", "sell_item":
			var fly := BMFx.instance.fly_card(src, at, "sell") if BMFx.instance and src else 0.0
			if fly > 0.0:
				BMAudio.sfx_later("card_poof", 0.1)
				if BMFx.instance:
					BMFx.instance.burst(at, [BMStyle.SUN, BMStyle.SUN_L, BMStyle.CREAM], 14, 300.0, 8.0)
			else:
				BMAudio.sfx("sell")
			_wallet.gain(at, int(r.value))
		"reroll":
			_wallet.spend(at, before - run.credits)
		"crate":
			var o: Dictionary = r.get("offer", {})
			if run.credits > before:
				_wallet.gain(at, run.credits - before)
			elif src and String(o.get("kind", "")) in ["joker", "item"]:
				return _launch(src)
		"buy_joker", "buy_consumable", "buy_tool", "buy_piece", "buy_holo":
			var loan := String(r.get("item", "")) == "loan_shark"
			_wallet.spend(at, BMJokers.cost("loan_shark") if loan else before - run.credits)
			if loan:
				_wallet.gain(get_global_rect().get_center(), BMJokers.LOAN_CREDITS)
			if src is BMCard:
				return _launch(src)
	return null


## Lifts the bought card off its shelf onto the effects layer (same place on screen) before the
## shelves are rebuilt. Null with Reduced Motion (the rack just shows the new card).
func _launch(src: Control) -> Control:
	if BMFx.instance == null or main.settings.reduced_motion or not src.is_visible_in_tree():
		return null
	var at := src.global_position
	var sz := src.size
	src.set_meta("flying", true)
	if src is BMCard:
		(src as BMCard).reduced_motion = true
	BMFx._ignore_mouse(src)
	src.reparent(BMFx.instance, false)
	src.global_position = at
	src.size = sz
	return src


## Where a bought card goes: a Joker or item to its new place in your rack, a piece or Workshop
## card into the bag, a Holo card onto the whole rack. The new rack card shows as it lands.
func _land_bought(card: Control, kind: String) -> void:
	var target: Control = null
	var reveal: Control = null
	match kind:
		"buy_joker", "crate_joker":
			if run.jokers.size() - 1 < _owned_box.get_child_count():
				reveal = _owned_box.get_child(run.jokers.size() - 1) as Control
		"buy_consumable", "crate_item":
			var holder: Container = _owned_grid if _owned_grid.visible else _owned_items
			if run.consumables.size() - 1 < holder.get_child_count():
				reveal = holder.get_child(run.consumables.size() - 1) as Control
		"buy_tool", "buy_piece":
			target = _bag_button
		_:
			target = _owned_box
	if reveal:
		target = reveal
		reveal.modulate.a = 0.0 # shows as the card lands
	if target == null or BMFx.instance == null:
		card.queue_free()
		return
	# The rebuilt rack is laid out on the next frame; then the card knows where to go.
	var target_ref: WeakRef = weakref(target)
	await get_tree().process_frame
	target = target_ref.get_ref() as Control
	if not is_instance_valid(card):
		return
	if target == null or run == null or run.phase != BMRun.Phase.SHOP:
		card.queue_free()
		if target:
			target.modulate = Color.WHITE
		return
	var t := BMFx.instance.fly_card(card, target.get_global_rect().get_center(), "buy")
	if t <= 0.0:
		card.queue_free()
		target.modulate = Color.WHITE
		return
	var is_card := reveal != null
	get_tree().create_timer(t).timeout.connect(func() -> void:
		var tgt := target_ref.get_ref() as Control
		BMAudio.sfx("card_land")
		if tgt == null:
			return
		tgt.pivot_offset = tgt.size / 2.0
		var tw := tgt.create_tween()
		if is_card:
			tgt.modulate = Color(1.7, 1.6, 1.2, 1.0)
			tw.tween_property(tgt, "scale", Vector2(1.06, 1.06), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(tgt, "scale", Vector2.ONE, 0.16)
			tw.parallel().tween_property(tgt, "modulate", Color.WHITE, 0.35)
		else:
			tw.tween_property(tgt, "scale", Vector2(1.1, 0.92), 0.07)
			tw.tween_property(tgt, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		if BMFx.instance:
			var c := tgt.get_global_rect().get_center()
			BMFx.instance.stars(c, 5, 70.0)
			BMFx.instance.ring(c, BMStyle.SUN_L, 60.0))


## New offers after a reroll fade in one after another, a soft deal tick each.
func _deal_in(rows: Array) -> void:
	if main.settings.reduced_motion:
		return
	var k := 0
	for row: Container in rows:
		for c in row.get_children():
			var card := c as Control
			card.modulate.a = 0.0
			var tw := card.create_tween()
			tw.tween_interval(0.05 * k)
			tw.tween_property(card, "modulate:a", 1.0, 0.16)
			BMAudio.sfx_later("deal", 0.05 * k, 1.0 + 0.03 * k)
			k += 1


func _play_result_sound(a: Dictionary, r: Dictionary) -> void:
	if not r.ok:
		BMAudio.sfx("deny")
		return
	match String(a.a):
		"buy_tool":
			BMAudio.sfx("workshop")
		"buy_holo":
			BMAudio.sfx("buy")
			_holo_fanfare(r)
		"buy_joker", "buy_consumable", "buy_piece":
			BMAudio.sfx("buy")
			if String(a.a) == "buy_joker" and BMJokers.is_legendary(String(r.get("item", ""))):
				_legendary_fanfare(String(r.item))
			if r.get("item", "") == "loan_shark":
				BMAudio.sfx_later("loan_cash", 0.15)
		"reroll":
			BMAudio.sfx("reroll")
		"move":
			BMAudio.sfx("tick")


## A Holo card applies: chrome sparkle, and a callout naming what changed.
func _holo_fanfare(r: Dictionary) -> void:
	if String(r.get("item", "")) == "legend_crate":
		_legendary_fanfare(String(r.get("joker", "")))
		return
	BMAudio.sfx_later("legendary_reveal", 0.1)
	var fx := BMFx.instance
	if fx == null:
		return
	var c := get_global_rect().get_center()
	fx.confetti(Rect2(Vector2.ZERO, size), 120)
	fx.pop_text(c + Vector2(0, -80), BMHolo.display_name(String(r.item)).to_upper(), BMStyle.CREAM, 60, 70.0, 1.4)
	if BMCrtLayer.instance:
		BMCrtLayer.instance.shock(0.4)


## A Legendary joins the rack: its own sting, lilac confetti and a callout.
func _legendary_fanfare(id: String) -> void:
	BMAudio.sfx_later("legendary_get", 0.1)
	var fx := BMFx.instance
	if fx == null:
		return
	var c := get_global_rect().get_center()
	fx.confetti(Rect2(Vector2.ZERO, size), 200)
	fx.pop_text(c + Vector2(0, -120), BMLoc.t("LEGENDARY!"), BMStyle.LILAC, 80, 70.0, 1.6)
	fx.pop_text(c + Vector2(0, -40), BMJokers.display_name(id).to_upper(), BMStyle.SUN_L, 40, 60.0, 1.6)
	fx.shake(10.0)
	if BMCrtLayer.instance:
		BMCrtLayer.instance.shock(0.6)


func _purchase_text(r: Dictionary) -> String:
	match r.type:
		"buy_piece":
			return BMLoc.t("Added %s to your bag (%d pieces).") % [BMPieces.piece_name(r.piece), run.bag.size()]
		"buy_tool":
			return BMLoc.t("Used %s.") % BMLoc.t(BMTools.get_def(r.item).name)
		"buy_joker":
			if r.item == "loan_shark":
				return BMLoc.t("Loan Shark lent you %d Credits. It takes %d back after each won round.") % [BMJokers.LOAN_CREDITS, BMJokers.LOAN_INSTALLMENT]
			return BMLoc.t("%s joined your rack!") % BMJokers.display_name(r.item)
		"buy_consumable":
			return BMLoc.t("Bought %s.") % BMConsumables.display_name(r.item)
		"buy_holo":
			return BMLoc.tf_join(r.get("events", []), "  ")
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if main.is_paused():
		return
	if _overlay.get_child_count() > 0 and not Array(run.shop.get("round_cards", [])).is_empty() and _picker_open():
		for i in 3:
			if event.is_action_pressed("bm_slot_%d" % (i + 1)) and i < Array(run.shop.round_cards).size():
				_pick_round_and_go(i)
				get_viewport().set_input_as_handled()
				return
	if _overlay.get_child_count() > 0 and event.is_action_pressed("bm_cancel"):
		BMUI.clear_children(_overlay)
		get_viewport().set_input_as_handled()
	elif _overlay.get_child_count() == 0 and event.is_action_pressed("bm_cancel"):
		main.show_pause()
		get_viewport().set_input_as_handled()
	elif _overlay.get_child_count() == 0 and event.is_action_pressed("bm_bag"):
		_show_bag()
		get_viewport().set_input_as_handled()


func refresh_all() -> void:
	if _crate_button:
		_crate_button.visible = run != null and run.has_crate()
	if run == null or run.phase != BMRun.Phase.SHOP:
		return
	_wallet.sync(run.credits)
	_overtime_pill.visible = run.overtime
	_reroll_button.text = BMLoc.t("REROLL  %d") % int(run.shop.reroll_cost)
	_reroll_button.disabled = run.credits < int(run.shop.reroll_cost)
	BMUI.fit_button(_reroll_button, 330, 30)
	_bag_button.text = BMLoc.t("BAG  %d") % run.bag.size()
	BMUI.fit_button(_bag_button, 236, 30)
	var next := run.round_number + 1
	var boss_next := BMRunConfig.is_boss_round(next)
	_next_label.text = BMLoc.t("ROUND %d") % next
	_boss_pill.visible = boss_next
	var cards: Array = run.shop.get("round_cards", [])
	var pick_card := String(cards[int(run.shop.get("round_pick", 0))]) if not cards.is_empty() else "standard"
	var next_target := run.round_target(next, pick_card)
	_target_label.text = BMUI.fmt_score(next_target)
	_target_label.tooltip_text = BMLoc.t("Score target for round %d: %s points") % [next, BMUI.fmt_int(next_target)] \
		+ ("\n" + BMLoc.t("Overtime: targets climb faster every round.") if run.overtime else "")
	var next_act := BMRunConfig.act_of(next)
	var boss_id: String = run.bosses[next_act - 1]
	var mk2 := run.boss_is_mk2(next_act)
	var boss_round := next_act * 4
	var bname := BMBosses.title(boss_id, mk2)
	var brule := BMBosses.rule_text(boss_id, mk2)
	_boss_name.text = bname.to_upper() if boss_next else BMLoc.t("%s  (ROUND %d)") % [bname.to_upper(), boss_round]
	_boss_label.text = brule
	_ticker.tooltip_text = BMLoc.t("Round %d boss: %s") % [boss_round, bname] + "\n" + brule
	_fit_ticker(_crate_button.visible)
	# Again once the wrapped labels have their width: measured before layout, their minimum
	# height is far too tall and the ticker would keep that size (past the screen bottom).
	_fit_ticker.call_deferred(_crate_button.visible)

	BMUI.clear_children(_jokers_row)
	for i in run.shop.jokers.size():
		var id: String = run.shop.jokers[i]
		if id == "":
			_jokers_row.add_child(_sold_out())
			continue
		var buy := _price_button(BMJokers.cost(id), func() -> void: _act({"a": "buy_joker", "i": i}))
		if BMJokers.is_legendary(id) and _legend_seen != "%d:%s" % [run.round_number, id]:
			_legend_seen = "%d:%s" % [run.round_number, id]
			BMAudio.sfx_later("legendary_reveal", 0.3)
		if run.rack_full():
			buy.disabled = true
			buy.tooltip_text = BMLoc.t("Joker slots are full. Sell one first.")
		_jokers_row.add_child(_card(BMCard.offer(run, "joker", id, buy)))

	BMUI.clear_children(_items_row)
	for i in run.shop.consumables.size():
		var id: String = run.shop.consumables[i]
		if id == "":
			_items_row.add_child(_sold_out())
			continue
		var buy := _price_button(BMConsumables.cost(id), func() -> void: _act({"a": "buy_consumable", "i": i}))
		if run.items_full():
			buy.disabled = true
			buy.tooltip_text = BMLoc.t("Item slots are full. Use an item first.")
		_items_row.add_child(_card(BMCard.offer(run, "item", id, buy)))

	BMUI.clear_children(_tools_row)
	for i in run.shop.tools.size():
		var o: Dictionary = run.shop.tools[i]
		if o.is_empty():
			_tools_row.add_child(_sold_out())
			continue
		var def := BMTools.get_def(o.id)
		var buy := _price_button(int(def.cost), func() -> void: _begin_tool(i),
			BMLoc.t("PICK %d") if int(def.max_targets) > 0 else "")
		_tools_row.add_child(_card(BMCard.offer(run, "tool", o, buy)))

	BMUI.clear_children(_pieces_row)
	var holo: Array = run.shop.get("holo", [])
	_pieces_pill.visible = holo.is_empty()
	_holo_pill.visible = not holo.is_empty()
	for i in holo.size():
		var ho: Dictionary = holo[i]
		if ho.is_empty():
			_pieces_row.add_child(_sold_out())
			continue
		var hbuy := _price_button(run.holo_price(ho), func() -> void: _act({"a": "buy_holo", "i": i}))
		var why := run.holo_blocked(ho)
		if why != "":
			hbuy.disabled = true
			hbuy.tooltip_text = BMLoc.tf(why)
		_pieces_row.add_child(_card(BMCard.offer(run, "holo", ho, hbuy)))
	for i in run.shop.pieces.size():
		var d: Dictionary = run.shop.pieces[i]
		if d.is_empty():
			_pieces_row.add_child(_sold_out())
			continue
		var buy := _price_button(int(d.cost), func() -> void: _act({"a": "buy_piece", "i": i}))
		if run.bag.size() >= BMPieces.MAX_BAG:
			buy.disabled = true
			buy.tooltip_text = BMLoc.t("Your bag is full.")
		_pieces_row.add_child(_card(BMCard.offer(run, "piece", BMPieces.from_dict(d), buy)))

	BMUI.clear_children(_owned_box)
	_owned_header.text = BMLoc.t("YOUR JOKERS %d/%d") % [run.occupied_slots(), run.joker_slots()]
	var card_h := BMCard.rack_height(run.rack_size())
	for i in run.jokers.size():
		var id := run.jokers[i]
		var card := BMCard.joker_rack(run, id, card_h, 420.0, i)
		card.reduced_motion = main.settings.reduced_motion
		card.drag_index = i
		card.drag_enabled = true
		card.drag_receiver = func(from: int, to: int) -> void:
			if to >= 0 and to < run.jokers.size():
				_act({"a": "move", "from": from, "to": to})
				if to < _owned_box.get_child_count():
					BMStyle.focus_later(_owned_box.get_child(to) as Control)
		card.tooltip_body += BMLoc.t("\nDrag onto another Joker to reorder. Alt+Up/Down while focused also moves it.")
		var loan := id == "loan_shark" and run.loan_debt > 0
		card.add_sell_button(BMJokers.sell_value(id), func() -> void: _act({"a": "sell", "i": i}), loan,
			BMLoc.tf(BMLoc.m("Repay the loan first (%d Credits owed).") % run.loan_debt) if loan else "")
		_owned_box.add_child(card)
	for i in maxi(0, run.joker_slots() - run.occupied_slots()):
		var empty := BMStyle.panel("panel_inset", Vector4.ZERO)
		empty.custom_minimum_size = Vector2(0, card_h)
		var l := BMStyle.label(BMLoc.t("empty slot"), 20, Color(BMStyle.TEXT_DIM, 0.5))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_child(l)
		_owned_box.add_child(empty)
	BMUI.clear_children(_owned_items)
	BMUI.clear_children(_owned_grid)
	var islots := run.consumable_slots()
	var ilayout := BMCard.item_layout(islots)
	var itiles := ilayout == "tile"
	_owned_items.visible = not itiles
	_owned_grid.visible = itiles
	var iholder: Container = _owned_grid if itiles else _owned_items
	var isize := Vector2(204, 76) if itiles else Vector2(204, 132)
	for i in run.consumables.size():
		var id := run.consumables[i]
		var c := BMCard.item_rack(id, run, ilayout, 2, false)
		c.custom_minimum_size = isize
		c.reduced_motion = main.settings.reduced_motion
		c.add_sell_button(BMConsumables.sell_value(id), func() -> void: _act({"a": "sell_item", "i": i}), false, "", itiles)
		iholder.add_child(c)
	for i in range(run.consumables.size(), islots):
		var empty := BMStyle.panel("panel_inset", Vector4.ZERO)
		empty.custom_minimum_size = isize
		var el := BMStyle.label(BMLoc.t("empty"), 20, Color(BMStyle.TEXT_DIM, 0.5))
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		el.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_child(el)
		iholder.add_child(empty)


func _card(c: BMCard) -> BMCard:
	c.reduced_motion = main.settings.reduced_motion
	return c


## While the BOSS CRATE button shows, the round ticker ends above it and the boss rule keeps
## as many lines as fit (ellipsis); the ticker tooltip always has the full rule.
## Shows as many lines of the boss rule as the ticker has room for. An autowrapped Label
## reports a one-line minimum height, so the rule's height is set from its real line count.
func _fit_ticker(crate_showing: bool) -> void:
	var h := (CRATE_BUTTON_Y - 8.0 if crate_showing else TICKER_BOTTOM) - _ticker.position.y
	_boss_label.custom_minimum_size.y = 0
	_boss_label.max_lines_visible = 1
	var lh := float(_boss_label.get_line_height()) + float(_boss_label.get_theme_constant("line_spacing"))
	var others := _ticker.get_combined_minimum_size().y - lh
	var lines := maxi(1, _boss_label.get_line_count())
	var n := clampi(floori((h - others) / lh), 1, mini(TICKER_RULE_LINES, lines))
	_boss_label.max_lines_visible = n
	_boss_label.custom_minimum_size.y = n * lh
	_ticker.size = Vector2(_ticker.size.x, h)


## `label` is the translated "BUY %d" (or "PICK %d" for Workshop cards that take targets).
func _price_button(cost: int, cb: Callable, label := "") -> Button:
	var text := (label if label != "" else BMLoc.t("BUY %d")) % cost
	# Longer words for "buy" step down to 20 so the button stays inside the offer card.
	# The button is the card's 224-px inner width: text room is what the coin icon leaves.
	var b := BMStyle.button(text, cb, "sun", BMUI.fit_size(text, BMStyle.font_bold, 30, 140)) # + coin icon, 224 px
	b.icon = BMStyle.tex("icon_coin")
	b.add_theme_constant_override("icon_max_width", 32)
	b.custom_minimum_size.y = 64
	if run.credits < cost:
		b.disabled = true
		b.tooltip_text = BMLoc.t("Not enough Credits.")
	return b


func _sold_out() -> Control:
	var p := BMStyle.panel("panel_inset", Vector4.ZERO)
	p.custom_minimum_size = BMCard.OFFER_SIZE
	var l := BMStyle.label(BMLoc.t("SOLD OUT"), 30, Color(BMStyle.TEXT_DIM, 0.6), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


# --- Bag viewer and Workshop picker ------------------------------------------------------------

## Where the tutorial (BMTutorial) points, in global coordinates; Rect2() when unknown.
func tutorial_rect(id: String) -> Rect2:
	match id:
		"shop_jokers":
			return _jokers_row.get_global_rect()
		"shop_tools":
			return _tools_row.get_global_rect()
		"next_round":
			var b := stage.find_child("LeaveButton", true, false) as Control
			return b.get_global_rect() if b else Rect2()
	return Rect2()


## NEXT ROUND: before a non-boss round the player first picks a round card (GDD §22.2).
func _on_leave() -> void:
	var cards: Array = run.shop.get("round_cards", [])
	if cards.is_empty():
		_act({"a": "leave_shop"})
	else:
		_show_round_picker()


const ROUND_CARD_COLORS := {"standard": "plum", "gold_rush": "sun", "tight_budget": "pink", "rush_hour": "sky",
	"double_or_nothing": "pink", "mult_fever": "pink", "treasure_hunt": "mint", "scholarship": "sky"}


func _show_round_picker() -> void:
	var v := _overlay_panel(1300)
	BMAudio.sfx("modal")
	var next := run.round_number + 1
	var t := BMStyle.label(BMLoc.t("CHOOSE ROUND %d") % next, 60, BMStyle.SUN, true, 14)
	t.name = "RoundPickerTitle"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_shadow_color", Color(BMStyle.PINK, 0.7))
	t.add_theme_constant_override("shadow_offset_y", 6)
	v.add_child(t)
	var sub := BMStyle.label(BMLoc.t("Play it straight, or take a twist for a reward. Keys 1-3 choose, Esc goes back."), 20, BMStyle.CREAM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var row := BMStyle.hbox(24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var cards: Array = run.shop.round_cards
	var first: Button = null
	for i in cards.size():
		var id := String(cards[i])
		var d := BMRoundCards.get_def(id)
		var color := String(ROUND_CARD_COLORS.get(id, "plum"))
		var card := BMStyle.panel("card_" + ("common" if id == "standard" else ("rare" if int(d.reward) >= 4 else "uncommon")), Vector4(-2, -2, -2, -6))
		card.custom_minimum_size = Vector2(360, 420)
		var cv := BMStyle.vbox(10)
		card.add_child(cv)
		var pill_row := CenterContainer.new()
		pill_row.add_child(BMStyle.pill(BMLoc.t("STANDARD") if id == "standard" else BMLoc.t("TWIST"), color, 20))
		cv.add_child(pill_row)
		var name := BMStyle.label(BMLoc.t(d.name).to_upper(), 40, BMStyle.INK, true)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(name)
		var tgt := BMStyle.hbox(6)
		tgt.alignment = BoxContainer.ALIGNMENT_CENTER
		tgt.add_child(BMStyle.icon_rect("icon_target", 0.75))
		var target := run.round_target(next, id)
		var tl := BMStyle.label(BMUI.fmt_score(target), 30, Color("#c42848"), true)
		tgt.add_child(tl)
		cv.add_child(tgt)
		var body := BMStyle.label(BMLoc.t(d.text), 20, Color(BMStyle.INK, 0.8))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cv.add_child(body)
		if int(d.reward) > 0:
			var rw := BMStyle.hbox(6)
			rw.alignment = BoxContainer.ALIGNMENT_CENTER
			rw.add_child(BMStyle.icon_rect("icon_coin", 0.75))
			rw.add_child(BMStyle.label(BMLoc.t("+%d IF YOU WIN") % int(d.reward), 20, Color("#8a5a00"), true))
			cv.add_child(rw)
		var idx := i
		var b := BMStyle.button(BMLoc.t("PLAY  %d") % (i + 1), func() -> void: _pick_round_and_go(idx), "sun" if i == 0 else color, 30)
		b.custom_minimum_size = Vector2(0, 72)
		cv.add_child(b)
		row.add_child(card)
		if first == null:
			first = b
		if not main.settings.reduced_motion:
			card.modulate = Color(1, 1, 1, 0)
			card.position.y += 40
			var tw := card.create_tween()
			tw.tween_interval(0.08 * i)
			tw.tween_property(card, "modulate", Color.WHITE, 0.2)
	var back := BMStyle.button(BMLoc.t("BACK TO THE SHOP"), func() -> void: BMUI.clear_children(_overlay), "plum", 20)
	var bc := CenterContainer.new()
	bc.add_child(back)
	v.add_child(bc)
	BMStyle.focus_later(first)


func _picker_open() -> bool:
	return _overlay.find_child("RoundPickerTitle", true, false) != null


func _pick_round_and_go(i: int) -> void:
	var r := _act({"a": "pick_round", "i": i})
	if not r.get("ok", false):
		return
	BMUI.clear_children(_overlay)
	BMAudio.sfx("round_pick", 1.0 if i == 0 else 1.12)
	_act({"a": "leave_shop"})


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
	var close := BMStyle.button(BMLoc.t("CLOSE  (ESC)"), func() -> void: BMUI.clear_children(_overlay), "sun", 30)
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
	hv.add_child(BMStyle.label(BMLoc.t("%s  -  %d CREDITS") % [BMTools.offer_name(o).to_upper(), int(def.cost)], 40, BMStyle.SUN, true, 10))
	var t := BMStyle.label(BMTools.offer_text(o, run), 20, BMStyle.CREAM)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(t)
	var status := BMStyle.label(BMLoc.tn("Choose up to %d piece.", "Choose up to %d pieces.", max_t) % max_t, 30, BMStyle.MINT_L, true, 8)
	v.add_child(status)
	var state := {"targets": [], "color": -1}
	var confirm := BMStyle.button(BMLoc.t("CONFIRM PURCHASE"), func() -> void: pass, "sun", 30)
	confirm.custom_minimum_size = Vector2(420, 72)
	var color_buttons: Array = []
	var update := func() -> void:
		var ok: bool = not state.targets.is_empty() and (def.kind != "repaint" or state.color >= 0)
		confirm.disabled = not ok
		var picked := BMLoc.t("%d of %d chosen") % [state.targets.size(), max_t]
		if def.kind == "repaint":
			picked += BMLoc.t("   -   color: %s") % (BMShapes.color_name(state.color).to_upper() if state.color >= 0 else BMLoc.t("pick one"))
		status.text = picked
		for i in color_buttons.size():
			var cb: Button = color_buttons[i]
			cb.text = ("> %s <" if i == state.color else "%s") % BMShapes.color_name(i).to_upper()
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
			status.text = BMLoc.tf(r.error)
			status.add_theme_color_override("font_color", BMStyle.PINK_L))
	row.add_child(confirm)
	var cancel := BMStyle.button(BMLoc.t("CANCEL  (ESC)"), func() -> void: BMUI.clear_children(_overlay), "plum", 30)
	cancel.custom_minimum_size = Vector2(300, 72)
	row.add_child(cancel)
	update.call()
