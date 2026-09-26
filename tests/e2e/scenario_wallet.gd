extends BME2ECase
## Selling items and the wallet (owner request, 2026-09-26: "add the selling unused items option,
## add animations when buying, selling, getting money ... make clicking in your money reactive").
##
## Ways this could fail (written down before the code):
##  S1  An owned item has no SELL control, in the shop or in the round's item rack (full cards
##      and the 2x2 tiles), so the player cannot sell it.
##  S2  A sale pays the wrong amount: it must be half the item's price rounded down, at least 1,
##      and never lift Credits past the cap.
##  S3  The wrong item leaves (index shift), or the sold one stays in the rack.
##  S4  A sale goes through where it should not: an empty or out-of-range slot, or outside the
##      shop and the gaps between placements (the round result screen).
##  S5  Selling while a targeted item is armed leaves a tool armed on a different item.
##  S6  The sale is missing from the history or the save, so resume/replay diverges.
##  S7  In the round a sale is one click with no confirmation (an item is easy to misclick away).
##  M1  After a purchase, a sale or a round win the wallet does not settle on the real Credits.
##  M2  A flying card (bought or sold) is left on screen, or it takes mouse input while it flies.
##  M3  The card a purchase lands in the rack stays transparent or scaled after its entrance.
##  M4  Clicking the wallet changes Credits or any run state, or fast clicking logs errors.
##  M5  Reduced Motion still flies cards and coins, or the wallet lags behind the real number.
## Setup that seeded play would not reliably reach (items held, Credits, the round) is written
## into the run and loaded through the real CONTINUE path; every step after that goes through
## the screens' own action functions.

const SEED := 70417


func run() -> void:
	await _shop_sale()
	await _round_sale()
	await _purchases_fly()
	await _wallet_clicks()
	await _reduced_motion()


func _load(r: BMRun) -> BMRun:
	BMSaveStore.save_run(r)
	main.continue_run()
	await frames(3)
	if main.run.phase == BMRun.Phase.ROUND:
		main.game_screen.close_overlay()
	await frames(1)
	return main.run


func _fresh(round_n: int = 1) -> BMRun:
	main.start_new_run(SEED, "standard", 0)
	await frames(3)
	main.game_screen.close_overlay()
	var r: BMRun = main.run
	if round_n != 1:
		r.round_number = round_n
		r.round_card = "standard"
		r._start_round()
	return r


static func _fx_cards() -> int:
	var n := 0
	if BMFx.instance == null:
		return 0
	for c in BMFx.instance.get_children():
		if c is BMCard or c.has_meta("flying"):
			n += 1
	return n


func _wallet_settled(w: BMWallet, tag: String) -> void:
	eq(w.target_amount(), main.run.credits, tag + ": the wallet aims at the real Credits")
	eq(w.shown_amount(), main.run.credits, tag + ": the wallet shows the real Credits")


# --- S1-S4, S6, M1, M2: selling in the shop ----------------------------------------------------

