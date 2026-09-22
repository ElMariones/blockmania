class_name BMCard
extends PanelContainer
## Card widgets: a compact horizontal "rack" card for owned Jokers/items and a tall "offer"
## card for the shop. Emblems are drawn per content type. Full rules text is always available:
## on the card (wrapped) and in a styled tooltip.

signal hovered_changed(on: bool)

var kind := "joker" ## joker | item | tool | piece
var data: Variant ## joker/item id (String), tool offer (Dictionary), or piece (Dictionary)
var tooltip_body := ""
var hover_controls: Control
var reduced_motion := false
var _hover := false
var _base_scale := Vector2.ONE

const PHASE_STYLE := {
	"chips": ["pill_sky", "icon_chip"],
	"add_mult": ["pill_pink", "icon_mult"],
	"x_mult": ["pill_sun", "icon_star"],
	"rule": ["pill_mint", "icon_gear"],
	"copy": ["pill_plum", "icon_target"],
}
const OFFER_SIZE := Vector2(260, 392)
const OFFER_BODY_LINES := 4
const JOKER_ICON := {
	"spare_parts": "icon_coin", "fire_sale": "icon_coin", "tiny_insurance": "icon_lock",
	"second_look": "icon_refresh", "long_game": "icon_hand", "chain_link": "icon_flame",
	"first_strike": "icon_target", "last_stand": "icon_skull", "hoarder": "icon_bag",
	"lean_bag": "icon_bag", "mimic": "icon_target", "collector": "icon_star",
}


func _ready() -> void:
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


