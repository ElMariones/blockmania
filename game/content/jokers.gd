class_name BMJokers
extends RefCounted
## Joker catalog (GDD §7). Stable string IDs are save-facing: never rename casually.
## `phase` documents where the effect acts:
##   chips / add_mult / x_mult  -> scoring pipeline steps 4 / 5 / 6
##   rule                       -> changes round rules (placements, refresh, rescue, economy)
## `color` = true marks color-dependent cards (disabled by The Color Blind).
## `implemented` = false keeps a card out of shop offers until its interaction exists.
## Values and costs are provisional balance numbers.

const COMMON := 0
const UNCOMMON := 1
const RARE := 2
## Legendary (2026-09-24): four unique, rule-bending Jokers. They come mostly from Boss Crates
## (act 2 onward) and rarely from late shops; never more than one copy each.
const LEGENDARY := 3
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Legendary"] # i18n
## Veteran: Chips an exact bag piece gains each time it completes a line (per Veteran copy).
const VETERAN_STEP := 5
const RARITY_COST := [3, 5, 8, 12]

const CATALOG := [ # i18n: name, text
	{"id": "clean_sweep", "name": "Clean Sweep", "rarity": COMMON, "phase": "chips", "text": "+50 Chips when exactly one line clears."},
	{"id": "crossbar", "name": "Crossbar", "rarity": COMMON, "phase": "chips", "text": "+100 Chips when two or more lines clear together; +100 more if they cross (a row and a column)."},
	{"id": "small_change", "name": "Small Change", "rarity": COMMON, "phase": "chips", "text": "+15 Chips per placed cell when placing a shape of 1-3 cells."},
	{"id": "heavy_hand", "name": "Heavy Hand", "rarity": COMMON, "phase": "chips", "text": "+100 Chips when placing a shape of 5 or more cells."},
	{"id": "first_strike", "name": "First Strike", "rarity": COMMON, "phase": "chips", "text": "The first clearing placement each round gains +150 Chips."},
	{"id": "neat_freak", "name": "Neat Freak", "rarity": COMMON, "phase": "chips", "text": "+40 Chips if the placed shape touches no occupied cell diagonally (checked before placement)."},
	{"id": "corner_office", "name": "Corner Office", "rarity": COMMON, "phase": "chips", "text": "+60 Chips if any placed cell occupies a board corner."},
	{"id": "blue_mood", "name": "Blue Mood", "rarity": COMMON, "phase": "add_mult", "color": true, "text": "Blue shapes gain +2 Mult."},
	{"id": "chain_link", "name": "Chain Link", "rarity": COMMON, "phase": "add_mult", "text": "+1 Mult per current combo level on clearing placements."},
	{"id": "spare_parts", "name": "Spare Parts", "rarity": COMMON, "phase": "rule", "text": "+2 Credits after a round won with at least two placements unused."},
	{"id": "tiny_insurance", "name": "Tiny Insurance", "rarity": COMMON, "phase": "rule", "text": "Once per round, when no offered shape fits and no tray Refresh is available, replace one unplaced shape with a Single before defeat is checked."},
	{"id": "second_look", "name": "Second Look", "rarity": COMMON, "phase": "rule", "text": "The first Refresh each round also grants +1 placement."},
	{"id": "wide_awake", "name": "Wide Awake", "rarity": UNCOMMON, "phase": "add_mult", "text": "+2 Mult on every clearing placement; +3 more when two or more lines clear."},
	{"id": "hollow_point", "name": "Hollow Point", "rarity": UNCOMMON, "phase": "add_mult", "text": "+0.5 Mult when the board has at least 44 empty cells before placement."},
	{"id": "pressure_cooker", "name": "Pressure Cooker", "rarity": UNCOMMON, "phase": "add_mult", "text": "+0.5 Mult for every eight occupied cells before placement (max +2)."},
	{"id": "golden_ratio", "name": "Golden Ratio", "rarity": UNCOMMON, "phase": "x_mult", "text": "Every third placed shape in a round gets x1.5 Mult."},
	{"id": "color_cycle", "name": "Color Cycle", "rarity": UNCOMMON, "phase": "x_mult", "color": true, "text": "When the last three placed shapes this round all have different colors, the third gains x1.75 Mult."},
	{"id": "patch_panel", "name": "Patch Panel", "rarity": UNCOMMON, "phase": "rule", "text": "After the first clear each round, remove one block of your choice (use it from the Items row). The removal scores nothing."},
	{"id": "long_game", "name": "Long Game", "rarity": UNCOMMON, "phase": "rule", "text": "+1 placement per round. The first placement of each round gains no cell Chips."},
	{"id": "fire_sale", "name": "Fire Sale", "rarity": UNCOMMON, "phase": "add_mult", "text": "+0.25 Mult for each Joker sold this run (max +2). Selling this card ends its bonus."},
	{"id": "jackpot_window", "name": "Jackpot Window", "rarity": RARE, "phase": "x_mult", "text": "x2.5 Mult when two lines clear in one placement; x5 Mult for three or more."},
	{"id": "mirror_maze", "name": "Mirror Maze", "rarity": RARE, "phase": "chips", "text": "The first row clear each round also clears the mirrored row's occupied cells for +50 Chips. The mirrored removal cannot chain."},
	{"id": "compound_interest", "name": "Compound Interest", "rarity": RARE, "phase": "x_mult", "text": "Every second clearing placement in a round gets x1.75 Mult."},
	{"id": "last_stand", "name": "Last Stand", "rarity": RARE, "phase": "x_mult", "text": "Placements made with four or fewer placements left gain x2.5 Mult."},
	# --- Bag-era Jokers (GDD §16.6) ---
	{"id": "hoarder", "name": "Hoarder", "rarity": UNCOMMON, "phase": "chips", "text": "+1 Chip for each piece in your bag."},
	{"id": "architect", "name": "Architect", "rarity": COMMON, "phase": "chips", "text": "+60 Chips when placing an L 3 or L 4 piece."},
	{"id": "straight_edge", "name": "Straight Edge", "rarity": COMMON, "phase": "chips", "text": "+15 Chips per cell when placing a Bar piece."},
	{"id": "square_deal", "name": "Square Deal", "rarity": COMMON, "phase": "add_mult", "text": "+2 Mult when placing a Square piece."},
	{"id": "last_piece", "name": "Last Piece", "rarity": COMMON, "phase": "chips", "text": "+80 Chips when this placement empties the tray."},
	{"id": "postmaster", "name": "Postmaster", "rarity": COMMON, "phase": "chips", "text": "+40 Chips when placing a stamped piece."},
	{"id": "lean_bag", "name": "Lean Bag", "rarity": UNCOMMON, "phase": "add_mult", "text": "+0.25 Mult for each piece your bag has below 24 (max +3)."},
	{"id": "foundry", "name": "Foundry", "rarity": UNCOMMON, "phase": "chips", "text": "+5 Chips for each upgraded piece (material or stamp) in your bag."},
	{"id": "neon_sign", "name": "Neon Sign", "rarity": UNCOMMON, "phase": "add_mult", "text": "Neon cells cleared give an extra +0.5 Mult each."},
	{"id": "specialist", "name": "Specialist", "rarity": UNCOMMON, "phase": "add_mult", "text": "+0.5 Mult per Schematic level of the placed piece's family."},
	{"id": "recycler", "name": "Recycler", "rarity": UNCOMMON, "phase": "add_mult", "text": "+0.1 Mult for each piece in the discard pile before placement (max +1)."},
	{"id": "glass_cannon", "name": "Glass Cannon", "rarity": RARE, "phase": "x_mult", "text": "x0.3 Mult for each Glass piece in your bag (x1 + 0.3 each, max x4)."},
	{"id": "collector", "name": "Collector", "rarity": RARE, "phase": "x_mult", "text": "x0.1 Mult for each different shape family in your bag beyond 6 (x1.4 with 10 families)."},
	{"id": "mimic", "name": "Mimic", "rarity": RARE, "phase": "copy", "text": "Copies the scoring effect of the Joker directly below it."},
	# --- Round-play update (docs/design/round_play_update.md §6) ---
	{"id": "hot_hand", "name": "Hot Hand", "rarity": RARE, "phase": "x_mult", "text": "x1.5 Mult on placements from a tray that formed a Hand."},
	{"id": "card_sharp", "name": "Card Sharp", "rarity": UNCOMMON, "phase": "rule", "text": "A full tray dealt by a Refresh or Second Tray can form a Hand."},
	{"id": "patience", "name": "Patience", "rarity": UNCOMMON, "phase": "chips", "text": "Each placement that clears nothing stores +40 Chips (max +200). The next clearing placement adds them and resets."},
	{"id": "locksmith", "name": "Locksmith", "rarity": UNCOMMON, "phase": "add_mult", "text": "+1 Mult when the placed piece fills a one-block hole closed on all four sides; +75 Chips more if it also clears a line."},
	{"id": "countdown", "name": "Countdown", "rarity": UNCOMMON, "phase": "x_mult", "text": "x1.5 Mult on the third of three placements in a row with fewer blocks each time (like 5, 4, 3)."},
	{"id": "breakage_bonus", "name": "Breakage Bonus", "rarity": UNCOMMON, "phase": "rule", "text": "+2 Credits whenever one of your Glass pieces shatters."},
	{"id": "insurance_policy", "name": "Insurance Policy", "rarity": RARE, "phase": "rule", "text": "Once: when you would lose a round, replay it from the start with no free Refresh. Then this card is destroyed."},
	{"id": "showboat", "name": "Showboat", "rarity": RARE, "phase": "add_mult", "text": "+2 Mult for each Feat you earn for the first time this round."},
	{"id": "full_tank", "name": "Full Tank", "rarity": UNCOMMON, "phase": "add_mult", "text": "+2 Mult when you place while your placements are at their refill cap."},
	{"id": "overflow", "name": "Overflow", "rarity": COMMON, "phase": "rule", "text": "When a line clear would refill past your cap, each wasted refill gives +1 Credit (max 3 per round)."},
	{"id": "keystone", "name": "Keystone", "rarity": RARE, "phase": "x_mult", "text": "x2 Mult when a piece of 1 to 3 blocks clears a line; x4 if it clears two or more."},
	{"id": "draftsman", "name": "Draftsman", "rarity": UNCOMMON, "phase": "rule", "text": "Clearing a row and a column in the same placement gives you an Eraser (if an item slot is free)."},
	{"id": "periscope", "name": "Periscope", "rarity": COMMON, "phase": "rule", "text": "Shows the next three pieces in your draw pile."},
	{"id": "loan_shark", "name": "Loan Shark", "rarity": COMMON, "phase": "rule", "cost": 0, "text": "Costs 0. When bought: +6 Credits. After each won round, 2 Credits go to repay the loan until 8 are repaid. Cannot be sold until then."},
	# --- Engine update (docs/playtests/2026-09-24_persona_playtest.md): scaling, economy, big pieces ---
	# `scaling` cards keep a value for the whole run in BMRun.joker_state (shared by copies).
	{"id": "snowball", "name": "Snowball", "rarity": UNCOMMON, "phase": "x_mult", "scaling": true, "text": "Gains x0.15 Mult every time two or more lines clear at once. Never resets."},
	{"id": "tally_counter", "name": "Tally Counter", "rarity": COMMON, "phase": "chips", "text": "+4 Chips for every line you have cleared this run."},
	{"id": "bonsai", "name": "Bonsai", "rarity": UNCOMMON, "phase": "add_mult", "text": "+0.35 Mult for every round won this run."},
	{"id": "coin_pusher", "name": "Coin Pusher", "rarity": COMMON, "phase": "add_mult", "text": "+0.1 Mult for every Credit you hold (max +5)."},
	{"id": "hot_streak", "name": "Hot Streak", "rarity": RARE, "phase": "x_mult", "scaling": true, "text": "Gains x0.3 Mult for each round won without a Refresh or Second Tray. Using one resets it to x1."},
	{"id": "big_game_hunter", "name": "Big Game Hunter", "rarity": UNCOMMON, "phase": "add_mult", "text": "+1 Mult for each block over 4 in the placed piece."},
	{"id": "rainbow_road", "name": "Rainbow Road", "rarity": UNCOMMON, "phase": "x_mult", "color": true, "text": "x1.75 Mult when the board holds all six block colors before the placement."},
	{"id": "solo_act", "name": "Solo Act", "rarity": RARE, "phase": "x_mult", "text": "x1 Mult plus x0.75 for each empty Joker slot."},
	{"id": "double_stamp", "name": "Double Stamp", "rarity": RARE, "phase": "rule", "text": "Stamps trigger twice: Encore x4, Tip +4 Credits, Refund +2 placements, Memory two Sparks."},
	{"id": "vending_machine", "name": "Vending Machine", "rarity": COMMON, "phase": "rule", "text": "After each round won, drops a random item into a free item slot."},
	{"id": "demolition_crew", "name": "Demolition Crew", "rarity": UNCOMMON, "phase": "chips", "text": "+15 Chips for every block cleared by the placement."},
	{"id": "overachiever", "name": "Overachiever", "rarity": UNCOMMON, "phase": "add_mult", "scaling": true, "text": "Gains +1 Mult whenever a round ends at 1.5 times its target or more. Never resets."},
	{"id": "full_pockets", "name": "Full Pockets", "rarity": COMMON, "phase": "add_mult", "text": "+1.5 Mult for each item you hold."},
	# --- Color and form Jokers (owner request, 2026-09-26): a common and a rare for every block
	# color and every piece form, so building the bag pays. Effects come from the fields:
	#   tint / form   which pieces the card cares about (tint: a color index; Prism counts)
	#   add_chips / add_mult   a common's flat boost when such a piece is placed
	#   bag_step      a rare's xMult: x1 plus this for each such piece in your bag, max BAG_X_MAX
	{"id": "red_alert", "name": "Red Alert", "rarity": COMMON, "phase": "add_mult", "color": true, "tint": 0, "add_mult": 2.0, "text": "Red shapes gain +2 Mult."},
	{"id": "citrus_twist", "name": "Citrus Twist", "rarity": COMMON, "phase": "chips", "color": true, "tint": 1, "add_chips": 60, "text": "Orange shapes gain +60 Chips."},
	{"id": "lemon_drop", "name": "Lemon Drop", "rarity": COMMON, "phase": "chips", "color": true, "tint": 2, "add_chips": 60, "text": "Yellow shapes gain +60 Chips."},
	{"id": "green_thumb", "name": "Green Thumb", "rarity": COMMON, "phase": "add_mult", "color": true, "tint": 3, "add_mult": 2.0, "text": "Green shapes gain +2 Mult."},
	{"id": "plum_job", "name": "Plum Job", "rarity": COMMON, "phase": "chips", "color": true, "tint": 5, "add_chips": 60, "text": "Purple shapes gain +60 Chips."},
	{"id": "red_giant", "name": "Red Giant", "rarity": RARE, "phase": "x_mult", "color": true, "tint": 0, "bag_step": 0.15, "text": "Red shapes gain x1 Mult plus x0.15 for each Red piece in your bag (max x3)."},
	{"id": "sunset_glow", "name": "Sunset Glow", "rarity": RARE, "phase": "x_mult", "color": true, "tint": 1, "bag_step": 0.15, "text": "Orange shapes gain x1 Mult plus x0.15 for each Orange piece in your bag (max x3)."},
	{"id": "solar_flare", "name": "Solar Flare", "rarity": RARE, "phase": "x_mult", "color": true, "tint": 2, "bag_step": 0.15, "text": "Yellow shapes gain x1 Mult plus x0.15 for each Yellow piece in your bag (max x3)."},
	{"id": "evergreen", "name": "Evergreen", "rarity": RARE, "phase": "x_mult", "color": true, "tint": 3, "bag_step": 0.15, "text": "Green shapes gain x1 Mult plus x0.15 for each Green piece in your bag (max x3)."},
	{"id": "deep_blue", "name": "Deep Blue", "rarity": RARE, "phase": "x_mult", "color": true, "tint": 4, "bag_step": 0.15, "text": "Blue shapes gain x1 Mult plus x0.15 for each Blue piece in your bag (max x3)."},
	{"id": "royal_purple", "name": "Royal Purple", "rarity": RARE, "phase": "x_mult", "color": true, "tint": 5, "bag_step": 0.15, "text": "Purple shapes gain x1 Mult plus x0.15 for each Purple piece in your bag (max x3)."},
	{"id": "lone_wolf", "name": "Lone Wolf", "rarity": COMMON, "phase": "add_mult", "form": "single", "add_mult": 2.0, "text": "+2 Mult when placing a Single."},
	{"id": "tee_time", "name": "Tee Time", "rarity": COMMON, "phase": "chips", "form": "t", "add_chips": 60, "text": "+60 Chips when placing a T piece."},
	{"id": "zigzagger", "name": "Zigzagger", "rarity": COMMON, "phase": "add_mult", "form": "zigzag", "add_mult": 2.0, "text": "+2 Mult when placing a Zigzag piece."},
	{"id": "plus_side", "name": "Plus Side", "rarity": COMMON, "phase": "chips", "form": "plus", "add_chips": 80, "text": "+80 Chips when placing a Plus piece."},
	{"id": "solitaire", "name": "Solitaire", "rarity": RARE, "phase": "x_mult", "form": "single", "bag_step": 0.3, "text": "Singles gain x1 Mult plus x0.3 for each Single in your bag (max x3)."},
	{"id": "barbell", "name": "Barbell", "rarity": RARE, "phase": "x_mult", "form": "bar", "bag_step": 0.1, "text": "Bar pieces gain x1 Mult plus x0.1 for each Bar in your bag (max x3)."},
	{"id": "elbow_room", "name": "Elbow Room", "rarity": RARE, "phase": "x_mult", "form": "l", "bag_step": 0.15, "text": "L pieces gain x1 Mult plus x0.15 for each L piece in your bag (max x3)."},
	{"id": "town_square", "name": "Town Square", "rarity": RARE, "phase": "x_mult", "form": "square", "bag_step": 0.25, "text": "Square pieces gain x1 Mult plus x0.25 for each Square in your bag (max x3)."},
	{"id": "t_rex", "name": "T-Rex", "rarity": RARE, "phase": "x_mult", "form": "t", "bag_step": 0.25, "text": "T pieces gain x1 Mult plus x0.25 for each T piece in your bag (max x3)."},
	{"id": "lightning_bolt", "name": "Lightning Bolt", "rarity": RARE, "phase": "x_mult", "form": "zigzag", "bag_step": 0.25, "text": "Zigzag pieces gain x1 Mult plus x0.25 for each Zigzag in your bag (max x3)."},
	{"id": "compass_rose", "name": "Compass Rose", "rarity": RARE, "phase": "x_mult", "form": "plus", "bag_step": 0.3, "text": "Plus pieces gain x1 Mult plus x0.3 for each Plus piece in your bag (max x3)."},
	{"id": "veteran", "name": "Veteran", "rarity": RARE, "phase": "rule", "text": "Each time a piece completes a line, that exact piece permanently gains +5 Chips. The Chips stay on the piece (and on its Copier copies) even if you sell Veteran."},
	# --- Legendary (unique; Boss Crates from act 2, rare in late shops) ---
	{"id": "avalanche", "name": "The Avalanche", "rarity": LEGENDARY, "phase": "rule", "unique": true, "text": "After a clear, blocks fall down their columns. New full lines clear as chain waves, each scoring double the last (x2, x4, x8...)."},
	{"id": "hall_of_mirrors", "name": "Hall of Mirrors", "rarity": LEGENDARY, "phase": "rule", "unique": true, "text": "Every other Joker's scoring effect triggers twice (Chips and Mult add twice, xMult applies twice)."},
	{"id": "philosophers_stone", "name": "Philosopher's Stone", "rarity": LEGENDARY, "phase": "rule", "unique": true, "text": "Material effects are doubled. Every piece you place without a material gains a random one for good."},
	{"id": "supernova", "name": "Supernova", "rarity": LEGENDARY, "phase": "x_mult", "unique": true, "text": "x1 Mult plus x0.5 for every line cleared earlier this round."},
]

