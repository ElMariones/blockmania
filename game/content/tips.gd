class_name BMTips
extends RefCounted
## Contextual tips (GDD §22.9): a short hint the first time something shows up. Each tip has
## a stable id, a title and text, and a condition that only reads state. Seen ids live in the
## settings ("tips_seen"), so they survive runs; Settings > Game > Tips turns them off and
## RESET TIPS shows them again. Presentation only: tips never touch the run.

const CATALOG := [
	{"id": "welcome", "title": "Place a piece",
		"text": "Drag a piece from the tray onto the board, or click it and then a cell. Fill a whole row or column to clear it: clears are where the points are."},
	{"id": "score", "title": "Chips x Mult",
		"text": "Every placement scores Chips x Mult. Cells and cleared lines give Chips; Jokers, combos and Tray Hands add Mult. The receipt shows the math."},
	{"id": "hold", "title": "Hold",
		"text": "Press H or drop a piece on HOLD to keep it for later; it deals a new one. You can hold or swap once between placements."},
	{"id": "refresh", "title": "Nothing fits",
		"text": "No piece fits the board. REFRESH (R) swaps the whole tray for new pieces. If nothing fits and neither a Refresh nor your held piece helps, the round is lost."},
	{"id": "combo", "title": "Combo",
		"text": "Clearing on placement after placement builds a combo that adds Mult. A few placements without a clear break it."},
	{"id": "hand", "title": "Tray Hand",
		"text": "The three dealt pieces form a Hand (same family, same color, a staircase...). The tag on each piece says what it adds while you place them."},
	{"id": "boss", "title": "Boss round",
		"text": "Each act ends with a boss that bends one rule for this round. Its rule is on the left panel; hover it any time."},
	{"id": "heat", "title": "Heat",
		"text": "Heat makes every run harder: bigger targets, fewer placements, Mk II bosses. Each Heat you win unlocks the next."},
	{"id": "shop", "title": "The Toybox",
		"text": "Spend Credits here. Jokers score for you every placement, items are one-use tools, and Workshop cards change the pieces in your bag."},
	{"id": "interest", "title": "Interest",
		"text": "Unspent Credits earn interest after each round: +1 for every 5 you hold, up to +5 (less at Heat 3+). Saving can pay off."},
	{"id": "round_cards", "title": "Choose the next round",
		"text": "Standard, or a twist: a harder target or a special rule for a bigger reward. Boss rounds never offer a choice."},
	{"id": "bag", "title": "Your bag",
		"text": "B (or the BAG button) shows every piece you own and what is still to draw. The tray is dealt from this bag, not at random."},
	{"id": "overtime", "title": "Overtime",
		"text": "Targets keep growing and a new boss arrives every four rounds. How far can the machine go?"},
]

static var _by_id := {}


static func get_def(id: String) -> Dictionary:
	if _by_id.is_empty():
		for d in CATALOG:
			_by_id[d.id] = d
	return _by_id.get(id, {})


static func ids() -> Array[String]:
	var out: Array[String] = []
	for d in CATALOG:
		out.append(String(d.id))
	return out


## The first unseen tip whose condition holds during a round, or "".
static func for_round(run: BMRun, seen: Array) -> String:
	if run == null or run.phase != BMRun.Phase.ROUND:
		return ""
	var rs := run.round_state
	var checks := [
		["boss", run.current_boss() != "" and rs.placements_made == 0],
		["heat", run.heat > 0 and run.round_number == 1],
		["overtime", run.round_number > BMRunConfig.ROUND_COUNT],
		["welcome", run.round_number == 1 and rs.placements_made == 0],
		["refresh", not BMBag.any_fits(run.board, run.tray) and run.refreshes_available() > 0],
		["hand", _tray_has_hand(run)],
		["combo", rs.combo >= 2],
		["score", rs.placements_made >= 1],
		["hold", rs.placements_made >= 3 or run.round_number >= 2],
	]
	for c in checks:
		if c[1] and not seen.has(c[0]):
			return String(c[0])
	return ""


## The first unseen tip for the shop, or "".
static func for_shop(run: BMRun, seen: Array) -> String:
	if run == null or run.phase != BMRun.Phase.SHOP:
		return ""
	var checks := [
		["shop", true],
		["interest", run.credits >= BMRunConfig.INTEREST_STEP],
		["bag", run.round_number >= 2],
	]
	for c in checks:
		if c[1] and not seen.has(c[0]):
			return String(c[0])
	return ""


static func _tray_has_hand(run: BMRun) -> bool:
	for p in run.tray:
		if not p.is_empty() and String(p.get("hand", "")) != "":
			return true
	return false
