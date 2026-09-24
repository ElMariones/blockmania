class_name BMMoodLayer
extends ColorRect
## Screen-edge atmosphere (shaders/mood.gdshader): hazard tape on boss rounds, a heartbeat
## vignette when a round is in danger, heat haze at Heat 3+ / act 3, and color flashes for
## slams. Presentation only: screens set the targets, this layer eases toward them. The Screen
## Effects setting scales everything (0 = off); Reduced Motion freezes the animation and the
## heartbeat pulse but keeps the tint (information by color and edge, never by motion alone).

static var instance: BMMoodLayer

var strength := 1.0
var reduced_motion := false
## Settings > Accessibility > Flashes (0 = none) and Settings > Audio > Danger heartbeat.
var flash_scale := 1.0
var heartbeat_sound := true
var _mat: ShaderMaterial
var _boss := 0.0
var _danger := 0.0
var _heat := 0.0
var target_boss := 0.0
var target_danger := 0.0
var target_heat := 0.0
var _flash := 0.0
var _beat_t := 0.0
var _beat := 0.0


func _init() -> void:
	instance = self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://game/presentation/shaders/mood.gdshader")
	material = _mat


## Sets the targets for a campaign round (called by the game screen after every refresh).
func set_round(boss: bool, danger: bool, heat: float) -> void:
	var was := target_danger
	target_boss = 1.0 if boss else 0.0
	target_danger = 1.0 if danger else 0.0
	target_heat = heat
	if danger and was <= 0.0 and strength > 0.0:
		BMAudio.sfx("danger_on")


func clear() -> void:
	target_boss = 0.0
	target_danger = 0.0
	target_heat = 0.0


func flash(color: Color, amount: float = 0.8) -> void:
	if strength <= 0.0 or flash_scale <= 0.0:
		return
	_mat.set_shader_parameter("flash_col", color)
	_flash = maxf(_flash, amount * flash_scale * (0.5 if reduced_motion else 1.0))


func _process(delta: float) -> void:
	var k := minf(1.0, delta * 2.5)
	_boss = lerpf(_boss, target_boss, k)
	_danger = lerpf(_danger, target_danger, k)
	_heat = lerpf(_heat, target_heat, k)
	_flash = maxf(0.0, _flash - delta * 2.2)
	# Heartbeat: ~70 bpm, a double thump; the sound plays on the first thump.
	if _danger > 0.05 and not reduced_motion:
		var before := _beat_t
		_beat_t = fmod(_beat_t + delta, 0.86)
		if _beat_t < before and target_danger > 0.0 and strength > 0.0 and heartbeat_sound:
			BMAudio.sfx("heartbeat")
		_beat = maxf(exp(-_beat_t * 9.0), 0.7 * exp(-maxf(0.0, _beat_t - 0.2) * 9.0) * (1.0 if _beat_t >= 0.2 else 0.0))
	else:
		_beat = 0.35
	_mat.set_shader_parameter("boss", _boss)
	_mat.set_shader_parameter("danger", _danger)
	_mat.set_shader_parameter("beat", _beat)
	_mat.set_shader_parameter("heat", _heat)
	_mat.set_shader_parameter("flash", _flash)
	_mat.set_shader_parameter("strength", strength)
	_mat.set_shader_parameter("time_scale", 0.0 if reduced_motion else 1.0)
	visible = strength > 0.0 and (_boss + _danger + _heat + _flash) > 0.01
