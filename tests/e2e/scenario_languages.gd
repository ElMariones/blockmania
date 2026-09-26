extends BME2ECase
## Every UI language on every screen. One seeded campaign run (and an Endless game) is driven
## through the real entry points; at each stop the language is switched through all eleven
## (Settings > Language, which rebuilds the screens in place) and the same view is reopened.
## For every visible Label, Button and LineEdit it checks:
##   glyph        a character the fonts (Blockhead + the language's CJK subset) cannot draw
##   escapes      text that sticks out of its panel (or the screen)
##   offscreen    a panel or button with text that reaches past the window edge
##   grew         a placed control (fixed rect, not inside a container) whose content's minimum
##                size overrode its rect, so it pushes past where the layout put it
##   cut off      a wrapping label with lines that do not fit its height
##   truncated    text shortened with an ellipsis or clipped, without the full text in a tooltip
##   shortened    the same, with the full text in the control's or card's tooltip: fixed-size
##                cards do this on purpose, so it is counted (facts) but does not fail
##   untranslated English text left on screen although the language has a translation for it
##   split word   a wrapped label that breaks a word in the middle (Latin scripts)
##   drawn        text drawn in code (`BMUI.fit_size`) that does not fit its width even at 20
##   overflow     a fitted button (`BMUI.fit_button`, the title menu) whose text does not fit at 20
## A problem a translation shares with English on the same control is not counted again, and
## English truncation is by design; everything else fails. Screenshots of
## every stop and language go to build/e2e/scenario_languages/ when a display is available.
##
## Failure modes this guards against (written before the checks): a translation longer than
## its fixed-size button or label; a CJK glyph missing from the subset; a language switch that
## leaves a screen half in the old language or breaks it; a string that was never wrapped in
## BMLoc; a rules string shown without BMLoc.tf; a multi-line tooltip body line cut.

const SEED := 4242
const KIT := "standard"

var _langs: Array = []
var _baseline := {}
var _report := {}
var _shortened := {}