func _shop_sale() -> void:
	var r := await _fresh()
	r.consumables.assign(["polish", "eraser"]) # setup
	r.credits = 10 # setup
	r.round_number = 2 # setup
	r._open_shop()
	r = await _load(r)
	var shop: BMShopScreen = main.shop_screen
	var holder: Container = shop._owned_grid if shop._owned_grid.visible else shop._owned_items
	var sells := 0
	for c in holder.get_children():
		if c is BMCard and (c as BMCard).hover_controls and (c as BMCard).hover_controls.find_child("Sell", true, false):
			sells += 1
	eq(sells, 2, "S1: both shop items have a SELL control")
	var polish_value := BMConsumables.sell_value("polish")
	var eraser_value := BMConsumables.sell_value("eraser")
	eq(polish_value, maxi(1, BMConsumables.cost("polish") / 2), "S2: Polish sells for half its price, rounded down")
	eq(eraser_value, maxi(1, BMConsumables.cost("eraser") / 2), "S2: Eraser sells for half its price, rounded down")
	var bad: Dictionary = shop._act({"a": "sell_item", "i": 5})
	check(not bad.get("ok", true), "S4: an empty slot cannot be sold")
	var res: Dictionary = shop._act({"a": "sell_item", "i": 1})
	check(res.get("ok", false), "S3: the Eraser sells")
	eq(Array(r.consumables), ["polish"], "S3: only the Eraser left")
	eq(r.credits, 10 + eraser_value, "S2: paid into the wallet")
	eq(r.history[-1], {"a": "sell_item", "i": 1}, "S6: the sale is in the history")
	await frames(2)
	check(_fx_cards() > 0 or main.settings.reduced_motion, "M2: the sold card flies off")
	for c in BMFx.instance.get_children():
		if c is Control and c.has_meta("flying"):
			eq((c as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "M2: a flying card takes no input")
			for d in c.find_children("*", "Control", true, false):
				eq((d as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "M2: nor do its parts")
	await wait(2.5)
	eq(_fx_cards(), 0, "M2: nothing is left flying")
	_wallet_settled(shop._wallet, "M1 shop sale")
	await screenshot("shop_after_sale")
	var digest := run_digest(r)
	r = await _load(r)
	eq(run_digest(r), digest, "S6: resume keeps the sale")
	# The Credit cap.
	r.credits = BMRunConfig.CREDIT_CAP # setup
	r = await _load(r)
	check(main.shop_screen._act({"a": "sell_item", "i": 0}).get("ok", false), "S2: sells at the cap")
	eq(r.credits, BMRunConfig.CREDIT_CAP, "S2: the cap holds")
	facts["shop_sale"] = {"polish": polish_value, "eraser": eraser_value, "credits": r.credits}
	checkpoint("shop_sale", facts["shop_sale"])
	main.abandon_run()
	await frames(2)


# --- S1, S3, S5, S7: selling between placements ---------------------------------------------

func _round_sale() -> void:
	var r := await _fresh(2)
	r.consumables.assign(["spark", "eraser"]) # setup
	r.credits = 4 # setup
	r = await _load(r)
	var gs: BMGameScreen = main.game_screen
	var cards := _item_cards(gs)
	eq(cards.size(), 2, "setup: two items in the rack")
	check(cards[0].hover_controls != null and cards[0].hover_controls.find_child("Sell", true, false) != null, "S1: the round item card has SELL")
	# S7: the button asks first; KEEP keeps the item.
	gs._confirm_sell_item(0)
	await frames(2)
	check(gs.overlay.get_child_count() > 0, "S7: selling asks for confirmation")
	var keep := _dialog_button(gs, BMLoc.t("KEEP"))
	check(keep != null, "S7: the dialog offers KEEP")
	if keep:
		keep.pressed.emit()
	await frames(2)
	eq(Array(r.consumables), ["spark", "eraser"], "S7: KEEP keeps the item")
	# S5: with the Eraser (slot 2) armed, SELL is off; a sale that still arrives disarms it.
	gs._begin_tool("eraser", 1)
	await frames(2)
	var armed_sell := _item_cards(gs)[0].hover_controls.find_child("Sell", true, false) as Button
	check(armed_sell != null and armed_sell.disabled, "S5: SELL is off while an item is armed")
	var before := r.credits
	check(gs._do_action({"a": "sell_item", "i": 0}).get("ok", false), "S3: Spark sells")
	check(gs._tool.is_empty(), "S5: no tool stays armed after a sale")
	eq(Array(r.consumables), ["eraser"], "S3: the Eraser stays")
	eq(r.credits, before + BMConsumables.sell_value("spark"), "S2: the round sale pays")
	await frames(2)
	before = r.credits
	gs._confirm_sell_item(0)
	await frames(2)
	var sell := _dialog_button(gs, BMLoc.t("SELL"))
	check(sell != null, "S7: the dialog offers SELL")
	if sell:
		sell.pressed.emit()
	await frames(2)
	eq(Array(r.consumables), [], "S3: the rack is empty")
	eq(r.credits, before + BMConsumables.sell_value("eraser"), "S2: the confirmed sale pays")
	await wait(2.5)
	_wallet_settled(gs._wallet, "M1 round sale")
	eq(_fx_cards(), 0, "M2: nothing left flying in the round")
	# S1: the 2x2 tiles (Item Pouch) have SELL too.
	r.extra_item_slots = 2 # setup
	r.consumables.assign(["eraser", "spark", "polish"]) # setup
	r = await _load(r)
	var tiles := _item_cards(main.game_screen)
	eq(tiles.size(), 3, "setup: three tiles")
	var tile_sells := 0
	for c in tiles:
		if c.hover_controls and c.hover_controls.find_child("Sell", true, false):
			tile_sells += 1
	eq(tile_sells, 3, "S1: every tile has SELL")
	await screenshot("round_tiles")
	# S4: not from the round result screen.
	r.round_state.score = r.round_state.target # setup
	r._after_round_action()
	check(not r.apply_action({"a": "sell_item", "i": 0}).get("ok", true), "S4: no sale on the round result")
	facts["round_sale"] = {"left": Array(r.consumables), "credits": r.credits}
	checkpoint("round_sale", facts["round_sale"])
	main.abandon_run()
	await frames(2)


func _item_cards(gs: BMGameScreen) -> Array[BMCard]:
	var out: Array[BMCard] = []
	var holder: Container = gs._items_grid if gs._items_grid.visible else gs._items_box
	for c in holder.get_children():
		if c is BMCard and c.has_meta("item_index"):
			out.append(c)
	return out


func _dialog_button(gs: BMGameScreen, text: String) -> Button:
	for b in gs.overlay.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null


# --- M1, M2, M3: purchases fly into the rack -------------------------------------------------

func _purchases_fly() -> void:
	var r := await _fresh()
	r.credits = 40 # setup
	r.round_number = 2 # setup
	r._open_shop()
	r = await _load(r)
	var shop: BMShopScreen = main.shop_screen
	var joker_i := -1
	for i in r.shop.jokers.size():
		if r.shop.jokers[i] != "" and BMJokers.cost(r.shop.jokers[i]) <= r.credits:
			joker_i = i
			break
	check(joker_i >= 0, "setup: an affordable Joker on the shelf")
	var jid: String = r.shop.jokers[joker_i]
	var res: Dictionary = shop._act({"a": "buy_joker", "i": joker_i})
	check(res.get("ok", false), "the Joker is bought")
	await frames(2)
	check(_fx_cards() > 0, "M2: the bought card flies to the rack")
	await wait(2.5)
	eq(_fx_cards(), 0, "M2: and lands")
	var landed := shop._owned_box.get_child(r.jokers.size() - 1) as BMCard
	check(landed != null and String(landed.data) == jid, "M3: the new card is last in the rack")
	if landed:
		check(landed.modulate.is_equal_approx(Color.WHITE), "M3: it is fully shown (modulate %s)" % landed.modulate)
		check(landed.scale.is_equal_approx(Vector2.ONE), "M3: at its size (scale %s)" % landed.scale)
	_wallet_settled(shop._wallet, "M1 purchase")
	var item_i := -1
	for i in r.shop.consumables.size():
		if r.shop.consumables[i] != "":
			item_i = i
			break
	if item_i >= 0:
		check(shop._act({"a": "buy_consumable", "i": item_i}).get("ok", false), "an item is bought")
		await wait(2.5)
		eq(_fx_cards(), 0, "M2: the item lands")
		_wallet_settled(shop._wallet, "M1 item purchase")
	await screenshot("shop_after_buys")
	facts["purchases"] = {"joker": jid, "credits": r.credits, "items": Array(r.consumables)}
	checkpoint("purchases", facts["purchases"])
	main.abandon_run()
	await frames(2)


# --- M4: the wallet reacts to clicks and changes nothing ---------------------------------------

func _wallet_clicks() -> void:
	var r := await _fresh()
	r.credits = 12 # setup
	r.round_number = 2 # setup
	r._open_shop()
	r = await _load(r)
	var digest := run_digest(r)
	var w: BMWallet = main.shop_screen._wallet
	for i in 14:
		_click(w)
		await frames(1)
	await wait(1.5)
	eq(run_digest(main.run), digest, "M4: clicking the wallet changes nothing in the run")
	eq(w.shown_amount(), 12, "M4: the wallet still shows 12")
	check(w.pokes() >= 14, "M4: every click registered (%d)" % w.pokes())
	main.shop_screen._act({"a": "leave_shop"}) if Array(r.shop.get("round_cards", [])).is_empty() else main.shop_screen._pick_round_and_go(0)
	await frames(3)
	main.game_screen.close_overlay()
	var gw: BMWallet = main.game_screen._wallet
	digest = run_digest(main.run)
	for i in 5:
		_click(gw)
		await frames(1)
	await wait(1.0)
	eq(run_digest(main.run), digest, "M4: nor does the round's wallet")
	facts["clicks"] = {"credits": main.run.credits}
	checkpoint("clicks", facts["clicks"])
	main.abandon_run()
	await frames(2)


func _click(w: Control) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = w.size / 2.0
	w._gui_input(ev)


# --- M5: Reduced Motion ---------------------------------------------------------------------

func _reduced_motion() -> void:
	main.set_setting("reduced_motion", true)
	var r := await _fresh()
	r.consumables.assign(["polish"]) # setup
	r.credits = 9 # setup
	r.round_number = 2 # setup
	r._open_shop()
	r = await _load(r)
	var shop: BMShopScreen = main.shop_screen
	check(shop._act({"a": "sell_item", "i": 0}).get("ok", false), "reduced motion: the sale goes through")
	await frames(2)
	eq(_fx_cards(), 0, "M5: no flying card with Reduced Motion")
	_wallet_settled(shop._wallet, "M5 sale")
	main.set_setting("reduced_motion", false)
	main.abandon_run()
	await frames(2)
