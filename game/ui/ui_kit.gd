class_name BMUI
extends RefCounted
## Placeholder theme and widget helpers so screens stay short. Final UI art replaces the
## StyleBoxes later; layout code keeps working.


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	t.set_color("font_color", "Label", BMPalette.TEXT)
	t.set_color("default_color", "RichTextLabel", BMPalette.TEXT)
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())
	t.set_stylebox("normal", "Button", _btn(BMPalette.TEAL, BMPalette.PANEL_EDGE))
	t.set_stylebox("hover", "Button", _btn(BMPalette.TEAL.lightened(0.12), BMPalette.CYAN))
	t.set_stylebox("pressed", "Button", _btn(BMPalette.TEAL.darkened(0.2), BMPalette.CYAN))
	t.set_stylebox("disabled", "Button", _btn(BMPalette.PANEL, Color(BMPalette.PANEL_EDGE, 0.5)))
	t.set_stylebox("focus", "Button", _focus_box())
	t.set_color("font_color", "Button", BMPalette.TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(BMPalette.TEXT_DIM, 0.6))
	t.set_stylebox("normal", "LineEdit", _btn(BMPalette.BG_DEEP, BMPalette.PANEL_EDGE))
	t.set_stylebox("focus", "LineEdit", _focus_box())
	t.set_color("font_color", "LineEdit", BMPalette.TEXT)
	var tip := panel_box(BMPalette.BG_DEEP, BMPalette.CYAN)
	tip.set_content_margin_all(10)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", BMPalette.TEXT)
	t.set_font_size("font_size", "TooltipLabel", 18)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = BMPalette.BG_DEEP
	bar_bg.set_corner_radius_all(6)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = BMPalette.CYAN
	bar_fill.set_corner_radius_all(6)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	return t


static func panel_box(bg: Color = BMPalette.PANEL, edge: Color = BMPalette.PANEL_EDGE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	return sb


static func _btn(bg: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func _focus_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = BMPalette.BRASS
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.expand_margin_left = 3
	sb.expand_margin_right = 3
	sb.expand_margin_top = 3
	sb.expand_margin_bottom = 3
	return sb


static func label(text: String, font_size: int = 20, color: Color = BMPalette.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, callback: Callable, font_size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(callback)
	return b


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func panel(bg: Color = BMPalette.PANEL, edge: Color = BMPalette.PANEL_EDGE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_box(bg, edge))
	return p


static func clear_children(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


static func fmt_mult(m: float) -> String:
	if is_equal_approx(m, roundf(m)):
		return str(int(m))
	return ("%.2f" % m).rstrip("0").rstrip(".")


static func fmt_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## A Joker card as a compact panel: name, rarity, rules text, live counter, disabled reason.
static func joker_card(run: BMRun, id: String, extra: Control = null, width: float = 0.0) -> PanelContainer:
	var def := BMJokers.get_def(id)
	var rarity := int(def.rarity)
	var disabled := run.joker_disabled_reason(id) if run != null else ""
	var edge: Color = BMPalette.RARITY[rarity]
	var p := panel(BMPalette.PANEL, Color(edge, 0.4) if disabled != "" else edge)
	if width > 0:
		p.custom_minimum_size.x = width
	var v := vbox(4)
	p.add_child(v)
	var head := hbox(8)
	v.add_child(head)
	var name_l := label(def.name, 21, BMPalette.TEXT if disabled == "" else BMPalette.TEXT_DIM)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	head.add_child(label(BMJokers.RARITY_NAMES[rarity].to_upper(), 14, edge))
	var text := label(def.text, 16, BMPalette.TEXT_DIM)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(text)
	if run != null:
		var counter := BMJokers.counter_text(id, run)
		if counter != "":
			v.add_child(label(counter, 15, BMPalette.CYAN))
	if disabled != "":
		var d := label("DISABLED: " + disabled, 15, BMPalette.CORAL)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)
	if extra != null:
		v.add_child(extra)
	p.tooltip_text = "%s (%s)\n%s" % [def.name, BMJokers.RARITY_NAMES[rarity], def.text]
	return p


static func item_card(id: String, extra: Control = null, width: float = 0.0) -> PanelContainer:
	var def := BMConsumables.get_def(id)
	var p := panel(BMPalette.BG_DEEP, BMPalette.CORAL)
	if width > 0:
		p.custom_minimum_size.x = width
	var v := vbox(4)
	p.add_child(v)
	var head := hbox(8)
	v.add_child(head)
	var n := label(def.name, 20)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	head.add_child(label("ITEM", 14, BMPalette.CORAL))
	var text := label(def.text, 16, BMPalette.TEXT_DIM)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(text)
	if extra != null:
		v.add_child(extra)
	p.tooltip_text = "%s\n%s" % [def.name, def.text]
	return p
