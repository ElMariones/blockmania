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
var drag_index := -1
var drag_enabled := false
var drag_receiver: Callable
var emblem: Emblem ## the card's portrait (hops when the card is hovered)

## Joker rack card height with five slots (the rack is 652 px tall).
const RACK_HEIGHT := 124
const PHASE_STYLE := {
	"chips": ["pill_sky", "icon_chip"],
	"add_mult": ["pill_pink", "icon_mult"],
	"x_mult": ["pill_sun", "icon_star"],
	"rule": ["pill_mint", "icon_gear"],
	"copy": ["pill_plum", "icon_target"],
}
const OFFER_SIZE := Vector2(260, 392)
const CARD_FX := preload("res://game/presentation/shaders/card_fx.gdshader")
const OFFER_BODY_LINES := 4
const JOKER_ICON := {
	"spare_parts": "icon_coin", "fire_sale": "icon_coin", "tiny_insurance": "icon_lock",
	"second_look": "icon_refresh", "long_game": "icon_hand", "chain_link": "icon_flame",
	"first_strike": "icon_target", "last_stand": "icon_skull", "hoarder": "icon_bag",
	"lean_bag": "icon_bag", "mimic": "icon_target", "collector": "icon_star",
	"patch_panel": "icon_eraser", "hot_hand": "icon_flame", "card_sharp": "icon_tag",
	"patience": "icon_hand", "locksmith": "icon_lock", "countdown": "icon_arrow_down",
	"breakage_bonus": "icon_coin", "insurance_policy": "icon_shield", "showboat": "icon_medal",
	"full_tank": "icon_bulb_on", "overflow": "icon_coin", "keystone": "icon_target",
	"draftsman": "icon_eraser", "periscope": "icon_scope", "loan_shark": "icon_coin",
}


func _ready() -> void:
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	# Reduced Motion freezes the Negative / AGAIN / Holo shader (the look itself stays).
	if reduced_motion and material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("motion", 0.0)
	if drag_index >= 0:
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_MOVE
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)


func _draw() -> void:
	if drag_index >= 0 and has_focus() and BMStyle.is_keyboard_focus_visible():
		draw_rect(Rect2(Vector2.ZERO, size).grow(-4), BMStyle.CREAM, false, 4.0)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not drag_enabled or drag_index < 0:
		return null
	var preview := BMStyle.panel("panel_plate", Vector4(12, 8, 12, 8))
	preview.custom_minimum_size = Vector2(260, 72)
	preview.add_child(BMStyle.label(BMJokers.display_name(String(data)), 20, BMStyle.SUN, true))
	set_drag_preview(preview)
	return {"kind": "bm_joker", "index": drag_index}


func _can_drop_data(_at_position: Vector2, payload: Variant) -> bool:
	return drag_enabled and payload is Dictionary and payload.get("kind", "") == "bm_joker" and int(payload.get("index", -1)) != drag_index


func _drop_data(_at_position: Vector2, payload: Variant) -> void:
	if _can_drop_data(_at_position, payload) and drag_receiver.is_valid():
		drag_receiver.call(int(payload.index), drag_index)


func _gui_input(event: InputEvent) -> void:
	if drag_enabled and event is InputEventKey and event.pressed and event.alt_pressed:
		var target := drag_index
		if event.keycode == KEY_UP:
			target -= 1
		elif event.keycode == KEY_DOWN:
			target += 1
		if target != drag_index and drag_receiver.is_valid():
			drag_receiver.call(drag_index, target)
			accept_event()


func _on_hover(on: bool) -> void:
	# Keep hover while the pointer is over child controls.
	if not on and get_global_rect().has_point(get_global_mouse_position()):
		return
	if on and not _hover:
		BMAudio.sfx("card_hover")
		if emblem != null:
			emblem.hop()
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


