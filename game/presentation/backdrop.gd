class_name BMBackdrop
extends Control
## Ambient retro layer: dark workbench gradient, faint grid, and a slow light-bar sweep.
## Purely decorative; sits behind all UI and stops animating under reduced motion.

var animate := true
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if animate:
		_t += delta
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BMPalette.BG)
	var steps := 12
	for i in steps:
		var y0 := size.y * i / steps
		var k := float(i) / steps
		draw_rect(Rect2(0, y0, size.x, size.y / steps + 1), Color(BMPalette.TEAL, 0.10 * k))
	var grid := 64.0
	var line := Color(BMPalette.CYAN, 0.035)
	var x := fmod(_t * 6.0, grid)
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), line, 1.0)
		x += grid
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), line, 1.0)
		y += grid
	var bar_y := fmod(_t * 90.0, size.y + 400.0) - 200.0
	for i in 8:
		draw_rect(Rect2(0, bar_y + i * 6, size.x, 6), Color(BMPalette.CYAN, 0.012 * (8 - absi(4 - i))))
