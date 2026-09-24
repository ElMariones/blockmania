class_name BMBadge
extends Control
## One achievement badge: a tiered medal frame (tools/art/gen_cards.py badges.png) holding the
## achievement's pixel icon. States: unlocked (full color, glint, legendary rims shimmer and
## twinkle), locked (dark frame, silhouette icon, small padlock) and secret (dark frame and a
## "?"). Drawn at a whole-number scale; the Trophy Case and the unlock toast both use it.
## Reduced Motion keeps the rest pose (the lock, "?" and colors still tell the state).

const FRAME := 24

var id := ""
var unlocked := false
var px := 4.0 ## screen pixels per art pixel
var lift := 0.0 ## hover lift in art pixels (set by the owner)
var spin := 1.0 ## horizontal squash for the toast's coin-flip reveal (1 = flat on)
var _t := 0.0
var _frame := 0


func setup(achievement_id: String, is_unlocked: bool, scale_px: float = 4.0) -> BMBadge:
	id = achievement_id
	unlocked = is_unlocked
	px = scale_px
	custom_minimum_size = Vector2(FRAME, FRAME) * px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self


func tier() -> String:
	return String(BMAchievements.get_def(id).get("tier", "bronze"))


func _process(delta: float) -> void:
	_t += delta
	if BMBlockPainter.reduced_motion or not unlocked:
		if _frame != 0:
			_frame = 0
			queue_redraw()
		return
	var period: float = {"bronze": 5.0, "silver": 4.0, "gold": 3.0, "legend": 2.0}.get(tier(), 4.0)
	_frame = BMCardArt.glint_frame(id, _t, period)
	queue_redraw()


func _draw() -> void:
	var secret := BMAchievements.is_secret(id) and not unlocked
	var frame_key := tier() if unlocked else ("secret" if secret else "locked")
	var sheet := BMCardArt.sheet("badges")
	var fi := BMCardArt.row("badges", frame_key)
	var dim := Vector2(FRAME, FRAME) * px
	var origin := ((size - Vector2(dim.x * spin, dim.y)) / 2.0).round() - Vector2(0, roundf(lift) * px)
	var rect := Rect2(origin, Vector2(dim.x * spin, dim.y))
	# Soft shadow under the medal.
	draw_rect(Rect2(rect.position + Vector2(px, px * 2), rect.size), Color(BMStyle.INK, 0.45))
	var tint := Color.WHITE
	if unlocked and frame_key == "legend" and not BMBlockPainter.reduced_motion:
		tint = Color.from_hsv(fmod(_t * 0.25, 1.0), 0.22, 1.0)
	draw_texture_rect_region(sheet, rect, Rect2(fi * FRAME, 0, FRAME, FRAME), tint)
	var icon_rect := Rect2(rect.position + Vector2(4 * px * spin, 4 * px), Vector2(16 * px * spin, 16 * px))
	var art := BMCardArt.sheet("achievements")
	if secret:
		draw_texture_rect_region(art, icon_rect, BMCardArt.region("achievements", "_mystery", 0))
	elif unlocked:
		draw_texture_rect_region(art, icon_rect, BMCardArt.region("achievements", id, _frame))
	else:
		draw_texture_rect_region(art, icon_rect, BMCardArt.region("achievements", id, BMCardArt.SILHOUETTE), Color(1.3, 1.3, 1.5, 0.9))
		var lock := BMStyle.tex("icon_lock")
		var ls := lock.get_size() * maxf(0.5, px / 4.0)
		draw_texture_rect(lock, Rect2((rect.end - ls - Vector2(px, px)).round(), ls), false)
	if unlocked and frame_key == "legend" and not BMBlockPainter.reduced_motion and spin >= 0.99:
		_twinkles(rect)


func _twinkles(rect: Rect2) -> void:
	var spots := [Vector2(0.06, 0.1), Vector2(0.94, 0.22), Vector2(0.1, 0.92), Vector2(0.9, 0.86)]
	for i in spots.size():
		var k := fmod(_t * 1.1 + i * 0.29, 1.0)
		if k > 0.45:
			continue
		var a := sin(k / 0.45 * PI)
		var c: Vector2 = (rect.position + rect.size * spots[i]).round()
		var arm := px * 2.0
		draw_rect(Rect2(c - Vector2(px / 2.0, arm), Vector2(px, arm * 2.0)), Color(BMStyle.SUN_L, a))
		draw_rect(Rect2(c - Vector2(arm, px / 2.0), Vector2(arm * 2.0, px)), Color(BMStyle.SUN_L, a))
