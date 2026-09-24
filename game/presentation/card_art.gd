class_name BMCardArt
extends RefCounted
## Card portraits: the 16x16 pixel sprites from tools/art/gen_cards.py (one per Joker, item,
## Workshop tool and achievement). Each sheet row holds 8 frames: 0 rest pose, 1-6 a glint of
## light sweeping across, 7 a dark silhouette for locked or unknown things. Drawn at whole-number
## scales with nearest filtering so the pixels stay square. Visual only.

const SIZE := 16
const FRAMES := 8
const SILHOUETTE := 7
const GLINT_FRAMES := 6
const GLINT_STEP := 0.055 ## seconds per glint frame

static var _index := {}
static var _sheets := {}


static func _load_index() -> void:
	if not _index.is_empty():
		return
	var f := FileAccess.open("res://assets/ui/cards/cards.json", FileAccess.READ)
	if f == null:
		push_warning("Card art index missing: run tools/art/gen_cards.py")
		_index = {"_": {}}
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	_index = data if data is Dictionary else {"_": {}}


static func has(set_name: String, id: String) -> bool:
	_load_index()
	return _index.has(set_name) and (_index[set_name] as Dictionary).has(id)


## Row (or, for "badges", column) of an entry in its sheet; 0 when unknown.
static func row(set_name: String, id: String) -> int:
	return int(_index[set_name][id]) if has(set_name, id) else 0


static func sheet(set_name: String) -> Texture2D:
	if not _sheets.has(set_name):
		_sheets[set_name] = load("res://assets/ui/cards/%s.png" % set_name)
	return _sheets[set_name]


## Source rect of one frame of a sprite in its sheet.
static func region(set_name: String, id: String, frame: int = 0) -> Rect2:
	_load_index()
	var row := int(_index[set_name][id])
	return Rect2(frame * SIZE, row * SIZE, SIZE, SIZE)


## Draws a sprite on `ci` with its top-left at `at`, `px` screen pixels per art pixel.
static func draw(ci: CanvasItem, set_name: String, id: String, at: Vector2, px: float, frame: int = 0, tint: Color = Color.WHITE) -> void:
	if not has(set_name, id):
		return
	ci.draw_texture_rect_region(sheet(set_name), Rect2(at.round(), Vector2(SIZE, SIZE) * px), region(set_name, id, frame), tint)


## Largest whole-number scale at which a sprite fits `room` pixels (at least 1).
static func fit_scale(room: float) -> float:
	return maxf(1.0, floorf(room / SIZE))


## Glint frame for a sprite at `t` seconds: a sweep every `period` seconds, offset per id so a
## shelf of cards never flashes in unison. 0 when resting.
static func glint_frame(id: String, t: float, period: float) -> int:
	var phase := fmod(t + float(absi(id.hash()) % 1000) / 1000.0 * period, period)
	var f := int(phase / GLINT_STEP) + 1
	return f if f <= GLINT_FRAMES else 0
