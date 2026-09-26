class_name BMFinishes
extends RefCounted
## Cosmetic block finishes: Endless block styles and the campaign's material faces share one
## catalog. Art is the animated sprite sheets from tools/art/gen_finishes.py (sheet layout in
## assets/ui/finishes.json); this file adds presentation data: display text, how a board of
## blocks animates together, glow, particles and sounds. Presentation only: nothing here reads
## or changes rules state, and cosmetic randomness uses the global RNG.
##
## IDs are settings-facing (endless_skin) and match BMPieces.MATERIALS: never rename casually.

## Picker order. "classic" is the plain plastic block kit and has no sheet.
const ENDLESS := ["classic", "glass", "crystal", "neon", "gold", "marble", "cyberpunk", "wood",
	"candy", "lava", "ice", "chrome", "prism", "aurora", "starfall"]
const RARE := ["aurora", "starfall"]

## phase: how neighbouring cells offset their animation ("diag" = a wave rolling across the
##   board from the top-left, "hash" = each cell on its own beat, "none" = in step).
## hold: extra rest frames (frame 0) appended to each loop, so shine waves and sparkles breathe.
## glow: strength of the stepped halo under the block (0 = none); glow_color: "hue" | "sun" | "mint".
## place / clear: particle styles (see emit()).
const DEFS := { # i18n: name, tag
	"classic": {"name": "CLASSIC PLASTIC", "tag": "Bright toy plastic. The original.", "phase": "none", "hold": 0,
		"glow": 0.0, "glow_color": "hue", "place": "", "clear": "pop"},
	"glass": {"name": "STAINED GLASS", "tag": "Lead-lined jewel panes. Light rolls through them.", "phase": "diag", "hold": 18,
		"glow": 0.22, "glow_color": "hue", "place": "glint", "clear": "shatter"},
	"crystal": {"name": "CRYSTAL", "tag": "Step-cut gems with twinkling facets.", "phase": "hash", "hold": 10,
		"glow": 0.34, "glow_color": "hue", "place": "glint", "clear": "gems"},
	"neon": {"name": "NEON", "tag": "Buzzing glass tubes on a black sign.", "phase": "hash", "hold": 30,
		"glow": 0.62, "glow_color": "hue", "place": "ring", "clear": "zap"},
	"gold": {"name": "GOLD", "tag": "Gilded bullion, enamel jewel, rolling shine.", "phase": "diag", "hold": 16,
		"glow": 0.2, "glow_color": "sun", "place": "glint", "clear": "treasure"},
	"marble": {"name": "MARBLE", "tag": "Polished stone veined with color.", "phase": "diag", "hold": 20,
		"glow": 0.0, "glow_color": "hue", "place": "dust", "clear": "rubble"},
	"cyberpunk": {"name": "CYBERPUNK", "tag": "Circuit boards pulsing with data.", "phase": "hash", "hold": 0,
		"glow": 0.24, "glow_color": "hue", "place": "bits", "clear": "glitch"},
	"wood": {"name": "TOY WOOD", "tag": "Painted maple blocks with carved rings.", "phase": "none", "hold": 0,
		"glow": 0.0, "glow_color": "hue", "place": "dust", "clear": "splinters"},
	"candy": {"name": "CANDY", "tag": "Glossy pinwheels that slowly turn.", "phase": "hash", "hold": 0,
		"glow": 0.0, "glow_color": "hue", "place": "", "clear": "sprinkles"},
	"lava": {"name": "LAVA", "tag": "Basalt plates over pulsing magma.", "phase": "diag", "hold": 0,
		"glow": 0.4, "glow_color": "hue", "place": "embers", "clear": "eruption"},
	"ice": {"name": "ICE", "tag": "Frosted cubes with trapped bubbles.", "phase": "hash", "hold": 14,
		"glow": 0.16, "glow_color": "hue", "place": "frost", "clear": "blizzard"},
	"chrome": {"name": "CHROME", "tag": "Mirror polish. A glint races across.", "phase": "diag", "hold": 14,
		"glow": 0.0, "glow_color": "hue", "place": "glint", "clear": "sparks"},
	"prism": {"name": "PRISM", "tag": "Holographic foil in every color at once.", "phase": "diag", "hold": 0,
		"glow": 0.26, "glow_color": "hue", "place": "glint", "clear": "rainbow"},
	"aurora": {"name": "AURORA", "tag": "Northern lights over tiny mountains.", "phase": "diag", "hold": 0,
		"glow": 0.4, "glow_color": "mint", "place": "motes", "clear": "lights"},
	"starfall": {"name": "STARFALL", "tag": "Nebulae, twinkles and shooting stars.", "phase": "hash", "hold": 8,
		"glow": 0.42, "glow_color": "hue", "place": "glint", "clear": "cosmos"},
}

