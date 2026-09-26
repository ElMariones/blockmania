class_name BMShapes
extends RefCounted
## Shape families, colors, and helpers. Data from GDD §4 "Shape tray" (weights provisional).
## A shape instance is a Dictionary: {family: StringName, rot: int, cells: Array[Vector2i], color: int}.
## Cells are normalized so the bounding box starts at (0, 0); the anchor is that top-left corner.

const COLOR_RED := 0
const COLOR_ORANGE := 1
const COLOR_YELLOW := 2
const COLOR_GREEN := 3
const COLOR_BLUE := 4
const COLOR_PURPLE := 5
## Boss-placed fixed cells (The Cramped Cabinet). Never offered in the tray.
const COLOR_STONE := 6
const OFFER_COLOR_COUNT := 6
const COLOR_NAMES := ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Stone"] # i18n

## Family definitions. `weight` (percent) now only weights random piece offers in the shop;
## trays are dealt from the player's bag (BMBag). `min_round` is kept for reference only.
const FAMILIES := [ # i18n: name
	{"id": &"single", "name": "Single", "weight": 8, "min_round": 1, "cells": [[0, 0]]},
	{"id": &"bar2", "name": "Bar 2", "weight": 12, "min_round": 1, "cells": [[0, 0], [1, 0]]},
	{"id": &"bar3", "name": "Bar 3", "weight": 14, "min_round": 1, "cells": [[0, 0], [1, 0], [2, 0]]},
	{"id": &"l3", "name": "L 3", "weight": 10, "min_round": 1, "cells": [[0, 0], [0, 1], [1, 1]]},
	{"id": &"square2", "name": "Square 2x2", "weight": 10, "min_round": 1, "cells": [[0, 0], [1, 0], [0, 1], [1, 1]]},
	{"id": &"bar4", "name": "Bar 4", "weight": 10, "min_round": 1, "cells": [[0, 0], [1, 0], [2, 0], [3, 0]]},
	{"id": &"l4", "name": "L 4", "weight": 9, "min_round": 1, "cells": [[0, 0], [0, 1], [0, 2], [1, 2]]},
	{"id": &"t4", "name": "T 4", "weight": 8, "min_round": 1, "cells": [[0, 0], [1, 0], [2, 0], [1, 1]]},
	{"id": &"zigzag4", "name": "Zigzag 4", "weight": 8, "min_round": 1, "cells": [[1, 0], [2, 0], [0, 1], [1, 1]]},
	{"id": &"plus5", "name": "Plus 5", "weight": 5, "min_round": 1, "cells": [[1, 0], [0, 1], [1, 1], [2, 1], [1, 2]]},
	{"id": &"bar5", "name": "Bar 5", "weight": 4, "min_round": 3, "cells": [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]]},
	{"id": &"square3", "name": "Square 3x3", "weight": 2, "min_round": 3, "cells": [[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [2, 1], [0, 2], [1, 2], [2, 2]]},
	# Endless-only offer for now; campaign shop weight stays zero.
	{"id": &"rect2x3", "name": "Rectangle 2x3", "weight": 0, "min_round": 99, "cells": [[0, 0], [1, 0], [0, 1], [1, 1], [0, 2], [1, 2]]},
]

static var _rotation_cache := {}


static func family(id: StringName) -> Dictionary:
	for f in FAMILIES:
		if f.id == id:
			return f
	push_error("Unknown shape family %s" % id)
	return {}


## Translated names for display (the catalogs keep the English source).
static func family_name(id: StringName) -> String:
	return BMLoc.t(String(family(id).get("name", id)))


static func color_name(color: int) -> String:
	return BMLoc.t(COLOR_NAMES[clampi(color, 0, COLOR_NAMES.size() - 1)])


static func normalize(cells: Array[Vector2i]) -> Array[Vector2i]:
	var min_x := 1 << 30
	var min_y := 1 << 30
	for c in cells:
		min_x = mini(min_x, c.x)
		min_y = mini(min_y, c.y)
	var out: Array[Vector2i] = []
	for c in cells:
		out.append(Vector2i(c.x - min_x, c.y - min_y))
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


## Distinct orientations of a family, in a fixed order (base, then successive 90° clockwise turns).
static func rotations(id: StringName) -> Array:
	if _rotation_cache.has(id):
		return _rotation_cache[id]
	var base: Array[Vector2i] = []
	for pair in family(id).cells:
		base.append(Vector2i(pair[0], pair[1]))
	var out: Array = []
	var keys := {}
	var current := normalize(base)
	for i in 4:
		var key := str(current)
		if not keys.has(key):
			keys[key] = true
			out.append(current)
		var turned: Array[Vector2i] = []
		for c in current:
			turned.append(Vector2i(-c.y, c.x))
		current = normalize(turned)
	_rotation_cache[id] = out
	return out


static func make_shape(id: StringName, rot: int, color: int) -> Dictionary:
	var rots := rotations(id)
	var cells: Array[Vector2i] = []
	cells.assign(rots[rot % rots.size()])
	return {"family": id, "rot": rot % rots.size(), "cells": cells, "color": color}


static func shape_size(shape: Dictionary) -> Vector2i:
	var s := Vector2i.ZERO
	for c: Vector2i in shape.cells:
		s.x = maxi(s.x, c.x + 1)
		s.y = maxi(s.y, c.y + 1)
	return s
