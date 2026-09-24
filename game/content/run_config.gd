class_name BMRunConfig
extends RefCounted
## Run structure, targets, economy, and Kits (GDD §5 "Round targets", §6). All numbers provisional.

const ROUND_COUNT := 12
const ROUNDS_PER_ACT := 4
const TARGETS := [450, 650, 850, 1150, 1600, 2100, 2800, 3700, 4700, 6000, 7500, 10000]

# Overtime (GDD §19): after the round-12 win the player may keep going. Rounds continue in acts
# of four with a boss every fourth round; the target of overtime round 12+k is
# TARGETS[-1] * OVERTIME_BASE^k * (1 + OVERTIME_CURVE * k^2), rounded to two significant digits.
const OVERTIME_BASE := 1.6
const OVERTIME_CURVE := 0.08
## The scoring machine's limit (safe for exact JSON numbers). A placement worth this much or more
## "breaks the machine": it scores exactly SCORE_CAP and ends the run as a legendary win.
const SCORE_CAP := 1_000_000_000_000_000
const SCORE_CAP_TEXT := "1,000,000,000,000,000"

# Base scoring (GDD §5 "Base scoring event").
const CHIPS_PER_CELL := 10
const CHIPS_PER_LINE := 100
const CHIPS_PER_EXTRA_LINE := 40
const CHIPS_PER_COMBO := 25
const COMBO_CAP := 4
## Non-clearing placements the combo survives before it resets (0 = resets on any miss).
const COMBO_GRACE := 1
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
## Boss Crate (docs/design/round_play_update.md §4): after a boss, pick 1 of 3 for free.
const CRATE_CREDITS := 6

## Rarity weights [common, uncommon, rare] per act: 65/30/5 shifting to 40/40/20 by act 3.
const RARITY_WEIGHTS := [[65, 30, 5], [53, 35, 12], [40, 40, 20]]

## Kits (GDD §6 "Starting Kits"; docs/design/round_play_update.md §4). `bag` names the starter
## bag in BMPieces.STARTER_BAGS. `unlock` is the player-facing requirement and `need` the
## lifetime profile counter that satisfies it (BMSaveStore profile); "" = always available.
const KITS := [
	{"id": "standard", "name": "Standard Kit", "joker_slots": 5, "refreshes": 1, "placements": 15, "credits": 0, "bag": "standard",
		"text": "5 Joker slots, 1 Refresh, 15 placements per round. The 24-piece starter bag.", "unlock": "", "need": {}},
	{"id": "compact", "name": "Compact Kit", "joker_slots": 4, "refreshes": 2, "placements": 15, "credits": 0, "bag": "compact",
		"text": "1 extra Refresh each round, but only 4 Joker slots. An 18-piece bag with no Singles.", "unlock": "Clear 100 lines across runs.", "need": {"lines": 100}},
	{"id": "high_roller", "name": "High Roller Kit", "joker_slots": 5, "refreshes": 1, "placements": 14, "credits": 4, "bag": "standard",
		"text": "Start with 4 Credits, but 14 placements per round.", "unlock": "Win a standard run.", "need": {"wins": 1}},
	{"id": "chunky", "name": "Chunky Kit", "joker_slots": 5, "refreshes": 1, "placements": 15, "credits": 0, "bag": "chunky",
		"text": "A 20-piece bag of big, plump shapes: squares, Ts, pluses, even a 3x3.", "unlock": "Defeat 3 bosses across runs.", "need": {"bosses": 3}},
	{"id": "tetromino", "name": "Tetromino Kit", "joker_slots": 5, "refreshes": 1, "placements": 15, "credits": 0, "bag": "tetromino",
		"text": "Only four-block pieces: 20 of them, so Twins and Triplets come often.", "unlock": "Form 25 Tray Hands across runs.", "need": {"hands": 25}},
]


static func target(round_number: int) -> int:
	if round_number <= ROUND_COUNT:
		return TARGETS[clampi(round_number, 1, ROUND_COUNT) - 1]
	var k := round_number - ROUND_COUNT
	var raw := float(TARGETS[ROUND_COUNT - 1]) * pow(OVERTIME_BASE, k) * (1.0 + OVERTIME_CURVE * k * k)
	if raw >= SCORE_CAP:
		return SCORE_CAP
	# Two significant digits: 17,280 -> 17,000; 2,611,000 -> 2,600,000.
	var step := pow(10.0, floorf(log(raw) / log(10.0)) - 1.0)
	return mini(SCORE_CAP, int(roundf(raw / step) * step))


static func is_overtime(round_number: int) -> bool:
	return round_number > ROUND_COUNT


## Rarity weights for the shop before `round_number`'s act (overtime uses the act 3 weights).
static func rarity_weights(act: int) -> Array:
	return RARITY_WEIGHTS[clampi(act, 1, RARITY_WEIGHTS.size()) - 1]


static func act_of(round_number: int) -> int:
	return (round_number - 1) / ROUNDS_PER_ACT + 1


static func is_boss_round(round_number: int) -> bool:
	return round_number % ROUNDS_PER_ACT == 0


static func kit(id: String) -> Dictionary:
	for k in KITS:
		if k.id == id:
			return k
	return KITS[0]


## Whether a Kit is available with the given lifetime profile counters.
static func kit_unlocked(id: String, profile: Dictionary) -> bool:
	var need: Dictionary = kit(id).get("need", {})
	for k in need:
		if int(profile.get(k, 0)) < int(need[k]):
			return false
	return true
