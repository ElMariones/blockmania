class_name BMTrayGenerator
extends RefCounted
## Seeded tray dealing (GDD §4 "Shape tray" and "Refresh and failure").
## Guarantees: at least one dealt shape fits the board at deal time; no more than two
## identical colors in a dealt set; a dealt set never repeats the previous one exactly.
## Rejected draws are counted for replay debugging. The generator never edits the board.

const MAX_ATTEMPTS := 400


## Returns {shapes: Array[Dictionary], rejected: int, forced: bool}.
static func deal(rng: BMRngStream, board: BMBoard, round_number: int, count: int, previous_signature: String) -> Dictionary:
	var fams := BMShapes.available_families(round_number)
	var weights: Array = []
	for f in fams:
		weights.append(int(f.weight))
	var rejected := 0
	for attempt in MAX_ATTEMPTS:
		var shapes: Array = []
		var color_counts := {}
		for i in count:
			var fam: Dictionary = fams[rng.weighted_index(weights)]
			var rot_count := BMShapes.rotations(fam.id).size()
			var rot := rng.randi_range(0, rot_count - 1)
			var color := rng.randi_range(0, BMShapes.OFFER_COLOR_COUNT - 1)
			while int(color_counts.get(color, 0)) >= 2:
				color = rng.randi_range(0, BMShapes.OFFER_COLOR_COUNT - 1)
			color_counts[color] = int(color_counts.get(color, 0)) + 1
			shapes.append(BMShapes.make_shape(fam.id, rot, color))
		if not any_fits(board, shapes):
			rejected += 1
			continue
		if signature_of(shapes) == previous_signature:
			rejected += 1
			continue
		return {"shapes": shapes, "rejected": rejected, "forced": false}
	# Practically unreachable: a board with any empty cell accepts a Single (8% weight),
	# so 400 rejected sets would be astronomically unlikely. Deterministic fallback only.
	var fallback: Array = []
	for i in count:
		fallback.append(BMShapes.make_shape(&"single", 0, i % BMShapes.OFFER_COLOR_COUNT))
	return {"shapes": fallback, "rejected": rejected, "forced": true}


static func any_fits(board: BMBoard, shapes: Array) -> bool:
	for s in shapes:
		if s is Dictionary and not s.is_empty() and board.fits_anywhere(s.cells):
			return true
	return false


static func signature_of(shapes: Array) -> String:
	var parts := PackedStringArray()
	for s in shapes:
		parts.append(BMShapes.signature(s if s is Dictionary else {}))
	return "|".join(parts)
