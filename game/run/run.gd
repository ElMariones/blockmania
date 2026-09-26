class_name BMRun
extends RefCounted
## Complete run state plus every player command. No nodes, no rendering, no timing.
## Each command validates, mutates state atomically, appends itself to `history`, and returns
## a result Dictionary ({ok: bool, error: String, ...}). Seed + history replays a run exactly.
## to_dict()/from_dict() capture a complete state between actions (saves, previews, tests).

const SCHEMA_VERSION := 9

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
	var placement_cap := 0 ## Line clears refill placements up to this starting count.
	var refreshes_left := 0
	var combo := 0
	var placements_made := 0
	var clearing_placements := 0
	var color_history: Array = []
	var first_refresh_done := false
	var tiny_insurance_used := false
	var mirror_used := false
	var patch_ready := false ## Patch Panel: a removal is available (after the first clear).
	var patch_used := false
	var pending_chips := 0
	var pending_mult := 0.0
	var cash_out := 0
	var status := PLAYING
	var fixed_cells: Array[Vector2i] = []
	var reshuffles := 0 ## Discard pile shuffled back into the draw pile.
	var rescued_deals := 0 ## Legality guarantee had to swap in a piece (or a temporary Single).
	var hands_formed := 0 ## Tray Hands formed this round.
	var size_history: Array = [] ## Cells of each placed piece (Countdown).
	var feats_seen: Array = [] ## Feat ids earned this round (Showboat).
	var patience_store := 0
	var overflow_paid := 0
	var insured := false ## This round is an Insurance Policy replay.
	var locked_slot := -1 ## The Warden: barred tray slot until the first clear.
	var combo_misses := 0 ## Non-clearing placements since the last clear (combo grace).
	var tombs: Array = [] ## The Undertaker: cells where tombstones rose ([x, y]).
	var pending_xmult := 1.0 ## Turbo item: xMult for the next placement.
	var held: Dictionary = {} ## Hold: a stored tray piece (not in any pile) or {}.
	var hold_used := false ## Hold was used since the last placement.
	var locked_slot2 := -1 ## The Warden Mk II: a second barred slot.
	var last_family := "" ## Family of the last placed piece (Scholarship).
	var start_board: Dictionary = {} ## Board at the round's start when it carried over (Insurance replays).
	var carried := false ## The board carried over from the last round of the act.
	var rubble := 0 ## Stone blocks dropped at the round's start.
	var lines_cleared := 0 ## Lines cleared this round (Supernova).
	var refresh_used := false ## A Refresh or Second Tray was used this round (Hot Streak).
	var pending_lines := 0 ## Phantom Line: extra lines for the next clearing placement.

	func to_dict() -> Dictionary:
		var fixed: Array = []
		for p in fixed_cells:
			fixed.append([p.x, p.y])
		return {
			"target": target, "score": score, "placements_left": placements_left, "placement_cap": placement_cap,
			"refreshes_left": refreshes_left, "combo": combo, "placements_made": placements_made,
			"clearing_placements": clearing_placements, "color_history": color_history.duplicate(),
			"first_refresh_done": first_refresh_done, "tiny_insurance_used": tiny_insurance_used,
			"mirror_used": mirror_used, "pending_chips": pending_chips, "pending_mult": pending_mult,
			"patch_ready": patch_ready, "patch_used": patch_used,
			"cash_out": cash_out, "status": status, "fixed_cells": fixed,
			"reshuffles": reshuffles, "rescued_deals": rescued_deals, "hands_formed": hands_formed,
			"size_history": size_history.duplicate(), "feats_seen": feats_seen.duplicate(),
			"patience_store": patience_store, "overflow_paid": overflow_paid, "insured": insured,
			"locked_slot": locked_slot, "tombs": tombs.duplicate(true), "combo_misses": combo_misses,
			"pending_xmult": pending_xmult, "lines_cleared": lines_cleared, "refresh_used": refresh_used,
			"held": BMPieces.to_dict(held), "hold_used": hold_used, "locked_slot2": locked_slot2,
			"last_family": last_family, "pending_lines": pending_lines, "start_board": start_board.duplicate(true),
			"carried": carried, "rubble": rubble,
		}

	static func from_dict(d: Dictionary) -> RoundState:
		var r := RoundState.new()
		r.target = int(d.target)
		r.score = int(d.score)
		r.placements_left = int(d.placements_left)
		r.placement_cap = int(d.get("placement_cap", r.placements_left))
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
		r.patch_ready = bool(d.get("patch_ready", false))
		r.patch_used = bool(d.get("patch_used", false))
		r.pending_chips = int(d.pending_chips)
		r.pending_mult = float(d.pending_mult)
		r.cash_out = int(d.cash_out)
		r.status = String(d.status)
		for p in d.fixed_cells:
			r.fixed_cells.append(Vector2i(int(p[0]), int(p[1])))
		r.reshuffles = int(d.get("reshuffles", 0))
		r.rescued_deals = int(d.get("rescued_deals", 0))
		r.hands_formed = int(d.get("hands_formed", 0))
		for v in d.get("size_history", []):
			r.size_history.append(int(v))
		for v in d.get("feats_seen", []):
			r.feats_seen.append(String(v))
		r.patience_store = int(d.get("patience_store", 0))
		r.overflow_paid = int(d.get("overflow_paid", 0))
		r.insured = bool(d.get("insured", false))
		r.locked_slot = int(d.get("locked_slot", -1))
		r.combo_misses = int(d.get("combo_misses", 0))
		for t in d.get("tombs", []):
			r.tombs.append([int(t[0]), int(t[1])])
		r.pending_xmult = float(d.get("pending_xmult", 1.0))
		r.lines_cleared = int(d.get("lines_cleared", 0))
		r.refresh_used = bool(d.get("refresh_used", false))
		r.held = BMPieces.from_dict(d.get("held", {}))
		r.hold_used = bool(d.get("hold_used", false))
		r.locked_slot2 = int(d.get("locked_slot2", -1))
		r.last_family = String(d.get("last_family", ""))
		r.pending_lines = int(d.get("pending_lines", 0))
		var sb: Variant = BMRun._integral(d.get("start_board", {}))
		r.start_board = sb if sb is Dictionary else {}
		r.carried = bool(d.get("carried", false))
		r.rubble = int(d.get("rubble", 0))
		return r


var run_seed := 0
var kit_id := "standard"
var rng_shapes: BMRngStream
var rng_shop: BMRngStream
var rng_boss: BMRngStream
## Chance items (Lucky Draw, Mystery Stamp, Double Down): their own stream, so using one never
## changes the shapes, the shop or the bosses.
var rng_items: BMRngStream
var phase: int = Phase.ROUND
var round_number := 1
var credits := 0
var jokers: Array[String] = []
## Per-Joker traits, aligned with `jokers` (same index): {"level": int, "negative": bool,
## "again": bool}; {} = none (BMHolo). Keep them aligned through _add_joker/_remove_joker_at.
var joker_mods: Array = []
var consumables: Array[String] = []
var jokers_sold := 0
var bosses: Array[String] = []
var board := BMBoard.new()
var tray: Array = [{}, {}, {}]
## The Bag (GDD §16): every piece the player owns, plus this round's piles of uids.
var bag: Array = []
var draw_pile: Array = []
var discard_pile: Array = []
var next_uid := 0
## Schematic levels per shape family id (String -> int).
var family_levels := {}
## Loan Shark: Credits still owed (repaid from round payouts).
var loan_debt := 0
## Set when an Insurance Policy replays a lost round (reported once in the action result).
var _insurance_event := false
var round_state := RoundState.new()
var shop := {}
var history: Array = []
var stats := {}
var last_round_result := {}
var end_reason := ""
## Overtime (GDD §19): the player chose to keep going after the round-12 win.
var overtime := false
## A placement reached BMRunConfig.SCORE_CAP: the run ended as a legendary win.
var machine_broken := false
## Lifetime profile counters this run has already added (BMSaveStore.record_run), so a run that
## is won and then continues into Overtime is never counted twice.
var recorded := {}
## Run-long values of scaling Jokers (BMJokers `scaling`: Snowball, Hot Streak, Overachiever),
## shared by copies of the same card and dropped when the last copy leaves.
var joker_state := {}
## Joker slots added by Rack Extender.
var extra_slots := 0
## Item slots added by the Item Pouch.
var extra_item_slots := 0
## Holo cards bought so far, by id (each makes the next one dearer).
var holo_bought := {}
## Heat (stakes) level 0-5 chosen at the start (GDD §22.5).
var heat := 0
## "YYYY-MM-DD" for a Daily run (fixed seed, standard Kit, nothing locked), else "".
var daily := ""
## The player typed or replayed this seed (practice): the run earns no achievements, records,
## Kit or Heat unlocks, and adds nothing to the lifetime profile. Fixed at new_run.
var custom_seed := false
## Round card chosen in the shop for the current round (BMRoundCards).
var round_card := "standard"
## Jokers not yet unlocked by achievements when the run started (never offered).
var locked_jokers: Array[String] = []


# --- Construction ------------------------------------------------------------------------

static func new_run(seed_value: int, kit: String = "standard", heat_level: int = 0, locked: Array = []) -> BMRun:
	var run := BMRun.new()
	run.run_seed = seed_value
	run.kit_id = BMRunConfig.kit(kit).id
	run.heat = clampi(heat_level, 0, BMRunConfig.MAX_HEAT)
	run.locked_jokers.assign(locked)
	run.rng_shapes = BMRngStream.new(seed_value, "shapes")
	run.rng_shop = BMRngStream.new(seed_value, "shop")
	run.rng_boss = BMRngStream.new(seed_value, "boss")
	run.rng_items = BMRngStream.new(seed_value, "items")
	run.credits = int(BMRunConfig.kit(run.kit_id).credits)
	run.bosses = BMBosses.choose_run_bosses(run.rng_boss)
	run.bag = BMPieces.starter_bag(String(BMRunConfig.kit(run.kit_id).get("bag", "standard")))
	run.next_uid = run.bag.size()
	run.stats = {"lines_cleared": 0, "placements": 0, "total_points": 0, "best_placement": 0,
		"highest_combo": 0, "triple_clears": 0, "rounds_won": 0, "jokers_bought": 0, "refreshes": 0,
		"tools_bought": 0, "pieces_bought": 0, "bosses_beaten": 0, "hands": 0}
	run._start_round()
	return run


