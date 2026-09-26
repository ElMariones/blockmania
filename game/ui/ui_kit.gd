class_name BMUI
extends RefCounted
## Small formatting and node helpers shared by the screens. Visual styling lives in BMStyle.


static func clear_children(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


static func fmt_mult(m: float) -> String:
	if absf(m) >= 1.0e18 or is_nan(m) or is_inf(m):
		return "%.1e" % m
	if absf(m) >= 1.0e6:
		return fmt_score(int(m))
	if is_equal_approx(m, roundf(m)):
		return str(int(m))
	return ("%.2f" % m).rstrip("0").rstrip(".")


static func fmt_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var sep := BMLoc.thousands_sep()
	while s.length() > 3:
		out = sep + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Scores that fit the HUD at any size: exact below a million, then 12.3M / 4.56B / 789T / 1.00Q.
static func fmt_score(n: int) -> String:
	if absi(n) < 1_000_000:
		return fmt_int(n)
	for u in [[1.0e15, "Q"], [1.0e12, "T"], [1.0e9, "B"], [1.0e6, "M"]]:
		if absf(n) >= u[0]:
			var v: float = n / u[0]
			var fmt := "%.2f" if absf(v) < 10.0 else ("%.1f" if absf(v) < 100.0 else "%.0f")
			return (fmt % v) + String(u[1])
	return fmt_int(n)


## Lines of `text` that fit `width` px at `font_size`, broken by the TextServer's line rules, so
## languages without spaces (Japanese, Chinese) wrap between characters. For text drawn in code.
static func wrap_lines(text: String, font: Font, font_size: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	for para in text.split("\n"):
		if para == "":
			out.append("")
			continue
		var tp := TextParagraph.new()
		tp.add_string(para, font, font_size)
		tp.width = width
		tp.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		for i in tp.get_line_count():
			var r := tp.get_line_range(i)
			out.append(para.substr(r.x, r.y - r.x).strip_edges())
	return out


## Texts that do not fit their width even at size 20, as of their latest fit (the languages E2E
## scenario fails on any; a text that fits on a later call, after layout settles, drops out).
static var overflows: Array[String] = []
const FIT_SIZES := [80, 60, 40, 30, 20]


## The font size for one line drawn in code into `width` px: `font_size`, or the next smaller
## grid size (60, 40, 30, 20) at which a longer translation still fits.
## `report` false leaves `overflows` alone (a control that flags itself instead).
static func fit_size(text: String, font: Font, font_size: int, width: float, report := true) -> int:
	var s := font_size
	while font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width + 0.5:
		var i := FIT_SIZES.find(s)
		if i < 0 or i == FIT_SIZES.size() - 1:
			if report and overflows.size() < 200 and not overflows.has(text):
				overflows.append(text)
			return s
		s = FIT_SIZES[i + 1]
	overflows.erase(text)
	return s


## draw_string for one line in `width` px that steps a longer translation down to a smaller
## grid size (see fit_size). `fit_width` defaults to `width` less a 16 px margin.
static func draw_fit(ci: CanvasItem, font: Font, pos: Vector2, text: String, align: HorizontalAlignment,
		width: float, font_size: int, color: Color, fit_width := -1.0) -> void:
	var s := fit_size(text, font, font_size, fit_width if fit_width >= 0.0 else width - 16.0)
	ci.draw_string(font, pos, text, align, width, s, color)


## A button at a fixed width (already in the tree, so it has the theme's font): its font steps
## down the grid sizes until text, icon and margins fit. Still too wide at 20: the button gets
## the meta "text_overflow" (the languages E2E scenario fails on a visible one).
static func fit_button(b: Button, width: float, font_size: int) -> void:
	var s := font_size
	b.add_theme_font_size_override("font_size", s)
	while b.get_minimum_size().x > width:
		var i := FIT_SIZES.find(s)
		if i < 0 or i == FIT_SIZES.size() - 1:
			b.set_meta("text_overflow", true)
			return
		s = FIT_SIZES[i + 1]
		b.add_theme_font_size_override("font_size", s)
	b.set_meta("text_overflow", false)
