class_name BMRun
extends RefCounted
## Complete run state plus every player command. No nodes, no rendering, no timing.
## Each command validates, mutates state atomically, appends itself to `history`, and returns
## a result Dictionary ({ok: bool, error: String, ...}). Seed + history replays a run exactly.
## to_dict()/from_dict() capture a complete state between actions (saves, previews, tests).

const SCHEMA_VERSION := 1

enum Phase { ROUND, ROUND_RESULT, SHOP, RUN_WON, RUN_LOST, ABANDONED }

## Round status inside Phase.ROUND.
const PLAYING := "playing"
const STUCK := "stuck" ## No offered shape fits, but a rescue (Refresh or consumable) exists.
const OUT_OF_PLACEMENTS := "out_of_placements" ## Target unmet, but an Extra Turn is owned.
const WON := "won"
const LOST := "lost"

const PHASE_NAMES := ["round", "round_result", "shop", "run_won", "run_lost", "abandoned"]


class RoundState:
	var target := 0
	var score := 0
	var placements_left := 0
	var refreshes_left := 0
	var combo := 0
	var placements_made := 0
	var clearing_placements := 0
	var color_history: Array = []
	var first_refresh_done := false
	var tiny_insurance_used := false
	var mirror_used := false
	var pending_chips := 0
	var pending_mult := 0.0
	var cash_out := 0
	var status := PLAYING
	var fixed_cells: Array[Vector2i] = []

	func to_dict() -> Dictionary:
		var fixed: Array = []
		for p in fixed_cells:
			fixed.append([p.x, p.y])
		return {
			"target": target, "score": score, "placements_left": placements_left,
			"refreshes_left": refreshes_left, "combo": combo, "placements_made": placements_made,
			"clearing_placements": clearing_placements, "color_history": color_history.duplicate(),
			"first_refresh_done": first_refresh_done, "tiny_insurance_used": tiny_insurance_used,
			"mirror_used": mirror_used, "pending_chips": pending_chips, "pending_mult": pending_mult,
			"cash_out": cash_out, "status": status, "fixed_cells": fixed,
		}

	static func from_dict(d: Dictionary) -> RoundState:
		var r := RoundState.new()
		r.target = int(d.target)
		r.score = int(d.score)
		r.placements_left = int(d.placements_left)
		r.refreshes_left = int(d.refreshes_left)
		r.combo = int(d.combo)
		r.placements_made = int(d.placements_made)
		r.clearing_placements = int(d.clearing_placements)
		r.color_history = []
		for c in d.color_history:
			r.color_history.append(int(c))
		r.first_refresh_done = bool(d.first_refresh_done)
		r.tiny_insurance_used = bool(d.tiny_insurance_used)
		r.mirror_used = bool(d.mirror_used)
		r.pending_chips = int(d.pending_chips)
		r.pending_mult = float(d.pending_mult)
		r.cash_out = int(d.cash_out)
		r.status = String(d.status)
		for p in d.fixed_cells:
			r.fixed_cells.append(Vector2i(int(p[0]), int(p[1])))
		return r


var run_seed := 0
var kit_id := "standard"
var rng_shapes: BMRngStream
var rng_shop: BMRngStream
var rng_boss: BMRngStream
var phase: int = Phase.ROUND
var round_number := 1
var credits := 0
var jokers: Array[String] = []
var consumables: Array[String] = []
var jokers_sold := 0
var bosses: Array[String] = []
var board := BMBoard.new()
var tray: Array = [{}, {}, {}]
var last_tray_signature := ""
var rejected_draws := 0
var round_state := RoundState.new()
var shop := {}
var history: Array = []
var stats := {}
var last_round_result := {}
var end_reason := ""


# --- Construction ------------------------------------------------------------------------

static func new_run(seed_value: int, kit: String = "standard") -> BMRun:
	var run := BMRun.new()
	run.run_seed = seed_value
	run.kit_id = BMRunConfig.kit(kit).id
	run.rng_shapes = BMRngStream.new(seed_value, "shapes")
	run.rng_shop = BMRngStream.new(seed_value, "shop")
	run.rng_boss = BMRngStream.new(seed_value, "boss")
	run.credits = int(BMRunConfig.kit(run.kit_id).credits)
	run.bosses = BMBosses.choose_run_bosses(run.rng_boss)
	run.stats = {"lines_cleared": 0, "placements": 0, "total_points": 0, "best_placement": 0,
		"highest_combo": 0, "triple_clears": 0, "rounds_won": 0, "jokers_bought": 0, "refreshes": 0}
	run._start_round()
	return run