## Rebuilds a run from its seed, Kit, and action history. Used by replay tests and debugging.
static func replay(seed_value: int, kit: String, actions: Array, heat_level: int = 0, locked: Array = []) -> BMRun:
	var run := BMRun.new_run(seed_value, kit, heat_level, locked)
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


## Full state copy without the action history (previews and bots never need it).
func clone() -> BMRun:
	return BMRun.from_dict(to_dict(false))


# --- Queries -------------------------------------------------------------------------------

func kit() -> Dictionary:
	return BMRunConfig.kit(kit_id)


func joker_slots() -> int:
	return int(kit().joker_slots) + extra_slots


## Slots in use: every Joker except Negative ones.
func occupied_slots() -> int:
	_sync_mods()
	var n := 0
	for i in jokers.size():
		if not bool(joker_mods[i].get("negative", false)):
			n += 1
	return n


## No room for one more (non-Negative) Joker.
func rack_full() -> bool:
	return occupied_slots() >= joker_slots() or jokers.size() >= BMRunConfig.MAX_RACK


## Cards the rack shows: every slot, plus the Negative Jokers beyond them.
func rack_size() -> int:
	return maxi(joker_slots(), mini(BMRunConfig.MAX_RACK, jokers.size() + maxi(0, joker_slots() - occupied_slots())))


func consumable_slots() -> int:
	return BMRunConfig.CONSUMABLE_SLOTS + extra_item_slots


func items_full() -> bool:
	return consumables.size() >= consumable_slots()


## Traits of the Joker at rack index `i` ({} when it has none).
func joker_mod(i: int) -> Dictionary:
	if i < 0 or i >= joker_mods.size() or not (joker_mods[i] is Dictionary):
		return {}
	return joker_mods[i]


func joker_level(i: int) -> int:
	return int(joker_mod(i).get("level", 0))


## Keeps `joker_mods` the same length as `jokers` (older saves, tools and tests that append to
## `jokers` directly).
func _sync_mods() -> void:
	while joker_mods.size() < jokers.size():
		joker_mods.append({})
	if joker_mods.size() > jokers.size():
		joker_mods.resize(jokers.size())


func _add_joker(id: String, mod: Dictionary = {}) -> void:
	_sync_mods()
	jokers.append(id)
	joker_mods.append(mod)


func _remove_joker_at(i: int) -> void:
	_sync_mods()
	var id := jokers[i]
	jokers.remove_at(i)
	joker_mods.remove_at(i)
	if not jokers.has(id):
		joker_state.erase(id)


## Rack indices of scoring Jokers that can still gain a level, top first.
func levelable_jokers() -> Array[int]:
	var out: Array[int] = []
	for i in jokers.size():
		if BMHolo.is_scoring(jokers[i]) and joker_level(i) < BMRunConfig.MAX_JOKER_LEVEL:
			out.append(i)
	return out


## Uids of bag pieces without a stamp (Mystery Stamp), in bag order.
func unstamped_uids() -> Array[int]:
	var out: Array[int] = []
	for p in bag:
		if String(p.get("stamp", "")) == "":
			out.append(int(p.uid))
	return out


## Current run-long value of a scaling Joker (its starting value when it has none yet).
func joker_value(id: String) -> float:
	return float(joker_state.get(id, BMJokers.scaling_start(id)))


func _grow_joker(id: String, amount: float) -> void:
	if jokers.has(id):
		joker_state[id] = joker_value(id) + amount


## Whether the boss of `boss_act` plays its Mk II rules: act bosses from act 2 on, every boss
## at Heat 4+, and the final boss once Overtime has started.
func boss_is_mk2(boss_act: int = -1) -> bool:
	var a := act() if boss_act < 0 else boss_act
	if heat >= 4:
		return true
	if a - 1 >= bosses.size():
		return a >= 2
	if bosses[a - 1] == "last_call":
		return overtime
	return a >= 2


## Target of round `n` with this run's Heat and a round card (default: the current card for the
## current round, Standard otherwise). Rounded to tens.
func round_target(n: int, card: String = "") -> int:
	if card == "":
		card = round_card if n == round_number else "standard"
	var t := float(BMRunConfig.target(n)) * float(BMRunConfig.heat_def(heat).target) * BMRoundCards.target_mult(card)
	if BMRunConfig.is_boss_round(n) and n < BMRunConfig.ROUND_COUNT:
		t *= BMRunConfig.BOSS_TARGET_MULT
	if t >= float(BMRunConfig.SCORE_CAP):
		return BMRunConfig.SCORE_CAP
	return maxi(10, roundi(t / 10.0) * 10)


## Hold is off under The Lockdown Mk II.
func hold_blocked() -> bool:
	return current_boss() == "lockdown" and boss_is_mk2()


## A Refresh or Second Tray was used: Hot Streak cools down.
func _used_refresh() -> void:
	round_state.refresh_used = true
	if joker_state.has("hot_streak"):
		joker_state["hot_streak"] = 1.0


func family_level(family: StringName) -> int:
	return int(family_levels.get(String(family), 0))


func add_credits(n: int) -> void:
	credits = clampi(credits + n, 0, BMRunConfig.CREDIT_CAP)


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
		return BMLoc.m("Disabled by The Color Blind: color effects are off this round.")
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
	if slot < 0 or slot >= tray.size() or tray[slot].is_empty() or slot_locked(slot):
		return false
	return board.can_place(tray[slot].cells, anchor)


func slot_fits(slot: int) -> bool:
	return slot >= 0 and slot < tray.size() and not tray[slot].is_empty() and not slot_locked(slot) and board.fits_anywhere(tray[slot].cells)


## The Warden's barred slot (its piece can't be placed, refreshed, or bricked).
func slot_locked(slot: int) -> bool:
	return phase == Phase.ROUND and (round_state.locked_slot == slot or round_state.locked_slot2 == slot)


## True when every slot that can still be used is empty (a new tray is due).
func tray_spent() -> bool:
	for i in tray.size():
		if not tray[i].is_empty() and not slot_locked(i):
			return false
	return true


func tray_is_empty() -> bool:
	for s in tray:
		if not s.is_empty():
			return false
	return true


func consumable_usable(index: int) -> String:
	## Returns "" when usable, otherwise the reason.
	if index < 0 or index >= consumables.size():
		return BMLoc.m("No item in that slot.")
	if not can_act_in_round():
		return BMLoc.m("Items can be used during a round, between placements.")
	var id := consumables[index]
	match id:
		"second_tray":
			if current_boss() == "lockdown":
				return BMLoc.m("The Lockdown disables tray refreshes.")
			if tray_is_empty():
				return BMLoc.m("The tray is empty.")
		"extra_turn":
			if round_state.placements_left >= BMConsumables.MAX_PLACEMENTS:
				return BMLoc.m("Already at %d placements.") % BMConsumables.MAX_PLACEMENTS
		"eraser", "punch", "color_purge":
			if board.occupied_count() == 0:
				return BMLoc.m("The board is empty.")
		"lucky_paint", "blueprint":
			if tray_is_empty():
				return BMLoc.m("The tray is empty.")
		"polish", "spark", "cash_out", "emergency_brick", "overclock", "coin_roll", "phantom_line":
			pass
		"lucky_draw":
			if rack_full():
				return BMLoc.m("Lucky Draw needs a free Joker slot.")
		"mystery_stamp":
			if unstamped_uids().is_empty():
				return BMLoc.m("Every piece in your bag already has a stamp.")
		"double_down":
			if credits <= 0:
				return BMLoc.m("You have no Credits to double.")
		"coffee_break":
			if current_boss() == "lockdown":
				return BMLoc.m("The Lockdown disables Refresh this round.")
			if round_card == "rush_hour":
				return BMLoc.m("Rush Hour: no Refresh this round.")
		"tune_up":
			if tray_is_empty():
				return BMLoc.m("The tray is empty.")
		_:
			if not BMConsumables.is_implemented(id):
				return BMLoc.m("Not usable yet in this build.")
	if round_state.status == OUT_OF_PLACEMENTS and id != "extra_turn":
		return BMLoc.m("Only Extra Turn helps when placements are spent.")
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
			return use_consumable(int(a.i), a)
		"patch":
			return patch_cell(Vector2i(int(a.x), int(a.y)))
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
		"buy_tool":
			return buy_tool(int(a.i), a.get("targets", []), int(a.get("color", -1)))
		"buy_piece":
			return buy_piece(int(a.i))
		"crate":
			return open_crate(int(a.i))
		"abandon":
			return abandon()
		"hold":
			return hold(int(a.slot))
		"pick_round":
			return pick_round(int(a.i))
		"overtime":
			return start_overtime()
		"buy_holo":
			return buy_holo(int(a.i))
	return _fail("Unknown action %s" % a)


func place(slot: int, anchor: Vector2i) -> Dictionary:
	if not can_place():
		return _fail(BMLoc.m("Cannot place right now."))
	if slot < 0 or slot >= tray.size() or tray[slot].is_empty():
		return _fail(BMLoc.m("That tray slot is empty."))
	if slot_locked(slot):
		return _fail(BMLoc.m("The Warden barred this slot. Clear a line to free it."))
	if not board.can_place(tray[slot].cells, anchor):
		return _fail(BMLoc.m("The shape does not fit there."))
	var result := BMResolver.resolve_placement(self, slot, anchor)
	history.append({"a": "place", "slot": slot, "x": anchor.x, "y": anchor.y})
	round_state.hold_used = false
	if bool(result.get("broken", false)):
		_break_machine()
		result.phase = phase
		return result
	# The Undertaker: a tombstone rises after every 4th placement (not after the winning one).
	var every := BMBosses.UNDERTAKER_EVERY_MK2 if boss_is_mk2() else BMBosses.UNDERTAKER_EVERY
	if current_boss() == "undertaker" and round_state.score < round_state.target \
			and round_state.placements_made % every == 0:
		var t := BMBosses.tomb_cell(rng_boss, board)
		if t.x >= 0:
			board.set_cell(t, BMShapes.COLOR_STONE)
			round_state.tombs.append([t.x, t.y])
			result.tomb = t
			result.events.append(BMLoc.m("The Undertaker raised a tombstone"))
	result.merge(_after_round_action(), true)
	return result


