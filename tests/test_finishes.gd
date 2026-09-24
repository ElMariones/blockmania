extends BMTestCase
## Block finishes are presentation only, but their art, sounds and catalog must stay in sync:
## a missing sheet or cue would silently draw nothing or log errors mid-run.


func test_every_style_and_material_has_art_and_sound() -> void:
	var ids: Array = BMFinishes.ENDLESS.duplicate()
	for m: String in BMPieces.MATERIALS:
		if m != "" and not ids.has(m):
			ids.append(m)
	for id: String in ids:
		check(BMFinishes.DEFS.has(id), "%s has a catalog entry" % id)
		if id == "classic":
			continue
		check(BMFinishes.has_sheet(id), "%s is drawn from a sheet" % id)
		check(BMFinishes.meta().finishes.has(id), "%s is in finishes.json" % id)
		check(ResourceLoader.exists("res://assets/ui/finish_%s.png" % id), "%s sheet exists" % id)
		for cue in ["place", "clear"]:
			check(ResourceLoader.exists("res://assets/audio/sfx/fin_%s_%s.wav" % [id, cue]), "%s %s cue exists" % [id, cue])


func test_stamps_have_badge_and_cue() -> void:
	for s: String in BMPieces.STAMP_DEFS:
		check(ResourceLoader.exists("res://assets/ui/stamp_%s.png" % s), "%s badge exists" % s)
		check(ResourceLoader.exists("res://assets/audio/sfx/stamp_%s.wav" % s), "%s cue exists" % s)


func test_regions_stay_inside_sheets() -> void:
	for id: String in BMFinishes.meta().finishes:
		var tex: Texture2D = load("res://assets/ui/finish_%s.png" % id)
		var bounds := Rect2(Vector2.ZERO, tex.get_size())
		for color in BMShapes.OFFER_COLOR_COUNT:
			for t in [0.0, 0.37, 1.9, 7.3, 55.0]:
				for cell in [Vector2i.ZERO, Vector2i(7, 7), Vector2i(3, 5)]:
					var r := BMFinishes.region(id, color, cell, t)
					check(bounds.encloses(r), "%s region %s inside %s" % [id, r, bounds])
