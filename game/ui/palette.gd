class_name BMPalette
extends RefCounted
## Placeholder "after-hours arcade workbench" palette (ASSET_PLAN §1 exploration values).
## Not final art direction. Color never carries meaning alone: every state also has a
## shape, outline, pattern, or text cue.

const BG := Color("#101923")
const BG_DEEP := Color("#0a1118")
const PANEL := Color("#132530")
const PANEL_EDGE := Color("#1f4450")
const TEAL := Color("#173944")
const CYAN := Color("#51D9E8")
const CORAL := Color("#F45C71")
const BRASS := Color("#F6BD50")
const TEXT := Color("#E8F1F4")
const TEXT_DIM := Color("#8FA7B0")
const CELL_EMPTY := Color("#0d1c24")
const CELL_EDGE := Color("#1b3440")
const INVALID := Color("#FF4D6A")
const CHIPS := Color("#51D9E8")
const MULT := Color("#F45C71")

const BLOCKS := [
	Color("#F2545B"), # red
	Color("#FF9A3D"), # orange
	Color("#FFD447"), # yellow
	Color("#4CD787"), # green
	Color("#4A8CFF"), # blue
	Color("#B46CF2"), # purple
	Color("#5E6B78"), # stone (boss fixed cell)
]

const RARITY := [Color("#9FB4BD"), Color("#51D9E8"), Color("#F6BD50")]


static func block(color_id: int) -> Color:
	return BLOCKS[clampi(color_id, 0, BLOCKS.size() - 1)]
