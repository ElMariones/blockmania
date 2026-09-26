extends BME2ECase
## Study follow-up (owner request, 2026-09-26): items that scale and show their value, merged
## and new random items, owned Jokers offered less often, real-bet round cards, sharper act
## bosses, dead trays that can end a round, and the late-game Credit sinks (Tuning Fork, Item
## Pouch, the Holo shelf with Negative and AGAIN Jokers).
##
## Ways this could fail (written down before the code it checks):
## Items
##  I1  Polish does not add 40 Chips per round number, or its preview differs from the result.
##  I2  Spark does not add 1 Mult per act.
##  I3  An item card does not show its live value before use (Polish "+N Chips", Spark "+N
##      Mult", Coin Roll "+N Credits", Double Down's stake).
##  I4  A retired item (Punch, Coffee Break, Cash Out, Blueprint) is still offered by the shop,
##      a crate, Treasure Hunt or the Vending Machine; or one held from an older save can no
##      longer be used.
##  I5  Eraser refuses three blocks or removes more than three.
##  I6  Lucky Draw adds a Joker with no free slot, wins more or less than about 1 in 5, or its
##      outcome changes on replay.
##  I7  Mystery Stamp stamps an already stamped piece, a piece outside the bag, or nothing when
##      an unstamped piece exists.
##  I8  Double Down pays more than +20, pays on a losing roll, or changes on replay.
##  I9  Phantom Line counts its extra line on a placement that clears nothing, is spent without
##      a clear, or its preview differs from the result.
## Shop
##  S1  An owned Joker is offered as often as an unowned one (it should be about 1/5 as
##      likely), or never.
##  S2  The shop card of a Joker you own has no OWNED tag.
##  S3  Tuning Fork or Item Pouch is offered before act 2.
##  S4  The Item Pouch's third slot does not hold or show an item; slots go past 4.
##  S5  Tuning Fork levels a rule Joker, or a level does not add +50% of the effect.
## Holo shelf
##  H1  Holo cards are offered before the shop after round 8, or pieces are still offered in
##      their place.
##  H2  A Negative Joker still takes a slot, the rack cannot take the extra Joker, or the card
##      does not say NEGATIVE.
##  H3  An AGAIN Joker does not trigger once more after every Joker, has no AGAIN receipt line,
##      or a rule Joker gets AGAIN.
##  H4  Holo purchases do not survive SAVE & QUIT + CONTINUE or replay.
##  H5  Legend Crate gives a Legendary you already own, or needs no free slot.
## Round cards and bosses
##  C1  Twist numbers differ from their card text (Double or Nothing x1.7 +7, Tight Budget -5
##      +5, Gold Rush +1, Rush Hour +3, Mult Fever x1.5, Treasure Hunt x1.35, Scholarship x1.4).
##  B1  Act-boss targets (rounds 4 and 8) are not x1.15; the final boss or Overtime changes.
## Dead trays
##  N1  A tray refilled during a round is still swapped for a fitting one (the guarantee holds
##      only for the round's first tray, a Refresh and Second Tray).
##  N2  A dead tray with no rescue does not end the round as a no-fit loss.
##  N3  A Refresh does not guarantee a playable tray.
## Color and form Jokers (owner request, 2026-09-26)
##  J1  A color common boosts a shape of another color, or misses its own color or a Prism piece.
##  J2  A color rare's xMult does not grow with the matching pieces in the bag (Repaint), or
##      passes x3.
##  J3  A form card boosts the wrong form (Bars are Bar 2 to Bar 5, Ls are L 3 and L 4).
##  J4  The Color Blind does not switch color cards off, or switches form cards off too.
##  H6  A Holo card's price does not rise by half its base after each purchase, or a rack takes
##      more than three Negative or three AGAIN Jokers.
## Saves
##  V1  Save schema 9 loses Joker mods, item slots, pending Phantom Lines or the item stream;
##      a schema-8 save no longer loads.
## Setup that seeded play would not reliably reach (a given rack, items, board or shop shelf) is
## written into the run and loaded through the real CONTINUE path, marked as setup. Every
## player step goes through the screens' own action functions (round screen, shop, picker).

const SEED := 91001


func run() -> void:
	await _boosts_and_phantom_line()
	await _board_items()
	await _chance_items()
	await _shop_odds_and_workshop()
	await _holo_shelf()
	await _round_cards_and_bosses()
	await _color_and_form_jokers()
	await _dead_trays()
	await _old_save_loads()


# --- helpers ------------------------------------------------------------------------------

func _load(r: BMRun) -> BMRun:
	BMSaveStore.save_run(r)
	main.continue_run()
	await frames(3)
	if main.run.phase == BMRun.Phase.ROUND:
		main.game_screen.close_overlay()
	await frames(1)
	return main.run


## A new run, optionally moved to round `round_n` (setup).
func _fresh(seed_value: int, round_n: int = 1) -> BMRun:
	main.start_new_run(seed_value, "standard", 0)
	await frames(3)
	main.game_screen.close_overlay()
	var r: BMRun = main.run
	if round_n != 1:
		r.round_number = round_n
		r.round_card = "standard"
		r._start_round()
	return r