## Rebuilds a run from its seed, Kit, and action history. Used by replay tests and debugging.
static func replay(seed_value: int, kit: String, actions: Array) -> BMRun:
	var run := BMRun.new_run(seed_value, kit)
	for a in actions:
		var r := run.apply_action(a)
		if not r.ok:
			push_error("Replay diverged at %s: %s" % [a, r.error])
			break
	return run


static func random_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(1, 999_999_999)


func clone() -> BMRun:
	return BMRun.from_dict(to_dict())


# --- Queries -------------------------------------------------------------------------------

func kit() -> Dictionary:
	return BMRunConfig.kit(kit_id)


func joker_slots() -> int:
	return int(kit().joker_slots)


func act() -> int:
	return BMRunConfig.act_of(round_number)


func current_boss() -> String:
	if phase != Phase.SHOP and BMRunConfig.is_boss_round(round_number):
		return bosses[act() - 1]
	return ""


## The boss of the current act (revealed at act start), whether or not this is its round.
func act_boss() -> String:
	return bosses[act() - 1]


func boss_active(id: String) -> bool:
	return phase == Phase.ROUND and current_boss() == id


func has_active_joker(id: String) -> bool:
	return jokers.has(id) and is_joker_active(id)


func is_joker_active(id: String) -> bool:
	return joker_disabled_reason(id) == ""


func joker_disabled_reason(id: String) -> String:
	if BMJokers.is_color_dependent(id) and current_boss() == "color_blind":
		return "Disabled by The Color Blind: color effects are off this round."
	return ""


func refreshes_available() -> int:
	if current_boss() == "lockdown":
		return 0
	return round_state.refreshes_left


func can_act_in_round() -> bool:
	return phase == Phase.ROUND and round_state.status in [PLAYING, STUCK, OUT_OF_PLACEMENTS]


func can_place() -> bool:
	return phase == Phase.ROUND and round_state.status == PLAYING and round_state.placements_left > 0


func is_legal(slot: int, anchor: Vector2i) -> bool:
	if slot < 0 or slot >= tray.size() or tray[slot].is_empty():
		return false
	return board.can_place(tray[slot].cells, anchor)


func slot_fits(slot: int) -> bool:
	return slot >= 0 and slot < tray.size() and not tray[slot].is_empty() and board.fits_anywhere(tray[slot].cells)


func tray_is_empty() -> bool:
	for s in tray:
		if not s.is_empty():
			return false
	return true


func consumable_usable(index: int) -> String:
	## Returns "" when usable, otherwise the reason.
	if index < 0 or index >= consumables.size():
		return "No item in that slot."
	if not can_act_in_round():
		return "Items can be used during a round, between placements."
	var id := consumables[index]
	match id:
		"second_tray":
			if current_boss() == "lockdown":
				return "The Lockdown disables tray refreshes."
			if tray_is_empty():
				return "The tray is empty."
		"extra_turn":
			if round_state.placements_left >= BMConsumables.MAX_PLACEMENTS:
				return "Already at %d placements." % BMConsumables.MAX_PLACEMENTS
		"polish", "spark", "cash_out":
			pass
		_:
			if not BMConsumables.is_implemented(id):
				return "Not usable yet in this build."
	if round_state.status == OUT_OF_PLACEMENTS and id != "extra_turn":
		return "Only Extra Turn helps when placements are spent."
	return ""


## Score preview: resolves the placement on a disposable copy of the run.
func preview_place(slot: int, anchor: Vector2i) -> Dictionary:
	if not can_place() or not is_legal(slot, anchor):
		return {"ok": false}
	var copy := clone()
	return BMResolver.resolve_placement(copy, slot, anchor)


# --- Round commands ------------------------------------------------------------------------