## Hold (GDD §22.1): store a tray piece (its slot draws a new one from the bag), or swap the
## stored piece with a tray slot (an empty slot takes it back). Once between placements.
func hold(slot: int) -> Dictionary:
	if not can_act_in_round() or round_state.status == OUT_OF_PLACEMENTS:
		return _fail(BMLoc.m("Cannot hold right now."))
	if hold_blocked():
		return _fail(BMLoc.m("The Lockdown Mk II disables Hold this round."))
	var rs := round_state
	if rs.hold_used:
		return _fail(BMLoc.m("Hold is available again after a placement."))
	if slot < 0 or slot >= tray.size() or slot_locked(slot):
		return _fail(BMLoc.m("Choose an open tray slot."))
	var outgoing: Dictionary = tray[slot]
	var incoming: Dictionary = rs.held
	if outgoing.is_empty() and incoming.is_empty():
		return _fail(BMLoc.m("Nothing to hold."))
	var events: Array = []
	if not outgoing.is_empty():
		outgoing.erase("hand")
	if incoming.is_empty():
		rs.held = outgoing
		tray[slot] = {}
		# A natural draw: Hold is not a free, guaranteed Refresh.
		if tray_spent():
			_deal_fresh_tray(false)
			events.append(BMLoc.m("New tray"))
		else:
			BMBag.deal(self, [slot], false)
		events.append(BMLoc.m("Held %s") % BMPieces.english_name(outgoing))
	else:
		tray[slot] = incoming
		rs.held = outgoing
		events.append(BMLoc.m("Swapped in %s") % BMPieces.english_name(incoming))
	rs.hold_used = true
	if rs.status == STUCK:
		rs.status = PLAYING
	history.append({"a": "hold", "slot": slot})
	var result := {"ok": true, "type": "hold", "slot": slot, "events": events, "held": rs.held}
	result.merge(_after_round_action(), true)
	return result


## Picks the round card for the next round (shop only; index into shop.round_cards).
func pick_round(i: int) -> Dictionary:
	if phase != Phase.SHOP:
		return _fail(BMLoc.m("The shop is closed."))
	var cards: Array = shop.get("round_cards", [])
	if i < 0 or i >= cards.size():
		return _fail(BMLoc.m("No round card there."))
	shop.round_pick = i
	history.append({"a": "pick_round", "i": i})
	return {"ok": true, "type": "pick_round", "card": String(cards[i])}


func refresh() -> Dictionary:
	if not can_act_in_round() or round_state.status == OUT_OF_PLACEMENTS:
		return _fail(BMLoc.m("Cannot refresh right now."))
	if current_boss() == "lockdown":
		return _fail(BMLoc.m("The Lockdown disables Refresh this round."))
	if round_state.refreshes_left <= 0:
		return _fail(BMLoc.m("No Refresh left this round."))
	if tray_is_empty():
		return _fail(BMLoc.m("The tray is empty."))
	round_state.refreshes_left -= 1
	_used_refresh()
	var result := _do_tray_refresh(BMLoc.m("Refresh"))
	history.append({"a": "refresh"})
	result.merge(_after_round_action(), true)
	return result


## `t` carries the player's target for items that need one (see BMConsumables): "cells" as
## [[x, y], ...], "slot", "color", "choice". Nothing changes if the target is invalid.
func use_consumable(index: int, t: Dictionary = {}) -> Dictionary:
	var reason := consumable_usable(index)
	if reason != "":
		return _fail(reason)
	var id := consumables[index]
	var target := _validate_target(id, t)
	if target.has("error"):
		return _fail(target.error)
	consumables.remove_at(index)
	var result := {"ok": true, "type": "use", "item": id, "events": []}
	match id:
		"eraser", "punch", "color_purge":
			var cells: Array[Vector2i] = []
			cells.assign(target.cells)
			result.removed = board.clear_cells(cells)
			var nrem: int = result.removed.size()
			result.events.append(BMLoc.mn("%s removed %d block", "%s removed %d blocks", nrem) % [BMConsumables.get_def(id).name, nrem])
		"lucky_paint":
			tray[target.slot].color = int(target.color)
			result.slot = target.slot
			result.color = target.color
		"blueprint":
			var old: Dictionary = tray[target.slot]
			BMBag.discard(self, old)
			var pick: Array = BMConsumables.BLUEPRINT_CHOICES[target.choice]
			var p := BMPieces.temporary_single(int(old.color))
			var sh := BMShapes.make_shape(StringName(pick[0]), int(pick[1]), int(old.color))
			p.family = sh.family
			p.rot = sh.rot
			p.cells = sh.cells
			tray[target.slot] = p
			result.slot = target.slot
		"emergency_brick":
			var hit: Dictionary = tray[target.slot]
			if not hit.is_empty():
				BMBag.discard(self, hit)
				result.smashed = hit
			tray[target.slot] = BMPieces.brick()
			result.slot = target.slot
		"polish":
			var pc := BMConsumables.polish_chips(round_number)
			round_state.pending_chips += pc
			result.value = pc
		"spark":
			var sm := BMConsumables.spark_mult(act())
			round_state.pending_mult += sm
			result.value = sm
		"phantom_line":
			round_state.pending_lines += 1
			result.events.append(BMLoc.m("Phantom Line: your next clear counts one extra line"))
		"lucky_draw":
			if rng_items.randi_range(1, BMConsumables.LUCKY_DRAW_ONE_IN) == 1:
				var rarity := rng_items.weighted_index(BMConsumables.LUCKY_DRAW_WEIGHTS)
				var pick := _pick_joker(rarity, [], rng_items)
				for r in [BMJokers.RARE, BMJokers.UNCOMMON]:
					if pick == "":
						pick = _pick_joker(r, [], rng_items)
				if pick != "":
					_add_joker(pick)
					_joker_joined(pick)
					result.joker = pick
					result.events.append(BMLoc.m("Lucky Draw: %s joined your rack!") % BMJokers.get_def(pick).name)
			if not result.has("joker"):
				result.events.append(BMLoc.m("Lucky Draw: no luck this time"))
		"mystery_stamp":
			var uids := unstamped_uids()
			var uid: int = uids[rng_items.randi_range(0, uids.size() - 1)]
			var stamps: Array = BMPieces.STAMP_DEFS.keys()
			var stamp: String = stamps[rng_items.randi_range(0, stamps.size() - 1)]
			var bp := BMBag.piece_by_uid(self, uid)
			bp.stamp = stamp
			# The copy on the tray or in Hold shows it at once.
			for i in tray.size():
				if not tray[i].is_empty() and int(tray[i].get("uid", -1)) == uid:
					tray[i].stamp = stamp
			if not round_state.held.is_empty() and int(round_state.held.get("uid", -1)) == uid:
				round_state.held.stamp = stamp
			result.uid = uid
			result.stamp = stamp
			result.events.append(BMLoc.m("Mystery Stamp: your %s got a %s") % [BMPieces.english_name(bp), BMPieces.STAMP_DEFS[stamp].name])
		"double_down":
			if rng_items.randi_range(1, BMConsumables.DOUBLE_DOWN_ONE_IN) == 1:
				var gain := mini(BMConsumables.DOUBLE_DOWN_MAX, credits)
				add_credits(gain)
				result.credits = gain
				result.events.append(BMLoc.m("Double Down: +%d Credits!") % gain)
			else:
				result.credits = 0
				result.events.append(BMLoc.m("Double Down: no luck this time"))
		"second_tray":
			_used_refresh()
			result.merge(_do_tray_refresh(BMLoc.m("Second Tray")), true)
			result.type = "use"
			result.item = id
		"overclock":
			round_state.pending_xmult *= BMConsumables.OVERCLOCK_X_MULT
		"tune_up":
			var fam := String(tray[target.slot].family)
			family_levels[fam] = int(family_levels.get(fam, 0)) + 1
			result.slot = target.slot
			result.family = fam
			result.level = family_levels[fam]
		"coffee_break":
			round_state.refreshes_left += 1
		"coin_roll":
			var gain := mini(BMConsumables.COIN_ROLL_MAX, round_number)
			add_credits(gain)
			result.credits = gain
		"extra_turn":
			round_state.placements_left = mini(BMConsumables.MAX_PLACEMENTS, round_state.placements_left + 2)
			if round_state.status == OUT_OF_PLACEMENTS:
				round_state.status = PLAYING
		"cash_out":
			round_state.cash_out += 1
	var h := {"a": "use", "i": index}
	for k in ["cells", "slot", "color", "choice"]:
		if t.has(k):
			h[k] = t[k]
	history.append(h)
	result.merge(_after_round_action(), true)
	return result