## The shop after round `round_n` (setup), shown through CONTINUE.
func _shop_at(r: BMRun, round_n: int) -> BMRun:
	r.round_number = round_n
	r._open_shop()
	return await _load(r)


func _use(i: int, extra: Dictionary = {}) -> Dictionary:
	var a := {"a": "use", "i": i}
	a.merge(extra)
	var res: Dictionary = main.game_screen._do_action(a)
	await frames(1)
	return res


## First legal placement of the first open slot that has one: {slot, anchor} or {}.
static func _any_move(r: BMRun) -> Dictionary:
	for s in r.tray.size():
		if r.tray[s].is_empty() or r.slot_locked(s):
			continue
		var anchors := r.board.legal_anchors(r.tray[s].cells)
		if not anchors.is_empty():
			return {"slot": s, "anchor": anchors[0]}
	return {}


## Places through the round screen after checking the preview; returns the result.
func _place(slot: int, anchor: Vector2i, tag: String) -> Dictionary:
	var r: BMRun = main.run
	var preview := r.preview_place(slot, anchor)
	var res: Dictionary = main.game_screen._do_action({"a": "place", "slot": slot, "x": anchor.x, "y": anchor.y})
	await frames(1)
	eq(int(res.get("points", -1)), int(preview.get("points", -2)), tag + ": preview equals the result")
	return res


## Row `y` full except its last cell, and a Single in `slot` (setup; call _load after).
static func _one_to_clear(r: BMRun, y: int, slot: int) -> void:
	r.board = BMBoard.new()
	for x in BMBoard.SIZE - 1:
		r.board.set_cell(Vector2i(x, y), (x + y) % BMShapes.OFFER_COLOR_COUNT)
	deal_family(r, slot, "single")


## Fewest empty cells left in the row or column of `p` (counting `p` itself).
static func _gaps(board: BMBoard, p: Vector2i) -> int:
	var row := 0
	var col := 0
	for i in BMBoard.SIZE:
		if board.is_empty(Vector2i(i, p.y)):
			row += 1
		if board.is_empty(Vector2i(p.x, i)):
			col += 1
	return mini(row, col)


static func _item(res: Dictionary, label: String) -> Dictionary:
	for it in res.get("items", []):
		if String(it.label) == label:
			return it
	return {}


static func _live_texts(box: Node) -> Array:
	var out: Array = []
	for l in box.find_children("LiveValue", "Label", true, false):
		out.append((l as Label).text)
	return out


# --- Items --------------------------------------------------------------------------------

func _boosts_and_phantom_line() -> void:
	var r: BMRun = await _fresh(SEED, 5)
	r.consumables.assign(["polish", "spark", "phantom_line"]) # setup
	r = await _load(r)
	var lives := _live_texts(main.game_screen._items_box)
	check(lives.has("+200 Chips"), "I3: Polish shows +200 Chips in round 5 (%s)" % str(lives))
	check(lives.has("+2 Mult"), "I3: Spark shows +2 Mult in act 2 (%s)" % str(lives))
	var used := await _use(0)
	eq(int(used.get("value", 0)), 200, "I1: Polish adds 40 x round 5")
	var mv := _any_move(main.run)
	var res := await _place(int(mv.slot), mv.anchor, "I1")
	eq(int(_item(res, "Polish").get("value", 0)), 200, "I1: the receipt shows Polish +200")
	used = await _use(0)
	eq(float(used.get("value", 0.0)), 2.0, "I2: Spark adds 1 Mult per act (act 2)")
	mv = _any_move(main.run)
	res = await _place(int(mv.slot), mv.anchor, "I2")
	eq(float(_item(res, "Spark").get("value", 0.0)), 2.0, "I2: the receipt shows Spark +2")
	# Phantom Line: waits for a clear, then counts one extra line.
	used = await _use(0)
	eq(main.run.round_state.pending_lines, 1, "I9: Phantom Line is armed")
	r = main.run
	r.board = BMBoard.new() # setup: an empty board, so the next placement clears nothing
	r = await _load(r)
	mv = _any_move(r)
	res = await _place(int(mv.slot), mv.anchor, "I9 miss")
	eq(int(res.get("lines", -1)), 0, "setup: the placement clears nothing")
	eq(main.run.round_state.pending_lines, 1, "I9: a placement without a clear keeps the Phantom Line")
	r = main.run
	_one_to_clear(r, 3, 0)
	r = await _load(r)
	res = await _place(0, Vector2i(BMBoard.SIZE - 1, 3), "I9 clear")
	eq(int(res.get("lines", 0)), 2, "I9: one real line plus the Phantom Line")
	eq(int(res.get("phantom_lines", 0)), 1, "I9: the record names the Phantom Line")
	check(not _item(res, "Lines x2 (Phantom Line +1)").is_empty(), "I9: the receipt says Phantom Line")
	eq(main.run.round_state.pending_lines, 0, "I9: the Phantom Line is spent by the clear")
	facts["boosts"] = {"lines": int(res.lines), "points": int(res.points)}
	main.abandon_run()
	await frames(2)