func run() -> void:
	for entry in BMLoc.LANGUAGES:
		_langs.append(String(entry[0]))
	main.settings.tips = false
	main.settings.boss_intro = "quick"
	# --- Title and its popups ---------------------------------------------------------------
	await _stop("title", func() -> void: main.title_screen.refresh())
	await _stop("kit_picker", func() -> void: main.title_screen._show_kit_picker("123"))
	await _stop("daily", func() -> void: main.title_screen._show_daily())
	await _stop("high_scores", func() -> void: main.title_screen._show_high_scores())
	for page in BMAchievements.page_count():
		await _stop("trophies_%d" % page, func() -> void:
			main.title_screen._show_trophies()
			await frames(2)
			var tc := main.title_screen._highscore_overlay as BMTrophyCase
			if tc != null and page > 0:
				tc._show_page(page, 1)
				await wait(0.4))
	main.title_screen._close_high_scores()
	for tab in ["game", "audio", "display", "access", "controls"]:
		await _stop("options_" + tab, func() -> void:
			main.close_pause()
			main.show_options()
			await frames(2)
			(main._pause.get_child(0) as BMSettingsMenu).show_tab(tab))
	main.close_pause()
	# --- The tutorial's first line (then it is skipped for the rest) -------------------------
	main.start_new_run(SEED, KIT, 0)
	await frames(3)
	main.game_screen.close_overlay()
	await wait(1.2)
	if main.tutorial != null and main.tutorial.active:
		await _stop("tutorial", func() -> void: await wait(2.5))
		main.tutorial.skip()
	main.settings.tutorial_done = true
	# --- A campaign round ----------------------------------------------------------------------
	await _stop("round_intro", func() -> void:
		main.game_screen.close_overlay()
		main.game_screen._show_round_intro())
	main.game_screen.close_overlay()
	await _bot_until(func(r: BMRun) -> bool: return r.phase == BMRun.Phase.ROUND and r.round_state.placements_made >= 3)
	await _stop("round", func() -> void: main.game_screen.close_overlay())
	await _stop("bag", func() -> void: main.game_screen._show_bag())
	main.game_screen.close_overlay()
	await _stop("pause_run", func() -> void:
		main.close_pause()
		main.show_pause()
		await frames(2)
		var menu := main._pause.get_child(0) as BMSettingsMenu
		menu.show_tab("run")
		var abandon := menu.find_child("Abandon", true, false) as Button
		if abandon != null:
			abandon.pressed.emit() # the first press only asks for a second one
		await frames(1))
	main.close_pause()
	await _bot_until(func(r: BMRun) -> bool: return r.phase == BMRun.Phase.ROUND_RESULT)
	await _stop("round_result", func() -> void:
		main.game_screen.close_overlay()
		main.game_screen._show_round_result())
	await _bot_until(func(r: BMRun) -> bool: return r.phase == BMRun.Phase.SHOP)
	await _stop("shop", func() -> void: pass)
	await _stop("round_picker", func() -> void: main.shop_screen._show_round_picker())
	BMUI.clear_children(main.shop_screen._overlay)
	await _stop("shop_bag", func() -> void: main.shop_screen._show_bag())
	BMUI.clear_children(main.shop_screen._overlay)
	# --- The first boss (round 4), its crate and the shop after it --------------------------
	await _bot_until(func(r: BMRun) -> bool: return r.phase == BMRun.Phase.ROUND and r.round_number == 4)
	await _stop("boss_intro", func() -> void:
		main.game_screen.close_overlay()
		main.game_screen._show_round_intro())
	main.game_screen.close_overlay()
	await _stop("boss_cinematic", func() -> void:
		main.game_screen.close_overlay()
		main.game_screen._play_boss_intro()
		await wait(2.0))
	main.game_screen.close_overlay()
	await _stop("boss_round", func() -> void: main.game_screen.close_overlay())
	await _bot_until(func(r: BMRun) -> bool: return r.phase == BMRun.Phase.SHOP or r.phase == BMRun.Phase.RUN_LOST)
	if main.run.phase == BMRun.Phase.SHOP:
		await _stop("crate", func() -> void: main.shop_screen._show_crate())
		BMUI.clear_children(main.shop_screen._overlay)
	# --- The end of the run and the history --------------------------------------------------
	if main.run.phase != BMRun.Phase.RUN_LOST:
		main.abandon_run()
		await frames(3)
	await _stop("run_end", func() -> void:
		main.game_screen.close_overlay()
		main.game_screen._show_run_end())
	main.show_title()
	await frames(2)
	await _stop("history", func() -> void: main.title_screen._show_history())
	main.title_screen._close_high_scores()
	# --- Endless ------------------------------------------------------------------------------
	main.start_endless()
	await frames(3)
	await _stop("endless", func() -> void: pass)
	await _stop("endless_styles", func() -> void: main.endless_screen._open_style_picker())
	main.endless_screen._close_style_picker()
	await _stop("endless_over", func() -> void: main.endless_screen._show_over())
	main.set_language("en")
	await frames(2)
	facts["problems"] = _report
	facts["shortened_with_tooltip"] = _shortened
	facts["languages"] = _langs


## One stop: for every language, switch, reopen the view with `setup`, check and screenshot.
func _stop(stop: String, setup: Callable) -> void:
	# Pop texts and feat banners from the bot's last moves (made in English) fade out first.
	for i in 80:
		if main.fx.find_children("*", "Control", false, false).is_empty():
			break
		await wait(0.1)
	for code in _langs:
		BMUI.overflows.clear() # before the switch: rebuilt widgets draw right away
		main.set_language(code)
		await frames(2)
		await setup.call()
		await frames(3)
		var found := _inspect()
		for t in BMUI.overflows:
			found.append("drawn '%s' does not fit @draw" % t.left(40))
		BMUI.overflows.clear()
		var real: Array = []
		for k in found:
			if code == "en":
				_baseline[_key(stop, k)] = true
				if String(k).begins_with("truncated") or String(k).begins_with("grew") or String(k).begins_with("shortened"):
					continue # English layout is the reviewed baseline (cards shorten long texts on purpose)
			elif _baseline.has(_key(stop, k)) or String(k).begins_with("shortened"):
				if String(k).begins_with("shortened"):
					_shortened["%s/%s" % [code, stop]] = int(_shortened.get("%s/%s" % [code, stop], 0)) + 1
				continue
			real.append(k)
		if not real.is_empty():
			_report["%s/%s" % [code, stop]] = real
			for k in real:
				check(false, "%s/%s: %s" % [code, stop, k])
		if DisplayServer.get_name() != "headless":
			await wait(0.6) # let overlays finish fading in before the picture
		await screenshot("%s_%s" % [stop, code])


## The same problem on the same control, whatever its text says in this language.
func _key(stop: String, problem: String) -> String:
	if problem.begins_with("drawn"):
		return stop + "|" + problem # no control to match: never excused by English
	return "%s|%s|%s" % [stop, problem.get_slice(" ", 0), problem.get_slice("@", problem.get_slice_count("@") - 1)]


