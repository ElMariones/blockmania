class_name BMBag
extends RefCounted
## Dealing trays from the run's bag (GDD §16.2). Pure rules, operating on BMRun fields:
##   run.bag          all pieces the player owns (persistent across rounds)
##   run.draw_pile    uids still to be drawn this round, front = next
##   run.discard_pile uids placed or refreshed away this round
## Each round starts with the whole bag shuffled into the draw pile. An empty draw pile is
## refilled by shuffling the discard pile back in. Every dealt tray must contain at least one
## piece that fits the board (legality guarantee), achieved by swapping in the first fitting
## piece from the draw pile, then the discard pile; only if no owned piece fits anywhere is a
## temporary Single (uid -1) dealt. All randomness uses the run's shapes stream.


static func shuffle(rng: BMRngStream, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


static func start_round(run: BMRun) -> void:
	run.draw_pile = []
	for p in run.bag:
		run.draw_pile.append(int(p.uid))
	shuffle(run.rng_shapes, run.draw_pile)
	run.discard_pile = []


static func any_fits(board: BMBoard, pieces: Array) -> bool:
	for p in pieces:
		if p is Dictionary and not p.is_empty() and board.fits_anywhere(p.cells):
			return true
	return false


static func piece_by_uid(run: BMRun, uid: int) -> Dictionary:
	for p in run.bag:
		if int(p.uid) == uid:
			return p
	return {}


## Draws the next piece (a fresh copy with cells), reshuffling the discard pile if needed.
static func draw_one(run: BMRun) -> Dictionary:
	if run.draw_pile.is_empty() and not run.discard_pile.is_empty():
		run.draw_pile = run.discard_pile.duplicate()
		run.discard_pile = []
		shuffle(run.rng_shapes, run.draw_pile)
		run.round_state.reshuffles += 1
	if run.draw_pile.is_empty():
		return {}
	var uid: int = run.draw_pile.pop_front()
	return piece_by_uid(run, uid).duplicate(true)


## Fills the given tray slots from the draw pile, then enforces the legality guarantee.
## Returns {rescued: bool (a swap happened), temporary: bool (a temporary Single was dealt)}.
static func deal(run: BMRun, slots: Array) -> Dictionary:
	for s in slots:
		run.tray[s] = draw_one(run)
	return ensure_legal(run, slots)


static func ensure_legal(run: BMRun, slots: Array) -> Dictionary:
	var result := {"rescued": false, "temporary": false}
	for i in run.tray.size():
		var p: Dictionary = run.tray[i]
		if not p.is_empty() and not run.slot_locked(i) and run.board.fits_anywhere(p.cells):
			return result
	if slots.is_empty():
		return result
	var slot: int = slots[slots.size() - 1]
	for pile_name in ["draw_pile", "discard_pile"]:
		var pile: Array = run.get(pile_name)
		for i in pile.size():
			var candidate := piece_by_uid(run, int(pile[i]))
			if not candidate.is_empty() and run.board.fits_anywhere(candidate.cells):
				var replaced: Dictionary = run.tray[slot]
				if replaced.is_empty() or int(replaced.uid) < 0:
					pile.remove_at(i)
				else:
					pile[i] = int(replaced.uid)
				run.tray[slot] = candidate.duplicate(true)
				result.rescued = true
				run.round_state.rescued_deals += 1
				return result
	# No owned piece fits anywhere: deal a temporary Single (kept out of the bag).
	var old: Dictionary = run.tray[slot]
	if not old.is_empty() and int(old.uid) >= 0:
		run.draw_pile.append(int(old.uid))
	var color: int = int(old.color) if not old.is_empty() else 0
	run.tray[slot] = BMPieces.temporary_single(color)
	result.temporary = true
	run.round_state.rescued_deals += 1
	return result


## Moves a piece that left the tray (placed or refreshed away) to the discard pile.
static func discard(run: BMRun, piece: Dictionary) -> void:
	var uid := int(piece.get("uid", -1))
	if uid >= 0 and not piece_by_uid(run, uid).is_empty():
		run.discard_pile.append(uid)


## Removes a piece from the bag and every pile. Returns false if the bag is at minimum size.
static func remove_piece(run: BMRun, uid: int) -> bool:
	if run.bag.size() <= BMPieces.MIN_BAG:
		return false
	for i in run.bag.size():
		if int(run.bag[i].uid) == uid:
			run.bag.remove_at(i)
			run.draw_pile.erase(uid)
			run.discard_pile.erase(uid)
			return true
	return false


static func add_piece(run: BMRun, piece: Dictionary) -> Dictionary:
	var p := BMPieces.make(run.next_uid, piece.family, int(piece.rot), int(piece.color), String(piece.get("material", "")), String(piece.get("stamp", "")))
	run.next_uid += 1
	run.bag.append(p)
	return p


static func distinct_families(run: BMRun) -> int:
	var seen := {}
	for p in run.bag:
		seen[p.family] = true
	return seen.size()


static func upgraded_count(run: BMRun) -> int:
	var n := 0
	for p in run.bag:
		if BMPieces.is_upgraded(p):
			n += 1
	return n


static func material_count(run: BMRun, material: String) -> int:
	var n := 0
	for p in run.bag:
		if String(p.get("material", "")) == material:
			n += 1
	return n
