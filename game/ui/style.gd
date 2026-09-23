class_name BMStyle
extends RefCounted
## Visual language for the "Midnight Toybox Arcade" UI: palette, the original Blockhead pixel
## fonts, the generated pixel-art kit (assets/ui, produced by tools/art/gen_ui.py), 9-slice
## StyleBoxes, and the Godot Theme. One art pixel = 4 screen pixels at 1920x1080.

const ART_PX := 4

# Palette (mirrors tools/art/gen_ui.py).
const INK := Color("#1a1026")
const PLUM_DD := Color("#211631")
const PLUM_D := Color("#2d1e43")
const PLUM := Color("#3f2b5e")
const PLUM_L := Color("#5c4282")
const PLUM_LL := Color("#8062ad")
const CREAM := Color("#fff3db")
const CREAM_D := Color("#efd6b0")
const CREAM_DD := Color("#cda87c")
const SUN_L := Color("#ffec96")
const SUN := Color("#ffcc3d")
const SUN_D := Color("#de9622")
const MINT := Color("#3dd691")
const MINT_L := Color("#8cf4be")
const PINK := Color("#ff4d6d")
const PINK_L := Color("#ff96aa")
const SKY := Color("#4daaff")
const SKY_L := Color("#a0d8ff")
const LILAC := Color("#b388ff")
const TEXT := CREAM
const TEXT_DIM := Color("#b9a6d6")
const CHIPS := SKY
const MULT := PINK

const BLOCK_NAMES := ["red", "orange", "yellow", "green", "blue", "purple", "stone"]

static var _tex := {}
static var _nine := {}
static var font: FontFile
static var font_bold: FontFile
static var _theme: Theme
static var _infinity_icon: Texture2D
static var _focus_visible := false
static var _focus_styles: Array[StyleBoxFlat] = []


static func load_fonts() -> void:
	if font != null:
		return
	font = _pixel_font("res://assets/fonts/blockhead.ttf")
	font_bold = _pixel_font("res://assets/fonts/blockhead_bold.ttf")


static func _pixel_font(path: String) -> FontFile:
	var f: FontFile = (load(path) as FontFile).duplicate()
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	f.allow_system_fallback = true
	return f


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load("res://assets/ui/%s.png" % name)
	return _tex[name]


## Original pixel-art infinity emblem drawn in code at art resolution.
static func infinity_icon() -> Texture2D:
	if _infinity_icon != null:
		return _infinity_icon
	var rows := [
		"...####...####...",
		"..##..##.##..##..",
		".##....###....##.",
		"##.....###.....##",
		"##.....###.....##",
		".##....###....##.",
		"..##..##.##..##..",
		"...####...####...",
	]
	var img := Image.create(17, rows.size() + 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] != "#":
				continue
			img.set_pixel(x, y + 1, INK)
			var col := SUN_L if x < 8 else SKY_L
			if x in [7, 8, 9]:
				col = MINT_L
			img.set_pixel(x, y, col if y < 4 else col.darkened(0.18))
	img.resize(68, 36, Image.INTERPOLATE_NEAREST)
	_infinity_icon = ImageTexture.create_from_image(img)
	return _infinity_icon


static func block_tex(color_id: int) -> Texture2D:
	return tex("block_" + BLOCK_NAMES[clampi(color_id, 0, BLOCK_NAMES.size() - 1)])


static func nine(name: String) -> Array:
	if _nine.is_empty():
		var f := FileAccess.open("res://assets/ui/nine.json", FileAccess.READ)
		if f:
			_nine = JSON.parse_string(f.get_as_text())
	return _nine.get(name, [16, 16, 16, 16])


## 9-slice StyleBox from a kit texture. `pad` adds content padding (screen px) on every side.
static func box(name: String, pad: Vector4 = Vector4(8, 8, 8, 8)) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(name)
	var m: Array = nine(name)
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	sb.content_margin_left = m[0] + pad.x
	sb.content_margin_top = m[1] + pad.y
	sb.content_margin_right = m[2] + pad.z
	sb.content_margin_bottom = m[3] + pad.w
	return sb


static func button_boxes(b: Button, kind: String = "sun") -> void:
	b.add_theme_stylebox_override("normal", box("btn_%s_normal" % kind, Vector4(10, 2, 10, 4)))
	b.add_theme_stylebox_override("hover", box("btn_%s_hover" % kind, Vector4(10, 2, 10, 4)))
	b.add_theme_stylebox_override("pressed", box("btn_%s_pressed" % kind, Vector4(10, 6, 10, 0)))
	b.add_theme_stylebox_override("disabled", box("btn_disabled", Vector4(10, 2, 10, 4)))
	b.add_theme_stylebox_override("focus", focus_box())
	var dark := kind in ["sun", "mint", "sky"]
	var fc := INK if dark else CREAM
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(s, fc)
	b.add_theme_color_override("font_disabled_color", Color(TEXT_DIM, 0.7))


## grab_focus on the next frame, only if the control is still in the tree (modals can close first).
static func focus_later(c: Control) -> void:
	# Weak reference: capturing a freed Object in a lambda logs an engine error.
	var ref: WeakRef = weakref(c)
	var cb := func() -> void:
		var ctl := ref.get_ref() as Control
		if ctl != null and ctl.is_inside_tree() and ctl.is_visible_in_tree():
			ctl.grab_focus()
	cb.call_deferred()