## The sell tab: while the card is hovered, a pink tab slides out of its right edge, full
## height, with SELL over the coin and the value (one line, "SELL +N", on a short card). It
## sits on the card like a drawer instead of floating over the text. The Button is named "Sell".
## `bottom_room` keeps the bottom of the card free (a round item card's USE button).
func add_sell_button(value: int, callback: Callable, disabled: bool = false, why: String = "", _small: bool = false, bottom_room: float = 0.0) -> Button:
	var wrap := Control.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tab := BMStyle.button("", callback, "pink", 20)
	tab.name = "Sell"
	tab.disabled = disabled
	tab.tooltip_text = why if why != "" else BMLoc.tn("Sell it for %d Credit.", "Sell it for %d Credits.", value) % value
	tab.clip_contents = true
	wrap.add_child(tab)
	# Two lines: SELL, then coin + value. Labels ignore the mouse so the tab gets every click.
	var stack := BMStyle.vbox(0)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var word := BMStyle.label(BMLoc.t("SELL"), 20, BMStyle.CREAM, true, 6)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(word)
	var price := BMStyle.hbox(4)
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	price.add_child(BMStyle.icon_rect("icon_coin", 0.5))
	price.add_child(BMStyle.label("+%d" % value, 20, BMStyle.SUN_L, true, 6))
	stack.add_child(price)
	var line := BMStyle.label(BMLoc.t("SELL +%d") % value, 20, BMStyle.CREAM, true, 6)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for n: Control in [stack, word, price, line]:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for n in price.get_children():
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.add_child(stack)
	tab.add_child(line)
	if disabled:
		stack.modulate = Color(1, 1, 1, 0.5)
		line.modulate = Color(1, 1, 1, 0.5)
	var font := BMStyle.font_bold
	var two_w := maxf(font.get_string_size(word.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, 26.0 + font.get_string_size("+%d" % value, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x)
	var one_w := font.get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	# Placed from the card's own rect: the panel's padding offsets the hover layer.
	var layout := func() -> void:
		var h := size.y - bottom_room - 12.0
		var two := h >= 62.0
		stack.visible = two
		line.visible = not two
		var w := (two_w if two else one_w) + 36.0
		tab.size = Vector2(maxf(w, 96.0), h)
		tab.position = Vector2(size.x - tab.size.x - 6.0, 6.0) - wrap.position
	wrap.resized.connect(layout)
	# The slide: the tab unfolds out of the card's right edge each time it shows.
	wrap.visibility_changed.connect(func() -> void:
		if not wrap.visible:
			return
		layout.call()
		if reduced_motion:
			return
		tab.pivot_offset = Vector2(tab.size.x, tab.size.y / 2.0)
		tab.scale = Vector2(0.4, 1.0)
		tab.modulate.a = 0.0
		var tw := tab.create_tween().set_parallel()
		tw.tween_property(tab, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(tab, "modulate:a", 1.0, 0.08))
	wrap.visible = false
	hover_controls = wrap
	add_child(wrap)
	return tab


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

## `height` shrinks the card when Rack Extender adds slots (the rack keeps its height).
## `width` is the rack's width (the round screen's rack is wider than the shop's).
static func joker_rack(run: BMRun, id: String, height: int = RACK_HEIGHT, width: float = 508.0, index: int = -1) -> BMCard:
	var def := BMJokers.get_def(id)
	var compact := height < RACK_HEIGHT
	var c := BMCard.new()
	c.kind = "joker"
	c.data = id
	var rarity := int(def.rarity)
	var disabled := BMLoc.tf(run.joker_disabled_reason(id)) if run != null else ""
	var jname := BMJokers.display_name(id)
	# A crowded rack (Rack Extender, 6-7 slots) trims the card's inner padding so its content
	# fits the slot height; otherwise the column would spill past the rack into the header below.
	var pad := Vector4(-2, 2, 0, -4) if height >= 90 else Vector4(-2, -4, 0, -9)
	c.add_theme_stylebox_override("panel", BMStyle.box(["rack_common", "rack_uncommon", "rack_rare", "rack_legendary"][rarity], pad))
	c.custom_minimum_size = Vector2(0, height)
	var h := BMStyle.hbox(10)
	c.add_child(h)
	# The emblem must leave room for the rim: at 6+ cards (Negative Jokers) a 64-px one would
	# push the card past its slot and the rack into the ITEMS header.
	var em := 80 if not compact else (64 if height >= 108 else 48)
	c.emblem = Emblem.for_joker(id, Vector2(em, em))
	var em_box := CenterContainer.new()
	em_box.add_child(c.emblem)
	h.add_child(em_box)
	var v := BMStyle.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var top := BMStyle.hbox(8)
	v.add_child(top)
	var name_l := BMStyle.label(jname, 20, BMStyle.INK, true)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name_l)
	# A long name keeps its full width: the rarity tag shortens instead (full words in the tooltip).
	# Traits (level, Negative, AGAIN) show as words next to the name: never color alone.
	var mod: Dictionary = run.joker_mod(index) if run != null and index >= 0 else {}
	var traits := PackedStringArray()
	if int(mod.get("level", 0)) > 0:
		traits.append(BMLoc.t("LV%d") % int(mod.level))
	if bool(mod.get("negative", false)):
		traits.append(BMLoc.t("NEGATIVE"))
	if bool(mod.get("again", false)):
		traits.append(BMLoc.t("AGAIN"))
	if not traits.is_empty():
		var tl := BMStyle.label(" ".join(traits), 20, Color("#c42848") if bool(mod.get("again", false)) else Color("#1f63b8"), true)
		top.add_child(tl)
		width -= BMStyle.font_bold.get_string_size(" ".join(traits), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 8.0
	var tag: String = BMJokers.rarity_name(rarity).to_upper()
	var fb := BMStyle.font_bold
	if fb.get_string_size(jname, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + fb.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > width - 130.0:
		tag = [BMLoc.t("COMMON"), BMLoc.t("UNCOM."), BMLoc.t("RARE"), BMLoc.t("LEGEND")][rarity]
	# Still too long (a narrow rack, a long translation): the name wins; the frame and the
	# tooltip still give the rarity.
	if fb.get_string_size(jname, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + fb.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x <= width - 130.0:
		var rl := BMStyle.label(tag, 20, [Color("#5c4282"), Color("#1f63b8"), Color("#a86a00"), Color("#7a3fd0")][rarity], true)
		top.add_child(rl)
	var body := BMJokers.display_text(id)
	var counter := BMJokers.counter_text(id, run) if run != null else ""
	var text := BMStyle.label(body, 20, Color(BMStyle.INK, 0.8))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.max_lines_visible = 1 if counter != "" or height < 110 else 2
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(text)
	if id == "periscope" and run != null:
		var peek := PeekStrip.new()
		peek.run = run
		peek.tooltip_text = counter
		v.add_child(peek)
	elif counter != "" and not (compact and height < 96):
		# Counters can be long ("Copying: nothing ..."); trim instead of widening the rack.
		var cl := BMStyle.label(counter, 20, Color("#1f63b8"), true)
		cl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(cl)
	if disabled != "":
		c.modulate = Color(0.65, 0.6, 0.7)
		name_l.text = jname + "  " + BMLoc.t("(DISABLED)")
	c.tooltip_text = jname
	c.tooltip_body = "%s  (%s)\n%s%s%s%s" % [jname, BMJokers.rarity_name(rarity), body,
		("\n" + counter) if counter != "" else "", ("\n" + BMLoc.t("DISABLED: %s") % disabled) if disabled != "" else "",
		trait_lines(mod)]
	apply_fx(c, bool(mod.get("negative", false)), bool(mod.get("again", false)), false, run == null)
	return c


## Tooltip lines explaining a Joker's traits ("" when it has none).
static func trait_lines(mod: Dictionary) -> String:
	var out := ""
	var lvl := int(mod.get("level", 0))
	if lvl > 0:
		out += "\n" + BMLoc.t("Level %d: +%d%% effect.") % [lvl, roundi(lvl * BMRunConfig.JOKER_LEVEL_STEP * 100.0)]
	if bool(mod.get("negative", false)):
		out += "\n" + BMLoc.t("NEGATIVE: takes no Joker slot.")
	if bool(mod.get("again", false)):
		out += "\n" + BMLoc.t("AGAIN: triggers once more after all your Jokers.")
	return out


## Card effects (Negative, AGAIN, Holo foil) drawn by one shader that every part of the card
## inherits. `still` freezes the motion (Reduced Motion or no run context); the look stays.
static func apply_fx(c: Control, negative: bool, again: bool, holo: bool, still: bool = false) -> void:
	if not (negative or again or holo):
		return
	var m := ShaderMaterial.new()
	m.shader = CARD_FX
	m.set_shader_parameter("negative", negative)
	m.set_shader_parameter("again", again)
	m.set_shader_parameter("holo", holo)
	m.set_shader_parameter("motion", 0.0 if still else 1.0)
	c.material = m
	_inherit_material(c)


static func _inherit_material(n: Node) -> void:
	for ch in n.get_children():
		if ch is CanvasItem:
			(ch as CanvasItem).use_parent_material = true
		_inherit_material(ch)


## Card height that fits `slots` cards in the 652-px rack with 8-px gaps, leaving room under
## the last card for its drop shadow above the ITEMS header (full 7-slot rack).
static func rack_height(slots: int) -> int:
	return mini(RACK_HEIGHT, (640 - 8 * (slots - 1)) / maxi(1, slots))


## An owned item. `layout`: "full" (name row, rules text, live value), "compact" (name row and
## live value) or "mini" (portrait over the name, for 3-4 narrow slots). The rules text is always
## in the tooltip; the live value (what the item is worth right now) shows on the card.
static func item_rack(id: String, run: BMRun = null, layout: String = "full", body_lines: int = 2, tile_live: bool = true, tile_room: float = 204.0) -> BMCard:
	var c := BMCard.new()
	c.kind = "item"
	c.data = id
	c.add_theme_stylebox_override("panel", BMStyle.box("rack_item", Vector4(2, -2, 2, -6)))
	var v := BMStyle.vbox(2)
	c.add_child(v)
	var live := BMConsumables.live_text(id, run)
	c.emblem = Emblem.for_item(id, Vector2(32, 32) if layout == "tile" else Vector2(40, 40))
	var n := BMStyle.label(BMConsumables.display_name(id), 20, BMStyle.INK, true)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.max_lines_visible = 2
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if layout == "tile":
		# A short card for 3-4 item slots (2x2 grid): portrait, then name and live value.
		var row := BMStyle.hbox(8)
		row.name = "Row"
		v.add_child(row)
		var em_box := CenterContainer.new()
		em_box.add_child(c.emblem)
		row.add_child(em_box)
		var info := BMStyle.vbox(0)
		info.name = "Info"
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(info)
		# The name wraps to two lines (never inside a word: a word too long for the tile trims
		# with an ellipsis instead); the live value takes the second line when there is one.
		n.max_lines_visible = 1 if (tile_live and live != "") else 2
		n.autowrap_mode = TextServer.AUTOWRAP_WORD
		n.clip_text = true
		n.tooltip_text = BMConsumables.display_name(id)
		var room := tile_room - 84.0 # rims, the 32-px portrait and the gap
		for word in BMConsumables.display_name(id).split(" "):
			if BMStyle.font_bold.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > room:
				n.autowrap_mode = TextServer.AUTOWRAP_OFF
				n.max_lines_visible = -1
		# A clipped, wrapping label reports a 1-px minimum height: give it its lines.
		var name_w := BMStyle.font_bold.get_string_size(BMConsumables.display_name(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var name_lines := 1 if n.max_lines_visible == 1 or n.autowrap_mode == TextServer.AUTOWRAP_OFF or name_w <= room else 2
		n.custom_minimum_size.y = (BMStyle.font_bold.get_height(20) + 4.0) * name_lines # + line spacing
		info.add_child(n)
		if tile_live and live != "":
			var tl := BMStyle.label(live, 20, Color("#1f63b8"), true)
			tl.name = "LiveValue"
			tl.clip_text = true
			tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			info.add_child(tl)
		c.tooltip_text = BMConsumables.display_name(id)
		c.tooltip_body = BMLoc.t("%s  (Item)") % BMConsumables.display_name(id) + "\n" + BMConsumables.display_text(id) \
			+ ("\n" + live if live != "" else "")
		return c
	if layout == "mini":
		var em := CenterContainer.new()
		em.add_child(c.emblem)
		v.add_child(em)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
	else:
		var top := BMStyle.hbox(8)
		v.add_child(top)
		top.add_child(c.emblem)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(n)
	if layout == "full":
		var body := BMStyle.label(BMConsumables.display_text(id), 20, Color(BMStyle.INK, 0.75))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.max_lines_visible = maxi(1, body_lines - (1 if live != "" else 0))
		body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(body)
	if live != "":
		var ll := BMStyle.label(live, 20, Color("#1f63b8"), true)
		ll.name = "LiveValue"
		ll.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if layout == "mini":
			ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ll)
	c.tooltip_text = BMConsumables.display_name(id)
	c.tooltip_body = BMLoc.t("%s  (Item)") % BMConsumables.display_name(id) + "\n" + BMConsumables.display_text(id) \
		+ ("\n" + live if live != "" else "")
	return c


## Item card layout for `slots` item slots: full cards for two, a 2x2 grid of tiles beyond.
static func item_layout(slots: int) -> String:
	return "full" if slots <= 2 else "tile"


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
			frame = ["card_common", "card_uncommon", "card_rare", "card_legendary"][rarity]
			title = BMJokers.display_name(value)
			body = BMJokers.display_text(value)
			tag = BMJokers.rarity_name(rarity).to_upper()
			tag_kind = ["plum", "sky", "sun", "lilac"][rarity]
			emblem = Emblem.for_joker(value, Vector2(80, 80))
		"item":
			var def := BMConsumables.get_def(value)
			frame = "card_item"
			title = BMConsumables.display_name(value)
			body = BMConsumables.display_text(value)
			tag = BMLoc.t("ITEM")
			tag_kind = "pink"
			emblem = Emblem.for_item(value, Vector2(80, 80))
		"tool":
			frame = "card_tool"
			title = BMTools.offer_name(value)
			body = BMTools.offer_text(value, run)
			tag = BMLoc.t("WORKSHOP")
			tag_kind = "mint"
			emblem = Emblem.for_tool(value, Vector2(80, 80))
		"piece":
			frame = "card_uncommon"
			title = BMPieces.piece_name(value)
			body = BMPieces.brief(value)
			tag = BMLoc.t("PIECE")
			tag_kind = "sky"
			emblem = Emblem.for_piece(value, Vector2(80, 80))
		"holo":
			frame = "card_holo"
			title = BMHolo.offer_name(value)
			body = BMHolo.offer_text(value)
			tag = BMLoc.t("HOLO")
			tag_kind = "holo"
			emblem = Emblem.for_holo(value, Vector2(80, 80))
	c.add_theme_stylebox_override("panel", BMStyle.box(frame, Vector4(-6, -4, -6, -8)))
	c.custom_minimum_size = OFFER_SIZE
	var v := BMStyle.vbox(6)
	c.add_child(v)
	var em_row := CenterContainer.new()
	em_row.add_child(emblem)
	c.emblem = emblem as Emblem
	v.add_child(em_row)
	var tag_row := HBoxContainer.new()
	tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tag_row.add_theme_constant_override("separation", 6)
	# A Joker you already own says so (a copy is possible, just rarer in the shop).
	var owned := 0
	if offer_kind == "joker" and run != null:
		owned = run.jokers.count(String(value))
	if owned > 0:
		var otag := BMLoc.t("OWNED")
		var fb := BMStyle.font_bold
		# Two pills (36 px of rim each) and a gap must fit the card's 224-px inner width: the
		# rarity word shortens, and if it still does not fit only OWNED shows (the frame color
		# and the tooltip still give the rarity).
		var room := OFFER_SIZE.x - 36.0 - 78.0 - 4.0
		if fb.get_string_size(tag + otag, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > room:
			tag = [BMLoc.t("COMMON"), BMLoc.t("UNCOM."), BMLoc.t("RARE"), BMLoc.t("LEGEND")][int(BMJokers.get_def(value).rarity)]
		if fb.get_string_size(tag + otag, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x <= room:
			tag_row.add_child(BMStyle.pill(tag, tag_kind, 20))
		var op := BMStyle.pill(otag, "plum", 20)
		op.name = "OwnedTag"
		op.tooltip_text = BMLoc.tn("You own %d of this Joker.", "You own %d of this Joker.", owned) % owned
		tag_row.add_child(op)
	else:
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
	if offer_kind == "holo":
		apply_fx(c, false, false, true, run == null)
	return c


## Pixel emblem: a colored tile (its color names the Joker's scoring phase) holding the card's
## own pixel portrait (BMCardArt), a piece drawing, or a Workshop illustration. Portraits catch
## a glint of light now and then (rare cards more often, with twinkles) and hop on hover.
## Reduced Motion shows the rest pose only.
class Emblem extends Control:
	var bg := "pill_plum"
	var icon := ""
	var piece: Dictionary = {}
	var badge := ""
	var level_text := ""
	var art_set := "" ## BMCardArt sheet ("jokers", "items", "tools"), "" = no portrait
	var art_id := ""
	var art_corner := false ## draw the portrait small in a corner (over a piece drawing)
	var glint_period := 5.0
	var twinkle := false ## rare cards: little stars blink around the portrait
	var _t := 0.0
	var _frame := 0
	var _hop := -1.0

	static func for_joker(id: String, sz: Vector2) -> Emblem:
		var e := Emblem.new()
		var def := BMJokers.get_def(id)
		var phase := String(def.get("phase", "rule"))
		var st: Array = BMCard.PHASE_STYLE.get(phase, BMCard.PHASE_STYLE.rule)
		e.bg = st[0]
		if BMCardArt.has("jokers", id):
			e.art_set = "jokers"
			e.art_id = id
			var rarity := int(def.get("rarity", 0))
			e.glint_period = [5.5, 4.0, 2.6, 1.6][rarity]
			e.twinkle = rarity >= BMJokers.RARE
		else:
			e.icon = BMCard.JOKER_ICON.get(id, st[1])
		e.custom_minimum_size = sz
		return e

	static func for_item(id: String, sz: Vector2) -> Emblem:
		var e := Emblem.new()
		e.bg = "pill_pink"
		if BMCardArt.has("items", id):
			e.art_set = "items"
			e.art_id = id
			e.glint_period = 4.5
		else:
			e.icon = {"polish": "icon_star", "spark": "icon_flame", "second_tray": "icon_refresh", "extra_turn": "icon_hand",
				"cash_out": "icon_coin", "eraser": "icon_eraser", "lucky_paint": "icon_bucket", "blueprint": "icon_blueprint",
				"punch": "icon_hammer", "color_purge": "icon_bucket", "emergency_brick": "icon_brick",
				"patch_panel": "icon_eraser"}.get(id, "icon_star")
		e.custom_minimum_size = sz
		return e

	static func for_piece(p: Dictionary, sz: Vector2) -> Emblem:
		var e := Emblem.new()
		e.bg = "pill_plum"
		e.piece = p
		e.custom_minimum_size = sz
		return e

	## Holo cards: a Legend Crate shows its Legendary's portrait; the rest their own.
	static func for_holo(o: Dictionary, sz: Vector2) -> Emblem:
		if String(o.get("id", "")) == "legend_crate" and String(o.get("joker", "")) != "":
			return Emblem.for_joker(String(o.joker), sz)
		var e := Emblem.new()
		e.bg = "pill_holo"
		e.glint_period = 2.6
		e.twinkle = true
		if BMCardArt.has("tools", String(o.get("id", ""))):
			e.art_set = "tools"
			e.art_id = String(o.id)
		e.custom_minimum_size = sz
		return e

	## Materials and stamps show a piece wearing them (the finish is the information); the
	## other Workshop cards have their own portrait. Schematics show the family they level up,
	## with the drafting portrait in the corner.
	static func for_tool(o: Dictionary, sz: Vector2) -> Emblem:
		var e := Emblem.new()
		e.bg = "pill_mint"
		e.glint_period = 4.8
		var def := BMTools.get_def(o.id)
		match String(def.kind):
			"material":
				e.piece = BMPieces.make(-1, &"square2", 0, 4, def.value)
			"stamp":
				e.piece = BMPieces.make(-1, &"single", 0, 1)
				e.badge = def.value
			"schematic":
				e.piece = BMPieces.make(-1, StringName(o.family), 0, 2)
				e.level_text = BMLoc.t("+1 LV")
		if e.piece.is_empty() and BMCardArt.has("tools", String(o.id)):
			e.art_set = "tools"
			e.art_id = String(o.id)
		elif String(def.kind) == "schematic" and BMCardArt.has("tools", "schematic"):
			e.art_set = "tools"
			e.art_id = "schematic"
			e.art_corner = true
		e.custom_minimum_size = sz
		return e

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(art_set != "")

	func hop() -> void:
		if art_set != "" and not BMBlockPainter.reduced_motion:
			_hop = 0.0

	func _process(delta: float) -> void:
		_t += delta
		var f := 0 if BMBlockPainter.reduced_motion else BMCardArt.glint_frame(art_id, _t, glint_period)
		var hopping := _hop >= 0.0
		if hopping:
			_hop += delta
			if _hop > 0.32:
				_hop = -1.0
		if f != _frame or hopping or (twinkle and not BMBlockPainter.reduced_motion):
			_frame = f
			queue_redraw()

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
				BMBlockPainter.draw_stamp_icon(self, Rect2(origin + Vector2(cell * 0.45, -cell * 0.25), Vector2(cell * 0.8, cell * 0.8)), badge)
		if art_set != "":
			_draw_art()
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
			BMUI.fit_size(level_text, f, 20, size.x - 8) # only reports text wider than the card
			var w := f.get_string_size(level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			draw_string_outline(f, Vector2((size.x - w) / 2.0, size.y - 8), level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 8, BMStyle.INK)
			draw_string(f, Vector2((size.x - w) / 2.0, size.y - 8), level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BMStyle.SUN)

	func _draw_art() -> void:
		if art_corner:
			var cs := 2.0 if size.x >= 64 else 1.0
			BMCardArt.draw(self, art_set, art_id, Vector2(size.x - 16 * cs - 3, 3), cs, _frame)
			return
		var px := BMCardArt.fit_scale(minf(size.x, size.y) - 6.0)
		var dim := Vector2(BMCardArt.SIZE, BMCardArt.SIZE) * px
		var at := ((size - dim) / 2.0).round()
		if _hop >= 0.0:
			at.y -= roundf(sin(_hop / 0.32 * PI) * 3.0) * px
		# Soft drop shadow one art pixel down-right, then the portrait.
		BMCardArt.draw(self, art_set, art_id, at + Vector2(px, px), px, BMCardArt.SILHOUETTE, Color(1, 1, 1, 0.35))
		BMCardArt.draw(self, art_set, art_id, at, px, _frame)
		if twinkle and not BMBlockPainter.reduced_motion:
			for i in 3:
				var k := fmod(_t * 0.9 + i * 0.37, 1.0)
				if k > 0.5:
					continue
				var a := sin(k / 0.5 * PI)
				var spots := [Vector2(0.12, 0.18), Vector2(0.86, 0.3), Vector2(0.2, 0.84)]
				var c: Vector2 = (size * spots[(i + int(_t * 0.9)) % 3]).round()
				var col := Color(BMStyle.SUN_L, a)
				draw_rect(Rect2(c - Vector2(1, 5), Vector2(2, 10)), col)
				draw_rect(Rect2(c - Vector2(5, 1), Vector2(10, 2)), col)
				draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, a))


## Periscope: the next three pieces of the draw pile as tiny drawings (presentation only).
class PeekStrip extends Control:
	var run: BMRun

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 32)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		draw_string(BMStyle.font_bold, Vector2(0, 22), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#1f63b8"))
		var x := 56.0
		for i in 3:
			if i >= run.draw_pile.size():
				draw_string(BMStyle.font_bold, Vector2(x, 22), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(BMStyle.INK, 0.5))
				x += 40.0
				continue
			var p := BMBag.piece_by_uid(run, int(run.draw_pile[i]))
			if p.is_empty():
				continue
			var dims := Vector2(BMShapes.shape_size(p))
			var cell := floorf(minf(10.0, 28.0 / maxf(dims.x, dims.y)))
			BMBlockPainter.draw_shape(self, p, Vector2(x, (32.0 - dims.y * cell) / 2.0).round(), cell)
			x += dims.x * cell + 16.0
