class_name BMConsumables
extends RefCounted
## Consumable catalog (GDD §7 "Consumables"). One-time, player-triggered, used between
## placements. `target` names the extra player choice an item needs; items whose choice UI
## does not exist yet are `implemented = false` and are not offered in the shop.

const CATALOG := [
	{"id": "polish", "name": "Polish", "cost": 3, "target": "", "text": "Add +100 Chips to the next placement this round."},
	{"id": "spark", "name": "Spark", "cost": 3, "target": "", "text": "Add +1 Mult to the next placement this round."},
	{"id": "eraser", "name": "Eraser", "cost": 4, "target": "cells", "implemented": false, "text": "Remove up to two occupied cells of your choice."},
	{"id": "second_tray", "name": "Second Tray", "cost": 3, "target": "", "text": "Refresh the current tray without spending the round's free Refresh."},
	{"id": "extra_turn", "name": "Extra Turn", "cost": 5, "target": "", "text": "Gain two placements this round (maximum 20 remaining)."},
	{"id": "lucky_paint", "name": "Lucky Paint", "cost": 3, "target": "shape_color", "implemented": false, "text": "Recolor one tray shape to a chosen color. Geometry is unchanged."},
	{"id": "blueprint", "name": "Blueprint", "cost": 4, "target": "shape_pick", "implemented": false, "text": "Replace one tray shape with a chosen 1-3 cell shape from a short list."},
	{"id": "cash_out", "name": "Cash Out", "cost": 3, "target": "", "text": "Gain 4 Credits after this round if it is won."},
]

const MAX_PLACEMENTS := 20

static var _by_id := {}


static func get_def(id: String) -> Dictionary:
	if _by_id.is_empty():
		for d in CATALOG:
			_by_id[d.id] = d
	return _by_id.get(id, {})


static func cost(id: String) -> int:
	return int(get_def(id).get("cost", 3))


static func is_implemented(id: String) -> bool:
	return bool(get_def(id).get("implemented", true))


static func shop_pool() -> Array[String]:
	var out: Array[String] = []
	for d in CATALOG:
		if bool(d.get("implemented", true)):
			out.append(d.id)
	return out