## Checks an item's target. Returns {"error": ...} or the normalized target.
func _validate_target(id: String, t: Dictionary) -> Dictionary:
	match BMConsumables.target_kind(id):
		"cells":
			var cells: Array[Vector2i] = []
			for c in t.get("cells", []):
				var p := Vector2i(int(c[0]), int(c[1]))
				if not BMBoard.in_bounds(p) or board.is_empty(p):
					return {"error": BMLoc.m("Choose blocks on the board.")}
				if not cells.has(p):
					cells.append(p)
			if cells.is_empty() or cells.size() > BMConsumables.ERASER_CELLS:
				return {"error": BMLoc.m("Choose 1 to %d blocks.") % BMConsumables.ERASER_CELLS}
			return {"cells": cells}
		"cell":
			var c: Array = t.get("cells", [])
			if c.size() != 1:
				return {"error": BMLoc.m("Choose where to hit.")}
			var hits: Array[Vector2i] = []
			for p: Vector2i in BMConsumables.punch_cells(Vector2i(int(c[0][0]), int(c[0][1]))):
				if not board.is_empty(p):
					hits.append(p)
			if hits.is_empty():
				return {"error": BMLoc.m("Nothing to hit there.")}
			return {"cells": hits}
		"color":
			var color := int(t.get("color", -1))
			if color < 0 or color >= BMShapes.OFFER_COLOR_COUNT:
				return {"error": BMLoc.m("Choose a color.")}
			var hits: Array[Vector2i] = []
			for y in BMBoard.SIZE:
				for x in BMBoard.SIZE:
					if board.get_cell(Vector2i(x, y)) == color:
						hits.append(Vector2i(x, y))
			if hits.is_empty():
				return {"error": BMLoc.m("No %s blocks on the board.") % BMShapes.COLOR_NAMES[color]}
			return {"cells": hits}
		"slot", "slot_color", "slot_shape":
			var slot := int(t.get("slot", -1))
			if slot < 0 or slot >= tray.size():
				return {"error": BMLoc.m("Choose a tray slot.")}
			var kind := BMConsumables.target_kind(id)
			if slot_locked(slot):
				return {"error": BMLoc.m("The Warden barred that slot.")}
			if (kind != "slot" or id == "tune_up") and tray[slot].is_empty():
				return {"error": BMLoc.m("That tray slot is empty.")}
			if kind == "slot_color":
				var color := int(t.get("color", -1))
				if color < 0 or color >= BMShapes.OFFER_COLOR_COUNT:
					return {"error": BMLoc.m("Choose a color.")}
				if color == int(tray[slot].color):
					return {"error": BMLoc.m("That piece is already %s.") % BMShapes.COLOR_NAMES[color]}
				return {"slot": slot, "color": color}
			if kind == "slot_shape":
				var choice := int(t.get("choice", -1))
				if choice < 0 or choice >= BMConsumables.BLUEPRINT_CHOICES.size():
					return {"error": BMLoc.m("Choose a shape.")}
				return {"slot": slot, "choice": choice}
			return {"slot": slot}
	return {}


## Patch Panel: after the first clear each round, remove one block of your choice (no score).
func patch_cell(p: Vector2i) -> Dictionary:
	if not can_act_in_round() or round_state.status == OUT_OF_PLACEMENTS:
		return _fail(BMLoc.m("Cannot patch right now."))
	if not round_state.patch_ready:
		return _fail(BMLoc.m("Patch Panel is not ready."))
	if not BMBoard.in_bounds(p) or board.is_empty(p):
		return _fail(BMLoc.m("Choose a block on the board."))
	var cells: Array[Vector2i] = [p]
	var removed := board.clear_cells(cells)
	round_state.patch_ready = false
	round_state.patch_used = true
	history.append({"a": "patch", "x": p.x, "y": p.y})
	var result := {"ok": true, "type": "patch", "removed": removed, "events": [BMLoc.m("Patch Panel removed a block")]}
	result.merge(_after_round_action(), true)
	return result


func concede_round() -> Dictionary:
	if not (phase == Phase.ROUND and round_state.status in [STUCK, OUT_OF_PLACEMENTS]):
		return _fail(BMLoc.m("You can only concede when stuck."))
	history.append({"a": "concede"})
	_lose(BMLoc.m("Conceded: no legal placement remained.") if round_state.status == STUCK else BMLoc.m("Conceded: out of placements."))
	var r := {"ok": true, "type": "concede", "phase": phase}
	if _insurance_event:
		_insurance_event = false
		r.insurance = true
	return r


func abandon() -> Dictionary:
	if phase in [Phase.RUN_WON, Phase.RUN_LOST, Phase.ABANDONED]:
		return _fail(BMLoc.m("The run is already over."))
	history.append({"a": "abandon"})
	phase = Phase.ABANDONED
	end_reason = BMLoc.m("Run abandoned.")
	return {"ok": true, "type": "abandon"}


func continue_after_round() -> Dictionary:
	if phase != Phase.ROUND_RESULT:
		return _fail(BMLoc.m("No round result to continue from."))
	history.append({"a": "continue"})
	if round_number >= BMRunConfig.ROUND_COUNT and not overtime:
		phase = Phase.RUN_WON
		end_reason = BMLoc.m("All %d rounds cleared!") % BMRunConfig.ROUND_COUNT
		return {"ok": true, "type": "continue", "phase": phase}
	_open_shop()
	return {"ok": true, "type": "continue", "phase": phase}


## Overtime: after the round-12 win, keep playing. The shop opens and rounds continue with
## rising targets (BMRunConfig.target) and a boss every fourth round, until a round is lost.
func start_overtime() -> Dictionary:
	if phase != Phase.RUN_WON or overtime or machine_broken or round_number < BMRunConfig.ROUND_COUNT:
		return _fail(BMLoc.m("Overtime starts after winning the final round."))
	overtime = true
	history.append({"a": "overtime"})
	_open_shop()
	return {"ok": true, "type": "overtime", "phase": phase}


## A placement hit the machine's limit: the round and the run end at once, as a win.
func _break_machine() -> void:
	machine_broken = true
	round_state.status = WON
	phase = Phase.RUN_WON
	stats.rounds_won += 1
	end_reason = BMLoc.m("You broke the machine in round %d: one placement hit its limit of %s points.") % [round_number, BMRunConfig.SCORE_CAP_TEXT]


# --- Shop commands -------------------------------------------------------------------------

func buy_joker(offer: int) -> Dictionary:
	if phase != Phase.SHOP:
		return _fail(BMLoc.m("The shop is closed."))
	if offer < 0 or offer >= shop.jokers.size() or shop.jokers[offer] == "":
		return _fail(BMLoc.m("That offer is gone."))
	var id: String = shop.jokers[offer]
	var price := BMJokers.cost(id)
	if credits < price:
		return _fail(BMLoc.m("Not enough Credits."))
	if rack_full():
		return _fail(BMLoc.m("Joker slots are full. Sell a Joker first."))
	credits -= price
	_add_joker(id)
	shop.jokers[offer] = ""
	stats.jokers_bought += 1
	_joker_joined(id)
	history.append({"a": "buy_joker", "i": offer})
	return {"ok": true, "type": "buy_joker", "item": id, "price": price}


func buy_consumable(offer: int) -> Dictionary:
	if phase != Phase.SHOP:
		return _fail(BMLoc.m("The shop is closed."))
	if offer < 0 or offer >= shop.consumables.size() or shop.consumables[offer] == "":
		return _fail(BMLoc.m("That offer is gone."))
	var id: String = shop.consumables[offer]
	var price := BMConsumables.cost(id)
	if credits < price:
		return _fail(BMLoc.m("Not enough Credits."))
	if items_full():
		return _fail(BMLoc.m("Item slots are full. Use an item first."))
	credits -= price
	consumables.append(id)
	shop.consumables[offer] = ""
	history.append({"a": "buy_consumable", "i": offer})
	return {"ok": true, "type": "buy_consumable", "item": id, "price": price}


## Buys a Workshop card and applies it at once to the chosen bag pieces (uids).
## `color` is required by Repaint. Nothing changes if validation fails.
func buy_tool(offer: int, targets: Array = [], color: int = -1) -> Dictionary:
	if phase != Phase.SHOP:
		return _fail(BMLoc.m("The shop is closed."))
	if offer < 0 or offer >= shop.tools.size() or shop.tools[offer].is_empty():
		return _fail(BMLoc.m("That offer is gone."))
	var o: Dictionary = shop.tools[offer]
	var def := BMTools.get_def(o.id)
	if credits < int(def.cost):
		return _fail(BMLoc.m("Not enough Credits."))
	var uids: Array[int] = []
	for t in targets:
		if not uids.has(int(t)):
			uids.append(int(t))
	var max_targets := int(def.max_targets)
	if max_targets == 0 and not uids.is_empty():
		return _fail(BMLoc.m("This card does not target pieces."))
	if max_targets > 0 and (uids.is_empty() or uids.size() > max_targets):
		return _fail(BMLoc.mn("Choose 1 to %d piece.", "Choose 1 to %d pieces.", max_targets) % max_targets)
	var pieces: Array = []
	for uid in uids:
		var p := BMBag.piece_by_uid(self, uid)
		if p.is_empty():
			return _fail(BMLoc.m("That piece is not in your bag."))
		pieces.append(p)
	match def.kind:
		"material":
			for p in pieces:
				if p.material == def.value:
					return _fail(BMLoc.m("A chosen piece is already %s.") % BMPieces.MATERIAL_DEFS[def.value].name)
			for p in pieces:
				p.material = def.value
		"stamp":
			for p in pieces:
				if p.stamp == def.value:
					return _fail(BMLoc.m("That piece already has this stamp."))
			for p in pieces:
				p.stamp = def.value
		"copy":
			if bag.size() + pieces.size() > BMPieces.MAX_BAG:
				return _fail(BMLoc.m("Your bag is full (%d pieces).") % BMPieces.MAX_BAG)
			for p in pieces:
				BMBag.add_piece(self, p)
		"remove":
			if bag.size() - pieces.size() < BMPieces.MIN_BAG:
				return _fail(BMLoc.m("Your bag must keep at least %d pieces.") % BMPieces.MIN_BAG)
			for uid in uids:
				BMBag.remove_piece(self, uid)
		"rotate":
			for p in pieces:
				if BMShapes.rotations(p.family).size() < 2:
					return _fail("%s has only one orientation." % BMShapes.family(p.family).name)
			for p in pieces:
				var turned := BMShapes.make_shape(p.family, int(p.rot) + 1, int(p.color))
				p.rot = turned.rot
				p.cells = turned.cells
		"repaint":
			if color < 0 or color >= BMShapes.OFFER_COLOR_COUNT:
				return _fail(BMLoc.m("Choose a color."))
			for p in pieces:
				p.color = color
		"schematic":
			var key := String(o.family)
			family_levels[key] = int(family_levels.get(key, 0)) + 1
		"slot":
			if joker_slots() >= BMRunConfig.MAX_JOKER_SLOTS:
				return _fail(BMLoc.m("Your Joker rack is already at %d slots.") % BMRunConfig.MAX_JOKER_SLOTS)
			extra_slots += 1
		"item_slot":
			if consumable_slots() >= BMRunConfig.MAX_ITEM_SLOTS:
				return _fail(BMLoc.m("You already have %d item slots.") % BMRunConfig.MAX_ITEM_SLOTS)
			extra_item_slots += 1
		"joker_level":
			var up := levelable_jokers()
			if up.is_empty():
				return _fail(BMLoc.m("No scoring Joker can gain a level."))
			_sync_mods()
			var m: Dictionary = joker_mods[up[0]].duplicate()
			m.level = int(m.get("level", 0)) + 1
			joker_mods[up[0]] = m
	credits -= int(def.cost)
	shop.tools[offer] = {}
	stats.tools_bought += 1
	history.append({"a": "buy_tool", "i": offer, "targets": uids.duplicate(), "color": color})
	return {"ok": true, "type": "buy_tool", "item": o.id, "price": int(def.cost)}


