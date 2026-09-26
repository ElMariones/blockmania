class_name BMConsumables
extends RefCounted
## Consumable catalog (GDD §7 "Consumables"). One-time, player-triggered, used between
## placements. `target` names the extra player choice an item needs (the "use" action carries
## it): "cells" (up to 2 occupied cells), "cell" (one center cell), "color" (a block color),
## "slot" (a tray slot), "slot_color", "slot_shape" (a tray slot plus a color or a Blueprint
## choice). Board tools remove cells without scoring: they never count as a clear, never trigger
## Jokers or refills (docs/design/round_play_update.md §3).

const CATALOG := [ # i18n: name, text
	{"id": "polish", "name": "Polish", "cost": 3, "target": "", "text": "Add +40 Chips per round number to the next placement this round."},
	{"id": "spark", "name": "Spark", "cost": 3, "target": "", "text": "Add +1 Mult per act to the next placement this round."},
	{"id": "eraser", "name": "Eraser", "cost": 4, "target": "cells", "text": "Remove up to three blocks of your choice from the board."},
	{"id": "second_tray", "name": "Second Tray", "cost": 3, "target": "", "text": "Refresh the current tray without spending the round's free Refresh."},
	{"id": "extra_turn", "name": "Extra Turn", "cost": 5, "target": "", "text": "Gain two placements this round (maximum 20 remaining)."},
	{"id": "lucky_paint", "name": "Lucky Paint", "cost": 3, "target": "slot_color", "text": "Recolor one tray piece to a color of your choice. Its shape is unchanged."},
	{"id": "color_purge", "name": "Color Purge", "cost": 5, "target": "color", "text": "Remove every block of one color from the board. Stone is immune."},
	{"id": "emergency_brick", "name": "Emergency Brick", "cost": 4, "target": "slot", "text": "Throw a brick at a tray slot: it becomes a temporary one-block piece. A piece it hits goes to the discard pile."},
	# --- Engine update (2026-09-24) ---
	{"id": "overclock", "name": "Turbo", "cost": 5, "target": "", "text": "The next placement this round gets x2 Mult."},
	{"id": "tune_up", "name": "Tune-Up", "cost": 4, "target": "slot", "text": "Level up the shape family of a tray piece, like a Schematic (+25 Chips, +0.25 Mult per level)."},
	{"id": "coin_roll", "name": "Coin Roll", "cost": 3, "target": "", "text": "Gain Credits equal to the round number (max 12)."},
	# --- Study follow-up (2026-09-26): chance items and a line maker ---
	{"id": "lucky_draw", "name": "Lucky Draw", "cost": 3, "target": "", "text": "1 in 5 chance: a random Uncommon or better Joker joins your rack. Needs a free Joker slot."},
	{"id": "mystery_stamp", "name": "Mystery Stamp", "cost": 3, "target": "", "text": "A random stamp goes on a random unstamped piece in your bag, for good."},
	{"id": "double_down", "name": "Double Down", "cost": 3, "target": "", "text": "1 in 5 chance to double your Credits (at most +20). Otherwise nothing."},
	{"id": "phantom_line", "name": "Phantom Line", "cost": 4, "target": "", "text": "The next placement that clears a line counts one extra line (Chips, Mult, refills and Jokers)."},
	# --- Retired 2026-09-26 (merged into Eraser, Second Tray, Coin Roll and Emergency Brick).
	# Never offered again; one held in an older save still works.
	{"id": "punch", "name": "Punch", "cost": 4, "target": "cell", "retired": true, "text": "Smash a plus-shaped area: remove up to 5 blocks around the cell you hit."},
	{"id": "coffee_break", "name": "Coffee Break", "cost": 3, "target": "", "retired": true, "text": "+1 Refresh this round."},
	{"id": "cash_out", "name": "Cash Out", "cost": 3, "target": "", "retired": true, "text": "Gain 4 Credits after this round if it is won."},
	{"id": "blueprint", "name": "Blueprint", "cost": 4, "target": "slot_shape", "retired": true, "text": "Swap one tray piece for a temporary 1-3 cell piece you choose."},
]

