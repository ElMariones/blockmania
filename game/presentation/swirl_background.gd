class_name BMSwirlBackground
extends ColorRect
## Animated paint-swirl backdrop behind every screen. Follows the pointer gently and pulses
## on big moments (BMSwirlBackground.instance.pulse(0.8)). Reduced motion freezes it.

static var instance: BMSwirlBackground

var _mat: ShaderMaterial
var _pulse := 0.0
var _focus := Vector2(0.5, 0.5)
var _target_focus := Vector2(0.5, 0.5)


func _init() -> void:
	instance = self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://game/presentation/shaders/bg_swirl.gdshader")
	material = _mat


func set_motion(enabled: bool) -> void:
	_mat.set_shader_parameter("time_scale", 1.0 if enabled else 0.0)


## Palette shift for context (e.g. boss rounds glow hotter).
func set_mood(mood: String) -> void:
	match mood:
		"boss":
			_mat.set_shader_parameter("col_mid", Color("#4a1330"))
			_mat.set_shader_parameter("col_hot", Color("#b3263f"))
			_mat.set_shader_parameter("col_teal", Color("#2a1840"))
		"shop":
			_mat.set_shader_parameter("col_mid", Color("#26314f"))
			_mat.set_shader_parameter("col_hot", Color("#2f8c7a"))
			_mat.set_shader_parameter("col_teal", Color("#3b2a66"))
		_:
			_mat.set_shader_parameter("col_mid", Color("#3b1d51"))
			_mat.set_shader_parameter("col_hot", Color("#942d70"))
			_mat.set_shader_parameter("col_teal", Color("#0b4d57"))


func pulse(amount: float) -> void:
	_pulse = clampf(maxf(_pulse, amount), 0.0, 1.0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_target_focus = event.position / get_viewport().get_visible_rect().size


func _process(delta: float) -> void:
	_focus = _focus.lerp(_target_focus, minf(1.0, delta * 1.5))
	_mat.set_shader_parameter("focus", _focus)
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 0.8)
	_mat.set_shader_parameter("pulse", _pulse)