func _board_items() -> void:
	var r: BMRun = await _fresh(SEED + 1)
	for x in 6: # setup: six blocks on the board
		r.board.set_cell(Vector2i(x, 5), x % BMShapes.OFFER_COLOR_COUNT)
	r.consumables.assign(["eraser", "punch"]) # setup: a retired Punch from an older save
	r = await _load(r)
	var res := await _use(0, {"cells": [[0, 5], [1, 5], [2, 5], [3, 5]]})
	check(not res.get("ok", true), "I5: Eraser refuses four blocks")
	res = await _use(0, {"cells": [[0, 5], [1, 5], [2, 5]]})
	check(res.get("ok", false), "I5: Eraser takes three blocks")
	eq(Array(res.get("removed", [])).size(), 3, "I5: three blocks removed")
	res = await _use(0, {"cells": [[4, 5]]})
	check(res.get("ok", false), "I4: a retired Punch held from an older save still works")
	# I4: retired items are never handed out.
	var pool := BMConsumables.shop_pool()
	for id in ["punch", "coffee_break", "cash_out", "blueprint"]:
		check(not pool.has(id), "I4: %s is not in the shop pool" % id)
	var c: BMRun = main.run.clone()
	for k in 40:
		var crate: Array = c._roll_crate()
		check(not BMConsumables.is_retired(String(crate[1].id)), "I4: a crate never holds a retired item")
	main.abandon_run()
	await frames(2)


func _chance_items() -> void:
	var r: BMRun = await _fresh(SEED + 2)
	r.jokers.assign([]) # setup
	r = await _load(r)
	var wins := 0
	var outcomes: Array = []
	for k in 30:
		r = main.run
		r.jokers.assign([]) # setup: a free slot every time
		r.joker_mods = []
		r.consumables.assign(["lucky_draw"])
		var copy := r.clone()
		var twin := copy.apply_action({"a": "use", "i": 0})
		var res := await _use(0)
		eq(String(res.get("joker", "")), String(twin.get("joker", "")), "I6: the same state gives the same draw")
		if res.has("joker"):
			wins += 1
			check(int(BMJokers.get_def(String(res.joker)).rarity) >= BMJokers.UNCOMMON, "I6: Lucky Draw gives Uncommon or better")
			check(main.run.jokers.has(String(res.joker)), "I6: the Joker joined the rack")
		outcomes.append(String(res.get("joker", "")))
	check(wins >= 1 and wins <= 14, "I6: about 1 in 5 wins (%d of 30)" % wins)
	r = main.run
	r.jokers.assign(["clean_sweep", "small_change", "heavy_hand", "first_strike", "neat_freak"]) # setup: full rack
	r.joker_mods = []
	r.consumables.assign(["lucky_draw"])
	r = await _load(r)
	var full := await _use(0)
	check(not full.get("ok", true), "I6: Lucky Draw needs a free Joker slot")
	# I7: Mystery Stamp.
	r = main.run
	r.consumables.assign(["mystery_stamp"])
	var before := {}
	for p in r.bag:
		before[int(p.uid)] = String(p.get("stamp", ""))
	r = await _load(r)
	var st := await _use(0)
	check(st.get("ok", false), "I7: Mystery Stamp is used")
	var changed: Array = []
	for p in main.run.bag:
		if String(p.get("stamp", "")) != String(before.get(int(p.uid), "")):
			changed.append(int(p.uid))
	eq(changed, [int(st.get("uid", -1))], "I7: exactly the named piece got a stamp")
	eq(String(before.get(int(st.get("uid", -1)), "x")), "", "I7: it had no stamp before")
	r = main.run
	for p in r.bag:
		p.stamp = "tip" # setup: every piece stamped
	r.consumables.assign(["mystery_stamp"])
	r = await _load(r)
	check(not (await _use(0)).get("ok", true), "I7: nothing to stamp is refused")
	# I8: Double Down.
	var dd_wins := 0
	for stake in [50, 7]:
		for k in 20:
			r = main.run
			r.credits = stake # setup
			r.consumables.assign(["double_down"])
			var twin := r.clone().apply_action({"a": "use", "i": 0})
			var res := await _use(0)
			var gain: int = main.run.credits - stake
			check(gain == 0 or gain == mini(20, stake), "I8: Double Down pays 0 or min(20, stake), got %d" % gain)
			eq(gain, int(twin.get("credits", -1)), "I8: the same state gives the same roll")
			if gain > 0:
				dd_wins += 1
	check(dd_wins >= 1 and dd_wins <= 20, "I8: about 1 in 5 wins (%d of 40)" % dd_wins)
	facts["chance"] = {"lucky": outcomes, "double_down_wins": dd_wins}
	main.abandon_run()
	await frames(2)


