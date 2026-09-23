class_name BMFeats
extends RefCounted
## Feats (docs/design/round_play_update.md §5): named accomplishments detected by the resolver
## from the placement record. They add no score by themselves; Jokers (Showboat) and presentation
## read them. Stable ids: save- and replay-facing.

const CATALOG := {
	"crossfire": {"name": "Crossfire", "text": "Clear a row and a column in the same placement."},
	"double_tap": {"name": "Double Tap", "text": "Clear lines on two placements in a row."},
	"hat_trick": {"name": "Hat Trick", "text": "Clear three or more lines in one placement."},
	"clean_board": {"name": "Clean Board", "text": "Leave the board completely empty."},
	"needle_threader": {"name": "Needle Threader", "text": "Fill a one-block hole (closed on all four sides) and clear a line with it."},
	"last_breath": {"name": "Last Breath", "text": "Clear a line with your last placement."},
}
## Display order (rarest last so the biggest banner lands on top).
const ORDER := ["double_tap", "crossfire", "last_breath", "needle_threader", "hat_trick", "clean_board"]


static func get_def(id: String) -> Dictionary:
	return CATALOG.get(id, {})


## Feats earned by one placement. `c` holds: rows, cols, lines, combo_before, holes_filled,
## placements_left_before, empty_after (occupied cells left once the clear resolves).
static func detect(c: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var clearing: bool = c.lines > 0
	if not clearing:
		return out
	if c.combo_before > 0:
		out.append("double_tap")
	if c.rows > 0 and c.cols > 0:
		out.append("crossfire")
	if c.placements_left_before <= 1:
		out.append("last_breath")
	if c.holes_filled > 0:
		out.append("needle_threader")
	if c.lines >= 3:
		out.append("hat_trick")
	if c.occupied_after == 0:
		out.append("clean_board")
	return out
