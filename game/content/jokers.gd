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
const RARITY_NAMES := ["Common", "Uncommon", "Rare"]
const RARITY_COST := [3, 5, 8]

const CATALOG := [
	{"id": "clean_sweep", "name": "Clean Sweep", "rarity": COMMON, "phase": "chips", "text": "+50 Chips when exactly one line clears."},
	{"id": "crossbar", "name": "Crossbar", "rarity": COMMON, "phase": "chips", "text": "+100 Chips when a row and a column clear together."},
	{"id": "small_change", "name": "Small Change", "rarity": COMMON, "phase": "chips", "text": "+20 Chips per placed cell when placing a shape of 1-3 cells."},
	{"id": "heavy_hand", "name": "Heavy Hand", "rarity": COMMON, "phase": "chips", "text": "+100 Chips when placing a shape of 5 or more cells."},
	{"id": "first_strike", "name": "First Strike", "rarity": COMMON, "phase": "chips", "text": "The first clearing placement each round gains +150 Chips."},
	{"id": "neat_freak", "name": "Neat Freak", "rarity": COMMON, "phase": "chips", "text": "+40 Chips if the placed shape touches no occupied cell diagonally (checked before placement)."},
	{"id": "corner_office", "name": "Corner Office", "rarity": COMMON, "phase": "chips", "text": "+60 Chips if any placed cell occupies a board corner."},
	{"id": "blue_mood", "name": "Blue Mood", "rarity": COMMON, "phase": "add_mult", "color": true, "text": "Blue shapes gain +1 Mult."},
	{"id": "chain_link", "name": "Chain Link", "rarity": COMMON, "phase": "add_mult", "text": "+0.5 Mult per current combo level on clearing placements."},
	{"id": "spare_parts", "name": "Spare Parts", "rarity": COMMON, "phase": "rule", "text": "+1 Credit after a round won with at least three placements unused."},
	{"id": "tiny_insurance", "name": "Tiny Insurance", "rarity": COMMON, "phase": "rule", "text": "Once per round, when no offered shape fits and no tray Refresh is available, replace one unplaced shape with a Single before defeat is checked."},
	{"id": "second_look", "name": "Second Look", "rarity": COMMON, "phase": "rule", "text": "The first Refresh each round also grants +1 placement."},
	{"id": "wide_awake", "name": "Wide Awake", "rarity": UNCOMMON, "phase": "add_mult", "text": "+2 Mult when two or more lines clear in a placement."},
	{"id": "hollow_point", "name": "Hollow Point", "rarity": UNCOMMON, "phase": "add_mult", "text": "+1.5 Mult when the board has at least 32 empty cells before placement."},
	{"id": "pressure_cooker", "name": "Pressure Cooker", "rarity": UNCOMMON, "phase": "add_mult", "text": "+0.5 Mult for every four occupied cells before placement (max +4)."},
	{"id": "golden_ratio", "name": "Golden Ratio", "rarity": UNCOMMON, "phase": "x_mult", "text": "Every third placed shape in a round gets x1.5 Mult."},
	{"id": "color_cycle", "name": "Color Cycle", "rarity": UNCOMMON, "phase": "x_mult", "color": true, "text": "When the last three placed shapes this round all have different colors, the third gains x2 Mult."},
	{"id": "patch_panel", "name": "Patch Panel", "rarity": UNCOMMON, "phase": "rule", "implemented": false, "text": "After the first clear each round, remove one extra occupied cell of your choice. This removal cannot clear a line."},
	{"id": "long_game", "name": "Long Game", "rarity": UNCOMMON, "phase": "rule", "text": "+1 placement per round. The first three placements of each round gain no cell Chips."},
	{"id": "fire_sale", "name": "Fire Sale", "rarity": UNCOMMON, "phase": "add_mult", "text": "+0.25 Mult for each Joker sold this run (max +2). Selling this card ends its bonus."},
	{"id": "jackpot_window", "name": "Jackpot Window", "rarity": RARE, "phase": "x_mult", "text": "If exactly three lines clear in one placement, x4 Mult."},
	{"id": "mirror_maze", "name": "Mirror Maze", "rarity": RARE, "phase": "chips", "text": "The first row clear each round also clears the mirrored row's occupied cells for +50 Chips. The mirrored removal cannot chain."},
	{"id": "compound_interest", "name": "Compound Interest", "rarity": RARE, "phase": "x_mult", "text": "Every second clearing placement in a round gets x1.75 Mult."},
	{"id": "last_stand", "name": "Last Stand", "rarity": RARE, "phase": "x_mult", "text": "When no Refresh and three or fewer placements remain, placements gain x2 Mult."},
]

