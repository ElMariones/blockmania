class_name BMBosses
extends RefCounted
## Boss rules (GDD §6 "Acts and bosses"). One boss per act at rounds 4, 8, 12.
## Bosses never repeat within a run; the final boss comes from the `final` subset.

const CATALOG := [
	{"id": "cramped_cabinet", "name": "The Cramped Cabinet", "final": false,
		"rule": "The round begins with four fixed occupied cells. They clear normally and score no placement Chips.",
		"counter": "Favor small shapes or board-clearing tools."},
	{"id": "taxman", "name": "The Taxman", "final": false,
		"rule": "The first line cleared by each placement grants 60 instead of 100 base Chips.",
		"counter": "Pursue double clears and flat Chip Jokers."},
	{"id": "color_blind", "name": "The Color Blind", "final": false,
		"rule": "Effects that name a block color are disabled this round.",
		"counter": "Diversify beyond color-dependent scoring."},
	# Withheld from the pool: only extra clear waves are affected, and no current card can
	# create one, so this boss would have no effect. Owner decision pending (GDD §13).
	{"id": "echo_chamber", "name": "The Echo Chamber", "final": false, "in_pool": false,
		"rule": "Extra clear waves after the first score half Chips before Jokers.",
		"counter": "Prefer immediate clears over chained board effects."},
	{"id": "lockdown", "name": "The Lockdown", "final": false,
		"rule": "The free Refresh and Second Tray are unavailable this round.",
		"counter": "Plan tray order and preserve board space."},
	{"id": "warden", "name": "The Warden", "final": false,
		"rule": "One tray slot starts barred: its piece can't be played until you clear a line. Deals skip the barred slot.",
		"counter": "Open with a quick clear using the other two slots."},
	{"id": "undertaker", "name": "The Undertaker", "final": false,
		"rule": "After every 4th placement, a tombstone rises on an empty cell. It clears with its line like any block.",
		"counter": "Clear often and keep lanes open."},
	{"id": "last_call", "name": "The Last Call", "final": true,
		"rule": "Only 12 placements. Each multi-line placement gains +50 Chips.",
		"counter": "Prepare efficient shapes and simultaneous clears."},
]

const FIXED_CELL_COUNT := 4
const UNDERTAKER_EVERY := 4
const TAXMAN_FIRST_LINE_CHIPS := 60
const LAST_CALL_PLACEMENTS := 12
const LAST_CALL_MULTI_LINE_CHIPS := 50

static var _by_id := {}


static func get_def(id: String) -> Dictionary:
	if _by_id.is_empty():
		for d in CATALOG:
			_by_id[d.id] = d
	return _by_id.get(id, {})


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


## Four distinct seeded cells for The Cramped Cabinet. Four cells can never complete a line.
static func cramped_cells(rng: BMRngStream) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	while out.size() < FIXED_CELL_COUNT:
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