func apply_action(a: Dictionary) -> Dictionary:
	match String(a.get("a", "")):
		"place":
			return place(int(a.slot), Vector2i(int(a.x), int(a.y)))
		"refresh":
			return refresh()
		"use":
			return use_consumable(int(a.i))
		"concede":
			return concede_round()
		"continue":
			return continue_after_round()
		"buy_joker":
			return buy_joker(int(a.i))
		"buy_consumable":
			return buy_consumable(int(a.i))
		"reroll":
			return reroll_shop()
		"sell":
			return sell_joker(int(a.i))
		"move":
			return move_joker(int(a.from), int(a.to))
		"leave_shop":
			return leave_shop()
		"abandon":
			return abandon()
	return _fail("Unknown action %s" % a)


func place(slot: int, anchor: Vector2i) -> Dictionary:
	if not can_place():
		return _fail("Cannot place right now.")
	if slot < 0 or slot >= tray.size() or tray[slot].is_empty():
		return _fail("That tray slot is empty.")
	if not board.can_place(tray[slot].cells, anchor):
		return _fail("The shape does not fit there.")
	var result := BMResolver.resolve_placement(self, slot, anchor)
	history.append({"a": "place", "slot": slot, "x": anchor.x, "y": anchor.y})
	result.merge(_after_round_action(), true)
	return result


func refresh() -> Dictionary:
	if not can_act_in_round() or round_state.status == OUT_OF_PLACEMENTS:
		return _fail("Cannot refresh right now.")
	if current_boss() == "lockdown":
		return _fail("The Lockdown disables Refresh this round.")
	if round_state.refreshes_left <= 0:
		return _fail("No Refresh left this round.")
	if tray_is_empty():
		return _fail("The tray is empty.")
	round_state.refreshes_left -= 1
	var result := _do_tray_refresh("Refresh")
	history.append({"a": "refresh"})
	result.merge(_after_round_action(), true)
	return result


func use_consumable(index: int) -> Dictionary:
	var reason := consumable_usable(index)
	if reason != "":
		return _fail(reason)
	var id := consumables[index]
	consumables.remove_at(index)
	var result := {"ok": true, "type": "use", "item": id, "events": []}
	match id:
		"polish":
			round_state.pending_chips += 100
		"spark":
			round_state.pending_mult += 1.0
		"second_tray":
			result.merge(_do_tray_refresh("Second Tray"), true)
			result.type = "use"
			result.item = id
		"extra_turn":
			round_state.placements_left = mini(BMConsumables.MAX_PLACEMENTS, round_state.placements_left + 2)
			if round_state.status == OUT_OF_PLACEMENTS:
				round_state.status = PLAYING
		"cash_out":
			round_state.cash_out += 1
	history.append({"a": "use", "i": index})
	result.merge(_after_round_action(), true)
	return result


func concede_round() -> Dictionary:
	if not (phase == Phase.ROUND and round_state.status in [STUCK, OUT_OF_PLACEMENTS]):
		return _fail("You can only concede when stuck.")
	history.append({"a": "concede"})
	_lose("Conceded: no legal placement remained." if round_state.status == STUCK else "Conceded: out of placements.")
	return {"ok": true, "type": "concede", "phase": phase}


func abandon() -> Dictionary:
	if phase in [Phase.RUN_WON, Phase.RUN_LOST, Phase.ABANDONED]:
		return _fail("The run is already over.")
	history.append({"a": "abandon"})
	phase = Phase.ABANDONED
	end_reason = "Run abandoned."
	return {"ok": true, "type": "abandon"}


func continue_after_round() -> Dictionary:
	if phase != Phase.ROUND_RESULT:
		return _fail("No round result to continue from.")
	history.append({"a": "continue"})
	if round_number >= BMRunConfig.ROUND_COUNT:
		phase = Phase.RUN_WON
		end_reason = "All %d rounds cleared!" % BMRunConfig.ROUND_COUNT
		return {"ok": true, "type": "continue", "phase": phase}
	_open_shop()
	return {"ok": true, "type": "continue", "phase": phase}


# --- Shop commands -------------------------------------------------------------------------

func buy_joker(offer: int) -> Dictionary:
	if phase != Phase.SHOP:
		return _fail("The shop is closed.")
	if offer < 0 or offer >= shop.jokers.size() or shop.jokers[offer] == "":
		return _fail("That offer is gone.")
	var id: String = shop.jokers[offer]
	var price := BMJokers.cost(id)
	if credits < price:
		return _fail("Not enough Credits.")
	if jokers.size() >= joker_slots():
		return _fail("Joker slots are full. Sell a Joker first.")
	credits -= price
	jokers.append(id)
	shop.jokers[offer] = ""
	stats.jokers_bought += 1
	history.append({"a": "buy_joker", "i": offer})
	return {"ok": true, "type": "buy_joker", "item": id, "price": price}


