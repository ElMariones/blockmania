class_name BMConsumables
extends RefCounted
## Consumable catalog (GDD §7 "Consumables"). One-time, player-triggered, used between
## placements. `target` names the extra player choice an item needs (the "use" action carries
## it): "cells" (up to 2 occupied cells), "cell" (one center cell), "color" (a block color),
## "slot" (a tray slot), "slot_color", "slot_shape" (a tray slot plus a color or a Blueprint
## choice). Board tools remove cells without scoring: they never count as a clear, never trigger
## Jokers or refills (docs/design/round_play_update.md §3).

const CATALOG := [ # i18n: name, text
	{"id": "polish", "name": "Polish", "cost": 3, "target": "", "text": "Add +100 Chips to the next placement this round."},
	{"id": "spark", "name": "Spark", "cost": 3, "target": "", "text": "Add +1 Mult to the next placement this round."},
	{"id": "eraser", "name": "Eraser", "cost": 4, "target": "cells", "text": "Remove up to two blocks of your choice from the board."},
	{"id": "second_tray", "name": "Second Tray", "cost": 3, "target": "", "text": "Refresh the current tray without spending the round's free Refresh."},
	{"id": "extra_turn", "name": "Extra Turn", "cost": 5, "target": "", "text": "Gain two placements this round (maximum 20 remaining)."},
	{"id": "lucky_paint", "name": "Lucky Paint", "cost": 3, "target": "slot_color", "text": "Recolor one tray piece to a color of your choice. Its shape is unchanged."},
	{"id": "blueprint", "name": "Blueprint", "cost": 4, "target": "slot_shape", "text": "Swap one tray piece for a temporary 1-3 cell piece you choose."},
	{"id": "cash_out", "name": "Cash Out", "cost": 3, "target": "", "text": "Gain 4 Credits after this round if it is won."},
	{"id": "punch", "name": "Punch", "cost": 4, "target": "cell", "text": "Smash a plus-shaped area: remove up to 5 blocks around the cell you hit."},
	{"id": "color_purge", "name": "Color Purge", "cost": 5, "target": "color", "text": "Remove every block of one color from the board. Stone is immune."},
	{"id": "emergency_brick", "name": "Emergency Brick", "cost": 4, "target": "slot", "text": "Throw a brick at a tray slot: it becomes a temporary one-block piece. A piece it hits goes to the discard pile."},
	# --- Engine update (2026-09-24) ---
	{"id": "overclock", "name": "Turbo", "cost": 5, "target": "", "text": "The next placement this round gets x2 Mult."},
	{"id": "tune_up", "name": "Tune-Up", "cost": 4, "target": "slot", "text": "Level up the shape family of a tray piece, like a Schematic (+25 Chips, +0.25 Mult per level)."},
	{"id": "coffee_break", "name": "Coffee Break", "cost": 3, "target": "", "text": "+1 Refresh this round."},
	{"id": "coin_roll", "name": "Coin Roll", "cost": 3, "target": "", "text": "Gain Credits equal to the round number (max 12)."},
]

## Blueprint choices: [family, rotation]. Order is the picker order.
const BLUEPRINT_CHOICES := [["single", 0], ["bar2", 0], ["bar2", 1], ["bar3", 0], ["bar3", 1],
	["l3", 0], ["l3", 1], ["l3", 2], ["l3", 3]]
const ERASER_CELLS := 2
## Punch hits the chosen cell and its four neighbours.
const PUNCH_OFFSETS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

const MAX_PLACEMENTS := 20
const OVERCLOCK_X_MULT := 2.0
const COIN_ROLL_MAX := 12

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


static func shop_pool() -> Array[String]:
	var out: Array[String] = []
	for d in CATALOG:
		if bool(d.get("implemented", true)):
			out.append(d.id)
	return out
