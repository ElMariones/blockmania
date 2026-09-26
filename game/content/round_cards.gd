class_name BMRoundCards
extends RefCounted
## Round cards (GDD §22.2): before every non-boss round the shop offers Standard plus two
## seeded twists, and the player picks one. The choice is a run command (`pick_round`), saved
## with the shop, and applied when the round starts. Values are provisional.

const CATALOG := [ # i18n: name, text
	{"id": "standard", "name": "Standard", "reward": 0,
		"text": "No twist."},
	{"id": "gold_rush", "name": "Gold Rush", "reward": 1,
		"text": "Six Gold blocks start on the board (+1 Credit per Gold cell cleared). +1 Credit if you win."},
	{"id": "tight_budget", "name": "Tight Budget", "reward": 5,
		"text": "Five fewer placements. +5 Credits if you win."},
	{"id": "rush_hour", "name": "Rush Hour", "reward": 3,
		"text": "Target x0.8, but no Refresh this round. +3 Credits if you win."},
	{"id": "double_or_nothing", "name": "Double or Nothing", "reward": 7,
		"text": "Target x1.7. +7 Credits if you win."},
	{"id": "mult_fever", "name": "Mult Fever", "reward": 0,
		"text": "Every placement gets +1 Mult. Target x1.5."},
	{"id": "treasure_hunt", "name": "Treasure Hunt", "reward": 0,
		"text": "Win to find a random item (needs a free item slot). Target x1.35."},
	{"id": "scholarship", "name": "Scholarship", "reward": 0,
		"text": "Win to level up the family of the last piece you place. Target x1.4."},
]

const GOLD_RUSH_CELLS := 6
## Release study 2026-09-26: twists were cleared as often as Standard (96%) and picking them
## lifted wins 79% -> 89%. They are real bets now: harsher rules, smaller sure rewards.
const TIGHT_BUDGET_PLACEMENTS := 5

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
			return 1.7
		"mult_fever":
			return 1.5
		"treasure_hunt":
			return 1.35
		"scholarship":
			return 1.4
	return 1.0


## The ids that can be offered as twists (everything but Standard).
static func twists() -> Array[String]:
	var out: Array[String] = []
	for d in CATALOG:
		if d.id != "standard":
			out.append(String(d.id))
	return out