func buy_consumable(offer: int) -> Dictionary:
	if phase != Phase.SHOP:
		return _fail("The shop is closed.")
	if offer < 0 or offer >= shop.consumables.size() or shop.consumables[offer] == "":
		return _fail("That offer is gone.")
	var id: String = shop.consumables[offer]
	var price := BMConsumables.cost(id)
	if credits < price:
		return _fail("Not enough Credits.")
	if consumables.size() >= BMRunConfig.CONSUMABLE_SLOTS:
		return _fail("Item slots are full. Use an item first.")
	credits -= price
	consumables.append(id)
	shop.consumables[offer] = ""
	history.append({"a": "buy_consumable", "i": offer})
	return {"ok": true, "type": "buy_consumable", "item": id, "price": price}


func reroll_shop() -> Dictionary:
	if phase != Phase.SHOP:
		return _fail("The shop is closed.")
	var price: int = shop.reroll_cost
	if credits < price:
		return _fail("Not enough Credits.")
	credits -= price
	shop.reroll_cost = price + 1
	_fill_shop_offers()
	history.append({"a": "reroll"})
	return {"ok": true, "type": "reroll", "price": price}


func sell_joker(index: int) -> Dictionary:
	if not (phase == Phase.SHOP or can_act_in_round()):
		return _fail("Jokers can be sold in the shop or between placements.")
	if index < 0 or index >= jokers.size():
		return _fail("No Joker in that slot.")
	var id := jokers[index]
	var value := BMJokers.sell_value(id)
	jokers.remove_at(index)
	credits = mini(BMRunConfig.CREDIT_CAP, credits + value)
	jokers_sold += 1
	history.append({"a": "sell", "i": index})
	var result := {"ok": true, "type": "sell", "item": id, "value": value}
	if phase == Phase.ROUND:
		result.merge(_after_round_action(), true)
	return result


func move_joker(from: int, to: int) -> Dictionary:
	if not (phase == Phase.SHOP or can_act_in_round()):
		return _fail("Jokers can be reordered in the shop or between placements.")
	if from < 0 or from >= jokers.size() or to < 0 or to >= jokers.size() or from == to:
		return _fail("Invalid Joker move.")
	var id := jokers[from]
	jokers.remove_at(from)
	jokers.insert(to, id)
	history.append({"a": "move", "from": from, "to": to})
	return {"ok": true, "type": "move"}


func leave_shop() -> Dictionary:
	if phase != Phase.SHOP:
		return _fail("The shop is closed.")
	history.append({"a": "leave_shop"})
	round_number += 1
	_start_round()
	return {"ok": true, "type": "leave_shop"}


# --- Internals -----------------------------------------------------------------------------

func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg}


func _start_round() -> void:
	phase = Phase.ROUND
	board = BMBoard.new()
	var rs := RoundState.new()
	rs.target = BMRunConfig.target(round_number)
	rs.placements_left = int(kit().placements)
	rs.refreshes_left = int(kit().refreshes)
	var boss := current_boss()
	if boss == "last_call":
		rs.placements_left = BMBosses.LAST_CALL_PLACEMENTS
	rs.placements_left += jokers.count("long_game")
	if boss == "cramped_cabinet":
		rs.fixed_cells = BMBosses.cramped_cells(rng_boss)
		for p in rs.fixed_cells:
			board.set_cell(p, BMShapes.COLOR_STONE)
	round_state = rs
	tray = [{}, {}, {}]
	_deal_fresh_tray()


func _deal_fresh_tray() -> void:
	var dealt := BMTrayGenerator.deal(rng_shapes, board, round_number, 3, last_tray_signature)
	tray = dealt.shapes.duplicate()
	rejected_draws += int(dealt.rejected)
	last_tray_signature = BMTrayGenerator.signature_of(tray)


