class_name BMTutorial
extends Control
## The first-session tutorial (GDD §23). POPS, the arcade's old caretaker bot, pops up in a
## corner of the screen, talks in toy gibberish while his lines type in, points at the part
## of the screen he is talking about (a pose, a bouncing glove and a spotlight), and waits for
## NEXT or for the player to do the thing. SKIP ends it for good; Options > Game > REPLAY
## TUTORIAL brings it back.
##
## Presentation only: it reads the run to decide when to move on and never changes it. Only
## the dialog box takes the mouse; the spotlight, POPS and the glove let every click through.
## Starts on round 1 of a campaign run while settings.tutorial_done is false.

const STAGE := Vector2(1920, 1080)
const ART := 4 ## POPS and the glove are drawn at 4x their art pixels
const FRAME := Vector2(56, 62)
const DIALOG_W := 520.0 ## narrow enough for the side columns, clear of the board
const MARGIN := 30.0 ## clear of the CRT filter's curved corners
const CPS := 42.0 ## typewriter speed, characters per second
const CORNERS := ["br", "bl", "tr", "tl"]

var main: Node
var stage: Control
var active := false
var step_id := ""
var voice_count := 0
var letters_spoken := 0

var _index := -1
var _tex: Texture2D
var _ptr_tex: Texture2D
var _pops: Control
var _dim: Control
var _glove: Control
var _dialog: PanelContainer
var _name: Control
var _text: Label
var _next: Button
var _skip: Button
var _wait_hint: Label
var _dots: Label
var _corner := "br"
var _t := 0.0
var _chars := 0.0
var _talking := false
var _blink_t := 2.0
var _base := {} ## step-start snapshot for "placed" / "cleared"
var _target := Rect2()
var _flip := false
var _move: Tween
var _typed_for := 0.0 ## seconds since the current line finished typing
var _mini := false ## POPS ducked down to a peek (minimize steps)
var _mini_k := 0.0 ## 0 = full, 1 = peeking (animated)
var _peek: PanelContainer ## the one-line reminder above the peeking POPS
var _peek_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex = load("res://assets/ui/helper.png")
	_ptr_tex = load("res://assets/ui/helper_pointer.png")
	stage = Control.new()
	stage.size = STAGE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	resized.connect(func() -> void: stage.position = ((size - STAGE) / 2.0).round())
	stage.position = ((size - STAGE) / 2.0).round()
	_dim = Control.new()
	_dim.size = STAGE
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.draw.connect(_draw_dim)
	stage.add_child(_dim)
	_pops = Control.new()
	_pops.size = FRAME * ART
	_pops.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pops.draw.connect(_draw_pops)
	stage.add_child(_pops)
	_glove = Control.new()
	_glove.size = Vector2(80, 80)
	_glove.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glove.draw.connect(_draw_glove)
	stage.add_child(_glove)
	_build_dialog()
	# The glove is drawn above the dialog, so the dialog can never hide it.
	stage.move_child(_glove, stage.get_child_count() - 1)
	_peek = BMStyle.panel("panel_sun", Vector4(14, 4, 14, 6))
	_peek.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_peek_label = BMStyle.label("", 20, BMStyle.INK, true, 0)
	_peek.add_child(_peek_label)
	stage.add_child(_peek)
	_peek.visible = false
	visible = false


