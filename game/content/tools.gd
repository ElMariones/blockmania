class_name BMTools
extends RefCounted
## Workshop cards (GDD §16.4): one-time bag edits bought in the shop and applied immediately
## to pieces chosen from the bag. `max_targets` 0 = no piece target (Schematic).
## `kind`: material | stamp | copy | remove | rotate | repaint | schematic | slot. Values provisional.

const CATALOG := [ # i18n: name, text
	{"id": "chrome_plating", "name": "Chrome Plating", "cost": 3, "kind": "material", "value": "chrome", "max_targets": 2, "text": "Give up to 2 pieces the Chrome material."},
	{"id": "neon_tubing", "name": "Neon Tubing", "cost": 3, "kind": "material", "value": "neon", "max_targets": 2, "text": "Give up to 2 pieces the Neon material."},
	{"id": "gold_leaf", "name": "Gold Leaf", "cost": 4, "kind": "material", "value": "gold", "max_targets": 1, "text": "Give 1 piece the Gold material."},
	{"id": "glassworks", "name": "Glassworks", "cost": 3, "kind": "material", "value": "glass", "max_targets": 2, "text": "Give up to 2 pieces the Glass material."},
	{"id": "prism_coat", "name": "Prism Coat", "cost": 3, "kind": "material", "value": "prism", "max_targets": 2, "text": "Give up to 2 pieces the Prism material."},
	{"id": "encore_stamp", "name": "Encore Stamp", "cost": 4, "kind": "stamp", "value": "encore", "max_targets": 2, "text": "Stamp up to 2 pieces with Encore."},
	{"id": "refund_stamp", "name": "Refund Stamp", "cost": 4, "kind": "stamp", "value": "refund", "max_targets": 2, "text": "Stamp up to 2 pieces with Refund."},
	{"id": "tip_stamp", "name": "Tip Stamp", "cost": 3, "kind": "stamp", "value": "tip", "max_targets": 2, "text": "Stamp up to 2 pieces with Tip."},
	{"id": "memory_stamp", "name": "Memory Stamp", "cost": 3, "kind": "stamp", "value": "memory", "max_targets": 2, "text": "Stamp up to 2 pieces with Memory."},
	{"id": "copier", "name": "Copier", "cost": 4, "kind": "copy", "max_targets": 1, "text": "Add an exact copy of 1 piece (with its material and stamp) to your bag."},
	{"id": "shredder", "name": "Shredder", "cost": 2, "kind": "remove", "max_targets": 2, "text": "Remove up to 2 pieces from your bag (the bag keeps at least 12)."},
	{"id": "turntable", "name": "Turntable", "cost": 2, "kind": "rotate", "max_targets": 2, "text": "Rotate up to 2 pieces 90 degrees clockwise."},
	{"id": "repaint", "name": "Repaint", "cost": 2, "kind": "repaint", "max_targets": 3, "text": "Repaint up to 3 pieces to a color of your choice."},
	{"id": "schematic", "name": "Schematic", "cost": 3, "kind": "schematic", "max_targets": 0, "text": "Level up a shape family: its pieces gain +25 Chips and +0.25 Mult per level when placed."},
	{"id": "rack_extender", "name": "Rack Extender", "cost": 9, "kind": "slot", "max_targets": 0, "text": "+1 Joker slot for the rest of the run (up to 7)."},
]

## Shop draw weights (schematic appears often enough to matter; bag surgery is common).
const WEIGHTS := {
	"chrome_plating": 8, "neon_tubing": 7, "gold_leaf": 4, "glassworks": 5, "prism_coat": 4,
	"encore_stamp": 4, "refund_stamp": 4, "tip_stamp": 5, "memory_stamp": 4,
	"copier": 6, "shredder": 7, "turntable": 5, "repaint": 5, "schematic": 12, "rack_extender": 3,
}

static var _by_id := {}


static func get_def(id: String) -> Dictionary:
	if _by_id.is_empty():
		for d in CATALOG:
			_by_id[d.id] = d
	return _by_id.get(id, {})


## A shop offer is {"id": tool id, "family": StringName (schematics only)}.
static func offer_name(offer: Dictionary) -> String:
	var def := get_def(offer.id)
	if def.kind == "schematic":
		return BMLoc.t("Schematic: %s") % BMShapes.family_name(offer.family)
	return BMLoc.t(def.name)


static func offer_text(offer: Dictionary, run: BMRun = null) -> String:
	var def := get_def(offer.id)
	if def.kind == "schematic":
		var lvl := 0 if run == null else run.family_level(offer.family)
		return BMLoc.t("Level up %s pieces (now Lv %d): +%d Chips and +%s Mult per level when placed.") % [
			BMShapes.family_name(offer.family), lvl, BMPieces.LEVEL_CHIPS, str(BMPieces.LEVEL_MULT)]
	var text := BMLoc.t(def.text)
	if def.kind == "material":
		text += "\n" + BMLoc.t(BMPieces.MATERIAL_DEFS[def.value].text)
	elif def.kind == "stamp":
		text += "\n" + BMLoc.t(BMPieces.STAMP_DEFS[def.value].text)
	return text