# --- Shop ---------------------------------------------------------------------------------

func _shop_odds_and_workshop() -> void:
	var r: BMRun = await _fresh(SEED + 3)
	var owned := ["clean_sweep", "small_change", "heavy_hand"]
	r.jokers.assign(owned) # setup
	r = await _shop_at(r, 2)
	var seen := {}
	var early_tools := 0
	var tag_ok := false
	for k in 150:
		r = main.run
		r.credits = 99 # setup: rerolls are free of money worries
		r.shop.reroll_cost = 2
		main.shop_screen._act({"a": "reroll"})
		for id in main.run.shop.jokers:
			seen[id] = int(seen.get(id, 0)) + 1
		for o in main.run.shop.tools:
			if String(o.get("id", "")) in ["tuning_fork", "item_pouch"]:
				early_tools += 1
		if not tag_ok:
			for card in main.shop_screen._jokers_row.get_children():
				if card is BMCard and owned.has(String(card.data)):
					tag_ok = card.find_child("OwnedTag", true, false) != null
		if k % 50 == 0:
			await frames(1)
	var owned_hits := 0
	for id in owned:
		owned_hits += int(seen.get(id, 0))
	var other := 0
	var others := 0
	for id in BMJokers.ids_of_rarity(BMJokers.COMMON):
		if not owned.has(id) and not main.run.locked_jokers.has(id):
			other += int(seen.get(id, 0))
			others += 1
	var ratio := (owned_hits / 3.0) / maxf(0.01, float(other) / others)
	check(owned_hits >= 1, "S1: owned Jokers can still be offered (%d times)" % owned_hits)
	check(ratio > 0.05 and ratio < 0.5, "S1: an owned Joker is about 1/5 as likely (ratio %.2f)" % ratio)
	check(tag_ok, "S2: an owned Joker's shop card has the OWNED tag")
	eq(early_tools, 0, "S3: no Tuning Fork or Item Pouch before act 2")
	# Act 2 shops can offer them.
	r = main.run
	r.jokers.assign(["hoarder"]) # a scoring Joker, so the Tuning Fork has a target
	r.joker_mods = []
	r = await _shop_at(r, 5)
	var late_tools := 0
	for k in 60:
		r = main.run
		r.credits = 99
		r.shop.reroll_cost = 2
		main.shop_screen._act({"a": "reroll"})
		for o in main.run.shop.tools:
			if String(o.get("id", "")) in ["tuning_fork", "item_pouch"]:
				late_tools += 1
	check(late_tools > 0, "S3: act 2 shops offer them (%d)" % late_tools)
	# S4: Item Pouch up to 4 slots.
	for n in 3:
		r = main.run
		r.credits = 99
		r.shop.tools = [{"id": "item_pouch", "family": ""}, {}] # setup
		var bought: Dictionary = main.shop_screen._act({"a": "buy_tool", "i": 0, "targets": [], "color": -1})
		check(bought.get("ok", false) == (n < 2), "S4: pouch %d %s" % [n + 1, "fits" if n < 2 else "is refused at 4 slots"])
	eq(main.run.consumable_slots(), 4, "S4: four item slots")
	# S5: the Tuning Fork levels the top scoring Joker, never a rule Joker.
	r = main.run
	r.jokers.assign(["spare_parts", "hoarder"]) # setup
	r.joker_mods = []
	r.credits = 99
	r.shop.tools = [{"id": "tuning_fork", "family": ""}, {}]
	var tf: Dictionary = main.shop_screen._act({"a": "buy_tool", "i": 0, "targets": [], "color": -1})
	check(tf.get("ok", false), "S5: Tuning Fork bought")
	eq(main.run.joker_level(0), 0, "S5: the rule Joker on top gets no level")
	eq(main.run.joker_level(1), 1, "S5: the scoring Joker gets level 1")
	# In the round: four items show, and Hoarder Lv 1 scores +50%.
	r = main.run
	r.consumables.assign(["polish", "spark", "coin_roll", "double_down"]) # setup
	main.shop_screen._pick_round_and_go(0) if not Array(r.shop.get("round_cards", [])).is_empty() else main.shop_screen._act({"a": "leave_shop"})
	await frames(3)
	main.game_screen.close_overlay()
	await frames(1)
	var item_cards := 0
	for ch in main.game_screen._items_grid.get_children():
		if ch is BMCard:
			item_cards += 1
	eq(item_cards, 4, "S4: the round shows four item cards")
	r = main.run
	var mv := _any_move(r)
	var res := await _place(int(mv.slot), mv.anchor, "S5")
	var bag_n := r.bag.size()
	eq(int(_item(res, "Hoarder Lv 1").get("value", 0)), roundi(bag_n * 1.5), "S5: Hoarder Lv 1 scores bag size x1.5")
	await screenshot("items_four")
	facts["shop"] = {"owned_hits": owned_hits, "late_tools": late_tools, "hoarder": int(_item(res, "Hoarder Lv 1").get("value", 0))}
	main.abandon_run()
	await frames(2)