func _do_tray_refresh(label: String) -> Dictionary:
	var slots: Array[int] = []
	var old: Array = []
	for i in tray.size():
		if not tray[i].is_empty():
			slots.append(i)
			old.append(tray[i])
	var dealt := BMTrayGenerator.deal(rng_shapes, board, round_number, slots.size(), BMTrayGenerator.signature_of(old))
	rejected_draws += int(dealt.rejected)
	for k in slots.size():
		tray[slots[k]] = dealt.shapes[k]
	var events: Array = [label]
	if not round_state.first_refresh_done:
		round_state.first_refresh_done = true
		var bonus := jokers.count("second_look")
		if bonus > 0:
			round_state.placements_left += bonus
			events.append("Second Look: +%d placement" % bonus)
	stats.refreshes += 1
	if round_state.status == STUCK:
		round_state.status = PLAYING
	return {"ok": true, "type": "refresh", "events": events}


## Win/loss/stuck evaluation after any round action. Order: target first (a crossing
## placement always wins), then tray refill, then placements, then legality and rescues.
func _after_round_action() -> Dictionary:
	var events: Array = []
	var rs := round_state
	if phase != Phase.ROUND:
		return {}
	if rs.score >= rs.target:
		_win_round()
		return {"round_won": true, "phase": phase}
	if tray_is_empty():
		_deal_fresh_tray()
		events.append("New tray")
	if rs.placements_left <= 0:
		if consumables.has("extra_turn"):
			rs.status = OUT_OF_PLACEMENTS
		else:
			_lose("Out of placements: %d / %d points." % [rs.score, rs.target])
		return {"status": rs.status, "phase": phase, "tray_events": events}
	var any_fit := false
	for i in tray.size():
		if slot_fits(i):
			any_fit = true
			break
	if any_fit:
		rs.status = PLAYING
	elif refreshes_available() > 0:
		rs.status = STUCK
	elif has_active_joker("tiny_insurance") and not rs.tiny_insurance_used and board.empty_count() > 0:
		rs.tiny_insurance_used = true
		for i in tray.size():
			if not tray[i].is_empty():
				tray[i] = BMShapes.make_shape(&"single", 0, int(tray[i].color))
				break
		rs.status = PLAYING
		events.append("Tiny Insurance: a Single replaced a stuck shape")
	elif _has_rescue_consumable():
		rs.status = STUCK
	else:
		_lose("No offered shape fits and no rescue remains.")
	return {"status": rs.status, "phase": phase, "tray_events": events}


func _has_rescue_consumable() -> bool:
	for id in consumables:
		if id == "second_tray" and current_boss() != "lockdown":
			return true
		if id in ["eraser", "blueprint"] and BMConsumables.is_implemented(id):
			return true
	return false


func _win_round() -> void:
	var rs := round_state
	rs.status = WON
	var unused := maxi(0, rs.placements_left)
	var lines: Array = []
	lines.append({"label": "Round won", "value": BMRunConfig.WIN_CREDITS})
	var bonus := mini(BMRunConfig.UNUSED_PLACEMENT_BONUS_CAP, unused / 2)
	if bonus > 0:
		lines.append({"label": "Unused placements (%d)" % unused, "value": bonus})
	if BMRunConfig.is_boss_round(round_number):
		lines.append({"label": "Boss defeated", "value": BMRunConfig.BOSS_CREDITS})
	if unused >= 3:
		for i in jokers.count("spare_parts"):
			lines.append({"label": "Spare Parts", "value": BMRunConfig.SPARE_PARTS_CREDITS})
	for i in rs.cash_out:
		lines.append({"label": "Cash Out", "value": BMRunConfig.CASH_OUT_CREDITS})
	var total := 0
	for l in lines:
		total += int(l.value)
	var before := credits
	credits = mini(BMRunConfig.CREDIT_CAP, credits + total)
	stats.rounds_won += 1
	last_round_result = {"round": round_number, "score": rs.score, "target": rs.target,
		"unused": unused, "credit_lines": lines, "credits_gained": credits - before,
		"boss": current_boss()}
	phase = Phase.ROUND_RESULT


func _lose(reason: String) -> void:
	round_state.status = LOST
	phase = Phase.RUN_LOST
	end_reason = reason


func _open_shop() -> void:
	phase = Phase.SHOP
	shop = {"jokers": [], "consumables": [], "reroll_cost": BMRunConfig.REROLL_BASE}
	_fill_shop_offers()