## Blueprint choices: [family, rotation]. Order is the picker order.
const BLUEPRINT_CHOICES := [["single", 0], ["bar2", 0], ["bar2", 1], ["bar3", 0], ["bar3", 1],
	["l3", 0], ["l3", 1], ["l3", 2], ["l3", 3]]
const ERASER_CELLS := 3
## Punch hits the chosen cell and its four neighbours.
const PUNCH_OFFSETS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

const MAX_PLACEMENTS := 20
const OVERCLOCK_X_MULT := 2.0
const COIN_ROLL_MAX := 12
## Boosts scale with the run (release study 2026-09-26: flat +100 Chips / +1 Mult fell from
## 12-14% of a target in act 1 to 4-8% in act 3).
const POLISH_CHIPS_PER_ROUND := 40
const SPARK_MULT_PER_ACT := 1.0
## Chance items (rolled on the run's item stream).
const LUCKY_DRAW_ONE_IN := 5
## Lucky Draw's Joker rarity weights [common, uncommon, rare, legendary].
const LUCKY_DRAW_WEIGHTS := [0, 60, 36, 4]
const DOUBLE_DOWN_ONE_IN := 5
const DOUBLE_DOWN_MAX := 20

static var _by_id := {}


static func get_def(id: String) -> Dictionary:
	if _by_id.is_empty():
		for d in CATALOG:
			_by_id[d.id] = d
	return _by_id.get(id, {})


static func display_name(id: String) -> String:
	return BMLoc.t(String(get_def(id).get("name", id)))


static func display_text(id: String) -> String:
	return BMLoc.t(String(get_def(id).get("text", "")))


static func cost(id: String) -> int:
	return int(get_def(id).get("cost", 3))


## Selling an unused item pays half its price, rounded down, and at least 1 Credit.
static func sell_value(id: String) -> int:
	return maxi(1, cost(id) / 2)


static func is_implemented(id: String) -> bool:
	return bool(get_def(id).get("implemented", true))


static func target_kind(id: String) -> String:
	return String(get_def(id).get("target", ""))


## Cells a Punch at `center` would hit (inside the board; occupied or not).
static func punch_cells(center: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for o: Vector2i in PUNCH_OFFSETS:
		if BMBoard.in_bounds(center + o):
			out.append(center + o)
	return out


## Items the shop, crates, Treasure Hunt and the Vending Machine can hand out.
static func shop_pool() -> Array[String]:
	var out: Array[String] = []
	for d in CATALOG:
		if bool(d.get("implemented", true)) and not bool(d.get("retired", false)):
			out.append(d.id)
	return out


static func is_retired(id: String) -> bool:
	return bool(get_def(id).get("retired", false))


## Polish's Chips in round `round_number`.
static func polish_chips(round_number: int) -> int:
	return POLISH_CHIPS_PER_ROUND * maxi(1, round_number)


## Spark's Mult in act `act`.
static func spark_mult(act: int) -> float:
	return SPARK_MULT_PER_ACT * maxi(1, act)


## What an item is worth right now, shown on its card before use ("" when it has no number).
static func live_text(id: String, run: BMRun) -> String:
	if run == null:
		return ""
	match id:
		"polish":
			return BMLoc.t("+%s Chips") % BMUI.fmt_int(polish_chips(run.round_number))
		"spark":
			return BMLoc.t("+%s Mult") % BMJokers._num(spark_mult(run.act()))
		"coin_roll":
			return BMLoc.tn("+%d Credit", "+%d Credits", mini(COIN_ROLL_MAX, run.round_number)) % mini(COIN_ROLL_MAX, run.round_number)
		"double_down":
			return BMLoc.t("Win +%d") % mini(DOUBLE_DOWN_MAX, run.credits)
		"lucky_draw":
			var free := maxi(0, run.joker_slots() - run.occupied_slots())
			return BMLoc.tn("%d free Joker slot", "%d free Joker slots", free) % free
		"mystery_stamp":
			var n := run.unstamped_uids().size()
			return BMLoc.tn("%d unstamped piece", "%d unstamped pieces", n) % n
	return ""
