class_name BMBosses
extends RefCounted
## Boss rules (GDD §6 "Acts and bosses"). One boss per act at rounds 4, 8, 12.
## Bosses never repeat within a run; the final boss comes from the `final` subset.

const CATALOG := [ # i18n: name, short, rule, rule2, counter
	{"id": "cramped_cabinet", "short": "Cramped Cabinet", "name": "The Cramped Cabinet", "final": false,
		"rule": "The round begins with four fixed occupied cells. They clear normally and score no placement Chips.",
		"rule2": "The round begins with seven fixed occupied cells. They clear normally and score no placement Chips.",
		"counter": "Favor small shapes or board-clearing tools."},
	{"id": "taxman", "short": "Taxman", "name": "The Taxman", "final": false,
		"rule": "The first line cleared by each placement grants 60 instead of 100 base Chips.",
		"rule2": "The first line cleared by each placement grants 30 instead of 100 base Chips, and multi-line Mult is halved.",
		"counter": "Pursue double clears and flat Chip Jokers."},
	{"id": "color_blind", "short": "Color Blind", "name": "The Color Blind", "final": false,
		"rule": "Effects that name a block color are disabled this round.",
		"rule2": "Effects that name a block color are disabled, and you have two fewer placements.",
		"counter": "Diversify beyond color-dependent scoring."},
	# Withheld from the pool: only extra clear waves are affected, and no current card can
	# create one, so this boss would have no effect. Owner decision pending (GDD §13).
	{"id": "echo_chamber", "short": "Echo Chamber", "name": "The Echo Chamber", "final": false, "in_pool": false,
		"rule": "Extra clear waves after the first score half Chips before Jokers.",
		"counter": "Prefer immediate clears over chained board effects."},
	{"id": "lockdown", "short": "Lockdown", "name": "The Lockdown", "final": false,
		"rule": "The free Refresh and Second Tray are unavailable this round.",
		"rule2": "Refresh, Second Tray, Coffee Break and Hold are all unavailable this round.",
		"counter": "Plan tray order and preserve board space."},
	{"id": "warden", "short": "Warden", "name": "The Warden", "final": false,
		"rule": "One tray slot starts barred: its piece can't be played until you clear a line. Deals skip the barred slot.",
		"rule2": "Two tray slots start barred. Each clearing placement frees one. Deals skip barred slots.",
		"counter": "Open with a quick clear using the other two slots."},
	{"id": "undertaker", "short": "Undertaker", "name": "The Undertaker", "final": false,
		"rule": "After every 4th placement, a tombstone rises on an empty cell. It clears with its line like any block.",
		"rule2": "After every 3rd placement, a tombstone rises on an empty cell. It clears with its line like any block.",
		"counter": "Clear often and keep lanes open."},
	{"id": "last_call", "short": "Last Call", "name": "The Last Call", "final": true,
		"rule": "Only 12 placements. Each multi-line placement gains +50 Chips.",
		"rule2": "Only 10 placements. Each multi-line placement gains +50 Chips.",
		"counter": "Prepare efficient shapes and simultaneous clears."},
]

const FIXED_CELL_COUNT := 4
const UNDERTAKER_EVERY := 4
const TAXMAN_FIRST_LINE_CHIPS := 60
const LAST_CALL_PLACEMENTS := 12
## Mk II bosses (GDD §22.3): act bosses from act 2 on, every boss at Heat 4+, the final boss in
## Overtime. `rule2` is the Mk II text.
const FIXED_CELL_COUNT_MK2 := 7
const UNDERTAKER_EVERY_MK2 := 3
const TAXMAN_FIRST_LINE_CHIPS_MK2 := 30
const LAST_CALL_PLACEMENTS_MK2 := 10
const COLOR_BLIND_MK2_PLACEMENTS := 2
const LAST_CALL_MULTI_LINE_CHIPS := 50

static var _by_id := {}


static func get_def(id: String) -> Dictionary:
	if _by_id.is_empty():
		for d in CATALOG:
			_by_id[d.id] = d
	return _by_id.get(id, {})


## Display name and rule text for a boss, Mk II or not (translated).
static func title(id: String, mk2: bool) -> String:
	return BMLoc.t(String(get_def(id).get("name", ""))) + (" Mk II" if mk2 else "")


static func rule_text(id: String, mk2: bool) -> String:
	var d := get_def(id)
	return BMLoc.t(String(d.get("rule2", d.get("rule", ""))) if mk2 else String(d.get("rule", "")))


## The name without its article ("Taxman"), for tight spaces.
static func short_title(id: String, mk2: bool) -> String:
	var d := get_def(id)
	return BMLoc.t(String(d.get("short", d.get("name", "")))) + (" Mk II" if mk2 else "")


static func counter_text(id: String) -> String:
	return BMLoc.t(String(get_def(id).get("counter", "")))


static func pool(final: bool) -> Array[String]:
	var out: Array[String] = []
	for d in CATALOG:
		if bool(d.final) == final and bool(d.get("in_pool", true)):
			out.append(d.id)
	return out


## Picks the act 1, act 2, and final bosses from the boss stream.
static func choose_run_bosses(rng: BMRngStream) -> Array[String]:
	var normal := pool(false)
	var out: Array[String] = []
	for i in 2:
		var idx := rng.randi_range(0, normal.size() - 1)
		out.append(normal[idx])
		normal.remove_at(idx)
	var finals := pool(true)
	out.append(finals[rng.randi_range(0, finals.size() - 1)])
	return out


## Overtime act boss: any boss in the pool (finals included) except the previous act's.
static func choose_overtime_boss(rng: BMRngStream, previous: String) -> String:
	var options: Array[String] = pool(false) + pool(true)
	options.erase(previous)
	return options[rng.randi_range(0, options.size() - 1)]


## Distinct seeded cells for The Cramped Cabinet (4, or 7 for Mk II). Fewer than 8 cells can
## never complete a line.
static func cramped_cells(rng: BMRngStream, count: int = FIXED_CELL_COUNT) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	while out.size() < count:
		var p := Vector2i(rng.randi_range(0, BMBoard.SIZE - 1), rng.randi_range(0, BMBoard.SIZE - 1))
		if not out.has(p):
			out.append(p)
	return out


## A seeded empty cell for The Undertaker's tombstone. Never one that would complete a row or
## column (a full line would sit uncleared until the next placement). Returns (-1, -1) if none.
static func tomb_cell(rng: BMRngStream, board: BMBoard) -> Vector2i:
	var options: Array[Vector2i] = []
	for y in BMBoard.SIZE:
		for x in BMBoard.SIZE:
			var p := Vector2i(x, y)
			if not board.is_empty(p):
				continue
			var row_gaps := 0
			var col_gaps := 0
			for i in BMBoard.SIZE:
				if board.is_empty(Vector2i(i, y)):
					row_gaps += 1
				if board.is_empty(Vector2i(x, i)):
					col_gaps += 1
			if row_gaps > 1 and col_gaps > 1:
				options.append(p)
	if options.is_empty():
		return Vector2i(-1, -1)
	return options[rng.randi_range(0, options.size() - 1)]