func _fill_shop_offers() -> void:
	var next_act := BMRunConfig.act_of(round_number + 1)
	var weights: Array = BMRunConfig.RARITY_WEIGHTS[next_act - 1]
	var offered: Array[String] = []
	for i in BMRunConfig.JOKER_OFFERS:
		var rarity := rng_shop.weighted_index(weights)
		var pick := _pick_joker(rarity, offered)
		if pick == "":
			for r in [BMJokers.COMMON, BMJokers.UNCOMMON, BMJokers.RARE]:
				pick = _pick_joker(r, offered)
				if pick != "":
					break
		offered.append(pick)
	shop.jokers = offered
	var pool := BMConsumables.shop_pool()
	var items: Array[String] = []
	for i in BMRunConfig.CONSUMABLE_OFFERS:
		if pool.is_empty():
			items.append("")
			continue
		var idx := rng_shop.randi_range(0, pool.size() - 1)
		items.append(pool[idx])
		pool.remove_at(idx)
	shop.consumables = items


func _pick_joker(rarity: int, exclude: Array[String]) -> String:
	var candidates: Array[String] = []
	for id in BMJokers.ids_of_rarity(rarity):
		if exclude.has(id):
			continue
		if BMJokers.is_unique(id) and jokers.has(id):
			continue
		candidates.append(id)
	if candidates.is_empty():
		return ""
	return candidates[rng_shop.randi_range(0, candidates.size() - 1)]


# --- Serialization -------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var tray_data: Array = []
	for s in tray:
		tray_data.append(BMShapes.shape_to_dict(s))
	return {
		"schema": SCHEMA_VERSION,
		"seed": run_seed, "kit": kit_id,
		"rng": {"shapes": rng_shapes.get_state(), "shop": rng_shop.get_state(), "boss": rng_boss.get_state()},
		"phase": PHASE_NAMES[phase], "round": round_number, "credits": credits,
		"jokers": jokers.duplicate(), "consumables": consumables.duplicate(), "jokers_sold": jokers_sold,
		"bosses": bosses.duplicate(), "board": board.to_array(), "tray": tray_data,
		"last_tray_signature": last_tray_signature, "rejected_draws": rejected_draws,
		"round_state": round_state.to_dict(), "shop": shop.duplicate(true),
		"history": history.duplicate(true), "stats": stats.duplicate(),
		"last_round_result": last_round_result.duplicate(true), "end_reason": end_reason,
	}


static func from_dict(d: Dictionary) -> BMRun:
	var run := BMRun.new()
	run.run_seed = int(d.seed)
	run.kit_id = String(d.kit)
	run.rng_shapes = BMRngStream.new()
	run.rng_shapes.set_state(d.rng.shapes)
	run.rng_shop = BMRngStream.new()
	run.rng_shop.set_state(d.rng.shop)
	run.rng_boss = BMRngStream.new()
	run.rng_boss.set_state(d.rng.boss)
	run.phase = PHASE_NAMES.find(String(d.phase))
	run.round_number = int(d.round)
	run.credits = int(d.credits)
	run.jokers.assign(d.jokers)
	run.consumables.assign(d.consumables)
	run.jokers_sold = int(d.jokers_sold)
	run.bosses.assign(d.bosses)
	run.board = BMBoard.from_array(d.board)
	run.tray = []
	for s in d.tray:
		run.tray.append(BMShapes.shape_from_dict(s))
	run.last_tray_signature = String(d.last_tray_signature)
	run.rejected_draws = int(d.rejected_draws)
	run.round_state = RoundState.from_dict(d.round_state)
	run.shop = _integral(d.shop.duplicate(true))
	run.history = _integral(d.history.duplicate(true))
	run.stats = {}
	for k in d.stats:
		run.stats[k] = int(d.stats[k])
	run.last_round_result = _integral(d.last_round_result.duplicate(true))
	run.end_reason = String(d.end_reason)
	return run


## JSON turns every number into a float; restore whole numbers to int in nested data.
static func _integral(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if is_equal_approx(v, roundf(v)) else v
		TYPE_ARRAY:
			var out: Array = []
			for e in v:
				out.append(_integral(e))
			return out
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[k] = _integral(v[k])
			return out
	return v