## Plays the bot until `done` holds (or the run ends).
func _bot_until(done: Callable) -> void:
	main.set_language("en")
	await frames(2)
	for i in 600:
		var r: BMRun = main.run
		if done.call(r):
			return
		if r.phase in [BMRun.Phase.RUN_WON, BMRun.Phase.RUN_LOST, BMRun.Phase.ABANDONED]:
			return
		var a := bot_action(r)
		if a.is_empty():
			return
		if r.phase == BMRun.Phase.SHOP:
			if a.a == "leave_shop" and not Array(r.shop.get("round_cards", [])).is_empty():
				main.shop_screen._show_round_picker()
				await frames(1)
				main.shop_screen._pick_round_and_go(0)
			else:
				main.shop_screen._act(a)
		else:
			if main.game_screen.overlay.get_child_count() > 0 and a.a != "continue":
				main.game_screen.close_overlay()
			main.game_screen._do_action(a)
		await frames(1)


# --- Inspection ------------------------------------------------------------------------------

func _english_only() -> Dictionary:
	var out := {}
	var tr := TranslationServer.get_translation_object(BMLoc.current)
	if tr == null or BMLoc.current == "en":
		return out
	for msg in tr.get_message_list():
		var id := String(msg)
		if id.length() >= 4 and BMLoc.t(id) != id and id.strip_edges() != "":
			out[id] = true
	return out


func _inspect() -> Array:
	var out: Array = []
	var english := _english_only()
	_walk(main, "", out, english)
	out.sort()
	return out


func _walk(n: Node, path: String, out: Array, english: Dictionary) -> void:
	for i in n.get_child_count():
		var c := n.get_child(i)
		var p := "%s/%d" % [path, i]
		if c is CanvasItem and not (c as CanvasItem).visible:
			continue
		if c is Control:
			_check_grown(c as Control, p, out)
			_check_control(c as Control, p, out, english)
			_check_on_screen(c as Control, p, out)
		if c is ScrollContainer or c == main.toasts:
			_walk_text_only(c, p, out, english)
			continue
		_walk(c, p, out, english)


## Inside scroll areas (clipped by design) and the sliding toast plates: text checks only.
func _walk_text_only(n: Node, path: String, out: Array, english: Dictionary) -> void:
	for i in n.get_child_count():
		var c := n.get_child(i)
		var p := "%s/%d" % [path, i]
		if c is CanvasItem and not (c as CanvasItem).visible:
			continue
		if c is Control:
			_check_grown(c as Control, p, out)
			_check_control(c as Control, p, out, english)
		_walk_text_only(c, p, out, english)


## A visible panel or button with text must stay inside the window (a bubble that grew past
## the edge, a dialog wider than the screen).
func _check_on_screen(c: Control, path: String, out: Array) -> void:
	if not (c is PanelContainer or c is Button) or not c.is_visible_in_tree() or c.modulate.a < 0.05:
		return
	var text := _first_text(c)
	if text.strip_edges() == "":
		return
	if not Rect2(Vector2.ZERO, main.size).grow(4).encloses(c.get_global_rect()):
		var r := c.get_global_rect()
		out.append("offscreen %s '%s' (%d,%d %dx%d) @%s" % [c.get_class(), text.left(30), r.position.x, r.position.y, r.size.x, r.size.y, path])


