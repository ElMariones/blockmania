extends Control
## Shared Endless run breakdown for the result screen and the high-score viewer.

var entry: Dictionary = {}


class ScoreGraph extends Control:
	var samples: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_style_box(BMStyle.box("panel_inset", Vector4.ZERO), Rect2(Vector2.ZERO, size))
		if samples.size() < 2:
			draw_string(BMStyle.font, Vector2(24, size.y / 2.0), "NO SCORE HISTORY FOR THIS RUN", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BMStyle.TEXT_DIM)
			return
		var plot := Rect2(Vector2(34, 28), size - Vector2(66, 72))
		for step in 4:
			var y := plot.position.y + plot.size.y * float(step) / 3.0
			draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(BMStyle.CREAM, 0.15), 2.0)
		var last_p := maxi(1, int(samples.back().p))
		var top := maxf(1.0, float(samples.back().score))
		var points := PackedVector2Array()
		for sample in samples:
			points.append(Vector2(plot.position.x + float(sample.p) / last_p * plot.size.x,
				plot.end.y - float(sample.score) / top * plot.size.y))
		draw_polyline(points, BMStyle.SUN, 5.0, false)
		draw_circle(points[points.size() - 1], 7.0, BMStyle.MINT_L)
		draw_string(BMStyle.font, Vector2(plot.position.x, size.y - 16), "0 PLACEMENTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BMStyle.TEXT_DIM)
		draw_string(BMStyle.font, Vector2(plot.end.x - 210, size.y - 16), "%d PLACEMENTS" % last_p, HORIZONTAL_ALIGNMENT_RIGHT, 210, 20, BMStyle.TEXT_DIM)


func set_entry(value: Dictionary) -> void:
	entry = value
	BMUI.clear_children(self)
	var heading := BMStyle.label("RUN BREAKDOWN", 30, BMStyle.MINT_L, true)
	_at(heading, Vector2(0, 0), Vector2(800, 46))
	var total := BMStyle.label(BMUI.fmt_int(int(entry.get("score", 0))), 60, BMStyle.SUN, true)
	_at(total, Vector2(0, 38), Vector2(800, 78))
	var complete := bool(entry.get("stats_complete", false))
	var unknown := "—"
	var fields := [
		["LINES CLEARED", str(int(entry.get("lines", 0)))],
		["BLOCKS PLACED", str(int(entry.get("placements", 0))) if complete else unknown],
		["HIGHEST COMBO", "x%d" % int(entry.get("combo", 1))],
		["PERFECT CLEARS", str(int(entry.get("perfect_clears", 0))) if complete else unknown],
		["LARGEST CLEAR", "%d lines" % int(entry.get("largest_clear", 0)) if complete else unknown],
		["RUN DURATION", _format_time(int(entry.get("duration_ms", 0))) if complete else unknown],
		["BOARD COVERAGE PEAK", "%d%%" % int(entry.get("coverage_peak", 0)) if complete else unknown],
		["AVERAGE PLACEMENT", "%.1f sec" % (float(entry.get("average_placement_ms", 0)) / 1000.0) if complete else unknown],
		["SCORE / PLACEMENT", "%.1f" % float(entry.get("score_per_placement", 0.0)) if complete else unknown],
		["BEST STREAK", str(int(entry.get("best_streak", 0))) if complete else unknown],
		["SEED", str(int(entry.get("seed", 0))) if entry.has("seed") else unknown],
		["DATE", String(entry.get("date", unknown))],
	]
	for i in fields.size():
		var col := i / 6
		var row := i % 6
		var x := col * 430
		var y := 112 + row * 57
		var label := BMStyle.label(fields[i][0], 20, BMStyle.TEXT_DIM, true)
		_at(label, Vector2(x, y), Vector2(420, 25))
		var shown := BMStyle.label(str(fields[i][1]), 30, BMStyle.CREAM, true)
		_at(shown, Vector2(x, y + 22), Vector2(420, 38))
	var graph_label := BMStyle.label("SCORE PROGRESSION", 20, BMStyle.SUN_L, true)
	_at(graph_label, Vector2(0, 460), Vector2(870, 28))
	var graph := ScoreGraph.new()
	graph.samples = entry.get("score_samples", [])
	_at(graph, Vector2(0, 490), Vector2(860, 190))


func _at(child: Control, at: Vector2, dimensions: Vector2) -> void:
	child.position = at
	child.size = dimensions
	add_child(child)


func _format_time(ms: int) -> String:
	var seconds := maxi(0, ms / 1000)
	return "%02d:%02d" % [seconds / 60, seconds % 60]