func _build_dialog() -> void:
	_dialog = BMStyle.panel("panel_plate", Vector4(12, 16, 12, 18))
	_dialog.custom_minimum_size.x = DIALOG_W
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(_dialog)
	var v := BMStyle.vbox(8)
	_dialog.add_child(v)
	var head := BMStyle.hbox(10)
	v.add_child(head)
	head.add_child(BMStyle.pill("POPS", "sun", 20))
	_dots = BMStyle.label("", 20, BMStyle.TEXT_DIM, true, 4)
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_dots)
	_text = BMStyle.label("", 30, BMStyle.CREAM, false, 0)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The bubble is DIALOG_W wide in total: the text gets what the frame leaves.
	_text.custom_minimum_size = Vector2(DIALOG_W - _dialog.get_theme_stylebox("panel").get_minimum_size().x, 120)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_text)
	var row := BMStyle.hbox(10)
	v.add_child(row)
	_skip = BMStyle.button(BMLoc.t("SKIP TUTORIAL"), skip, "plum", 20)
	_skip.name = "SkipTutorial"
	_skip.custom_minimum_size = Vector2(210, 52)
	_skip.focus_mode = Control.FOCUS_NONE
	row.add_child(_skip)
	_wait_hint = BMStyle.label("", 20, BMStyle.MINT_L, true, 4)
	_wait_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wait_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_wait_hint)
	_next = BMStyle.button(BMLoc.t("NEXT  >"), press_next, "sun", 30)
	_next.name = "NextTutorial"
	_next.custom_minimum_size = Vector2(190, 60)
	_next.focus_mode = Control.FOCUS_NONE
	row.add_child(_next)


# --- Public API (the game and the E2E scenario use these) ------------------------------------

func has_skip() -> bool:
	return active and _skip.visible


func can_next() -> bool:
	return active and _index >= 0 and String(_step().advance) == "next"


## POPS is off stage while a step waits for the game (after "see you in the shop", and after
## the NEXT ROUND hint), so he never covers the board, the shop or its cards.
func away() -> bool:
	return active and _index >= 0 and bool(_step().get("hidden", false))


## POPS has ducked down to a peek while the player works on a multi-turn task.
func minimized() -> bool:
	return active and _mini


func typing() -> bool:
	return active and _chars < _text.text.length()


func press_next() -> void:
	if not active:
		return
	if typing():
		# First press finishes the line; the next press moves on.
		_chars = _text.text.length()
		_text.visible_characters = -1
		return
	if not can_next():
		return
	BMAudio.sfx("pops_next")
	_go(_index + 1)


func skip() -> void:
	if not active:
		return
	_finish(false)


## Clears the saved flag so the next round 1 starts the tour again (Options > REPLAY TUTORIAL).
func reset() -> void:
	active = false
	_index = -1
	step_id = ""
	visible = false
	main.settings["tutorial_done"] = false
	BMSaveStore.save_settings(main.settings)


func helper_rect() -> Rect2:
	return Rect2(_pops.position, _pops.size)


func dialog_rect() -> Rect2:
	return Rect2(_dialog.position, _dialog.size)


func target_rect() -> Rect2:
	return _target


func target_on_screen() -> bool:
	if _target.size == Vector2.ZERO:
		return true
	return Rect2(Vector2.ZERO, STAGE).encloses(_target.grow(-2)) and _screen_for(String(_step().screen)).visible


## Only the dialog box takes the mouse; everything else lets clicks through to the game.
func blocks_only_dialog() -> bool:
	return mouse_filter == Control.MOUSE_FILTER_IGNORE and stage.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and _dim.mouse_filter == Control.MOUSE_FILTER_IGNORE and _pops.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and _glove.mouse_filter == Control.MOUSE_FILTER_IGNORE and _dialog.mouse_filter == Control.MOUSE_FILTER_STOP


# --- Flow ------------------------------------------------------------------------------------

func _step() -> Dictionary:
	return BMTutorialSteps.STEPS[clampi(_index, 0, BMTutorialSteps.STEPS.size() - 1)]


