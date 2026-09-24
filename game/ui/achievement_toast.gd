class_name BMAchievementToasts
extends Control
## Unlock announcements (GDD §20). Each new achievement slides a plate in at the top right
## (clear of centered dialogs such as the run-end screen): the medal flips in like a coin, a pill says ACHIEVEMENT / SECRET / LEGENDARY, then the
## name and rule. The fanfare and particles grow with the tier. Several unlocks queue up.
## Never takes input; Reduced Motion fades the plate in and out and skips particles.

const HOLD := {"bronze": 3.0, "silver": 3.4, "gold": 4.0, "legend": 5.0}
const WIDTH := 600.0

var reduced_motion := false
var _queue: Array[String] = []
var _busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func announce(ids: Array) -> void:
	for id in ids:
		_queue.append(String(id))
	if not _busy:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	_show(_queue.pop_front())


func _show(id: String) -> void:
	var d := BMAchievements.get_def(id)
	var tier := String(d.tier)
	var secret := bool(d.get("secret", false))
	var plate := BMStyle.panel("panel_sun" if tier in ["gold", "legend"] else "panel_plate", Vector4(20, 12, 24, 14))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.custom_minimum_size = Vector2(WIDTH, 0)
	add_child(plate)
	var row := BMStyle.hbox(18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)
	var badge := BMBadge.new().setup(id, true, 4.0)
	row.add_child(badge)
	var v := BMStyle.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var pill_text := "LEGENDARY!" if tier == "legend" else ("SECRET UNLOCKED!" if secret else "ACHIEVEMENT UNLOCKED")
	var pill_kind := "pink" if tier == "legend" else ("plum" if secret else ("sky" if tier in ["gold"] else "mint"))
	var pill_row := BMStyle.hbox(10)
	pill_row.add_child(BMStyle.pill(pill_text, pill_kind, 20))
	var tl := BMStyle.label(String(BMAchievements.TIER_NAMES[tier]).to_upper(), 20, BMTrophyCase.TIER_COLORS[tier] if tier not in ["gold", "legend"] else BMStyle.INK, true, 0 if tier in ["gold", "legend"] else 6)
	pill_row.add_child(tl)
	v.add_child(pill_row)
	var dark := tier in ["gold", "legend"]
	var name_l := BMStyle.label(String(d.name), 30, BMStyle.INK if dark else BMStyle.SUN, true, 0 if dark else 8)
	v.add_child(name_l)
	var text := BMStyle.label(String(d.text), 20, Color(BMStyle.INK, 0.8) if dark else BMStyle.CREAM)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.max_lines_visible = 2
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(text)
	plate.reset_size()
	var rest := Vector2(size.x - plate.size.x - 24, 24).round()
	plate.position = rest
	BMAudio.sfx("ach_secret" if secret and tier != "legend" else "ach_" + tier)
	var hold: float = HOLD.get(tier, 3.2)
	if reduced_motion:
		plate.modulate.a = 0.0
		var tw := plate.create_tween()
		tw.tween_property(plate, "modulate:a", 1.0, 0.2)
		tw.tween_interval(hold)
		tw.tween_property(plate, "modulate:a", 0.0, 0.3)
		tw.tween_callback(_done.bind(plate))
		return
	plate.position.x = size.x + 20
	badge.spin = 0.05
	var tw := plate.create_tween()
	tw.tween_property(plate, "position:x", rest.x, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _celebrate(badge, tier))
	tw.tween_property(badge, "spin", 1.0, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(plate, "position:x", size.x + 20, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(_done.bind(plate))


func _celebrate(badge: BMBadge, tier: String) -> void:
	if BMFx.instance == null or not is_instance_valid(badge):
		return
	var at := badge.get_global_rect().get_center()
	var col: Color = BMTrophyCase.TIER_COLORS.get(tier, BMStyle.SUN_L)
	BMFx.instance.ring(at, col, 90.0)
	BMFx.instance.stars(at, 8, 80, col.lightened(0.3))
	match tier:
		"silver":
			BMFx.instance.sparks(at, BMStyle.CREAM, 12)
		"gold":
			BMFx.instance.sparks(at, BMStyle.SUN_L, 18)
			BMFx.instance.confetti(Rect2(Vector2(size.x * 0.55, 0), Vector2(size.x * 0.45, 10)), 70)
		"legend":
			BMFx.instance.burst(at, [BMStyle.PINK, BMStyle.SUN, BMStyle.MINT, BMStyle.SKY, BMStyle.LILAC], 40, 520.0)
			BMFx.instance.confetti(Rect2(Vector2.ZERO, Vector2(size.x, 10)), 180)
			BMFx.instance.shake(6.0)
			if BMSwirlBackground.instance:
				BMSwirlBackground.instance.pulse(1.0)


func _done(plate: Control) -> void:
	if is_instance_valid(plate):
		plate.queue_free()
	_next()