func _on_hover(on: bool) -> void:
	# Keep hover while the pointer is over child controls.
	if not on and get_global_rect().has_point(get_global_mouse_position()):
		return
	_hover = on
	if hover_controls:
		hover_controls.visible = on
	hovered_changed.emit(on)
	if reduced_motion:
		return
	pivot_offset = size / 2.0
	var tw := create_tween()
	tw.tween_property(self, "scale", _base_scale * (1.04 if on else 1.0), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _make_custom_tooltip(_for_text: String) -> Object:
	if tooltip_body == "":
		return null
	var l := BMStyle.label(tooltip_body, 20, BMStyle.CREAM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	return l


## Trigger feedback: bounce, glow, and a pop label above the card.
func pulse(text: String = "", color: Color = BMStyle.SUN) -> void:
	if not reduced_motion:
		pivot_offset = size / 2.0
		var tw := create_tween()
		modulate = Color(1.5, 1.4, 1.1)
		tw.tween_property(self, "scale", Vector2(1.1, 1.1), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2.ONE, 0.14)
		tw.parallel().tween_property(self, "modulate", Color.WHITE, 0.3)
	if text != "" and BMFx.instance:
		var at := get_global_rect().get_center() + Vector2(-size.x * 0.25, -size.y * 0.35)
		BMFx.instance.pop_text(at, text, color, 30, 50.0, 0.8)


# --- Builders ------------------------------------------------------------------------------

static func joker_rack(run: BMRun, id: String) -> BMCard:
	var def := BMJokers.get_def(id)
	var c := BMCard.new()
	c.kind = "joker"
	c.data = id
	var rarity := int(def.rarity)
	var disabled := run.joker_disabled_reason(id) if run != null else ""
	c.add_theme_stylebox_override("panel", BMStyle.box(["rack_common", "rack_uncommon", "rack_rare"][rarity], Vector4(-2, 2, 0, -4)))
	c.custom_minimum_size = Vector2(0, 124)
	var h := BMStyle.hbox(10)
	c.add_child(h)
	h.add_child(Emblem.for_joker(id, Vector2(72, 72)))
	var v := BMStyle.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var top := BMStyle.hbox(8)
	v.add_child(top)
	var name_l := BMStyle.label(def.name, 20, BMStyle.INK, true)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name_l)
	var rl := BMStyle.label(BMJokers.RARITY_NAMES[rarity].to_upper(), 20, [Color("#5c4282"), Color("#1f63b8"), Color("#a86a00")][rarity], true)
	top.add_child(rl)
	var body := String(def.text)
	var counter := BMJokers.counter_text(id, run) if run != null else ""
	var text := BMStyle.label(body, 20, Color(BMStyle.INK, 0.8))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.max_lines_visible = 1 if counter != "" else 2
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(text)
	if counter != "":
		# Counters can be long ("Copying: nothing ..."); trim instead of widening the rack.
		var cl := BMStyle.label(counter, 20, Color("#1f63b8"), true)
		cl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(cl)
	if disabled != "":
		c.modulate = Color(0.65, 0.6, 0.7)
		name_l.text = def.name + "  (DISABLED)"
	c.tooltip_text = def.name
	c.tooltip_body = "%s  (%s)\n%s%s%s" % [def.name, BMJokers.RARITY_NAMES[rarity], body,
		("\n" + counter) if counter != "" else "", ("\nDISABLED: " + disabled) if disabled != "" else ""]
	return c


static func item_rack(id: String) -> BMCard:
	var def := BMConsumables.get_def(id)
	var c := BMCard.new()
	c.kind = "item"
	c.data = id
	c.add_theme_stylebox_override("panel", BMStyle.box("rack_item", Vector4(2, -2, 2, -6)))
	var v := BMStyle.vbox(2)
	c.add_child(v)
	var top := BMStyle.hbox(8)
	v.add_child(top)
	top.add_child(Emblem.for_item(id, Vector2(40, 40)))
	var n := BMStyle.label(def.name, 20, BMStyle.INK, true)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(n)
	c.tooltip_text = def.name
	c.tooltip_body = "%s  (Item)\n%s" % [def.name, def.text]
	return c


## Tall shop card. `price_button` is placed at the bottom.
static func offer(run: BMRun, offer_kind: String, value: Variant, price_button: Control) -> BMCard:
	var c := BMCard.new()
	c.kind = offer_kind
	c.data = value
	var frame := "card_common"
	var title := ""
	var body := ""
	var tag := ""
	var tag_kind := "plum"
	var emblem: Control
	match offer_kind:
		"joker":
			var def := BMJokers.get_def(value)
			var rarity := int(def.rarity)
			frame = ["card_common", "card_uncommon", "card_rare"][rarity]
			title = def.name
			body = def.text
			tag = BMJokers.RARITY_NAMES[rarity].to_upper()
			tag_kind = ["plum", "sky", "sun"][rarity]
			emblem = Emblem.for_joker(value, Vector2(80, 80))
		"item":
			var def := BMConsumables.get_def(value)
			frame = "card_item"
			title = def.name
			body = def.text
			tag = "ITEM"
			tag_kind = "pink"
			emblem = Emblem.for_item(value, Vector2(80, 80))
		"tool":
			frame = "card_tool"
			title = BMTools.offer_name(value)
			body = BMTools.offer_text(value, run)
			tag = "WORKSHOP"
			tag_kind = "mint"
			emblem = Emblem.for_tool(value, Vector2(80, 80))
		"piece":
			frame = "card_uncommon"
			title = "%s %s" % [BMShapes.COLOR_NAMES[int(value.color)], BMShapes.family(value.family).name]
			body = BMPieces.brief(value)
			tag = "PIECE"
			tag_kind = "sky"
			emblem = Emblem.for_piece(value, Vector2(80, 80))
	c.add_theme_stylebox_override("panel", BMStyle.box(frame, Vector4(-6, -4, -6, -8)))
	c.custom_minimum_size = OFFER_SIZE
	var v := BMStyle.vbox(6)
	c.add_child(v)
	var em_row := CenterContainer.new()
	em_row.add_child(emblem)
	v.add_child(em_row)
	var tag_row := CenterContainer.new()
	tag_row.add_child(BMStyle.pill(tag, tag_kind, 20))
	v.add_child(tag_row)
	var t := BMStyle.label(title, 20, BMStyle.INK, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.max_lines_visible = 2
	v.add_child(t)
	# Fixed card size: the body shows what fits (ellipsis); the tooltip always has it all.
	var title_lines := 1 if BMStyle.font_bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x <= OFFER_SIZE.x - 40 else 2
	var b := BMStyle.label(body, 20, Color(BMStyle.INK, 0.78))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.max_lines_visible = OFFER_BODY_LINES + 1 - title_lines
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(b)
	v.add_child(price_button)
	c.tooltip_text = title
	c.tooltip_body = "%s\n%s" % [title, body if offer_kind != "piece" else BMPieces.describe(value)]
	return c


## Pixel emblem: colored tile with an icon, a piece drawing, or a Workshop illustration.
class Emblem extends Control:
	var bg := "pill_plum"
	var icon := ""
	var piece: Dictionary = {}
	var badge := ""
	var level_text := ""

	static func for_joker(id: String, sz: Vector2) -> Emblem:
		var e := Emblem.new()
		var phase := String(BMJokers.get_def(id).get("phase", "rule"))
		var st: Array = BMCard.PHASE_STYLE.get(phase, BMCard.PHASE_STYLE.rule)
		e.bg = st[0]
		e.icon = BMCard.JOKER_ICON.get(id, st[1])
		e.custom_minimum_size = sz
		return e

	static func for_item(id: String, sz: Vector2) -> Emblem:
		var e := Emblem.new()
		e.bg = "pill_pink"
		e.icon = {"polish": "icon_star", "spark": "icon_flame", "second_tray": "icon_refresh", "extra_turn": "icon_hand",
			"cash_out": "icon_coin", "eraser": "icon_target", "lucky_paint": "icon_star", "blueprint": "icon_gear"}.get(id, "icon_star")
		e.custom_minimum_size = sz
		return e

	static func for_piece(p: Dictionary, sz: Vector2) -> Emblem:
		var e := Emblem.new()
		e.bg = "pill_plum"
		e.piece = p
		e.custom_minimum_size = sz
		return e

	static func for_tool(o: Dictionary, sz: Vector2) -> Emblem:
		var e := Emblem.new()
		e.bg = "pill_mint"
		var def := BMTools.get_def(o.id)
		match String(def.kind):
			"material":
				e.piece = BMPieces.make(-1, &"square2", 0, 4, def.value)
			"stamp":
				e.piece = BMPieces.make(-1, &"single", 0, 1)
				e.badge = def.value
			"copy":
				e.piece = BMPieces.make(-1, &"bar2", 0, 3)
				e.icon = "icon_star"
			"remove":
				e.piece = BMPieces.make(-1, &"single", 0, 6)
				e.icon = "icon_target"
			"rotate":
				e.piece = BMPieces.make(-1, &"l3", 0, 5)
				e.icon = "icon_refresh"
			"repaint":
				e.piece = BMPieces.make(-1, &"bar3", 0, 0, "prism")
			"schematic":
				e.piece = BMPieces.make(-1, StringName(o.family), 0, 2)
				e.level_text = "+1 LV"
		e.custom_minimum_size = sz
		return e

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(BMStyle.box(bg, Vector4.ZERO), r)
		draw_rect(r.grow(-10), Color(BMStyle.INK, 0.22))
		if not piece.is_empty():
			var dims := Vector2(BMShapes.shape_size(piece))
			var cell := floorf(minf((size.x - 28) / dims.x, (size.y - 28) / dims.y))
			cell = minf(cell, size.x * 0.34)
			var origin := ((size - dims * cell) / 2.0).round()
			BMBlockPainter.draw_shape(self, piece, origin, cell)
			if badge != "":
				draw_texture_rect(BMStyle.tex("stamp_" + badge), Rect2(origin + Vector2(cell * 0.45, -cell * 0.25), Vector2(cell * 0.8, cell * 0.8)), false)
		if icon != "":
			var t := BMStyle.tex(icon)
			var s := t.get_size() * (1.0 if piece.is_empty() else 0.7)
			if piece.is_empty():
				s = t.get_size() * floorf(minf(size.x * 0.62 / t.get_size().x, size.y * 0.62 / t.get_size().y) * 4.0) / 4.0
				draw_texture_rect(t, Rect2(((size - s) / 2.0).round(), s), false)
			else:
				draw_texture_rect(t, Rect2(Vector2(size.x - s.x - 4, size.y - s.y - 4), s), false)
		if level_text != "":
			var f := BMStyle.font_bold
			var w := f.get_string_size(level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			draw_string_outline(f, Vector2((size.x - w) / 2.0, size.y - 8), level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 8, BMStyle.INK)
			draw_string(f, Vector2((size.x - w) / 2.0, size.y - 8), level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BMStyle.SUN)
