class_name BMRunConfig
extends RefCounted
## Run structure, targets, economy, and Kits (GDD §5 "Round targets", §6). All numbers provisional.

const ROUND_COUNT := 12
const ROUNDS_PER_ACT := 4
const TARGETS := [450, 650, 850, 1150, 1600, 2100, 2800, 3700, 4700, 6000, 7500, 10000]

# Base scoring (GDD §5 "Base scoring event").
const CHIPS_PER_CELL := 10
const CHIPS_PER_LINE := 100
const CHIPS_PER_EXTRA_LINE := 40
const CHIPS_PER_COMBO := 25
const COMBO_CAP := 4
const MAX_CLEAR_WAVES := 5

# Placement budget (GDD §5 "Placements and refills"): every completed line gives back this many
# placements, never above the round's starting count (Kit + Long Game, or a boss limit).
const REFILL_PER_LINE := 1

# Economy (GDD §6 "Credits and shop").
const WIN_CREDITS := 3
const UNUSED_PLACEMENT_BONUS_CAP := 3
const BOSS_CREDITS := 2
const CREDIT_CAP := 99
const JOKER_OFFERS := 3
const CONSUMABLE_OFFERS := 2
const CONSUMABLE_SLOTS := 2
const TOOL_OFFERS := 2
const PIECE_OFFERS := 2
const REROLL_BASE := 2
const SPARE_PARTS_CREDITS := 2
const CASH_OUT_CREDITS := 4

## Rarity weights [common, uncommon, rare] per act: 65/30/5 shifting to 40/40/20 by act 3.
const RARITY_WEIGHTS := [[65, 30, 5], [53, 35, 12], [40, 40, 20]]

const KITS := [
	{"id": "standard", "name": "Standard Kit", "joker_slots": 5, "refreshes": 1, "placements": 15, "credits": 0,
		"text": "5 Joker slots, 1 Refresh, 15 placements per round.", "unlock": ""},
	{"id": "compact", "name": "Compact Kit", "joker_slots": 4, "refreshes": 2, "placements": 15, "credits": 0,
		"text": "1 extra Refresh each round, but only 4 Joker slots.", "unlock": "Clear 100 total lines across runs."},
	{"id": "high_roller", "name": "High Roller Kit", "joker_slots": 5, "refreshes": 1, "placements": 14, "credits": 4,
		"text": "Start with 4 Credits, but 14 placements per round.", "unlock": "Win a standard run."},
]


static func target(round_number: int) -> int:
	return TARGETS[clampi(round_number, 1, ROUND_COUNT) - 1]


static func act_of(round_number: int) -> int:
	return (round_number - 1) / ROUNDS_PER_ACT + 1


static func is_boss_round(round_number: int) -> bool:
	return round_number % ROUNDS_PER_ACT == 0


static func kit(id: String) -> Dictionary:
	for k in KITS:
		if k.id == id:
			return k
	return KITS[0]
