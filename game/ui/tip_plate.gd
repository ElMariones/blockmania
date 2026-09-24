class_name BMTipPlate
extends PanelContainer
## One contextual tip (BMTips) on a plate: a TIP pill, the title, the text and GOT IT. It
## slides in (fades under Reduced Motion), stays until dismissed or for LIFE seconds, and
## never blocks the board: only the plate itself takes the mouse. Presentation only.

signal dismissed

const LIFE := 16.0

var tip_id := ""
var reduced_motion := false
var _t := 0.0
var _closing := false


func _ready() -> void:
	add_theme_stylebox_override("panel", BMStyle.box("panel_plate", Vector4(18, 10, 18, 14)))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var def := BMTips.get_def(tip_id)
	var v := BMStyle.vbox(6)
	add_child(v)
	var head := BMStyle.hbox(12)
	v.add_child(head)
	head.add_child(BMStyle.pill("TIP", "sun", 20))
	var title := BMStyle.label(String(def.get("title", "")).to_upper(), 30, BMStyle.SUN_L, true, 6)
	head.add_child(title)
	var body := BMStyle.label(String(def.get("text", "")), 20, BMStyle.CREAM)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = maxf(300.0, custom_minimum_size.x - 40.0)
	v.add_child(body)
	var foot := BMStyle.hbox(10)
	v.add_child(foot)
	var off := BMStyle.label("Turn tips off in Options.", 20, BMStyle.TEXT_DIM)
	off.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	off.clip_text = true
	foot.add_child(off)
	var ok := BMStyle.button("GOT IT", close, "sun", 20)
	ok.custom_minimum_size = Vector2(130, 48)
	ok.focus_mode = Control.FOCUS_NONE
	foot.add_child(ok)
	BMAudio.sfx("tick", 1.3)
	if reduced_motion:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	else:
		var to := position
		position = to + Vector2(-60, 0)
		modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(self, "position", to, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 1.0, 0.18)


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE and not _closing and not get_global_rect().has_point(get_global_mouse_position()):
		close()


func close() -> void:
	if _closing:
		return
	_closing = true
	dismissed.emit()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)