# --- Holo shelf ---------------------------------------------------------------------------

func _holo_shelf() -> void:
	var r: BMRun = await _fresh(SEED + 4)
	r = await _shop_at(r, 7)
	check(Array(r.shop.get("holo", [])).is_empty() and r.shop.pieces.size() == BMRunConfig.PIECE_OFFERS, "H1: no Holo shelf after round 7")
	r = await _shop_at(main.run, 8)
	eq(Array(r.shop.get("holo", [])).size(), BMRunConfig.HOLO_OFFERS, "H1: the Holo shelf opens after round 8")
	eq(Array(r.shop.pieces).size(), 0, "H1: no pieces in its place")
	check(main.shop_screen._holo_pill.visible and not main.shop_screen._pieces_pill.visible, "H1: the shelf is labeled HOLO")
	await screenshot("holo_shelf")
	# H2: Negative Film on a full rack.
	r = main.run
	r.jokers.assign(["clean_sweep", "small_change", "heavy_hand", "first_strike", "neat_freak"]) # setup
	r.joker_mods = []
	r.credits = 99
	r.shop.holo = [{"id": "negative_film", "joker": ""}, {"id": "again_seal", "joker": ""}]
	r = await _load(r)
	var twin := r.clone().apply_action({"a": "buy_holo", "i": 0})
	var neg: Dictionary = main.shop_screen._act({"a": "buy_holo", "i": 0})
	check(neg.get("ok", false), "H2: Negative Film bought")
	eq(int(neg.get("index", -1)), int(twin.get("index", -2)), "H4: the same state picks the same Joker")
	r = main.run
	eq(r.occupied_slots(), 4, "H2: the Negative Joker takes no slot")
	check(not r.rack_full(), "H2: the rack has room again")
	r.shop.jokers[0] = "chain_link" # setup
	var extra: Dictionary = main.shop_screen._act({"a": "buy_joker", "i": 0})
	check(extra.get("ok", false), "H2: a sixth Joker fits beside the Negative one")
	eq(main.run.jokers.size(), 6, "H2: six Jokers on a five-slot rack")
	var neg_card := false
	for card in main.shop_screen._owned_box.get_children():
		if card is BMCard and card.material is ShaderMaterial:
			for l in card.find_children("*", "Label", true, false):
				if (l as Label).text.contains("NEGATIVE"):
					neg_card = true
	check(neg_card, "H2: the rack card says NEGATIVE (and wears the shader)")
	# H3: AGAIN on the only scoring Joker; a rule Joker is never chosen.
	r = main.run
	r.jokers.assign(["spare_parts", "clean_sweep"]) # setup
	r.joker_mods = []
	r.credits = 99
	r.shop.holo = [{"id": "again_seal", "joker": ""}, {}]
	r = await _load(r)
	var ag: Dictionary = main.shop_screen._act({"a": "buy_holo", "i": 0})
	check(ag.get("ok", false), "H3: AGAIN Seal bought")
	check(not bool(main.run.joker_mod(0).get("again", false)), "H3: the rule Joker did not get AGAIN")
	check(bool(main.run.joker_mod(1).get("again", false)), "H3: Clean Sweep got AGAIN")
	# H4: survives SAVE & QUIT + CONTINUE.
	var mods: Array = main.run._mods_data()
	main.show_pause()
	await frames(2)
	main.save_and_quit()
	await frames(2)
	main.continue_run()
	await frames(3)
	eq(main.run._mods_data(), mods, "H4: Joker traits survive SAVE & QUIT + CONTINUE")
	# In a round: one line clear, Clean Sweep scores, then scores AGAIN after every Joker.
	r = main.run
	r.round_number = 9
	r.round_card = "standard"
	r._start_round() # setup
	_one_to_clear(r, 2, 1)
	r = await _load(r)
	var res := await _place(1, Vector2i(BMBoard.SIZE - 1, 2), "H3")
	var labels: Array = []
	for it in res.items:
		if String(it.source) == "joker":
			labels.append(String(it.label))
	check(labels.has("Clean Sweep") and labels.has("Clean Sweep, AGAIN"), "H3: Clean Sweep scores, then AGAIN (%s)" % str(labels))
	eq(labels.back() if not labels.is_empty() else "", "Clean Sweep, AGAIN", "H3: AGAIN comes after every Joker")
	eq(int(_item(res, "Clean Sweep, AGAIN").get("value", 0)), 50, "H3: AGAIN adds the effect once more")
	# H5: Legend Crate.
	r = main.run
	r.phase = BMRun.Phase.ROUND_RESULT # setup: straight back to a shop
	r._open_shop()
	r.jokers.assign(["clean_sweep", "small_change", "heavy_hand", "first_strike", "neat_freak"])
	r.joker_mods = []
	r.credits = 99
	r.shop.holo = [{"id": "legend_crate", "joker": "supernova"}, {}]
	r = await _load(r)
	check(not main.shop_screen._act({"a": "buy_holo", "i": 0}).get("ok", true), "H5: Legend Crate needs a free slot")
	r = main.run
	r.jokers.remove_at(4) # setup: free a slot
	r.joker_mods = []
	var lc: Dictionary = main.shop_screen._act({"a": "buy_holo", "i": 0})
	check(lc.get("ok", false) and main.run.jokers.has("supernova"), "H5: the Legendary joins the rack")
	r = main.run
	r.credits = 99
	r.shop.holo = [{"id": "legend_crate", "joker": "supernova"}, {}]
	check(not main.shop_screen._act({"a": "buy_holo", "i": 0}).get("ok", true), "H5: an owned Legendary is refused")
	var c2: BMRun = main.run.clone()
	for k in 60:
		var o: Dictionary = c2._roll_holo_offer([])
		if String(o.id) == "legend_crate":
			check(not c2.jokers.has(String(o.joker)), "H5: the shelf never offers an owned Legendary")
	facts["holo"] = {"negative": int(neg.get("index", -1)), "again": labels}
	main.abandon_run()
	await frames(2)