static func focus_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	# Hugs the button face (the kit's buttons have a 3-art-px depth lip at the bottom).
	sb.border_color = CREAM if _focus_visible else Color.TRANSPARENT
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(8)
	sb.corner_detail = 2
	sb.expand_margin_left = 4
	sb.expand_margin_right = 4
	sb.expand_margin_top = 4
	sb.expand_margin_bottom = -8
	sb.anti_aliasing = false
	_focus_styles.append(sb)
	return sb


## A pointer can leave a control focused in Godot. Keep that focus for accessibility,
## but draw its outline only after a keyboard action.
static func set_keyboard_focus_visible(visible: bool) -> void:
	if _focus_visible == visible:
		return
	_focus_visible = visible
	for sb in _focus_styles:
		sb.border_color = CREAM if visible else Color.TRANSPARENT
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var focused := tree.root.gui_get_focus_owner()
		if focused != null:
			focused.queue_redraw()


static func is_keyboard_focus_visible() -> bool:
	return _focus_visible


static func make_theme() -> Theme:
	if _theme != null:
		return _theme
	load_fonts()
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 20
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(INK, 0.0))
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font("normal_font", "RichTextLabel", font)
	t.set_font("bold_font", "RichTextLabel", font_bold)
	t.set_font_size("normal_font_size", "RichTextLabel", 20)
	t.set_font_size("bold_font_size", "RichTextLabel", 20)
	t.set_font("font", "Button", font_bold)
	t.set_font_size("font_size", "Button", 20)
	t.set_stylebox("normal", "Button", box("btn_sun_normal", Vector4(10, 2, 10, 4)))
	t.set_stylebox("hover", "Button", box("btn_sun_hover", Vector4(10, 2, 10, 4)))
	t.set_stylebox("pressed", "Button", box("btn_sun_pressed", Vector4(10, 6, 10, 0)))
	t.set_stylebox("disabled", "Button", box("btn_disabled", Vector4(10, 2, 10, 4)))
	t.set_stylebox("focus", "Button", focus_box())
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(s, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(TEXT_DIM, 0.7))
	t.set_stylebox("panel", "PanelContainer", box("panel_plate"))
	t.set_stylebox("panel", "Panel", box("panel_plate"))
	t.set_stylebox("normal", "LineEdit", box("panel_inset", Vector4(8, 4, 8, 4)))
	t.set_stylebox("focus", "LineEdit", focus_box())
	t.set_color("font_color", "LineEdit", CREAM)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_DIM)
	t.set_color("caret_color", "LineEdit", SUN)
	t.set_font("font", "LineEdit", font_bold)
	t.set_font_size("font_size", "LineEdit", 20)
	t.set_stylebox("panel", "TooltipPanel", box("panel_tooltip", Vector4(10, 6, 10, 8)))
	t.set_color("font_color", "TooltipLabel", CREAM)
	t.set_font("font", "TooltipLabel", font)
	t.set_font_size("font_size", "TooltipLabel", 20)
	# Scrollbars: slim sun thumb on a dark track.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(INK, 0.6)
	track.content_margin_left = 4
	track.content_margin_right = 4
	var thumb := StyleBoxFlat.new()
	thumb.bg_color = SUN_D
	thumb.content_margin_left = 4
	thumb.content_margin_right = 4
	var thumb_hi := thumb.duplicate()
	thumb_hi.bg_color = SUN
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("grabber", "VScrollBar", thumb)
	t.set_stylebox("grabber_highlight", "VScrollBar", thumb_hi)
	t.set_stylebox("grabber_pressed", "VScrollBar", thumb_hi)
	_theme = t
	return t


# --- Widget helpers ------------------------------------------------------------------------

## Pixel label. `bold` uses Blockhead Bold; `outline` adds an ink outline for text on busy art.
static func label(text: String, size: int = 20, color: Color = TEXT, bold: bool = false, outline: int = 0) -> Label:
	load_fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_bold if bold else font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", outline)
	return l


static func button(text: String, callback: Callable, kind: String = "sun", size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	button_boxes(b, kind)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Sound first, so a callback that plays its own sound (buy, sell...) layers on top.
	b.pressed.connect(func() -> void: BMAudio.sfx("click"))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			BMAudio.sfx("hover"))
	b.pressed.connect(callback)
	return b


static func icon_rect(name: String, scale: float = 1.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(name)
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.custom_minimum_size = r.texture.get_size() * scale
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func panel(kind: String = "panel_plate", pad: Vector4 = Vector4(8, 8, 8, 8)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(kind, pad))
	return p


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


## A small rounded pill with text (rarity tags, section headers).
static func pill(text: String, kind: String = "sun", size: int = 20) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box("pill_" + kind, Vector4(6, -2, 6, 0)))
	var dark := kind in ["sun", "mint", "sky"]
	var l := label(text, size, INK if dark else CREAM, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Section header: bold cream text with an ink outline and a sun underline tick.
static func header(text: String, size: int = 30) -> Label:
	return label(text, size, SUN, true, 8)
