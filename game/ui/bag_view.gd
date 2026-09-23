class_name BMBagView
extends VBoxContainer
## Shows the player's bag. View mode (round): pieces grouped into Draw pile / In tray /
## Discard pile, sorted by family so the draw order is never revealed. View mode (shop) and
## select mode: the whole bag, with tiles selectable up to `select_max` for Workshop cards.
## Also lists Schematic family levels.

signal selection_changed(uids: Array)

const COLS := 8
const GAP := 10
const WIDTH := COLS * BMPieceTile.TILE.x + (COLS - 1) * GAP

var run: BMRun
var select_max := 0
var selected: Array = []
var _tiles: Array[BMPieceTile] = []


func setup(new_run: BMRun, max_select: int = 0) -> void:
	run = new_run
	select_max = max_select
	selected = []
	add_theme_constant_override("separation", 12)
	# Exactly COLS tiles wide and centered by the caller, so every section lines up on one grid.
	custom_minimum_size.x = WIDTH
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_build()


func _build() -> void:
	BMUI.clear_children(self)
	_tiles.clear()
	var in_round := run.phase == BMRun.Phase.ROUND and select_max == 0
	var head := BMStyle.hbox(12)
	add_child(head)
	head.add_child(BMStyle.icon_rect("icon_bag", 1.0))
	# Inside the Workshop picker the card title is the main heading; keep the bag header quieter.
	var head_size := 30 if select_max > 0 else 40
	head.add_child(BMStyle.label("YOUR BAG  %d PIECES" % run.bag.size(), head_size, BMStyle.SUN, true, 10))
	var lim := BMStyle.label("min %d  -  max %d" % [BMPieces.MIN_BAG, BMPieces.MAX_BAG], 20, BMStyle.TEXT_DIM, false, 6)
	lim.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(lim)
	var keys := run.family_levels.keys()
	keys.sort()
	if not keys.is_empty():
		var lv := HFlowContainer.new()
		lv.add_theme_constant_override("h_separation", 8)
		lv.add_child(BMStyle.label("SCHEMATICS", 20, BMStyle.TEXT_DIM, true, 6))
		for k in keys:
			lv.add_child(BMStyle.pill("%s LV %d" % [BMShapes.family(StringName(k)).name.to_upper(), int(run.family_levels[k])], "sun", 20))
		add_child(lv)
	if in_round:
		var tray_pieces: Array = []
		for p in run.tray:
			if not p.is_empty():
				tray_pieces.append(p)
		_section("DRAW PILE  %d" % run.draw_pile.size(), "order hidden", "sky", _pieces_for(run.draw_pile))
		_section("IN TRAY  %d" % tray_pieces.size(), "", "sun", tray_pieces)
		_section("DISCARD PILE  %d" % run.discard_pile.size(), "shuffled back in when the draw pile runs out", "plum", _pieces_for(run.discard_pile))
	else:
		_section("", "", "", run.bag)


func _pieces_for(uids: Array) -> Array:
	var out: Array = []
	for u in uids:
		var p := BMBag.piece_by_uid(run, int(u))
		if not p.is_empty():
			out.append(p)
	return out


func _section(title: String, note: String, kind: String, pieces: Array) -> void:
	if title != "":
		var h := BMStyle.hbox(10)
		h.add_child(BMStyle.pill(title, kind, 20))
		if note != "":
			var n := BMStyle.label(note, 20, BMStyle.TEXT_DIM, false, 6)
			h.add_child(n)
		add_child(h)
	var sorted := pieces.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return BMPieces.sort_key(a) < BMPieces.sort_key(b))
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	add_child(grid)
	for p in sorted:
		var t := BMPieceTile.new(p)
		t.selectable = select_max > 0
		t.toggled_piece.connect(_on_toggle)
		grid.add_child(t)
		_tiles.append(t)
	if sorted.is_empty():
		grid.add_child(BMStyle.label("(empty)", 20, BMStyle.TEXT_DIM))


func _on_toggle(uid: int) -> void:
	if selected.has(uid):
		selected.erase(uid)
		BMAudio.sfx("deselect")
	elif selected.size() < select_max:
		selected.append(uid)
		BMAudio.sfx("select")
	elif select_max == 1:
		selected = [uid]
		BMAudio.sfx("select")
	else:
		BMAudio.sfx("deny")
	for t in _tiles:
		t.selected = selected.has(int(t.piece.uid))
		t.queue_redraw()
	selection_changed.emit(selected.duplicate())