# --- Round cards and bosses ---------------------------------------------------------------

func _round_cards_and_bosses() -> void:
	# C1: numbers from the card texts. Round 3's target is 900 x1.15 (act 1 scale) = 1,040;
	# 15 placements.
	var cards := {
		"double_or_nothing": {"target": 1770, "reward": 7},
		"tight_budget": {"target": 1040, "reward": 5, "placements": 10},
		"gold_rush": {"target": 1040, "reward": 1},
		"rush_hour": {"target": 830, "reward": 3, "refreshes": 0},
		"mult_fever": {"target": 1560, "reward": 0},
		"treasure_hunt": {"target": 1400, "reward": 0},
		"scholarship": {"target": 1460, "reward": 0},
	}
	var got := {}
	for id in cards:
		var r: BMRun = await _fresh(SEED + 5)
		r = await _shop_at(r, 2)
		r.shop.round_cards = ["standard", id, "standard"] # setup
		main.shop_screen._show_round_picker()
		await frames(1)
		main.shop_screen._pick_round_and_go(1)
		await frames(3)
		main.game_screen.close_overlay()
		r = main.run
		var want: Dictionary = cards[id]
		eq(r.round_card, id, "C1: %s picked" % id)
		eq(r.round_state.target, int(want.target), "C1: %s target" % id)
		if want.has("placements"):
			eq(r.round_state.placements_left, int(want.placements), "C1: %s placements" % id)
		if want.has("refreshes"):
			eq(r.refreshes_available(), int(want.refreshes), "C1: %s Refreshes" % id)
		r.round_state.score = r.round_state.target - 1 # setup: one placement from the win
		r = await _load(r)
		var mv := _any_move(r)
		main.game_screen._do_action({"a": "place", "slot": int(mv.slot), "x": mv.anchor.x, "y": mv.anchor.y})
		await frames(2)
		var bonus := 0
		for l in main.run.last_round_result.get("credit_lines", []):
			if String(l.label) == "%s bonus" % BMRoundCards.get_def(id).name:
				bonus = int(l.value)
		eq(bonus, int(want.reward), "C1: %s pays +%d" % [id, int(want.reward)])
		got[id] = [r.round_state.target, bonus]
		main.abandon_run()
		await frames(1)
	# B1: act bosses x1.15, the final boss and Overtime unchanged.
	var b: BMRun = await _fresh(SEED + 6)
	# Rounds 3+ carry their act's scale (x1.15 / x1.35 / x1.55); act bosses add x1.15.
	eq(b.round_target(4), 1590, "B1: round 4 boss 1,200 x1.15 (act) x1.15 (boss)")
	eq(b.round_target(8), 6830, "B1: round 8 boss 4,400 x1.35 (act) x1.15 (boss)")
	eq(b.round_target(12), 19380, "B1: the final boss gets only its act scale (12,500 x1.55)")
	eq(b.round_target(3), 1040, "B1: a normal round gets its act scale only")
	eq(b.round_target(16), BMRunConfig.target(16), "B1: Overtime bosses get no boss bump")
	facts["cards"] = got
	main.abandon_run()
	await frames(2)


# --- Color and form Jokers ----------------------------------------------------------------

static func _count_color(r: BMRun, color: int) -> int:
	var n := 0
	for p in r.bag:
		if int(p.color) == color or String(p.get("material", "")) == "prism":
			n += 1
	return n


## Setup: turns the tray piece in `slot` (and its bag piece) into color `color`, like Repaint.
static func _paint(r: BMRun, slot: int, color: int) -> void:
	r.tray[slot].color = color
	BMBag.piece_by_uid(r, int(r.tray[slot].uid)).color = color