func _process(delta: float) -> void:
	var rm: bool = main != null and bool(main.settings.get("reduced_motion", false))
	_t += delta
	if not active:
		_maybe_start()
		if not active:
			visible = false
			return
	var run: BMRun = main.run
	if run == null or run.phase in [BMRun.Phase.RUN_LOST, BMRun.Phase.ABANDONED, BMRun.Phase.RUN_WON]:
		# The run ended mid-tour: stop quietly; the next first round starts it again.
		active = false
		visible = false
		return
	_follow_the_game(run)
	var shown := _should_show()
	visible = shown
	if not shown:
		return
	var st := _step()
	# Minimize steps: once the player gets going (a placement) or after a few seconds of reading,
	# POPS ducks down and leaves a one-line reminder.
	if bool(st.get("minimize", false)) and not _mini and not typing():
		if run.round_state.placements_made > int(_base.get("placements", 0)) or _typed_for > 4.0:
			_mini = true
	_mini_k = move_toward(_mini_k, 1.0 if _mini else 0.0, delta * 5.0) if not rm else (1.0 if _mini else 0.0)
	if not typing():
		_typed_for += delta
		# Auto steps move on by themselves a moment after the line is read.
		if float(st.get("auto", 0.0)) > 0.0 and _typed_for >= float(st.auto) and can_next():
			_go(_index + 1)
			return
	# Typewriter with gibberish: one blip for every second letter.
	if _chars < _text.text.length():
		var before := int(_chars)
		_chars = minf(_text.text.length(), _chars + delta * CPS) if not rm else float(_text.text.length())
		_text.visible_characters = int(_chars)
		for i in range(before, int(_chars)):
			_speak(_text.text[i], i)
		_talking = _chars < _text.text.length()
	else:
		_talking = false
	_blink_t -= delta
	if _blink_t < -0.12:
		_blink_t = randf_range(1.8, 3.6)
	_layout(rm)
	_pops.queue_redraw()
	_glove.queue_redraw()
	_dim.queue_redraw()


