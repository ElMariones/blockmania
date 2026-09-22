class_name BMTitleScreen
extends Control
## Title: the BLOCKMANIA logo built from toy blocks that drop in letter by letter and bob,
## drifting pieces behind the menu, and arcade buttons (Continue, New Run with seed, Quit).

const STAGE := Vector2(1920, 1080)
## Chunky block letters for the logo (original, two-block strokes).
const LETTERS := {
	"B": ["#####.", "##..##", "##..##", "#####.", "##..##", "##..##", "#####."],
	"L": ["##....", "##....", "##....", "##....", "##....", "##....", "######"],
	"O": [".####.", "##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
	"C": [".#####", "##....", "##....", "##....", "##....", "##....", ".#####"],
	"K": ["##..##", "##.##.", "####..", "###...", "####..", "##.##.", "##..##"],
	"M": ["##...##", "###.###", "#######", "##.#.##", "##...##", "##...##", "##...##"],
	"A": [".####.", "##..##", "##..##", "######", "##..##", "##..##", "##..##"],
	"N": ["##..##", "###.##", "######", "##.###", "##..##", "##..##", "##..##"],
	"I": ["######", "..##..", "..##..", "..##..", "..##..", "..##..", "######"],
}
const WORD := "BLOCKMANIA"
const CELL := 22.0

var main: Node
var stage: Control
var _logo: Control
var _drift: Control
var _seed_edit: LineEdit
var _continue: Button
var _new: Button
var _t := 0.0
var _intro_t := 0.0
var _drifters: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage = Control.new()
	stage.size = STAGE
	add_child(stage)
	resized.connect(func() -> void: stage.position = ((size - STAGE) / 2.0).round())

	_drift = Control.new()
	_drift.size = STAGE
	_drift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drift.draw.connect(_draw_drift)
	stage.add_child(_drift)

	_logo = Control.new()
	_logo.position = Vector2(0, 120)
	_logo.size = Vector2(STAGE.x, 260)
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.draw.connect(_draw_logo)
	stage.add_child(_logo)

	var tag := BMStyle.label("a toy-block roguelike of tricks, jokers and one very full board", 30, BMStyle.CREAM, true, 10)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.position = Vector2(0, 372)
	tag.size = Vector2(STAGE.x, 40)
	stage.add_child(tag)

	var menu := BMStyle.vbox(16)
	menu.position = Vector2((STAGE.x - 520) / 2.0, 464)
	menu.size = Vector2(520, 420)
	stage.add_child(menu)
	_continue = BMStyle.button("CONTINUE RUN", func() -> void: main.continue_run(), "mint", 40)
	_continue.custom_minimum_size.y = 92
	menu.add_child(_continue)
	_new = BMStyle.button("NEW RUN", _new_run, "sun", 40)
	_new.custom_minimum_size.y = 92
	menu.add_child(_new)
	var seed_row := BMStyle.hbox(10)
	menu.add_child(seed_row)
	seed_row.add_child(BMStyle.label("SEED", 30, BMStyle.TEXT_DIM, true, 8))
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "random"
	_seed_edit.custom_minimum_size = Vector2(0, 60)
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_edit.text_submitted.connect(func(_s: String) -> void: _new_run())
	seed_row.add_child(_seed_edit)
	var low := BMStyle.hbox(16)
	menu.add_child(low)
	var options := BMStyle.button("OPTIONS", func() -> void: main.show_options(), "sky", 30)
	options.icon = BMStyle.tex("icon_gear")
	options.alignment = HORIZONTAL_ALIGNMENT_CENTER
	options.add_theme_constant_override("icon_max_width", 32)
	options.custom_minimum_size.y = 72
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	low.add_child(options)
	var quit := BMStyle.button("QUIT", func() -> void: get_tree().quit(), "plum", 30)
	quit.custom_minimum_size.y = 72
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	low.add_child(quit)

	var foot := BMStyle.label("prototype build", 20, BMStyle.TEXT_DIM, false, 6)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.position = Vector2(0, 1020)
	foot.size = Vector2(STAGE.x, 30)
	stage.add_child(foot)
	_seed_drifters()


func refresh() -> void:
	stage.position = ((size - STAGE) / 2.0).round()
	_continue.visible = BMSaveStore.has_run()
	_intro_t = 0.0
	focus_default()


func focus_default() -> void:
	BMStyle.focus_later((_continue if _continue.visible else _new))


func _new_run() -> void:
	var text := _seed_edit.text.strip_edges()
	var seed_value := BMRun.random_seed()
	if text != "":
		seed_value = int(text) if text.is_valid_int() else absi(text.hash())
	main.start_new_run(seed_value)


func _seed_drifters() -> void:
	var fams := [&"l4", &"t4", &"bar3", &"square2", &"zigzag4", &"plus5", &"l3", &"bar4"]
	for i in 14:
		_drifters.append({"shape": BMShapes.make_shape(fams[i % fams.size()], i % 4, i % 6),
			"pos": Vector2(randf_range(0, STAGE.x), randf_range(-200, STAGE.y)),
			"speed": randf_range(18, 46), "cell": randf_range(18, 34), "alpha": randf_range(0.10, 0.22)})


func _process(delta: float) -> void:
	var rm: bool = main != null and main.settings.reduced_motion
	_t += delta if not rm else 0.0
	_intro_t += delta
	if not rm:
		for d in _drifters:
			d.pos.y += d.speed * delta
			if d.pos.y > STAGE.y + 120:
				d.pos = Vector2(randf_range(0, STAGE.x), -160)
	_logo.queue_redraw()
	_drift.queue_redraw()


func _draw_drift() -> void:
	for d in _drifters:
		BMBlockPainter.draw_shape(_drift, d.shape, d.pos.round(), d.cell, d.alpha)


func _draw_logo() -> void:
	var rm: bool = main != null and main.settings.reduced_motion
	var widths: Array = []
	var total := 0.0
	for ch in WORD:
		var w: int = LETTERS[ch][0].length()
		widths.append(w)
		total += (w + 1) * CELL
	total -= CELL
	var x := (STAGE.x - total) / 2.0
	var shine := fmod(_t * 0.35, 1.6) - 0.3
	for li in WORD.length():
		var ch := WORD[li]
		var rows: Array = LETTERS[ch]
		var color := li % BMShapes.OFFER_COLOR_COUNT
		var appear := clampf((_intro_t - li * 0.07) / 0.45, 0.0, 1.0)
		var bounce := 0.0
		if appear < 1.0 and not rm:
			bounce = -(1.0 - appear) * 220.0 + sin(appear * PI) * 30.0
		var bob := 0.0 if rm else sin(_t * 2.0 + li * 0.55) * 6.0
		var ox := x
		var oy := 20.0 + bounce + bob
		for ry in rows.size():
			var row: String = rows[ry]
			for rx in row.length():
				if row[rx] != "#":
					continue
				var r := Rect2(Vector2(ox + rx * CELL, oy + ry * CELL).round(), Vector2(CELL, CELL))
				# Chunky ink shadow under the letters.
				_logo.draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(BMStyle.INK, 0.55 * appear))
				BMBlockPainter.draw_block(_logo, r, color, appear)
				var k := (r.position.x / STAGE.x) - shine
				if absf(k) < 0.05 and not rm:
					_logo.draw_rect(r.grow(-4), Color(1, 1, 1, 0.55 * (1.0 - absf(k) / 0.05)))
		x += (widths[li] + 1) * CELL
