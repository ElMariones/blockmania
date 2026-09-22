class_name BMBagView
extends VBoxContainer
## Shows the player's bag. View mode (round): pieces grouped into Draw pile / In tray /
## Discard pile, sorted by family so the draw order is never revealed. View mode (shop) and
## select mode: the whole bag, with tiles selectable up to `select_max` for Workshop cards.
## Also lists Schematic family levels.

signal selection_changed(uids: Array)

var run: BMRun
var select_max := 0
var selected: Array = []
var _tiles: Array[BMPieceTile] = []


func setup(new_run: BMRun, max_select: int = 0) -> void:
	run = new_run
	select_max = max_select
	selected = []
	add_theme_constant_override("separation", 10)
	_build()


func _build() -> void:
	BMUI.clear_children(self)
	_tiles.clear()
	var in_round := run.phase == BMRun.Phase.ROUND and select_max == 0
	var header := "YOUR BAG  %d pieces   (min %d, max %d)" % [run.bag.size(), BMPieces.MIN_BAG, BMPieces.MAX_BAG]
	add_child(BMUI.label(header, 20, BMPalette.CYAN))
	var levels := PackedStringArray()
	var keys := run.family_levels.keys()
	keys.sort()
	for k in keys:
		levels.append("%s Lv %d" % [BMShapes.family(StringName(k)).name, int(run.family_levels[k])])
	if not levels.is_empty():
		add_child(BMUI.label("Schematics: " + ", ".join(levels), 16, BMPalette.BRASS))
	if in_round:
		var tray_pieces: Array = []
		for p in run.tray:
			if not p.is_empty():
				tray_pieces.append(p)
		_section("DRAW PILE  %d  (order hidden)" % run.draw_pile.size(), _pieces_for(run.draw_pile))
		_section("IN TRAY  %d" % tray_pieces.size(), tray_pieces)
		_section("DISCARD PILE  %d  (shuffled back in when the draw pile runs out)" % run.discard_pile.size(), _pieces_for(run.discard_pile))
	else:
		_section("", run.bag)


func _pieces_for(uids: Array) -> Array:
	var out: Array = []
	for u in uids:
		var p := BMBag.piece_by_uid(run, int(u))
		if not p.is_empty():
			out.append(p)
	return out


func _section(title: String, pieces: Array) -> void:
	if title != "":
		add_child(BMUI.label(title, 16, BMPalette.TEXT_DIM))
	var sorted := pieces.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return BMPieces.sort_key(a) < BMPieces.sort_key(b))
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	for p in sorted:
		var t := BMPieceTile.new(p)
		t.selectable = select_max > 0
		t.toggled_piece.connect(_on_toggle)
		grid.add_child(t)
		_tiles.append(t)
	if sorted.is_empty():
		grid.add_child(BMUI.label("(empty)", 15, BMPalette.TEXT_DIM))


func _on_toggle(uid: int) -> void:
	if selected.has(uid):
		selected.erase(uid)
	elif selected.size() < select_max:
		selected.append(uid)
	elif select_max == 1:
		selected = [uid]
	for t in _tiles:
		t.selected = selected.has(int(t.piece.uid))
		t.queue_redraw()
	selection_changed.emit(selected.duplicate())
