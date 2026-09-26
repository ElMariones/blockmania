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
			var none := BMLoc.t("NO SCORE HISTORY FOR THIS RUN")
			BMUI.draw_fit(self, BMStyle.font, Vector2(24, size.y / 2.0), none, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BMStyle.TEXT_DIM, size.x - 48)
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
		draw_string(BMStyle.font, Vector2(plot.position.x, size.y - 16), BMLoc.t("0 PLACEMENTS"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BMStyle.TEXT_DIM)
		BMUI.draw_fit(self, BMStyle.font, Vector2(plot.end.x - 300, size.y - 16), BMLoc.tn("%d PLACEMENT", "%d PLACEMENTS", last_p) % last_p, HORIZONTAL_ALIGNMENT_RIGHT, 300, 20, BMStyle.TEXT_DIM, 300)


func set_entry(value: Dictionary) -> void:
	entry = value
	BMUI.clear_children(self)
	var heading := BMStyle.label(BMLoc.t("RUN BREAKDOWN"), 30, BMStyle.MINT_L, true)
	_at(heading, Vector2(0, 0), Vector2(800, 46))
	var total := BMStyle.label(BMUI.fmt_int(int(entry.get("score", 0))), 60, BMStyle.SUN, true)
	_at(total, Vector2(0, 38), Vector2(800, 78))
	var complete := bool(entry.get("stats_complete", false))
	var unknown := "—"
	var fields := [
		[BMLoc.m("LINES CLEARED"), str(int(entry.get("lines", 0)))],
		[BMLoc.m("BLOCKS PLACED"), str(int(entry.get("placements", 0))) if complete else unknown],
		[BMLoc.m("HIGHEST COMBO"), "x%d" % int(entry.get("combo", 1))],
		[BMLoc.m("PERFECT CLEARS"), str(int(entry.get("perfect_clears", 0))) if complete else unknown],
		[BMLoc.m("LARGEST CLEAR"), BMLoc.tn("%d line", "%d lines", int(entry.get("largest_clear", 0))) % int(entry.get("largest_clear", 0)) if complete else unknown],
		[BMLoc.m("RUN DURATION"), _format_time(int(entry.get("duration_ms", 0))) if complete else unknown],
		[BMLoc.m("BOARD COVERAGE PEAK"), "%d%%" % int(entry.get("coverage_peak", 0)) if complete else unknown],
		[BMLoc.m("AVERAGE PLACEMENT"), BMLoc.t("%.1f sec") % (float(entry.get("average_placement_ms", 0)) / 1000.0) if complete else unknown],
		[BMLoc.m("SCORE / PLACEMENT"), "%.1f" % float(entry.get("score_per_placement", 0.0)) if complete else unknown],
		[BMLoc.m("BEST STREAK"), str(int(entry.get("best_streak", 0))) if complete else unknown],
		[BMLoc.m("SEED"), str(int(entry.get("seed", 0))) if entry.has("seed") else unknown],
		[BMLoc.m("DATE"), String(entry.get("date", unknown))],
	]
	for i in fields.size():
		var col := i / 6
		var row := i % 6
		var x := col * 430
		var y := 112 + row * 57
		var label := BMStyle.label(BMLoc.t(fields[i][0]), 20, BMStyle.TEXT_DIM, true)
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.tooltip_text = label.text
		_at(label, Vector2(x, y), Vector2(420, 25))
		var shown := BMStyle.label(str(fields[i][1]), 30, BMStyle.CREAM, true)
		_at(shown, Vector2(x, y + 22), Vector2(420, 38))
	var graph_label := BMStyle.label(BMLoc.t("SCORE PROGRESSION"), 20, BMStyle.SUN_L, true)
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