func _color_and_form_jokers() -> void:
	var r: BMRun = await _fresh(SEED + 9)
	r.jokers.assign(["red_alert", "red_giant", "barbell", "tee_time"]) # setup
	r.board = BMBoard.new()
	deal_family(r, 0, "bar3")
	_paint(r, 0, BMShapes.COLOR_RED)
	r = await _load(r)
	var reds := _count_color(r, BMShapes.COLOR_RED)
	var bars := 0
	for p in r.bag:
		if BMShapes.form(p.family) == "bar":
			bars += 1
	var res := await _place(0, Vector2i(0, 0), "J1")
	eq(float(_item(res, "Red Alert").get("value", 0.0)), 2.0, "J1: Red Alert gives a Red shape +2 Mult")
	eq(float(_item(res, "Red Giant").get("value", 0.0)), minf(3.0, 1.0 + 0.15 * reds), "J2: Red Giant is x1 + 0.15 per Red piece (%d)" % reds)
	eq(float(_item(res, "Barbell").get("value", 0.0)), minf(3.0, 1.0 + 0.1 * bars), "J3: Barbell counts every Bar (%d)" % bars)
	check(_item(res, "Tee Time").is_empty(), "J3: Tee Time ignores a Bar")
	# J1: a Blue piece gets nothing from Red cards; a Prism piece counts as Red.
	r = main.run
	r.board = BMBoard.new()
	deal_family(r, 1, "l3")
	_paint(r, 1, BMShapes.COLOR_BLUE)
	r = await _load(r)
	res = await _place(1, Vector2i(0, 4), "J1 blue")
	check(_item(res, "Red Alert").is_empty() and _item(res, "Red Giant").is_empty(), "J1: Red cards ignore a Blue shape")
	r = main.run
	r.board = BMBoard.new()
	deal_family(r, 2, "l4")
	_paint(r, 2, BMShapes.COLOR_BLUE)
	r.tray[2].material = "prism"
	BMBag.piece_by_uid(r, int(r.tray[2].uid)).material = "prism"
	r = await _load(r)
	res = await _place(2, Vector2i(4, 4), "J1 prism")
	check(not _item(res, "Red Alert").is_empty(), "J1: a Prism piece counts as Red")
	# J2: Repaint in the shop grows Red Giant.
	r = main.run
	var before := _count_color(r, BMShapes.COLOR_RED)
	r = await _shop_at(r, 1)
	r.credits = 99
	r.shop.tools = [{"id": "repaint", "family": ""}, {}]
	var targets: Array = []
	for p in r.bag:
		if int(p.color) != BMShapes.COLOR_RED and String(p.material) != "prism" and targets.size() < 3:
			targets.append(int(p.uid))
	var rp: Dictionary = main.shop_screen._act({"a": "buy_tool", "i": 0, "targets": targets, "color": BMShapes.COLOR_RED})
	check(rp.get("ok", false), "J2: Repaint three pieces Red")
	eq(_count_color(main.run, BMShapes.COLOR_RED), before + 3, "J2: three more Red pieces")
	var ctx := {"color": BMShapes.COLOR_RED, "prism": false, "family": &"bar3", "bag_colors": BMBag.color_counts(main.run), "bag_forms": BMBag.form_counts(main.run)}
	eq(BMJokers.x_mult("red_giant", ctx), minf(3.0, 1.0 + 0.15 * (before + 3)), "J2: Red Giant grows with the Repaint")
	# J4: The Color Blind.
	r = main.run
	r.bosses[0] = "color_blind"
	r.round_number = 4
	r.round_card = "standard"
	r._start_round() # setup
	r.board = BMBoard.new()
	deal_family(r, 0, "bar3")
	_paint(r, 0, BMShapes.COLOR_RED)
	r = await _load(r)
	res = await _place(0, Vector2i(0, 0), "J4")
	check(_item(res, "Red Alert").is_empty() and _item(res, "Red Giant").is_empty(), "J4: the Color Blind switches Red cards off")
	check(not _item(res, "Barbell").is_empty(), "J4: form cards still work under the Color Blind")
	facts["palette"] = {"reds": reds, "bars": bars, "after_repaint": before + 3}
	main.abandon_run()
	await frames(2)
	# H6: Holo prices rise; trait caps hold.
	r = await _fresh(SEED + 10)
	r = await _shop_at(r, 9)
	var prices: Array = []
	for k in 3:
		r = main.run
		r.credits = 99
		r.jokers.assign(["clean_sweep", "small_change", "heavy_hand", "first_strike", "neat_freak"])
		r.joker_mods = []
		r.shop.holo = [{"id": "master_schematic", "joker": ""}, {}]
		prices.append(r.holo_price(r.shop.holo[0]))
		check(main.shop_screen._act({"a": "buy_holo", "i": 0}).get("ok", false), "H6: Master Schematic %d bought" % (k + 1))
	eq(prices, [12, 18, 24], "H6: each purchase adds half the base price")
	var negs := 0
	for k in 4:
		r = main.run
		r.credits = 99
		r.holo_bought.erase("negative_film") # setup: keep the price flat, test the cap
		r.shop.holo = [{"id": "negative_film", "joker": ""}, {}]
		if main.shop_screen._act({"a": "buy_holo", "i": 0}).get("ok", false):
			negs += 1
	eq(negs, BMHolo.MAX_NEGATIVE, "H6: at most three Negative Jokers")
	facts["holo_prices"] = prices
	main.abandon_run()
	await frames(2)


