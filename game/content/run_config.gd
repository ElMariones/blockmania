class_name BMRunConfig
extends RefCounted
## Run structure, targets, economy, and Kits (GDD §5 "Round targets", §6). All numbers provisional.

const ROUND_COUNT := 12
const ROUNDS_PER_ACT := 4
const TARGETS := [450, 650, 900, 1200, 1800, 2400, 3300, 4400, 5700, 7300, 9300, 12500]

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
## Base Mult for each line beyond the first in one placement (playtest 2026-09-24: multi-line
## clears were only 1-2% of placements and scored like two small clears; a double clear now
## scores x2 base Mult, a triple x3).
const MULT_PER_EXTRA_LINE := 1.0
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
## Interest (playtest 2026-09-24: Credits piled up late with nothing to decide): after a won
## round, +1 Credit for every INTEREST_STEP Credits held, at most INTEREST_CAP.
const INTEREST_STEP := 5
const INTEREST_CAP := 5
## Overkill: +1 Credit for every full OVERKILL_STEP of the target scored beyond it (max cap).
const OVERKILL_STEP := 0.5
const OVERKILL_CAP := 3
## Joker slots can grow with Rack Extender (Workshop) up to this many.
const MAX_JOKER_SLOTS := 7

## Rarity weights [common, uncommon, rare, legendary] per act: 65/30/5 shifting to 40/40/19/1
## by act 3; Overtime acts use the last row. Legendary Jokers mostly come from Boss Crates.
const RARITY_WEIGHTS := [[65, 30, 5, 0], [53, 35, 12, 0], [40, 40, 19, 1], [34, 40, 23, 3]]
## Boss Crate Joker odds (percent): legendary by boss round (act 1 never), else rare 40%.
const CRATE_LEGENDARY_ACT2 := 12
const CRATE_LEGENDARY_ACT3 := 20
const CRATE_LEGENDARY_OVERTIME := 30
const CRATE_RARE := 40

## Kits (GDD §6 "Starting Kits"; docs/design/round_play_update.md §4). `bag` names the starter
## bag in BMPieces.STARTER_BAGS. `unlock` is the player-facing requirement and `need` the
## lifetime profile counter that satisfies it (BMSaveStore profile); "" = always available.
## Each unlockable Kit has its own bag and one signature rule (`perk`, owner request 2026-09-24):
##   thrift_credits   Credits per Refresh left unused when a round is won (BMRun._win_round)
##   interest_bonus   added to the interest cap (BMRun._win_round)
##   big_piece_chips  Chips per cell for a placed piece of 5+ cells (BMResolver step 3). Not a
##                    refill perk: extra placements per line would let a round run forever.
##   hand_credits     Credits each time a Tray Hand forms (BMRun._apply_hand)
## All numbers provisional.
const KITS := [ # i18n: name, short, perk, perk_text, text, unlock
	{"id": "standard", "short": "Standard", "name": "Standard Kit", "joker_slots": 5, "refreshes": 1, "placements": 15, "credits": 0, "bag": "standard",
		"perk": "CLASSIC", "perk_text": "No twist: the rules as designed. The best Kit to learn with.",
		"text": "The 24-piece starter bag: a bit of every shape.", "unlock": "", "need": {}},
	{"id": "compact", "short": "Compact", "name": "Compact Kit", "joker_slots": 4, "refreshes": 2, "placements": 16, "credits": 0, "bag": "compact",
		"perk": "THRIFT", "perk_text": "+1 Credit for every Refresh you did not use when you win a round.", "thrift_credits": 1,
		"text": "An 18-piece bag of small pieces: Singles, Bars, little Ls and Squares. Only 4 Joker slots.", "unlock": "Clear 100 lines across runs.", "need": {"lines": 100}},
	{"id": "high_roller", "short": "High Roller", "name": "High Roller Kit", "joker_slots": 5, "refreshes": 1, "placements": 14, "credits": 4, "bag": "standard",
		"perk": "COMPOUND INTEREST", "perk_text": "Interest can pay up to +3 more Credits each round.", "interest_bonus": 3,
		"text": "Start with 4 Credits. The standard bag, 14 placements per round.", "unlock": "Win a standard run.", "need": {"wins": 1}},
	{"id": "chunky", "short": "Chunky", "name": "Chunky Kit", "joker_slots": 5, "refreshes": 1, "placements": 13, "credits": 0, "bag": "chunky",
		"perk": "HEAVY LIFTING", "perk_text": "Pieces of 5 or more blocks score +10 Chips per block.", "big_piece_chips": 10,
		"text": "A 19-piece bag of big, plump shapes: squares, Ts, pluses, a Bar 5 and a 3x3. Only 13 placements.", "unlock": "Defeat 3 bosses across runs.", "need": {"bosses": 3}},
	{"id": "tetromino", "short": "Tetromino", "name": "Tetromino Kit", "joker_slots": 5, "refreshes": 1, "placements": 14, "credits": 0, "bag": "tetromino",
		"perk": "FULL HOUSE", "perk_text": "+1 Credit every time a Tray Hand forms.", "hand_credits": 1,
		"text": "Only four-block pieces: 20 of them, so Twins and Triplets come often.", "unlock": "Form 25 Tray Hands across runs.", "need": {"hands": 25}},
]


## Heat (stakes after a win, GDD §22): each level keeps the ones below it. Heat N unlocks when
## a run at heat N-1 is won. `target` multiplies round targets (never Overtime's formula input).
const HEATS := [ # i18n: name, short
	{"name": "Heat 0", "short": "Standard rules.", "target": 1.0},
	{"name": "Heat 1", "short": "Targets +15%.", "target": 1.15},
	{"name": "Heat 2", "short": "One fewer placement every round.", "target": 1.15},
	{"name": "Heat 3", "short": "Interest pays at most +3; rerolls start at 3.", "target": 1.15},
	{"name": "Heat 4", "short": "Every boss is its Mk II version.", "target": 1.15},
	{"name": "Heat 5", "short": "Targets +35% and one fewer Refresh.", "target": 1.35},
]
const MAX_HEAT := 5
const HEAT_INTEREST_CAP := 3
const HEAT_REROLL_BASE := 3


static func heat_def(heat: int) -> Dictionary:
	return HEATS[clampi(heat, 0, MAX_HEAT)]


## Every rule a heat level adds, cumulative, for menus and tooltips.
static func heat_rules(heat: int) -> PackedStringArray:
	var out := PackedStringArray()
	for h in range(1, clampi(heat, 0, MAX_HEAT) + 1):
		out.append(BMLoc.t(HEATS[h].short))
	return out


## Daily run seed from a date string "YYYY-MM-DD" (same for everyone on that day).
static func daily_seed(date: String) -> int:
	var h := 2166136261
	for c in date.to_utf8_buffer():
		h = ((h ^ c) * 16777619) & 0x7FFFFFFF
	return maxi(1, h % 999_999_937)


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


## Rarity weights for the shop before `round_number`'s act (Overtime acts use the last row).
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