func buy_piece(offer: int) -> Dictionary:
	if phase != Phase.SHOP:
		return _fail(BMLoc.m("The shop is closed."))
	if offer < 0 or offer >= shop.pieces.size() or shop.pieces[offer].is_empty():
		return _fail(BMLoc.m("That offer is gone."))
	var d: Dictionary = shop.pieces[offer]
	if credits < int(d.cost):
		return _fail(BMLoc.m("Not enough Credits."))
	if bag.size() >= BMPieces.MAX_BAG:
		return _fail(BMLoc.m("Your bag is full (%d pieces).") % BMPieces.MAX_BAG)
	credits -= int(d.cost)
	var p := BMBag.add_piece(self, BMPieces.from_dict(d))
	shop.pieces[offer] = {}
	stats.pieces_bought += 1
	history.append({"a": "buy_piece", "i": offer})
	return {"ok": true, "type": "buy_piece", "piece": p, "price": int(d.cost)}


func has_crate() -> bool:
	return phase == Phase.SHOP and not Array(shop.get("crate", [])).is_empty()


func reroll_shop() -> Dictionary:
	if phase != Phase.SHOP:
		return _fail(BMLoc.m("The shop is closed."))
	var price: int = shop.reroll_cost
	if credits < price:
		return _fail(BMLoc.m("Not enough Credits."))
	credits -= price
	shop.reroll_cost = price + 1
	_fill_shop_offers()
	history.append({"a": "reroll"})
	return {"ok": true, "type": "reroll", "price": price}


func sell_joker(index: int) -> Dictionary:
	if not (phase == Phase.SHOP or can_act_in_round()):
		return _fail(BMLoc.m("Jokers can be sold in the shop or between placements."))
	if index < 0 or index >= jokers.size():
		return _fail(BMLoc.m("No Joker in that slot."))
	var id := jokers[index]
	if id == "loan_shark" and loan_debt > 0:
		return _fail(BMLoc.m("Repay the loan first (%d Credits owed).") % loan_debt)
	var value := BMJokers.sell_value(id)
	_remove_joker_at(index)
	credits = mini(BMRunConfig.CREDIT_CAP, credits + value)
	jokers_sold += 1
	history.append({"a": "sell", "i": index})
	var result := {"ok": true, "type": "sell", "item": id, "value": value}
	if phase == Phase.ROUND:
		result.merge(_after_round_action(), true)
	return result


func move_joker(from: int, to: int) -> Dictionary:
	if not (phase == Phase.SHOP or can_act_in_round()):
		return _fail(BMLoc.m("Jokers can be reordered in the shop or between placements."))
	if from < 0 or from >= jokers.size() or to < 0 or to >= jokers.size() or from == to:
		return _fail(BMLoc.m("Invalid Joker move."))
	_sync_mods()
	var id := jokers[from]
	var mod: Dictionary = joker_mods[from]
	jokers.remove_at(from)
	joker_mods.remove_at(from)
	jokers.insert(to, id)
	joker_mods.insert(to, mod)
	history.append({"a": "move", "from": from, "to": to})
	return {"ok": true, "type": "move"}


func leave_shop() -> Dictionary:
	if phase != Phase.SHOP:
		return _fail(BMLoc.m("The shop is closed."))
	history.append({"a": "leave_shop"})
	var cards: Array = shop.get("round_cards", [])
	var pick := int(shop.get("round_pick", 0))
	round_card = String(cards[pick]) if pick >= 0 and pick < cards.size() else "standard"
	round_number += 1
	_start_round()
	return {"ok": true, "type": "leave_shop"}


# --- Internals -----------------------------------------------------------------------------

func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg}


func _start_round(replay: bool = false) -> void:
	_ensure_bosses(act())
	phase = Phase.ROUND
	# Board pressure: inside an act the board can carry over from the last round (it is swept
	# when an act starts). An Insurance replay restarts from the round's own starting board.
	var carried := {}
	if replay and not round_state.start_board.is_empty():
		carried = round_state.start_board
	elif BMRunConfig.carry_board and (round_number - 1) % BMRunConfig.ROUNDS_PER_ACT != 0:
		carried = board.to_dict()
	board = BMBoard.from_dict(carried) if not carried.is_empty() else BMBoard.new()
	var boss := current_boss()
	if boss != "":
		round_card = "standard"
	var mk2 := boss != "" and boss_is_mk2()
	var rs := RoundState.new()
	rs.target = round_target(round_number)
	rs.placements_left = int(kit().placements) - (1 if heat >= 2 else 0)
	rs.refreshes_left = maxi(0, int(kit().refreshes) - (1 if heat >= 5 else 0))
	if boss == "last_call":
		rs.placements_left = BMBosses.LAST_CALL_PLACEMENTS_MK2 if mk2 else BMBosses.LAST_CALL_PLACEMENTS
	if boss == "color_blind" and mk2:
		rs.placements_left -= BMBosses.COLOR_BLIND_MK2_PLACEMENTS
	match round_card:
		"tight_budget":
			rs.placements_left -= BMRoundCards.TIGHT_BUDGET_PLACEMENTS
		"rush_hour":
			rs.refreshes_left = 0
	rs.placements_left += jokers.count("long_game")
	rs.placement_cap = rs.placements_left
	if boss == "cramped_cabinet":
		rs.fixed_cells = _seed_cells(BMBosses.FIXED_CELL_COUNT_MK2 if mk2 else BMBosses.FIXED_CELL_COUNT)
		for p in rs.fixed_cells:
			board.set_cell(p, BMShapes.COLOR_STONE)
	if round_card == "gold_rush":
		# Six seeded Gold blocks (boss stream). Six cells can never complete a line.
		var gold := _seed_cells(BMRoundCards.GOLD_RUSH_CELLS)
		for p in gold:
			board.set_cell(p, rng_boss.randi_range(0, BMShapes.OFFER_COLOR_COUNT - 1))
			board.mats[p.y * BMBoard.SIZE + p.x] = BMPieces.material_index("gold")
	# Rubble: stone blocks on empty cells that never complete a line (boss stream).
	rs.carried = not carried.is_empty()
	if not replay:
		for i in BMRunConfig.rubble(act()):
			var t := BMBosses.tomb_cell(rng_boss, board)
			if t.x >= 0:
				board.set_cell(t, BMShapes.COLOR_STONE)
				rs.rubble += 1
	rs.start_board = board.to_dict() if BMRunConfig.carry_board else {}
	round_state = rs
	tray = [{}, {}, {}]
	BMBag.start_round(self)
	_deal_fresh_tray()
	if boss == "warden":
		rs.locked_slot = rng_boss.randi_range(0, 2)
		if mk2:
			rs.locked_slot2 = (rs.locked_slot + rng_boss.randi_range(1, 2)) % 3
		# The guarantee must hold for the playable slots: re-check without the barred ones.
		var open_slots: Array = []
		for i in 3:
			if i != rs.locked_slot and i != rs.locked_slot2:
				open_slots.append(i)
		BMBag.ensure_legal(self, open_slots)


## Seeded cells for a round's starting blocks (boss stream): anywhere on an empty board (fewer
## than 8 can never complete a line), else only empty cells that complete no line.
func _seed_cells(count: int) -> Array[Vector2i]:
	if board.occupied_count() == 0:
		return BMBosses.cramped_cells(rng_boss, count)
	var out: Array[Vector2i] = []
	var probe := board.duplicate_board()
	for i in count:
		var t := BMBosses.tomb_cell(rng_boss, probe)
		if t.x < 0:
			break
		probe.set_cell(t, BMShapes.COLOR_STONE)
		out.append(t)
	return out


## Deals a whole new tray and checks it for a Hand. Returns the Hand id or "".
## `guarantee`: swap in a fitting piece if none fits (the round's first tray only). A tray
## refilled during play is dealt as drawn, so a crowded board can leave it dead (study
## follow-up 2026-09-26: running out of room should be a real way to lose).
func _deal_fresh_tray(guarantee: bool = true) -> String:
	var slots: Array = []
	for i in 3:
		if not slot_locked(i):
			tray[i] = {}
			slots.append(i)
	BMBag.deal(self, slots, guarantee)
	return _apply_hand() if slots.size() == 3 else ""


## Marks the three tray pieces with their Hand and grants the one-time rewards
## (docs/design/round_play_update.md §2). Returns the Hand id or "".
func _apply_hand() -> String:
	var hand := BMHands.detect(tray)
	if hand == "":
		return ""
	for p in tray:
		p.hand = hand
	var rs := round_state
	match hand:
		BMHands.STAIRCASE:
			rs.placements_left += BMHands.STAIRCASE_PLACEMENTS
		BMHands.TRIPLETS:
			rs.refreshes_left += BMHands.TRIPLETS_REFRESHES
		BMHands.GRAND_SLAM:
			rs.refreshes_left += BMHands.TRIPLETS_REFRESHES
			add_credits(BMHands.GRAND_SLAM_CREDITS)
	rs.hands_formed += 1
	stats["hands"] = int(stats.get("hands", 0)) + 1
	# Tetromino Kit, Full House: every Hand pays.
	var hc := int(kit().get("hand_credits", 0))
	if hc > 0:
		add_credits(hc)
	return hand