const HUES := [Color("#f6485c"), Color("#ff8e34"), Color("#ffce34"), Color("#3ace7c"), Color("#3c8eff"), Color("#a662ff"), Color("#78708a")]

static var _meta := {}


static func has_sheet(id: String) -> bool:
	return id != "" and id != "classic" and DEFS.has(id)


static func def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS.classic)


static func display_name(id: String) -> String:
	return BMLoc.t(String(def(id).name))


static func display_tag(id: String) -> String:
	return BMLoc.t(String(def(id).get("tag", "")))


static func hue(color_id: int) -> Color:
	return HUES[clampi(color_id, 0, HUES.size() - 1)]


static func meta() -> Dictionary:
	if _meta.is_empty():
		var f := FileAccess.open("res://assets/ui/finishes.json", FileAccess.READ)
		if f:
			_meta = JSON.parse_string(f.get_as_text())
		if _meta == null or _meta.is_empty():
			_meta = {"cell": 96, "face": 88, "finishes": {}, "stamp_cell": 56, "stamp_face": 48, "stamp_frames": 8}
	return _meta


## Frame index for a cell at `time` seconds (time <= 0 = the rest frame).
static func frame(id: String, cell: Vector2i, time: float) -> int:
	var m: Dictionary = meta().finishes.get(id, {})
	var frames := int(m.get("frames", 1))
	if time <= 0.0 or frames <= 1:
		return 0
	var d := def(id)
	var cycle := frames + int(d.hold)
	var offset := 0
	match String(d.phase):
		"diag":
			offset = -(cell.x + cell.y)
		"hash":
			offset = absi(cell.x * 7919 + cell.y * 104729 + cell.x * cell.y * 31) % cycle
	var f := posmod(int(time * float(m.get("fps", 8))) + offset, cycle)
	return f if f < frames else 0


## Source rect inside finish_<id>.png for a block color, board cell (variant + phase) and time.
static func region(id: String, color_id: int, cell: Vector2i, time: float) -> Rect2:
	var mm := meta()
	var m: Dictionary = mm.finishes.get(id, {})
	var variants := int(m.get("variants", 1))
	var variant := posmod(cell.x * 5 + cell.y * 3 + (cell.x * cell.y) % 3, variants) if variants > 1 else 0
	var c := float(mm.cell)
	var inset := (c - float(mm.face)) / 2.0
	return Rect2(frame(id, cell, time) * c + inset, (color_id * variants + variant) * c + inset, float(mm.face), float(mm.face))


static func stamp_region(time: float, phase: int = 0) -> Rect2:
	var mm := meta()
	var frames := int(mm.stamp_frames)
	var f := 0
	if time > 0.0:
		f = posmod(int(time * 7.0) + phase, frames + 20)
		if f >= frames:
			f = 0
	var c := float(mm.stamp_cell)
	var inset := (c - float(mm.stamp_face)) / 2.0
	return Rect2(f * c + inset, inset, float(mm.stamp_face), float(mm.stamp_face))


static func glow_color(id: String, color_id: int) -> Color:
	match String(def(id).glow_color):
		"sun":
			return BMStyle.SUN_L
		"mint":
			return BMStyle.MINT_L.lerp(hue(color_id), 0.35)
	return hue(color_id).lightened(0.25)