static var _by_id := {}


static func get_def(id: String) -> Dictionary:
	if _by_id.is_empty():
		for d in CATALOG:
			_by_id[d.id] = d
	return _by_id.get(id, {})


static func cost(id: String) -> int:
	return RARITY_COST[int(get_def(id).get("rarity", COMMON))]


static func sell_value(id: String) -> int:
	return ceili(cost(id) / 2.0)


static func is_color_dependent(id: String) -> bool:
	return bool(get_def(id).get("color", false))


static func is_implemented(id: String) -> bool:
	return bool(get_def(id).get("implemented", true))


static func is_unique(id: String) -> bool:
	return bool(get_def(id).get("unique", false))


static func ids_of_rarity(rarity: int) -> Array[String]:
	var out: Array[String] = []
	for d in CATALOG:
		if int(d.rarity) == rarity and bool(d.get("implemented", true)):
			out.append(d.id)
	return out


# --- Scoring effects -------------------------------------------------------------------
# ctx is built by BMResolver: see BMResolver._make_context for fields.


## Additive Chips (pipeline step 4). Returns 0 when the card does not trigger.
static func chips(id: String, ctx: Dictionary) -> int:
	match id:
		"clean_sweep":
			return 50 if ctx.lines == 1 else 0
		"crossbar":
			return 100 if ctx.rows > 0 and ctx.cols > 0 else 0
		"small_change":
			return 20 * ctx.cell_count if ctx.cell_count <= 3 else 0
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
	return 0


## Additive Mult (pipeline step 5).
static func add_mult(id: String, ctx: Dictionary) -> float:
	match id:
		"blue_mood":
			return 1.0 if ctx.color == BMShapes.COLOR_BLUE else 0.0
		"chain_link":
			return 0.5 * ctx.combo_before if ctx.is_clearing else 0.0
		"wide_awake":
			return 2.0 if ctx.lines >= 2 else 0.0
		"hollow_point":
			return 1.5 if ctx.empty_before >= 32 else 0.0
		"pressure_cooker":
			return minf(4.0, 0.5 * floori(ctx.occupied_before / 4.0))
		"fire_sale":
			return minf(2.0, 0.25 * ctx.jokers_sold)
	return 0.0


## Multiplicative Mult (pipeline step 6). Returns 1.0 when the card does not trigger.
static func x_mult(id: String, ctx: Dictionary) -> float:
	match id:
		"golden_ratio":
			return 1.5 if ctx.placement_index % 3 == 0 else 1.0
		"color_cycle":
			var h: Array = ctx.color_history
			if h.size() >= 3:
				var a: int = h[h.size() - 3]
				var b: int = h[h.size() - 2]
				var c: int = h[h.size() - 1]
				if a != b and b != c and a != c:
					return 2.0
			return 1.0
		"jackpot_window":
			return 4.0 if ctx.lines == 3 else 1.0
		"compound_interest":
			return 1.75 if ctx.is_clearing and ctx.clearing_index % 2 == 0 else 1.0
		"last_stand":
			return 2.0 if ctx.refreshes_available == 0 and ctx.placements_left_before <= 3 else 1.0
	return 1.0


## Live counter text for card tooltips/HUD, or "" when the card has none.
static func counter_text(id: String, run: BMRun) -> String:
	match id:
		"golden_ratio":
			var next := 3 - (run.round_state.placements_made % 3)
			return "Next trigger in %d placement(s)" % next
		"compound_interest":
			return "Clearing placements this round: %d" % run.round_state.clearing_placements
		"color_cycle":
			var names := PackedStringArray()
			var h: Array = run.round_state.color_history
			for i in range(maxi(0, h.size() - 2), h.size()):
				names.append(BMShapes.COLOR_NAMES[h[i]])
			return "Recent colors: %s" % (", ".join(names) if names.size() > 0 else "none")
		"fire_sale":
			return "Jokers sold this run: %d" % run.jokers_sold
		"first_strike":
			return "Used this round" if run.round_state.clearing_placements > 0 else "Ready"
		"tiny_insurance":
			return "Used this round" if run.round_state.tiny_insurance_used else "Ready"
		"mirror_maze":
			return "Used this round" if run.round_state.mirror_used else "Ready"
	return ""
