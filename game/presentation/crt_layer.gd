class_name BMCrtLayer
extends CanvasLayer
## Full-screen CRT post-process. Because the image is curved, pointer events are remapped with
## the same warp function before any other node sees them, so what you click is what you see.
## Modes: "off", "soft" (default), "full" (the reference strength).

const PRESETS := {
	"off": {},
	"soft": {"warp": 0.35, "scan": 0.28, "aberration": 1.0, "glow": 0.2, "vignette": 0.32, "grain": 0.02, "roll": 0.035},
	"full": {"warp": 0.75, "scan": 0.6, "aberration": 1.8, "glow": 0.3, "vignette": 0.45, "grain": 0.035, "roll": 0.06},
}

static var instance: BMCrtLayer

var mode := "soft"
var _rect: ColorRect
var _mat: ShaderMaterial
var _warp := 0.35
var _shock := 0.0
## Settings > Accessibility > Flashes also scales the CRT jolt (0 = none).
var shock_scale := 1.0


func _init() -> void:
	layer = 100
	instance = self


func _ready() -> void:
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://game/presentation/shaders/crt.gdshader")
	_rect.material = _mat
	add_child(_rect)
	set_mode(mode)


func set_mode(m: String) -> void:
	mode = m if PRESETS.has(m) else "soft"
	_rect.visible = mode != "off"
	var p: Dictionary = PRESETS.get(mode, {})
	for k in p:
		_mat.set_shader_parameter(k, p[k])
	_warp = float(p.get("warp", 0.0))


## Brief impact pulse (big clears). Presentation only.
func shock(amount: float) -> void:
	if mode == "off":
		return
	_shock = clampf(maxf(_shock, amount * shock_scale), 0.0, 1.0)


func _process(delta: float) -> void:
	if _shock > 0.0:
		_shock = maxf(0.0, _shock - delta * 2.5)
		_mat.set_shader_parameter("shock", _shock)


## Same curvature as the shader: screen uv -> content uv.
func warp_uv(uv: Vector2) -> Vector2:
	var dc := (Vector2(0.5, 0.5) - uv).abs()
	dc *= dc
	var out := uv
	out.x = (out.x - 0.5) * (1.0 + dc.y * 0.3 * _warp) + 0.5
	out.y = (out.y - 0.5) * (1.0 + dc.x * 0.4 * _warp) + 0.5
	return out


func _input(event: InputEvent) -> void:
	if mode == "off" or _warp <= 0.0 or not (event is InputEventMouse):
		return
	var size := get_viewport().get_visible_rect().size
	var uv: Vector2 = event.position / size
	event.position = warp_uv(uv) * size
