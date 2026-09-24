class_name BMHands
extends RefCounted
## Tray Hands (docs/design/round_play_update.md §2). When a full three-piece tray is dealt
## naturally (round start or after the tray empties; not by Refresh, Second Tray, or Tiny
## Insurance), its pattern is checked once. The tray gets at most one Hand, the highest ranked.
## Hand pieces are marked (`piece.hand`), and the resolver reads the mark, so previews, replays,
## and saves agree. Pure rules: no nodes, no randomness.

const TWINS := "twins"
const STAIRCASE := "staircase"
const MONOCHROME := "monochrome"
const TRIPLETS := "triplets"
const GRAND_SLAM := "grand_slam"

## Highest rank first. `short` is the badge text; `text` the full rule for tooltips.
const DEFS := {
	GRAND_SLAM: {"name": "Grand Slam", "badge": "SLAM!", "short": "x2 MULT, +2 MULT, +1 REFRESH, +3 CREDITS",
		"text": "Three pieces of the same family and the same color. Every placement from this tray gets +2 Mult and x2 Mult; you gain +1 Refresh this round and 3 Credits."},
	TRIPLETS: {"name": "Triplets", "badge": "TRIPLETS", "short": "+2 MULT, x1.5 MULT EACH, +1 REFRESH",
		"text": "Three pieces of the same family. Every placement from this tray gets +2 Mult and x1.5 Mult, and you gain +1 Refresh this round."},
	MONOCHROME: {"name": "Monochrome", "badge": "MONO", "short": "x2 MULT EACH",
		"text": "Three pieces of the same color (Prism counts as any color). Every placement from this tray gets x2 Mult."},
	STAIRCASE: {"name": "Staircase", "badge": "STAIRS", "short": "+1 PLACEMENT",
		"text": "Cell counts in a row, like 2-3-4. You gain +1 placement (it can go above your refill cap)."},
	TWINS: {"name": "Twins", "badge": "TWINS", "short": "+1 MULT EACH",
		"text": "Exactly two pieces of the same family. Every placement from this tray gets +1 Mult."},
}
const ORDER := [GRAND_SLAM, TRIPLETS, MONOCHROME, STAIRCASE, TWINS]

## Rebalanced 2026-09-24 (docs/playtests): the common Hands were noise and the rare ones too
## small for how rarely they form.
const TWINS_MULT := 1.0
const TRIPLETS_MULT := 2.0
const TRIPLETS_X_MULT := 1.5
const MONOCHROME_X_MULT := 2.0
const STAIRCASE_PLACEMENTS := 1
const TRIPLETS_REFRESHES := 1
const GRAND_SLAM_CREDITS := 3


static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})


## The Hand formed by exactly three dealt pieces, or "" (temporary pieces never form one).
static func detect(pieces: Array) -> String:
	var ps: Array = []
	for p in pieces:
		if not (p is Dictionary) or p.is_empty():
			return ""
		if bool(p.get("temporary", false)):
			return ""
		ps.append(p)
	if ps.size() != 3:
		return ""
	var families := {}
	for p in ps:
		families[String(p.family)] = true
	var mono := _same_color(ps)
	if families.size() == 1:
		return GRAND_SLAM if mono else TRIPLETS
	if mono:
		return MONOCHROME
	if families.size() == 2:
		return TWINS
	var sizes: Array = []
	for p in ps:
		sizes.append(p.cells.size())
	sizes.sort()
	if sizes[1] == sizes[0] + 1 and sizes[2] == sizes[1] + 1:
		return STAIRCASE
	return ""


## Prism pieces count as every color.
static func _same_color(ps: Array) -> bool:
	var color := -1
	for p in ps:
		if String(p.get("material", "")) == "prism":
			continue
		if color < 0:
			color = int(p.color)
		elif int(p.color) != color:
			return false
	return true


## Chance of each Hand for a natural deal of three pieces drawn from the whole bag
## (composition only, so it never reveals draw order). Exact enumeration: C(60, 3) = 34,220 at
## the bag's maximum size. Returns {hand_id: probability, "any": probability}.
static func odds(bag: Array) -> Dictionary:
	var out := {"any": 0.0}
	for id in ORDER:
		out[id] = 0.0
	var n := bag.size()
	if n < 3:
		return out
	var total := 0
	for i in n:
		for j in range(i + 1, n):
			for k in range(j + 1, n):
				total += 1
				var h := detect([bag[i], bag[j], bag[k]])
				if h != "":
					out[h] += 1.0
					out.any += 1.0
	for key in out:
		out[key] = out[key] / total
	return out
