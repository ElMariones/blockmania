class_name BMTitleScreen
extends Control
## Title: Continue (when a run save exists), New Run with optional seed, Quit.
## Practice, Collection, Settings, and Kit selection are later milestones (see TASKS.md).

var main: Node
var _seed_edit: LineEdit
var _continue: Button
var _logo: Control
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := BMUI.vbox(18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	_logo = Control.new()
	_logo.custom_minimum_size = Vector2(1100, 200)
	_logo.draw.connect(_draw_logo)
	v.add_child(_logo)
	var sub := BMUI.label("block placement roguelike  -  prototype build", 22, BMPalette.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var box := BMUI.vbox(12)
	box.custom_minimum_size.x = 420
	var holder := CenterContainer.new()
	holder.add_child(box)
	v.add_child(holder)
	_continue = BMUI.button("Continue Run", func() -> void: main.continue_run(), 26)
	box.add_child(_continue)
	box.add_child(BMUI.button("New Run", _new_run, 26))
	var seed_row := BMUI.hbox(8)
	box.add_child(seed_row)
	seed_row.add_child(BMUI.label("Seed", 18, BMPalette.TEXT_DIM))
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "random"
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_edit.text_submitted.connect(func(_t: String) -> void: _new_run())
	seed_row.add_child(_seed_edit)
	box.add_child(BMUI.button("Quit", func() -> void: get_tree().quit(), 22))


func refresh() -> void:
	_continue.visible = BMSaveStore.has_run()
	if _continue.visible:
		_continue.grab_focus.call_deferred()
	else:
		(_continue.get_parent().get_child(1) as Button).grab_focus.call_deferred()


func _new_run() -> void:
	var text := _seed_edit.text.strip_edges()
	var seed_value := BMRun.random_seed()
	if text != "":
		seed_value = int(text) if text.is_valid_int() else absi(text.hash())
	main.start_new_run(seed_value)


func _process(delta: float) -> void:
	if not main.settings.reduced_motion:
		_t += delta
		_logo.queue_redraw()


## Placeholder logotype built from beveled blocks (not final brand art).
func _draw_logo() -> void:
	var word := "BLOCKMANIA"
	var font := get_theme_default_font()
	var cell := 92.0
	var total := cell * word.length()
	var x0 := (_logo.size.x - total) / 2.0
	for i in word.length():
		var bob := sin(_t * 2.2 + i * 0.6) * 6.0
		var r := Rect2(Vector2(x0 + i * cell, 40 + bob), Vector2(cell - 6, cell - 6))
		BMBlockPainter.draw_block(_logo, r, i % BMShapes.OFFER_COLOR_COUNT)
		_logo.draw_string_outline(font, r.position + Vector2(0, cell * 0.68), word[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 56, 10, Color(0, 0, 0, 0.55))
		_logo.draw_string(font, r.position + Vector2(0, cell * 0.68), word[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 56, Color.WHITE)