## Color and form rares: the most xMult a bag can give them.
const BAG_X_MAX := 3.0
const PATIENCE_STEP := 40
const PATIENCE_MAX := 200
const LOAN_CREDITS := 6
const LOAN_TOTAL := 8
const LOAN_INSTALLMENT := 2
const OVERFLOW_MAX := 3
const SNOWBALL_STEP := 0.15
const HOT_STREAK_STEP := 0.3
const OVERACHIEVER_RATIO := 1.5
const SUPERNOVA_STEP := 0.5
const LEGENDARY_IDS := ["avalanche", "hall_of_mirrors", "philosophers_stone", "supernova"]
## Jokers that join the shop pool when an achievement is earned (GDD §22.6). A run records its
## locked set at the start (BMRun.locked_jokers), so seeds replay exactly. Daily runs lock nothing.
const UNLOCKS := {
	"snowball": "triple_decker", "hot_streak": "boss_buster", "overachiever": "overkill",
	"solo_act": "travel_light", "double_stamp": "special_delivery", "rainbow_road": "full_spectrum",
	"big_game_hunter": "square_dance", "demolition_crew": "crossroads", "mimic": "rare_taste",
	"jackpot_window": "red_hot",
	"avalanche": "champion", "hall_of_mirrors": "champion", "philosophers_stone": "champion", "supernova": "champion",
}


