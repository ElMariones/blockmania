class_name BMRoundCards
extends RefCounted
## Round cards (GDD §22.2): before every non-boss round the shop offers Standard plus two
## seeded twists, and the player picks one. The choice is a run command (`pick_round`), saved
## with the shop, and applied when the round starts. Values are provisional.

const CATALOG := [
	{"id": "standard", "name": "Standard", "reward": 0,
		"text": "No twist."},
	{"id": "gold_rush", "name": "Gold Rush", "reward": 2,
		"text": "Six Gold blocks start on the board (+1 Credit per Gold cell cleared). +2 Credits if you win."},
	{"id": "tight_budget", "name": "Tight Budget", "reward": 4,
		"text": "Three fewer placements. +4 Credits if you win."},
	{"id": "rush_hour", "name": "Rush Hour", "reward": 0,
		"text": "Target x0.8, but no Refresh this round."},
	{"id": "double_or_nothing", "name": "Double or Nothing", "reward": 6,
		"text": "Target x1.4. +6 Credits if you win."},
	{"id": "mult_fever", "name": "Mult Fever", "reward": 0,
		"text": "Every placement gets +1 Mult. Target x1.3."},
	{"id": "treasure_hunt", "name": "Treasure Hunt", "reward": 0,
		"text": "Win to find a random item (needs a free item slot). Target x1.15."},
	{"id": "scholarship", "name": "Scholarship", "reward": 0,
		"text": "Win to level up the family of the last piece you place. Target x1.2."},
]

const GOLD_RUSH_CELLS := 6
const TIGHT_BUDGET_PLACEMENTS := 3

static var _by_id := {}


static func get_def(id: String) -> Dictionary:
	if _by_id.is_empty():
		for d in CATALOG:
			_by_id[d.id] = d
	return _by_id.get(id, CATALOG[0])


## Target multiplier of a round card.
static func target_mult(id: String) -> float:
	match id:
		"rush_hour":
			return 0.8
		"double_or_nothing":
			return 1.4
		"mult_fever":
			return 1.3
		"treasure_hunt":
			return 1.15
		"scholarship":
			return 1.2
	return 1.0


## The ids that can be offered as twists (everything but Standard).
static func twists() -> Array[String]:
	var out: Array[String] = []
	for d in CATALOG:
		if d.id != "standard":
			out.append(String(d.id))
	return out