## Place/clear flourish for one cell. `strength` scales particle counts (1 = normal).
static func emit(style: String, at: Vector2, color_id: int, cell_px: float, strength: float = 1.0) -> void:
	var fx := BMFx.instance
	if fx == null or style == "":
		return
	var h := hue(color_id)
	var n := func(base: int) -> int: return maxi(1, roundi(base * strength))
	match style:
		"pop":
			fx.burst(at, [h, h.lightened(0.4), BMStyle.CREAM], n.call(7), 320.0, 8.0)
		"glint":
			fx.glint(at + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)) * cell_px, Color.WHITE)
		"ring":
			fx.ring(at, h.lightened(0.3), cell_px * 0.9)
		"dust":
			fx.dust(at + Vector2(0, cell_px * 0.4), cell_px, n.call(3))
		"bits":
			fx.bits(at, [h, Color("#5df1f7"), Color("#f54fb7")], n.call(3))
		"embers":
			fx.embers(at, [h.lightened(0.3), BMStyle.SUN_L], n.call(3), cell_px)
		"frost":
			fx.burst(at, [Color(1, 1, 1, 0.9), h.lightened(0.6)], n.call(4), 140.0, 4.0, false)
		"motes":
			fx.motes(at, [BMStyle.MINT_L, h.lightened(0.3)], n.call(2), cell_px)
		"shatter":
			fx.shards(at, n.call(6), h.lightened(0.45))
			fx.burst(at, [h, Color.WHITE], n.call(4), 300.0, 6.0)
		"gems":
			fx.shards(at, n.call(4), h.lightened(0.3))
			fx.stars(at, n.call(2), cell_px * 0.5, Color.WHITE)
		"zap":
			fx.sparks(at, h.lightened(0.35), n.call(7), 620.0)
			fx.sparks(at, Color.WHITE, n.call(3), 420.0)
			fx.ring(at, h.lightened(0.3), cell_px * 1.2)
		"treasure":
			fx.burst(at, [BMStyle.SUN, BMStyle.SUN_L, Color("#de9622"), h], n.call(8), 360.0, 8.0)
			fx.stars(at, n.call(1), cell_px * 0.4, BMStyle.SUN_L)
		"rubble":
			fx.burst(at, [Color("#efe9df"), Color("#cfc5bc"), h.lightened(0.2)], n.call(7), 260.0, 10.0)
			fx.dust(at, cell_px, n.call(3))
		"glitch":
			fx.bits(at, [h, h.lightened(0.5), Color("#5df1f7"), Color("#f54fb7"), Color.WHITE], n.call(9))
		"splinters":
			fx.chips(at, [Color("#daa666"), Color("#ba824a"), h], n.call(7))
		"sprinkles":
			fx.sprinkles(at, [BMStyle.PINK_L, BMStyle.SKY_L, BMStyle.SUN_L, BMStyle.MINT_L, Color.WHITE, h], n.call(9))
		"eruption":
			fx.embers(at, [h.lightened(0.4), BMStyle.SUN_L, Color("#fffae2")], n.call(9), cell_px)
			fx.burst(at, [h.darkened(0.2), Color("#2c2028")], n.call(4), 300.0, 8.0)
		"blizzard":
			fx.snow(at, n.call(5), cell_px)
			fx.shards(at, n.call(3), h.lightened(0.6))
		"sparks":
			fx.sparks(at, Color("#eef4ff"), n.call(8), 560.0)
			fx.burst(at, [h, Color("#98a6bc")], n.call(4), 320.0, 6.0)
		"rainbow":
			var bow := [Color("#ff8a9a"), Color("#ffc27a"), Color("#fff08a"), Color("#8cf4be"), Color("#8ac6ff"), Color("#d2a6ff")]
			fx.burst(at, bow, n.call(9), 360.0, 7.0)
			fx.stars(at, n.call(1), cell_px * 0.4, Color.WHITE)
		"lights":
			fx.motes(at, [BMStyle.MINT_L, Color("#c492ff"), h.lightened(0.3)], n.call(6), cell_px)
		"cosmos":
			fx.stars(at, n.call(3), cell_px * 0.6, h.lightened(0.5))
			fx.sparks(at, Color.WHITE, n.call(3), 380.0)