func _check_control(c: Control, path: String, out: Array, english: Dictionary) -> void:
	var text := ""
	if c is Label:
		text = (c as Label).text
	elif c is Button:
		text = (c as Button).text
	elif c is LineEdit:
		text = (c as LineEdit).text if (c as LineEdit).text != "" else (c as LineEdit).placeholder_text
	if text.strip_edges() == "" or not c.is_visible_in_tree() or c.modulate.a < 0.05:
		return
	var font: Font = c.get_theme_font("font")
	var fs: int = c.get_theme_font_size("font_size")
	for ch in text:
		if ch == "\n" or ch == " ":
			continue
		if not font.has_char(ch.unicode_at(0)):
			out.append("glyph %s in '%s' @%s" % [ch, text.left(30), path])
			break
	if english.has(text.strip_edges()):
		out.append("untranslated '%s' @%s" % [text.left(40), path])
	var rect := c.get_global_rect()
	var box := _container_rect(c)
	if box.size.x > 0 and not box.grow(4).encloses(rect):
		out.append("escapes '%s' (%d,%d %dx%d) @%s" % [text.left(30), rect.position.x, rect.position.y, rect.size.x, rect.size.y, path])
	if c is Label:
		var l := c as Label
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var w := 0.0
			for line in text.split("\n"):
				w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
			if w > l.size.x + 2 and (l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING):
				_cut(out, c, text, "'%s' @%s" % [text.left(30), path])
		else:
			var shown := l.get_visible_line_count()
			var lines := l.get_line_count()
			if shown < lines:
				if l.max_lines_visible > 0 or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
					_cut(out, c, text, "'%s' (%d of %d lines) @%s" % [text.left(30), shown, lines, path])
				else:
					out.append("cut off '%s' (%d of %d lines) @%s" % [text.left(30), shown, lines, path])
			var split := _split_word(text, font, fs, l.size.x)
			if split != "":
				out.append("split word '%s' in '%s' @%s" % [split, text.left(30), path])
	elif c is Button:
		var b := c as Button
		if bool(b.get_meta("text_overflow", false)):
			out.append("overflow '%s' too wide for its button even at 20 @%s" % [text.left(30), path])
		var sb := b.get_theme_stylebox("normal")
		var need := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb else 0.0)
		if b.icon != null:
			need += b.icon.get_width() + b.get_theme_constant("h_separation")
		if need > b.size.x + 2 and b.clip_text:
			_cut(out, c, text, "'%s' @%s" % [text.left(30), path])


## A word too long for its line gets broken in the middle ("STEUEREINTREIBE / R"). Latin
## scripts only: Japanese and Chinese lines may break between any two characters.
func _split_word(text: String, font: Font, fs: int, width: float) -> String:
	if BMLoc.CJK.has(BMLoc.current) or width < 1.0:
		return ""
	for para in text.split("\n"):
		var tp := TextParagraph.new()
		tp.add_string(para, font, fs)
		tp.width = width
		tp.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		for i in tp.get_line_count() - 1:
			var end := tp.get_line_range(i).y
			if end > 0 and end < para.length() and _letter(para[end - 1]) and _letter(para[end]):
				return para.substr(maxi(0, end - 8), 16)
	return ""


func _letter(ch: String) -> bool:
	return ch.to_upper() != ch.to_lower() or (ch >= "0" and ch <= "9")


## Shortened text is fine where the full text is one hover away (the card or control's
## tooltip); anywhere else it hides information.
func _cut(out: Array, c: Control, text: String, what: String) -> void:
	var n: Node = c
	for i in 8:
		if n == null or not (n is Control):
			break
		var tip := String((n as Control).tooltip_text)
		if "tooltip_body" in n:
			tip += " " + String(n.get("tooltip_body"))
		if tip.contains(text.strip_edges()):
			out.append("shortened " + what)
			return
		n = n.get_parent()
	out.append("truncated " + what)


## A control placed at a fixed rect keeps that rect in its anchors and offsets; Godot silently
## enlarges `size` when the content's minimum size is bigger.
func _check_grown(c: Control, path: String, out: Array) -> void:
	var parent := c.get_parent_control()
	if parent == null or parent is Container or not c.is_visible_in_tree():
		return
	var want := Vector2((c.anchor_right - c.anchor_left) * parent.size.x + c.offset_right - c.offset_left,
			(c.anchor_bottom - c.anchor_top) * parent.size.y + c.offset_bottom - c.offset_top)
	if want.x < 1.0 or want.y < 1.0:
		return
	# Width and height separately: English growing 2 px taller must not excuse a wider translation.
	if c.size.x > want.x + 1.0:
		out.append("grew_wide %s '%s' %d -> %d @%s" % [c.get_class(), _first_text(c).left(30), want.x, c.size.x, path])
	if c.size.y > want.y + 1.0:
		out.append("grew_tall %s '%s' %d -> %d @%s" % [c.get_class(), _first_text(c).left(30), want.y, c.size.y, path])


func _first_text(n: Node) -> String:
	if n is Label:
		return (n as Label).text
	if n is Button and (n as Button).text != "":
		return (n as Button).text
	for ch in n.get_children():
		var t := _first_text(ch)
		if t != "":
			return t
	return ""


## The rect text must stay inside: the nearest panel (or scroll viewport), else the window.
func _container_rect(c: Control) -> Rect2:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			var s := (p as Control).get_global_rect()
			return Rect2(s.position.x, -1.0e6, s.size.x, 2.0e6)
		if p is PanelContainer or p is Panel:
			return (p as Control).get_global_rect()
		if p == main:
			break
		p = p.get_parent()
	return Rect2(Vector2.ZERO, main.size)
