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
	_stats_strip()
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



## Bag statistics and Tray Hand odds (from the whole bag's composition, so draw order stays
## hidden). Odds enumerate every three-piece deal: exact, and cached per bag signature.
func _stats_strip() -> void:
	var upgraded := BMBag.upgraded_count(run)
	var colors := {}
	for p in run.bag:
		colors[int(p.color)] = true
	var st := HFlowContainer.new()
	st.add_theme_constant_override("h_separation", 8)
	st.add_theme_constant_override("v_separation", 6)
	st.add_child(BMStyle.label("BAG", 20, BMStyle.TEXT_DIM, true, 6))
	st.add_child(BMStyle.pill("%d FAMILIES" % BMBag.distinct_families(run), "plum", 20))
	st.add_child(BMStyle.pill("%d COLORS" % colors.size(), "plum", 20))
	st.add_child(BMStyle.pill("%d UPGRADED" % upgraded, "plum", 20))
	add_child(st)
	var odds := _odds()
	var ho := HFlowContainer.new()
	ho.add_theme_constant_override("h_separation", 8)
	ho.add_theme_constant_override("v_separation", 6)
	var hl := BMStyle.label("HAND ODDS PER DEAL", 20, BMStyle.TEXT_DIM, true, 6)
	hl.tooltip_text = "Chance that a fresh three-piece deal forms each Tray Hand, from your whole bag."
	hl.mouse_filter = Control.MOUSE_FILTER_PASS
	ho.add_child(hl)
	var kinds := {BMHands.TWINS: "sky", BMHands.STAIRCASE: "mint", BMHands.MONOCHROME: "pink", BMHands.TRIPLETS: "sun", BMHands.GRAND_SLAM: "plum"}
	for id in [BMHands.TWINS, BMHands.STAIRCASE, BMHands.MONOCHROME, BMHands.TRIPLETS, BMHands.GRAND_SLAM]:
		var pct := 100.0 * float(odds.get(id, 0.0))
		var txt := "%s %s" % [BMHands.get_def(id).badge, ("%.0f%%" % pct) if pct >= 1.0 or pct == 0.0 else "<1%"]
		var pill := BMStyle.pill(txt, kinds[id], 20)
		pill.tooltip_text = BMHands.get_def(id).text
		pill.mouse_filter = Control.MOUSE_FILTER_PASS
		ho.add_child(pill)
	add_child(ho)


static var _odds_cache := {}


func _odds() -> Dictionary:
	var sig := PackedStringArray()
	for p in run.bag:
		sig.append("%s%d%s" % [p.family, int(p.color), p.get("material", "")])
	sig.sort()
	var key := ",".join(sig)
	if not _odds_cache.has(key):
		if _odds_cache.size() > 16:
			_odds_cache.clear()
		_odds_cache[key] = BMHands.odds(run.bag)
	return _odds_cache[key]
