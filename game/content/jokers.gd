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
	{"id": "crossbar", "name": "Crossbar", "rarity": COMMON, "phase": "chips", "text": "+150 Chips when a row and a column clear together."},
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
	{"id": "wide_awake", "name": "Wide Awake", "rarity": UNCOMMON, "phase": "add_mult", "text": "+3 Mult when two or more lines clear in a placement."},
	{"id": "hollow_point", "name": "Hollow Point", "rarity": UNCOMMON, "phase": "add_mult", "text": "+0.5 Mult when the board has at least 44 empty cells before placement."},
	{"id": "pressure_cooker", "name": "Pressure Cooker", "rarity": UNCOMMON, "phase": "add_mult", "text": "+0.5 Mult for every eight occupied cells before placement (max +2)."},
	{"id": "golden_ratio", "name": "Golden Ratio", "rarity": UNCOMMON, "phase": "x_mult", "text": "Every third placed shape in a round gets x1.5 Mult."},
	{"id": "color_cycle", "name": "Color Cycle", "rarity": UNCOMMON, "phase": "x_mult", "color": true, "text": "When the last three placed shapes this round all have different colors, the third gains x1.75 Mult."},
	{"id": "patch_panel", "name": "Patch Panel", "rarity": UNCOMMON, "phase": "rule", "implemented": false, "text": "After the first clear each round, remove one extra occupied cell of your choice. This removal cannot clear a line."},
	{"id": "long_game", "name": "Long Game", "rarity": UNCOMMON, "phase": "rule", "text": "+1 placement per round. The first placement of each round gains no cell Chips."},
	{"id": "fire_sale", "name": "Fire Sale", "rarity": UNCOMMON, "phase": "add_mult", "text": "+0.25 Mult for each Joker sold this run (max +2). Selling this card ends its bonus."},
	{"id": "jackpot_window", "name": "Jackpot Window", "rarity": RARE, "phase": "x_mult", "text": "If three or more lines clear in one placement, x4 Mult."},
	{"id": "mirror_maze", "name": "Mirror Maze", "rarity": RARE, "phase": "chips", "text": "The first row clear each round also clears the mirrored row's occupied cells for +50 Chips. The mirrored removal cannot chain."},
	{"id": "compound_interest", "name": "Compound Interest", "rarity": RARE, "phase": "x_mult", "text": "Every second clearing placement in a round gets x1.75 Mult."},
	{"id": "last_stand", "name": "Last Stand", "rarity": RARE, "phase": "x_mult", "text": "When no Refresh and three or fewer placements remain, placements gain x2 Mult."},
	# --- Bag-era Jokers (GDD §16.6) ---
	{"id": "hoarder", "name": "Hoarder", "rarity": UNCOMMON, "phase": "chips", "text": "+1 Chip for each piece in your bag."},
	{"id": "architect", "name": "Architect", "rarity": COMMON, "phase": "chips", "text": "+60 Chips when placing an L 3 or L 4 piece."},
	{"id": "straight_edge", "name": "Straight Edge", "rarity": COMMON, "phase": "chips", "text": "+15 Chips per cell when placing a Bar piece."},
	{"id": "square_deal", "name": "Square Deal", "rarity": COMMON, "phase": "add_mult", "text": "+2 Mult when placing a Square piece."},
	{"id": "last_piece", "name": "Last Piece", "rarity": COMMON, "phase": "chips", "text": "+80 Chips when this placement empties the tray."},
	{"id": "postmaster", "name": "Postmaster", "rarity": COMMON, "phase": "chips", "text": "+40 Chips when placing a stamped piece."},
	{"id": "lean_bag", "name": "Lean Bag", "rarity": UNCOMMON, "phase": "add_mult", "text": "+0.25 Mult for each piece your bag has below 24 (max +3)."},
	{"id": "foundry", "name": "Foundry", "rarity": UNCOMMON, "phase": "chips", "text": "+8 Chips for each upgraded piece (material or stamp) in your bag."},
	{"id": "neon_sign", "name": "Neon Sign", "rarity": UNCOMMON, "phase": "add_mult", "text": "Neon cells cleared give an extra +0.5 Mult each."},
	{"id": "specialist", "name": "Specialist", "rarity": UNCOMMON, "phase": "add_mult", "text": "+0.5 Mult per Schematic level of the placed piece's family."},
	{"id": "recycler", "name": "Recycler", "rarity": UNCOMMON, "phase": "add_mult", "text": "+0.1 Mult for each piece in the discard pile before placement (max +1)."},
	{"id": "glass_cannon", "name": "Glass Cannon", "rarity": RARE, "phase": "x_mult", "text": "x1.5 Mult when a placement clears any Glass cell."},
	{"id": "collector", "name": "Collector", "rarity": RARE, "phase": "x_mult", "text": "x0.1 Mult for each different shape family in your bag beyond 6 (x1.4 with 10 families)."},
	{"id": "mimic", "name": "Mimic", "rarity": RARE, "phase": "copy", "text": "Copies the scoring effect of the Joker directly below it."},
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
			return 150 if ctx.rows > 0 and ctx.cols > 0 else 0
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
			return 8 * ctx.upgraded_count
	return 0