func _do_tray_refresh(label: String) -> Dictionary:
	var slots: Array = []
	for i in tray.size():
		if not tray[i].is_empty() and not slot_locked(i):
			slots.append(i)
			BMBag.discard(self, tray[i])
			tray[i] = {}
	var dealt := BMBag.deal(self, slots)
	var events: Array = [label]
	if dealt.temporary:
		events.append(BMLoc.m("No piece in your bag fits: a temporary Single was dealt"))
	var hand := ""
	if slots.size() == 3 and has_active_joker("card_sharp"):
		hand = _apply_hand()
		if hand != "":
			events.append(BMLoc.m("Card Sharp: %s!") % BMHands.get_def(hand).name)
	if not round_state.first_refresh_done:
		round_state.first_refresh_done = true
		var bonus := jokers.count("second_look")
		if bonus > 0:
			round_state.placements_left += bonus
			events.append(BMLoc.mn("Second Look: +%d placement", "Second Look: +%d placements", bonus) % bonus)
	stats.refreshes += 1
	if round_state.status == STUCK:
		round_state.status = PLAYING
	return {"ok": true, "type": "refresh", "events": events, "hand": hand}


## Win/loss/stuck evaluation after any round action (see _evaluate_round). Reports an
## Insurance Policy claim once.
func _after_round_action() -> Dictionary:
	var r := _evaluate_round()
	if _insurance_event:
		_insurance_event = false
		r.insurance = true
		r.phase = phase
		r.status = round_state.status
	return r


## Order: target first (a crossing placement always wins), then tray refill, then placements,
## then legality and rescues.
func _evaluate_round() -> Dictionary:
	var events: Array = []
	var rs := round_state
	if phase != Phase.ROUND:
		return {}
	if rs.score >= rs.target:
		_win_round()
		return {"round_won": true, "phase": phase}
	var hand := ""
	if tray_spent():
		hand = _deal_fresh_tray(false)
		events.append(BMLoc.m("New tray"))
		for p in tray:
			if not p.is_empty() and bool(p.get("temporary", false)):
				events.append(BMLoc.m("No piece in your bag fits: a temporary Single was dealt"))
	if rs.placements_left <= 0:
		if consumables.has("extra_turn"):
			rs.status = OUT_OF_PLACEMENTS
		else:
			_lose(BMLoc.m("Out of placements: %d / %d points.") % [rs.score, rs.target])
		return {"status": rs.status, "phase": phase, "tray_events": events, "tray_hand": hand}
	var any_fit := false
	for i in tray.size():
		if slot_fits(i):
			any_fit = true
			break
	# A stored piece that fits can still be swapped in.
	if not any_fit and not rs.held.is_empty() and not rs.hold_used and not hold_blocked() and board.fits_anywhere(rs.held.cells):
		any_fit = true
	if any_fit:
		rs.status = PLAYING
	elif refreshes_available() > 0:
		rs.status = STUCK
	elif has_active_joker("tiny_insurance") and not rs.tiny_insurance_used and board.empty_count() > 0 			and _insurance_slot() >= 0:
		# The Single goes into a slot the player can use: never the Warden's barred one (a
		# Single there left the round PLAYING with no legal move and no Concede).
		rs.tiny_insurance_used = true
		var slot := _insurance_slot()
		var color := int(tray[slot].color)
		BMBag.discard(self, tray[slot])
		tray[slot] = BMPieces.temporary_single(color)
		rs.status = PLAYING
		events.append(BMLoc.m("Tiny Insurance: a Single replaced a stuck shape"))
	elif _has_rescue_consumable():
		rs.status = STUCK
	else:
		_lose(BMLoc.m("No offered shape fits and no rescue remains."))
	return {"status": rs.status, "phase": phase, "tray_events": events, "tray_hand": hand}


## Tiny Insurance's slot: the first unbarred tray slot holding a piece, or -1.
func _insurance_slot() -> int:
	for i in tray.size():
		if not tray[i].is_empty() and not slot_locked(i):
			return i
	return -1


func _has_rescue_consumable() -> bool:
	if round_state.patch_ready:
		return true
	for id in consumables:
		if id in ["second_tray", "coffee_break"] and current_boss() != "lockdown":
			return true
		if id in ["eraser", "punch", "color_purge", "blueprint", "emergency_brick"] and BMConsumables.is_implemented(id):
			return true
	return false


func _win_round() -> void:
	var rs := round_state
	rs.status = WON
	var unused := maxi(0, rs.placements_left)
	var held := credits
	var lines: Array = []
	lines.append({"label": BMLoc.m("Round won"), "value": BMRunConfig.WIN_CREDITS})
	var bonus := mini(BMRunConfig.UNUSED_PLACEMENT_BONUS_CAP, unused / 2)
	if bonus > 0:
		lines.append({"label": BMLoc.m("Unused placements (%d)") % unused, "value": bonus})
	if BMRunConfig.is_boss_round(round_number):
		lines.append({"label": BMLoc.m("Boss defeated"), "value": BMRunConfig.BOSS_CREDITS})
		stats["bosses_beaten"] = int(stats.get("bosses_beaten", 0)) + 1
	if unused >= 2:
		for i in jokers.count("spare_parts"):
			lines.append({"label": BMLoc.m("Spare Parts"), "value": BMRunConfig.SPARE_PARTS_CREDITS})
	for i in rs.cash_out:
		lines.append({"label": BMLoc.m("Cash Out"), "value": BMRunConfig.CASH_OUT_CREDITS})
	# Overkill: every full half-target scored beyond the target pays a Credit.
	var overkill := 0
	if rs.target > 0:
		overkill = mini(BMRunConfig.OVERKILL_CAP, floori(float(rs.score - rs.target) / (rs.target * BMRunConfig.OVERKILL_STEP)))
	if overkill > 0:
		lines.append({"label": BMLoc.m("Overkill (%s of target)") % ("%.1fx" % (float(rs.score) / rs.target)), "value": overkill})
	var card := BMRoundCards.get_def(round_card)
	if int(card.reward) > 0:
		lines.append({"label": BMLoc.m("%s bonus") % card.name, "value": int(card.reward)})
	# Compact Kit, Thrift: Refreshes left unused pay.
	var thrift := int(kit().get("thrift_credits", 0))
	if thrift > 0 and rs.refreshes_left > 0:
		lines.append({"label": BMLoc.mn("Thrift (%d unused Refresh)", "Thrift (%d unused Refreshes)", rs.refreshes_left) % rs.refreshes_left, "value": thrift * rs.refreshes_left})
	# Interest on the Credits held when the round ended (High Roller: Compound Interest).
	var cap := (BMRunConfig.HEAT_INTEREST_CAP if heat >= 3 else BMRunConfig.INTEREST_CAP) + int(kit().get("interest_bonus", 0))
	var interest := mini(cap, held / BMRunConfig.INTEREST_STEP)
	if interest > 0:
		lines.append({"label": BMLoc.m("Interest (%d held)") % held, "value": interest})
	# Scaling Jokers that grow when a round is won.
	var growth: Array = []
	if jokers.has("overachiever") and rs.score >= rs.target * BMJokers.OVERACHIEVER_RATIO:
		_grow_joker("overachiever", 1.0)
		growth.append(BMLoc.m("Overachiever grew to +%s Mult") % BMJokers._num(joker_value("overachiever")))
	if jokers.has("hot_streak") and not rs.refresh_used:
		_grow_joker("hot_streak", BMJokers.HOT_STREAK_STEP)
		growth.append(BMLoc.m("Hot Streak heated up to x%s Mult") % BMJokers._num(joker_value("hot_streak")))
	var drops: Array = []
	if round_card == "treasure_hunt" and not items_full():
		var tpool := BMConsumables.shop_pool()
		var titem: String = tpool[rng_shop.randi_range(0, tpool.size() - 1)]
		consumables.append(titem)
		drops.append(titem)
		growth.append(BMLoc.m("Treasure Hunt: found %s") % BMConsumables.get_def(titem).name)
	if round_card == "scholarship" and rs.last_family != "":
		family_levels[rs.last_family] = int(family_levels.get(rs.last_family, 0)) + 1
		growth.append(BMLoc.m("Scholarship: %s is now level %d") % [BMShapes.family(StringName(rs.last_family)).name, family_levels[rs.last_family]])
	for i in jokers.count("vending_machine"):
		if not items_full():
			var pool := BMConsumables.shop_pool()
			var item: String = pool[rng_shop.randi_range(0, pool.size() - 1)]
			consumables.append(item)
			drops.append(item)
			growth.append(BMLoc.m("Vending Machine dropped %s") % BMConsumables.get_def(item).name)
	if loan_debt > 0:
		var pay := mini(BMJokers.LOAN_INSTALLMENT, loan_debt)
		loan_debt -= pay
		lines.append({"label": BMLoc.m("Loan Shark repayment"), "value": -pay})
	var total := 0
	for l in lines:
		total += int(l.value)
	var before := credits
	credits = mini(BMRunConfig.CREDIT_CAP, credits + total)
	stats.rounds_won += 1
	last_round_result = {"round": round_number, "score": rs.score, "target": rs.target,
		"unused": unused, "credit_lines": lines, "credits_gained": credits - before,
		"boss": current_boss(), "interest": interest, "overkill": overkill, "events": growth, "drops": drops}
	phase = Phase.ROUND_RESULT


func _lose(reason: String) -> void:
	if phase == Phase.ROUND and jokers.has("insurance_policy"):
		# Insurance Policy: replay this round from the start without the free Refresh.
		_remove_joker_at(jokers.find("insurance_policy"))
		stats["insurance_claims"] = int(stats.get("insurance_claims", 0)) + 1
		_start_round(true)
		round_state.refreshes_left = 0
		round_state.insured = true
		_insurance_event = true
		return
	round_state.status = LOST
	phase = Phase.RUN_LOST
	end_reason = reason