# --- Dead trays ---------------------------------------------------------------------------

func _dead_trays() -> void:
	var r: BMRun = await _fresh(SEED + 7)
	# Setup: isolated one-block holes (two per row and column: no line can complete), a Single
	# in slot 1, the other slots empty, and the draw pile's next three pieces all too big.
	for y in BMBoard.SIZE:
		for x in BMBoard.SIZE:
			var hole := x == (3 * y) % 8 or x == (3 * y + 4) % 8
			r.board.set_cell(Vector2i(x, y), BMBoard.EMPTY if hole else (x + y) % BMShapes.OFFER_COLOR_COUNT)
	for s in 3:
		if not r.tray[s].is_empty():
			r.draw_pile.append(int(r.tray[s].uid))
			r.tray[s] = {}
	deal_family(r, 0, "single")
	var big: Array = []
	var small: Array = []
	for uid in r.draw_pile:
		var p := BMBag.piece_by_uid(r, int(uid))
		(small if String(p.family) == "single" else big).append(int(uid))
	r.draw_pile.assign(big + small)
	var next_three := big.slice(0, 3)
	var rescued := r.round_state.rescued_deals
	r = await _load(r)
	check(bag_accounted(r), "setup keeps every piece in one place")
	var anchors := r.board.legal_anchors(r.tray[0].cells)
	main.game_screen._do_action({"a": "place", "slot": 0, "x": anchors[0].x, "y": anchors[0].y})
	await frames(2)
	r = main.run
	var dealt: Array = []
	for p in r.tray:
		dealt.append(int(p.get("uid", -1)))
	eq(dealt, next_three, "N1: the refilled tray is dealt as drawn")
	eq(r.round_state.rescued_deals, rescued, "N1: no piece was swapped in")
	eq(r.round_state.status, BMRun.STUCK, "N2: a dead tray with a Refresh left is STUCK")
	await screenshot("dead_tray")
	# N3: the Refresh is guaranteed.
	main.game_screen._do_action({"a": "refresh"})
	await frames(2)
	r = main.run
	check(has_legal_move(r), "N3: a Refresh always deals a playable tray")
	# N2: with no Refresh and no rescue, a dead tray ends the round.
	var mv := _any_move(r)
	var s: int = mv.slot
	for i in 3:
		if i != s and not r.tray[i].is_empty():
			r.draw_pile.append(int(r.tray[i].uid)) # setup: only the playable piece stays
			r.tray[i] = {}
	var big2: Array = []
	var small2: Array = []
	for uid in r.draw_pile + r.discard_pile:
		var p := BMBag.piece_by_uid(r, int(uid))
		(small2 if String(p.family) == "single" else big2).append(int(uid))
	r.discard_pile = []
	r.draw_pile.assign(big2 + small2)
	r = await _load(r)
	# A hole whose row and column keep another hole, so no line clears and frees room.
	var at: Vector2i = mv.anchor
	for a in r.board.legal_anchors(r.tray[s].cells):
		if _gaps(r.board, a) >= 2:
			at = a
			break
	main.game_screen._do_action({"a": "place", "slot": s, "x": at.x, "y": at.y})
	await frames(2)
	r = main.run
	eq(r.phase, BMRun.Phase.RUN_LOST, "N2: no room and no rescue loses the round")
	eq(r.end_reason, "No offered shape fits and no rescue remains.", "N2: the loss says why")
	facts["dead_tray"] = {"dealt": dealt, "phase": r.phase}
	await frames(2)


# --- Saves --------------------------------------------------------------------------------

func _old_save_loads() -> void:
	var r: BMRun = await _fresh(SEED + 8)
	r.jokers.assign(["hoarder"])
	var d := r.to_dict()
	# A schema-8 save: none of the fields this update added.
	d.erase("joker_mods")
	d.erase("extra_item_slots")
	d.rng.erase("items")
	d.round_state.erase("pending_lines")
	var f := FileAccess.open(BMSaveStore.run_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": 8, "run": d}))
	f.close()
	main.continue_run()
	await frames(3)
	main.game_screen.close_overlay()
	r = main.run
	check(r != null and r.jokers.has("hoarder"), "V1: a schema-8 save loads")
	eq(r.joker_mods.size(), r.jokers.size(), "V1: Joker traits are padded to the rack")
	eq(r.consumable_slots(), BMRunConfig.CONSUMABLE_SLOTS, "V1: two item slots")
	check(r.rng_items != null, "V1: the item stream starts from the seed")
	var mv := _any_move(r)
	var res: Dictionary = main.game_screen._do_action({"a": "place", "slot": int(mv.slot), "x": mv.anchor.x, "y": mv.anchor.y})
	check(res.get("ok", false), "V1: the old save plays on")
	main.abandon_run()
	await frames(2)