func _maybe_start() -> void:
	if main == null or bool(main.settings.get("tutorial_done", false)) or main.is_paused():
		return
	var run: BMRun = main.run
	if run == null or not main.game_screen.visible or run.phase != BMRun.Phase.ROUND:
		return
	if run.round_number != 1 or run.round_state.placements_made > 0 or main.game_screen.overlay.get_child_count() > 0:
		return
	active = true
	_corner = "br"
	BMAudio.sfx("pops_hi")
	_go(0)
	# Slide in from below the corner.
	if not bool(main.settings.get("reduced_motion", false)):
		_layout(true)
		var to_p := _pops.position
		var to_d := _dialog.position
		_pops.position.y += 300
		_dialog.position.y += 300
		_move = create_tween().set_parallel()
		_move.tween_property(_pops, "position", to_p, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_move.tween_property(_dialog, "position", to_d, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Steps whose moment has passed are skipped: the round ended before the round steps were
## done, or the shop closed before its steps were.
func _follow_the_game(run: BMRun) -> void:
	var st := _step()
	var adv := String(st.advance)
	match adv:
		"placed":
			if run.round_state.placements_made > int(_base.get("placements", 0)):
				_go(_index + 1)
				return
		"cleared":
			if int(run.stats.get("lines_cleared", 0)) > int(_base.get("lines", 0)) \
					or run.round_state.placements_made >= int(_base.get("placements", 0)) + 5:
				_go(_index + 1)
				return
		"shop":
			if run.phase == BMRun.Phase.SHOP:
				_go(_index + 1)
				return
		"left_shop":
			if run.phase == BMRun.Phase.ROUND:
				_go(_index + 1)
				return
	if st.screen == "round" and run.phase == BMRun.Phase.SHOP:
		var first_shop := BMTutorialSteps.first_on("shop", _index)
		if first_shop >= 0:
			_go(first_shop)
	elif st.screen == "shop" and run.phase == BMRun.Phase.ROUND and adv != "left_shop":
		_go(BMTutorialSteps.index_of("bye"))


func _should_show() -> bool:
	if main.is_paused() or away():
		return false
	var screen := _screen_for(String(_step().screen))
	if not screen.visible:
		return false
	if screen == main.game_screen:
		return main.game_screen.overlay.get_child_count() == 0
	return main.shop_screen._overlay.get_child_count() == 0


func _screen_for(name: String) -> Control:
	return main.shop_screen if name == "shop" else main.game_screen


func _go(i: int) -> void:
	if i >= BMTutorialSteps.STEPS.size():
		_finish(true)
		return
	_index = i
	var st := _step()
	step_id = String(st.id)
	var run: BMRun = main.run
	_base = {"placements": run.round_state.placements_made if run else 0, "lines": int(run.stats.get("lines_cleared", 0)) if run else 0}
	_text.text = BMLoc.t(String(st.text))
	_typed_for = 0.0
	_mini = false
	_chars = 0.0
	_text.visible_characters = 0
	_talking = true
	var adv := String(st.advance)
	_next.visible = adv == "next"
	_step_labels(st)
	var shown_steps := BMTutorialSteps.shown_count()
	_dots.text = "%d / %d" % [BMTutorialSteps.shown_index(i) + 1, shown_steps]
	_dialog.reset_size()


## The buttons and hints of a step, in the current language.
func _step_labels(st: Dictionary) -> void:
	var adv := String(st.advance)
	_next.text = BMLoc.t("SHOW ME!") if step_id == "hello" else (BMLoc.t("BYE!") if step_id == "bye" else BMLoc.t("NEXT  >"))
	_wait_hint.text = {"placed": BMLoc.t("Place a piece"), "cleared": BMLoc.t("Clear a line"), "shop": BMLoc.t("Win the round"),
		"left_shop": BMLoc.t("Press NEXT ROUND")}.get(adv, "")
	_peek_label.text = String(_wait_hint.text).to_upper() + "!" if _wait_hint.text != "" else ""
	# The button row is as wide as the text: longer words step the buttons' font down.
	var row_w := _text.custom_minimum_size.x
	BMUI.fit_button(_skip, row_w - 190.0, 20)
	BMUI.fit_button(_next, row_w - 10.0 - maxf(210.0, _skip.get_minimum_size().x), 30)


## The language changed: re-read the visible lines; the tour keeps its place.
func relocalize() -> void:
	if _skip == null:
		return
	_skip.text = BMLoc.t("SKIP TUTORIAL")
	if _index >= 0 and _index < BMTutorialSteps.STEPS.size():
		var st := _step()
		_text.text = BMLoc.t(String(st.text))
		_step_labels(st)
		_dialog.reset_size()


func _finish(completed: bool) -> void:
	active = false
	visible = false
	main.settings["tutorial_done"] = true
	if completed:
		var seen: Array = main.settings.get("tips_seen", [])
		for t in BMTutorialSteps.COVERED_TIPS:
			if not seen.has(t):
				seen.append(t)
		main.settings["tips_seen"] = seen
		BMAudio.sfx("pops_bye")
	BMSaveStore.save_settings(main.settings)


## Toy gibberish: every second letter plays a vowel blip, pitched by the letter so a line
## always sounds the same.
func _speak(ch: String, i: int) -> void:
	var code := ch.to_lower().unicode_at(0)
	if code < 97 or code > 122:
		return
	letters_spoken += 1
	if letters_spoken % 2 == 1:
		return
	var vowel: String = ch.to_lower() if ch.to_lower() in ["a", "e", "i", "o", "u"] else ["a", "e", "i", "o", "u"][code % 5]
	voice_count += 1
	BMAudio.sfx("pops_" + vowel, 0.92 + float((code + i) % 7) * 0.05, -4.0)


# --- Layout ----------------------------------------------------------------------------------

func _layout(rm: bool) -> void:
	var screen := _screen_for(String(_step().screen))
	_target = Rect2()
	var target_id := String(_step().target)
	if target_id != "" and screen.has_method("tutorial_rect"):
		var g: Rect2 = screen.tutorial_rect(target_id)
		if g.size != Vector2.ZERO:
			_target = Rect2(g.position - stage.global_position, g.size)
	# Pick the corner farthest from the target whose POPS + dialog does not cover it.
	var best := _corner
	if _target.size != Vector2.ZERO:
		var order := CORNERS.duplicate()
		var c := _target.get_center()
		order.sort_custom(func(a: String, b: String) -> bool:
			return _corner_point(a).distance_to(c) > _corner_point(b).distance_to(c))
		for k in order:
			var rects := _rects_for(k)
			if not rects[0].intersects(_target) and not rects[1].intersects(_target):
				best = k
				break
	var rects := _rects_for(best)
	if rm and _is_tweening():
		_move.kill() # Reduced Motion: no slides, POPS just appears in place
	var bob := 0.0 if rm else roundf(sin(_t * 2.2) * 3.0)
	var pops_to: Vector2 = rects[0].position + Vector2(0, bob)
	var dialog_to: Vector2 = rects[1].position
	if best != _corner and not rm:
		# Hop to the new corner.
		if _move and _move.is_valid():
			_move.kill()
		_move = create_tween().set_parallel()
		_move.tween_property(_pops, "position", pops_to, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_move.tween_property(_dialog, "position", dialog_to, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	elif best == _corner and not _is_tweening():
		_pops.position = pops_to
		_dialog.position = dialog_to
	_corner = best
	_flip = _target.size != Vector2.ZERO and _target.get_center().x < _pops.position.x + _pops.size.x / 2.0
	# The glove sits just outside the target and bobs toward it. It prefers pointing down from
	# above; if POPS or his dialog would cover it there, it tries his side, below, then the far side.
	_glove.visible = _target.size != Vector2.ZERO
	if _glove.visible:
		var push := 0.0 if rm else absf(sin(_t * 6.0)) * 10.0
		var c := _target.get_center()
		var gs := _glove.size
		var toward := signf(rects[0].get_center().x - c.x)
		if toward == 0.0:
			toward = 1.0
		var candidates := [
			[Vector2(c.x - gs.x / 2.0, _target.position.y - 8.0 - push - gs.y), 1],
			[Vector2(c.x + toward * (_target.size.x / 2.0 + 8.0 + push) - (0.0 if toward > 0 else gs.x), c.y - gs.y / 2.0), 2 if toward > 0 else 0],
			[Vector2(c.x - gs.x / 2.0, _target.end.y + 8.0 + push), 3],
			[Vector2(c.x - toward * (_target.size.x / 2.0 + 8.0 + push) - (gs.x if toward > 0 else 0.0), c.y - gs.y / 2.0), 0 if toward > 0 else 2],
		]
		var pick: Array = candidates[0]
		for cand in candidates:
			var gr := Rect2(cand[0], gs)
			# Judge the spot without the bob, so the glove does not jump sides mid-bounce.
			gr.position -= Vector2(0, -push) if int(cand[1]) == 1 else Vector2.ZERO
			if Rect2(Vector2.ZERO, STAGE).encloses(gr) and not gr.intersects(rects[0]) and not gr.intersects(rects[1]):
				pick = cand
				break
		_glove.position = pick[0]
		_glove.set_meta("dir", int(pick[1]))
	# Minimized: POPS ducks down in his corner with a one-line reminder; no dim, no glove.
	var k := _mini_k
	_dialog.visible = k < 0.99
	_dialog.modulate.a = 1.0 - k
	if k > 0.0:
		_target = Rect2() if k >= 0.99 else _target
		_glove.visible = _glove.visible and k < 0.5
		_pops.position.y = rects[0].position.y + k * _pops.size.y * 0.66 + (0.0 if rm else roundf(sin(_t * 2.2) * 3.0))
	_peek.visible = k >= 0.99 and _peek_label.text != ""
	if _peek.visible:
		_peek.reset_size()
		var px := clampf(rects[0].get_center().x - _peek.size.x / 2.0, MARGIN, STAGE.x - MARGIN - _peek.size.x)
		_peek.position = Vector2(px, _pops.position.y - _peek.size.y - 6.0)


func _is_tweening() -> bool:
	return _move != null and _move.is_valid() and _move.is_running()


func _corner_point(k: String) -> Vector2:
	return Vector2(STAGE.x if k.ends_with("r") else 0.0, STAGE.y if k.begins_with("b") else 0.0)


## [POPS rect, dialog rect] for a corner. POPS hugs the corner and the dialog stacks above
## him (bottom corners) or below him (top corners), like a speech bubble, inside the side
## column so it never covers the board.
func _rects_for(k: String) -> Array:
	var ps := _pops.size
	var ds := Vector2(maxf(_dialog.size.x, DIALOG_W), maxf(_dialog.size.y, 200.0))
	var right := k.ends_with("r")
	var bottom := k.begins_with("b")
	var px := STAGE.x - ps.x - MARGIN if right else MARGIN
	var py := STAGE.y - ps.y - MARGIN if bottom else MARGIN
	var dx := STAGE.x - ds.x - MARGIN if right else MARGIN
	var dy := py - ds.y - 6.0 if bottom else py + ps.y + 6.0
	dy = clampf(dy, MARGIN, STAGE.y - ds.y - MARGIN)
	return [Rect2(px, py, ps.x, ps.y), Rect2(dx, dy, ds.x, ds.y)]


# --- Drawing ---------------------------------------------------------------------------------

func _frame() -> int:
	var st := _step()
	var happy := String(st.get("pose", "")) == "happy"
	var mouth := _talking and int(_t * 10.0) % 2 == 0
	if _target.size != Vector2.ZERO:
		return 5 if mouth else 4
	if happy:
		return 7 if mouth else 6
	if mouth:
		return 2 if int(_t * 20.0) % 3 else 3
	return 1 if _blink_t < 0.0 else 0


func _draw_pops() -> void:
	if _tex == null:
		return
	var f := _frame()
	var src := Rect2(Vector2(f * FRAME.x, 0), FRAME)
	# A soft ink shadow under POPS so he reads on any background.
	_pops.draw_rect(Rect2(Vector2(40, _pops.size.y - 36), Vector2(_pops.size.x - 80, 16)), Color(BMStyle.INK, 0.45))
	if _flip:
		_pops.draw_set_transform(Vector2(_pops.size.x, 0), 0.0, Vector2(-1, 1))
	_pops.draw_texture_rect_region(_tex, Rect2(Vector2.ZERO, _pops.size), src)
	_pops.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_glove() -> void:
	if _ptr_tex == null or not _glove.visible:
		return
	var dir := int(_glove.get_meta("dir", 0))
	_glove.draw_texture_rect_region(_ptr_tex, Rect2(Vector2.ZERO, _glove.size), Rect2(dir * 16, 0, 16, 16))


## Spotlight: the stage is dimmed except for the target, which gets a marching sun outline.
func _draw_dim() -> void:
	if _target.size == Vector2.ZERO:
		return
	var r := _target.grow(10.0)
	var dim := Color(BMStyle.INK, 0.42)
	_dim.draw_rect(Rect2(0, 0, STAGE.x, r.position.y), dim)
	_dim.draw_rect(Rect2(0, r.end.y, STAGE.x, STAGE.y - r.end.y), dim)
	_dim.draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), dim)
	_dim.draw_rect(Rect2(r.end.x, r.position.y, STAGE.x - r.end.x, r.size.y), dim)
	var rm: bool = bool(main.settings.get("reduced_motion", false))
	var off := 0.0 if rm else fmod(_t * 40.0, 24.0)
	for edge in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
			[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		var len := a.distance_to(b)
		var dirv := (b - a) / maxf(1.0, len)
		var s := -off
		while s < len:
			var s0 := maxf(0.0, s)
			var s1 := minf(len, s + 14.0)
			if s1 > s0:
				_dim.draw_line(a + dirv * s0, a + dirv * s1, BMStyle.SUN, 6.0)
			s += 24.0
