var R = m.run
var rows := ["00.13.55", "1..23..5", "11.2.4..", "223...40", ".555..11", "..51322.", "4..03.2.", "4400311."]
R.board = BMBoard.new()
for y in 8:
	for x in 8:
		var ch: String = rows[y][x]
		if ch != ".":
			R.board.set_cell(Vector2i(x, y), int(ch))
for mc in [[0, 7, "gold"], [7, 0, "chrome"], [6, 4, "neon"], [2, 3, "glass"], [4, 6, "chrome"], [1, 3, "gold"], [4, 0, "neon"], [7, 3, "prism"]]:
	R.board.mats[mc[1] * 8 + mc[0]] = BMPieces.material_index(mc[2])
var uids := [3, 7, 11]
R.tray[0] = BMPieces.make(uids[0], &"plus5", 0, 4, "neon")
R.tray[1] = BMPieces.make(uids[1], &"l4", 1, 1, "chrome")
R.tray[2] = BMPieces.make(uids[2], &"square2", 0, 2, "gold", "encore")
R.round_state.combo = 0
R.round_state.score = 3260
var plus_anchor := Vector2i(-1, -1)
for a in R.board.legal_anchors(R.tray[0].cells):
	var c = R.clone()
	var pr = c.place(0, a)
	if pr.ok and int(pr.lines) >= 2:
		plus_anchor = a
		break
print("INFO plus anchor ", plus_anchor)
m.game_screen.bind(R)
m.game_screen.close_overlay()
var rc = R.clone()
var ra = rc.board.legal_anchors(rc.tray[2].cells)
m.game_screen._write_receipt(rc.place(2, ra[ra.size() - 1]))
await get_tree().create_timer(0.3).timeout
