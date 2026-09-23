class_name BMPieces
extends RefCounted
## The Bag's pieces (GDD §16). A piece is a concrete, persistent tray offer:
##   {uid, family, rot, color, material, stamp, cells}
## `uid` is unique within a run (-1 = not in the bag: temporary pieces, shop offers, test pieces).
## Temporary pieces also carry `temporary: true`.
## `cells` is derived from family + rot and is never saved.
## Material and stamp IDs are save-facing: never rename casually. Values are provisional.

const MIN_BAG := 12
const MAX_BAG := 60

## Index 0 is "no material"; board cells store the index (BMBoard.mats).
const MATERIALS := ["", "chrome", "neon", "gold", "glass", "prism"]
const MATERIAL_DEFS := {
	"chrome": {"name": "Chrome", "short": "CHR", "brief": "+20 Chips per cell", "text": "Each cell scores +20 Chips when placed."},
	"neon": {"name": "Neon", "short": "NEO", "brief": "+0.5 Mult per cell cleared", "text": "Each Neon cell cleared gives +0.5 Mult to that placement."},
	"gold": {"name": "Gold", "short": "GLD", "brief": "+1 Credit per cell cleared", "text": "Each Gold cell cleared gives +1 Credit."},
	"glass": {"name": "Glass", "short": "GLS", "brief": "x1.5 Mult on clear, may shatter", "text": "x1.5 Mult when a placement clears any Glass cell. A Glass piece with a cleared cell has a 1 in 4 chance to shatter and leave your bag."},
	"prism": {"name": "Prism", "short": "PRM", "brief": "counts as every color", "text": "Counts as every color for Joker effects."},
}
const CHROME_CHIPS_PER_CELL := 20
const NEON_MULT_PER_CELL := 0.5
const GOLD_CREDITS_PER_CELL := 1
const GLASS_X_MULT := 1.5
const GLASS_SHATTER_ONE_IN := 4

const STAMP_DEFS := {
	"encore": {"name": "Encore Stamp", "short": "E", "brief": "x2 Mult on clear", "text": "If this piece clears a line, x2 Mult."},
	"refund": {"name": "Refund Stamp", "short": "R", "brief": "placing it is free", "text": "Placing this piece does not use up a placement."},
	"tip": {"name": "Tip Stamp", "short": "T", "brief": "+2 Credits when placed", "text": "+2 Credits whenever this piece is placed."},
	"memory": {"name": "Memory Stamp", "short": "M", "brief": "Spark when placed", "text": "Whenever this piece is placed, gain a Spark item (needs a free item slot)."},
}
const TIP_CREDITS := 2
const ENCORE_X_MULT := 2.0

## Shape-family levels bought with Schematics.
const LEVEL_CHIPS := 25
const LEVEL_MULT := 0.25

## Starter bag for every Kit: 24 pieces covering 10 families (no Bar 5 / Square 3x3, which
## players add through the Workshop). [family, rot, color]
const STARTER_BAG := [
	["single", 0, 0], ["single", 0, 3],
	["bar2", 0, 1], ["bar2", 0, 4], ["bar2", 1, 5],
	["bar3", 0, 2], ["bar3", 0, 0], ["bar3", 1, 3], ["bar3", 1, 5],
	["l3", 0, 1], ["l3", 1, 2], ["l3", 2, 4], ["l3", 3, 0],
	["square2", 0, 5], ["square2", 0, 1],
	["bar4", 0, 3], ["bar4", 1, 2],
	["l4", 0, 4], ["l4", 2, 5],
	["t4", 0, 0], ["t4", 2, 1],
	["zigzag4", 0, 2], ["zigzag4", 1, 3],
	["plus5", 0, 4],
]


static func make(uid: int, family: StringName, rot: int, color: int, material: String = "", stamp: String = "") -> Dictionary:
	var p := BMShapes.make_shape(family, rot, color)
	p.uid = uid
	p.material = material
	p.stamp = stamp
	return p


static func starter_bag() -> Array:
	var out: Array = []
	for i in STARTER_BAG.size():
		var e: Array = STARTER_BAG[i]
		out.append(make(i, StringName(e[0]), int(e[1]), int(e[2])))
	return out


static func to_dict(p: Dictionary) -> Dictionary:
	if p.is_empty():
		return {}
	var d := {"uid": int(p.uid), "family": String(p.family), "rot": int(p.rot), "color": int(p.color),
		"material": String(p.get("material", "")), "stamp": String(p.get("stamp", ""))}
	if bool(p.get("temporary", false)):
		d.temporary = true
	if String(p.get("hand", "")) != "":
		d.hand = String(p.hand)
	return d


static func from_dict(d: Dictionary) -> Dictionary:
	if d.is_empty():
		return {}
	var p := make(int(d.uid), StringName(d.family), int(d.rot), int(d.color), String(d.get("material", "")), String(d.get("stamp", "")))
	if bool(d.get("temporary", false)):
		p.temporary = true
	if String(d.get("hand", "")) != "":
		p.hand = String(d.hand)
	return p


## A temporary Single dealt by the legality guarantee or Tiny Insurance. Never enters the bag.
static func temporary_single(color: int) -> Dictionary:
	var p := make(-1, &"single", 0, color)
	p.temporary = true
	return p


static func material_index(material: String) -> int:
	return maxi(0, MATERIALS.find(material))


static func is_upgraded(p: Dictionary) -> bool:
	return String(p.get("material", "")) != "" or String(p.get("stamp", "")) != ""


static func family_name(family: StringName) -> String:
	return BMShapes.family(family).name


## One-line description for tooltips and the bag view.
static func describe(p: Dictionary) -> String:
	var parts := PackedStringArray()
	parts.append("%s %s" % [BMShapes.COLOR_NAMES[int(p.color)], family_name(p.family)])
	var m := String(p.get("material", ""))
	if m != "":
		parts.append("%s: %s" % [MATERIAL_DEFS[m].name, MATERIAL_DEFS[m].text])
	var s := String(p.get("stamp", ""))
	if s != "":
		parts.append("%s: %s" % [STAMP_DEFS[s].name, STAMP_DEFS[s].text])
	if bool(p.get("temporary", false)):
		parts.append("Temporary: dealt because no piece in your bag fit the board. It does not stay in your bag.")
	return "\n".join(parts)


## Compact effect summary (one "Name: effect" line per upgrade).
static func brief(p: Dictionary) -> String:
	var parts := PackedStringArray()
	var m := String(p.get("material", ""))
	if m != "":
		parts.append("%s: %s" % [MATERIAL_DEFS[m].name, MATERIAL_DEFS[m].brief])
	var s := String(p.get("stamp", ""))
	if s != "":
		parts.append("%s: %s" % [STAMP_DEFS[s].name.replace(" Stamp", ""), STAMP_DEFS[s].brief])
	return "\n".join(parts) if not parts.is_empty() else "No upgrades."


static func sort_key(p: Dictionary) -> String:
	var fam_index := 0
	for i in BMShapes.FAMILIES.size():
		if BMShapes.FAMILIES[i].id == p.family:
			fam_index = i
	return "%02d_%d_%d_%06d" % [fam_index, int(p.rot), int(p.color), int(p.uid)]