## Jokers still locked for a player with these achievements (id -> anything).
static func locked_for(unlocked: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id in UNLOCKS:
		if not unlocked.has(UNLOCKS[id]):
			out.append(String(id))
	return out


## Jokers unlocked by one achievement (for toasts and the Trophy Case).
static func unlocked_by(achievement: String) -> Array[String]:
	var out: Array[String] = []
	for id in UNLOCKS:
		if UNLOCKS[id] == achievement:
			out.append(String(id))
	return out

static var _by_id := {}


static func get_def(id: String) -> Dictionary:
	if _by_id.is_empty():
		for d in CATALOG:
			_by_id[d.id] = d
	return _by_id.get(id, {})


## Translated card name and rule text (display only; the catalog keeps the English source).
static func display_name(id: String) -> String:
	return BMLoc.t(String(get_def(id).get("name", id)))


static func display_text(id: String) -> String:
	return BMLoc.t(String(get_def(id).get("text", "")))


static func rarity_name(rarity: int) -> String:
	return BMLoc.t(RARITY_NAMES[clampi(rarity, 0, RARITY_NAMES.size() - 1)])


static func cost(id: String) -> int:
	var d := get_def(id)
	if d.has("cost"):
		return int(d.cost)
	return RARITY_COST[int(d.get("rarity", COMMON))]


static func sell_value(id: String) -> int:
	return ceili(cost(id) / 2.0)


static func is_color_dependent(id: String) -> bool:
	return bool(get_def(id).get("color", false))


static func is_implemented(id: String) -> bool:
	return bool(get_def(id).get("implemented", true))


static func is_unique(id: String) -> bool:
	return bool(get_def(id).get("unique", false))


static func is_legendary(id: String) -> bool:
	return int(get_def(id).get("rarity", COMMON)) == LEGENDARY


static func is_scaling(id: String) -> bool:
	return bool(get_def(id).get("scaling", false))


## Starting value of a scaling card's run-long state.
static func scaling_start(id: String) -> float:
	match id:
		"snowball", "hot_streak":
			return 1.0
	return 0.0


static func ids_of_rarity(rarity: int) -> Array[String]:
	var out: Array[String] = []
	for d in CATALOG:
		if int(d.rarity) == rarity and bool(d.get("implemented", true)):
			out.append(d.id)
	return out


# --- Scoring effects -------------------------------------------------------------------
# ctx is built by BMResolver: see BMResolver._make_context for fields.


## Color and form cards: does the placed piece match the card's tint or form?
static func _matches(d: Dictionary, ctx: Dictionary) -> bool:
	if d.has("tint"):
		return int(ctx.color) == int(d.tint) or bool(ctx.prism)
	if d.has("form"):
		return BMShapes.form(StringName(ctx.family)) == String(d.form)
	return false


## Pieces in the bag a color or form card counts (Prism pieces count for every color).
static func bag_count(d: Dictionary, ctx: Dictionary) -> int:
	if d.has("tint"):
		return int(ctx.bag_colors.get(int(d.tint), 0)) + int(ctx.bag_colors.get(-1, 0))
	if d.has("form"):
		return int(ctx.bag_forms.get(String(d.form), 0))
	return 0


## xMult of a color or form rare with `n` matching pieces in the bag.
static func bag_x(d: Dictionary, n: int) -> float:
	return minf(BAG_X_MAX, 1.0 + float(d.get("bag_step", 0.0)) * n)


## Additive Chips (pipeline step 4). Returns 0 when the card does not trigger.
static func chips(id: String, ctx: Dictionary) -> int:
	var d := get_def(id)
	if d.has("add_chips"):
		return int(d.add_chips) if _matches(d, ctx) else 0
	match id:
		"clean_sweep":
			return 50 if ctx.lines == 1 else 0
		"crossbar":
			if ctx.lines < 2:
				return 0
			return 200 if ctx.rows > 0 and ctx.cols > 0 else 100
		"small_change":
			return 15 * ctx.cell_count if ctx.cell_count <= 3 else 0
		"heavy_hand":
			return 100 if ctx.cell_count >= 5 else 0
		"first_strike":
			return 150 if ctx.is_clearing and ctx.clearing_index == 1 else 0
		"neat_freak":
			return 40 if not ctx.touches_diagonal else 0
		"corner_office":
			return 60 if ctx.touches_corner else 0
		"mirror_maze":
			return 50 if ctx.mirror_removed > 0 else 0
		"hoarder":
			return ctx.bag_size
		"architect":
			return 60 if ctx.family in [&"l3", &"l4"] else 0
		"straight_edge":
			return 15 * ctx.cell_count if ctx.family in [&"bar2", &"bar3", &"bar4", &"bar5"] else 0
		"last_piece":
			return 80 if ctx.empties_tray else 0
		"postmaster":
			return 40 if ctx.stamp != "" else 0
		"foundry":
			return 5 * ctx.upgraded_count
		"patience":
			return ctx.patience_store if ctx.is_clearing else 0
		"locksmith":
			return 75 if ctx.holes_filled > 0 and ctx.is_clearing else 0
		"tally_counter":
			return 4 * ctx.lines_before_run
		"demolition_crew":
			return 15 * ctx.cells_cleared
	return 0


## Additive Mult (pipeline step 5).
static func add_mult(id: String, ctx: Dictionary) -> float:
	var d := get_def(id)
	if d.has("add_mult"):
		return float(d.add_mult) if _matches(d, ctx) else 0.0
	match id:
		"blue_mood":
			return 2.0 if ctx.color == BMShapes.COLOR_BLUE or ctx.prism else 0.0
		"chain_link":
			return 1.0 * ctx.combo_before if ctx.is_clearing else 0.0
		"wide_awake":
			if not ctx.is_clearing:
				return 0.0
			return 5.0 if ctx.lines >= 2 else 2.0
		"hollow_point":
			return 0.5 if ctx.empty_before >= 44 else 0.0
		"pressure_cooker":
			return minf(2.0, 0.5 * floori(ctx.occupied_before / 8.0))
		"fire_sale":
			return minf(2.0, 0.25 * ctx.jokers_sold)
		"square_deal":
			return 2.0 if ctx.family in [&"square2", &"square3"] else 0.0
		"lean_bag":
			return minf(3.0, 0.25 * maxi(0, 24 - ctx.bag_size))
		"neon_sign":
			return BMPieces.NEON_MULT_PER_CELL * ctx.neon_cleared
		"specialist":
			return 0.5 * ctx.family_level
		"recycler":
			return minf(1.0, 0.1 * ctx.discard_size)
		"locksmith":
			return 1.0 if ctx.holes_filled > 0 else 0.0
		"showboat":
			return 2.0 * ctx.new_feats
		"full_tank":
			return 2.0 if ctx.at_cap else 0.0
		"bonsai":
			return 0.35 * ctx.rounds_won
		"coin_pusher":
			return minf(5.0, 0.1 * ctx.credits)
		"big_game_hunter":
			return 1.0 * maxi(0, ctx.cell_count - 4)
		"overachiever":
			return float(ctx.state.get("overachiever", 0.0))
		"full_pockets":
			return 1.5 * ctx.items_held
	return 0.0


## Multiplicative Mult (pipeline step 6). Returns 1.0 when the card does not trigger.
static func x_mult(id: String, ctx: Dictionary) -> float:
	var d := get_def(id)
	if d.has("bag_step"):
		return bag_x(d, bag_count(d, ctx)) if _matches(d, ctx) else 1.0
	match id:
		"golden_ratio":
			return 1.5 if ctx.placement_index % 3 == 0 else 1.0
		"color_cycle":
			# Prism pieces are recorded as -1 (wild) and never match another color.
			var h: Array = ctx.color_history
			if h.size() >= 3:
				var a: int = h[h.size() - 3]
				var b: int = h[h.size() - 2]
				var c: int = h[h.size() - 1]
				if not _same_color(a, b) and not _same_color(b, c) and not _same_color(a, c):
					return 1.75
			return 1.0
		"glass_cannon":
			return minf(4.0, 1.0 + 0.3 * ctx.glass_in_bag)
		"collector":
			return 1.0 + 0.1 * maxi(0, ctx.distinct_families - 6)
		"jackpot_window":
			if ctx.lines >= 3:
				return 5.0
			return 2.5 if ctx.lines == 2 else 1.0
		"compound_interest":
			return 1.75 if ctx.is_clearing and ctx.clearing_index % 2 == 0 else 1.0
		"last_stand":
			return 2.5 if ctx.placements_left_before <= 4 else 1.0
		"hot_hand":
			return 1.5 if ctx.hand != "" else 1.0
		"countdown":
			var h: Array = ctx.size_history
			if h.size() >= 3 and h[h.size() - 3] > h[h.size() - 2] and h[h.size() - 2] > h[h.size() - 1]:
				return 1.5
			return 1.0
		"keystone":
			if ctx.cell_count > 3 or ctx.lines == 0:
				return 1.0
			return 4.0 if ctx.lines >= 2 else 2.0
		"snowball":
			return maxf(1.0, float(ctx.state.get("snowball", 1.0)))
		"hot_streak":
			return maxf(1.0, float(ctx.state.get("hot_streak", 1.0)))
		"rainbow_road":
			return 1.75 if ctx.colors_before >= 6 else 1.0
		"solo_act":
			return 1.0 + 0.75 * ctx.empty_joker_slots
		"supernova":
			return 1.0 + SUPERNOVA_STEP * ctx.round_lines_before
	return 1.0


## Compact number for counters: 2, 2.5, 2.25.
static func _num(v: float) -> String:
	var t := "%.2f" % v
	while t.ends_with("0"):
		t = t.left(t.length() - 1)
	return t.trim_suffix(".")


static func _same_color(a: int, b: int) -> bool:
	return a >= 0 and b >= 0 and a == b


## Live counter text for card tooltips/HUD, or "" when the card has none.
static func counter_text(id: String, run: BMRun) -> String:
	var d := get_def(id)
	if d.has("bag_step"):
		var n := bag_count(d, {"bag_colors": BMBag.color_counts(run), "bag_forms": BMBag.form_counts(run)})
		return BMLoc.tn("%d in your bag: x%s Mult", "%d in your bag: x%s Mult", n) % [n, _num(bag_x(d, n))]
	match id:
		"golden_ratio":
			var next := 3 - (run.round_state.placements_made % 3)
			return BMLoc.tn("Triggers in %d placement", "Triggers in %d placements", next) % next
		"compound_interest":
			return BMLoc.t("Clears this round: %d") % run.round_state.clearing_placements
		"color_cycle":
			var names := PackedStringArray()
			var h: Array = run.round_state.color_history
			for i in range(maxi(0, h.size() - 2), h.size()):
				names.append(BMShapes.color_name(h[i]))
			return BMLoc.t("Recent: %s") % (BMLoc.list_sep().join(names) if names.size() > 0 else BMLoc.t("none"))
		"fire_sale":
			return BMLoc.t("Jokers sold: %d") % run.jokers_sold
		"first_strike":
			return BMLoc.t("Used this round") if run.round_state.clearing_placements > 0 else BMLoc.t("Ready")
		"tiny_insurance":
			return BMLoc.t("Used this round") if run.round_state.tiny_insurance_used else BMLoc.t("Ready")
		"mirror_maze":
			return BMLoc.t("Used this round") if run.round_state.mirror_used else BMLoc.t("Ready")
		"patience":
			return BMLoc.t("Stored: +%d Chips") % run.round_state.patience_store
		"countdown":
			var sh: Array = run.round_state.size_history
			var last := PackedStringArray()
			for i in range(maxi(0, sh.size() - 2), sh.size()):
				last.append(str(sh[i]))
			return BMLoc.t("Recent sizes: %s") % (BMLoc.list_sep().join(last) if last.size() > 0 else BMLoc.t("none"))
		"showboat":
			return BMLoc.t("Feats this round: %d") % run.round_state.feats_seen.size()
		"full_tank":
			return BMLoc.t("Placements %d / %d") % [run.round_state.placements_left, run.round_state.placement_cap]
		"overflow":
			return BMLoc.t("Paid this round: %d / %d") % [run.round_state.overflow_paid, OVERFLOW_MAX]
		"loan_shark":
			return BMLoc.t("Owed: %d Credits") % run.loan_debt if run.loan_debt > 0 else BMLoc.t("Repaid")
		"insurance_policy":
			return BMLoc.t("Unused: saves one lost round")
		"periscope":
			var names := PackedStringArray()
			for i in mini(3, run.draw_pile.size()):
				var p := BMBag.piece_by_uid(run, int(run.draw_pile[i]))
				names.append(BMPieces.describe(p).get_slice("\n", 0))
			if run.draw_pile.size() < 3:
				names.append(BMLoc.t("reshuffle"))
			return BMLoc.t("Next: %s") % BMLoc.list_sep().join(names)
		"patch_panel":
			if run.round_state.patch_ready:
				return BMLoc.t("Ready: remove a block")
			return BMLoc.t("Used this round") if run.round_state.patch_used else BMLoc.t("Waiting for the first clear")
		"hoarder":
			return BMLoc.t("%d pieces: +%d Chips") % [run.bag.size(), run.bag.size()]
		"lean_bag":
			return BMLoc.t("%d pieces: +%s Mult") % [run.bag.size(), str(minf(3.0, 0.25 * maxi(0, 24 - run.bag.size())))]
		"foundry":
			return BMLoc.t("%d upgraded: +%d Chips") % [BMBag.upgraded_count(run), 5 * BMBag.upgraded_count(run)]
		"collector":
			var fams := BMBag.distinct_families(run)
			return BMLoc.t("%d families: x%s Mult") % [fams, str(1.0 + 0.1 * maxi(0, fams - 6))]
		"recycler":
			return BMLoc.t("Discard pile: %d") % run.discard_pile.size()
		"snowball":
			return BMLoc.t("Now x%s Mult") % _num(run.joker_value("snowball"))
		"hot_streak":
			return BMLoc.t("Now x%s Mult") % _num(run.joker_value("hot_streak"))
		"overachiever":
			return BMLoc.t("Now +%s Mult") % _num(run.joker_value("overachiever"))
		"tally_counter":
			return BMLoc.t("%d lines: +%d Chips") % [int(run.stats.get("lines_cleared", 0)), 4 * int(run.stats.get("lines_cleared", 0))]
		"bonsai":
			return BMLoc.t("%d rounds won: +%s Mult") % [int(run.stats.get("rounds_won", 0)), _num(0.35 * int(run.stats.get("rounds_won", 0)))]
		"coin_pusher":
			return BMLoc.t("%d Credits: +%s Mult") % [run.credits, _num(minf(5.0, 0.1 * run.credits))]
		"solo_act":
			var empty := maxi(0, run.joker_slots() - run.occupied_slots())
			return BMLoc.tn("%d empty slot: x%s Mult", "%d empty slots: x%s Mult", empty) % [empty, _num(1.0 + 0.75 * empty)]
		"full_pockets":
			var held := run.consumables.size()
			return BMLoc.tn("%d item: +%s Mult", "%d items: +%s Mult", held) % [held, _num(1.5 * held)]
		"glass_cannon":
			var g := BMBag.material_count(run, "glass")
			return BMLoc.tn("%d Glass piece: x%s Mult", "%d Glass pieces: x%s Mult", g) % [g, _num(minf(4.0, 1.0 + 0.3 * g))]
		"supernova":
			return BMLoc.t("Lines this round: %d (x%s)") % [run.round_state.lines_cleared, _num(1.0 + SUPERNOVA_STEP * run.round_state.lines_cleared)]
		"philosophers_stone":
			return BMLoc.t("Transmuted this run: %d") % int(run.stats.get("transmuted", 0))
		"avalanche":
			var waves := int(run.stats.get("best_waves", 1))
			return BMLoc.tn("Best chain: %d wave", "Best chain: %d waves", waves) % waves
		"mimic":
			var i := run.jokers.find("mimic")
			if i >= 0 and i + 1 < run.jokers.size():
				return BMLoc.t("Copying: %s") % display_name(run.jokers[i + 1])
			return BMLoc.t("Copying: nothing below")
	return ""


## True when `id` has a scoring phase that Mimic can copy.
static func is_copyable(id: String) -> bool:
	return String(get_def(id).get("phase", "")) in ["chips", "add_mult", "x_mult"] and id != "mimic"