## Overtime acts beyond the third draw their boss from the boss stream when first needed.
func _ensure_bosses(through_act: int) -> void:
	while bosses.size() < through_act:
		bosses.append(BMBosses.choose_overtime_boss(rng_boss, bosses[bosses.size() - 1]))


func _open_shop() -> void:
	_ensure_bosses(BMRunConfig.act_of(round_number + 1))
	phase = Phase.SHOP
	var reroll_base := BMRunConfig.HEAT_REROLL_BASE if heat >= 3 else BMRunConfig.REROLL_BASE
	shop = {"jokers": [], "consumables": [], "tools": [], "pieces": [], "reroll_cost": reroll_base, "crate": [],
		"round_cards": [], "round_pick": 0}
	if BMRunConfig.is_boss_round(round_number):
		shop.crate = _roll_crate()
	# Round cards for the next round (never before a boss): Standard plus two seeded twists.
	if not BMRunConfig.is_boss_round(round_number + 1):
		var twists := BMRoundCards.twists()
		var cards: Array = ["standard"]
		for i in 2:
			var k := rng_shop.randi_range(0, twists.size() - 1)
			cards.append(twists[k])
			twists.remove_at(k)
		shop.round_cards = cards
	_fill_shop_offers()


## Boss Crate: a Joker (uncommon or rare), an item, and a stack of Credits.
func _roll_crate() -> Array:
	var legendary_pct := 0
	if BMRunConfig.is_overtime(round_number):
		legendary_pct = BMRunConfig.CRATE_LEGENDARY_OVERTIME
	elif BMRunConfig.act_of(round_number) == 2:
		legendary_pct = BMRunConfig.CRATE_LEGENDARY_ACT2
	elif BMRunConfig.act_of(round_number) >= 3:
		legendary_pct = BMRunConfig.CRATE_LEGENDARY_ACT3
	var roll := rng_shop.randi_range(1, 100)
	var rarity := BMJokers.UNCOMMON
	if roll <= legendary_pct:
		rarity = BMJokers.LEGENDARY
	elif roll <= legendary_pct + BMRunConfig.CRATE_RARE:
		rarity = BMJokers.RARE
	var joker := _pick_joker(rarity, [])
	if joker == "":
		joker = _pick_joker(BMJokers.RARE, [])
	var pool := BMConsumables.shop_pool()
	var item: String = pool[rng_shop.randi_range(0, pool.size() - 1)]
	return [{"kind": "joker", "id": joker}, {"kind": "item", "id": item}, {"kind": "credits", "value": BMRunConfig.CRATE_CREDITS}]


## Takes one Boss Crate offer for free; the rest of the crate is gone.
func open_crate(i: int) -> Dictionary:
	if phase != Phase.SHOP:
		return _fail(BMLoc.m("The shop is closed."))
	var crate: Array = shop.get("crate", [])
	if i < 0 or i >= crate.size():
		return _fail(BMLoc.m("Nothing in the crate there."))
	var o: Dictionary = crate[i]
	match String(o.kind):
		"joker":
			if String(o.id) == "":
				return _fail(BMLoc.m("That offer is empty."))
			if rack_full():
				return _fail(BMLoc.m("Joker slots are full. Sell a Joker first."))
			_add_joker(String(o.id))
			_joker_joined(String(o.id))
		"item":
			if items_full():
				return _fail(BMLoc.m("Item slots are full. Use an item first."))
			consumables.append(String(o.id))
		"credits":
			add_credits(int(o.value))
	shop.crate = []
	history.append({"a": "crate", "i": i})
	return {"ok": true, "type": "crate", "offer": o}


func _fill_shop_offers() -> void:
	var next_act := BMRunConfig.act_of(round_number + 1)
	var weights: Array = BMRunConfig.rarity_weights(next_act)
	var offered: Array[String] = []
	for i in BMRunConfig.JOKER_OFFERS:
		var rarity := rng_shop.weighted_index(weights)
		var pick := _pick_joker(rarity, offered)
		if pick == "":
			for r in [BMJokers.RARE, BMJokers.UNCOMMON, BMJokers.COMMON]:
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
	var tool_offers: Array = []
	var tool_ids: Array = BMTools.WEIGHTS.keys()
	for i in BMRunConfig.TOOL_OFFERS:
		var tool_weights: Array = []
		for tid in tool_ids:
			var taken := false
			for o in tool_offers:
				if o.id == tid and tid != "schematic":
					taken = true
			if tid == "rack_extender" and joker_slots() >= BMRunConfig.MAX_JOKER_SLOTS:
				taken = true
			if next_act < BMTools.from_act(tid):
				taken = true
			if tid == "item_pouch" and consumable_slots() >= BMRunConfig.MAX_ITEM_SLOTS:
				taken = true
			if tid == "tuning_fork" and levelable_jokers().is_empty():
				taken = true
			tool_weights.append(0 if taken else int(BMTools.WEIGHTS[tid]))
		var id: String = tool_ids[rng_shop.weighted_index(tool_weights)]
		var offer := {"id": id, "family": ""}
		if id == "schematic":
			var fams: Array = []
			for p in bag:
				if not fams.has(String(p.family)):
					fams.append(String(p.family))
			fams.sort()
			offer.family = fams[rng_shop.randi_range(0, fams.size() - 1)]
		tool_offers.append(offer)
	shop.tools = tool_offers
	# From the shop after round 8 the pieces shelf becomes the Holo shelf.
	var piece_offers: Array = []
	var holo_offers: Array = []
	if holo_open():
		for i in BMRunConfig.HOLO_OFFERS:
			holo_offers.append(_roll_holo_offer(holo_offers))
	else:
		for i in BMRunConfig.PIECE_OFFERS:
			piece_offers.append(_roll_piece_offer())
	shop.pieces = piece_offers
	shop.holo = holo_offers


## A random piece for sale: any family (including Bar 5 and Square 3x3), any rotation and
## color, sometimes pre-upgraded. Price rises with upgrades and size.
func _roll_piece_offer() -> Dictionary:
	var fam_weights: Array = []
	for f in BMShapes.FAMILIES:
		fam_weights.append(int(f.weight) + 4)
	var fam: Dictionary = BMShapes.FAMILIES[rng_shop.weighted_index(fam_weights)]
	var rot := rng_shop.randi_range(0, BMShapes.rotations(fam.id).size() - 1)
	var color := rng_shop.randi_range(0, BMShapes.OFFER_COLOR_COUNT - 1)
	var material := ""
	var stamp := ""
	if rng_shop.randi_range(1, 100) <= 30:
		material = BMPieces.MATERIALS[rng_shop.randi_range(1, BMPieces.MATERIALS.size() - 1)]
	if rng_shop.randi_range(1, 100) <= 15:
		var stamps: Array = BMPieces.STAMP_DEFS.keys()
		stamp = stamps[rng_shop.randi_range(0, stamps.size() - 1)]
	var d := BMPieces.to_dict(BMPieces.make(-1, fam.id, rot, color, material, stamp))
	d.cost = 2 + (1 if material != "" else 0) + (1 if stamp != "" else 0) + (1 if fam.cells.size() >= 5 else 0)
	return d


## A random Joker of `rarity` (never one in `exclude`, a locked one, or a unique one owned).
## Jokers you own are BMRunConfig.OWNED_JOKER_WEIGHT / NEW_JOKER_WEIGHT as likely as the rest.
func _pick_joker(rarity: int, exclude: Array[String], rng: BMRngStream = null) -> String:
	if rng == null:
		rng = rng_shop
	var candidates: Array[String] = []
	var weights: Array = []
	for id in BMJokers.ids_of_rarity(rarity):
		if exclude.has(id) or locked_jokers.has(id):
			continue
		if BMJokers.is_unique(id) and jokers.has(id):
			continue
		candidates.append(id)
		weights.append(BMRunConfig.OWNED_JOKER_WEIGHT if jokers.has(id) else BMRunConfig.NEW_JOKER_WEIGHT)
	if candidates.is_empty():
		return ""
	return candidates[rng.weighted_index(weights)]


## A Joker just joined the rack (shop, crate, Lucky Draw, Legend Crate): one-time effects.
func _joker_joined(id: String) -> void:
	if id == "loan_shark":
		add_credits(BMJokers.LOAN_CREDITS)
		loan_debt += BMJokers.LOAN_TOTAL


# --- The Holo shelf (BMHolo) ---------------------------------------------------------------

## The shop in front of the player shows the Holo shelf (from the shop after round 8).
func holo_open() -> bool:
	return round_number >= BMRunConfig.HOLO_FROM_ROUND


## Why a Holo card cannot apply to the current rack ("" = it can).
func holo_blocked(offer: Dictionary) -> String:
	match String(offer.get("id", "")):
		"negative_film":
			if _trait_count("negative") >= BMHolo.MAX_NEGATIVE:
				return BMLoc.m("Your rack already has %d Negative Jokers.") % BMHolo.MAX_NEGATIVE
			if _negative_candidates().is_empty():
				return BMLoc.m("No Joker to turn Negative.")
		"again_seal":
			if _trait_count("again") >= BMHolo.MAX_AGAIN:
				return BMLoc.m("Your rack already has %d AGAIN Jokers.") % BMHolo.MAX_AGAIN
			if _again_candidates().is_empty():
				return BMLoc.m("No scoring Joker without AGAIN.")
		"master_tuning":
			if levelable_jokers().is_empty():
				return BMLoc.m("No scoring Joker can gain a level.")
		"legend_crate":
			if String(offer.get("joker", "")) == "" or jokers.has(String(offer.joker)):
				return BMLoc.m("You already own that Legendary.")
			if rack_full():
				return BMLoc.m("Joker slots are full. Sell a Joker first.")
		"hologram":
			if _trait_count("negative") >= BMHolo.MAX_NEGATIVE:
				return BMLoc.m("Your rack already has %d Negative Jokers.") % BMHolo.MAX_NEGATIVE
			if _hologram_candidates().is_empty():
				return BMLoc.m("No Joker to copy.")
			if jokers.size() >= BMRunConfig.MAX_RACK:
				return BMLoc.m("Your rack is full.")
	return ""