## Additive Mult (pipeline step 5).
static func add_mult(id: String, ctx: Dictionary) -> float:
	match id:
		"blue_mood":
			return 2.0 if ctx.color == BMShapes.COLOR_BLUE or ctx.prism else 0.0
		"chain_link":
			return 1.0 * ctx.combo_before if ctx.is_clearing else 0.0
		"wide_awake":
			return 3.0 if ctx.lines >= 2 else 0.0
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
	return 0.0


## Multiplicative Mult (pipeline step 6). Returns 1.0 when the card does not trigger.
static func x_mult(id: String, ctx: Dictionary) -> float:
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
			return 1.5 if ctx.glass_cleared > 0 else 1.0
		"collector":
			return 1.0 + 0.1 * maxi(0, ctx.distinct_families - 6)
		"jackpot_window":
			return 4.0 if ctx.lines >= 3 else 1.0
		"compound_interest":
			return 1.75 if ctx.is_clearing and ctx.clearing_index % 2 == 0 else 1.0
		"last_stand":
			return 2.0 if ctx.refreshes_available == 0 and ctx.placements_left_before <= 3 else 1.0
	return 1.0


static func _same_color(a: int, b: int) -> bool:
	return a >= 0 and b >= 0 and a == b


## Live counter text for card tooltips/HUD, or "" when the card has none.
static func counter_text(id: String, run: BMRun) -> String:
	match id:
		"golden_ratio":
			var next := 3 - (run.round_state.placements_made % 3)
			return "Triggers in %d placement%s" % [next, "" if next == 1 else "s"]
		"compound_interest":
			return "Clears this round: %d" % run.round_state.clearing_placements
		"color_cycle":
			var names := PackedStringArray()
			var h: Array = run.round_state.color_history
			for i in range(maxi(0, h.size() - 2), h.size()):
				names.append(BMShapes.COLOR_NAMES[h[i]])
			return "Recent: %s" % (", ".join(names) if names.size() > 0 else "none")
		"fire_sale":
			return "Jokers sold: %d" % run.jokers_sold
		"first_strike":
			return "Used this round" if run.round_state.clearing_placements > 0 else "Ready"
		"tiny_insurance":
			return "Used this round" if run.round_state.tiny_insurance_used else "Ready"
		"mirror_maze":
			return "Used this round" if run.round_state.mirror_used else "Ready"
		"hoarder":
			return "%d pieces: +%d Chips" % [run.bag.size(), run.bag.size()]
		"lean_bag":
			return "%d pieces: +%s Mult" % [run.bag.size(), str(minf(3.0, 0.25 * maxi(0, 24 - run.bag.size())))]
		"foundry":
			return "%d upgraded: +%d Chips" % [BMBag.upgraded_count(run), 8 * BMBag.upgraded_count(run)]
		"collector":
			var fams := BMBag.distinct_families(run)
			return "%d families: x%s Mult" % [fams, str(1.0 + 0.1 * maxi(0, fams - 6))]
		"recycler":
			return "Discard pile: %d" % run.discard_pile.size()
		"mimic":
			var i := run.jokers.find("mimic")
			if i >= 0 and i + 1 < run.jokers.size():
				return "Copying: %s" % get_def(run.jokers[i + 1]).name
			return "Copying: nothing below"
	return ""


## True when `id` has a scoring phase that Mimic can copy.
static func is_copyable(id: String) -> bool:
	return String(get_def(id).get("phase", "")) in ["chips", "add_mult", "x_mult"] and id != "mimic"