## What a Holo shelf offer costs now.
func holo_price(offer: Dictionary) -> int:
	var id := String(offer.get("id", ""))
	return BMHolo.price(id, int(holo_bought.get(id, 0)))


func _trait_count(key: String) -> int:
	var n := 0
	for i in jokers.size():
		if bool(joker_mod(i).get(key, false)):
			n += 1
	return n


func _negative_candidates() -> Array[int]:
	var out: Array[int] = []
	for i in jokers.size():
		if not bool(joker_mod(i).get("negative", false)):
			out.append(i)
	return out


func _again_candidates() -> Array[int]:
	var out: Array[int] = []
	for i in jokers.size():
		if BMHolo.is_scoring(jokers[i]) and not bool(joker_mod(i).get("again", false)):
			out.append(i)
	return out


func _hologram_candidates() -> Array[int]:
	var out: Array[int] = []
	for i in jokers.size():
		if not BMJokers.is_unique(jokers[i]) and jokers[i] != "loan_shark":
			out.append(i)
	return out


## One Holo shelf offer ({"id", "joker"}), never the same card twice on a shelf.
func _roll_holo_offer(taken: Array) -> Dictionary:
	var ids: Array = []
	var weights: Array = []
	for d in BMHolo.CATALOG:
		var dup := false
		for o in taken:
			if String(o.id) == String(d.id):
				dup = true
		if d.id == "legend_crate" and _unowned_legendaries().is_empty():
			dup = true
		ids.append(String(d.id))
		weights.append(0 if dup else int(d.weight))
	var id: String = ids[rng_shop.weighted_index(weights)]
	var offer := {"id": id, "joker": ""}
	if id == "legend_crate":
		var pool := _unowned_legendaries()
		offer.joker = pool[rng_shop.randi_range(0, pool.size() - 1)]
	return offer


func _unowned_legendaries() -> Array[String]:
	var out: Array[String] = []
	for id in BMJokers.ids_of_rarity(BMJokers.LEGENDARY):
		if not jokers.has(id) and not locked_jokers.has(id):
			out.append(id)
	return out


## Buys a Holo card and applies it at once. Random targets use the shop stream.
func buy_holo(i: int) -> Dictionary:
	if phase != Phase.SHOP:
		return _fail(BMLoc.m("The shop is closed."))
	var offers: Array = shop.get("holo", [])
	if i < 0 or i >= offers.size() or Dictionary(offers[i]).is_empty():
		return _fail(BMLoc.m("That offer is gone."))
	var o: Dictionary = offers[i]
	var price := holo_price(o)
	if credits < price:
		return _fail(BMLoc.m("Not enough Credits."))
	var blocked := holo_blocked(o)
	if blocked != "":
		return _fail(blocked)
	_sync_mods()
	var result := {"ok": true, "type": "buy_holo", "item": String(o.id), "price": price, "events": []}
	match String(o.id):
		"negative_film":
			var c := _negative_candidates()
			var k: int = c[rng_shop.randi_range(0, c.size() - 1)]
			var m: Dictionary = joker_mods[k].duplicate()
			m.negative = true
			joker_mods[k] = m
			result.joker = jokers[k]
			result.index = k
			result.events.append(BMLoc.m("%s turned Negative: it takes no slot") % BMJokers.get_def(jokers[k]).name)
		"again_seal":
			var c := _again_candidates()
			var k: int = c[rng_shop.randi_range(0, c.size() - 1)]
			var m: Dictionary = joker_mods[k].duplicate()
			m.again = true
			joker_mods[k] = m
			result.joker = jokers[k]
			result.index = k
			result.events.append(BMLoc.m("%s gained AGAIN") % BMJokers.get_def(jokers[k]).name)
		"master_schematic":
			var fams: Array = []
			for p in bag:
				if not fams.has(String(p.family)):
					fams.append(String(p.family))
			for f in fams:
				family_levels[f] = int(family_levels.get(f, 0)) + 1
			result.events.append(BMLoc.mn("%d shape family gained a level", "%d shape families gained a level", fams.size()) % fams.size())
		"master_tuning":
			var up := levelable_jokers()
			for k in up:
				var m: Dictionary = joker_mods[k].duplicate()
				m.level = int(m.get("level", 0)) + 1
				joker_mods[k] = m
			result.events.append(BMLoc.mn("%d Joker gained a level", "%d Jokers gained a level", up.size()) % up.size())
		"legend_crate":
			_add_joker(String(o.joker))
			_joker_joined(String(o.joker))
			result.joker = String(o.joker)
			result.events.append(BMLoc.m("%s joined your rack") % BMJokers.get_def(String(o.joker)).name)
		"hologram":
			var c := _hologram_candidates()
			var k: int = c[rng_shop.randi_range(0, c.size() - 1)]
			var m: Dictionary = joker_mods[k].duplicate()
			m.negative = true
			_add_joker(jokers[k], m)
			result.joker = jokers[k]
			result.index = jokers.size() - 1
			result.events.append(BMLoc.m("Hologram: a Negative copy of %s") % BMJokers.get_def(jokers[k]).name)
	credits -= price
	offers[i] = {}
	holo_bought[String(o.id)] = int(holo_bought.get(String(o.id), 0)) + 1
	stats["holo_bought"] = int(stats.get("holo_bought", 0)) + 1
	history.append({"a": "buy_holo", "i": i})
	return result


# --- Serialization -------------------------------------------------------------------------

## Joker traits for saves: one entry per Joker, only the traits it has.
func _mods_data() -> Array:
	_sync_mods()
	var out: Array = []
	for m in joker_mods:
		var e := {}
		if int(m.get("level", 0)) > 0:
			e.level = int(m.level)
		if bool(m.get("negative", false)):
			e.negative = true
		if bool(m.get("again", false)):
			e.again = true
		out.append(e)
	return out


func to_dict(include_history: bool = true) -> Dictionary:
	var tray_data: Array = []
	for s in tray:
		tray_data.append(BMPieces.to_dict(s))
	var bag_data: Array = []
	for p in bag:
		bag_data.append(BMPieces.to_dict(p))
	return {
		"schema": SCHEMA_VERSION,
		"seed": run_seed, "kit": kit_id,
		"rng": {"shapes": rng_shapes.get_state(), "shop": rng_shop.get_state(), "boss": rng_boss.get_state(),
			"items": rng_items.get_state()},
		"phase": PHASE_NAMES[phase], "round": round_number, "credits": credits,
		"jokers": jokers.duplicate(), "joker_mods": _mods_data(), "consumables": consumables.duplicate(), "jokers_sold": jokers_sold,
		"extra_item_slots": extra_item_slots, "holo_bought": holo_bought.duplicate(),
		"bosses": bosses.duplicate(), "board": board.to_dict(), "tray": tray_data,
		"bag": bag_data, "draw_pile": draw_pile.duplicate(), "discard_pile": discard_pile.duplicate(),
		"next_uid": next_uid, "family_levels": family_levels.duplicate(), "loan_debt": loan_debt,
		"round_state": round_state.to_dict(), "shop": shop.duplicate(true),
		"history": history.duplicate(true) if include_history else [], "stats": stats.duplicate(),
		"last_round_result": last_round_result.duplicate(true), "end_reason": end_reason,
		"overtime": overtime, "machine_broken": machine_broken, "recorded": recorded.duplicate(),
		"joker_state": joker_state.duplicate(), "extra_slots": extra_slots,
		"heat": heat, "daily": daily, "round_card": round_card, "locked_jokers": locked_jokers.duplicate(),
		"custom_seed": custom_seed,
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
	# Schema 9 added the item stream; older saves start it from the seed.
	if d.rng.has("items"):
		run.rng_items = BMRngStream.new()
		run.rng_items.set_state(d.rng.items)
	else:
		run.rng_items = BMRngStream.new(int(d.seed), "items")
	run.phase = PHASE_NAMES.find(String(d.phase))
	run.round_number = int(d.round)
	run.credits = int(d.credits)
	run.jokers.assign(d.jokers)
	run.joker_mods = []
	for m in d.get("joker_mods", []):
		run.joker_mods.append(_integral(Dictionary(m).duplicate()) if m is Dictionary else {})
	run._sync_mods()
	run.consumables.assign(d.consumables)
	run.extra_item_slots = int(d.get("extra_item_slots", 0))
	run.holo_bought = _integral(Dictionary(d.get("holo_bought", {})).duplicate())
	run.jokers_sold = int(d.jokers_sold)
	run.bosses.assign(d.bosses)
	run.board = BMBoard.from_dict(d.board)
	run.tray = []
	for s in d.tray:
		run.tray.append(BMPieces.from_dict(s))
	run.bag = []
	for p in d.bag:
		run.bag.append(BMPieces.from_dict(p))
	run.draw_pile = _integral(d.draw_pile.duplicate())
	run.discard_pile = _integral(d.discard_pile.duplicate())
	run.next_uid = int(d.next_uid)
	run.family_levels = _integral(d.family_levels.duplicate())
	run.loan_debt = int(d.get("loan_debt", 0))
	run.round_state = RoundState.from_dict(d.round_state)
	run.shop = _integral(d.shop.duplicate(true))
	run.history = _integral(d.history.duplicate(true))
	run.stats = {}
	for k in d.stats:
		run.stats[k] = int(d.stats[k])
	run.last_round_result = _integral(d.last_round_result.duplicate(true))
	run.end_reason = String(d.end_reason)
	run.overtime = bool(d.get("overtime", false))
	run.machine_broken = bool(d.get("machine_broken", false))
	run.recorded = _integral(d.get("recorded", {}).duplicate())
	run.joker_state = {}
	var js: Dictionary = d.get("joker_state", {})
	for k in js:
		run.joker_state[String(k)] = float(js[k])
	run.extra_slots = int(d.get("extra_slots", 0))
	run.heat = int(d.get("heat", 0))
	run.daily = String(d.get("daily", ""))
	run.custom_seed = bool(d.get("custom_seed", false))
	run.round_card = String(d.get("round_card", "standard"))
	run.locked_jokers.assign(d.get("locked_jokers", []))
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
